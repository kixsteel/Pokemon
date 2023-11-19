-- spell bar by Pota based on draky's
local spells = {}
local spellsNumber = 12
local OPCODE_SKILLBAR = 52
local side = 'vertical'
local sbw -- window widget
local spellBarWindow -- UIWindow
local hideLevel = false -- hide spells that can not be used due to level dependence

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
  local moves = {}
  local cooldowns = {}
  local cooldownRemaining = {}
  spells = {}
  for match in string.gmatch(buffer, "([^,]+),%s*") do
    if tonumber(match) == nil then
      moves[#moves + 1] = match
    else
      if #cooldowns < #moves then
        cooldowns[#cooldowns + 1] = tonumber(match)
      else
        cooldownRemaining[#cooldownRemaining + 1] = tonumber(match)        
      end
    end
  end
  for i = 1, #moves do
     local inside = {id = i, words = moves[i], lvl = 1, exhaustion = cooldowns[i], cooldownRemaining = cooldownRemaining[i]}
     table.insert(spells, inside)
  end
  getSpells(spells)
  level = g_game.getLocalPlayer():getLevel()
  sbw:show()
end

function init()
  sbw = g_ui.displayUI('pokemonmoves')
  sbw:move(10,50)
  g_mouse.bindPress(sbw, function() createMenu() end, MouseRightButton)
  sbw:hide()
  connect(g_game, 'onTalk', messageSentCallback)
  connect(g_game, { onGameEnd = function() sbw:hide() end })
  connect(LocalPlayer, {
    onLevelChange = onLevelChange
  })
  ProtocolGame.registerExtendedOpcode(OPCODE_SKILLBAR, getOpCode)
end

function onLevelChange(localPlayer, value, percent)
  getSpells(spells)
end

function messageSentCallback(name, level, mode, text, channelId, pos)
  if not g_game.isOnline() then return end
  if g_game.getLocalPlayer():getName() ~= name then return end
  if mode ~= 34 then return end
  if msgcontains(text, "use") then
    text = string.gsub(text, "use ", "")
    text = string.gsub(text, "!", "")
    text = text:split(", ")[2]
    for i = 1, #spells do
      if spells[i].words:lower() == text:lower() then 
        startDownDelay(i)
        break
      end
    end
  elseif msgcontains(text, "thanks") then
    sbw:hide()
  end
end

function terminate()
  ProtocolGame.unregisterExtendedOpcode(OPCODE_SKILLBAR)
  sbw:destroy()
  disconnect(g_game, { onGameEnd = function() sbw:hide() end })
  disconnect(g_game, 'onTalk', messageSentCallback)
  disconnect(LocalPlayer, {
    onLevelChange = onLevelChange
  })
end

function createMenu()
  local menu = g_ui.createWidget('PopupMenu')
  if side == 'horizontal' then
    menu:addOption('Set Vertical', function() side = 'vertical' getSpells(spells) end)
  else
    menu:addOption('Set Horizontal',function() side = 'horizontal' getSpells(spells) end)
  end
  menu:display()
end

function destroySpells()
  for i = 1, spellsNumber do
    if sbw:recursiveGetChildById('spell'..i) == nil then break end
    sbw:recursiveGetChildById('spell'..i):destroy()
    sbw:recursiveGetChildById('progress'..i):destroy()
  end
end

function getSpells(table)
  destroySpells()
  spellBarWindow = sbw:recursiveGetChildById('mainWindow')
  local player = g_game.getLocalPlayer()
  local value = #table
  local width = 38
  local height = 38
  if not player then return end
  for i = 1, #table do
    if (table[i].lvl > player:getLevel()) and hideLevel == true then
      value = i - 1
      break
    end
    if i == #table then value = i end
    icon = g_ui.createWidget('SpellButton',spellBarWindow)
    --icon:
    icon:setId('spell'..i)
    local pathOn = "moves_icon/"..table[i].words.."_on.png"
    icon:setImageSource(pathOn)
    icon:setVisible(true) 
    icon.words = table[i].words
    icon.lvl = table[i].lvl
    icon.exhaustion = table[i].exhaustion
    icon.exhaustionNeeded = icon.exhaustion - table[i].cooldownRemaining
    icon:setTooltip(table[i].words)
    if side == 'horizontal' then
      icon:setMarginTop(3)
      height = 38
      width = (i) * 32 + 2*(i)
      icon:setMarginLeft((i) * 32 + 2*(i) - 32)
    else
      icon:setMarginLeft(3)
      icon:setMarginTop((i) * 32 + 2*(i) - 32)
      width = 38
      height = (i) * 32 + 2*(i)
    end
    --progress:
    progress = g_ui.createWidget('SpellProgressSpell',spellBarWindow)
    progress:setId('progress'..i)
    progress:setVisible(true)
    progress:setPercent(100)
    progress:setMarginLeft(icon:getMarginLeft())
    progress:setMarginTop(icon:getMarginTop())
    if player:getLevel() < icon.lvl then progress:setText('L'..icon.lvl) progress:setColor('red') progress:setPercent(0) end
    if progress:getPercent() == 100 then progress:setText('') elseif icon.lvl < player:getLevel() then progress:setText(progress:getPercent()) end
    progress:setPhantom(true)
    icon.onClick = function() useSpell(i) end
  end
  sbw:setHeight(height)
  sbw:setWidth(width)  
  spellBarWindow:setSize(sbw:getSize())
end

function useSpell(i)
  local progress = sbw:recursiveGetChildById('progress'..i)
  local player = g_game.getLocalPlayer()
  if not player then return end
  if progress:getPercent() < 100 then return modules.game_textmessage.displayFailureMessage('Sorry, not possible.') end
  g_game.talk('m'..i)
end

function startDownDelay(i)
  local spell = sbw:recursiveGetChildById('spell'..i)
  if not spell then return end
  local progress = sbw:recursiveGetChildById('progress'..i)
  progress:setPercent(0)
  progress:setText('0%')
  progress:setColor('red')
  spell.exhaustionNeeded = 0
  scheduleEvent(function() spellTimeleft(i) end,100) 
end

function spellTimeleft(i)
  local spell = sbw:recursiveGetChildById('spell'..i)
  if not spell then return end
  local progress = sbw:recursiveGetChildById('progress'..i)
  spell.exhaustionNeeded = spell.exhaustionNeeded + 100
  if spell.exhaustionNeeded < spell.exhaustion then
    progress:setPercent(math.floor(((spell.exhaustionNeeded) * 100)/spell.exhaustion))
    progress:setText(progress:getPercent())
    progress:setColor('red')
  else
    progress:setPercent(100)
    progress:setText('')
    spell.exhaustionNeeded = 0    
    return true
  end
  scheduleEvent(function() spellTimeleft(i) end,100) 
end
