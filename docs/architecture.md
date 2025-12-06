## Modules
- **main.lua**: Bootstraps Love2D callbacks, owns global game state, orchestrates update/draw loop, manages tab navigation, and relays input to UI/hospital.
- **patients.lua**: Factory helpers for generating randomized patients, updating vitals and disease progression, tracking ward assignment, testing status, risk factors, treatment plans, and recovery/death timers.
- **treatments.lua**: Defines treatment catalog, resource costs, eligibility, and effect modifiers for recovery odds, viral shedding, and resource consumption.
- **supply.lua**: Tracks consumable inventories (tests, PPE, meds, vaccines), handles purchase orders with delivery timers/costs, and provides convenience getters for UI display.
- **hospital.lua**: Central simulation manager that keeps roster of patients per ward, bed/ventilator capacity, staff counts, finances, policies, upgrades, clocks, random event scheduler, infection spread model, and scoring/end-state detection.
- **ui.lua**: Renders dashboards, patient cards, treatment controls, supply tab, and policy/upgrade menus using primitive shapes/text; translates simple mouse interactions into commands for `hospital`.

## Core Systems
- **Timekeeping**: `hospital` tracks float hours and derives day count; per-hour tick drives arrivals, treatments, infection calculations, deliveries, and random events.
- **Patient Flow**: New patients spawn with randomized vitals/risk; players can test (decrementing test stock) and admit to general vs isolation. Vitals drift based on disease severity and assigned treatments.
- **Resource Economy**: Beds, ventilators, PPE, meds, vaccines, funds pulled from `hospital`+`supply`; upgrades modify caps and infection modifiers.
- **Infection Model**: Each hour, compute ward probability using density, infectivity, and policy modifiers; apply to general ward patients and staff pools.
- **Random Events**: Scheduled via `hospital` to trigger surges, staff sickness, supply delays, or viral mutations affecting infectivity.
- **End Conditions & Scoring**: `hospital` monitors casualties, bed/staff availability, and elapsed days to finalize score metrics reported on UI when finished.
