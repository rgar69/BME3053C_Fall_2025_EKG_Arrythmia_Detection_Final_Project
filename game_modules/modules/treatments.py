from __future__ import annotations

from dataclasses import dataclass
from typing import Dict


@dataclass(frozen=True)
class Treatment:
    key: str
    label: str
    description: str
    resource_cost: Dict[str, int]
    effects: Dict[str, float]


TREATMENTS: Dict[str, Treatment] = {
    "oxygen": Treatment(
        key="oxygen",
        label="Oxygen Therapy",
        description="Supplemental oxygen to stabilize respiration and improve saturation.",
        resource_cost={"ppe": 1},
        effects={
            "spo2": 3,
            "recovery": 0.02,
            "rr": 2,
            "shedding": -0.04,
            "stabilization": 0.02,
            "stress": 0.08,
        },
    ),
    "antivirals": Treatment(
        key="antivirals",
        label="Antivirals",
        description="Antiviral course that shortens disease duration and reduces viral load.",
        resource_cost={"meds": 1},
        effects={
            "recovery": 0.04,
            "severity": -0.02,
            "shedding": -0.05,
            "stress": 0.05,
        },
    ),
    "steroids": Treatment(
        key="steroids",
        label="Steroids",
        description="Steroid taper to calm inflammatory response and bring down fever.",
        resource_cost={"meds": 1},
        effects={
            "temp": 0.8,
            "severity": -0.015,
            "stabilization": 0.03,
            "stress": 0.06,
        },
    ),
    "ventilator": Treatment(
        key="ventilator",
        label="Ventilator",
        description="Mechanical ventilation for critical respiratory failure.",
        resource_cost={"ventilator": 1, "ppe": 1},
        effects={
            "spo2": 5,
            "recovery": 0.03,
            "severity": -0.03,
            "vent": 1,
            "stabilization": 0.05,
            "stress": 0.2,
        },
    ),
}
