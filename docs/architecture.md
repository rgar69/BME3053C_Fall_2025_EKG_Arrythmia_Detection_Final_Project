## Overview

The Love2D Lua prototype has been replaced with a Python + Streamlit stack. Simulation logic lives in a pure-Python package (`game_modules`) so that UI layers (Streamlit today, potentially other toolkits later) can call a simple API.

## Modules
- **app.py**: Streamlit entry point. Creates dashboards/tabs, wires interactive controls to the simulation API, and renders metrics, tables, and logs.
- **game_modules/__init__.py**: Convenience exports so `from game_modules import Hospital` works without exposing the internal layout.
- **game_modules/modules/infections.py**: Catalog of pathogen profiles (COVID, influenza, strep, adenovirus), weighted sampling, clinical note templates, and reference-table helpers exposed to the UI.
- **game_modules/modules/patients.py**: Patient dataclass plus helpers to generate vitals, symptoms, and disease trajectories. Encapsulates per-hour deterioration, recovery checks, and treatment modifiers.
- **game_modules/modules/treatments.py**: Static catalog describing each treatment's label, description, resource costs, and mechanical effects (spo2 bump, severity drift, shedding reduction, etc.).
- **game_modules/modules/supplies.py**: Handles consumable inventories, purchase orders with ETA timers, vaccine drives, and delivery delays triggered by events.
- **game_modules/modules/hospital.py**: Core state machine. Owns the master patient list, bed/ventilator capacity, finances, policies, upgrades, infection model, random event system, and scoring.

## Core Systems
- **Timekeeping**: `Hospital.advance_hours()` iterates hour-by-hour. Each hour triggers supply updates, patient vitals ticks, infections, random events, and end-condition checks. Daily snapshots feed historical charts.
- **Patient Flow**: `_maybe_spawn_patients()` injects new arrivals with randomized severity, vitals, and pathogen types. Actions such as `run_test`, `order_infection_panel`, `admit_patient`, and `toggle_treatment` mutate patient state while enforcing capacity (COVID isolation requires a positive test) and resource limits.
- **Treatment Effects**: Each patient aggregates modifiers from active treatments plus contextual effects (e.g., virus severity events). These modifiers drive vitals drift, recovery progress, and infectiousness every tick.
- **Resource Economy**: Supplies are decremented via treatment activation and testing. `SupplyChain` processes purchase orders over time and can be delayed by events. Upgrades adjust bed/ventilator caps and grant bonuses (rapid tests, extra stock).
- **Infection Model**: Calculates a risk score based on patient density, active infection load, and policy multipliers. Applies hospital-acquired infections to negatives in general wards and can sideline staff.
- **Random Events**: Every 6–12 hours a surge, logistics delay, staff illness wave, or virus mutation modifies modifiers/stock to keep runs dynamic.
- **End Conditions & Scoring**: Monitors staff availability, bed saturation, fatalities, and elapsed days. When triggered, freezes the simulation, computes a score (recoveries vs deaths/staff loss/infection risk), and surfaces the reason in the UI.

## UI Flow

1. **Sidebar controls** call `advance_hours` or reset the simulation stored in Streamlit `session_state`.
2. **Tabs** issue actions (testing, admissions, treatments, policies, supply orders) via helper callbacks that display success/warning banners and rerun the script.
3. **Data presentation** relies on pandas DataFrames for tables (patient roster, diagnostic reference board, supply orders) and Streamlit charts for trend lines.
4. **Diagnostics reference** tab surfaces the infection catalog so players can compare signature symptoms/vitals before expending scarce tests.
5. **Messages** originate from `Hospital.enqueue_message` and are rendered verbatim so backend events remain visible to the player.
