local Treatments = {}

local catalog = {
    oxygen = {
        key = "oxygen",
        label = "Oxygen Therapy",
        description = "Improves SpO2 and reduces respiratory distress.",
        resourceCost = { ppe = 1 },
        effects = { spo2 = 3, recovery = 0.02, rr = 2, shedding = -0.04, stabilization = 0.02, stress = 0.08 },
        price = 200
    },
    antivirals = {
        key = "antivirals",
        label = "Antivirals",
        description = "Broad antiviral course to shorten illness length.",
        resourceCost = { meds = 1 },
        effects = { recovery = 0.04, severity = -0.02, shedding = -0.05, stress = 0.05 },
        price = 600
    },
    steroids = {
        key = "steroids",
        label = "Steroids",
        description = "Anti-inflammatory steroids to calm immune response.",
        resourceCost = { meds = 1 },
        effects = { temp = 0.8, severity = -0.015, stabilization = 0.03, stress = 0.06 },
        price = 450
    },
    ventilator = {
        key = "ventilator",
        label = "Ventilator",
        description = "Mechanical ventilation for critical support.",
        resourceCost = { ventilator = 1, ppe = 1 },
        effects = { spo2 = 5, recovery = 0.03, severity = -0.03, vent = true, stabilization = 0.05, stress = 0.2 },
        price = 0
    }
}

function Treatments.getCatalog()
    return catalog
end

function Treatments.get(key)
    return catalog[key]
end

function Treatments.aggregate(patient)
    local modifiers = {
        spo2Boost = 0,
        rrReduction = 0,
        tempReduction = 0,
        recoveryBoost = 0,
        sheddingModifier = 0,
        severityShift = 0,
        stabilization = 0,
        bpSupport = 0,
        hrReduction = 0,
        stressReduction = 0,
        ventSupport = false
    }
    if not patient.treatments then
        return modifiers
    end

    for key, state in pairs(patient.treatments) do
        if state then
            local entry = catalog[key]
            if entry then
                modifiers.spo2Boost = modifiers.spo2Boost + (entry.effects.spo2 or 0)
                modifiers.rrReduction = modifiers.rrReduction + (entry.effects.rr or 0)
                modifiers.tempReduction = modifiers.tempReduction + (entry.effects.temp or 0)
                modifiers.recoveryBoost = modifiers.recoveryBoost + (entry.effects.recovery or 0)
                modifiers.sheddingModifier = modifiers.sheddingModifier + (entry.effects.shedding or 0)
                modifiers.severityShift = modifiers.severityShift + (entry.effects.severity or 0)
                modifiers.stabilization = modifiers.stabilization + (entry.effects.stabilization or 0)
                modifiers.bpSupport = modifiers.bpSupport + (entry.effects.bp or 0)
                modifiers.hrReduction = modifiers.hrReduction + (entry.effects.hr or 0)
                modifiers.stressReduction = modifiers.stressReduction + (entry.effects.stress or 0)
                if entry.effects.vent then
                    modifiers.ventSupport = true
                end
            end
        end
    end
    return modifiers
end

return Treatments
