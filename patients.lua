local Patients = {}

local COMORBIDITIES = {
    "Hypertension",
    "Diabetes",
    "Asthma",
    "Obesity",
    "Cardiac Disease",
    "Kidney Disease"
}

local SYMPTOMS = { "Fever", "Cough", "Fatigue", "Short Breath" }

local function pick(list)
    return list[math.random(1, #list)]
end

local function randomBool(prob)
    return math.random() < prob
end

local function clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

local function generateVitals(severity)
    return {
        hr = math.floor(75 + severity * 40 + math.random(-5, 12)),
        spo2 = clamp(math.floor(97 - severity * 20 + math.random(-4, 3)), 70, 100),
        bp = math.floor(120 - severity * 15 + math.random(-5, 8)),
        temp = 36.8 + severity * 2 + math.random() * 0.8,
        rr = math.floor(16 + severity * 12 + math.random(-2, 5))
    }
end

local function randomSymptoms(severity)
    local flags = {}
    for _, symptom in ipairs(SYMPTOMS) do
        flags[symptom] = randomBool(0.35 + severity * 0.35)
    end
    return flags
end

function Patients.create(id, currentHour)
    local severity = math.random() * 0.8 + 0.2
    local covidPositive = randomBool(0.65)
    local patient = {
        id = id,
        name = string.format("Patient %03d", id),
        admittedHour = currentHour,
        vitals = generateVitals(severity),
        symptoms = randomSymptoms(severity),
        risk = {
            age = math.random(22, 90),
            comorbidity = pick(COMORBIDITIES)
        },
        treatments = {},
        actualCovidStatus = covidPositive and "positive" or "negative",
        covidStatus = "unknown",
        infectivity = covidPositive and (0.25 + severity * 0.5) or 0.05,
        baseInfectivity = covidPositive and (0.25 + severity * 0.5) or 0.05,
        ward = "triage",
        tested = false,
        hoursInHospital = 0,
        recoveryProgress = math.random() * 0.15,
        severity = severity,
        alive = true,
        discharged = false,
        onVentilator = false,
        notes = {}
    }
    return patient
end

local function updateVitals(patient, modifiers)
    local vitals = patient.vitals
    local severity = patient.severity
    local stress = severity * 0.4 - (modifiers.stressReduction or 0)

    vitals.spo2 = clamp(vitals.spo2 - stress * 2 + (modifiers.spo2Boost or 0), 60, 100)
    vitals.hr = clamp(vitals.hr + stress * 5 - (modifiers.hrReduction or 0), 45, 160)
    vitals.bp = clamp(vitals.bp - stress * 3 + (modifiers.bpSupport or 0), 80, 160)
    vitals.temp = clamp(vitals.temp + stress * 0.15 - (modifiers.tempReduction or 0), 35.5, 41)
    vitals.rr = clamp(vitals.rr + stress * 4 - (modifiers.rrReduction or 0), 10, 45)
end

local function updateRecovery(patient, modifiers)
    local gain = 0.015 + (modifiers.recoveryBoost or 0)
    gain = gain - patient.severity * 0.01
    patient.recoveryProgress = clamp(patient.recoveryProgress + gain, 0, 1.2)
    if patient.recoveryProgress >= 1 then
        return true
    end
    return false
end

local function checkForDeterioration(patient, modifiers)
    local vitals = patient.vitals
    local risk = 0
    if vitals.spo2 < 85 then risk = risk + 0.08 end
    if vitals.temp > 39.5 then risk = risk + 0.03 end
    if vitals.rr > 35 then risk = risk + 0.04 end
    if vitals.bp < 90 then risk = risk + 0.02 end
    if patient.onVentilator then risk = risk + 0.06 end
    risk = risk - (modifiers.stabilization or 0)
    risk = risk + patient.severity * 0.02
    if math.random() < math.max(0, risk) then
        return true
    end
    return false
end

local function checkForDeath(patient)
    local vitals = patient.vitals
    local risk = 0
    if vitals.spo2 < 78 then risk = risk + 0.25 end
    if vitals.temp > 40.2 then risk = risk + 0.12 end
    if vitals.bp < 85 then risk = risk + 0.1 end
    if patient.severity > 0.85 then risk = risk + 0.1 end
    if patient.onVentilator then risk = risk + 0.05 end
    if math.random() < math.min(0.95, risk) then
        return true
    end
    return false
end

function Patients.update(patient, hours, modifiers)
    modifiers = modifiers or {}
    if not patient.alive or patient.discharged then
        return nil
    end

    patient.hoursInHospital = patient.hoursInHospital + hours
    updateVitals(patient, modifiers)

    if modifiers.ventSupport then
        patient.onVentilator = true
    else
        patient.onVentilator = false
    end

    patient.severity = clamp(patient.severity + (modifiers.severityShift or 0) * hours, 0.05, 1.2)

    local recovered = updateRecovery(patient, modifiers)
    if recovered and patient.vitals.spo2 >= 93 then
        patient.discharged = true
        return "recovered"
    end

    if checkForDeterioration(patient, modifiers) then
        patient.severity = clamp(patient.severity + 0.08, 0, 1.5)
        patient.vitals.spo2 = clamp(patient.vitals.spo2 - 4, 50, 100)
    end

    if checkForDeath(patient) then
        patient.alive = false
        patient.discharged = true
        return "died"
    end

    patient.infectivity = clamp(patient.baseInfectivity + (modifiers.sheddingModifier or 0), 0, 1)
    return nil
end

function Patients.revealStatus(patient)
    patient.tested = true
    patient.covidStatus = patient.actualCovidStatus
end

function Patients.setWard(patient, ward)
    patient.ward = ward or "triage"
end

function Patients.addNote(patient, text)
    table.insert(patient.notes, 1, string.format("%s", text))
    if #patient.notes > 4 then
        table.remove(patient.notes)
    end
end

return Patients
