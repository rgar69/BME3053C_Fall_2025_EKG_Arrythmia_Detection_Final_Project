local Patients = require("patients")
local Treatments = require("treatments")
local Supply = require("supply")

local Hospital = {}
Hospital.__index = Hospital

local function cloneCatalog(src)
    local dest = {}
    for key, data in pairs(src) do
        dest[key] = {}
        for k, v in pairs(data) do
            dest[key][k] = v
        end
        dest[key].active = false
        dest[key].purchased = false
    end
    return dest
end

local POLICY_CATALOG = {
    mask = { label = "Mask Mandate", cost = 2500, modifier = 0.7, description = "Reduces infection chance hospital-wide." },
    visitors = { label = "Visitor Lockdown", cost = 1800, modifier = 0.85, description = "Limits outside exposure." },
    isolation = { label = "Isolation Retrofit", cost = 4200, modifier = 0.6, description = "Improves isolation airflow." }
}

local UPGRADE_CATALOG = {
    beds = { label = "Expand Ward", cost = 5000, effect = "Adds 4 gen / 2 isolation beds." },
    vents = { label = "Ventilator Cache", cost = 4000, effect = "Adds 2 ventilators." },
    rapid = { label = "Rapid Diagnostics", cost = 3500, effect = "Adds 6 tests and halves arrival severity." }
}

function Hospital.new()
    local self = setmetatable({}, Hospital)
    self:reset(true)
    return self
end

function Hospital:reset(firstLoad)
    if firstLoad then
        math.randomseed(os.time())
    end
    self.clock = {
        hour = 0,
        day = 1,
        accumulator = 0,
        hoursPerSecond = 0.25
    }
    self.patientId = 1
    self.patients = {}
    self.capacity = { general = 12, isolation = 8, ventilators = 4 }
    self.resources = {
        ventsAvailable = self.capacity.ventilators,
        staff = 24,
        staffSick = 0
    }
    self.finance = { money = 50000, score = 0 }
    self.supply = Supply.new()
    self.policies = cloneCatalog(POLICY_CATALOG)
    self.upgrades = cloneCatalog(UPGRADE_CATALOG)
    self.messageLog = { "Hospital shift has started." }
    self.stats = {
        deaths = 0,
        discharges = 0,
        infections = 0,
        staffLosses = 0
    }
    self.history = {
        infections = {},
        deaths = {},
        recoveries = {}
    }
    self.infectionRisk = 0
    self.randomEventTimer = 6
    self.modifiers = {
        surgeHours = 0,
        virusSeverity = 0,
        infectionBoost = 0
    }
    self.endCondition = nil
end

local function summarizeWard(patients, ward)
    local count = 0
    for _, patient in ipairs(patients) do
        if patient.ward == ward and patient.alive and not patient.discharged then
            count = count + 1
        end
    end
    return count
end

function Hospital:getWardUsage()
    return summarizeWard(self.patients, "general"), summarizeWard(self.patients, "isolation")
end

function Hospital:update(dt)
    if self.endCondition then
        return
    end
    self.clock.accumulator = self.clock.accumulator + dt * self.clock.hoursPerSecond
    while self.clock.accumulator >= 1 do
        self.clock.accumulator = self.clock.accumulator - 1
        self:advanceHour()
    end
end

function Hospital:advanceHour()
    self.clock.hour = self.clock.hour + 1
    if self.clock.hour % 24 == 0 then
        self.clock.day = self.clock.day + 1
        self:recordDailySnapshot()
    end

    self.supply:update(1)
    self:maybeSpawnPatients()
    self:updatePatients()
    self:simulateInfectionSpread()
    self:maybeTriggerRandomEvent()
    self:checkEndConditions()
end

function Hospital:maybeSpawnPatients()
    local surgeBonus = self.modifiers.surgeHours > 0 and 0.35 or 0
    if self.modifiers.surgeHours > 0 then
        self.modifiers.surgeHours = self.modifiers.surgeHours - 1
    end
    local chance = 0.35 + surgeBonus
    if math.random() < chance then
        local count = (math.random() < 0.25) and 2 or 1
        for _ = 1, count do
            self:addIncomingPatient()
        end
    end
