from __future__ import annotations

import math
import random
import time
from collections import deque
from typing import Dict, List, Optional, Tuple

from .patients import Patient
from .supplies import ORDER_CATALOG, SupplyChain
from .treatments import TREATMENTS


def _clone_catalog(catalog: Dict[str, Dict[str, object]], *, flag: str) -> Dict[str, Dict[str, object]]:
    cloned: Dict[str, Dict[str, object]] = {}
    for key, data in catalog.items():
        cloned[key] = dict(data)
        cloned[key][flag] = False
    return cloned


POLICY_CATALOG = {
    "mask": {"label": "Mask Mandate", "cost": 2500, "modifier": 0.7, "description": "Reduces airborne spread across all wards."},
    "visitors": {"label": "Visitor Lockdown", "cost": 1800, "modifier": 0.85, "description": "Limits outside exposure and admissions."},
    "isolation": {"label": "Isolation Retrofit", "cost": 4200, "modifier": 0.6, "description": "Improves airflow and sealing in isolation unit."},
}

UPGRADE_CATALOG = {
    "beds": {"label": "Expand Ward", "cost": 5000, "effect": "Adds 4 general and 2 isolation beds."},
    "vents": {"label": "Ventilator Cache", "cost": 4000, "effect": "Adds 2 ventilators."},
    "rapid": {"label": "Rapid Diagnostics", "cost": 3500, "effect": "Adds 6 tests and lowers arrival severity."},
}


