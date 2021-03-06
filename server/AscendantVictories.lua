local AscendantVictories = {}

local function sacramentVictory(pNum, matchState)
  local ChosenKillCount = matchState['Player'..pNum]['ChosenKillCount'] or 0
  return ChosenKillCount >= 3
end

AscendantVictories[1] = {
  name='The Sacrament',
  victoryFunc=sacramentVictory
}

local function imperatorVictory(pNum, matchState)
  -- count how many Outposts there are
  local outpostCount = 0
  for _, lane in pairs(matchState.MasterLanes) do
    for _, tile in pairs(lane) do
      local hasOutpost = false
        for _, unit in pairs(tile.content) do
          if unit.name == 'Imperial Outpost' then hasOutpost = true end
        end
      if hasOutpost then outpostCount = outpostCount + 1 end
    end
  end
  return outpostCount >= 3
end


AscendantVictories[2] = {
  name='The Imperator',
  victoryFunc=imperatorVictory
}

local function parallelVictory(pNum, matchState)
  local allSameATK = true
  local allSameHP = true
  local ATKcheck, HPcheck

  for _, lane in pairs(matchState.MasterLanes) do
    for _, tile in pairs(lane) do
      for _, unit in pairs(tile.content) do
        if not ATKcheck then ATKcheck = unit.attack end
        if not HPcheck then HPcheck = unit.health end
        if unit.attack ~= ATKcheck then allSameATK = false end
        if unit.health ~= HPcheck then allSameHP = false end
      end
    end
  end

  return (allSameATK or allSameHP)

end

AscendantVictories[3] = {
  name='The Parallel',
  victoryText='If every surviving unit has the same Attack OR the same Health.',
  victoryFunc=parallelVictory
}

local function sleeperVictory(pNum, matchState)
  local sleeperState = (matchState['Player'..pNum])['SleeperState']

  local function isMad(unit)
    local specTable = unit.specTable
    local tags = specTable.tags

    for tag, val in pairs(tags) do
      if tag == 'unitMoveIn|madnessPassive' and val == true then return true end
    end

    return false
  end

  if sleeperState == 3 then

    local onlyUnit = true
    local sleeperUID = (matchState['Player'..pNum])['AscendantUID']
    for _, lane in pairs(matchState.MasterLanes) do
      for _, tile in pairs(lane) do
        for _, unit in pairs(tile.content) do
          if not isMad(unit) then
            if sleeperUID ~= unit.uid then
              onlyUnit = false
            end
          end
        end
      end
    end

    return onlyUnit
  end

end

AscendantVictories[4] = {
  victoryText='The Sleeper\'s Incarnate must be placed on the board during Unit Placement. Refer to the Incarnate for more information.',
  victoryFunc=sleeperVictory
}

local function savantVictory(pNum, matchState)
  if matchState.TurnNumber == matchState['Player'..pNum]['SavantVictoryTurn'] then
    local alliedUnits, enemyUnits = 0, 0
    for _, lane in pairs(matchState.MasterLanes) do
      for _, tile in pairs(lane) do
        for _, unit in pairs(tile.content) do
          if unit.player == pNum then
            alliedUnits = alliedUnits + 1
          elseif unit.player ~= pNum then
            enemyUnits = enemyUnits + 1
          end
        end
      end
    end
    return alliedUnits > enemyUnits
  else
    return false
  end
end

AscendantVictories[5] = {
  name='The Savant',
  victoryText='At the start of the game, pick a turn number greater than 5. On that turn, if you have more Units than your opponent, you win. Otherwise, you lose.',
  victoryFunc=savantVictory
}

return AscendantVictories