end

function Hospital:addIncomingPatient()
    local patient = Patients.create(self.patientId, self.clock.hour)
    if self.upgrades.rapid and self.upgrades.rapid.purchased then
        patient.severity = math.max(0.1, patient.severity - 0.1)
    end
    self.patientId = self.patientId + 1
    table.insert(self.patients, patient)
    self:enqueueMessage(string.format("%s awaiting triage", patient.name))
end

function Hospital:updatePatients()
    for _, patient in ipairs(self.patients) do
        if patient.alive and not patient.discharged then
            local mods = Treatments.aggregate(patient)
            if patient.ward == "isolation" then
                mods.sheddingModifier = (mods.sheddingModifier or 0) - 0.05
            end
            mods.severityShift = (mods.severityShift or 0) + self.modifiers.virusSeverity
            local outcome = Patients.update(patient, 1, mods)
            if outcome == "recovered" then
                self:dischargePatient(patient)
            elseif outcome == "died" then
                self:registerDeath(patient)
            end
        end
    end
end

function Hospital:releaseVentilator(patient)
    if patient.treatments and patient.treatments.ventilator then
        patient.treatments.ventilator = false
        self.resources.ventsAvailable = math.min(self.capacity.ventilators, self.resources.ventsAvailable + 1)
    end
end

function Hospital:dischargePatient(patient)
    self:releaseVentilator(patient)
    patient.ward = nil
    self.stats.discharges = self.stats.discharges + 1
    self.finance.money = self.finance.money + 500
    self:enqueueMessage(string.format("%s recovered and discharged.", patient.name))
end

function Hospital:registerDeath(patient)
    self:releaseVentilator(patient)
    patient.ward = nil
    self.stats.deaths = self.stats.deaths + 1
    self:enqueueMessage(string.format("%s died from complications.", patient.name))
end

function Hospital:simulateInfectionSpread()
    local generalCount = 0
    local infectiousLoad = 0
    for _, patient in ipairs(self.patients) do
        if patient.ward == "general" and patient.alive and not patient.discharged then
            generalCount = generalCount + 1
            if patient.actualCovidStatus == "positive" then
                infectiousLoad = infectiousLoad + patient.infectivity
            end
        end
    end
    if generalCount == 0 then
        self.infectionRisk = 0
        return
    end

    local density = generalCount / self.capacity.general
    local baseRisk = infectiousLoad * 0.08 + density * 0.05
    baseRisk = baseRisk + self.modifiers.infectionBoost

    local policyModifier = 1
    for key, policy in pairs(self.policies) do
        if policy.active then
            policyModifier = policyModifier * policy.modifier
        end
    end
    self.infectionRisk = math.max(0, baseRisk * policyModifier)

    for _, patient in ipairs(self.patients) do
        if patient.ward == "general" and patient.actualCovidStatus == "negative" and patient.alive and not patient.discharged then
            if math.random() < self.infectionRisk then
                patient.actualCovidStatus = "positive"
                if patient.tested then
                    patient.covidStatus = "positive"
                end
                patient.baseInfectivity = math.min(1, patient.baseInfectivity + 0.1)
                self.stats.infections = self.stats.infections + 1
                Patients.addNote(patient, "Likely hospital-acquired infection.")
            end
        end
    end

    local staffRisk = math.min(0.3, self.infectionRisk * (generalCount / math.max(1, self.resources.staff)))
    if math.random() < staffRisk then
        self.resources.staff = math.max(0, self.resources.staff - 1)
        self.resources.staffSick = self.resources.staffSick + 1
        self.stats.staffLosses = self.stats.staffLosses + 1
        self:enqueueMessage("Staff member infected and off duty.")
    end
end

