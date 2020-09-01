menu = require("menu")
board = require("board")
buildArmy = require("buildArmy")
unitPlacement = require('unitPlacement')
connectScreen = require('ConnectScreen')

suit = require("suit")
inspect = require("inspect")
local sock = require("sock")

local currentScreen

-- TODO: optimization-- only call love.getDImensions() once in main.lua love.update, else we're being expensive for no reason

function Round(n)
  return math.floor(n+.5)
end

-- * temporary solution to adjust coordinates from the default res to different reses
-- * does not fix for phones! need a diff solution
function AdjustCenter(coord, XorY)
  local x,y = love.graphics.getDimensions()
  local Centers = {centerX=Round(x/2),centerY=Round(y/2)}
  local center = Centers['center'..XorY]
  local defaultCenter
  if XorY=="X" then defaultCenter=375 else defaultCenter=250 end
  local distanceFromCenter = defaultCenter-coord
  return center-distanceFromCenter
end

function CreateAlert(alertText, duration)
  -- * creates an alert and plays the alert sound
  -- add the Alert to the list of active alerts
  ActiveAlerts[alertText] = duration
  love.audio.play(AudioSources["alertSound"])
end

function UpdateAlerts(dt)
  local x,y = love.graphics.getDimensions()
  local center = Round(x/2)
  for alertText, timeRemaining in pairs(ActiveAlerts) do
    ActiveAlerts[alertText] = timeRemaining-dt
    if ActiveAlerts[alertText] > 0 then
      local alert = AlertSuit:Button(alertText, center-75, 10, 150, 20)
      if alert.hit then
        ActiveAlerts[alertText] = nil
      end
    else
      -- if duration is 0, delete the button
      ActiveAlerts[alertText] = nil
    end
  end
end

function WaitFor(event, func, args)
  -- this is essentially a client-side queueing function
  -- takes an event, a certain string e.g. "targetEnemy", and a function object
  -- fills the WaitingFor table with that info
  -- it can later be used by TriggerEvent()
  WaitingFor[event] = {func, args}
end

function TriggerEvent(event, triggerArgs)
  -- takes an event, a certain string e.g. "targetEnemy" --
  -- takes a table triggerArgs, which, if requested in the initial WaitFor, is passed into args
  -- triggerArgs is passed into the function as a table if in the "main" arg string
  -- else, if its part of a subtable, its unpacked and passed into it
  if WaitingFor[event] then
    -- trigger only if the event is being Awaited
    -- call the function
    local func = WaitingFor[event][1]
    local args = WaitingFor[event][2]
    -- loop through args and sub-tables in args
    -- replace any "triggerArgs" string with the triggerArgs table
    for k, v in pairs(args) do
      if v == 'triggerArgs' then
        args[k] = triggerArgs
      end
      -- loop through any sub-tables that exist
      if type(v) == 'table' then
        for k2, v2 in pairs(v) do
          if v2 == 'triggerArgs' then
            -- clear the subtable
            args[k][k2] = nil
            -- if its a subtable, then we unpack it and add it to overtable
            for _, triggerArg in pairs(triggerArgs) do
              table.insert(args[k], triggerArg)
            end
          end
        end
      end
    end
    func(unpack(args))
    -- clear the WaitingFor event
    WaitingFor[event] = nil
  end
end

function changeScreen(screen)
  if screen.load then screen.load() end
  currentScreen = screen
end

function connectToHost(ip)
  -- create the client
  tickRate = 1/60
  tick = 0
  client = sock.newClient(ip, 22122)

  -- ! SETUP CLIENT

  -- on connection
  client:on("connect", function(data)
    print('Successfully connected!')
  end)

  --for getting the player index (p1 or p2)
  client:on("setUpGame", function(num)
    playerNumber = num
    print('Client number: '..playerNumber)
    -- once the client knows what number it is, it's ready to go
    Ready = true
  end)

  -- ! SERVER-TO-USER COMMUNICATION

  -- allows the server to create client-side alerts
  client:on("createAlert", function(data)
    local alertText, duration = data[1], data[2]

    CreateAlert(alertText, duration)
  end)

  -- ! BOARD FUNCTIONS

  -- * when called, the client updates its copy of the Lanes to match the server's
  client:on("updateLanes", function(UpdatedLanes)
    board.lanes = UpdatedLanes
  end)

  -- ! TURN SYSTEM

  -- * used to manage turn timer and amount of actions
  client:on("actionUsed", function(actionType)
    print(actionType.. ' action used.')
    ActionsRemaining[actionType] = ActionsRemaining[actionType] - 1
  end)

  -- * used to set who's turn it is
  client:on("setPlayerTurn", function(playerN)
    print('Player '..CurrentTurnTaker..'\'s turn ended.')
    print('It is now Player'..playerN..'\'s turn')
    -- if it's now your turn, reset available actions
    ActionsRemaining.primary, ActionsRemaining.secondary = 1,1
    CurrentTurnTaker = playerN
  end)

  -- ! CONNECTION TO SERVER
  local function dummyConnect()
    client:connect()
  end

  -- if connection works (pcall stops any errors from crashing)
  if pcall(dummyConnect) then
    Connected = true
  else
    print('Connection failed')
  end
end

-- ! LOVE loops and game events

function love.load()
  -- used as a queueing system for WaitFor() events
  WaitingFor = {}
  -- used to draw temporary alerts
  AlertSuit = suit.new()
  ActiveAlerts = {}
  -- basic settings
  love.keyboard.setKeyRepeat(true)
  love.window.setTitle('Domaine')
  love.window.setMode(750, 500, {resizable=true})
  -- audio assets (expensive to create many times)
  AudioSources = {}
  AudioSources["alertSound"] = love.audio.newSource('sounds/alertSoundDown.wav', 'static')
  AudioSources["alertSound"]:setVolume(.25)
  AudioSources["walkingAlong"] = love.audio.newSource('sounds/walkingAlong.mp3', 'stream')
  AudioSources["walkingAlong"]:setVolume(.25)
  love.audio.play(AudioSources["walkingAlong"])
  -- used for the turn system
  CurrentTurnTaker = 1
  -- initialize by setting the currentScreen to the menu
	currentScreen = menu
end

function love.update(dt)
  -- * quit the game with escape!
  if love.keyboard.isDown('escape') then love.event.quit() end
  -- control the multiplayer stuff
  if Connected then
    client:update()
  end
  -- create and increment duration of Alert buttons
  UpdateAlerts(dt)
  -- update the current screen
  currentScreen.update(dt)
end


function love.draw()
  -- draw alerts
  AlertSuit.theme.color.normal.bg = {1,1,1}
  AlertSuit.theme.color.normal.fg = {0,0,0}
  AlertSuit:draw()
  -- reset the theme
  suit.theme.color = {
    normal   = {bg = { 0.25, 0.25, 0.25}, fg = {0.73,0.73,0.73}},
		hovered  = {bg = { 0.19,0.6,0.73}, fg = {1,1,1}},
		active   = {bg = {1,0.6,  0}, fg = {1,1,1}}
	}
  -- draw the current screen
	currentScreen.draw()
end
