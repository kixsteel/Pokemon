-- bar by Pota
local pokes = {}
local pokesNumber = 6
local OPCODE_POKEBAR = 53
local side = 'vertical'
local pkb -- window widget
local pokeBarWindow -- UIWindow
local hideLevel = false -- hide pokes that can not be used due to level dependence

function msgcontains(message, keyword)
  local message, keyword = message:lower(), keyword:lower()
  if message == keyword then
    return true
  end
  return message:find(keyword) and not message:find('(%w+)' .. keyword)
end

function string:split( inSplitPattern, outResults )
  if not outResults then
    outResults = { }
  end
  local theStart = 1
  local theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
  while theSplitStart do
    table.insert( outResults, string.sub( self, theStart, theSplitStart-1 ) )
    theStart = theSplitEnd + 1
    theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
  end
  table.insert( outResults, string.sub( self, theStart ) )
  return outResults
end

function getOpCode(protocol, opcode, buffer)
  local names = {}
  pokes = {}
  for match in string.gmatch(buffer, "([^,]+),%s*") do
    if tonumber(match) == nil then
      names[#names + 1] = match
    end
  end
  for i = 1, #names do
     local inside = {id = i, words = names[i], lvl = 1}
     table.insert(pokes, inside)
  end
  getPortraits(pokes)
  level = g_game.getLocalPlayer():getLevel()
  pkb:show()
end

function init()
  pkb = g_ui.displayUI('pokemonbar')
  pkb:setParent(modules.game_interface.getRootPanel(), true)
  pkb:addAnchor(AnchorLeft, 'parent', AnchorLeft)
  pkb:addAnchor(AnchorTop, 'parent', AnchorTop)
  pkb:setMarginLeft(10)
  pkb:setMarginTop(210)
  -- pkb:setPhantom(true)
  g_mouse.bindPress(pkb, function() createMenu() end, MouseRightButton)
  pkb:hide()
  connect(g_game, 'onTalk', messageSentCallback)
  connect(g_game, { onGameEnd = function() pkb:hide() end })
  connect(LocalPlayer, {
    onLevelChange = onLevelChange,
--    onFreeCapacityChange = onFreeCapacityChange

	
  })
  ProtocolGame.registerExtendedOpcode(OPCODE_POKEBAR, getOpCode)
end

function onLevelChange(localPlayer, value, percent)
  getPortraits(pokes)
end

--function onFreeCapacityChange(player, freeCapacity)
--  print(player, freeCapacity)
--end

function messageSentCallback(name, level, mode, text, channelId, pos)
  if not g_game.isOnline() then return end
  if g_game.getLocalPlayer():getName() ~= name then return end
  if mode ~= 34 then return end
  if msgcontains(text, "use") then
    text = string.gsub(text, "use ", "")
    text = string.gsub(text, "!", "")
    text = text:split(", ")[2]
    for i = 1, #pokes do
      if pokes[i].words:lower() == text:lower() then 
        startDownDelay(i)
        break
      end
    end
  elseif msgcontains(text, "thanks") then
--    pkb:hide()
  end
end

function terminate()
  ProtocolGame.unregisterExtendedOpcode(OPCODE_POKEBAR)
  pkb:destroy()
  disconnect(g_game, { onGameEnd = function() pkb:hide() end })
  disconnect(g_game, 'onTalk', messageSentCallback)
  disconnect(LocalPlayer, {
    onLevelChange = onLevelChange,
--    onFreeCapacityChange = onFreeCapacityChange
  })
end

function createMenu()
  local menu = g_ui.createWidget('PopupMenu')
  if side == 'horizontal' then
    menu:addOption('Set Vertical', function() side = 'vertical' getPortraits(pokes) end)
  else
    menu:addOption('Set Horizontal',function() side = 'horizontal' getPortraits(pokes) end)
  end
  menu:display()
end

function destroyPortraits()
  for i = 1, pokesNumber do
    if pkb:recursiveGetChildById('poke'..i) == nil then break end
    pkb:recursiveGetChildById('poke'..i):destroy()
    pkb:recursiveGetChildById('progress'..i):destroy()
	pkb:recursiveGetChildById('back'..i):destroy()
  end
end

function getPortraits(table)
  destroyPortraits()
  pokeBarWindow = pkb:recursiveGetChildById('mainWindow')
  local player = g_game.getLocalPlayer()
  local value = #table
  local width = 48
  local height = 48
  if not player then return end
  for i = 1, #table do
    if (table[i].lvl > player:getLevel()) and hideLevel == true then
      value = i - 1
      break
    end
    if i == #table then value = i end
	backg = g_ui.createWidget('BackGround',pokeBarWindow)
	icon = g_ui.createWidget('PokeButton',pokeBarWindow)
    --icon:
	backg:setVisible(true)
	backg:setPhantom(true)
    icon:setId('poke'..i)
	backg:setId('back'..i)
    local pathOn = "bar_icon/"..table[i].words:lower()..".png"
    icon:setImageSource(pathOn)
    icon:setVisible(true)
    icon.words = table[i].words
    icon.lvl = table[i].lvl
    icon:setTooltip(table[i].words)
    if side == 'horizontal' then
      icon:setMarginTop(4)
	  backg:setMarginTop(4)
      icon:setMarginLeft((i) * 44 + 2*(i) - 44)
	  backg:setMarginLeft((i) * 44 + 2*(i) - 47)
      height = 86
      width = (i) * 44 + 2*(i)
    else
      icon:setMarginLeft(4)
	  backg:setMarginLeft(1)
      icon:setMarginTop((i) * 48 + 2*(i) - 48)
	  backg:setMarginTop((i) * 47 + 2*(i) - 47)
      width = 86
      height = (i) * 46 + 2*(i)
    end
    --progress:
    progress = g_ui.createWidget('PokeProgress',pokeBarWindow)
    progress:setId('progress'..i)
    progress:setVisible(true)
    progress:setPercent(100)
    progress:setMarginLeft(icon:getMarginLeft())
    progress:setMarginTop(icon:getMarginTop())
    if player:getLevel() < icon.lvl then progress:setText('L'..icon.lvl) progress:setColor('red') progress:setPercent(0) end
    if progress:getPercent() == 100 then progress:setText('') elseif icon.lvl < player:getLevel() then progress:setText(progress:getPercent()) end
    progress:setPhantom(true)
    icon.onClick = function() usePoke(i) end
  end
  pkb:setHeight(height)
  pkb:setWidth(width)  
  pokeBarWindow:setSize(pkb:getSize())
end

function usePoke(i)
--  local progress = pkb:recursiveGetChildById('progress'..i)
  local player = g_game.getLocalPlayer()
  if not player then return end
  local icon = pkb:recursiveGetChildById('poke'..i)
--  if progress:getPercent() < 100 then return modules.game_textmessage.displayFailureMessage('Sorry, not possible.') end
  g_game.talk("!p "..i)
end
