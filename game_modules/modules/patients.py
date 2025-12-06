from __future__ import annotations

import random
from dataclasses import dataclass, field
from typing import Dict, List, Optional

from .infections import build_clinical_notes, choose_infection_profile
from .treatments import TREATMENTS

SYMPTOMS = ["fever", "cough", "fatigue", "shortness", "sore_throat"]
COMORBIDITIES = [
    "Hypertension",
    "Diabetes",
    "Asthma",
    "Obesity",
    "Cardiac Disease",
    "Kidney Disease",
]


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def _generate_vitals(severity: float, rng: Optional[random.Random] = None) -> Dict[str, float]:
    uniform = rng.uniform if rng else random.uniform
    return {
        "hr": round(75 + severity * 40 + uniform(-5, 12)),
        "spo2": clamp(97 - severity * 20 + uniform(-4, 3), 70, 100),
        "bp": round(120 - severity * 15 + uniform(-5, 8)),
        "temp": 36.7 + severity * 2 + uniform(-0.2, 0.8),
        "rr": round(16 + severity * 12 + uniform(-2, 5)),
    }


def _roll_symptoms(
    severity: float,
    rng: Optional[random.Random] = None,
    bias: Optional[Dict[str, float]] = None,
) -> Dict[str, bool]:
    rand = rng.random if rng else random.random
    result: Dict[str, bool] = {}
    for symptom in SYMPTOMS:
        base = 0.35 + severity * 0.35
        base += (bias or {}).get(symptom, 0.0)
        chance = clamp(base, 0.0, 0.95)
        result[symptom] = rand() < chance
    return result


