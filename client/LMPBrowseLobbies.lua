local BrowseLobbies = {}

function BrowseLobbies.setUpLobbyClient()
  tickRate = 1/60
  tick = 0
  client = sock.newClient(SERVER_IP, 22122)

  -- ! client functions
  client:on("connect", function(data)
    print('Successfully connected to server!')
  end)

  client:on("updateActiveLobbies", function(data)
    ActiveLobbies = data
  end)

  client:on("joinLobby", function(lobby)
    -- stores what lobby you're in and resets PreMatchData
    PreMatchData = {}
    InsideLobby = lobby
    -- moves client to LMPLobbyWait
    changeScreen(LMPLobbyWait)
  end)

  client:on("updateInsideLobby", function(newLobbyData)
    InsideLobby = newLobbyData
  end)

  client:on("goToUnitPlacement", function(lobby)
    LMPUnitPlacement.setArmyFromLobby(lobby)
    changeScreen(LMPUnitPlacement)
  end)

  -- ! connection
  local function dummyConnect()
    client:connect()
    Connected = true
  end
  -- if connection works (pcall stops any errors from crashing)
  if pcall(dummyConnect) then print('Connecting...') else print('Connection failed') end

end

function BrowseLobbies.load()

  BGSuit = suit.new()

  Avatar1 = love.graphics.newImage('images/avatar.png')
  AvatarReference = {TestAvatar=Avatar1}

  -- a list of the lobbies currently being hosted
  ActiveLobbies = {}
  -- marks whether or not this client is part of a lobby
  -- if they are, this is set equal to the lobby
  InsideLobby = false


  -- create a client instance
  SERVER_IP = 'localhost'
  BrowseLobbies.setUpLobbyClient()

end

function BrowseLobbies.update(dt)

  suit.layout:reset(centerX-75, 100)
  suit.Label('Available Lobbies', suit.layout:row(150,20))


  -- create listings on the browser
  BGSuit.layout:reset(centerX-345, centerY-220)
  BGSuit.layout:padding(3)
  for k, lobby in pairs(ActiveLobbies) do

      local bgButton = BGSuit:Button('', {id='lobby'..k}, BGSuit.layout:row(690, 40))
      if bgButton.hit then
        client:send("joinLobby", lobby.ID)
      end

      local x, y = bgButton.x, bgButton.y

      suit.layout:reset(x+7, y+4)
      local avatarImage = AvatarReference[lobby.hostAvatarStr]
      local avatar = suit.ImageButton(avatarImage, suit.layout:col(32,32))

      suit.layout:reset(x+45, y+10)
      local username = suit.Label(lobby.hostCID, suit.layout:col(100,20))
      local privacy = suit.Label(lobby.privacy, suit.layout:col(100,20))

      suit.layout:reset(centerX+245, y+10)
      local membersLabel = tostring(#lobby.members)..'/2'
      local members = suit.Label(membersLabel, suit.layout:col(100,20))
      local gameType = suit.Label(lobby.gameType, suit.layout:left(100,20))

  end

  -- create "host lobby" button
  suit.layout:reset(centerX+225, centerY+175)
  local hostButton = suit.Button('Host Lobby', suit.layout:row(125,25))
  if hostButton.hit and not InsideLobby then
    -- send a lobby table to the server to be created
    client:send("hostLobby", {hostAvatarStr='TestAvatar', hostCID=client.connectId,
                                privacy='Open', gameType='Standard',
                                members={}, hostPreMatch={}, guestPreMatch={},
                                ID=nil})
  end

  client:send("requestActiveLobbies")

end

function BrowseLobbies.draw()

  -- background of browser
  love.graphics.setColor(1/10,1/10,1/10)
  love.graphics.rectangle('fill', centerX-350, centerY-230, 700, 400, 5, 5)

  love.graphics.setColor(1,1,1)
  BGSuit:draw()
  suit.draw()

end

return BrowseLobbies