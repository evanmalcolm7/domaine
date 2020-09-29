local unitSpecs = {}

-- * All specials are called with the Unit calling them as the first arg

local function distanceBetweenRefs(ref1, ref2, skipLanes)
  -- * used to get the distance between two tileRefs
  local l1, t1 = ref1:sub(1,1), ref1:sub(2,2)
  local l2, t2 = ref2:sub(1,1), ref2:sub(2,2)
  -- ? are they in the same lane?
  -- if we don't care, then skip this
  if skipLanes then goto skipLanes end
  if l1 ~= l2 then
    return false
  end
  ::skipLanes::
  local distance = math.abs(t1-t2)
  return distance
end

local function adjacentLanes(lane1, lane2)
  -- * note: lanes are not adjacent to themselves
  if lane1 == 'r' then
    if lane2 ~= 'y' then return false end
  elseif lane1 == 'g' then
    if lane2 ~= 'y' then return false end
  elseif lane1 == 'y' then
    -- only lane not adjacent to yellow is itself
    if lane2 == 'y' then return false end
  end
  return true
end

local function findUnitByID(uidToFind)
  -- TODO: optimize, only run tiles that have units in them?
  for laneKey, lane in pairs(board.lanes) do
    for tileKey, tile in pairs(lane) do
      -- optimization: if a tile has nothing in it, skip it
      if not tile.content then goto nextTile end

      for unitKey, unit in pairs(tile.content) do
        if unit.uid == uidToFind then return unit end
      end

      ::nextTile::
    end
  end
  -- if no unit is found, return false
  return false
end

local function tileRefToTile(tileRef)
  local l, t = tileRef:sub(1,1), tileRef:sub(2,2)
  local tile = (board.lanes[l])[tonumber(t)]
  return tile
end

-- !!! TRAVELLERS !!! --

local function envoySpecial(caster)
  AskingForTile = true
  CreateAlert('Select a Tile to move to.', 5)
  WaitFor("tileSelected", function(newTileRef)
    -- * we nest on tile selection
    client:send("unitMove", {caster, caster.tile, newTileRef})
    -- use a secondary action
    client:send("useAction", {'secondary', caster, 'unitSpecial'})
  end, {'triggerArgs'})
end

unitSpecs["envoySpec"] = envoySpecial

-- ! SIREN

local function sirenSpecial(caster)
  CreateAlert('Target an enemy unit in an adjacent Tile.', 3)
  WaitFor("targetEnemy", function(enemyUnit)
    -- first, we check if target is valid
    if distanceBetweenRefs(caster.tile, enemyUnit.tile) ~= 1 then
      CreateAlert('Invalid target; not adjacent tiles!', 3)
      return
    end
    -- if all's well, we move the target to the caster's tile
    client:send("unitMove", {enemyUnit, enemyUnit.tile, caster.tile})
    -- use a secondary action
    client:send("useAction", {'secondary', caster, 'unitSpecial'})
  end, {'triggerArgs'})
end

unitSpecs["sirenSpec"] = sirenSpecial

-- ! ROUTER

local function routerSpecial(caster)
  CreateAlert('Target a friendly Unit in the same Tile.', 3)
  WaitFor("targetAlly", function(allyUnit)
    -- check they're in the same tile
    if allyUnit.tile ~= caster.tile then
      CreateAlert('Invalid target', 3)
      return
    end
    -- then, select a different tile to move that unit to
    AskingForTile = true
    CreateAlert('Select a Tile to move to.', 5)
    WaitFor("tileSelected", function(newTileRef)
      -- move the ally unit
      client:send("unitMove", {allyUnit, allyUnit.tile, newTileRef})
    -- use a secondary action
    client:send("useAction", {'secondary', caster, 'unitSpecial'})
    end, {'triggerArgs'}) -- * end of tileSelected block
  end, {'triggerArgs'}) -- * end of targetAlly block
end

unitSpecs["routerSpec"] = routerSpecial

-- ! SHIFTER

local function shifterSpec(caster)
  CreateAlert('Select a unit to swap with.', 3)
  WaitFor("targetUnit", function(targetUnit)
    -- move the caster to the target's tile
    client:send("unitMove", {caster, caster.tile, targetUnit.tile})
    -- move the target to the caster's tile
    client:send("unitMove", {targetUnit, targetUnit.tile, caster.tile})
    -- use a secondary action
    client:send("useAction", {'secondary', caster, 'unitSpecial'})
  end, {'triggerArgs'})
end

unitSpecs["shifterSpec"] = shifterSpec