@dataclass
class Patient:
    id: int
    name: str
    admitted_hour: int
    severity: float
    infection: str
    infection_label: str
    actual_covid_status: str
    covid_status: str
    tested: bool
    diagnosis_known: bool
    ward: str
    vitals: Dict[str, float]
    symptoms: Dict[str, bool]
    risk: Dict[str, float]
    treatments: Dict[str, bool]
    infectivity: float
    base_infectivity: float
    hours_in_hospital: int
    recovery_progress: float
    alive: bool
    discharged: bool
    on_ventilator: bool
    notes: List[str] = field(default_factory=list)
    clinical_notes: List[str] = field(default_factory=list)
    requires_quarantine: bool = False

    @classmethod
    def create(cls, patient_id: int, current_hour: int, *, rng: Optional[random.Random] = None) -> "Patient":
        rand = rng.random if rng else random.random
        uniform = rng.uniform if rng else random.uniform
        randint = rng.randint if rng else random.randint
        choice = rng.choice if rng else random.choice

        severity = uniform(0.2, 1.0)
        infection_key, profile = choose_infection_profile(rng)
        covid_positive = profile["quarantine"]
        vitals = _generate_vitals(severity, rng)
        symptoms = _roll_symptoms(severity, rng, profile.get("symptom_bias"))
        infectivity = profile["infectivity"] + severity * 0.3
        clinical_notes = build_clinical_notes(infection_key, rng)
        return cls(
            id=patient_id,
            name=f"Patient {patient_id:03d}",
            admitted_hour=current_hour,
            severity=severity,
            infection=infection_key,
            infection_label=profile["label"],
            actual_covid_status="positive" if covid_positive else "negative",
            covid_status="unknown",
            tested=False,
            diagnosis_known=False,
            ward="triage",
            vitals=vitals,
            symptoms=symptoms,
            risk={"age": randint(22, 92), "comorbidity": choice(COMORBIDITIES)},
            treatments={},
            infectivity=infectivity,
            base_infectivity=infectivity,
            hours_in_hospital=0,
            recovery_progress=uniform(0, 0.2),
            alive=True,
            discharged=False,
            on_ventilator=False,
            clinical_notes=clinical_notes,
            requires_quarantine=profile["quarantine"],
        )

    def add_note(self, entry: str) -> None:
        self.notes.insert(0, entry)
        if len(self.notes) > 6:
            self.notes.pop()

    def treatment_modifiers(self) -> Dict[str, float]:
        modifiers = {
            "spo2": 0.0,
            "rr": 0.0,
            "temp": 0.0,
            "recovery": 0.0,
            "shedding": 0.0,
            "severity": 0.0,
            "stabilization": 0.0,
            "stress": 0.0,
            "vent": 0.0,
        }
        for key, active in self.treatments.items():
            if not active:
                continue
            treatment = TREATMENTS.get(key)
            if not treatment:
                continue
            for eff_key, value in treatment.effects.items():
                modifiers[eff_key] = modifiers.get(eff_key, 0.0) + value
        self.on_ventilator = modifiers.get("vent", 0) > 0
        return modifiers

    def tick(self, context: Optional[Dict[str, float]] = None) -> Optional[str]:
        if not self.alive or self.discharged:
            return None
        modifiers = self.treatment_modifiers()
        context = context or {}
        for key, value in context.items():
            modifiers[key] = modifiers.get(key, 0.0) + value

        self.hours_in_hospital += 1
        stress = clamp(self.severity * 0.4 - modifiers.get("stress", 0), 0, 1.5)
        self.vitals["spo2"] = clamp(self.vitals["spo2"] - stress * 2 + modifiers.get("spo2", 0), 60, 100)
        self.vitals["hr"] = clamp(self.vitals["hr"] + stress * 5 - modifiers.get("hr", 0), 45, 160)
        self.vitals["bp"] = clamp(self.vitals["bp"] - stress * 3 + modifiers.get("bp", 0), 80, 170)
        self.vitals["temp"] = clamp(self.vitals["temp"] + stress * 0.15 - modifiers.get("temp", 0), 35.5, 41.5)
        self.vitals["rr"] = clamp(self.vitals["rr"] + stress * 4 - modifiers.get("rr", 0), 10, 48)

        severity_drift = modifiers.get("severity", 0) + modifiers.get("severity_shift", 0)
        self.severity = clamp(self.severity + severity_drift, 0.05, 1.5)

        gain = 0.015 + modifiers.get("recovery", 0) - self.severity * 0.01
        self.recovery_progress = clamp(self.recovery_progress + gain, 0, 1.5)
        if self.recovery_progress >= 1 and self.vitals["spo2"] >= 93:
            self.discharged = True
            return "recovered"

        if self._should_deteriorate(modifiers):
            self.severity = clamp(self.severity + 0.08, 0.05, 1.7)
            self.vitals["spo2"] = clamp(self.vitals["spo2"] - 4, 50, 100)

        if self._should_die():
            self.alive = False
            self.discharged = True
            return "died"

        shedding = modifiers.get("shedding", 0) + modifiers.get("shedding_modifier", 0)
        self.infectivity = clamp(self.base_infectivity + shedding, 0, 1)
        return None

    def _should_deteriorate(self, modifiers: Dict[str, float]) -> bool:
        vitals = self.vitals
        risk = 0.0
        if vitals["spo2"] < 85:
            risk += 0.08
        if vitals["temp"] > 39.5:
            risk += 0.03
        if vitals["rr"] > 35:
            risk += 0.04
        if vitals["bp"] < 90:
            risk += 0.02
        if self.on_ventilator:
            risk += 0.06
        risk -= modifiers.get("stabilization", 0)
        risk += self.severity * 0.02
        return random.random() < max(0.0, risk)

    def _should_die(self) -> bool:
        vitals = self.vitals
        risk = 0.0
        if vitals["spo2"] < 78:
            risk += 0.25
        if vitals["temp"] > 40.2:
            risk += 0.12
        if vitals["bp"] < 85:
            risk += 0.1
        if self.severity > 0.85:
            risk += 0.1
        if self.on_ventilator:
            risk += 0.05
        return random.random() < min(0.95, risk)

    def reveal_status(self) -> None:
        self.tested = True
        self.covid_status = self.actual_covid_status

    def set_ward(self, ward: str) -> None:
        self.ward = ward
        self.add_note(f"Moved to {ward.title()} ward")
