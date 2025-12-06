from __future__ import annotations

import random
from typing import Dict, List, Optional, Tuple

InfectionProfile = Dict[str, object]


INFECTION_PROFILES: Dict[str, InfectionProfile] = {
    "covid": {
        "label": "COVID-19 / SARS-CoV-2",
        "pathogen_type": "Viral",
        "quarantine": True,
        "weight": 0.55,
        "common_symptoms": ["dry cough", "loss of smell", "fatigue", "shortness of breath"],
        "thresholds": {"Temp": ">= 38.0°C", "SpO2": "<= 93%", "RR": ">= 24/min"},
        "infectivity": 0.65,
        "symptom_bias": {"fever": 0.15, "shortness": 0.25, "fatigue": 0.15},
        "notes": [
            "Patient reports scratchy pharyngeal irritation that intensified overnight despite negative streptococcal history.",
            "Patient notes abrupt anosmia with patent nasal passages and minimal congestion.",
            "Patient experiences low-grade pyrexia with disproportionate exertional dyspnea during minimal ambulation.",
            "Patient endorses substernal tightness on inspiration without sputum production.",
        ],
    },
    "influenza": {
        "label": "Seasonal Influenza",
        "pathogen_type": "Viral",
        "quarantine": False,
        "weight": 0.2,
        "common_symptoms": ["high fever", "body aches", "productive cough"],
        "thresholds": {"Temp": "38.5-40.0°C", "SpO2": ">= 95%", "RR": "18-26/min"},
        "infectivity": 0.35,
        "symptom_bias": {"fever": 0.3, "fatigue": 0.1, "cough": 0.15},
        "notes": [
            "Patient describes diffuse myalgias with abrupt onset earlier in the day.",
            "Patient demonstrates febrile spikes yet maintains acceptable oxygen saturation.",
            "Patient reports thick green sputum production with nocturnal exacerbation.",
        ],
    },
    "strep": {
        "label": "Strep Throat",
        "pathogen_type": "Bacterial",
        "quarantine": False,
        "weight": 0.15,
        "common_symptoms": ["severe sore throat", "swollen nodes", "low-grade fever"],
        "thresholds": {"Temp": "37.8-38.5°C", "SpO2": ">= 96%", "RR": "16-22/min"},
        "infectivity": 0.2,
        "symptom_bias": {"sore_throat": 0.4, "fever": -0.05},
        "notes": [
            "Patient reports severe razor-like odynophagia with minimal cough.",
            "Patient presents with tender cervical lymphadenopathy and only mild pyrexia.",
            "Patient tolerates liquids exclusively and denies anosmia or ageusia.",
        ],
    },
    "adenovirus": {
        "label": "Adenovirus / RSV mix",
        "pathogen_type": "Viral",
        "quarantine": False,
        "weight": 0.1,
        "common_symptoms": ["runny nose", "wheezing", "low oxygen dips"],
        "thresholds": {"Temp": "<= 38.0°C", "SpO2": "92-95%", "RR": ">= 22/min"},
        "infectivity": 0.4,
        "symptom_bias": {"shortness": 0.2, "cough": 0.1},
        "notes": [
            "Patient demonstrates audible expiratory wheeze with low-grade fever.",
            "Patient reports viscous nasal congestion while appetite remains intact.",
            "Patient experiences transient desaturations to 93% in supine position with rapid recovery when upright.",
        ],
    },
}

_PROFILE_KEYS: Tuple[str, ...] = tuple(INFECTION_PROFILES.keys())
_PROFILE_WEIGHTS: Tuple[float, ...] = tuple(profile["weight"] for profile in INFECTION_PROFILES.values())


def choose_infection_profile(rng: Optional[random.Random] = None) -> Tuple[str, InfectionProfile]:
    picker = rng or random
    key = picker.choices(_PROFILE_KEYS, weights=_PROFILE_WEIGHTS, k=1)[0]
    return key, INFECTION_PROFILES[key]


def build_clinical_notes(key: str, rng: Optional[random.Random] = None) -> List[str]:
    profile = INFECTION_PROFILES[key]
    picker = rng or random
    samples = profile["notes"]
    if len(samples) <= 2:
        return list(samples)
    return picker.sample(samples, 2)


def get_reference_rows() -> List[Dict[str, str]]:
    rows: List[Dict[str, str]] = []
    for key, profile in INFECTION_PROFILES.items():
        rows.append(
            {
                "Pathogen": profile["label"],
                "Type": profile["pathogen_type"],
                "Quarantine?": "Yes" if profile["quarantine"] else "No",
                "Signature Symptoms": ", ".join(profile["common_symptoms"]),
                "Vital Clues": ", ".join(f"{metric}: {value}" for metric, value in profile["thresholds"].items()),
                "Chief Subjective Complaints": "; ".join(profile["notes"][:2]),
            }
        )
    return rows