-- ! CHAIN

local function chainSpec(caster)
  -- first, we get a target
  CreateAlert('Select a Unit to attach to.', 3)
  WaitFor("targetUnit", function(targetUnit)
    -- we verify the target is in the same tile
    if distanceBetweenRefs(caster.tile, targetUnit.tile) ~= 0 then
      CreateAlert('Invalid target.', 3)
      return false
    end
    -- TODO: we remove any other units that this chain is attached to
    -- we attach a tag to the chain's specTable, "unitMove|chainAttached"
    -- this tag contains the chain unit as the value
    local newTargetSpec = targetUnit.specTable
    newTargetSpec.tags["unitMove|chainAttached"] = caster.uid
    client:send("modifyUnitTable", {targetUnit, 'specTable', newTargetSpec})
    -- use a secondary action
    client:send("useAction", {'secondary', caster, 'unitSpecial'})
    -- when that unit moves, chainAttached() is called by the server handleEvent()
  end, {'triggerArgs'})
end

-- * called when a unit the Chain is attached to moves
local function chainAttached(mover, oldTileRef, newTileRef)
    -- first, we find the Chain unit
    local chainUnit = findUnitByID(mover.specTable.tags["unitMove|chainAttached"])
    print(inspect(chainUnit))
    -- then, we move the Chain unit to the newTileRef
    client:send("removeUnitFromTile", {chainUnit})
    client:send("addUnitToTile", {chainUnit, mover.tile})
end

unitSpecs["chainSpec"] = chainSpec
unitSpecs["chainAttached"] = chainAttached

-- !!! STRIKERS !!! --

local function sniperSpec(caster)
  -- first, get a targetEnemy
  CreateAlert('Select an enemy to attack.', 5)
  WaitFor("targetEnemy", function(targetEnemy)
    -- check if they're a valid target
    local ref1, ref2 = caster.tile, targetEnemy.tile
    local l1, t1 = ref1:sub(1,1), ref1:sub(2,2)
    local l2, t2 = ref2:sub(1,1), ref2:sub(2,2)
    -- ? are they not in same tile
    if t1 ~= t2 then CreateAlert('Invalid target, not adjacent', 3) return false end
    -- ? are they in adjacent lanes
    if not adjacentLanes(l1, l2) then CreateAlert('Invalid target, not adjacent', 3) return false end
    -- if all is well, make an attack
    client:send("unitAttack", {caster, targetEnemy, doNotCheckRange=true})
    -- use a secondary action
    client:send("useAction", {'secondary', caster, 'unitSpecial'})
  end, {'triggerArgs'})
end

unitSpecs["sniperSpec"] = sniperSpec

-- ! HUNTER

local function hunterSpec(caster)
  -- first, we get an enemy
  CreateAlert('Select a Unit to Mark.', 3)
  WaitFor("targetEnemy", function(targetEnemy)
    -- we tag the target as "hunter|Marked"
    local newTargetSpec = targetEnemy.specTable
    newTargetSpec.tags["hunter|MarkedBy"] = caster.uid
    client:send("modifyUnitTable", {targetEnemy, 'specTable', newTargetSpec})
    -- * the rest is handled in unitBasicAttack
    -- use a secondary action
    client:send("useAction", {'secondary', caster, 'unitSpecial'})
  end, {'triggerArgs'})

end

unitSpecs["hunterSpec"] = hunterSpec

-- ! NULLITY

local function nullitySpec(caster)
  CreateAlert('Target a unit.', 3)
  WaitFor("targetUnit", function(targetUnit)
    -- first, we just remove the target unit
    client:send("removeUnitFromTile", {targetUnit})
    -- then, we remove the caster
    client:send("removeUnitFromTile", {caster})
    
    -- ensures that one nullity returning doesn't return them all 
    local uniqueReturnEvent = caster.uid.."Return"
    -- then, we queueTimedEvent the event caster.uid.."Return" for targetUnit.health turns later
    client:send("queueTimedEvent", {uniqueReturnEvent, targetUnit.health, {}})

    -- we wait for that queued event, with a function that returns the nullity
    WaitFor(uniqueReturnEvent, function(unitToReturn)
      CreateAlert(caster.name..' has returned!', 3)
      client:send("addUnitToTile", {unitToReturn, unitToReturn.tile})
    end, {caster})

    -- finally, we use a secondary ability
    client:send("useAction", {'secondary', caster, 'unitSpecial'})

  end, {'triggerArgs'})
end

unitSpecs["nullitySpec"] = nullitySpec

