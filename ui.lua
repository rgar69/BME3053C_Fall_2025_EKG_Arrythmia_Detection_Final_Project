local Treatments = require("treatments")

local UI = {}
UI.__index = UI

function UI.new()
    local self = setmetatable({}, UI)
    self.currentTab = "Dashboard"
    self.selectedPatientId = nil
    self.buttons = {}
    self.tabs = { "Dashboard", "Patients", "Treatment", "Supply", "Policies" }
    self.treatmentOrder = { "oxygen", "antivirals", "steroids", "ventilator" }
    self.policyOrder = { "mask", "visitors", "isolation" }
    self.upgradeOrder = { "beds", "vents", "rapid" }
    self.fonts = nil
    return self
end

function UI:loadAssets()
    self.fonts = {
        large = love.graphics.newFont(20),
        normal = love.graphics.newFont(14),
        small = love.graphics.newFont(12)
    }
    love.graphics.setFont(self.fonts.normal)
end

function UI:update(dt, hospital)
    if self.selectedPatientId then
        local patient = hospital:findPatient(self.selectedPatientId)
        if not patient or not patient.alive or patient.discharged then
            self.selectedPatientId = nil
        end
    end
end

function UI:draw(hospital)
    if not self.fonts then
        self:loadAssets()
    end
    local summary = hospital:getSummary()
    self.buttons = {}

    love.graphics.clear(0.08, 0.09, 0.12, 1)
    self:drawTopBar(summary)
    self:drawTabs()

    local contentY = 110
    if self.currentTab == "Dashboard" then
        self:drawDashboard(summary, hospital, contentY)
    elseif self.currentTab == "Patients" then
        self:drawPatientsTab(hospital, contentY)
    elseif self.currentTab == "Treatment" then
        self:drawTreatmentTab(hospital, contentY)
    elseif self.currentTab == "Supply" then
        self:drawSupplyTab(summary, contentY)
    elseif self.currentTab == "Policies" then
        self:drawPoliciesTab(summary, contentY)
    end

    if summary.endCondition then
        self:drawEndOverlay(summary)
    end
end

function UI:drawTopBar(summary)
    local w = love.graphics.getWidth()
    love.graphics.setColor(0.13, 0.15, 0.22, 1)
    love.graphics.rectangle("fill", 0, 0, w, 100)
    love.graphics.setFont(self.fonts.large)
    love.graphics.setColor(0.95, 0.96, 0.98, 1)
    love.graphics.print("COVID Ward Commander: Isolation Edition", 20, 20)
    love.graphics.setFont(self.fonts.normal)
    love.graphics.print(string.format("Day %d  |  %02d:00", summary.day, summary.hour), 20, 60)
    love.graphics.print(string.format("Funds: $%s", tostring(summary.money)), 220, 60)
    love.graphics.print(string.format("Staff: %d avail / %d sick", summary.staff.available, summary.staff.sick), 420, 60)
    love.graphics.print(string.format("Infection Risk: %d%%", math.floor(summary.infectionRisk * 100)), 650, 60)
end

function UI:drawTabs()
    local x = 20
    for _, tab in ipairs(self.tabs) do
        local active = self.currentTab == tab
        self:drawButton({
            label = tab,
            x = x,
            y = 70,
            w = 140,
            h = 30,
            action = { type = "switch_tab", tab = tab },
            active = active
        })
        x = x + 150
    end
end

function UI:drawDashboard(summary, hospital, y)
    love.graphics.setColor(0.12, 0.14, 0.2, 1)
    love.graphics.rectangle("fill", 20, y, love.graphics.getWidth() - 40, 450, 8, 8)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.fonts.large)
    love.graphics.print("Main Dashboard", 40, y + 15)

    love.graphics.setFont(self.fonts.normal)
    local lineY = y + 60
    love.graphics.print(string.format("General Ward: %d / %d beds", summary.general.used, summary.general.capacity), 40, lineY)
    love.graphics.print(string.format("Isolation Ward: %d / %d beds", summary.isolation.used, summary.isolation.capacity), 40, lineY + 24)
    love.graphics.print(string.format("Ventilators: %d free / %d total", summary.vents.free, summary.vents.total), 40, lineY + 48)
    love.graphics.print(string.format("Recoveries: %d", summary.stats.discharges), 40, lineY + 72)
    love.graphics.print(string.format("Deaths: %d", summary.stats.deaths), 40, lineY + 96)
    love.graphics.print(string.format("Hospital-acquired infections: %d", summary.stats.infections), 40, lineY + 120)

    self:drawMessages(summary.messages, love.graphics.getWidth() - 400, y + 60)
    self:drawHistoryGraph(hospital, 40, y + 210)