function Hospital:maybeTriggerRandomEvent()
    self.randomEventTimer = self.randomEventTimer - 1
    if self.randomEventTimer > 0 then
        return
    end
    self.randomEventTimer = 6 + math.random(0, 6)
    local roll = math.random()
    if roll < 0.25 then
        self.modifiers.surgeHours = self.modifiers.surgeHours + 6
        self:enqueueMessage("Random Event: Community outbreak drives surge!")
    elseif roll < 0.5 then
        self.supply:delayOrders(4)
        self:enqueueMessage("Random Event: Logistics delay slows deliveries.")
    elseif roll < 0.7 then
        self.resources.staff = math.max(0, self.resources.staff - 2)
        self.resources.staffSick = self.resources.staffSick + 2
        self.stats.staffLosses = self.stats.staffLosses + 2
        self:enqueueMessage("Random Event: Staff illness wave.")
    else
        self.modifiers.virusSeverity = self.modifiers.virusSeverity + 0.01
        self.modifiers.infectionBoost = self.modifiers.infectionBoost + 0.02
        self:enqueueMessage("Random Event: Virus mutation increases severity.")
    end
end

function Hospital:checkEndConditions()
    local general, isolation = self:getWardUsage()
    if self.resources.staff <= 2 then
        self:endGame("Staff exhausted. Hospital forced to close.")
        return
    end
    if self.stats.deaths >= 12 then
        self:endGame("Fatalities exceeded safety threshold.")
        return
    end
    if general >= self.capacity.general and isolation >= self.capacity.isolation then
        self:endGame("All beds occupied. Unable to accept patients.")
        return
    end
    if self.clock.day > 30 then
        self:endGame("Simulation complete. 30 days passed.")
    end
end

function Hospital:endGame(message)
    if self.endCondition then return end
    self.endCondition = message
    self.finance.score = self:calculateScore()
    self:enqueueMessage(message)
end

function Hospital:calculateScore()
    local score = self.stats.discharges * 5
    score = score - self.stats.deaths * 7
    score = score - self.stats.staffLosses * 3
    score = score + math.floor(self.finance.money / 500)
    score = score - math.floor(self.infectionRisk * 100)
    return score
end

function Hospital:recordDailySnapshot()
    table.insert(self.history.infections, self.stats.infections)
    table.insert(self.history.deaths, self.stats.deaths)
    table.insert(self.history.recoveries, self.stats.discharges)
end

function Hospital:enqueueMessage(text)
    table.insert(self.messageLog, 1, string.format("Day %d Hr %d: %s", self.clock.day, self.clock.hour % 24, text))
    if #self.messageLog > 12 then
        table.remove(self.messageLog)
    end
end

function Hospital:findPatient(id)
    for _, patient in ipairs(self.patients) do
        if patient.id == id then
            return patient
        end
    end
    return nil
end

function Hospital:runTest(patientId)
    local patient = self:findPatient(patientId)
    if not patient or not patient.alive or patient.discharged then
        return false, "Patient unavailable"
    end
    if patient.tested then
        return false, "Already tested"
    end
    if not self.upgrades.rapid.purchased then
        if not self.supply:consume("tests", 1) then
            return false, "No tests remaining"
        end
    end
    Patients.revealStatus(patient)
    self:enqueueMessage(string.format("Test result: %s is %s", patient.name, patient.covidStatus))
    return true, "Test complete"
end

function Hospital:admitPatient(patientId, ward)
    local patient = self:findPatient(patientId)
    if not patient or not patient.alive or patient.discharged then
        return false, "Patient unavailable"
    end
    if patient.ward == ward then
        return false, "Already there"
    end
    local general, isolation = self:getWardUsage()
    if ward == "general" then
        if general >= self.capacity.general then
            return false, "General ward full"
        end
    elseif ward == "isolation" then
        if isolation >= self.capacity.isolation then
            return false, "Isolation full"
        end
    else
        return false, "Unknown ward"
    end
    Patients.setWard(patient, ward)
    Patients.addNote(patient, string.format("Admitted to %s ward.", ward))
    return true, string.format("%s now in %s", patient.name, ward)
end