class Hospital:
    def __init__(self) -> None:
        self.reset()

    def reset(self, *, seed: Optional[int] = None) -> None:
        self.seed = seed or int(time.time())
        random.seed(self.seed)
        self.clock = {"hour": 0, "day": 1}
        self.patient_id = 1
        self.patients: List[Patient] = []
        self.capacity = {"general": 12, "isolation": 8, "ventilators": 4}
        self.resources = {"vents_available": 4, "staff": 24, "staff_sick": 0}
        self.finance = {"money": 0, "score": 0}
        self.supply = SupplyChain()
        self.policies = _clone_catalog(POLICY_CATALOG, flag="active")
        self.upgrades = _clone_catalog(UPGRADE_CATALOG, flag="purchased")
        self.stats = {"deaths": 0, "discharges": 0, "infections": 0, "staff_losses": 0}
        self.history = {"infections": [], "deaths": [], "recoveries": []}
        self.message_log: deque[str] = deque(maxlen=18)
        self.modifiers = {"surge_hours": 0, "virus_severity": 0, "infection_boost": 0}
        self.current_infection_risk = 0.0
        self.random_event_timer = 6
        self.end_condition: Optional[str] = None
        self.enqueue_message("Hospital control dashboard initialized.")

    # ------------------------------------------------------------------
    # Core simulation loop
    # ------------------------------------------------------------------
    def advance_hours(self, hours: int = 1) -> None:
        for _ in range(hours):
            if self.end_condition:
                break
            self._advance_one_hour()

    def _advance_one_hour(self) -> None:
        self.clock["hour"] += 1
        if self.clock["hour"] % 24 == 0:
            self.clock["day"] += 1
            self._record_daily_snapshot()

        self.supply.update(1)
        self._maybe_spawn_patients()
        self._update_patients()
        self._simulate_infections()
        self._trigger_random_event()
        self._check_end_conditions()

    # ------------------------------------------------------------------
    # Patient flow
    # ------------------------------------------------------------------
    def _maybe_spawn_patients(self) -> None:
        surge_bonus = 0.35 if self.modifiers["surge_hours"] > 0 else 0
        if self.modifiers["surge_hours"] > 0:
            self.modifiers["surge_hours"] -= 1
        chance = 0.35 + surge_bonus
        if random.random() < chance:
            arrivals = 2 if random.random() < 0.25 else 1
            for _ in range(arrivals):
                self._add_incoming_patient()

    def _add_incoming_patient(self) -> None:
        patient = Patient.create(self.patient_id, self.clock["hour"])
        if self.upgrades["rapid"]["purchased"]:
            patient.severity = max(0.1, patient.severity - 0.1)
            self.supply.stock["tests"] += 1
        self.patient_id += 1
        self.patients.append(patient)
        self.enqueue_message(f"{patient.name} awaiting triage")

    def _update_patients(self) -> None:
        for patient in self.patients:
            if not patient.alive or patient.discharged:
                continue
            context = {
                "severity_shift": self.modifiers["virus_severity"],
                "shedding_modifier": -0.05 if patient.ward == "isolation" else 0,
            }
            outcome = patient.tick(context)
            if outcome == "recovered":
                self._discharge_patient(patient)
            elif outcome == "died":
                self._register_death(patient)

    def _discharge_patient(self, patient: Patient) -> None:
        self._release_ventilator(patient)
        patient.ward = "discharged"
        self.stats["discharges"] += 1
        self.finance["money"] += 1000
        self.enqueue_message(f"{patient.name} recovered and discharged")

    def _register_death(self, patient: Patient) -> None:
        self._release_ventilator(patient)
        patient.ward = "morgue"
        self.stats["deaths"] += 1
        self.enqueue_message(f"{patient.name} died from complications")

    def _release_ventilator(self, patient: Patient) -> None:
        if patient.treatments.get("ventilator"):
            patient.treatments["ventilator"] = False
            self.resources["vents_available"] = min(
                self.capacity["ventilators"], self.resources["vents_available"] + 1
            )

    # ------------------------------------------------------------------
    # Infection model and random events
    # ------------------------------------------------------------------
    def _simulate_infections(self) -> None:
        general_count = 0
        infectious_load = 0.0
        for patient in self.patients:
            if patient.ward == "general" and patient.alive and not patient.discharged:
                general_count += 1
                if patient.actual_covid_status == "positive":
                    infectious_load += patient.infectivity
        if general_count == 0:
            self.current_infection_risk = 0.0
            return

        density = general_count / max(1, self.capacity["general"])
        base_risk = infectious_load * 0.08 + density * 0.05 + self.modifiers["infection_boost"]
        policy_modifier = 1.0
        for policy in self.policies.values():
            if policy.get("active"):
                policy_modifier *= policy["modifier"]
        self.current_infection_risk = max(0.0, base_risk * policy_modifier)

        for patient in self.patients:
            if patient.ward == "general" and patient.actual_covid_status == "negative" and patient.alive and not patient.discharged:
                if random.random() < self.current_infection_risk:
                    patient.actual_covid_status = "positive"
                    if patient.tested:
                        patient.covid_status = "positive"
                    patient.base_infectivity = min(1.0, patient.base_infectivity + 0.1)
                    self.stats["infections"] += 1
                    patient.add_note("Likely hospital-acquired infection")

        staff_risk = min(0.3, self.current_infection_risk * (general_count / max(1, self.resources["staff"])))
        if random.random() < staff_risk:
            self.resources["staff"] = max(0, self.resources["staff"] - 1)
            self.resources["staff_sick"] += 1
            self.stats["staff_losses"] += 1
            self.enqueue_message("Staff member infected and off shift")

    def _trigger_random_event(self) -> None:
        self.random_event_timer -= 1
        if self.random_event_timer > 0:
            return
        self.random_event_timer = 6 + random.randint(0, 6)
        roll = random.random()
        if roll < 0.25:
            self.modifiers["surge_hours"] += 6
            self.enqueue_message("Random Event: Community outbreak surge")
        elif roll < 0.5:
            self.supply.delay_orders(4)
            self.enqueue_message("Random Event: Logistics delay slows deliveries")
        elif roll < 0.7:
            loss = min(2, self.resources["staff"])
            self.resources["staff"] -= loss
            self.resources["staff_sick"] += loss
            self.stats["staff_losses"] += loss
            self.enqueue_message("Random Event: Staff illness wave")
        else:
            self.modifiers["virus_severity"] += 0.01
            self.modifiers["infection_boost"] += 0.02
            self.enqueue_message("Random Event: Virus mutation increases severity")

    # ------------------------------------------------------------------
    # Player actions
    # ------------------------------------------------------------------
    def run_test(self, patient_id: int) -> Tuple[bool, str]:
        patient = self.get_patient(patient_id)
        if not patient or not patient.alive or patient.discharged:
            return False, "Patient unavailable"
        if patient.tested:
            return False, "Patient already tested"
        if not self.supply.consume("tests", 1):
            return False, "No test kits available"
        patient.reveal_status()
        if patient.covid_status == "positive":
            self.enqueue_message(f"COVID confirmed for {patient.name}")
            return True, "COVID test positive"
        self.enqueue_message(f"COVID ruled out for {patient.name}. Check diagnostic board.")
        return True, "COVID test negative"

    def order_infection_panel(self, patient_id: int) -> Tuple[bool, str]:
        patient = self.get_patient(patient_id)
        if not patient or not patient.alive or patient.discharged:
            return False, "Patient unavailable"
        if patient.diagnosis_known:
            return False, "Diagnosis already confirmed"
        if not self.supply.consume("tests", 1):
            return False, "No lab kits available"
        patient.diagnosis_known = True
        patient.add_note(f"Diagnosis confirmed: {patient.infection_label}")
        self.enqueue_message(f"Panel ID'd {patient.infection_label} in {patient.name}")
        return True, f"Panel confirms {patient.infection_label}"

    def admit_patient(self, patient_id: int, ward: str) -> Tuple[bool, str]:
        patient = self.get_patient(patient_id)
        if not patient or not patient.alive or patient.discharged:
            return False, "Patient unavailable"
        if ward not in {"general", "isolation"}:
            return False, "Unknown ward"
        if patient.ward == ward:
            return False, "Already in ward"
        general, isolation = self.get_ward_usage()
        if ward == "general" and general >= self.capacity["general"]:
            return False, "General ward full"
        if ward == "isolation" and isolation >= self.capacity["isolation"]:
            return False, "Isolation ward full"
        if ward == "isolation" and patient.covid_status != "positive":
            return False, "Need confirmed COVID result before isolating"
        patient.set_ward(ward)
        return True, f"{patient.name} moved to {ward}"

    def toggle_treatment(self, patient_id: int, key: str) -> Tuple[bool, str]:
        patient = self.get_patient(patient_id)
        if not patient or not patient.alive or patient.discharged:
            return False, "Patient unavailable"
        treatment = TREATMENTS.get(key)
        if not treatment:
            return False, "Unknown treatment"

        if patient.treatments.get(key):
            patient.treatments[key] = False
            if treatment.resource_cost.get("ventilator"):
                self.resources["vents_available"] = min(
                    self.capacity["ventilators"], self.resources["vents_available"] + 1
                )
            return True, f"Stopped {treatment.label}"

        if treatment.resource_cost.get("ventilator"):
            if self.resources["vents_available"] <= 0:
                return False, "No ventilators available"
            self.resources["vents_available"] -= 1
        for item, qty in treatment.resource_cost.items():
            if item == "ventilator":
                continue
            if not self.supply.consume(item, qty):
                return False, f"Need more {item.upper()}"
        patient.treatments[key] = True
        patient.add_note(f"Started {treatment.label}")
        return True, f"{treatment.label} applied"

    def order_supply(self, item: str) -> Tuple[bool, str]:
        template = ORDER_CATALOG.get(item)
        if not template:
            return False, "Unknown supply"
        if self.finance["money"] < template["cost"]:
            return False, "Insufficient funds"
        order = self.supply.place_order(item)
        if not order:
            return False, "Order failed"
        self.finance["money"] -= template["cost"]
        self.enqueue_message(f"Ordered {template['label']} (arrives in {template['eta']}h)")
        return True, "Order placed"

    def toggle_policy(self, key: str) -> Tuple[bool, str]:
        policy = self.policies.get(key)
        if not policy:
            return False, "Unknown policy"
        if policy.get("active"):
            return False, "Policy already active"
        if self.finance["money"] < policy["cost"]:
            return False, "Insufficient funds"
        self.finance["money"] -= policy["cost"]
        policy["active"] = True
        self.enqueue_message(f"Policy enacted: {policy['label']}")
        return True, "Policy enabled"

    def buy_upgrade(self, key: str) -> Tuple[bool, str]:
        upgrade = self.upgrades.get(key)
        if not upgrade:
            return False, "Unknown upgrade"
        if upgrade.get("purchased"):
            return False, "Already purchased"
        if self.finance["money"] < upgrade["cost"]:
            return False, "Insufficient funds"
        self.finance["money"] -= upgrade["cost"]
        upgrade["purchased"] = True
        if key == "beds":
            self.capacity["general"] += 4
            self.capacity["isolation"] += 2
        elif key == "vents":
            self.capacity["ventilators"] += 2
            self.resources["vents_available"] += 2
        elif key == "rapid":
            self.supply.stock["tests"] += 6
        self.enqueue_message(f"Upgrade purchased: {upgrade['label']}")
        return True, "Upgrade purchased"

    def deploy_vaccination(self) -> Tuple[bool, str]:
        if not self.supply.consume("vaccines", 2):
            return False, "Need at least 2 vaccine vials"
        self.modifiers["infection_boost"] = max(0, self.modifiers["infection_boost"] - 0.02)
        self.enqueue_message("Vaccination drive shields staff and patients")
        return True, "Vaccination deployed"

    # ------------------------------------------------------------------
    # Reporting helpers
    # ------------------------------------------------------------------
    def get_patient(self, patient_id: int) -> Optional[Patient]:
        return next((p for p in self.patients if p.id == patient_id), None)

    def get_active_patients(self) -> List[Patient]:
        active = [p for p in self.patients if p.alive and not p.discharged]
        active.sort(key=lambda p: p.id)
        return active

    def get_ward_usage(self) -> Tuple[int, int]:
        general = sum(1 for p in self.patients if p.ward == "general" and p.alive and not p.discharged)
        isolation = sum(1 for p in self.patients if p.ward == "isolation" and p.alive and not p.discharged)
        return general, isolation

    def summary(self) -> Dict[str, object]:
        general, isolation = self.get_ward_usage()
        return {
            "day": self.clock["day"],
            "hour": self.clock["hour"] % 24,
            "general": {"used": general, "capacity": self.capacity["general"]},
            "isolation": {"used": isolation, "capacity": self.capacity["isolation"]},
            "vents": {"free": self.resources["vents_available"], "total": self.capacity["ventilators"]},
            "staff": self.resources,
            "stats": self.stats,
            "money": self.finance["money"],
            "infection_risk": getattr(self, "current_infection_risk", 0.0),
            "policies": self.policies,
            "upgrades": self.upgrades,
            "supplies": self.supply.summary(),
            "messages": list(self.message_log),
            "end_condition": self.end_condition,
            "score": self.finance["score"],
            "history": self.history,
        }

    def _record_daily_snapshot(self) -> None:
        self.history["infections"].append(self.stats["infections"])
        self.history["deaths"].append(self.stats["deaths"])
        self.history["recoveries"].append(self.stats["discharges"])

    def enqueue_message(self, text: str) -> None:
        timestamp = f"{self.clock['hour'] % 24:02d}:00"
        self.message_log.appendleft(f"{timestamp}: {text}")

    def _check_end_conditions(self) -> None:
        general, isolation = self.get_ward_usage()
        if self.resources["staff"] <= 2:
            self._end_game("Staff exhausted. Hospital forced to close.")
        elif self.stats["deaths"] >= 12:
            self._end_game("Fatalities exceeded safety threshold.")
        elif general >= self.capacity["general"] and isolation >= self.capacity["isolation"]:
            self._end_game("All beds occupied. Unable to admit new patients.")
        elif self.clock["day"] > 30:
            self._end_game("Simulation complete. 30 days passed.")

    def _end_game(self, reason: str) -> None:
        if self.end_condition:
            return
        self.end_condition = reason
        self.finance["score"] = self._calculate_score()
        self.enqueue_message(reason)

    def _calculate_score(self) -> int:
        score = self.stats["discharges"] * 5
        score -= self.stats["deaths"] * 7
        score -= self.stats["staff_losses"] * 3
        score += math.floor(self.finance["money"] / 500)
        score -= math.floor(getattr(self, "current_infection_risk", 0) * 100)
        return score