end

function UI:drawMessages(messages, x, y)
    love.graphics.setFont(self.fonts.normal)
    love.graphics.setColor(0.18, 0.2, 0.27, 1)
    love.graphics.rectangle("fill", x, y, 340, 230, 6, 6)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Message Log", x + 12, y + 10)
    local offset = 30
    love.graphics.setFont(self.fonts.small)
    for i = 1, math.min(#messages, 9) do
        love.graphics.print(messages[i], x + 12, y + offset)
        offset = offset + 20
    end
end

function UI:drawHistoryGraph(hospital, x, y)
    local width = love.graphics.getWidth() - 80
    local height = 200
    love.graphics.setColor(0.1, 0.12, 0.18, 1)
    love.graphics.rectangle("fill", x, y, width, height, 6, 6)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.fonts.normal)
    love.graphics.print("Trend (cumulative)", x + 10, y + 10)

    local infections = hospital.history.infections
    local deaths = hospital.history.deaths
    local recoveries = hospital.history.recoveries
    local maxVal = 1
    for _, list in ipairs({ infections, deaths, recoveries }) do
        for _, v in ipairs(list) do
            if v > maxVal then maxVal = v end
        end
    end
    local function drawLine(data, r, g, b)
        if #data < 2 then return end
        love.graphics.setColor(r, g, b, 1)
        for i = 2, #data do
            local x1 = x + 20 + (i - 2) * ((width - 40) / math.max(1, (#data - 1)))
            local y1 = y + height - 20 - (data[i - 1] / maxVal) * (height - 60)
            local x2 = x + 20 + (i - 1) * ((width - 40) / math.max(1, (#data - 1)))
            local y2 = y + height - 20 - (data[i] / maxVal) * (height - 60)
            love.graphics.line(x1, y1, x2, y2)
        end
    end
    drawLine(recoveries, 0.2, 0.8, 0.4)
    drawLine(infections, 0.9, 0.4, 0.2)
    drawLine(deaths, 0.8, 0.2, 0.6)
    love.graphics.setFont(self.fonts.small)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Green: Recoveries", x + 20, y + height - 40)
    love.graphics.print("Orange: Infections", x + 200, y + height - 40)
    love.graphics.print("Magenta: Deaths", x + 400, y + height - 40)
end

function UI:drawPatientsTab(hospital, y)
    local patients = hospital:getActivePatients()
    local listHeight = love.graphics.getHeight() - y - 20
    love.graphics.setColor(0.12, 0.14, 0.2, 1)
    love.graphics.rectangle("fill", 20, y, love.graphics.getWidth() - 40, listHeight, 8, 8)
    love.graphics.setFont(self.fonts.large)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Patients", 40, y + 10)
    love.graphics.setFont(self.fonts.small)

    local rowY = y + 50
    for i, patient in ipairs(patients) do
        if rowY + 60 > love.graphics.getHeight() then
            break
        end
        local active = (self.selectedPatientId == patient.id)
        self:drawPatientRow(patient, rowY, active)
        rowY = rowY + 70
    end
end

function UI:drawPatientRow(patient, y, active)
    love.graphics.setColor(active and 0.18 or 0.1, 0.2, 0.28, 1)
    love.graphics.rectangle("fill", 40, y, love.graphics.getWidth() - 80, 60, 6, 6)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.fonts.normal)
    love.graphics.print(string.format("%s  |  Ward: %s  |  Status: %s", patient.name, patient.ward or "triage", patient.covidStatus), 50, y + 10)
    love.graphics.print(string.format("SpO2 %d%%  Temp %.1fC  RR %d", patient.vitals.spo2, patient.vitals.temp, patient.vitals.rr), 50, y + 32)

    self:drawButton({ label = active and "Selected" or "Select", x = love.graphics.getWidth() - 340, y = y + 10, w = 80, h = 36, action = { type = "select_patient", patientId = patient.id }, active = active })
    self:drawButton({ label = "Test", x = love.graphics.getWidth() - 250, y = y + 10, w = 60, h = 36, action = { type = "run_test", patientId = patient.id } })
    self:drawButton({ label = "General", x = love.graphics.getWidth() - 180, y = y + 10, w = 80, h = 36, action = { type = "assign", patientId = patient.id, ward = "general" } })
    self:drawButton({ label = "Isolation", x = love.graphics.getWidth() - 90, y = y + 10, w = 80, h = 36, action = { type = "assign", patientId = patient.id, ward = "isolation" } })
end

function UI:drawTreatmentTab(hospital, y)
    love.graphics.setColor(0.12, 0.14, 0.2, 1)
    love.graphics.rectangle("fill", 20, y, love.graphics.getWidth() - 40, love.graphics.getHeight() - y - 20, 8, 8)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.fonts.large)
    love.graphics.print("Treatment Panel", 40, y + 10)

    local patient = self.selectedPatientId and hospital:findPatient(self.selectedPatientId)
    love.graphics.setFont(self.fonts.normal)
    if not patient then
        love.graphics.print("Select a patient from the Patients tab.", 40, y + 60)
        return
    end

    love.graphics.print(string.format("Name: %s  |  Ward: %s  |  Status: %s", patient.name, patient.ward or "triage", patient.covidStatus), 40, y + 60)
    love.graphics.print(string.format("Vitals -> HR %d  SpO2 %d%%  RR %d  Temp %.1fC  BP %d", patient.vitals.hr, patient.vitals.spo2, patient.vitals.rr, patient.vitals.temp, patient.vitals.bp), 40, y + 90)
    love.graphics.print(string.format("Risk: Age %d  Condition: %s", patient.risk.age, patient.risk.comorbidity), 40, y + 120)

    local cardsY = y + 160
    love.graphics.setFont(self.fonts.normal)
    local catalog = Treatments.getCatalog()
    local x = 40
    for _, key in ipairs(self.treatmentOrder) do
        local entry = catalog[key]
        if entry then
        local active = patient.treatments and patient.treatments[key]
        self:drawButton({
            label = entry.label,
            x = x,
            y = cardsY,
            w = 180,
            h = 60,
            action = { type = "toggle_treatment", patientId = patient.id, treatment = key },
            active = active
        })
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(self.fonts.small)
        love.graphics.printf(entry.description, x + 8, cardsY + 30, 160)
        x = x + 200
        if x + 200 > love.graphics.getWidth() then
            x = 40
            cardsY = cardsY + 80
        end
        love.graphics.setFont(self.fonts.normal)
        end
    end
end

function UI:drawSupplyTab(summary, y)
    love.graphics.setColor(0.12, 0.14, 0.2, 1)
    love.graphics.rectangle("fill", 20, y, love.graphics.getWidth() - 40, love.graphics.getHeight() - y - 20, 8, 8)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.fonts.large)
    love.graphics.print("Supplies", 40, y + 10)

    love.graphics.setFont(self.fonts.normal)
    local x = 40
    for _, key in ipairs({ "tests", "ppe", "meds", "vaccines" }) do
        local qty = summary.supplies.stock[key] or 0
        local catalog = summary.supplies.catalog[key]
        local label = catalog and catalog.label or key
        local cost = catalog and catalog.cost or 0
        self:drawButton({
            label = string.format("%s: %d (Order $%d)", label, qty, cost),
            x = x,
            y = y + 60,
            w = 180,
            h = 60,
            action = { type = "order_supply", item = key }
        })
        x = x + 200
    end

    love.graphics.setFont(self.fonts.normal)
    love.graphics.print("Pending Orders:", 40, y + 150)
    local orders = summary.supplies.orders
    local offset = y + 180
    if #orders == 0 then
        love.graphics.print("None", 40, offset)
    else
        for _, order in ipairs(orders) do
            love.graphics.print(string.format("%s arriving in %dh", order.item, math.ceil(order.remaining)), 40, offset)
            offset = offset + 20
        end
    end

    self:drawButton({
        label = "Deploy Vaccination Drive (uses 2 vials)",
        x = 40,
        y = offset + 30,
        w = love.graphics.getWidth() - 80,
        h = 40,
        action = { type = "vaccinate" }
    })
end

function UI:drawPoliciesTab(summary, y)
    love.graphics.setColor(0.12, 0.14, 0.2, 1)
    love.graphics.rectangle("fill", 20, y, love.graphics.getWidth() - 40, love.graphics.getHeight() - y - 20, 8, 8)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.fonts.large)
    love.graphics.print("Policies & Upgrades", 40, y + 10)

    love.graphics.setFont(self.fonts.normal)
    local py = y + 60
    love.graphics.print("Policies", 40, py)
    py = py + 30
    for _, key in ipairs(self.policyOrder) do
        local policy = summary.policies[key]
        if policy then
        local label = policy.active and "Active" or string.format("Enable ($%d)", policy.cost)
        self:drawButton({
            label = string.format("%s - %s", policy.label, label),
            x = 40,
            y = py,
            w = love.graphics.getWidth() - 80,
            h = 40,
            action = policy.active and nil or { type = "policy", key = key },
            active = policy.active
        })
        love.graphics.setFont(self.fonts.small)
        love.graphics.printf(policy.description or "", 50, py + 22, love.graphics.getWidth() - 120)
        love.graphics.setFont(self.fonts.normal)
        py = py + 60
        end
    end

    love.graphics.print("Upgrades", 40, py)
    py = py + 30
    for _, key in ipairs(self.upgradeOrder) do
        local upgrade = summary.upgrades[key]
        if upgrade then
        local label = upgrade.purchased and "Purchased" or string.format("Buy ($%d)", upgrade.cost)
        self:drawButton({
            label = string.format("%s - %s", upgrade.label, label),
            x = 40,
            y = py,
            w = love.graphics.getWidth() - 80,
            h = 40,
            action = upgrade.purchased and nil or { type = "upgrade", key = key },
            active = upgrade.purchased
        })
        love.graphics.setFont(self.fonts.small)
        love.graphics.printf(upgrade.effect or "", 50, py + 22, love.graphics.getWidth() - 120)
        love.graphics.setFont(self.fonts.normal)
        py = py + 60
        end
    end
end

function UI:drawEndOverlay(summary)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.fonts.large)
    love.graphics.printf("Simulation Complete", 0, h / 2 - 60, w, "center")
    love.graphics.setFont(self.fonts.normal)
    love.graphics.printf(summary.endCondition or "", 0, h / 2 - 20, w, "center")
    love.graphics.printf(string.format("Score: %d", summary.score or 0), 0, h / 2 + 20, w, "center")
    love.graphics.printf("Press R to restart", 0, h / 2 + 60, w, "center")
end

function UI:drawButton(opts)
    local x, y, w, h = opts.x, opts.y, opts.w, opts.h
    local active = opts.active
    local r = active and 0.25 or 0.18
    local g = active and 0.55 or 0.22
    local b = active and 0.35 or 0.27
    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    love.graphics.setColor(0.8, 0.9, 1, 1)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)
    love.graphics.setFont(self.fonts.normal)
    love.graphics.print(opts.label, x + 8, y + (h / 2) - 8)
    if opts.action then
        table.insert(self.buttons, { x = x, y = y, w = w, h = h, action = opts.action })
    end
