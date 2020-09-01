local buildArmy = {}

local suit = require("suit")

local armyList = {}
local unitList = require('unitList')
--init currentArmyCost so it can be used in the armyList
local currentArmyCost = 0

function buildArmy.update(dt)
  -- * make all the unitselect buttons
  local x,y = love.graphics.getDimensions()
  local centerX = Round(x/2)
  local centerY = Round(y/2)
  local startX, endX = math.max(0,centerX-375), math.min(centerX+375,x)

  local unitNames = {}
  for k,_ in pairs(unitList) do
    table.insert(unitNames, k)
  end
  
  local numOfRows = 6
  for rowNum=1,numOfRows do
    -- 1 = 1:5
    -- 2: 6:10
    -- 3: 11:15

    local row = {unpack(unitNames, 1+(numOfRows*(rowNum-1)), (numOfRows*rowNum))}

    suit.layout:reset(startX, (25*(rowNum-1))+20 )
    suit.layout:padding(30)
    -- every button is effectively buttonWidth + 10px wide, because of the padding on each side
    local buttonWidth = Round(endX/10)
    for _, unitName in pairs(row) do
      suit.Button(unitName, suit.layout:col(100,20))
    end

  end

  --add units to armyList when their button is hit
  for k,v in pairs(unitList) do
      if suit.isHit(k) then
          -- make sure there's room in the budgest
          if currentArmyCost + v[1] <= 7 then
              table.insert(armyList, k)
          end
      end
  end

  --create the armyList labels and buttons
  suit.layout:reset(centerX-50, centerY+10)
  suit.Label('YOUR ARMY', suit.layout:row(100, 20))
  local budgetText = string.format('Budget: %d/7', currentArmyCost)
  suit.Label(budgetText, suit.layout:row(100,20))
  for k, v in pairs(armyList) do
      suit.Button(v, {id = v..tostring(k)}, suit.layout:row(100, 20))
  end

  --remove the unit from the armyList when clicked
  for k, v in pairs(armyList) do
      if suit.isHit(v..tostring(k)) then
          table.remove(armyList, k)
      end
  end

  --calculate currentArmyCost from armyList
  currentArmyCost = 0
  for k,v in pairs(armyList) do
      currentArmyCost = currentArmyCost + unitList[v][1]
  end

  --make a button to launch into the matchmaking screen
  suit.Button('Army Complete', centerX-50, centerY+200, 100, 20)
  if suit.isHit('Army Complete') then
      changeScreen(unitPlacement)
      unitPlacement.setArmy(armyList)
  end

end

function buildArmy.draw()
  suit.draw()
end

return buildArmy