function Hospital:toggleTreatment(patientId, key)
    local patient = self:findPatient(patientId)
    if not patient or not patient.alive or patient.discharged then
        return false, "Patient unavailable"
    end
    patient.treatments = patient.treatments or {}
    local entry = Treatments.get(key)
    if not entry then
        return false, "Unknown treatment"
    end
    if patient.treatments[key] then
        patient.treatments[key] = false
        if entry.resourceCost and entry.resourceCost.ventilator then
            self.resources.ventsAvailable = math.min(self.capacity.ventilators, self.resources.ventsAvailable + 1)
        end
        return true, string.format("Stopped %s", entry.label)
    end
    if entry.resourceCost then
        if entry.resourceCost.ventilator then
            if self.resources.ventsAvailable <= 0 then
                return false, "No ventilators free"
            end
            self.resources.ventsAvailable = self.resources.ventsAvailable - 1
        end
        if entry.resourceCost.ppe then
            if not self.supply:consume("ppe", entry.resourceCost.ppe) then
                return false, "Need PPE"
            end
        end
        if entry.resourceCost.meds then
            if not self.supply:consume("meds", entry.resourceCost.meds) then
                return false, "Need meds"
            end
        end
    end
    patient.treatments[key] = true
    Patients.addNote(patient, string.format("Started %s", entry.label))
    return true, string.format("%s applied", entry.label)
end

function Hospital:orderSupply(item)
    local template = self.supply:getOrderTemplate(item)
    if not template then
        return false, "Unknown order"
    end
    if self.finance.money < template.cost then
        return false, "Insufficient funds"
    end
    self.finance.money = self.finance.money - template.cost
    local order = self.supply:placeOrder(item)
    if order then
        self:enqueueMessage(string.format("Ordered %s (arrives in %dh)", template.label, template.eta))
        return true, "Order placed"
    end
    return false, "Order failed"
end

function Hospital:deployVaccination()
    if not self.supply:consume("vaccines", 2) then
        return false, "Need at least 2 vaccine vials"
    end
    self.modifiers.infectionBoost = math.max(0, self.modifiers.infectionBoost - 0.02)
    self:enqueueMessage("Vaccination drive shields staff.")
    return true, "Vaccination deployed"
end

function Hospital:togglePolicy(key)
    local policy = self.policies[key]
    if not policy then
        return false, "Unknown policy"
    end
    if policy.active then
        return false, "Already active"
    end
    if self.finance.money < policy.cost then
        return false, "Insufficient funds"
    end
    policy.active = true
    self.finance.money = self.finance.money - policy.cost
    self:enqueueMessage(string.format("Policy enacted: %s", policy.label))
    return true, "Policy active"
end

function Hospital:buyUpgrade(key)
    local upgrade = self.upgrades[key]
    if not upgrade then
        return false, "Unknown upgrade"
    end
    if upgrade.purchased then
        return false, "Already purchased"
    end
    if self.finance.money < upgrade.cost then
        return false, "Insufficient funds"
    end
    upgrade.purchased = true
    self.finance.money = self.finance.money - upgrade.cost
    if key == "beds" then
        self.capacity.general = self.capacity.general + 4
        self.capacity.isolation = self.capacity.isolation + 2
    elseif key == "vents" then
        self.capacity.ventilators = self.capacity.ventilators + 2
        self.resources.ventsAvailable = self.resources.ventsAvailable + 2
    elseif key == "rapid" then
        self.supply:addStock("tests", 6)
    end
    self:enqueueMessage(string.format("Upgrade purchased: %s", upgrade.label))
    return true, "Upgrade purchased"
end

function Hospital:getPatients()
    return self.patients
end

function Hospital:getActivePatients()
    local active = {}
    for _, patient in ipairs(self.patients) do
        if patient.alive and not patient.discharged then
            table.insert(active, patient)
        end
    end
    table.sort(active, function(a, b) return a.id < b.id end)
    return active
end

function Hospital:getSummary()
    local general, isolation = self:getWardUsage()
    return {
        day = self.clock.day,
        hour = self.clock.hour % 24,
        general = { used = general, capacity = self.capacity.general },
        isolation = { used = isolation, capacity = self.capacity.isolation },
        vents = { free = self.resources.ventsAvailable, total = self.capacity.ventilators },
        staff = { available = self.resources.staff, sick = self.resources.staffSick },
        stats = self.stats,
        money = self.finance.money,
        infectionRisk = self.infectionRisk,
        supplies = self.supply:getSummary(),
        policies = self.policies,
        upgrades = self.upgrades,
        messages = self.messageLog,
        endCondition = self.endCondition,
        score = self.finance.score
    }
end

return Hospital