end

function UI:mousepressed(x, y, button, hospital)
    if button ~= 1 then return end
    for _, zone in ipairs(self.buttons) do
        if x >= zone.x and x <= zone.x + zone.w and y >= zone.y and y <= zone.y + zone.h then
            self:performAction(zone.action, hospital)
            return
        end
    end
end

function UI:performAction(action, hospital)
    if not action then return end
    if action.type == "switch_tab" then
        self.currentTab = action.tab
        return
    end
    if action.type == "select_patient" then
        self.selectedPatientId = action.patientId
        return
    end
    if action.type == "run_test" then
        local ok, msg = hospital:runTest(action.patientId)
        if not ok and msg then hospital:enqueueMessage(msg) end
        return
    end
    if action.type == "assign" then
        local ok, msg = hospital:admitPatient(action.patientId, action.ward)
        if not ok and msg then hospital:enqueueMessage(msg) end
        return
    end
    if action.type == "toggle_treatment" then
        local ok, msg = hospital:toggleTreatment(action.patientId, action.treatment)
        if not ok and msg then hospital:enqueueMessage(msg) end
        return
    end
    if action.type == "order_supply" then
        local ok, msg = hospital:orderSupply(action.item)
        if not ok and msg then hospital:enqueueMessage(msg) end
        return
    end
    if action.type == "vaccinate" then
        local ok, msg = hospital:deployVaccination()
        if not ok and msg then hospital:enqueueMessage(msg) end
        return
    end
    if action.type == "policy" then
        local ok, msg = hospital:togglePolicy(action.key)
        if not ok and msg then hospital:enqueueMessage(msg) end
        return
    end
    if action.type == "upgrade" then
        local ok, msg = hospital:buyUpgrade(action.key)
        if not ok and msg then hospital:enqueueMessage(msg) end
        return
    end
end

return UI
