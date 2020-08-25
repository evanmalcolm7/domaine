menu = {}

local suit = require('suit')

function menu.update(dt)
    -- ! change these to layout-based
    -- button to launch into unitPlacement
    local startButton = suit.Button("Start Game", 225, 200, 300, 30)
    if startButton.hit then
        unitPlacement.load()
        changeScreen(buildArmy)
    end
    -- button to connect to a game
    local connectButton = suit.Button('Connect to Game', 225, 240, 300, 30)
    if connectButton.hit then
        ConnectScreen.load()
        changeScreen(ConnectScreen)
    end
end

function menu.draw()
    local logo = love.graphics.newImage('logo.png')
    love.graphics.draw(logo, 125, 10)
    suit.draw()
end

return menu