-- ! BERSERKER

local function berserkerPassive(caster)
  -- * the berserker's passive, called when it kills a unit
  CreateAlert('Berserker rages! Select a new attack target', 5)
  
  -- we use a dummy function so we can recursively call in case of
  -- the user targeting the wrong unit
  local function dummyFunc()
    WaitFor("targetEnemy", function(targetEnemy)
      if distanceBetweenRefs(caster.tile, targetEnemy.tile) ~= 0 then
        CreateAlert('Target is in a different Tile! Try again.', 3)
        dummyFunc()
        return
      end
      -- if all is well, make an attack
      client:send("unitAttack", {caster, targetEnemy})
    end, {'triggerArgs'})
  end

  dummyFunc()
end

unitSpecs["berserkerPassive"] = berserkerPassive

-- ! KNIGHT

local function knightPassive(mover, oldTileRef, newTileRef)
  local l1, t1 = oldTileRef:sub(1,1), oldTileRef:sub(2,2)
  local l2, t2 = newTileRef:sub(1,1), newTileRef:sub(2,2)
  -- first, we determine if lane has been changed
  local laneChanged = false
  if l1 ~= l2 then laneChanged = true end
  -- then, we see how much distance between tiles
  local distance = distanceBetweenRefs(oldTileRef, newTileRef, true)
  -- then, we calculate how much attack to add
  local attackGain = 0
  if laneChanged then attackGain = 3 end
  attackGain = attackGain + distance
  -- then, we calculate the new attack
  local newAttack = mover.attack + attackGain
  client:send("modifyUnitTable", {mover, 'attack', newAttack})
  -- finally, we queue up an event for next turn to reset the attack
  local originalAttack = mover.specTable.tags["storage|OriginalAttack"]
  local uniqueEvent = mover.uid.."resetAttack"
  
  WaitFor(uniqueEvent, function(unit, originalAttack)
    client:send("modifyUnitTable", {unit, 'attack', originalAttack})
  end, {mover, originalAttack})

  client:send("queueTimedEvent", {uniqueEvent, 1, {} })
end

unitSpecs["knightPassive"] = knightPassive

-- !!! SHAKERS !!! --

-- ! FLEET ADMIRAL

local function fleetAdmiralSpec(caster)
  AskingForTile = true
  CreateAlert('Target a Tile to orbital strike.', 5)
  WaitFor("tileSelected", function(tileRef)

    -- we queue a unique fleet admiral event in 2 turns
    local uniqueEvent = caster.uid.."orbitalStrike"
    client:send("queueTimedEvent", {uniqueEvent, 2, {}})

    -- then we nest again waiting for that event
    WaitFor(uniqueEvent, function(refToStrike)
      -- we get the contents of the tile
      local tile = tileRefToTile(refToStrike)
      for _, unit in pairs(tile.content) do
        -- TODO: unit damage event?
        CreateAlert('Orbital strike activated!', 3)
        client:send("modifyUnitTable", {unit, 'health', unit.health - 3})
      end
    end, {tileRef})


    -- finally, we use a secondary action
    client:send("useAction", {'secondary', caster, 'unitSpecial'})
  end, {'triggerArgs'})
end

unitSpecs["fleetAdmiralSpec"] = fleetAdmiralSpec

-- ! PLAGUEBEARER

local function plaguebearerPassive1(_, oldTileRef, _)
  -- * when the carcass moves out of a tile, kill everything in it
  tile = tileRefToTile(oldTileRef)
  for _, unit in pairs(tile.content) do
    -- TODO: call death event for these units?
    client:send("removeUnitFromTile", {unit})
  end
end

local function plaguebearerPassive2(caster)
  -- * when the carcass dies, kill everything in the tile
  local tile = tileRefToTile(caster.tile)
  for _, unit in pairs(tile.content) do
    -- TODO: death event?
    client:send("removeUnitFromTile", {unit})
  end
end

unitSpecs["plaguebearerPassive1"] = plaguebearerPassive1
unitSpecs["plaguebearerPassive2"] = plaguebearerPassive2

-- ! INFERNO

