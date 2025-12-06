local Hospital = require("hospital")
local UI = require("ui")

local game = {
    hospital = nil,
    ui = nil
}

function love.load()
    love.window.setTitle("COVID Ward Commander: Isolation Edition")
    love.window.setMode(1280, 800, { resizable = true, minwidth = 1024, minheight = 720 })
    game.hospital = Hospital.new()
    game.ui = UI.new()
end

function love.update(dt)
    if game.hospital then
        game.hospital:update(dt)
    end
    if game.ui and game.hospital then
        game.ui:update(dt, game.hospital)
    end
end

function love.draw()
    if game.ui and game.hospital then
        game.ui:draw(game.hospital)
    end
end

function love.mousepressed(x, y, button)
    if game.ui and game.hospital then
        game.ui:mousepressed(x, y, button, game.hospital)
    end
end

function love.keypressed(key)
    if key == "r" and game.hospital then
        local summary = game.hospital:getSummary()
        if summary.endCondition then
            game.hospital:reset(false)
        end
    elseif key == "escape" then
        love.event.quit()
    end
end
