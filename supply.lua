local Supply = {}
Supply.__index = Supply

local orderCatalog = {
    tests = { label = "PCR Test Kits", qty = 8, cost = 1200, eta = 6 },
    ppe = { label = "PPE Crate", qty = 20, cost = 800, eta = 4 },
    meds = { label = "Medication Pack", qty = 12, cost = 1500, eta = 8 },
    vaccines = { label = "Vaccine Vials", qty = 10, cost = 2000, eta = 10 }
}

function Supply.new()
    local self = {
        stock = {
            tests = 10,
            ppe = 30,
            meds = 18,
            vaccines = 6
        },
        orders = {},
        nextOrderId = 1,
        history = {}
    }
    return setmetatable(self, Supply)
end

function Supply:getStock()
    return self.stock
end

function Supply:consume(item, amount)
    amount = amount or 1
    if not self.stock[item] then return false end
    if self.stock[item] < amount then
        return false
    end
    self.stock[item] = self.stock[item] - amount
    return true
end

function Supply:addStock(item, amount)
    if not self.stock[item] then
        self.stock[item] = 0
    end
    self.stock[item] = self.stock[item] + amount
end

function Supply:getOrderTemplate(item)
    return orderCatalog[item]
end

function Supply:getOrders()
    return self.orders
end

function Supply:delayOrders(extraHours)
    for _, order in ipairs(self.orders) do
        order.remaining = order.remaining + extraHours
    end
end

function Supply:placeOrder(item)
    local template = orderCatalog[item]
    if not template then
        return nil, "Unknown supply"
    end
    local order = {
        id = self.nextOrderId,
        item = item,
        qty = template.qty,
        cost = template.cost,
        eta = template.eta,
        remaining = template.eta
    }
    self.nextOrderId = self.nextOrderId + 1
    table.insert(self.orders, order)
    table.insert(self.history, string.format("Ordered %s x%d", template.label, template.qty))
    return order
end

function Supply:update(hours)
    for i = #self.orders, 1, -1 do
        local order = self.orders[i]
        order.remaining = order.remaining - hours
        if order.remaining <= 0 then
            self:addStock(order.item, order.qty)
            table.remove(self.orders, i)
        end
    end
end

function Supply:getSummary()
    return {
        stock = self.stock,
        orders = self.orders,
        catalog = orderCatalog
    }
end

return Supply