local function infernoSpec(caster)
 -- first, we await a tile
 CreateAlert('Select a tile to set ablaze.', 3)
 AskingForTile = true
 WaitFor("tileSelected", function(tileRef)
    -- we create a function that will damage each unit in a tile by 1
    local function burn(burnTileRef)
      local tile = tileRefToTile(burnTileRef)
      for _, unit in pairs(tile.content) do
        client:send("modifyUnitTable", {unit, 'health', unit.health-1})
      end
    end
    -- then, we schedule a burn for the next three turns
    local eventTable = {caster.uid..'Burn'..'1', caster.uid..'Burn'..'2', caster.uid..'Burn'..'3'}
    for i, event in pairs(eventTable) do
      client:send("queueTimedEvent", {event, i, {}})
      WaitFor(event, burn, {tileRef})
    end

  end, {'triggerArgs'})

  --todo: action
end

unitSpecs["infernoSpec"] = infernoSpec

-- ! OVERGROWTH

local function overgrowthSpec(caster)
  -- we convert the overgrowth to a tree
  client:send("modifyUnitTable", {caster, 'name', 'Sacred Tree'})
  client:send("modifyUnitTable", {caster, 'attack', 0})
  client:send("modifyUnitTable", {caster, 'health', 5})
  client:send("modifyUnitTable", {caster, 'canMove', false})
  client:send("modifyUnitTable", {caster, 'canAttack', false})
  client:send("modifyUnitTable", {caster, 'canSpecial', false})
  local newSpecTable = {shortDesc='At the end of each turn, all other Units in this Tile are converted to allied 1|1 Beasts. The Tree cannot move.',
                        fullDesc='At the end of each turn, all other Units in this Tile are converted to allied 1|1 Beasts. The Tree cannot move',
                        specRef=nil,
                        tags={} }
  client:send("modifyUnitTable", {caster, 'specTable', newSpecTable})

  -- then we create a function that converts everything to beasts
  local function beastConversion(event, tileRef, iteration)
    local tile = tileRefToTile(tileRef)
    for _, unit in pairs(tile.content) do
      if unit.name ~= 'Sacred Tree' then
        -- convert each unit to a beast
        client:send("modifyUnitTable", {unit, 'name', 'Beast'})
        client:send("modifyUnitTable", {unit, 'attack', 1})
        client:send("modifyUnitTable", {unit, 'health', 1})
        client:send("modifyUnitTable", {unit, 'player', playerNumber})
        local newSpecTable = {shortDesc='\n',
                              fullDesc='\n',
                              specRef=nil,
                              tags={} }
        client:send("modifyUnitTable", {unit, 'specTable', newSpecTable})
      end
    end

    local iter = iteration + 1
    local newUnique = event..tostring(iter)
    WaitFor(newUnique, beastConversion, {newUnique, caster.tile, iter})
    client:send("queueTimedEvent", {newUnique, 1, {}})
  end

  local uniqueEvent = 'sacredTreeSpecial'
  WaitFor(uniqueEvent, beastConversion, {uniqueEvent, caster.tile, 1})
  client:send("queueTimedEvent", {uniqueEvent, 1, {} } )

  -- todo: use action

end

unitSpecs["overgrowthSpec"] = overgrowthSpec

-- ! ARCHITECT

--
-- ACTIVE: Create one of the following in the Architect’s tile:
-- The Wall - 0/3 - Units cannot move into or out of the Wall’s tile.
-- The Road - 0/3 - Basic moves into the Road’s tile do not consume an Action.
--

local function architectSpec(caster)
  -- first, we present a popmenu asking which to view
  CreatePopup('Select a building to construct.', {'Wall', 'Road'}, 120, "buildingSelect")
  -- then, we await for the building selection
  WaitFor("buildingSelect", function(building)
    client:send("createUnitOnTile", {building, caster.tile})
  end, {'triggerArgs'})

  --TODO: use an action 
  

end

unitSpecs["architectSpec"] = architectSpec

local function wallPassive(mover, oldTileRef, newTileRef)
  -- called when a unit moves into or out of a wall's tile
  -- we basically "rubberband" the unit back
  CreateAlert('A Wall prevents movement in or out of this tile.', 3)
  client:send("removeUnitFromTile", {mover, newTileRef})
  client:send("addUnitToTile", {mover, oldTileRef})
end

unitSpecs["wallPassive"] = wallPassive

--TODO: road

-- !!! TRANSMUTERS !!! --

-- ! DEMAGOGUE

local function demagogueSpec(caster)
  -- get an enemy unit
  CreateAlert('Target an enemy unit.', 3)
  local uniqueEvent = caster.uid..'demagogueReversion'
  WaitFor("targetEnemy", function(targetEnemy)
    -- make sure enemy is in the same tile
    if distanceBetweenRefs(caster.tile, targetEnemy.tile) ~= 0 then
      CreateAlert('Invalid target.', 3)
      return false
    end
    -- convert the enemy to this player
    local originalPlayer = targetEnemy.player
    client:send("modifyUnitTable", {targetEnemy, 'player', playerNumber})
    -- schedule the reversion event
    client:send("queueTimedEvent", {uniqueEvent, 1, {targetEnemy, originalPlayer}})
  end, {'triggerArgs'})

  --TODO: use an action

  -- then we wait for the unique event
  WaitFor(uniqueEvent, function(data)
    local target, player = unpack(data)
    client:send("modifyUnitTable", {target, 'player', player})
  end, {'triggerArgs'})
end

unitSpecs["demagogueSpec"] = demagogueSpec

-- ! BLANK

local function blankSpec(caster)
  CreateAlert('Target a unit.', 3)
  WaitFor("targetUnit", function(targetUnit)
    -- make sure enemy is in the same tile
    if distanceBetweenRefs(caster.tile, targetUnit.tile) ~= 0 then
      CreateAlert('Invalid target.', 3)
      return false
    end
    
    local emptySpecTable = {shortDesc='Special has been blanked.', fullDesc='Special has been blanked.', specRef=nil, tags={}}
    client:send("modifyUnitTable", {targetUnit, 'specTable', emptySpecTable})
    -- TODO: use action 
  end, {'triggerArgs'})
end

unitSpecs["blankSpec"] = blankSpec

-- ! WARDEN

local function wardenSpec(caster)
  -- unit target
  CreateAlert('Target a unit.', 3)
  WaitFor("targetUnit", function(targetUnit)
    -- store original values
    local OGmove, OGattack, OGspecial = targetUnit.canMove, targetUnit.canAttack, targetUnit.canSpecial
    -- disable acting
    client:send("modifyUnitTable", {targetUnit, 'canMove', false})
    client:send("modifyUnitTable", {targetUnit, 'canAttack', false})
    client:send("modifyUnitTable", {targetUnit, 'canSpecial', false})

    -- in 2 turns from now, revert it
    local uniqueEvent = caster.uid..'wardenReversion'
    client:send("queueTimedEvent", {uniqueEvent, 2, {targetUnit, OGmove, OGattack, OGspecial}})


    WaitFor(uniqueEvent, function(data)
      local target, moveFlag, attackFlag, specialFlag = unpack(data)
      client:send("modifyUnitTable", {target, 'canMove', moveFlag})
      client:send("modifyUnitTable", {target, 'canAttack', attackFlag})
      client:send("modifyUnitTable", {target, 'canSpecial', specialFlag})
    end, {'triggerArgs'})
    
    -- TODO: action usage
  end, {'triggerArgs'})
end

unitSpecs["wardenSpec"] = wardenSpec

-- ! CHRONOMAGE

local function chronomageSpec(caster)
  CreateAlert('Target a unit.', 3)
  WaitFor("targetUnit", function(targetUnit)
    -- strip all numbers from the UID
    local newID = string.match(targetUnit.uid, '.*%D')
    local newTile = targetUnit.tile
    -- remove the unit
    client:send("removeUnitFromTile", {targetUnit})
    -- create the fresh copy
    print(newTile)
    client:send("createUnitOnTile", {newID, newTile})
    -- TODO: use action
  end, {'triggerArgs'})
end

unitSpecs["chronomageSpec"] = chronomageSpec

-- ! ANIMATOR

local function animatorSpec(caster)
  CreateAlert('Target a unit.', 3)
  WaitFor("targetUnit", function(targetUnit)
    client:send("modifyUnitTable", {targetUnit, 'canMove', true})
    client:send("modifyUnitTable", {targetUnit, 'canAttack', true})
    local specTable = targetUnit.specTable
    if not specTable.specRef then
      specTable.specRef = "animatorRef"
      client:send("modifyUnitTable", {targetUnit, 'specTable', specTable})
    end
  end, {'triggerArgs'})
end

unitSpecs["animatorSpec"] = animatorSpec

-- !!! CONDUITS !!! --

-- ! MISERY



-- ! BEACON



-- ! INEFFABLE



-- ! RITUALIST



-- ! FOOL

local function foolSpec(caster)
  CreateAlert('Target a unit.', 3)
  WaitFor("targetUnit", function(targetUnit)
    -- get that unit's specFunc
    local specTable = targetUnit.specTable
    local specRef = specTable['specRef']
    local specFunc = unitSpecs[specRef]
    -- call the specRef
    specFunc(caster)
  end, {'triggerArgs'})
end

unitSpecs["foolSpec"] = foolSpec

return unitSpecs