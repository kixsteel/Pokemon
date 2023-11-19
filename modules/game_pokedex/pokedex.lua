effectiveness = {{"Super Effective", 4}, {"Effective", 2}, {"Normal", 1}, {"Ineffective", 0.5}, {"Very Ineffective", 0.25}, {"Null", 0}}

pokemons = {}
seen = 0
catches = 0
viewShiny = nil
advancedSearchWindow = nil

function init()
  connect(g_game, { onGameEnd = hide })

  pokedexWindow = g_ui.displayUI('pokedex', modules.game_interface.getRootPanel())
  pokedexTabBar = pokedexWindow:recursiveGetChildById('pokedexTabBar')
  pokemonInfoPanel = pokedexWindow:recursiveGetChildById('pokemonInfoPanel')
  pokemonsPanel = pokedexWindow:recursiveGetChildById('pokemonsPanel')
  pokemonSearch = pokedexWindow:recursiveGetChildById('searchText')
  seenLabel = pokedexWindow:recursiveGetChildById('seenLabelValue')
  catchesLabel = pokedexWindow:recursiveGetChildById('catchesLabelValue')
  pokemonHide = pokedexWindow:recursiveGetChildById('hideUnseen')
  pokemonInfoPanel:getChildById('mapMark'):setVisible(false)
  pokedexTabContent = pokedexWindow:recursiveGetChildById('pokedexTabContent')
  advancedSearchWindow = pokedexWindow:recursiveGetChildById('advancedSearchWindow')
  pokedexTabBar:setContentWidget(pokedexTabContent)
  pokedexWindow:hide()

  movesPanel = g_ui.loadUI('moves')
  pokedexTabBar:addTab(tr('Moves'), movesPanel)

  effectivenessPanel = g_ui.loadUI('effectiveness')
  pokedexTabBar:addTab(tr('Effectiveness'), effectivenessPanel)

  lootsPanel = g_ui.loadUI('loots')
  pokedexTabBar:addTab(tr('Loots'), lootsPanel)

  for i = 1, 375 do
    local pokemonButton = g_ui.createWidget('PokemonButton', pokemonsPanel)
    pokemonButton.onMouseRelease = onPokemonButtonMouseRelease
    pokemonButton.id = i
    pokemonButton.see = false
    pokemonButton.catched = 0
    pokemonButton.name = pokemonId[i]
    if i < 10 then
      pokemonButton:setText('00'..i)
    elseif i >= 10 and i < 100 then
      pokemonButton:setText('0'..i)
    else
      pokemonButton:setText(i)
    end
    if i == 375 then
      pokemonButton:focus()
    end
	pokemonButton:setIconColor('black')
    pokemonButton:setIcon('/images/game/pokedex/icons/'..i)
    table.insert(pokemons, pokemonButton)
  end

  ProtocolGame.registerExtendedOpcode(60, function(protocol, opcode, buffer) onCheckPokedex(protocol, opcode, buffer) end)
  ProtocolGame.registerExtendedOpcode(62, function(protocol, opcode, buffer) onPokedexSelect(protocol, opcode, buffer) end)
  ProtocolGame.registerExtendedOpcode(63, function(protocol, opcode, buffer) getMapMarks(protocol, opcode, buffer) end)
  
  pokemonsPanel.onChildFocusChange = function(self, focusedChild) reloadPokemonsPanelInfo(focusedChild) end
  g_keyboard.bindKeyPress('Left', function() pokemonsPanel:focusPreviousChild(KeyboardFocusReason) end, pokedexWindow)
  g_keyboard.bindKeyPress('Right', function() pokemonsPanel:focusNextChild(KeyboardFocusReason) end, pokedexWindow)
  g_keyboard.bindKeyPress('Up', function() for i = 1, 4 do pokemonsPanel:focusPreviousChild(KeyboardFocusReason) end end, pokedexWindow)
  g_keyboard.bindKeyPress('Down', function() for i = 1, 4 do pokemonsPanel:focusNextChild(KeyboardFocusReason) end end, pokedexWindow)
end

function onPokedexSelect(protocol, opcode, buffer)
	local tabe = string.explode(buffer, "*")
	local mapMark = pokemonInfoPanel:getChildById('mapMark')
	reloadLoots(tabe[1])
	local pokemonDescription = pokemonInfoPanel:getChildById('pokemonDescription')
	pokemonDescription:setText(tabe[3])
	if tabe[2] == "false" then
		mapMark:setVisible(false)
	else
		mapMark:setVisible(true)
	end
end

function sendMapProtocolToServer(pokeName)
	local protocol = g_game.getProtocolGame()
	if protocol then
		if not pokeName:find('?') then
			protocol:sendExtendedOpcode(69, pokeName)
		end
	end
end

function getMapMarks(protocol, opcode, buffer)
	if buffer ~= "false" then
		assert(loadstring("mapInfo = "..tostring(buffer)))()
		for i, v in pairs(mapInfo) do
			addMapMarks(v['x'], v['y'], v['z'], v['imagem'], v['description'])
		end
	end
end

function addMapMarks(x, y, z, imagem, description)
	modules.game_minimap.setMonsterCave(x, y, z, imagem, description)
	scheduleEvent(function() modules.game_minimap.removeMonsterCave(x, y, z, imagem, description) end, 30*1000)
end

function reloadLoots(list)
	if list == "false" then
		return
	end
	assert(loadstring("itemInfo = "..tostring(list)))()
	local count = 1
	for p = 1, 10 do
		local loots = lootsPanel:getChildById('pokemonLoots'):getChildById("item"..p)
		local lootsLabel = lootsPanel:getChildById('pokemonLoots'):getChildById("item"..p.."label")
		loots:setVisible(false)
		lootsLabel:setText("")
	end
	for i, v in pairs(itemInfo) do
		local loots = lootsPanel:getChildById('pokemonLoots'):getChildById("item"..count)
		local lootsLabel = lootsPanel:getChildById('pokemonLoots'):getChildById("item"..count.."label")
		loots:setItemId(v['id'])
		loots:setItemCount(v['count'])
		lootsLabel:setText("Chance: "..v['chance'].."%")
		loots:setTooltip(v['name'])
		loots:setVisible(true)
		count = count +1
	end
end

function terminate()
  disconnect(g_game, { onGameEnd = hide })

  g_keyboard.unbindKeyPress('Left')
  g_keyboard.unbindKeyPress('Right')
  g_keyboard.unbindKeyPress('Up')
  g_keyboard.unbindKeyPress('Down')

  save()
  seen = 0
  catches = 0
  pokedexWindow:destroy()
end

function show(focus, shiny)
  local scrollBar = pokedexWindow:getChildById('pokedexScrollBar')
  if focus == 0 then
    pokemonSearch:clearText()
    pokemonSearch:focus()
    pokedexWindow:show()
    pokedexWindow:raise()
    pokedexWindow:focus()
    clearCheckBoxChecked()
    pokemonsPanel:getChildByIndex(1):focus()
    scrollBar:setValue(0)
    return
  end
  if shiny then
    pokemons[focus].shiny = true
  else
    pokemons[focus].shiny = false
  end
  pokemonSearch:clearText()
  pokemonSearch:focus()
  pokedexWindow:show()
  pokedexWindow:raise()
  pokedexWindow:focus()
  clearCheckBoxChecked()
  scrollBar:setValue(math.floor((focus-21)/4)*43)
  pokemonsPanel:getChildByIndex(focus):focus()
end

function hide()
  save()
  seen = 0
  catches = 0
  pokedexWindow:hide()
end

function load()
  local settings = g_settings.getNode('game_pokedex')
  settings.hideUnseen = settings.hideUnseen or false
  pokemonHide:setChecked(settings.hideUnseen)
  hideUnseen(pokemonHide:isChecked())
end

function save()
  local settings = {}
  settings.hideUnseen = pokemonHide:isChecked()
  g_settings.setNode('game_pokedex', settings)
end

function onPokemonButtonMouseRelease(self, mousePosition, mouseButton)
  if mouseButton == MouseRightButton then
    if not self.see or not haveShinyPokemon(self.name) then return end
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    if not viewShiny or pokemonsPanel:getFocusedChild() ~= self then
      menu:addOption('Shiny', function() self:focus() reloadShinyPokemonPanelInfo(self) end)
    elseif pokemonsPanel:getFocusedChild() == self then
      menu:addOption('Normal', function() self:focus() reloadPokemonsPanelInfo(self) end)
    end
    menu:display(mousePos)
  end
end

function onCheckPokedex(protocol, opcode, buffer)
  if string.find(buffer, 'reloadCatch') then
    local pokemonId = string.explode(buffer, '-')[1]
    local pokemon = pokemonsPanel:getChildByIndex(pokemonId)
	pokemon.catched = 1
    if pokemon.see then
      pokemon:getChildByIndex(1):setImageColor('white')
    end
    return
  end
  seen = 0
  catches = 0
  for i = 1, (#string.explode(buffer, '|')-1) do
    local pokemon = pokemonsPanel:getChildByIndex(i)
	if pokemon ~= nil then
		local pokemonSee = string.explode(string.explode(buffer, '|')[i], '-')[1]
		local pokemonCatched = string.explode(string.explode(buffer, '|')[i], '-')[2]
		pokemon.catched = tonumber(pokemonCatched)
		if pokemonSee == '0' then
			pokemon.see = false
			pokemon:setIconColor('black')
		else
			pokemon.see = true
			pokemon:setIconColor('white')
			pokemon:setVisible(true)
		end
		if pokemon.catched == 1 and pokemon.see then
			pokemon:getChildByIndex(1):setImageColor('white')
		else
			pokemon:getChildByIndex(1):setImageColor('alpha')
		end
		if pokemon.see then
			seen = seen + 1
		end
		if pokemon.catched == 1 then
		catches = catches + 1
		end
	end
  end
  seenLabel:setText(seen)
  catchesLabel:setText(catches)
  load()
end

function advancedSearch(checkBox)
  for b = 1, pokemonsPanel:getChildCount() do
    local pokemon = pokemonsPanel:getChildByIndex(b)
    local type1 = pokemonTypes[pokemon.name].type1
    local type2 = pokemonTypes[pokemon.name].type2 or 'none'
    local advancedSearchCondition = (getPokemonHaveCheckedSkills(pokemon) and pokemon.see)
    if getCatchedChecked() then
      advancedSearchCondition = pokemon.catched == 1 and advancedSearchCondition
    end
    if getTypesCheckBoxCheckedCount() == 1 then
      advancedSearchCondition = (string.find(getTypesChecked(), type1) or string.find(getTypesChecked(), type2)) and advancedSearchCondition
    elseif getTypesCheckBoxCheckedCount() == 2 then
      advancedSearchCondition = (string.find(getTypesChecked(), type1) and string.find(getTypesChecked(), type2)) and advancedSearchCondition
    elseif getTypesCheckBoxCheckedCount() >= 3 then
      advancedSearchCondition = false
    end
    if pokemonHide:isChecked() then
      advancedSearchCondition = (not checkBox:isChecked() and not haveCheckBoxChecked() and pokemon.see) or advancedSearchCondition
    else
      advancedSearchCondition = (not checkBox:isChecked() and not haveCheckBoxChecked()) or advancedSearchCondition
    end
    pokemon:setVisible(advancedSearchCondition)
  end
end

function getCatchedChecked()
  if advancedSearchWindow:getChildByIndex(2):isChecked() then
    return true
  end
  return false
end

function getPokemonHaveCheckedSkills(pokemon)
  local skills = getPokemonSkills(doCorrectString(pokemon.name)):lower()
  for i = 1, #getSkillsChecked() do
    if not string.find(skills, getSkillsChecked()[i]) then
      return false
    end
  end
  return true
end

function getSkillsChecked()
  local skillsChecked = {}
  for i = 7, 18 do
    local checkBox = advancedSearchWindow:getChildByIndex(i)
    if checkBox:isChecked() then
      table.insert(skillsChecked, checkBox:getText():lower())
    end
  end
  return skillsChecked
end

function getTypesChecked()
  local typesChecked = {}
  for i = 19, 36 do
    local checkBox = advancedSearchWindow:getChildByIndex(i)
    if checkBox:isChecked() then
      table.insert(typesChecked, checkBox:getText():lower()..',')
    end
  end
  return table.concat(typesChecked)
end

function getTypesCheckBoxCheckedCount()
  local typesChecked = 0
  for i = 19, 36 do
    local checkBox = advancedSearchWindow:getChildByIndex(i)
    if checkBox:isChecked() then
      typesChecked = typesChecked + 1
    end
  end
  return typesChecked
end

function clearCheckBoxChecked()
  for i = 2, #advancedSearchWindow:getChildren() do
    if i == 2 or i >= 7 then
      advancedSearchWindow:getChildByIndex(i):setChecked(false)
    end
  end
end

function haveCheckBoxChecked()
  for i = 2, #advancedSearchWindow:getChildren() do
    if i == 2 or i >= 7 then
      if advancedSearchWindow:getChildByIndex(i):isChecked() then
        return true
      end
    end
  end
  return false
end

function hideUnseen(value)
  if pokemonSearch:getText() ~= '' then return end
  for i = 1, pokemonsPanel:getChildCount() do
    local pokemon = pokemonsPanel:getChildByIndex(i)
    local visibleCondition = (not value) or (value and pokemon.see)
    pokemon:setVisible(visibleCondition)
  end
  clearCheckBoxChecked()
end

function searchPokemon()
  local searchFilter = pokemonSearch:getText():lower()
  for i = 1, pokemonsPanel:getChildCount() do
    local pokemon = pokemonsPanel:getChildByIndex(i)
    local searchCondition = (searchFilter ~= '' and string.find(pokemon.name, searchFilter) ~= nil and pokemon.see)
    if pokemonHide:isChecked() then
      searchCondition = (searchFilter == '' and pokemon.see) or searchCondition
    else
      searchCondition = (searchFilter == '') or searchCondition
    end
    pokemon:setVisible(searchCondition)
  end
  clearCheckBoxChecked()
end

function reloadPokemonsPanelInfo(button)
  if button.shiny then
    return reloadShinyPokemonPanelInfo(button)
  end
  local pokemonNameLabel = pokemonInfoPanel:getChildById('pokemonName')
  local pokemonImage = pokemonInfoPanel:getChildById('pokemonImage')
  local pokemonType1 = pokemonInfoPanel:getChildById('pokemonType1')
  local pokemonType2 = pokemonInfoPanel:getChildById('pokemonType2')
  local pokemonDescription = pokemonInfoPanel:getChildById('pokemonDescription')
  local pokemonSkills = pokemonInfoPanel:getChildById('pokemonSkills')
  viewShiny = false
  if button.see then
    pokemonNameLabel:setText('#'..button:getText()..' '..doCorrectString(button.name))
    pokemonImage:setImageColor('white')
	pokemonImage:setTooltip(tr('Description:')..'\n'..pokesDescription[button.name])
    pokemonSkills:setText(tr('Skills')..': '..getPokemonSkills(doCorrectString(button.name))..'.')
    pokemonType1:setVisible(true)
    pokemonType2:setVisible(true)
    pokedexTabContent:setVisible(true)
  else
    pokemonImage:setImageColor('black')
    pokemonNameLabel:setText('#'..button:getText()..' ??????')
    pokemonDescription:setText(tr('Description:')..'\n??????')
    pokemonSkills:setText(tr('Skills')..': ??????.')
    pokemonType1:setVisible(false)
    pokemonType2:setVisible(false)
    pokedexTabContent:setVisible(false)
  end
  pokemonImage:setImageSource('/images/game/pokemon/portraits/'..button.name)
  pokemonType1:setTooltip(string.upper(pokemonTypes[button.name].type1))
  pokemonType1:setImageSource('/images/game/elements/'..pokemonTypes[button.name].type1)
  if pokemonTypes[button.name].type2 and button.see then
    pokemonType2:setVisible(true)
    pokemonType2:setTooltip(string.upper(pokemonTypes[button.name].type2))
    pokemonType2:setImageSource('/images/game/elements/'..pokemonTypes[button.name].type2)
  else
    pokemonType2:setVisible(false)
  end

  for i = 1, 12 do
    movesPanel:getChildById('pokemonMoves'):getChildById('move'..i):setVisible(false)
  end
  reloadMoves(doCorrectString(button.name))
  reloadEffectiveness(button.name, pokemonTypes[button.name].type1, pokemonTypes[button.name].type2)
  local protocol = g_game.getProtocolGame()
  if protocol and button.see then
	protocol:sendExtendedOpcode(55, button.name.."*false")
  end
end

function reloadShinyPokemonPanelInfo(button)
  local pokemonNameLabel = pokemonInfoPanel:getChildById('pokemonName')
  local pokemonImage = pokemonInfoPanel:getChildById('pokemonImage')
  local pokemonType1 = pokemonInfoPanel:getChildById('pokemonType1')
  local pokemonType2 = pokemonInfoPanel:getChildById('pokemonType2')
  local pokemonDescription = pokemonInfoPanel:getChildById('pokemonDescription')
  local pokemonSkills = pokemonInfoPanel:getChildById('pokemonSkills')
  viewShiny = true
  button.shiny = false
  pokemonNameLabel:setText('#'..button:getText()..' Shiny '..doCorrectString(button.name))
  pokemonImage:setImageColor('white')
  pokemonDescription:setText(tr('Description:')..'\n'..pokesDescription['shiny '..button.name])
  pokemonSkills:setText(tr('Skills')..': '..getPokemonSkills('Shiny '..doCorrectString(button.name))..'.')
  pokemonType1:setVisible(true)
  pokemonType2:setVisible(true)
  pokedexTabContent:setVisible(true)
  pokemonImage:setImageSource('/images/game/pokemon/portraits/shiny '..button.name)
  pokemonType1:setTooltip(string.upper(pokemonTypes['shiny '..button.name].type1))
  pokemonType1:setImageSource('/images/game/elements/'..pokemonTypes['shiny '..button.name].type1)
  if pokemonTypes['shiny '..button.name].type2 and button.see then
    pokemonType2:setVisible(true)
    pokemonType2:setTooltip(string.upper(pokemonTypes['shiny '..button.name].type2))
    pokemonType2:setImageSource('/images/game/elements/'..pokemonTypes['shiny '..button.name].type2)
  else
    pokemonType2:setVisible(false)
  end
  reloadMoves('Shiny '..doCorrectString(button.name))
  reloadEffectiveness('shiny '..button.name, pokemonTypes[button.name].type1, pokemonTypes[button.name].type2)
  local protocol = g_game.getProtocolGame()
  if protocol and button.see then
	protocol:sendExtendedOpcode(55, button.name.."*true")
  end
end

function reloadMoves(pokemonName)
  for i = 1, getPokemonMovesCount(pokemonName) do
    local move = movesPanel:getChildById('pokemonMoves'):getChildById('move'..i)
    local moveInfo = getPokemonMoveIdInfo(pokemonName)[i]
    move:getChildByIndex(1):setImageSource('/images/game/moves/'..moveInfo.name..'_on')
    move:getChildByIndex(1):setText(moveInfo.cd)
    move:getChildByIndex(2):setText(moveInfo.name)
    move:getChildByIndex(3):setText('Level '..moveInfo.level)
    move:getChildByIndex(4):setImageSource('/images/game/elements/'..moveInfo.t)
    move:getChildByIndex(4):setTooltip(doCorrectString(moveInfo.t))
    move:setVisible(true)
  end
end

function reloadEffectiveness(pokemonName, type1, type2)
  local scrollPanel = effectivenessPanel:getChildById('pokemonEffectiveness')
  local first = 1

  for i = 1, #scrollPanel:getChildren()-1 do
    scrollPanel:getChildByIndex(2):destroy()
  end

  for i = 1, #effectiveness do
    local effePanel = g_ui.createWidget('EffectivenessPanel', scrollPanel)
    if i > first then
      effePanel:setMarginTop(5)
    end

    local effeTypesPanel1 = effePanel:getChildByIndex(2)
    local effeTypesPanel2 = effePanel:getChildByIndex(3)
    local effeType = string.explode(getEffectiveness(type1, type2, effectiveness[i][2]), '-')
    scrollPanel:getChildByIndex(1):setText(tr('Effectiveness against')..' '..doCorrectString(pokemonName)..':')
    effePanel:getChildByIndex(1):setText(tr(effectiveness[i][1])..':')

    for a = 1, #effeTypesPanel1:getChildren() do
      effeTypesPanel1:getChildByIndex(1):destroy()
    end
    for a = 1, #effeTypesPanel2:getChildren() do
      effeTypesPanel2:getChildByIndex(1):destroy()
    end

    if getEffectiveness(type1, type2, effectiveness[i][2]) ~= "" then
      for b = 1, #effeType-1 do
        if #effeTypesPanel1:getChildren() <= 14 then
          element = g_ui.createWidget('ElementButton', effeTypesPanel1)
        else
          effePanel:setHeight(49)
          element = g_ui.createWidget('ElementButton', effeTypesPanel2)
        end
        element:setTooltip(doCorrectString(effeType[b]))
        element:setImageSource('/images/game/elements/'..effeType[b])
      end
    else
      effePanel:destroy()
      first = first + 1
    end

  end
end

function advancedSearchShow()
  if advancedSearchWindow:isVisible() then
    scheduleEvent(function() advancedSearchWindow:hide() end, 1)
  else
    advancedSearchWindow:show()
    advancedSearchWindow:raise()
    advancedSearchWindow:focus()
  end
end

function getPokemonMovesCount(pokename)
  local ret = 0
  local var = getPokemonMoveIdInfo(pokename)
  for i = 1, #var do
    if var and not var[i].passive and not var[i].mega then
      ret = ret + 1
    end
  end
  return ret
end

function getPokemonMoveIdInfo(pokename)
  local x = pokemonMoves[pokename]
  if not x then
	 print("Pokemon nao encontrado: " ..pokename .." na tabela de moves do otc.")
     return {}
  end
  
  local tables = {x.move1, x.move2, x.move3, x.move4, x.move5, x.move6, x.move7, x.move8, x.move9, x.move10, x.move11, x.move12}
  return tables
end

pokemonMoves = {                                                                                         
  ["Bulbasaur"] = {move1 = {name = "Tackle", level = 1, cd = 10, dist = 1, target = 1, f = 50, t = "normal"},
       move2 = {name = "Razor Leaf", level = 1, cd = 10, dist = 10, target = 1, f = 60, t = "grass"},
       move3 = {name = "Vine Whip", level = 1, cd = 20, dist = 1, target = 0, f = 65, t = "grass"},
       move4 = {name = "Headbutt", level = 1, cd = 15, dist = 1, target = 1, f = 70, t = "normal"},
       move5 = {name = "Leech Seed", level = 22, cd = 60, dist = 10, target = 1, f = 60, t = "grass"},
       move6 = {name = "Solar Beam", level = 30, cd = 60, dist = 1, target = 0, f = 350, t = "grass"},
       move7 = {name = "Sleep Powder", level = 28, cd = 80, dist = 1, target = 0, f = 0, t = "normal"},
       move8 = {name = "Stun Spore", level = 26, cd = 45, dist = 1, target = 0, f = 0, t = "normal"},
       move9 = {name = "Poison Powder", level = 24, cd = 45, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Ivysaur"] =   {move1 = {name = "Tackle", level = 40, cd = 20, dist = 1, target = 1, f = 80, t = "normal"},
       move2 = {name = "Razor Leaf", level = 40, cd = 10, dist = 10, target = 1, f = 90, t = "grass"},
       move3 = {name = "Vine Whip", level = 40, cd = 20, dist = 1, target = 0, f = 95, t = "grass"},
       move4 = {name = "Headbutt", level = 40, cd = 15, dist = 1, target = 1, f = 100, t = "normal"},
       move5 = {name = "Leech Seed", level = 40, cd = 60, dist = 10, target = 1, f = 90, t = "grass"},
       move6 = {name = "Bullet Seed", level = 45, cd = 35, dist = 1, target = 0, f = 100, t = "grass"},
       move7 = {name = "Solar Beam", level = 50, cd = 60, dist = 1, target = 0, f = 450, t = "grass"},
       move8 = {name = "Sleep Powder", level = 44, cd = 80, dist = 1, target = 0, f = 0, t = "normal"},
       move9 = {name = "Stun Spore", level = 40, cd = 45, dist = 1, target = 0, f = 0, t = "normal"},
       move10 = {name = "Poison Powder", level = 40, cd = 45, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Venusaur"] =  {move1 = {name = "Tackle", level = 80, cd = 10, dist = 1, target = 1, f = 100, t = "normal"},
       move2 = {name = "Razor Leaf", level = 80, cd = 9, dist = 10, target = 1, f = 120, t = "grass"},
       move3 = {name = "Vine Whip", level = 80, cd = 20, dist = 1, target = 0, f = 125, t = "grass"}, --65
       move4 = {name = "Headbutt", level = 80, cd = 15, dist = 1, target = 1, f = 140, t = "normal"},
       move5 = {name = "Leech Seed", level = 80, cd = 35, dist = 10, target = 1, f = 150, t = "grass"},
       move6 = {name = "Bullet Seed", level = 80, cd = 35, dist = 1, target = 0, f = 120, t = "grass"},
       move7 = {name = "Solar Beam", level = 80, cd = 60, dist = 1, target = 0, f = 600, t = "grass"},
           move8 = {name = "Giga Drain", level = 85, cd = 25, dist = 10, target = 1, f = 250, t = "grass"},
       move9 = {name = "Sleep Powder", level = 80, cd = 80, dist = 1, target = 0, f = 0, t = "normal"},
       move10 = {name = "Poison Powder", level = 80, cd = 45, dist = 1, target = 0, f = 0, t = "normal"},
       move11 = {name = "Leaf Storm", level = 90, cd = 90, dist = 1, target = 0, f = 150, t = "grass"},
       },
  ["Charmander"] = {move1 = {name = "Scratch", level = 1, cd = 15, dist = 1, target = 1, f = 50, t = "normal"},
        move2 = {name = "Ember", level = 1, cd = 10, dist = 10, target = 1, f = 50, t = "fire"},
        move3 = {name = "Flamethrower", level = 1, cd = 20, dist = 1, target = 0, f = 75, t = "fire"},
        move4 = {name = "Fireball", level = 1, cd = 25, dist = 10, target = 1, f = 75, t = "fire"},
        move5 = {name = "Fire Fang", level = 22, cd = 20, dist = 1, target = 1, f = 65, t = "fire"},
        move6 = {name = "Fire Blast", level = 30, cd = 60, dist = 1, target = 0, f = 350, t = "fire"},
        move7 = {name = "Rage", level = 30, cd = 80, dist = 1, target = 0, f = 0, t = "dragon"},
       },
  ["Charmeleon"] = {move1 = {name = "Scratch", level = 40, cd = 15, dist = 1, target = 1, f = 70, t = "normal"},
        move2 = {name = "Ember", level = 40, cd = 10, dist = 10, target = 1, f = 72, t = "fire"},
        move3 = {name = "Flamethrower", level = 40, cd = 20, dist = 1, target = 0, f = 90, t = "fire"},
        move4 = {name = "Fireball", level = 40, cd = 25, dist = 10, target = 1, f = 95, t = "fire"},
        move5 = {name = "Fire Fang", level = 40, cd = 20, dist = 1, target = 1, f = 95, t = "fire"},
        move6 = {name = "Flame Burst", level = 45, cd = 30, dist = 1, target = 0, f = 100, t = "fire"},
        move7 = {name = "Fire Blast", level = 50, cd = 60, dist = 1, target = 0, f = 450, t = "fire"},
        move8 = {name = "Rage", level = 40, cd = 80, dist = 1, target = 0, f = 0, t = "dragon"},
       },
  ["Charizard"] =  {move1 = {name = "Ember", level = 80, cd = 10, dist = 10, target = 1, f = 120, t = "fire"},
        move2 = {name = "Flamethrower", level = 80, cd = 20, dist = 1, target = 0, f = 120, t = "fire"},
        move3 = {name = "Fireball", level = 80, cd = 25, dist = 10, target = 1, f = 120, t = "fire"},
        move4 = {name = "Fire Fang", level = 80, cd = 20, dist = 1, target = 1, f = 120, t = "fire"},
        move5 = {name = "Flame Burst", level = 80, cd = 35, dist = 1, target = 0, f = 150, t = "fire"},
        move6 = {name = "Fire Blast", level = 80, cd = 60, dist = 1, target = 0, f = 250, t = "fire"},
            move7 = {name = "Air Slash", level = 83, cd = 40, dist = 1, target = 0, f = 150, t = "flying"},
        move8 = {name = "Wing Attack", level = 85, cd = 35, dist = 1, target = 0, f = 250, t = "flying"},
        move9 = {name = "Magma Storm", level = 90, cd = 90, dist = 1, target = 0, f = 600, t = "fire"},
        move10 = {name = "Scary Face", level = 82, cd = 50, dist = 1, target = 0, f = 0, t = "ghost"},
        move11 = {name = "Rage", level = 80, cd = 40, dist = 1, target = 0, f = 0, t = "dragon"},
        move12 = {name = "Mega - Charizard", level = 1, cd = 0, dist = 10, target = 0, f = 50, t = "ground", mega = 1},
       },
  ["Squirtle"] =   {move1 = {name = "Headbutt", level = 1, cd = 15, dist = 1, target = 1, f = 40, t = "normal"},
        move2 = {name = "Bubbles", level = 1, cd = 10, dist = 10, target = 1, f = 40, t = "water"},
        move3 = {name = "Water Gun", level = 1, cd = 20, dist = 1, target = 0, f = 55, t = "water"},
        move4 = {name = "Waterball", level = 1, cd = 25, dist = 10, target = 1, f = 65, t = "water"},
        move5 = {name = "Aqua Tail", level = 22, cd = 20, dist = 1, target = 1, f = 50, t = "water"},
        move6 = {name = "Hydro Cannon", level = 30, cd = 60, dist = 1, target = 0, f = 250, t = "water"},
        move7 = {name = "Harden", level = 28, cd = 50, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Wartortle"] =  {move1 = {name = "Headbutt", level = 40, cd = 15, dist = 1, target = 1, f = 70, t = "normal"},
        move2 = {name = "Bubbles", level = 40, cd = 10, dist = 10, target = 1, f = 60, t = "water"},
        move3 = {name = "Water Gun", level = 40, cd = 20, dist = 1, target = 0, f = 65, t = "water"},
        move4 = {name = "Waterball", level = 40, cd = 25, dist = 10, target = 1, f = 75, t = "water"},
        move5 = {name = "Aqua Tail", level = 40, cd = 20, dist = 1, target = 1, f = 75, t = "water"},
        move6 = {name = "Brine", level = 45, cd = 40, dist = 1, target = 0, f = 150, t = "water"},
        move7 = {name = "Hydro Cannon", level = 50, cd = 60, dist = 1, target = 0, f = 350, t = "water"},
        move8 = {name = "Harden", level = 40, cd = 50, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Blastoise"] =  {move1 = {name = "Headbutt", level = 80, cd = 15, dist = 1, target = 1, f = 90, t = "normal"},
        move2 = {name = "Bubbles", level = 80, cd = 10, dist = 10, target = 1, f = 90, t = "water"},
        move3 = {name = "Water Gun", level = 80, cd = 20, dist = 1, target = 0, f = 95, t = "water"},
        move4 = {name = "Waterball", level = 80, cd = 25, dist = 10, target = 1, f = 95, t = "water"},
        move5 = {name = "Water Pulse", level = 80, cd = 25, dist = 1, target = 0, f = 120, t = "water"},
        move6 = {name = "Brine", level = 80, cd = 40, dist = 1, target = 0, f = 200, t = "water"},
        move7 = {name = "Hydro Cannon", level = 80, cd = 60, dist = 1, target = 0, f = 250, t = "water"},
        move8 = {name = "Skull Bash", level = 85, cd = 45, dist = 1, target = 0, f = 180, t = "normal"},
        move9 = {name = "Hydropump", level = 90, cd = 90, dist = 1, target = 0, f = 600, t = "water"},
        move10 = {name = "Harden", level = 80, cd = 50, dist = 1, target = 0, f = 0, t = "normal"},	  
       },
  ["Caterpie"] =   {move1 = {name = "Headbutt", level = 1, cd = 10, dist = 1, target = 1, f = 20, t = "normal"},
        move2 = {name = "String Shot", level = 1, cd = 10, dist = 10, target = 1, f = 0, t = "bug"},
        move3 = {name = "Bug Bite", level = 1, cd = 5, dist = 1, target = 1, f = 35, t = "bug"},
       },
  ["Metapod"] =    {move1 = {name = "String Shot", level = 10, cd = 10, dist = 10, target = 1, f = 0, t = "bug"},
        move2 = {name = "Headbutt", level = 10, cd = 10, dist = 1, target = 1, f = 45, t = "normal"},
        move3 = {name = "Harden", level = 10, cd = 15, dist = 1, target = 0, f = 0, t = "normal"},
        move4 = {name = "Bug Bite", level = 10, cd = 10, dist = 1, target = 1, f = 50, t = "bug"},
       },                                                                                                     
  ["Butterfree"] = {move1 = {name = "Super Sonic", level = 30, cd = 15, dist = 10, target = 1, f = 0, t = "normal"},
        move2 = {name = "Silver Wind", level = 30, cd = 25, dist = 10, target = 1, f = 70, t = "bug"}, 
        move3 = {name = "Whirlwind", level = 32, cd = 25, dist = 1, target = 0, f = 80, t = "flying"},
        move4 = {name = "Confusion", level = 34, cd = 30, dist = 1, target = 0, f = 80, t = "psychic"},
        move5 = {name = "Psybeam", level = 36, cd = 15, dist = 1, target = 0, f = 90, t = "psychic"},
        move6 = {name = "Air Cutter", level = 38, cd = 40, dist = 1, target = 0, f = 90, t = "flying"},
        move7 = {name = "Sleep Powder", level = 30, cd = 60, dist = 1, target = 0, f = 0, t = "normal"},
        move8 = {name = "Safeguard", level = 40, cd = 40, dist = 1, target = 0, f = 0, t = "normal"},
        move9 = {name = "Poison Powder", level = 30, cd = 20, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Weedle"] =     {move1 = {name = "Horn Attack", level = 1, cd = 10, dist = 1, target = 1, f = 20, t = "normal"},
        move2 = {name = "String Shot", level = 1, cd = 10, dist = 10, target = 1, f = 0, t = "normal"},
        move3 = {name = "Poison Sting", level = 1, cd = 5, dist = 1, target = 1, f = 35, t = "poison"},
       },
  ["Kakuna"] =     {move1 = {name = "String Shot", level = 10, cd = 10, dist = 10, target = 1, f = 0, t = "normal"},
        move2 = {name = "Headbutt", level = 10, cd = 8, dist = 1, target = 1, f = 45, t = "normal"},
        move3 = {name = "Harden", level = 10, cd = 25, dist = 1, target = 0, f = 0, t = "normal"},
        move4 = {name = "Bug Bite", level = 10, cd = 9, dist = 1, target = 1, f = 50, t = "bug"},
       },
  ["Beedrill"] =   {move1 = {name = "String Shot", level = 30, cd = 10, dist = 10, target = 1, f = 0, t = "normal"},
        move2 = {name = "Poison Jab", level = 30, cd = 16, dist = 10, target = 1, f = 85, t = "poison"},
        move3 = {name = "Poison Sting", level = 30, cd = 10, dist = 1, target = 1, f = 60, t = "poison"},
        move4 = {name = "Fury Cutter", level = 35, cd = 15, dist = 1, target = 0, f = 70, t = "bug"},
        move5 = {name = "Pin Missile", level = 35, cd = 20, dist = 1, target = 0, f = 80, t = "bug"},
        move6 = {name = "Toxic Spikes", level = 32, cd = 25, dist = 10, target = 1, f = 90, t = "poison"},
        move7 = {name = "Rage", level = 21, cd = 30, dist = 1, target = 0, f = 0, t = "dragon"},
        move8 = {name = "Strafe", level = 21, cd = 38, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Pidgey"] =     {move1 = {name = "Quick Attack", level = 1, cd = 10, dist = 1, target = 1, f = 20, t = "normal"},
        move2 = {name = "Sand Attack", level = 1, cd = 10, dist = 1, target = 0, f = 0, t = "ground"},
        move3 = {name = "Gust", level = 3, cd = 15, dist = 1, target = 0, f = 30, t = "flying"},
        move4 = {name = "Drill Peck", level = 8, cd = 20, dist = 1, target = 1, f = 35, t = "flying"},
       },
  ["Pidgeotto"] =  {move1 = {name = "Quick Attack", level = 20, cd = 10, dist = 1, target = 1, f = 40, t = "normal"},
        move2 = {name = "Sand Attack", level = 20, cd = 15, dist = 1, target = 0, f = 0, t = "ground"},
        move3 = {name = "Whirlwind", level = 20, cd = 22, dist = 1, target = 0, f = 70, t = "flying"},
        move4 = {name = "Drill Peck", level = 20, cd = 20, dist = 1, target = 1, f = 45, t = "flying"},
        move5 = {name = "Wing Attack", level = 25, cd = 30, dist = 1, target = 0, f = 75, t = "flying"},
        move6 = {name = "Aeroblast", level = 30, cd = 100, dist = 1, target = 0, f = 350, t = "flying"},
       },
  ["Pidgeot"] =    {move1 = {name = "Quick Attack", level = 80, cd = 10, dist = 1, target = 1, f = 80, t = "normal"},
        move2 = {name = "Sand Attack", level = 80, cd = 15, dist = 1, target = 0, f = 0, t = "ground"},
        move3 = {name = "Whirlwind", level = 80, cd = 22, dist = 1, target = 0, f = 120, t = "flying"},
        move4 = {name = "Drill Peck", level = 80, cd = 20, dist = 1, target = 1, f = 120, t = "flying"},
        move5 = {name = "Wing Attack", level = 82, cd = 30, dist = 1, target = 0, f = 125, t = "flying"},
        move6 = {name = "Hurricane", level = 90, cd = 60, dist = 1, target = 0, f = 110, t = "flying"},
        move7 = {name = "Aeroblast", level = 84, cd = 100, dist = 1, target = 0, f = 600, t = "flying"},
        move8 = {name = "Agility", level = 80, cd = 25, dist = 1, target = 0, f = 0, t = "flying"},
        move9 = {name = "Roost", level = 85, cd = 70, dist = 1, target = 0, f = 0, t = "flying"},
        move10 = {name = "Mega - Pidgeot", level = 0, cd = 0, dist = 1, target = 0, f = 0, t = "flying", mega = 1},
       },
  ["Rattata"] =    {move1 = {name = "Quick Attack", level = 1, cd = 10, dist = 1, target = 1, f = 20, t = "normal"},
        move2 = {name = "Bite", level = 1, cd = 15, dist = 1, target = 1, f = 25, t = "dark"},
        move3 = {name = "Scratch", level = 1, cd = 15, dist = 1, target = 1, f = 30, t = "normal"},
        move4 = {name = "Super Fang", level = 12, cd = 25, dist = 1, target = 1, f = 35, t = "normal"},
       },
  ["Raticate"] =   {move1 = {name = "Quick Attack", level = 30, cd = 10, dist = 1, target = 1, f = 60, t = "normal"},
        move2 = {name = "Bite", level = 30, cd = 10, dist = 1, target = 1, f = 70, t = "dark"},
        move3 = {name = "Scratch", level = 30, cd = 13, dist = 1, target = 1, f = 60, t = "normal"},
        move4 = {name = "Pursuit", level = 30, cd = 20, dist = 10, target = 1, f = 75, t = "dark"},
        move5 = {name = "Super Fang", level = 30, cd = 25, dist = 1, target = 1, f = 75, t = "normal"},
        move6 = {name = "Scary Face", level = 32, cd = 45, dist = 1, target = 0, f = 0, t = "ghost"},
       },
  ["Spearow"] =    {move1 = {name = "Quick Attack", level = 10, cd = 10, dist = 1, target = 1, f = 30, t = "normal"},
        move2 = {name = "Sand Attack", level = 10, cd = 10, dist = 1, target = 0, f = 0, t = "ground"},
        move3 = {name = "Gust", level = 10, cd = 12, dist = 1, target = 0, f = 45, t = "flying"},
        move4 = {name = "Drill Peck", level = 10, cd = 16, dist = 1, target = 1, f = 50, t = "flying"},
        move5 = {name = "Agility", level = 10, cd = 25, dist = 1, target = 0, f = 0, t = "flying"},
       },
  ["Fearow"] =     {move1 = {name = "Peck", level = 50, cd = 10, dist = 1, target = 1, f = 80, t = "flying"},
        move2 = {name = "Sand Attack", level = 50, cd = 15, dist = 1, target = 0, f = 0, t = "ground"},
        move3 = {name = "Drill Peck", level = 50, cd = 20, dist = 1, target = 1, f = 90, t = "flying"},
        move4 = {name = "Whirlwind", level = 50, cd = 22, dist = 1, target = 0, f = 100, t = "flying"},
        move5 = {name = "Air Cutter", level = 50, cd = 30, dist = 1, target = 0, f = 100, t = "flying"},
        move6 = {name = "Wing Attack", level = 52, cd = 30, dist = 1, target = 0, f = 100, t = "flying"},
        move7 = {name = "Aerial Ace", level = 50, cd = 60, dist = 1, target = 0, f = 150, t = "flying"},
        move8 = {name = "Agility", level = 50, cd = 20, dist = 1, target = 0, f = 0, t = "flying"},
       },
  ["Ekans"] =      {move1 = {name = "Bite", level = 10, cd = 10, dist = 1, target = 1, f = 40, t = "dark"},
        move2 = {name = "Poison Fang", level = 10, cd = 15, dist = 1, target = 1, f = 40, t = "poison"},
        move3 = {name = "Gunk Shot", level = 12, cd = 15, dist = 10, target = 1, f = 45, t = "poison"},
        move4 = {name = "Acid", level = 15, cd = 10, dist = 10, target = 1, f = 50, t = "poison"},
        move5 = {name = "Fear", level = 20, cd = 25, dist = 1, target = 0, f = 0, t = "ghost"},
       },
  ["Arbok"] = {move1 = {name = "Bite", level = 40, cd = 10, dist = 1, target = 1, f = 60, t = "dark"},
        move2 = {name = "Poison Fang", level = 40, cd = 15, dist = 1, target = 1, f = 75, t = "poison"},
        move3 = {name = "Gunk Shot", level = 40, cd = 15, dist = 10, target = 1, f = 75, t = "poison"},
        move4 = {name = "Wrap", level = 40, cd = 20, dist = 10, target = 1, f = 0, t = "normal"},
        move5 = {name = "Gastro Acid", level = 43, cd = 25, dist = 1, target = 0, f = 80, t = "bug"},
        move6 = {name = "Acid", level = 40, cd = 15, dist = 10, target = 1, f = 95, t = "poison"},
        move7 = {name = "Iron Tail", level = 45, cd = 15, dist = 1, target = 1, f = 100, t = "steel"},
        move8 = {name = "Poison Jab", level = 40, cd = 16, dist = 10, target = 1, f = 105, t = "poison"},
       },
  ["Pikachu"] =    {move1 = {name = "Mega Kick", level = 40, cd = 40, dist = 1, target = 1, f = 95, t = "fighting"},
        move2 = {name = "Thunder Shock", level = 40, cd = 10, dist = 10, target = 1, f = 65, t = "electric"},
        move3 = {name = "Thunder Bolt", level = 40, cd = 20, dist = 10, target = 1, f = 63, t = "electric"},
        move4 = {name = "Thunder Wave", level = 40, cd = 25, dist = 1, target = 0, f = 80, t = "electric"},
        move5 = {name = "Thunder Punch", level = 40, cd = 40, dist = 1, target = 1, f = 85, t = "electric"},
        move6 = {name = "Iron Tail", level = 40, cd = 20, dist = 1, target = 1, f = 80, t = "steel"},
        move7 = {name = "Thunder", level = 50, cd = 60, dist = 1, target = 0, f = 150, t = "electric"},
        move8 = {name = "Electric Storm", level = 55, cd = 25, dist = 1, target = 0, f = 180, t = "electric"},
        move9 = {name = "Agility", level = 50, cd = 60, dist = 1, target = 0, f = 0, t = "flying"},
       },
  ["Raichu"] =     {move1 = {name = "Mega Kick", level = 80, cd = 40, dist = 1, target = 1, f = 105, t = "fighting"},
        move2 = {name = "Thunder Shock", level = 80, cd = 10, dist = 10, target = 1, f = 80, t = "electric"},
        move3 = {name = "Thunder Bolt", level = 80, cd = 20, dist = 10, target = 1, f = 80, t = "electric"},
        move4 = {name = "Thunder Wave", level = 80, cd = 25, dist = 1, target = 0, f = 80, t = "electric"},
        move5 = {name = "Thunder Punch", level = 80, cd = 40, dist = 1, target = 1, f = 95, t = "electric"},
        move6 = {name = "Iron Tail", level = 80, cd = 20, dist = 1, target = 1, f = 95, t = "steel"},
        move7 = {name = "Body Slam", level = 85, cd = 20, dist = 1, target = 1, f = 95, t = "normal"},
        move8 = {name = "Thunder", level = 80, cd = 60, dist = 1, target = 0, f = 200, t = "electric"},
        move9 = {name = "Electric Storm", level = 90, cd = 25, dist = 1, target = 0, f = 250, t = "electric"},
        move10 = {name = "Agility", level = 80, cd = 60, dist = 1, target = 0, f = 0, t = "flying"},
       },
  ["Sandshrew"] =  {move1 = {name = "Sand Attack", level = 20, cd = 10, dist = 1, target = 0, f = 0, t = "ground"},
        move2 = {name = "Mud Shot", level = 20, cd = 15, dist = 10, target = 1, f = 30, t = "ground"},
        move3 = {name = "Scratch", level = 20, cd = 10, dist = 1, target = 1, f = 30, t = "normal"},
        move4 = {name = "Rollout", level = 25, cd = 20, dist = 1, target = 0, f = 5, t = "rock"},
        move5 = {name = "Bulldoze", level = 30, cd = 35, dist = 1, target = 0, f = 50, t = "ground"},
       },
  ["Sandslash"] =  {move1 = {name = "Sand Attack", level = 70, cd = 15, dist = 1, target = 0, f = 0, t = "ground"},
        move2 = {name = "Mud Shot", level = 70, cd = 15, dist = 10, target = 1, f = 40, t = "ground"},
        move3 = {name = "Scratch", level = 70, cd = 10, dist = 1, target = 1, f = 40, t = "normal"},
        move4 = {name = "Rollout", level = 70, cd = 25, dist = 1, target = 0, f = 25, t = "rock"},
        move5 = {name = "Bulldoze", level = 70, cd = 35, dist = 1, target = 0, f = 100, t = "ground"},
        move6 = {name = "Fury Cutter", level = 75, cd = 15, dist = 1, target = 0, f = 75, t = "bug"},
        move7 = {name = "Earth Power", level = 73, cd = 35, dist = 1, target = 0, f = 75, t = "ground"},
        move8 = {name = "Earthquake", level = 80, cd = 60, dist = 1, target = 0, f = 6, t = "ground"},
        move9 = {name = "Defense Curl", level = 70, cd = 80, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Nidoran Female"] = {move1 = {name = "Quick Attack", level = 10, cd = 10, dist = 1, target = 1, f = 40, t = "normal"},
        move2 = {name = "Bite", level = 10, cd = 10, dist = 1, target = 1, f = 50, t = "dark"},
        move3 = {name = "Horn Attack", level = 12, cd = 15, dist = 1, target = 1, f = 55, t = "normal"},
        move4 = {name = "Poison Sting", level = 10, cd = 15, dist = 1, target = 1, f = 40, t = "poison"},
        move5 = {name = "Poison Fang", level = 15, cd = 15, dist = 1, target = 1, f = 65, t = "poison"},
       },
  ["Nidorina"] =   {move1 = {name = "Quick Attack", level = 30, cd = 15, dist = 1, target = 1, f = 40, t = "normal"},
        move2 = {name = "Horn Attack", level = 30, cd = 15, dist = 1, target = 1, f = 55, t = "normal"},
        move3 = {name = "Poison Jab", level = 30, cd = 25, dist = 10, target = 1, f = 65, t = "poison"},  
        move4 = {name = "Earth Power", level = 30, cd = 30, dist = 1, target = 0, f = 75, t = "ground"},
        move5 = {name = "Crusher Stomp", level = 32, cd = 25, dist = 1, target = 0, f = 90, t = "ground"},
        move6 = {name = "Cross Poison", level = 32, cd = 40, dist = 1, target = 0, f = 80, t = "poison"}, 
        move7 = {name = "Agility", level = 30, cd = 40, dist = 1, target = 0, f = 0, t = "flying"},
       },
  ["Nidoqueen"] =  {move1 = {name = "Quick Attack", level = 70, cd = 15, dist = 1, target = 1, f = 40, t = "normal"},
        move2 = {name = "Horn Attack", level = 70, cd = 15, dist = 1, target = 1, f = 55, t = "normal"},
        move3 = {name = "Sand Tomb", level = 70, cd = 35, dist = 1, target = 0, f = 50, t = "ground"},
        move4 = {name = "Poison Jab", level = 70, cd = 25, dist = 10, target = 1, f = 65, t = "poison"},  
        move5 = {name = "Earth Power", level = 70, cd = 30, dist = 1, target = 0, f = 75, t = "ground"},
        move6 = {name = "Crusher Stomp", level = 70, cd = 45, dist = 1, target = 0, f = 110, t = "ground"},
        move7 = {name = "Cross Poison", level = 72, cd = 40, dist = 1, target = 0, f = 80, t = "poison"}, 
        move8 = {name = "Earthquake", level = 76, cd = 45, dist = 1, target = 0, f = 15, t = "ground"},
        move9 = {name = "Agility", level = 70, cd = 40, dist = 1, target = 0, f = 0, t = "flying"},
       },
  ["Nidoran Male"] = {move1 = {name = "Quick Attack", level = 10, cd = 10, dist = 1, target = 1, f = 40, t = "normal"},
        move2 = {name = "Bite", level = 10, cd = 10, dist = 1, target = 1, f = 50, t = "dark"},
        move3 = {name = "Horn Attack", level = 12, cd = 15, dist = 1, target = 1, f = 55, t = "normal"},
        move4 = {name = "Poison Sting", level = 10, cd = 15, dist = 1, target = 1, f = 40, t = "poison"},
        move5 = {name = "Poison Fang", level = 15, cd = 15, dist = 1, target = 1, f = 65, t = "poison"},
       },
  ["Nidorino"] =   {move1 = {name = "Quick Attack", level = 30, cd = 15, dist = 1, target = 1, f = 40, t = "normal"},
        move2 = {name = "Horn Attack", level = 30, cd = 15, dist = 1, target = 1, f = 55, t = "normal"},
        move3 = {name = "Poison Jab", level = 30, cd = 25, dist = 10, target = 1, f = 65, t = "poison"},
        move4 = {name = "Poison Fang", level = 30, cd = 15, dist = 1, target = 1, f = 65, t = "poison"},
        move5 = {name = "Crusher Stomp", level = 32, cd = 45, dist = 1, target = 0, f = 110, t = "ground"},
        move6 = {name = "Cross Poison", level = 32, cd = 40, dist = 1, target = 0, f = 80, t = "poison"},
        move7 = {name = "Rage", level = 30, cd = 20, dist = 1, target = 0, f = 0, t = "dragon"},
       },
  ["Nidoking"] =   {move1 = {name = "Quick Attack", level = 70, cd = 8, dist = 1, target = 1, f = 50, t = "normal"},
        move2 = {name = "Horn Attack", level = 70, cd = 10, dist = 1, target = 1, f = 65, t = "normal"},
        move3 = {name = "Poison Jab", level = 70, cd = 15, dist = 10, target = 1, f = 95, t = "poison"},
        move4 = {name = "Poison Fang", level = 70, cd = 10, dist = 1, target = 1, f = 75, t = "poison"},
        move5 = {name = "Dig", level = 70, cd = 45, dist = 1, target = 0, f = 110, t = "ground"},
        move6 = {name = "Sludge Wave", level = 74, cd = 45, dist = 1, target = 0, f = 95, t = "poison"},
        move7 = {name = "Cross Poison", level = 72, cd = 40, dist = 1, target = 0, f = 80, t = "poison"},
        move8 = {name = "Rage", level = 76, cd = 20, dist = 1, target = 0, f = 0, t = "dragon"},
        move9 = {name = "Fear", level = 70, cd = 30, dist = 1, target = 0, f = 0, t = "ghost"},
       },
  ["Clefairy"] =   {move1 = {name = "Doubleslap", level = 40, cd = 5, dist = 1, target = 1, f = 25, t = "normal"},
        move2 = {name = "Body Slam", level = 44, cd = 20, dist = 1, target = 1, f = 80, t = "normal"},
        move3 = {name = "Sing", level = 40, cd = 30, dist = 1, target = 0, f = 0, t = "normal"},
        move4 = {name = "Multislap", level = 40, cd = 20, dist = 1, target = 0, f = 35, t = "normal"},
        move5 = {name = "Great Love", level = 47, cd = 40, dist = 1, target = 0, f = 50, t = "normal"},
        move6 = {name = "Healarea", level = 45, cd = 80, dist = 1, target = 0, f = 0, t = "normal"},
        move7 = {name = "Metronome", level = 40, cd = 30, dist = 1, target = 0, f = 0, t = "normal"},
        move8 = {name = "Defense Curl", level = 40, cd = 60, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Clefable"] =   {move1 = {name = "Doubleslap", level = 70, cd = 5, dist = 1, target = 1, f = 25, t = "normal"},
        move2 = {name = "Body Slam", level = 74, cd = 20, dist = 1, target = 1, f = 80, t = "normal"},
        move3 = {name = "Sing", level = 70, cd = 40, dist = 1, target = 0, f = 0, t = "normal"},
        move4 = {name = "Multislap", level = 70, cd = 25, dist = 1, target = 0, f = 35, t = "normal"},
        move5 = {name = "Dazzling Gleam", level = 74, cd = 20, dist = 10, target = 1, f = 65, t = "normal"},
        move6 = {name = "Great Love", level = 77, cd = 40, dist = 1, target = 0, f = 50, t = "normal"},
        move7 = {name = "Healarea", level = 75, cd = 80, dist = 1, target = 0, f = 0, t = "normal"},
        move8 = {name = "Metronome", level = 70, cd = 40, dist = 1, target = 0, f = 0, t = "normal"},
        move9 = {name = "Defense Curl", level = 70, cd = 60, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Vulpix"] =     {move1 = {name = "Quick Attack", level = 20, cd = 10, dist = 1, target = 1, f = 40, t = "normal"},
        move2 = {name = "Iron Tail", level = 20, cd = 15, dist = 1, target = 1, f = 70, t = "steel"},
        move3 = {name = "Ember", level = 20, cd = 15, dist = 10, target = 1, f = 42, t = "fire"},
        move4 = {name = "Flamethrower", level = 22, cd = 20, dist = 1, target = 0, f = 80, t = "fire"},
        move5 = {name = "Flame Circle", level = 24, cd = 26, dist = 1, target = 0, f = 85, t = "fire"},
        move6 = {name = "Fire Blast", level = 30, cd = 60, dist = 1, target = 0, f = 120, t = "fire"},
       },
  ["Ninetales"] =  {move1 = {name = "Quick Attack", level = 70, cd = 10, dist = 1, target = 1, f = 40, t = "normal"},
        move2 = {name = "Iron Tail", level = 70, cd = 15, dist = 1, target = 1, f = 70, t = "steel"},
        move3 = {name = "Ember", level = 70, cd = 15, dist = 10, target = 1, f = 42, t = "fire"},
        move4 = {name = "Flamethrower", level = 70, cd = 20, dist = 1, target = 0, f = 80, t = "fire"},
        move5 = {name = "Flame Circle", level = 70, cd = 20, dist = 1, target = 0, f = 85, t = "fire"},
        move6 = {name = "Fireball", level = 70, cd = 20, dist = 10, target = 1, f = 75, t = "fire"},
        move7 = {name = "Confuse Ray", level = 70, cd = 25, dist = 10, target = 1, f = 65, t = "ghost"},
        move8 = {name = "Fire Blast", level = 74, cd = 30, dist = 1, target = 0, f = 105, t = "fire"},
        move9 = {name = "Magma Storm", level = 78, cd = 60, dist = 1, target = 0, f = 150, t = "fire"},
        move10 = {name = "Safeguard", level = 80, cd = 40, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Jigglypuff"] = {move1 = {name = "Doubleslap", level = 40, cd = 5, dist = 1, target = 1, f = 25, t = "normal"},
        move2 = {name = "Body Slam", level = 44, cd = 20, dist = 1, target = 1, f = 80, t = "normal"},
        move3 = {name = "Sing", level = 40, cd = 22, dist = 1, target = 0, f = 0, t = "normal"},
        move4 = {name = "Hyper Voice", level = 40, cd = 20, dist = 1, target = 0, f = 65, t = "normal"},
        move5 = {name = "Multislap", level = 40, cd = 25, dist = 1, target = 0, f = 35, t = "normal"},
        move6 = {name = "Echoed Voice", level = 45, cd = 30, dist = 1, target = 0, f = 85, t = "normal"},
        move7 = {name = "Selfheal", level = 45, cd = 40, dist = 1, target = 0, f = 0, t = "normal"},
          move8 = {name = "Charm", level = 40, cd = 15, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Wigglytuff"] = {move1 = {name = "Doubleslap", level = 70, cd = 5, dist = 1, target = 1, f = 25, t = "normal"},
        move2 = {name = "Body Slam", level = 74, cd = 20, dist = 1, target = 1, f = 80, t = "normal"},
        move3 = {name = "Sing", level = 70, cd = 40, dist = 1, target = 0, f = 0, t = "normal"},
        move4 = {name = "Hyper Voice", level = 70, cd = 15, dist = 1, target = 0, f = 65, t = "normal"},
        move5 = {name = "Multislap", level = 70, cd = 25, dist = 1, target = 0, f = 35, t = "normal"},
        move6 = {name = "Rock n'Roll", level = 74, cd = 60, dist = 1, target = 0, f = 65, t = "normal"},  --alterado v1.5 
        move7 = {name = "Echoed Voice", level = 75, cd = 30, dist = 1, target = 0, f = 85, t = "normal"},
        move8 = {name = "Selfheal", level = 75, cd = 80, dist = 1, target = 0, f = 0, t = "normal"},
          move9 = {name = "Charm", level = 70, cd = 15, dist = 1, target = 0, f = 0, t = "normal"},
        move10 = {name = "Melody", level = 1, cd = 0, dist = 1, target = 0, f = 0, t = "normal", passive = "sim"},
       },
  ["Zubat"] =      {move1 = {name = "Super Sonic", level = 10, cd = 15, dist = 10, target = 1, f = 0, t = "normal"},
        move2 = {name = "Bite", level = 10, cd = 10, dist = 1, target = 1, f = 50, t = "dark"},
        move3 = {name = "Poison Fang", level = 10, cd = 10, dist = 1, target = 1, f = 65, t = "poison"},
        move4 = {name = "Absorb", level = 12, cd = 20, dist = 1, target = 1, f = 40, t = "grass"},
        move5 = {name = "Toxic", level = 15, cd = 20, dist = 1, target = 0, f = 50, t = "poison"},
       },
  ["Golbat"] =     {move1 = {name = "Super Sonic", level = 40, cd = 15, dist = 10, target = 1, f = 0, t = "normal"},
        move2 = {name = "Bite", level = 40, cd = 10, dist = 1, target = 1, f = 50, t = "dark"},
        move3 = {name = "Poison Fang", level = 40, cd = 10, dist = 1, target = 1, f = 65, t = "poison"},
        move4 = {name = "Toxic", level = 40, cd = 20, dist = 1, target = 0, f = 50, t = "poison"},
        move5 = {name = "Whirlwind", level = 40, cd = 22, dist = 1, target = 0, f = 80, t = "flying"},
        move6 = {name = "Wing Attack", level = 40, cd = 30, dist = 1, target = 0, f = 75, t = "flying"},
        move7 = {name = "Air Cutter", level = 44, cd = 40, dist = 1, target = 0, f = 70, t = "flying"},
       },
  ["Oddish"] =     {move1 = {name = "Absorb", level = 7, cd = 15, dist = 1, target = 1, f = 40, t = "grass"},
        move2 = {name = "Acid", level = 1, cd = 10, dist = 10, target = 1, f = 45, t = "poison"},
        move3 = {name = "Leech Seed", level = 1, cd = 15, dist = 10, target = 1, f = 1, t = "grass"},
        move4 = {name = "Sleep Powder", level = 9, cd = 80, dist = 1, target = 0, f = 0, t = "normal"},
        move5 = {name = "Poison Powder", level = 8, cd = 15, dist = 1, target = 0, f = 0, t = "normal"},
        move6 = {name = "Stun Spore", level = 8, cd = 25, dist = 1, target = 0, f = 0, t = "normal"},
        move7 = {name = "Mega Drain", level = 1, cd = 0, dist = 1, target = 0, f = 20, t = "grass", passive = "sim"},
        move8 = {name = "Spores Reaction", level = 1, cd = 0, dist = 1, target = 0, f = 0, t = "normal", passive = "sim"},
       },
  ["Gloom"] =      {move1 = {name = "Absorb", level = 30, cd = 20, dist = 1, target = 1, f = 40, t = "grass"},
            move2 = {name = "Leech Seed", level = 30, cd = 20, dist = 10, target = 1, f = 1, t = "grass"},
        move3 = {name = "Acid", level = 30, cd = 10, dist = 10, target = 1, f = 45, t = "poison"},
        move4 = {name = "Poison Bomb", level = 33, cd = 20, dist = 10, target = 1, f = 70, t = "poison"},
        move5 = {name = "Poison Gas", level = 37, cd = 32, dist = 1, target = 0, f = 5, t = "poison"},
        move6 = {name = "Sleep Powder", level = 30, cd = 80, dist = 1, target = 0, f = 0, t = "normal"},
        move7 = {name = "Stun Spore", level = 30, cd = 25, dist = 1, target = 0, f = 0, t = "normal"},
        move8 = {name = "Poison Powder", level = 30, cd = 20, dist = 1, target = 0, f = 0, t = "normal"},
        move9 = {name = "Mega Drain", level = 1, cd = 0, dist = 1, target = 0, f = 20, t = "grass", passive = "sim"},
        move10 = {name = "Spores Reaction", level = 1, cd = 0, dist = 1, target = 0, f = 0, t = "normal", passive = "sim"},
       },
  ["Vileplume"] =  {move1 = {name = "Absorb", level = 50, cd = 20, dist = 1, target = 1, f = 40, t = "grass"},
        move2 = {name = "Leech Seed", level = 50, cd = 20, dist = 10, target = 1, f = 1, t = "grass"},
        move3 = {name = "Acid", level = 50, cd = 10, dist = 10, target = 1, f = 45, t = "poison"},
        move4 = {name = "Poison Bomb", level = 50, cd = 20, dist = 10, target = 1, f = 70, t = "poison"},
        move5 = {name = "Poison Gas", level = 50, cd = 32, dist = 1, target = 0, f = 5, t = "poison"},
        move6 = {name = "Petal Dance", level = 55, cd = 20, dist = 1, target = 0, f = 70, t = "grass"},
        move7 = {name = "Solar Beam", level = 60, cd = 50, dist = 1, target = 0, f = 190, t = "grass"},
        move8 = {name = "Sleep Powder", level = 50, cd = 80, dist = 1, target = 0, f = 0, t = "normal"},
        move9 = {name = "Stun Spore", level = 50, cd = 25, dist = 1, target = 0, f = 0, t = "normal"},
        move10 = {name = "Poison Powder", level = 50, cd = 20, dist = 1, target = 0, f = 0, t = "normal"},
        move11 = {name = "Mega Drain", level = 1, cd = 0, dist = 1, target = 0, f = 20, t = "grass", passive = "sim"},
        move12 = {name = "Spores Reaction", level = 1, cd = 0, dist = 1, target = 0, f = 0, t = "normal", passive = "sim"},
       },
  ["Paras"] =      {move1 = {name = "Scratch", level = 1, cd = 10, dist = 1, target = 1, f = 40, t = "normal"},
        move2 = {name = "Poison Sting", level = 1, cd = 10, dist = 1, target = 1, f = 40, t = "poison"},
        move3 = {name = "Slash", level = 1, cd = 15, dist = 1, target = 1, f = 60, t = "normal"},
        move4 = {name = "Stun Spore", level = 6, cd = 25, dist = 1, target = 0, f = 0, t = "normal"},
        move5 = {name = "Poison Powder", level = 4, cd = 15, dist = 1, target = 0, f = 0, t = "normal"},
        move6 = {name = "Sleep Powder", level = 8, cd = 80, dist = 1, target = 0, f = 0, t = "normal"},
        move7 = {name = "Mega Drain", level = 1, cd = 0, dist = 1, target = 0, f = 20, t = "grass", passive = "sim"},
        move8 = {name = "Spores Reaction", level = 1, cd = 0, dist = 1, target = 0, f = 0, t = "normal", passive = "sim"},
       },
  ["Parasect"] =   {move1 = {name = "Absorb", level = 50, cd = 20, dist = 1, target = 1, f = 40, t = "grass"},
        move2 = {name = "Scratch", level = 50, cd = 10, dist = 1, target = 1, f = 40, t = "normal"},
        move3 = {name = "Poison Sting", level = 50, cd = 10, dist = 1, target = 1, f = 40, t = "poison"},
        move4 = {name = "Slash", level = 50, cd = 15, dist = 1, target = 1, f = 60, t = "normal"},
        move5 = {name = "Poison Bomb", level = 50, cd = 20, dist = 10, target = 1, f = 70, t = "poison"},
        move6 = {name = "Stun Spore", level = 50, cd = 25, dist = 1, target = 0, f = 0, t = "normal"},
        move7 = {name = "Poison Powder", level = 50, cd = 20, dist = 1, target = 0, f = 0, t = "normal"},
        move8 = {name = "Sleep Powder", level = 50, cd = 80, dist = 1, target = 0, f = 0, t = "normal"},
        move9 = {name = "Fury Cutter", level = 56, cd = 25, dist = 1, target = 0, f = 65, t = "bug"},
        move10 = {name = "X-Scissor", level = 58, cd = 25, dist = 1, target = 0, f = 65, t = "bug"},
        move11 = {name = "Mega Drain", level = 1, cd = 0, dist = 1, target = 0, f = 20, t = "grass", passive = "sim"},
        move12 = {name = "Spores Reaction", level = 1, cd = 0, dist = 1, target = 0, f = 0, t = "normal", passive = "sim"},
       },
  ["Venonat"] =    {move1 = {name = "Super Sonic", level = 20, cd = 15, dist = 10, target = 1, f = 0, t = "normal"},
        move2 = {name = "Psybeam", level = 20, cd = 20, dist = 1, target = 0, f = 75, t = "psychic"},
        move3 = {name = "Silver Wind", level = 20, cd = 25, dist = 10, target = 1, f = 70, t = "bug"}, 
        move4 = {name = "Confusion", level = 20, cd = 25, dist = 1, target = 0, f = 50, t = "psychic"},
        move5 = {name = "Psychic", level = 26, cd = 20, dist = 1, target = 0, f = 90, t = "psychic"},
        move6 = {name = "Sleep Powder", level = 30, cd = 60, dist = 1, target = 0, f = 0, t = "normal"},
        move7 = {name = "Poison Powder", level = 22, cd = 20, dist = 1, target = 0, f = 0, t = "normal"},
        move8 = {name = "Stun Spore", level = 24, cd = 25, dist = 1, target = 0, f = 0, t = "normal"},
        move9 = {name = "Mega Drain", level = 1, cd = 0, dist = 1, target = 0, f = 20, t = "grass", passive = "sim"},
        move10 = {name = "Spores Reaction", level = 1, cd = 0, dist = 1, target = 0, f = 0, t = "normal", passive = "sim"},
       },
  ["Venomoth"] =   {move1 = {name = "Super Sonic", level = 50, cd = 15, dist = 10, target = 1, f = 0, t = "normal"},
        move2 = {name = "Psybeam", level = 50, cd = 20, dist = 1, target = 0, f = 75, t = "psychic"},
        move3 = {name = "Silver Wind", level = 50, cd = 25, dist = 10, target = 1, f = 70, t = "bug"}, 
        move4 = {name = "Confusion", level = 56, cd = 25, dist = 1, target = 0, f = 50, t = "psychic"},
        move5 = {name = "Psychic", level = 50, cd = 20, dist = 1, target = 0, f = 90, t = "psychic"},
        move6 = {name = "Pin Missile", level = 56, cd = 15, dist = 1, target = 0, f = 90, t = "bug"},  
        move7 = {name = "Bug Buzz", level = 54, cd = 20, dist = 1, target = 0, f = 70, t = "bug"},
        move8 = {name = "Sleep Powder", level = 50, cd = 60, dist = 1, target = 0, f = 0, t = "normal"},
        move9 = {name = "Poison Powder", level = 50, cd = 20, dist = 1, target = 0, f = 0, t = "normal"},
        move10 = {name = "Mega Drain", level = 1, cd = 0, dist = 1, target = 0, f = 20, t = "grass", passive = "sim"},
        move11 = {name = "Spores Reaction", level = 1, cd = 0, dist = 1, target = 0, f = 0, t = "normal", passive = "sim"},
       },
  ["Diglett"] =    {move1 = {name = "Sand Attack", level = 10, cd = 15, dist = 1, target = 0, f = 0, t = "ground"},
        move2 = {name = "Slash", level = 10, cd = 10, dist = 1, target = 1, f = 60, t = "normal"},
        move3 = {name = "Mud Shot", level = 10, cd = 15, dist = 10, target = 1, f = 40, t = "ground"},   
        move4 = {name = "Mud Slap", level = 12, cd = 20, dist = 10, target = 1, f = 50, t = "ground"},
        move5 = {name = "Earth Power", level = 15, cd = 40, dist = 1, target = 0, f = 75, t = "ground"},
       },
  ["Dugtrio"] =    {move1 = {name = "Sand Attack", level = 40, cd = 15, dist = 1, target = 0, f = 0, t = "ground"},
        move2 = {name = "Slash", level = 40, cd = 10, dist = 1, target = 1, f = 60, t = "normal"},
        move3 = {name = "Mud Shot", level = 40, cd = 15, dist = 10, target = 1, f = 40, t = "ground"},
        move4 = {name = "Mud Slap", level = 40, cd = 20, dist = 10, target = 1, f = 50, t = "ground"},
        move5 = {name = "Earth Power", level = 40, cd = 40, dist = 1, target = 0, f = 75, t = "ground"},
        move6 = {name = "Bulldoze", level = 42, cd = 35, dist = 1, target = 0, f = 90, t = "ground"},
        move7 = {name = "Earthquake", level = 47, cd = 60, dist = 1, target = 0, f = 10, t = "ground"},
        move8 = {name = "Rage", level = 50, cd = 30, dist = 1, target = 0, f = 0, t = "dragon"},
       },
  ["Meowth"] =     {move1 = {name = "Slash", level = 15, cd = 10, dist = 1, target = 1, f = 60, t = "normal"},
        move2 = {name = "Scratch", level = 15, cd = 10, dist = 1, target = 1, f = 40, t = "normal"},
        move3 = {name = "Bite", level = 15, cd = 15, dist = 1, target = 1, f = 50, t = "dark"},
        move4 = {name = "Night Slash", level = 18, cd = 20, dist = 1, target = 0, f = 70, t = "dark"},
        move5 = {name = "Pay Day", level = 18, cd = 15, dist = 10, target = 1, f = 50, t = "normal"},
       },
  ["Persian"] =    {move1 = {name = "Slash", level = 50, cd = 10, dist = 1, target = 1, f = 60, t = "normal"},
        move2 = {name = "Scratch", level = 50, cd = 10, dist = 1, target = 1, f = 40, t = "normal"},
        move3 = {name = "Bite", level = 50, cd = 15, dist = 1, target = 1, f = 50, t = "dark"},
        move4 = {name = "Fury Swipes", level = 55, cd = 15, dist = 1, target = 1, f = 65, t = "normal"}, 
        move5 = {name = "Night Slash", level = 50, cd = 20, dist = 1, target = 0, f = 70, t = "dark"},
        move6 = {name = "Pay Day", level = 60, cd = 15, dist = 10, target = 1, f = 50, t = "normal"},
        move7 = {name = "Fear", level = 60, cd = 25, dist = 1, target = 0, f = 0, t = "ghost"},
       },
  ["Psyduck"] =    {move1 = {name = "Water Gun", level = 25, cd = 15, dist = 1, target = 0, f = 55, t = "water"},
        move2 = {name = "Aqua Tail", level = 25, cd = 15, dist = 1, target = 1, f = 50, t = "water"},
        move3 = {name = "Waterball", level = 25, cd = 15, dist = 10, target = 1, f = 60, t = "water"},
        move4 = {name = "Confusion", level = 28, cd = 25, dist = 1, target = 0, f = 50, t = "psychic"},
        move5 = {name = "Headbutt", level = 25, cd = 15, dist = 1, target = 1, f = 70, t = "normal"},
        move6 = {name = "Stunning Confusion", level = 1, cd = 0, dist = 10, target = 0, f = 20, t = "psychic", passive = "sim"},
       },
  ["Golduck"] =    {move1 = {name = "Water Gun", level = 70, cd = 20, dist = 1, target = 0, f = 55, t = "water"},
        move2 = {name = "Fury Swipes", level = 70, cd = 15, dist = 1, target = 1, f = 65, t = "normal"}, 
        move3 = {name = "Water Pulse", level = 70, cd = 25, dist = 1, target = 0, f = 70, t = "water"},
        move4 = {name = "Confusion", level = 70, cd = 30, dist = 1, target = 0, f = 50, t = "psychic"},
        move5 = {name = "Psychic", level = 70, cd = 30, dist = 1, target = 0, f = 80, t = "psychic"},
        move6 = {name = "Water Spout", level = 80, cd = 90, dist = 1, target = 0, f = 120, t = "water"},
         move7 = {name = "Hydropump", level = 80, cd = 63, dist = 1, target = 0, f = 120, t = "water"},
        move8 = {name = "Stunning Confusion", level = 1, cd = 0, dist = 10, target = 0, f = 20, t = "psychic", passive = "sim"},
       },
  ["Mankey"] =     {move1 = {name = "Scratch", level = 10, cd = 10, dist = 1, target = 1, f = 40, t = "normal"},
        move2 = {name = "Triple Kick", level = 10, cd = 15, dist = 1, target = 1, f = 60, t = "fighting"},
        move3 = {name = "Karate Chop", level = 13, cd = 20, dist = 1, target = 1, f = 50, t = "fighting"},
        move4 = {name = "Cross Chop", level = 15, cd = 15, dist = 1, target = 0, f = 80, t = "fighting"},
        move5 = {name = "Rage", level = 17, cd = 20, dist = 1, target = 0, f = 0, t = "dragon"},
       },
  ["Primeape"] =   {move1 = {name = "Scratch", level = 50, cd = 10, dist = 1, target = 1, f = 40, t = "normal"},
        move2 = {name = "Triple Kick", level = 50, cd = 15, dist = 1, target = 1, f = 60, t = "fighting"},   
        move3 = {name = "Karate Chop", level = 50, cd = 25, dist = 1, target = 1, f = 50, t = "fighting"},
        move4 = {name = "Cross Chop", level = 54, cd = 20, dist = 1, target = 0, f = 80, t = "fighting"},
        move5 = {name = "Mega Punch", level = 56, cd = 20, dist = 1, target = 1, f = 85, t = "fighting"},
        move6 = {name = "Mega Kick", level = 58, cd = 20, dist = 1, target = 1, f = 85, t = "fighting"},
        move7 = {name = "Rage", level = 50, cd = 25, dist = 1, target = 0, f = 0, t = "dragon"},
        move8 = {name = "Fear", level = 50, cd = 25, dist = 1, target = 0, f = 0, t = "ghost"},
       },
  ["Growlithe"] =  {move1 = {name = "Roar", level = 33, cd = 20, dist = 1, target = 0, f = 0, t = "normal"},
        move2 = {name = "Bite", level = 30, cd = 10, dist = 1, target = 1, f = 50, t = "dark"},
        move3 = {name = "Quick Attack", level = 30, cd = 10, dist = 1, target = 1, f = 40, t = "normal"},
        move4 = {name = "Ember", level = 30, cd = 15, dist = 10, target = 1, f = 42, t = "fire"},
        move5 = {name = "Flamethrower", level = 30, cd = 20, dist = 1, target = 0, f = 80, t = "fire"},
        move6 = {name = "Fireball", level = 32, cd = 20, dist = 10, target = 1, f = 75, t = "fire"},
        move7 = {name = "Tri Flames", level = 34, cd = 45, dist = 1, target = 0, f = 90, t = "fire"},
        move8 = {name = "War Dog", level = 36, cd = 30, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Arcanine"] =   {move1 = {name = "Roar", level = 100, cd = 20, dist = 1, target = 0, f = 0, t = "normal"},
        move2 = {name = "Bite", level = 90, cd = 10, dist = 1, target = 1, f = 50, t = "dark"},
        move3 = {name = "Ember", level = 90, cd = 15, dist = 10, target = 1, f = 42, t = "fire"},
        move4 = {name = "Flamethrower", level = 90, cd = 20, dist = 1, target = 0, f = 80, t = "fire"},
        move5 = {name = "Fireball", level = 90, cd = 20, dist = 10, target = 1, f = 75, t = "fire"},
        move6 = {name = "Fire Fang", level = 90, cd = 25, dist = 1, target = 1, f = 65, t = "fire"},
        move7 = {name = "ExtremeSpeed", level = 90, cd = 20, dist = 10, target = 1, f = 65, t = "normal"},
        move8 = {name = "Fire Blast", level = 92, cd = 60, dist = 1, target = 0, f = 120, t = "fire"},
        move9 = {name = "Tri Flames", level = 94, cd = 45, dist = 1, target = 0, f = 90, t = "fire"},
        move10 = {name = "War Dog", level = 96, cd = 30, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Poliwag"] =    {move1 = {name = "Doubleslap", level = 1, cd = 5, dist = 1, target = 1, f = 25, t = "normal"},
        move2 = {name = "Bubbles", level = 1, cd = 10, dist = 10, target = 1, f = 40, t = "water"},
        move3 = {name = "Water Gun", level = 6, cd = 15, dist = 1, target = 0, f = 55, t = "water"},
        move4 = {name = "Aqua Tail", level = 3, cd = 15, dist = 1, target = 1, f = 50, t = "water"},
        move5 = {name = "Hypnosis", level = 8, cd = 20, dist = 10, target = 1, f = 0, t = "psychic"},
       },
  ["Poliwhirl"] =  {move1 = {name = "Mud Shot", level = 30, cd = 15, dist = 10, target = 1, f = 40, t = "ground"},
        move2 = {name = "Doubleslap", level = 30, cd = 10, dist = 1, target = 1, f = 25, t = "normal"},
        move3 = {name = "Bubbles", level = 30, cd = 15, dist = 10, target = 1, f = 40, t = "water"},
        move4 = {name = "Water Gun", level = 30, cd = 20, dist = 1, target = 0, f = 55, t = "water"},
        move5 = {name = "Ice Beam", level = 30, cd = 25, dist = 1, target = 0, f = 195, t = "ice"},
        move6 = {name = "Hammer Arm", level = 32, cd = 60, dist = 1, target = 0, f = 80, t = "fighting"},
        move7 = {name = "Dynamic Punch", level = 40, cd = 25, dist = 1, target = 0, f = 100, t = "fighting"},
        move8 = {name = "Hypnosis", level = 30, cd = 20, dist = 10, target = 1, f = 0, t = "psychic"},
       },
  ["Poliwrath"] =  {move1 = {name = "Mud Shot", level = 70, cd = 15, dist = 10, target = 1, f = 40, t = "ground"},
        move2 = {name = "Doubleslap", level = 70, cd = 10, dist = 1, target = 1, f = 25, t = "normal"},
        move3 = {name = "Bubblebeam", level = 70, cd = 20, dist = 10, target = 1, f = 60, t = "water"},
        move4 = {name = "Water Gun", level = 70, cd = 20, dist = 1, target = 0, f = 55, t = "water"},
        move5 = {name = "Ice Beam", level = 70, cd = 25, dist = 1, target = 0, f = 195, t = "ice"},
        move6 = {name = "Hammer Arm", level = 72, cd = 60, dist = 1, target = 0, f = 80, t = "fighting"},
        move7 = {name = "Dynamic Punch", level = 80, cd = 25, dist = 1, target = 0, f = 105, t = "fighting"},
        move8 = {name = "Ground Chop", level = 78, cd = 30, dist = 1, target = 0, f = 80, t = "fighting"},
        move9 = {name = "Hypnosis", level = 70, cd = 25, dist = 10, target = 1, f = 0, t = "psychic"},
       },
  ["Abra"] =       {move1 = {name = "Restore", level = 15, cd = 180, dist = 1, target = 0, f = 0, t = "normal"},
        move2 = {name = "Psy Pulse", level = 10, cd = 15, dist = 10, target = 1, f = 35, t = "psychic"},
        move3 = {name = "Psychic", level = 20, cd = 40, dist = 1, target = 0, f = 90, t = "psychic"},
        move4 = {name = "Calm Mind", level = 13, cd = 50, dist = 1, target = 0, f = 0, t = "psychic"},
       },
  ["Kadabra"] =    {move1 = {name = "Psybeam", level = 40, cd = 15, dist = 1, target = 0, f = 75, t = "psychic"},
        move2 = {name = "Psywave", level = 40, cd = 20, dist = 1, target = 0, f = 75, t = "psychic"},
        move3 = {name = "Psy Pulse", level = 40, cd = 15, dist = 10, target = 1, f = 35, t = "psychic"},
        move4 = {name = "Confusion", level = 40, cd = 35, dist = 1, target = 0, f = 50, t = "psychic"},
        move5 = {name = "Psychic", level = 42, cd = 40, dist = 1, target = 0, f = 90, t = "psychic"},
        move6 = {name = "Calm Mind", level = 40, cd = 50, dist = 1, target = 0, f = 0, t = "psychic"},
        move7 = {name = "Hypnosis", level = 40, cd = 80, dist = 10, target = 1, f = 0, t = "psychic"},
        move8 = {name = "Reflect", level = 55, cd = 60, dist = 1, target = 0, f = 0, t = "psychic"},
        move9 = {name = "Restore", level = 45, cd = 180, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Alakazam"] =   {move1 = {name = "Psybeam", level = 80, cd = 15, dist = 1, target = 0, f = 75, t = "psychic"},
        move2 = {name = "Psywave", level = 80, cd = 20, dist = 1, target = 0, f = 75, t = "psychic"},
        move3 = {name = "Psy Pulse", level = 80, cd = 15, dist = 10, target = 1, f = 35, t = "psychic"},
        move4 = {name = "Confusion", level = 80, cd = 35, dist = 1, target = 0, f = 50, t = "psychic"},
        move5 = {name = "Psychic", level = 80, cd = 40, dist = 1, target = 0, f = 90, t = "psychic"},
        move6 = {name = "Psyusion", level = 95, cd = 90, dist = 1, target = 0, f = 70, t = "psychic"},
        move7 = {name = "Calm Mind", level = 80, cd = 50, dist = 1, target = 0, f = 0, t = "psychic"},
        move8 = {name = "Hypnosis", level = 80, cd = 80, dist = 10, target = 1, f = 0, t = "psychic"},
        move9 = {name = "Reflect", level = 85, cd = 60, dist = 1, target = 0, f = 0, t = "psychic"},
        move10 = {name = "Restore", level = 85, cd = 180, dist = 1, target = 0, f = 0, t = "normal"},
        move11 = {name = "Miracle Eye", level = 80, cd = 40, dist = 1, target = 0, f = 0, t = "psychic"},
        move12 = {name = "Mega - Alakazam", level = 1, cd = 0, dist = 10, target = 0, f = 50, t = "ground", mega = 1},	
       },
  ["Mega Alakazam"] =   {move1 = {name = "Psybeam", level = 80, cd = 15, dist = 1, target = 0, f = 75, t = "psychic"},
        move2 = {name = "Psy Pulse", level = 80, cd = 15, dist = 10, target = 1, f = 35, t = "psychic"},
        move3 = {name = "Kinesis", level = 80, cd = 35, dist = 1, target = 0, f = 50, t = "psychic"},
        move4 = {name = "Confusion", level = 80, cd = 35, dist = 1, target = 0, f = 50, t = "psychic"},
        move5 = {name = "Psychic", level = 80, cd = 40, dist = 1, target = 0, f = 90, t = "psychic"},
        move6 = {name = "Psyusion", level = 95, cd = 90, dist = 1, target = 0, f = 70, t = "psychic"},
        move7 = {name = "Calm Mind", level = 90, cd = 50, dist = 1, target = 0, f = 0, t = "psychic"},
        move8 = {name = "Reflect", level = 85, cd = 60, dist = 1, target = 0, f = 0, t = "psychic"},
        move9 = {name = "Restore", level = 85, cd = 180, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Machop"] =     {move1 = {name = "Triple Punch", level = 20, cd = 10, dist = 1, target = 1, f = 60, t = "fighting"},
        move2 = {name = "Mega Punch", level = 20, cd = 15, dist = 1, target = 1, f = 85, t = "fighting"},
        move3 = {name = "Karate Chop", level = 24, cd = 15, dist = 1, target = 1, f = 50, t = "fighting"},
        move4 = {name = "Ground Chop", level = 28, cd = 15, dist = 1, target = 0, f = 100, t = "fighting"},
        move5 = {name = "Strafe", level = 30, cd = 20, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Machoke"] =    {move1 = {name = "Triple Punch", level = 42, cd = 10, dist = 1, target = 1, f = 60, t = "fighting"},
        move2 = {name = "Mega Punch", level = 40, cd = 15, dist = 1, target = 1, f = 85, t = "fighting"},
        move3 = {name = "Mega Kick", level = 44, cd = 15, dist = 1, target = 1, f = 85, t = "fighting"},
        move4 = {name = "Karate Chop", level = 40, cd = 20, dist = 1, target = 1, f = 50, t = "fighting"},
        move5 = {name = "Ground Chop", level = 40, cd = 20, dist = 1, target = 0, f = 100, t = "fighting"},
        move6 = {name = "Hammer Arm", level = 45, cd = 60, dist = 1, target = 0, f = 80, t = "fighting"},
        move7 = {name = "Strafe", level = 48, cd = 20, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Machamp"] =    {move1 = {name = "Triple Punch", level = 80, cd = 15, dist = 1, target = 1, f = 60, t = "fighting"},
        move2 = {name = "Mega Punch", level = 80, cd = 15, dist = 1, target = 1, f = 85, t = "fighting"},
        move3 = {name = "Revenge", level = 82, cd = 40, dist = 1, target = 0, f = 40, t = "fighting"},
        move4 = {name = "Ground Chop", level = 80, cd = 25, dist = 1, target = 0, f = 100, t = "fighting"},
        move5 = {name = "Fist Machine", level = 86, cd = 25, dist = 1, target = 0, f = 105, t = "fighting"},
        move6 = {name = "Destroyer Hand", level = 88, cd = 45, dist = 1, target = 0, f = 90, t = "fighting"},
        move7 = {name = "Dynamic Punch", level = 90, cd = 30, dist = 1, target = 0, f = 80, t = "fighting"},  
        move8 = {name = "Strafe", level = 80, cd = 25, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Bellsprout"] = {move1 = {name = "Razor Leaf", level = 5, cd = 10, dist = 10, target = 1, f = 15, t = "grass"},  
        move2 = {name = "Vine Whip", level = 6, cd = 12, dist = 1, target = 0, f = 30, t = "grass"},
        move3 = {name = "Acid", level = 6, cd = 10, dist = 10, target = 1, f = 30, t = "poison"},
        move4 = {name = "Slash", level = 5, cd = 15, dist = 1, target = 1, f = 35, t = "normal"},
       },
  ["Weepinbell"] = {move1 = {name = "Razor Leaf", level = 20, cd = 10, dist = 10, target = 1, f = 20, t = "grass"},
        move2 = {name = "Vine Whip", level = 20, cd = 15, dist = 1, target = 0, f = 30, t = "grass"},
        move3 = {name = "Acid", level = 20, cd = 10, dist = 10, target = 1, f = 35, t = "poison"},
        move4 = {name = "Poison Bomb", level = 24, cd = 14, dist = 10, target = 1, f = 40, t = "poison"},
        move5 = {name = "Slash", level = 20, cd = 20, dist = 1, target = 1, f = 20, t = "normal"},
        move6 = {name = "Stun Spore", level = 22, cd = 25, dist = 1, target = 0, f = 0, t = "normal"},
        move7 = {name = "Leaf Storm", level = 25, cd = 60, dist = 1, target = 0, f = 50, t = "grass"},
       },
  ["Victreebel"] = {move1 = {name = "Razor Leaf", level = 50, cd = 10, dist = 10, target = 1, f = 33, t = "grass"},
        move2 = {name = "Vine Whip", level = 50, cd = 15, dist = 1, target = 0, f = 65, t = "grass"},
        move3 = {name = "Acid", level = 50, cd = 12, dist = 10, target = 1, f = 45, t = "poison"},
        move4 = {name = "Poison Bomb", level = 50, cd = 20, dist = 10, target = 1, f = 70, t = "poison"},
        move5 = {name = "Slash", level = 50, cd = 20, dist = 1, target = 1, f = 60, t = "normal"},
        move6 = {name = "Stun Spore", level = 50, cd = 25, dist = 1, target = 0, f = 0, t = "normal"},
        move7 = {name = "Poison Powder", level = 50, cd = 20, dist = 1, target = 0, f = 0, t = "normal"},
        move8 = {name = "Sleep Powder", level = 55, cd = 70, dist = 1, target = 0, f = 0, t = "normal"},
        move9 = {name = "Leaf Storm", level = 60, cd = 60, dist = 1, target = 0, f = 150, t = "grass"},
        move10 = {name = "Giga Drain", level = 55, cd = 25, dist = 1, target = 1, f = 120, t = "grass"},
       },
  ["Tentacool"] =  {move1 = {name = "Super Sonic", level = 16, cd = 15, dist = 10, target = 1, f = 0, t = "normal"},
          move2 = {name = "Wrap", level = 10, cd = 20, dist = 10, target = 1, f = 0, t = "normal"}, 
        move3 = {name = "Bubbles", level = 10, cd = 10, dist = 10, target = 1, f = 40, t = "water"},
        move4 = {name = "Poison Jab", level = 10, cd = 16, dist = 10, target = 1, f = 85, t = "poison"},
        move5 = {name = "Acid", level = 10, cd = 15, dist = 10, target = 1, f = 45, t = "poison"},
        move6 = {name = "Waterball", level = 10, cd = 20, dist = 10, target = 1, f = 65, t = "water"},
       },
  ["Tentacruel"] = {move1 = {name = "Super Sonic", level = 80, cd = 15, dist = 10, target = 1, f = 0, t = "normal"},
               move2 = {name = "Wrap", level = 80, cd = 20, dist = 10, target = 1, f = 0, t = "normal"}, 
        move3 = {name = "Bubbles", level = 80, cd = 10, dist = 10, target = 1, f = 40, t = "water"},
        move4 = {name = "Poison Jab", level = 80, cd = 16, dist = 10, target = 1, f = 85, t = "poison"},
        move5 = {name = "Waterball", level = 80, cd = 20, dist = 10, target = 1, f = 65, t = "water"},
        move6 = {name = "Bubblebeam", level = 80, cd = 20, dist = 10, target = 1, f = 60, t = "water"},
        move7 = {name = "Acid", level = 80, cd = 15, dist = 10, target = 1, f = 45, t = "poison"},
        move8 = {name = "Poison Bomb", level = 80, cd = 25, dist = 10, target = 1, f = 70, t = "poison"},
        move9 = {name = "Mortal Gas", level = 88, cd = 45, dist = 1, target = 0, f = 90, t = "poison"},
        move10 = {name = "Hydropump", level = 90, cd = 60, dist = 1, target = 0, f = 125, t = "water"},
       },
  ["Geodude"] =    {move1 = {name = "Rock Throw", level = 10, cd = 10, dist = 10, target = 1, f = 55, t = "rock"},
        move2 = {name = "Rock Slide", level = 10, cd = 15, dist = 10, target = 1, f = 35, t = "rock"},
        move3 = {name = "Stone Edge", level = 13, cd = 20, dist = 10, target = 1, f = 67, t = "rock"}, 
        move4 = {name = "Earth Power", level = 20, cd = 80, dist = 1, target = 0, f = 75, t = "ground"},
        move5 = {name = "Harden", level = 15, cd = 50, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Graveler"] =   {move1 = {name = "Rock Throw", level = 40, cd = 10, dist = 10, target = 1, f = 55, t = "rock"},
        move2 = {name = "Rock Slide", level = 40, cd = 15, dist = 10, target = 1, f = 35, t = "rock"},
        move3 = {name = "Stone Edge", level = 40, cd = 20, dist = 10, target = 1, f = 67, t = "rock"}, 
        move4 = {name = "Earth Power", level = 40, cd = 80, dist = 1, target = 0, f = 75, t = "ground"},
        move5 = {name = "Falling Rocks", level = 50, cd = 100, dist = 1, target = 0, f = 190, t = "rock"},
        move6 = {name = "Harden", level = 45, cd = 50, dist = 1, target = 0, f = 0, t = "normal"},
        move7 = {name = "Selfdestruct", level = 40, cd = 120, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Golem"] =      {move1 = {name = "Rock Throw", level = 70, cd = 10, dist = 10, target = 1, f = 55, t = "rock"},
        move2 = {name = "Rock Slide", level = 70, cd = 15, dist = 10, target = 1, f = 35, t = "rock"},
        move3 = {name = "Stone Edge", level = 70, cd = 20, dist = 10, target = 1, f = 67, t = "rock"}, 
        move4 = {name = "Earth Power", level = 70, cd = 80, dist = 1, target = 0, f = 75, t = "ground"},
        move5 = {name = "Falling Rocks", level = 75, cd = 100, dist = 1, target = 0, f = 190, t = "rock"},
        move6 = {name = "Harden", level = 70, cd = 50, dist = 1, target = 0, f = 0, t = "normal"},
        move7 = {name = "Rollout", level = 70, cd = 60, dist = 1, target = 0, f = 15, t = "rock"},
        move8 = {name = "Selfdestruct", level = 70, cd = 120, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Ponyta"] =     {move1 = {name = "Quick Attack", level = 20, cd = 15, dist = 1, target = 1, f = 40, t = "normal"},
        move2 = {name = "Ember", level = 20, cd = 10, dist = 10, target = 1, f = 40, t = "fire"},
        move3 = {name = "Flamethrower", level = 26, cd = 20, dist = 1, target = 0, f = 80, t = "fire"},
        move4 = {name = "Fireball", level = 23, cd = 25, dist = 10, target = 1, f = 75, t = "fire"},
        move5 = {name = "Stomp", level = 28, cd = 40, dist = 1, target = 0, f = 90, t = "ground"},
       },
  ["Rapidash"] =   {move1 = {name = "Horn Attack", level = 70, cd = 10, dist = 1, target = 1, f = 55, t = "normal"},
        move2 = {name = "Ember", level = 70, cd = 10, dist = 10, target = 1, f = 40, t = "fire"},
        move3 = {name = "Stomp", level = 78, cd = 40, dist = 1, target = 0, f = 90, t = "ground"},
        move4 = {name = "Fireball", level = 73, cd = 20, dist = 10, target = 1, f = 75, t = "fire"},
        move5 = {name = "Flamethrower", level = 76, cd = 20, dist = 1, target = 0, f = 80, t = "fire"},
        move6 = {name = "Fire Blast", level = 70, cd = 60, dist = 1, target = 0, f = 115, t = "fire"},
        move7 = {name = "Inferno", level = 80, cd = 45, dist = 1, target = 0, f = 150, t = "fire"},
        move8 = {name = "Megahorn", level = 77, cd = 35, dist = 1, target = 0, f = 90, t = "bug"},   
       },
  ["Slowpoke"] =   {move1 = {name = "Aqua Tail", level = 10, cd = 10, dist = 1, target = 1, f = 50, t = "water"},
        move2 = {name = "Headbutt", level = 10, cd = 15, dist = 1, target = 1, f = 50, t = "normal"},
        move3 = {name = "Iron Tail", level = 10, cd = 10, dist = 1, target = 1, f = 50, t = "steel"},
        move4 = {name = "Waterball", level = 13, cd = 15, dist = 10, target = 1, f = 65, t = "water"},
        move5 = {name = "Water Gun", level = 15, cd = 19, dist = 1, target = 0, f = 55, t = "water"},
        move6 = {name = "Confusion", level = 20, cd = 25, dist = 1, target = 0, f = 50, t = "psychic"},
       },
  ["Slowbro"] =    {move1 = {name = "Aqua Tail", level = 50, cd = 15, dist = 1, target = 1, f = 50, t = "water"},
        move2 = {name = "Headbutt", level = 50, cd = 10, dist = 1, target = 1, f = 50, t = "normal"},
        move3 = {name = "Iron Tail", level = 50, cd = 10, dist = 1, target = 1, f = 50, t = "steel"},
        move4 = {name = "Waterball", level = 50, cd = 15, dist = 10, target = 1, f = 65, t = "water"},
        move5 = {name = "Water Pulse", level = 50, cd = 25, dist = 1, target = 0, f = 70, t = "water"},
        move6 = {name = "Confusion", level = 50, cd = 25, dist = 1, target = 0, f = 50, t = "psychic"},
        move7 = {name = "Psychic", level = 60, cd = 30, dist = 1, target = 0, f = 90, t = "psychic"},
        move8 = {name = "Yawn", level = 50, cd = 50, dist = 10, target = 1, f = 0, t = "normal"}, 
       },
  ["Magnemite"] =  {move1 = {name = "Super Sonic", level = 10, cd = 35, dist = 10, target = 1, f = 0, t = "normal"},
        move2 = {name = "Thunder Shock", level = 10, cd = 10, dist = 10, target = 1, f = 55, t = "electric"},
        move3 = {name = "Spark", level = 10, cd = 15, dist = 10, target = 1, f = 50, t = "electric"},
        move4 = {name = "Zap Cannon", level = 15, cd = 40, dist = 1, target = 0, f = 80, t = "electric"},
        move5 = {name = "Sonicboom", level = 15, cd = 30, dist = 10, target = 1, f = 55, t = "normal"},
       },
  ["Magneton"] =   {move1 = {name = "Super Sonic", level = 80, cd = 35, dist = 10, target = 1, f = 0, t = "normal"},
        move2 = {name = "Thunder Shock", level = 80, cd = 10, dist = 10, target = 1, f = 55, t = "electric"},
        move3 = {name = "Spark", level = 80, cd = 15, dist = 10, target = 1, f = 50, t = "electric"},
        move4 = {name = "Tri-Attack", level = 95, cd = 25, dist = 10, target = 1, f = 25, t = "normal"},
        move5 = {name = "Thunder", level = 88, cd = 35, dist = 1, target = 0, f = 125, t = "electric"},
        move6 = {name = "Electric Storm", level = 92, cd = 50, dist = 1, target = 0, f = 150, t = "electric"},
        move7 = {name = "Zap Cannon", level = 80, cd = 40, dist = 1, target = 0, f = 80, t = "electric"},
        move8 = {name = "Hyper Beam", level = 65, cd = 25, dist = 1, target = 0, f = 190, t = "normal"},
        move9 = {name = "Sonicboom", level = 60, cd = 30, dist = 10, target = 1, f = 55, t = "normal"},
       },
  ["Farfetch'd"] = {move1 = {name = "Sand Attack", level = 50, cd = 15, dist = 1, target = 0, f = 0, t = "ground"},
        move2 = {name = "Drill Peck", level = 50, cd = 20, dist = 1, target = 1, f = 55, t = "flying"},
        move3 = {name = "Stick Throw", level = 52, cd = 20, dist = 1, target = 0, f = 75, t = "flying"},
        move4 = {name = "Stickslash", level = 51, cd = 25, dist = 1, target = 0, f = 80, t = "flying"},
        move5 = {name = "Stickmerang", level = 54, cd = 15, dist = 10, target = 1, f = 65, t = "flying"},
        move6 = {name = "Night Slash", level = 50, cd = 20, dist = 1, target = 0, f = 70, t = "dark"},
        move7 = {name = "Air Slash", level = 53, cd = 40, dist = 1, target = 0, f = 100, t = "flying"},
        move8 = {name = "Agility", level = 50, cd = 40, dist = 1, target = 0, f = 0, t = "flying"},
       },
  ["Doduo"] =      {move1 = {name = "Sand Attack", level = 10, cd = 15, dist = 1, target = 0, f = 0, t = "ground"},
        move2 = {name = "Quick Attack", level = 10, cd = 10, dist = 1, target = 1, f = 40, t = "normal"},
        move3 = {name = "Drill Peck", level = 11, cd = 15, dist = 1, target = 1, f = 35, t = "flying"},
        move4 = {name = "Rage", level = 15, cd = 20, dist = 1, target = 0, f = 0, t = "dragon"},
        move5 = {name = "Strafe", level = 15, cd = 20, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Dodrio"] =     {move1 = {name = "Sand Attack", level = 50, cd = 15, dist = 1, target = 0, f = 0, t = "ground"},
        move2 = {name = "Quick Attack", level = 50, cd = 10, dist = 1, target = 1, f = 40, t = "normal"},
        move3 = {name = "Drill Peck", level = 50, cd = 20, dist = 1, target = 1, f = 35, t = "flying"},
        move4 = {name = "Pluck", level = 55, cd = 15, dist = 1, target = 1, f = 60, t = "flying"},
        move5 = {name = "Tri-Attack", level = 60, cd = 25, dist = 10, target = 1, f = 25, t = "normal"},
         move6 = {name = "Roost", level = 55, cd = 60, dist = 1, target = 0, f = 0, t = "flying"},
        move7 = {name = "Rage", level = 50, cd = 20, dist = 1, target = 0, f = 0, t = "dragon"},
        move8 = {name = "Strafe", level = 50, cd = 20, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Seel"] =       {move1 = {name = "Headbutt", level = 20, cd = 10, dist = 1, target = 1, f = 50, t = "normal"},
        move2 = {name = "Aqua Tail", level = 20, cd = 10, dist = 1, target = 1, f = 50, t = "water"},
        move3 = {name = "Ice Shards", level = 20, cd = 15, dist = 10, target = 1, f = 65, t = "ice"},
        move4 = {name = "Ice Beam", level = 24, cd = 25, dist = 1, target = 0, f = 195, t = "ice"},
        move5 = {name = "Icy Wind", level = 26, cd = 20, dist = 1, target = 0, f = 45, t = "ice"},
        move6 = {name = "Aurora Beam", level = 30, cd = 25, dist = 1, target = 0, f = 190, t = "ice"},
       },
  ["Dewgong"] =    {move1 = {name = "Aqua Tail", level = 60, cd = 15, dist = 1, target = 1, f = 50, t = "water"},
        move2 = {name = "Headbutt", level = 60, cd = 10, dist = 1, target = 1, f = 50, t = "normal"},
        move3 = {name = "Brine", level = 60, cd = 40, dist = 1, target = 0, f = 100, t = "water"},
        move4 = {name = "Ice Shards", level = 60, cd = 20, dist = 10, target = 1, f = 65, t = "ice"},
        move5 = {name = "Ice Beam", level = 60, cd = 25, dist = 1, target = 0, f = 195, t = "ice"},
        move6 = {name = "Icy Wind", level = 60, cd = 20, dist = 1, target = 0, f = 45, t = "ice"},
        move7 = {name = "Aurora Beam", level = 64, cd = 25, dist = 1, target = 0, f = 190, t = "ice"},
        move8 = {name = "Blizzard", level = 66, cd = 50, dist = 1, target = 0, f = 150, t = "ice"},
        move9 = {name = "Rest", level = 66, cd = 60, dist = 1, target = 0, f = 0, t = "normal"},
        move10 = {name = "Safeguard", level = 70, cd = 40, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Grimer"] =     {move1 = {name = "Mud Shot", level = 10, cd = 15, dist = 10, target = 1, f = 40, t = "ground"},
        move2 = {name = "Acid", level = 10, cd = 10, dist = 10, target = 1, f = 45, t = "poison"},
        move3 = {name = "Sludge", level = 10, cd = 15, dist = 10, target = 1, f = 65, t = "poison"},
        move4 = {name = "Mud Bomb", level = 13, cd = 20, dist = 10, target = 1, f = 60, t = "ground"},
        move5 = {name = "Poison Bomb", level = 15, cd = 25, dist = 10, target = 1, f = 70, t = "poison"},
        move6 = {name = "Harden", level = 17, cd = 30, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Muk"] =        {move1 = {name = "Mud Shot", level = 80, cd = 15, dist = 10, target = 1, f = 40, t = "ground"},
        move2 = {name = "Acid", level = 80, cd = 10, dist = 10, target = 1, f = 45, t = "poison"},
        move3 = {name = "Sludge", level = 80, cd = 20, dist = 10, target = 1, f = 65, t = "poison"},
        move4 = {name = "Mud Bomb", level = 80, cd = 20, dist = 10, target = 1, f = 60, t = "ground"},
        move5 = {name = "Poison Bomb", level = 80, cd = 30, dist = 10, target = 1, f = 70, t = "poison"},
        move6 = {name = "Sludge Rain", level = 92, cd = 60, dist = 1, target = 0, f = 150, t = "poison"},
        move7 = {name = "Sludge Wave", level = 80, cd = 45, dist = 1, target = 0, f = 95, t = "poison"},
        move8 = {name = "Harden", level = 95, cd = 40, dist = 1, target = 0, f = 0, t = "normal"},
        move9 = {name = "Acid Armor", level = 88, cd = 55, dist = 1, target = 0, f = 0, t = "poison"},
       },
  ["Shellder"] =   {move1 = {name = "Lick", level = 10, cd = 15, dist = 2, target = 1, f = 0, t = "normal"},
        move2 = {name = "Super Sonic", level = 17, cd = 15, dist = 10, target = 1, f = 0, t = "normal"},
        move3 = {name = "Clamp", level = 14, cd = 10, dist = 10, target = 1, f = 50, t = "water"},
        move4 = {name = "Bubbles", level = 18, cd = 10, dist = 10, target = 1, f = 40, t = "water"},
        move5 = {name = "Ice Beam", level = 20, cd = 20, dist = 1, target = 0, f = 195, t = "ice"},
        move6 = {name = "Harden", level = 16, cd = 25, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Cloyster"] =   {move1 = {name = "Lick", level = 60, cd = 15, dist = 2, target = 1, f = 0, t = "normal"},
        move2 = {name = "Super Sonic", level = 60, cd = 15, dist = 10, target = 1, f = 0, t = "normal"},
        move3 = {name = "Clamp", level = 60, cd = 15, dist = 10, target = 1, f = 50, t = "water"},
        move4 = {name = "Bubbles", level = 60, cd = 10, dist = 10, target = 1, f = 40, t = "water"},
        move5 = {name = "Ice Beam", level = 60, cd = 20, dist = 1, target = 0, f = 195, t = "ice"},
        move6 = {name = "Aurora Beam", level = 64, cd = 25, dist = 1, target = 0, f = 190, t = "ice"},
        move7 = {name = "Blizzard", level = 68, cd = 50, dist = 1, target = 0, f = 150, t = "ice"},
        move8 = {name = "Harden", level = 62, cd = 30, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Gastly"] =     {move1 = {name = "Lick", level = 20, cd = 40, dist = 3, target = 1, f = 0, t = "normal"},
        move2 = {name = "Shadow Ball", level = 20, cd = 8, dist = 10, target = 1, f = 60, t = "ghost"},
        move3 = {name = "Night Shade", level = 26, cd = 35, dist = 1, target = 0, f = 80, t = "ghost"},
        move4 = {name = "Invisible", level = 24, cd = 20, dist = 1, target = 0, f = 0, t = "ghost"},
        move5 = {name = "Hypnosis", level = 28, cd = 80, dist = 10, target = 1, f = 0, t = "psychic"},
        move5 = {name = "Fear", level = 30, cd = 40, dist = 1, target = 0, f = 0, t = "ghost"},
       },
  ["Haunter"] =    {move1 = {name = "Lick", level = 40, cd = 40, dist = 3, target = 1, f = 0, t = "normal"},
        move2 = {name = "Shadow Ball", level = 40, cd = 10, dist = 10, target = 1, f = 60, t = "ghost"},
        move3 = {name = "Night Shade", level = 40, cd = 35, dist = 1, target = 0, f = 80, t = "ghost"},
        move4 = {name = "Shadow Storm", level = 55, cd = 120, dist = 1, target = 0, f = 95, t = "ghost"},
        move5 = {name = "Invisible", level = 40, cd = 15, dist = 1, target = 0, f = 0, t = "ghost"},
        move6 = {name = "Nightmare", level = 45, cd = 70, dist = 10, target = 1, f = 80, t = "ghost"}, 
        move7 = {name = "Hypnosis", level = 40, cd = 80, dist = 10, target = 1, f = 0, t = "psychic"},
        move8 = {name = "Fear", level = 40, cd = 40, dist = 1, target = 0, f = 0, t = "ghost"},
        move9 = {name = "Dark Eye", level = 40, cd = 35, dist = 1, target = 0, f = 0, t = "ghost"},
       },
  ["Gengar"] =     {move1 = {name = "Lick", level = 80, cd = 40, dist = 1, target = 1, f = 0, t = "normal"},
        move2 = {name = "Shadow Ball", level = 80, cd = 15, dist = 10, target = 1, f = 60, t = "ghost"},
        move3 = {name = "Shadow Punch", level = 84, cd = 40, dist = 1, target = 1, f = 75, t = "ghost"},
        move4 = {name = "Night Shade", level = 80, cd = 35, dist = 1, target = 0, f = 80, t = "ghost"},
        move5 = {name = "Shadow Storm", level = 86, cd = 120, dist = 1, target = 0, f = 95, t = "ghost"},
        move6 = {name = "Invisible", level = 80, cd = 15, dist = 1, target = 0, f = 0, t = "ghost"},
        move7 = {name = "Nightmare", level = 80, cd = 70, dist = 10, target = 1, f = 80, t = "ghost"},
        move8 = {name = "Hypnosis", level = 80, cd = 80, dist = 10, target = 1, f = 0, t = "psychic"},
        move9 = {name = "Fear", level = 80, cd = 40, dist = 1, target = 0, f = 0, t = "ghost"},
        move10 = {name = "Dark Eye", level = 80, cd = 35, dist = 1, target = 0, f = 0, t = "ghost"},
       },
  ["Onix"] =       {move1 = {name = "Sand Attack", level = 50, cd = 15, dist = 1, target = 0, f = 0, t = "ground"},
        move2 = {name = "Iron Tail", level = 50, cd = 10, dist = 1, target = 1, f = 70, t = "steel"},  --alterado v1.9
        move3 = {name = "Rock Throw", level = 50, cd = 10, dist = 10, target = 1, f = 55, t = "rock"},
        move4 = {name = "Rock Slide", level = 50, cd = 15, dist = 10, target = 1, f = 35, t = "rock"},
        move5 = {name = "Earth Power", level = 50, cd = 30, dist = 1, target = 0, f = 75, t = "ground"},
        move6 = {name = "Falling Rocks", level = 58, cd = 50, dist = 1, target = 0, f = 190, t = "rock"},
        move7 = {name = "Earthquake", level = 62, cd = 45, dist = 1, target = 0, f = 15, t = "ground"},
        move8 = {name = "Harden", level = 50, cd = 35, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Drowzee"] =    {move1 = {name = "Headbutt", level = 30, cd = 10, dist = 1, target = 1, f = 50, t = "normal"},
        move2 = {name = "Psybeam", level = 30, cd = 15, dist = 1, target = 0, f = 75, t = "psychic"},
        move3 = {name = "Confusion", level = 32, cd = 25, dist = 1, target = 0, f = 50, t = "psychic"},
        move4 = {name = "Dream Eater", level = 35, cd = 25, dist = 10, target = 1, f = 80, t = "psychic"},
        move5 = {name = "Hypnosis", level = 35, cd = 40, dist = 10, target = 1, f = 0, t = "psychic"},
        move6 = {name = "Focus", level = 37, cd = 30, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Hypno"] =      {move1 = {name = "Psy Pulse", level = 50, cd = 15, dist = 10, target = 1, f = 35, t = "psychic"},
        move2 = {name = "Psywave", level = 50, cd = 15, dist = 1, target = 0, f = 75, t = "psychic"},
        move3 = {name = "Psybeam", level = 50, cd = 15, dist = 1, target = 0, f = 75, t = "psychic"},
        move4 = {name = "Confusion", level = 50, cd = 25, dist = 1, target = 0, f = 50, t = "psychic"},
        move5 = {name = "Psychic", level = 53, cd = 30, dist = 1, target = 0, f = 80, t = "psychic"},
        move6 = {name = "Dream Eater", level = 56, cd = 30, dist = 10, target = 1, f = 80, t = "psychic"},
        move7 = {name = "Hypnosis", level = 55, cd = 40, dist = 10, target = 1, f = 0, t = "psychic"},
        move8 = {name = "Focus", level = 65, cd = 30, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Krabby"] =     {move1 = {name = "Bubbles", level = 10, cd = 10, dist = 10, target = 1, f = 40, t = "water"},
        move2 = {name = "Bubblebeam", level = 12, cd = 20, dist = 10, target = 1, f = 40, t = "water"},
        move3 = {name = "Mud Shot", level = 10, cd = 20, dist = 10, target = 1, f = 40, t = "ground"},
        move4 = {name = "Crabhammer", level = 15, cd = 25, dist = 1, target = 1, f = 60, t = "normal"},
        move5 = {name = "Harden", level = 13, cd = 80, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Kingler"] =    {move1 = {name = "Bubbles", level = 40, cd = 10, dist = 10, target = 1, f = 40, t = "water"},
        move2 = {name = "Bubblebeam", level = 40, cd = 20, dist = 10, target = 1, f = 40, t = "water"},
        move3 = {name = "Mud Shot", level = 40, cd = 20, dist = 10, target = 1, f = 40, t = "ground"},
        move4 = {name = "Crabhammer", level = 40, cd = 30, dist = 1, target = 1, f = 60, t = "normal"},
        move5 = {name = "Metal Claw", level = 45, cd = 15, dist = 1, target = 1, f = 60, t = "steel"},   
        move6 = {name = "Brine", level = 40, cd = 40, dist = 1, target = 0, f = 100, t = "water"},
        move7 = {name = "Hyper Beam", level = 49, cd = 25, dist = 1, target = 0, f = 190, t = "normal"},
        move8 = {name = "Guillotine", level = 50, cd = 20, dist = 1, target = 1, f = 70, t = "normal"},
        move9 = {name = "Harden", level = 40, cd = 80, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Voltorb"] =    {move1 = {name = "Thunder Shock", level = 10, cd = 10, dist = 10, target = 1, f = 55, t = "electric"},
        move2 = {name = "Spark", level = 0, cd = 15, dist = 10, target = 1, f = 50, t = "electric"},
        move3 = {name = "Thunder Wave", level = 12, cd = 25, dist = 1, target = 0, f = 70, t = "electric"},
        move4 = {name = "Rollout", level = 15, cd = 60, dist = 1, target = 0, f = 15, t = "rock"},
        move5 = {name = "Selfdestruct", level = 10, cd = 120, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Electrode"] =  {move1 = {name = "Thunder Shock", level = 40, cd = 10, dist = 10, target = 1, f = 55, t = "electric"},
        move2 = {name = "Spark", level = 40, cd = 15, dist = 10, target = 1, f = 50, t = "electric"},
        move3 = {name = "Thunder Wave", level = 40, cd = 14, dist = 1, target = 0, f = 70, t = "electric"},
        move4 = {name = "Rollout", level = 40, cd = 45, dist = 1, target = 0, f = 15, t = "rock"},
        move5 = {name = "Charge Beam", level = 40, cd = 30, dist = 1, target = 0, f = 80, t = "electric"},
        move6 = {name = "Electric Storm", level = 45, cd = 60, dist = 1, target = 0, f = 150, t = "electric"},
        move7 = {name = "Selfdestruct", level = 40, cd = 120, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Exeggcute"] =  {move1 = {name = "Hypnosis", level = 14, cd = 15, dist = 10, target = 1, f = 0, t = "psychic"},
        move2 = {name = "Leech Seed", level = 10, cd = 18, dist = 10, target = 1, f = 1, t = "grass"},
        move3 = {name = "Egg Bomb", level = 10, cd = 10, dist = 10, target = 1, f = 70, t = "normal"},
        move4 = {name = "Confusion", level = 16, cd = 15, dist = 1, target = 0, f = 50, t = "psychic"},
       },
  ["Exeggutor"] =  {move1 = {name = "Seed Bomb", level = 80, cd = 30, dist = 1, target = 0, f = 125, t = "grass"},
        move2 = {name = "Egg Bomb", level = 80, cd = 10, dist = 10, target = 1, f = 80, t = "normal"},
        move3 = {name = "Leaf Blade", level = 80, cd = 15, dist = 10, target = 1, f = 60, t = "grass"},
        move4 = {name = "Confusion", level = 80, cd = 30, dist = 1, target = 0, f = 60, t = "psychic"},    --alterado v1.6
        move5 = {name = "Psyshock", level = 88, cd = 35, dist = 1, target = 0, f = 75, t = "psychic"},
        move6 = {name = "Bullet Seed", level = 80, cd = 45, dist = 1, target = 0, f = 95, t = "grass"},
        move7 = {name = "Solar Beam", level = 84, cd = 60, dist = 1, target = 0, f = 190, t = "grass"},
        move8 = {name = "Leaf Storm", level = 95, cd = 80, dist = 1, target = 0, f = 150, t = "grass"},
        move9 = {name = "Hypnosis", level = 80, cd = 60, dist = 10, target = 1, f = 0, t = "psychic"},
       },
  ["Cubone"] =     {move1 = {name = "Headbutt", level = 20, cd = 10, dist = 1, target = 1, f = 50, t = "normal"},
        move2 = {name = "Bonemerang", level = 20, cd = 15, dist = 10, target = 1, f = 60, t = "ground"},
        move3 = {name = "Bone Club", level = 22, cd = 20, dist = 10, target = 1, f = 70, t = "ground"},
        move4 = {name = "Bone Slash", level = 27, cd = 25, dist = 1, target = 0, f = 75, t = "ground"},
        move5 = {name = "Rage", level = 32, cd = 20, dist = 1, target = 0, f = 0, t = "dragon"},
        move6 = {name = "Bone-Spin", level = 1, cd = 0, dist = 10, target = 0, f = 50, t = "ground", passive = "sim"},
       },
  ["Marowak"] =    {move1 = {name = "Mud Shot", level = 50, cd = 15, dist = 10, target = 1, f = 40, t = "ground"},
        move2 = {name = "Headbutt", level = 50, cd = 10, dist = 1, target = 1, f = 50, t = "normal"},
        move3 = {name = "Bonemerang", level = 50, cd = 15, dist = 10, target = 1, f = 60, t = "ground"},
        move4 = {name = "Bone Club", level = 50, cd = 20, dist = 10, target = 1, f = 70, t = "ground"},
        move5 = {name = "Bone Rush", level = 50, cd = 25, dist = 1, target = 0, f = 60, t = "ground"},
        move6 = {name = "Earth Power", level = 54, cd = 30, dist = 1, target = 0, f = 75, t = "ground"},
        move7 = {name = "Bulldoze", level = 56, cd = 35, dist = 1, target = 0, f = 90, t = "ground"},
        move8 = {name = "Rage", level = 60, cd = 25, dist = 1, target = 0, f = 0, t = "dragon"},
        move9 = {name = "Bone-Spin", level = 1, cd = 0, dist = 10, target = 0, f = 50, t = "ground", passive = "sim"},
       },
  ["Hitmonlee"] =  {move1 = {name = "Triple Kick Lee", level = 60, cd = 15, dist = 1, target = 1, f = 70, t = "fighting"},
        move2 = {name = "Mega Kick", level = 60, cd = 20, dist = 1, target = 1, f = 85, t = "fighting"},
        move3 = {name = "Multi-Kick", level = 65, cd = 25, dist = 1, target = 0, f = 75, t = "fighting"},
        move4 = {name = "Furious Legs", level = 60, cd = 30, dist = 1, target = 0, f = 0, t = "fighting"},
        move5 = {name = "Demon Kicker", level = 1, cd = 0, dist = 1, target = 1, f = 45, t = "fighting", passive = "sim"},
       },
  ["Hitmonchan"] = {move1 = {name = "Triple Punch", level = 60, cd = 15, dist = 1, target = 1, f = 70, t = "fighting"},
        move2 = {name = "Mega Punch", level = 60, cd = 20, dist = 1, target = 1, f = 85, t = "fighting"},
        move3 = {name = "Multi-Punch", level = 65, cd = 25, dist = 1, target = 0, f = 75, t = "fighting"},
        move4 = {name = "Ultimate Champion", level = 60, cd = 30, dist = 1, target = 0, f = 0, t = "fighting"},
        move5 = {name = "Elemental Hands", level = 60, cd = 1, dist = 1, target = 0, f = 0, t = "fighting"},
        move6 = {name = "Demon Puncher", level = 1, cd = 0, dist = 1, target = 1, f = 45, t = "unknow", passive = "sim"},
       },
  ["Lickitung"] =  {move1 = {name = "Lick", level = 60, cd = 15, dist = 1, target = 1, f = 0, t = "normal"},
        move2 = {name = "Shadow Ball", level = 60, cd = 8, dist = 10, target = 1, f = 60, t = "ghost"},
        move3 = {name = "Headbutt", level = 60, cd = 15, dist = 1, target = 1, f = 50, t = "normal"},
        move4 = {name = "Body Slam", level = 64, cd = 10, dist = 1, target = 1, f = 80, t = "normal"},
        move5 = {name = "Mega Punch", level = 60, cd = 20, dist = 1, target = 1, f = 85, t = "fighting"},
        move6 = {name = "Iron Tail", level = 60, cd = 20, dist = 1, target = 1, f = 70, t = "steel"},
        move7 = {name = "Squisky Licking", level = 65, cd = 35, dist = 1, target = 0, f = 100, t = "normal"},
        move8 = {name = "Super Sonic", level = 60, cd = 20, dist = 10, target = 1, f = 0, t = "normal"},
        move9 = {name = "Defense Curl", level = 60, cd = 35, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Koffing"] =    {move1 = {name = "Mud Shot", level = 10, cd = 15, dist = 10, target = 1, f = 40, t = "ground"},
        move2 = {name = "Acid", level = 10, cd = 10, dist = 10, target = 1, f = 45, t = "poison"},
        move3 = {name = "Headbutt", level = 10, cd = 15, dist = 1, target = 1, f = 50, t = "normal"},
        move4 = {name = "Mud Bomb", level = 13, cd = 25, dist = 10, target = 1, f = 50, t = "ground"},
        move5 = {name = "Poison Bomb", level = 15, cd = 25, dist = 10, target = 1, f = 70, t = "poison"},
        move6 = {name = "Poison Gas", level = 15, cd = 32, dist = 1, target = 0, f = 5, t = "poison"},
        move7 = {name = "Selfdestruct", level = 10, cd = 120, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Weezing"] =    {move1 = {name = "Mud Shot", level = 50, cd = 15, dist = 10, target = 1, f = 40, t = "ground"},
        move2 = {name = "Acid", level = 50, cd = 10, dist = 10, target = 1, f = 45, t = "poison"},
        move3 = {name = "Headbutt", level = 50, cd = 15, dist = 1, target = 1, f = 50, t = "normal"},
        move4 = {name = "Mud Bomb", level = 52, cd = 25, dist = 10, target = 1, f = 50, t = "ground"},
        move5 = {name = "Poison Bomb", level = 55, cd = 25, dist = 10, target = 1, f = 70, t = "poison"},
        move6 = {name = "Poison Gas", level = 50, cd = 32, dist = 1, target = 0, f = 5, t = "poison"},
        move7 = {name = "Mortal Gas", level = 60, cd = 45, dist = 1, target = 0, f = 90, t = "poison"},
        move8 = {name = "Selfdestruct", level = 52, cd = 120, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Rhyhorn"] =    {move1 = {name = "Horn Attack", level = 30, cd = 25, dist = 2, target = 1, f = 70, t = "normal"},
        move2 = {name = "Stone Edge", level = 30, cd = 20, dist = 10, target = 1, f = 67, t = "rock"}, 
        move3 = {name = "Rock Throw", level = 30, cd = 25, dist = 10, target = 1, f = 55, t = "rock"},
        move4 = {name = "Crusher Stomp", level = 32, cd = 45, dist = 1, target = 0, f = 110, t = "ground"},
        move5 = {name = "Bulldoze", level = 33, cd = 45, dist = 1, target = 0, f = 90, t = "ground"},
        move6 = {name = "Rock Drill", level = 37, cd = 35, dist = 10, target = 1, f = 90, t = "rock"},
       },
  ["Rhydon"] =     {move1 = {name = "Horn Attack", level = 80, cd = 25, dist = 2, target = 1, f = 70, t = "normal"},
        move2 = {name = "Stone Edge", level = 80, cd = 20, dist = 10, target = 1, f = 67, t = "rock"}, 
        move3 = {name = "Rock Throw", level = 80, cd = 25, dist = 10, target = 1, f = 55, t = "rock"},
        move4 = {name = "Crusher Stomp", level = 85, cd = 45, dist = 1, target = 0, f = 110, t = "ground"},
        move5 = {name = "Horn Drill", level = 80, cd = 30, dist = 2, target = 1, f = 60, t = "normal"},
        move6 = {name = "Bulldoze", level = 83, cd = 50, dist = 1, target = 0, f = 90, t = "ground"},
        move7 = {name = "Hammer Arm", level = 80, cd = 60, dist = 1, target = 0, f = 80, t = "fighting"},
        move8 = {name = "Falling Rocks", level = 85, cd = 80, dist = 1, target = 0, f = 190, t = "rock"},
        move9 = {name = "Rock Drill", level = 87, cd = 35, dist = 1, target = 0, f = 90, t = "rock"},
       },
  ["Chansey"] =    {move1 = {name = "Doubleslap", level = 60, cd = 5, dist = 1, target = 1, f = 25, t = "normal"},
        move2 = {name = "Egg Bomb", level = 60, cd = 10, dist = 10, target = 1, f = 70, t = "normal"},
        move3 = {name = "Great Love", level = 68, cd = 60, dist = 1, target = 0, f = 50, t = "normal"},          
        move4 = {name = "Sing", level = 60, cd = 40, dist = 1, target = 0, f = 0, t = "normal"},
        move5 = {name = "Healarea", level = 60, cd = 80, dist = 1, target = 0, f = 0, t = "normal"},
        move6 = {name = "Harden", level = 66, cd = 30, dist = 1, target = 0, f = 0, t = "normal"},             --fazer protection
        move7 = {name = "Egg Rain", level = 70, cd = 50, dist = 1, target = 0, f = 150, t = "normal"},
       },
  ["Tangela"] =    {move1 = {name = "Absorb", level = 50, cd = 15, dist = 1, target = 1, f = 40, t = "grass"},
        move2 = {name = "Leech Seed", level = 50, cd = 10, dist = 10, target = 1, f = 1, t = "grass"},
        move3 = {name = "Vine Whip", level = 50, cd = 8, dist = 1, target = 0, f = 65, t = "grass"},
        move4 = {name = "Super Vines", level = 57, cd = 22, dist = 1, target = 0, f = 95, t = "grass"},
        move5 = {name = "Poison Powder", level = 50, cd = 10, dist = 1, target = 0, f = 0, t = "normal"},
        move6 = {name = "Sleep Powder", level = 55, cd = 80, dist = 1, target = 0, f = 0, t = "normal"},
        move7 = {name = "Stun Spore", level = 50, cd = 30, dist = 1, target = 0, f = 0, t = "normal"},
        move8 = {name = "Mega Drain", level = 1, cd = 0, dist = 10, target = 0, f = 20, t = "grass", passive = "sim"},
        move9 = {name = "Spores Reaction", level = 1, cd = 0, dist = 10, target = 0, f = 0, t = "normal", passive = "sim"},
       },
  ["Kangaskhan"] = {move1 = {name = "Bite", level = 80, cd = 15, dist = 1, target = 1, f = 40, t = "dark"},
        move2 = {name = "Dizzy Punch", level = 80, cd = 25, dist = 1, target = 1, f = 75, t = "normal"},
        move3 = {name = "Headbutt", level = 80, cd = 15, dist = 1, target = 1, f = 50, t = "normal"},
        move4 = {name = "Mega Punch", level = 80, cd = 25, dist = 1, target = 1, f = 85, t = "fighting"},
        move5 = {name = "Crunch", level = 80, cd = 10, dist = 1, target = 0, f = 65, t = "dark"},
               move6 = {name = "Sucker Punch", level = 83, cd = 20, dist = 1, target = 1, f = 65, t = "dark"},
        move7 = {name = "Hammer Arm", level = 80, cd = 40, dist = 1, target = 0, f = 85, t = "fighting"},
        move8 = {name = "Epicenter", level = 95, cd = 50, dist = 1, target = 0, f = 150, t = "ground"},
        move9 = {name = "Rage", level = 80, cd = 40, dist = 1, target = 0, f = 0, t = "dragon"},
        move10 = {name = "Counter Helix", level = 1, cd = 0, dist = 10, target = 0, f = 55, t = "ground", passive = "sim"},
        move11 = {name = "Mega - Kangaskhan", level = 0, cd = 0, dist = 1, target = 0, f = 0, t = "ground", mega = 1},
       },
  ["Horsea"] =     {move1 = {name = "Mud Shot", level = 10, cd = 15, dist = 10, target = 1, f = 40, t = "ground"},
        move2 = {name = "Bubbles", level = 10, cd = 10, dist = 10, target = 1, f = 40, t = "water"},
        move3 = {name = "Bubblebeam", level = 15, cd = 20, dist = 10, target = 1, f = 40, t = "water"},
        move4 = {name = "Water Gun", level = 12, cd = 20, dist = 1, target = 0, f = 55, t = "water"},
        move5 = {name = "Waterball", level = 10, cd = 15, dist = 10, target = 1, f = 60, t = "water"},
       },
  ["Seadra"] =     {move1 = {name = "Mud Shot", level = 40, cd = 15, dist = 10, target = 1, f = 40, t = "ground"},
        move2 = {name = "SmokeScreen", level = 40, cd = 40, dist = 1, target = 0, f = 0, t = "normal"},
        move3 = {name = "Quick Attack", level = 40, cd = 10, dist = 2, target = 1, f = 40, t = "normal"},
        move4 = {name = "Bubbles", level = 40, cd = 15, dist = 10, target = 1, f = 40, t = "water"},
        move5 = {name = "Bubblebeam", level = 40, cd = 20, dist = 10, target = 1, f = 40, t = "water"},
        move6 = {name = "Water Gun", level = 40, cd = 25, dist = 1, target = 0, f = 55, t = "water"},
        move7 = {name = "Dragon Pulse", level = 45, cd = 45, dist = 1, target = 0, f = 60, t = "dragon"},
        move8 = {name = "Hydro Cannon", level = 50, cd = 35, dist = 1, target = 0, f = 95, t = "water"},
       },
  ["Goldeen"] =    {move1 = {name = "Super Sonic", level = 18, cd = 20, dist = 10, target = 1, f = 0, t = "normal"},
        move2 = {name = "Horn Attack", level = 10, cd = 10, dist = 2, target = 1, f = 60, t = "normal"},
        move3 = {name = "Poison Sting", level = 10, cd = 10, dist = 2, target = 1, f = 40, t = "poison"},
        move4 = {name = "Water Gun", level = 12, cd = 15, dist = 1, target = 0, f = 55, t = "water"},
        move5 = {name = "Water Pulse", level = 15, cd = 25, dist = 1, target = 0, f = 70, t = "water"},
        move6 = {name = "Aqua Tail", level = 12, cd = 15, dist = 1, target = 1, f = 50, t = "water"},
       },
  ["Seaking"] =    {move1 = {name = "Super Sonic", level = 40, cd = 20, dist = 10, target = 1, f = 0, t = "normal"},
        move2 = {name = "Horn Attack", level = 40, cd = 10, dist = 2, target = 1, f = 60, t = "normal"},
        move3 = {name = "Poison Sting", level = 40, cd = 10, dist = 2, target = 1, f = 40, t = "poison"},
        move4 = {name = "Water Gun", level = 40, cd = 15, dist = 1, target = 0, f = 55, t = "water"},
        move5 = {name = "Water Pulse", level = 40, cd = 20, dist = 1, target = 0, f = 70, t = "water"},
        move6 = {name = "Aqua Tail", level = 40, cd = 20, dist = 1, target = 1, f = 50, t = "water"},
        move7 = {name = "Horn Drill", level = 48, cd = 20, dist = 2, target = 1, f = 60, t = "normal"},
        move8 = {name = "Rock Drill", level = 47, cd = 35, dist = 10, target = 1, f = 95, t = "rock"},
       },
  ["Staryu"] =     {move1 = {name = "Swift", level = 20, cd = 10, dist = 10, target = 1, f = 25, t = "normal"},
        move2 = {name = "Water Gun", level = 20, cd = 20, dist = 1, target = 0, f = 55, t = "water"},
        move3 = {name = "Bubblebeam", level = 23, cd = 20, dist = 10, target = 1, f = 40, t = "water"},
        move4 = {name = "Psyshock", level = 28, cd = 35, dist = 1, target = 0, f = 65, t = "psychic"},
        move5 = {name = "Psychic", level = 20, cd = 30, dist = 1, target = 0, f = 80, t = "psychic"},
        move6 = {name = "Harden", level = 20, cd = 25, dist = 1, target = 0, f = 0, t = "normal"},
        move7 = {name = "Restore", level = 25, cd = 30, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Starmie"] =    {move1 = {name = "Swift", level = 80, cd = 20, dist = 10, target = 1, f = 30, t = "normal"},
        move2 = {name = "Water Gun", level = 80, cd = 20, dist = 1, target = 0, f = 55, t = "water"},
        move3 = {name = "Confuse Ray", level = 80, cd = 25, dist = 10, target = 1, f = 65, t = "ghost"},
        move4 = {name = "Bubblebeam", level = 80, cd = 20, dist = 10, target = 1, f = 40, t = "water"},
        move5 = {name = "Psyshock", level = 88, cd = 35, dist = 1, target = 0, f = 65, t = "psychic"},
        move6 = {name = "Psychic", level = 80, cd = 30, dist = 1, target = 0, f = 80, t = "psychic"},
        move7 = {name = "Harden", level = 80, cd = 25, dist = 1, target = 0, f = 0, t = "normal"},
        move8 = {name = "Hydropump", level = 85, cd = 60, dist = 1, target = 0, f = 125, t = "water"},
        move9 = {name = "Magic Coat", level = 80, cd = 40, dist = 1, target = 0, f = 0, t = "psychic"}, 
        move10 = {name = "Restore", level = 85, cd = 120, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Mr. Mime"] =   {move1 = {name = "Doubleslap", level = 70, cd = 10, dist = 1, target = 1, f = 25, t = "normal"},
                move2 = {name = "Psywave", level = 70, cd = 15, dist = 1, target = 0, f = 75, t = "psychic"},
                move3 = {name = "Magical Leaf", level = 70, cd = 15, dist = 10, target = 1, f = 35, t = "grass"},
        move4 = {name = "Confusion", level = 70, cd = 35, dist = 1, target = 0, f = 50, t = "psychic"},
        move5 = {name = "Psychic", level = 70, cd = 30, dist = 1, target = 0, f = 90, t = "psychic"},
        move6 = {name = "Psyusion", level = 85, cd = 60, dist = 1, target = 0, f = 70, t = "psychic"},
        move7 = {name = "Ice Punch", level = 70, cd = 25, dist = 1, target = 1, f = 75, t = "ice"},
        move8 = {name = "Reflect", level = 70, cd = 35, dist = 1, target = 0, f = 0, t = "psychic"},
        move9 = {name = "Mimic Wall", level = 70, cd = 3, dist = 1, target = 0, f = 0, t = "psychic"},
        move10 = {name = "Miracle Eye", level = 70, cd = 40, dist = 1, target = 0, f = 0, t = "psychic"},
       },
  ["Scyther"] =    {move1 = {name = "Quick Attack", level = 80, cd = 10, dist = 2, target = 1, f = 40, t = "normal"},
        move2 = {name = "Slash", level = 80, cd = 25, dist = 1, target = 1, f = 60, t = "normal"},
        move3 = {name = "Wing Attack", level = 80, cd = 35, dist = 1, target = 0, f = 75, t = "flying"},
        move4 = {name = "Fury Cutter", level = 85, cd = 15, dist = 1, target = 0, f = 65, t = "bug"},
        move5 = {name = "Shredder Team", level = 95, cd = 40, dist = 1, target = 0, f = 0, t = "normal"},
        move6 = {name = "Air Slash", level = 83, cd = 40, dist = 1, target = 0, f = 100, t = "flying"},
        move7 = {name = "Agility", level = 80, cd = 40, dist = 1, target = 0, f = 0, t = "flying"},
        move8 = {name = "Team Slice", level = 95, cd = 7, dist = 10, target = 1, f = 80, t = "bug"},
        move9 = {name = "Counter Helix", level = 1, cd = 0, dist = 10, target = 0, f = 55, t = "bug", passive = "sim"},
       },
  ["Jynx"] =       {move1 = {name = "Lovely Kiss", level = 80, cd = 15, dist = 10, target = 1, f = 0, t = "normal"},
        move2 = {name = "Doubleslap", level = 80, cd = 10, dist = 1, target = 1, f = 25, t = "normal"},
        move3 = {name = "Psywave", level = 80, cd = 20, dist = 1, target = 0, f = 75, t = "psychic"},
        move4 = {name = "Psy Pulse", level = 80, cd = 15, dist = 10, target = 1, f = 35, t = "psychic"},
        move5 = {name = "Ice Punch", level = 80, cd = 25, dist = 1, target = 1, f = 75, t = "ice"},
        move6 = {name = "Ice Beam", level = 80, cd = 25, dist = 1, target = 0, f = 195, t = "ice"},
        move7 = {name = "Icy Wind", level = 80, cd = 35, dist = 1, target = 0, f = 45, t = "ice"},
        move8 = {name = "Aurora Beam", level = 84, cd = 20, dist = 1, target = 0, f = 190, t = "ice"},
        move9 = {name = "Blizzard", level = 86, cd = 60, dist = 1, target = 0, f = 150, t = "ice"},
        move10 = {name = "Great Love", level = 88, cd = 50, dist = 1, target = 0, f = 50, t = "normal"},
       },
  ["Electabuzz"] = {move1 = {name = "Quick Attack", level = 80, cd = 10, dist = 2, target = 1, f = 50, t = "normal"},
        move2 = {name = "Low Kick", level = 80, cd = 25, dist = 1, target = 1, f = 75, t = "fighting"},
        move3 = {name = "Thunder Punch", level = 80, cd = 20, dist = 1, target = 1, f = 85, t = "electric"},
        move4 = {name = "Thunder Shock", level = 80, cd = 10, dist = 10, target = 1, f = 65, t = "electric"},
        move5 = {name = "Thunder Bolt", level = 80, cd = 25, dist = 10, target = 1, f = 53, t = "electric"},
        move6 = {name = "Thunder Wave", level = 80, cd = 25, dist = 1, target = 0, f = 80, t = "electric"},
        move7 = {name = "Thunder", level = 86, cd = 35, dist = 1, target = 0, f = 120, t = "electric"},
        move8 = {name = "Electric Storm", level = 90, cd = 80, dist = 1, target = 0, f = 150, t = "electric"},
        move9 = {name = "Shock-Counter", level = 1, cd = 0, dist = 10, target = 0, f = 50, t = "electric", passive = "sim"},
       },
  ["Magmar"] =     {move1 = {name = "Scratch", level = 80, cd = 10, dist = 1, target = 1, f = 40, t = "normal"},
        move2 = {name = "Fire Punch", level = 80, cd = 30, dist = 1, target = 1, f = 75, t = "fire"},
        move3 = {name = "Ember", level = 80, cd = 10, dist = 10, target = 1, f = 40, t = "fire"},
        move4 = {name = "Flamethrower", level = 80, cd = 15, dist = 1, target = 0, f = 80, t = "fire"},
        move5 = {name = "Fireball", level = 80, cd = 20, dist = 10, target = 1, f = 65, t = "fire"},
        move6 = {name = "Fire Blast", level = 80, cd = 40, dist = 1, target = 0, f = 120, t = "fire"},
        move7 = {name = "Magma Storm", level = 88, cd = 90, dist = 1, target = 0, f = 150, t = "fire"},
        move8 = {name = "Sunny Day", level = 92, cd = 60, dist = 1, target = 0, f = 0, t = "fire"},
        move9 = {name = "Lava-Counter", level = 1, cd = 0, dist = 10, target = 0, f = 50, t = "fire", passive = "sim"},
       },
  ["Pinsir"] =     {move1 = {name = "Bug Bite", level = 50, cd = 10, dist = 1, target = 1, f = 50, t = "bug"},
        move2 = {name = "Hammer Arm", level = 50, cd = 60, dist = 1, target = 0, f = 80, t = "fighting"},
        move3 = {name = "X-Scissor", level = 50, cd = 25, dist = 1, target = 0, f = 65, t = "bug"},
        move4 = {name = "Fury Cutter", level = 50, cd = 25, dist = 1, target = 0, f = 65, t = "bug"},
        move5 = {name = "Guillotine", level = 54, cd = 20, dist = 1, target = 1, f = 70, t = "normal"}, 
        move6 = {name = "Revenge", level = 56, cd = 25, dist = 1, target = 0, f = 100, t = "fighting"},
                    move7 = {name = "Megahorn", level = 50, cd = 35, dist = 1, target = 0, f = 90, t = "bug"},
        move8 = {name = "Harden", level = 50, cd = 25, dist = 1, target = 0, f = 0, t = "normal"},
        move9 = {name = "Rage", level = 60, cd = 25, dist = 1, target = 0, f = 0, t = "dragon"},
        move10 = {name = "Swords Dance", level = 58, cd = 60, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Tauros"] =     {move1 = {name = "Headbutt", level = 50, cd = 10, dist = 1, target = 1, f = 50, t = "normal"},
        move2 = {name = "Body Slam", level = 50, cd = 15, dist = 1, target = 1, f = 80, t = "normal"},
        move3 = {name = "Horn Attack", level = 50, cd = 15, dist = 2, target = 1, f = 60, t = "normal"},
        move4 = {name = "Hyper Beam", level = 55, cd = 25, dist = 1, target = 0, f = 190, t = "normal"},
        move5 = {name = "Thrash", level = 56, cd = 25, dist = 1, target = 0, f = 80, t = "normal"},
        move6 = {name = "Rage", level = 50, cd = 20, dist = 1, target = 0, f = 0, t = "dragon"},
        move7 = {name = "Rest", level = 60, cd = 60, dist = 1, target = 0, f = 0, t = "normal"},
        move8 = {name = "Fear", level = 58, cd = 25, dist = 1, target = 0, f = 0, t = "ghost"},
       },
  ["Magikarp"] =   {move1 = {name = "Splash", level = 1, cd = 5, dist = 1, target = 0, f = 1, t = "water"},
       },
  ["Gyarados"] =   {move1 = {name = "Roar", level = 100, cd = 30, dist = 1, target = 0, f = 0, t = "normal"},
        move2 = {name = "Bite", level = 90, cd = 15, dist = 1, target = 1, f = 40, t = "dark"},
        move3 = {name = "Aqua Tail", level = 90, cd = 15, dist = 1, target = 1, f = 50, t = "water"},
        move4 = {name = "Waterball", level = 90, cd = 20, dist = 10, target = 1, f = 60, t = "water"},
        move5 = {name = "Twister", level = 94, cd = 30, dist = 1, target = 0, f = 80, t = "dragon"},
        move6 = {name = "Hydro Cannon", level = 90, cd = 45, dist = 1, target = 0, f = 95, t = "water"},
        move7 = {name = "Dragon Breath", level = 90, cd = 30, dist = 1, target = 0, f = 80, t = "dragon"},
        move8 = {name = "Hyper Beam", level = 90, cd = 45, dist = 1, target = 0, f = 190, t = "normal"},
        move9 = {name = "Hydropump", level = 98, cd = 70, dist = 1, target = 0, f = 120, t = "water"},
        move10 = {name = "Rain Dance", level = 90, cd = 50, dist = 1, target = 0, f = 0, t = "water"},
       },
  ["Ditto"] =      {},
  ["Lapras"] =     {move1 = {name = "Ice Beam", level = 80, cd = 20, dist = 1, target = 0, f = 195, t = "ice"},
        move2 = {name = "Ice Shards", level = 80, cd = 15, dist = 10, target = 1, f = 45, t = "ice"},
        move3 = {name = "Water Gun", level = 80, cd = 18, dist = 1, target = 0, f = 55, t = "water"},
        move4 = {name = "Waterball", level = 80, cd = 18, dist = 10, target = 1, f = 60, t = "water"},
        move5 = {name = "Brine", level = 80, cd = 40, dist = 1, target = 0, f = 100, t = "water"},
        move6 = {name = "Aurora Beam", level = 80, cd = 20, dist = 1, target = 0, f = 190, t = "ice"},
        move7 = {name = "Blizzard", level = 88, cd = 60, dist = 1, target = 0, f = 150, t = "ice"},
        move8 = {name = "Hydropump", level = 90, cd = 75, dist = 1, target = 0, f = 120, t = "water"},
        move9 = {name = "Sing", level = 80, cd = 30, dist = 1, target = 0, f = 0, t = "normal"},
        move10 = {name = "Safeguard", level = 90, cd = 40, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Eevee"] =      {move1 = {name = "Sand Attack", level = 20, cd = 15, dist = 2, target = 0, f = 0, t = "ground"},
        move2 = {name = "Quick Attack", level = 20, cd = 10, dist = 1, target = 1, f = 40, t = "normal"},
        move3 = {name = "Bite", level = 20, cd = 10, dist = 1, target = 1, f = 50, t = "dark"},
        move4 = {name = "Headbutt", level = 24, cd = 15, dist = 1, target = 1, f = 50, t = "normal"},
        move5 = {name = "Iron Tail", level = 28, cd = 20, dist = 1, target = 1, f = 70, t = "steel"},
        move6 = {name = "Great Love", level = 35, cd = 25, dist = 1, target = 0, f = 50, t = "normal"},
       },
  ["Vaporeon"] =   {move1 = {name = "Quick Attack", level = 60, cd = 10, dist = 2, target = 1, f = 40, t = "normal"},
        move2 = {name = "Bite", level = 60, cd = 15, dist = 1, target = 1, f = 50, t = "dark"},
        move3 = {name = "Water Gun", level = 60, cd = 20, dist = 1, target = 0, f = 55, t = "water"},
        move4 = {name = "Bubblebeam", level = 60, cd = 20, dist = 10, target = 1, f = 40, t = "water"},
        move5 = {name = "Water Pulse", level = 60, cd = 20, dist = 1, target = 0, f = 70, t = "water"},
        move6 = {name = "Muddy Water", level = 60, cd = 25, dist = 1, target = 0, f = 125, t = "water"},
        move7 = {name = "Aurora Beam", level = 64, cd = 25, dist = 1, target = 0, f = 190, t = "ice"},
        move8 = {name = "Hydro Cannon", level = 68, cd = 40, dist = 10, target = 0, f = 95, t = "water"},
       },
  ["Jolteon"] =    {move1 = {name = "Quick Attack", level = 60, cd = 10, dist = 2, target = 1, f = 40, t = "normal"},
        move2 = {name = "Bite", level = 12, cd = 60, dist = 1, target = 1, f = 50, t = "dark"},
        move3 = {name = "Thunder Bolt", level = 60, cd = 20, dist = 10, target = 1, f = 55, t = "electric"},
        move4 = {name = "Thunder Fang", level = 60, cd = 20, dist = 1, target = 1, f = 65, t = "electric"},
        move5 = {name = "Thunder Wave", level = 60, cd = 20, dist = 1, target = 0, f = 70, t = "electric"},
        move6 = {name = "Pin Missile", level = 60, cd = 25, dist = 1, target = 0, f = 80, t = "bug"},
        move7 = {name = "Zap Cannon", level = 64, cd = 40, dist = 1, target = 0, f = 80, t = "electric"},
        move8 = {name = "Thunder", level = 68, cd = 30, dist = 1, target = 0, f = 125, t = "electric"},
       },
  ["Flareon"] =    {move1 = {name = "Quick Attack", level = 60, cd = 10, dist = 2, target = 1, f = 40, t = "normal"},
        move2 = {name = "Bite", level = 60, cd = 15, dist = 1, target = 1, f = 50, t = "dark"},
        move3 = {name = "Flamethrower", level = 60, cd = 20, dist = 1, target = 0, f = 70, t = "fire"},
        move4 = {name = "Sacred Fire", level = 60, cd = 20, dist = 10, target = 1, f = 80, t = "fire"},
        move5 = {name = "Blaze Kick", level = 60, cd = 20, dist = 1, target = 0, f = 80, t = "fire"},
        move6 = {name = "Flame Burst", level = 60, cd = 25, dist = 1, target = 0, f = 80, t = "fire"},
        move7 = {name = "Overheat", level = 64, cd = 30, dist = 1, target = 0, f = 80, t = "fire"}, 
        move8 = {name = "Fire Blast", level = 68, cd = 40, dist = 1, target = 0, f = 95, t = "fire"},
       },
  ["Porygon"] =    {move1 = {name = "Super Sonic", level = 40, cd = 15, dist = 10, target = 1, f = 0, t = "normal"},
        move2 = {name = "Psybeam", level = 40, cd = 15, dist = 1, target = 0, f = 75, t = "psychic"},
        move3 = {name = "Cyber Pulse", level = 45, cd = 15, dist = 10, target = 1, f = 35, t = "psychic"},     
        move4 = {name = "Psychic", level = 40, cd = 30, dist = 1, target = 0, f = 80, t = "psychic"},
        move5 = {name = "Zap Cannon", level = 44, cd = 30, dist = 1, target = 0, f = 80, t = "electric"},
        move6 = {name = "Focus", level = 50, cd = 40, dist = 1, target = 0, f = 0, t = "normal"},
        move7 = {name = "Magic Coat", level = 48, cd = 40, dist = 1, target = 0, f = 0, t = "psychic"}, 
        move8 = {name = "Restore", level = 40, cd = 60, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Omanyte"] =    {move1 = {name = "Bite", level = 20, cd = 10, dist = 1, target = 1, f = 40, t = "dark"},
        move2 = {name = "Rock Throw", level = 20, cd = 10, dist = 10, target = 1, f = 55, t = "rock"},
        move3 = {name = "Waterball", level = 20, cd = 15, dist = 10, target = 1, f = 60, t = "water"},
        move4 = {name = "Water Gun", level = 20, cd = 20, dist = 1, target = 0, f = 55, t = "water"},
        move5 = {name = "Mud Shot", level = 20, cd = 20, dist = 10, target = 1, f = 40, t = "ground"},
        move6 = {name = "Brine", level = 25, cd = 40, dist = 1, target = 0, f = 100, t = "water"},
        move7 = {name = "Harden", level = 26, cd = 30, dist = 1, target = 0, f = 0, t = "normal"},
        move8 = {name = "Ancient Power", level = 30, cd = 40, dist = 1, target = 0, f = 100, t = "rock"},
       },
  ["Omastar"] =    {move1 = {name = "Mud Shot", level = 85, cd = 20, dist = 10, target = 1, f = 40, t = "ground"},
         move2 = {name = "Bite", level = 80, cd = 15, dist = 1, target = 1, f = 40, t = "dark"},
        move3 = {name = "Rock Throw", level = 80, cd = 10, dist = 10, target = 1, f = 55, t = "rock"},
        move4 = {name = "Waterball", level = 85, cd = 15, dist = 10, target = 1, f = 60, t = "water"},
          move5 = {name = "Rock Slide", level = 80, cd = 15, dist = 10, target = 1, f = 35, t = "rock"},
        move6 = {name = "Brine", level = 85, cd = 25, dist = 1, target = 0, f = 100, t = "water"},
        move7 = {name = "Rollout", level = 90, cd = 54, dist = 1, target = 0, f = 30, t = "rock"},
        move8 = {name = "Ancient Power", level = 95, cd = 40, dist = 1, target = 0, f = 100, t = "rock"},
        move9 = {name = "Hydropump", level = 88, cd = 70, dist = 1, target = 0, f = 120, t = "water"},
        move10 = {name = "Harden", level = 90, cd = 30, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Kabuto"] =     {move1 = {name = "Scratch", level = 20, cd = 12, dist = 1, target = 1, f = 40, t = "normal"},
        move2 = {name = "Bubbles", level = 20, cd = 10, dist = 10, target = 1, f = 40, t = "water"},
        move3 = {name = "Slash", level = 20, cd = 20, dist = 1, target = 1, f = 60, t = "normal"},
        move4 = {name = "Mud Shot", level = 20, cd = 20, dist = 10, target = 1, f = 40, t = "ground"},
        move5 = {name = "Night Slash", level = 20, cd = 20, dist = 1, target = 0, f = 60, t = "dark"},
        move6 = {name = "Harden", level = 30, cd = 30, dist = 1, target = 0, f = 0, t = "normal"},
        move7 = {name = "Ancient Power", level = 26, cd = 40, dist = 1, target = 0, f = 100, t = "rock"},
        move8 = {name = "Mega Drain", level = 1, cd = 0, dist = 10, target = 0, f = 20, t = "grass", passive = "sim"},
       },
  ["Kabutops"] =   {move1 = {name = "Slash", level = 85, cd = 20, dist = 1, target = 1, f = 70, t = "normal"}, 
        move2 = {name = "Bubbles", level = 85, cd = 10, dist = 10, target = 1, f = 40, t = "water"},
        move3 = {name = "Rock Throw", level = 80, cd = 10, dist = 10, target = 1, f = 55, t = "rock"},
          move4 = {name = "Rock Slide", level = 80, cd = 15, dist = 10, target = 1, f = 35, t = "rock"},
        move5 = {name = "Mud Shot", level = 85, cd = 20, dist = 10, target = 1, f = 40, t = "ground"},
        move6 = {name = "Night Slash", level = 80, cd = 20, dist = 1, target = 0, f = 60, t = "dark"},  --alterado v1.7
        move7 = {name = "Rock Tomb", level = 80, cd = 30, dist = 10, target = 1, f = 85, t = "rock"},
        move8 = {name = "Ancient Power", level = 95, cd = 40, dist = 1, target = 0, f = 100, t = "rock"},
        move9 = {name = "Harden", level = 90, cd = 30, dist = 1, target = 0, f = 0, t = "normal"}, 
        move10 = {name = "Mega Drain", level = 1, cd = 0, dist = 10, target = 0, f = 20, t = "grass", passive = "sim"},
       },
  ["Aerodactyl"] = {move1 = {name = "Roar", level = 110, cd = 20, dist = 1, target = 0, f = 0, t = "normal"},
        move2 = {name = "Super Sonic", level = 100, cd = 20, dist = 1, target = 1, f = 0, t = "normal"},
        move3 = {name = "Bite", level = 100, cd = 10, dist = 1, target = 1, f = 50, t = "dark"},
        move4 = {name = "Crunch", level = 100, cd = 10, dist = 1, target = 0, f = 65, t = "dark"},
        move5 = {name = "Rock Throw", level = 100, cd = 15, dist = 10, target = 1, f = 55, t = "rock"},
        move6 = {name = "Rock Slide", level = 100, cd = 20, dist = 10, target = 1, f = 35, t = "rock"},
        move7 = {name = "Air Cutter", level = 105, cd = 40, dist = 1, target = 0, f = 70, t = "flying"},
        move8 = {name = "Wing Attack", level = 100, cd = 35, dist = 1, target = 0, f = 75, t = "flying"},
        move9 = {name = "Falling Rocks", level = 105, cd = 50, dist = 1, target = 0, f = 120, t = "rock"},
        move10 = {name = "Hyper Beam", level = 110, cd = 30, dist = 1, target = 0, f = 120, t = "normal"},
        move11 = {name = "Ancient Power", level = 115, cd = 40, dist = 1, target = 0, f = 100, t = "rock"},
        move12 = {name = "Mega - Aerodactyl", level = 0, cd = 0, dist = 1, target = 0, f = 0, t = "rock", mega = 1},
       },
  ["Snorlax"] =    {move1 = {name = "Lick", level = 90, cd = 30, dist = 1, target = 1, f = 0, t = "normal"},
        move2 = {name = "Bite", level = 90, cd = 15, dist = 1, target = 1, f = 50, t = "dark"},
        move3 = {name = "Crunch", level = 90, cd = 10, dist = 1, target = 0, f = 65, t = "dark"},  
        move4 = {name = "Mega Punch", level = 90, cd = 20, dist = 1, target = 1, f = 85, t = "fighting"},
        move5 = {name = "Body Slam", level = 94, cd = 20, dist = 1, target = 1, f = 80, t = "normal"},
        move6 = {name = "Focus Blast", level = 95, cd = 25, dist = 1, target = 0, f = 100, t = "fighting"},
        move7 = {name = "Hyper Beam", level = 95, cd = 30, dist = 1, target = 0, f = 120, t = "normal"},
        move8 = {name = "Crusher Stomp", level = 100, cd = 45, dist = 1, target = 0, f = 110, t = "ground"},
        move9 = {name = "Rest", level = 96, cd = 120, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Dratini"] =    {move1 = {name = "Aqua Tail", level = 20, cd = 10, dist = 1, target = 1, f = 60, t = "water"},
        move2 = {name = "Thunder Wave", level = 20, cd = 15, dist = 1, target = 0, f = 70, t = "electric"},
        move3 = {name = "Headbutt", level = 20, cd = 12, dist = 1, target = 1, f = 50, t = "normal"},
        move4 = {name = "Twister", level = 21, cd = 30, dist = 1, target = 0, f = 80, t = "dragon"},
        move5 = {name = "Hyper Beam", level = 30, cd = 20, dist = 1, target = 0, f = 190, t = "normal"},
        move6 = {name = "Dragon Breath", level = 25, cd = 25, dist = 1, target = 0, f = 80, t = "dragon"},
       },
  ["Dragonair"] =  {move1 = {name = "Aqua Tail", level = 60, cd = 15, dist = 1, target = 1, f = 60, t = "water"},
        move2 = {name = "Thunder Wave", level = 60, cd = 20, dist = 1, target = 0, f = 70, t = "electric"},
        move3 = {name = "Headbutt", level = 60, cd = 15, dist = 1, target = 1, f = 50, t = "normal"},
               move4 = {name = "Wrap", level = 60, cd = 20, dist = 10, target = 1, f = 0, t = "normal"},
        move5 = {name = "Dragon Claw", level = 60, cd = 20, dist = 1, target = 1, f = 60, t = "dragon"},
        move6 = {name = "Dragon Breath", level = 62, cd = 20, dist = 1, target = 0, f = 80, t = "dragon"},
        move7 = {name = "Twister", level = 64, cd = 30, dist = 1, target = 0, f = 80, t = "dragon"},
        move8 = {name = "Hyper Beam", level = 68, cd = 25, dist = 1, target = 0, f = 190, t = "normal"},
       },
  ["Dragonite"] =  {move1 = {name = "Aqua Tail", level = 100, cd = 15, dist = 1, target = 1, f = 60, t = "water"},
        move2 = {name = "Thunder Wave", level = 100, cd = 20, dist = 1, target = 0, f = 70, t = "electric"},
        move3 = {name = "Headbutt", level = 100, cd = 15, dist = 1, target = 1, f = 50, t = "normal"},
          move4 = {name = "Dragon Claw", level = 100, cd = 20, dist = 1, target = 1, f = 60, t = "dragon"},
        move5 = {name = "Dragon Breath", level = 102, cd = 25, dist = 1, target = 0, f = 80, t = "dragon"},
        move6 = {name = "Twister", level = 104, cd = 30, dist = 1, target = 0, f = 80, t = "dragon"},
        move7 = {name = "Wing Attack", level = 106, cd = 35, dist = 1, target = 0, f = 75, t = "flying"},
        move8 = {name = "Hyper Beam", level = 108, cd = 30, dist = 1, target = 0, f = 120, t = "normal"},
        move9 = {name = "Draco Meteor", level = 115, cd = 70, dist = 1, target = 0, f = 110, t = "dragon"},
       },
    
  ["Zapdos"] = {move1 = {name = "Thunder Bolt", level = 100, cd = 15, dist = 10, target = 1, f = 185, t = "electric"},
        move2 = {name = "Thunder Wave", level = 100, cd = 10, dist = 1, target = 0, f = 110, t = "electric"},
        move3 = {name = "Drill Peck", level = 100, cd = 15, dist = 1, target = 1, f = 175, t = "flying"},
        move4 = {name = "Aeroblast", level = 100, cd = 50, dist = 1, target = 0, f = 190, t = "flying"},
        move5 = {name = "Wing Attack", level = 100, cd = 20, dist = 1, target = 0, f = 215, t = "flying"},
        move6 = {name = "Thunder", level = 100, cd = 45, dist = 1, target = 0, f = 180, t = "electric"},
        move7 = {name = "Electric Storm", level = 100, cd = 60, dist = 1, target = 0, f = 237, t = "electric"},
        move8 = {name = "Aerial Ace", level = 100, cd = 50, dist = 1, target = 0, f = 230, t = "flying"}, 
        move9 = {name = "Electro Field", level = 100, cd = 30, dist = 1, target = 0, f = 180, t = "electric"}, 
        move10 = {name = "Ancient Power", level = 100, cd = 30, dist = 1, target = 0, f = 180, t = "electric"}, 
        move11 = {name = "Roost", level = 100, cd = 70, dist = 1, target = 0, f = 0, t = "flying"},  
        move12 = {name = "Shock-Counter", level = 1, cd = 0, dist = 10, target = 0, f = 50, t = "electric", passive = "sim"},
       },
  
  ["Articuno"] = {move1 = {name = "Drill Peck", level = 100, cd = 15, dist = 1, target = 1, f = 185, t = "flying"},
        move2 = {name = "Icy Wind", level = 100, cd = 20, dist = 1, target = 0, f = 95, t = "ice"},
        move3 = {name = "Wing Attack", level = 100, cd = 20, dist = 1, target = 0, f = 215, t = "flying"},
        move4 = {name = "Ice Beam", level = 100, cd = 25, dist = 1, target = 0, f = 125, t = "ice"},
        move5 = {name = "Aurora Beam", level = 100, cd = 25, dist = 1, target = 0, f = 210, t = "ice"},
        move6 = {name = "Aeroblast", level = 100, cd = 50, dist = 1, target = 0, f = 150, t = "flying"},
        move7 = {name = "Blizzard", level = 100, cd = 50, dist = 1, target = 0, f = 210, t = "ice"},
        move8 = {name = "Aerial Ace", level = 100, cd = 50, dist = 1, target = 0, f = 230, t = "flying"}, 
        move9 = {name = "Roost", level = 100, cd = 70, dist = 1, target = 0, f = 0, t = "flying"},  
        move10 = {name = "Ancient Power", level = 100, cd = 30, dist = 1, target = 0, f = 180, t = "electric"}, 
       },
       
  ["Moltres"] = { move1 = {name = "Wing Attack", level = 100, cd = 15, dist = 1, target = 0, f = 215, t = "flying"},
        move2 = {name = "Ember", level = 100, cd = 10, dist = 10, target = 1, f = 192, t = "fire"},
        move3 = {name = "Flamethrower", level = 100, cd = 20, dist = 1, target = 0, f = 190, t = "fire"},
        move4 = {name = "Fireball", level = 100, cd = 15, dist = 10, target = 1, f = 215, t = "fire"},
        move5 = {name = "Fire Blast", level = 100, cd = 45, dist = 1, target = 0, f = 225, t = "fire"},
        move6 = {name = "Sunny Day", level = 100, cd = 30, dist = 1, target = 0, f = 0, t = "fire"},
        move7 = {name = "Aerial Ace", level = 100, cd = 50, dist = 1, target = 0, f = 210, t = "flying"}, 
        move8 = {name = "Inferno", level = 100, cd = 55, dist = 1, target = 0, f = 250, t = "fire"},  
        move9 = {name = "Roost", level = 100, cd = 70, dist = 1, target = 0, f = 0, t = "flying"}, 
        move10 = {name = "Ancient Power", level = 100, cd = 30, dist = 1, target = 0, f = 180, t = "electric"}, 
        move11 = {name = "Lava-Counter", level = 1, cd = 0, dist = 10, target = 0, f = 50, t = "fire", passive = "sim"}, 
       },
  
  ["Mew"] = {move1 = {name = "Shadow Ball", level = 100, cd = 8, dist = 10, target = 1, f = 200, t = "ghost"},
      move2 = {name = "Brine", level = 100, cd = 40, dist = 1, target = 0, f = 220, t = "water"},
      move3 = {name = "Flamethrower", level = 100, cd = 20, dist = 1, target = 0, f = 210, t = "fire"},
      move4 = {name = "Thunder Bolt", level = 100, cd = 20, dist = 10, target = 1, f = 220, t = "electric"},
      move5 = {name = "Psychic", level = 100, cd = 40, dist = 1, target = 0, f = 235, t = "psychic"},
      move6 = {name = "Hydro Cannon", level = 100, cd = 35, dist = 1, target = 0, f = 250, t = "water"},
      move7 = {name = "Solar Beam", level = 100, cd = 60, dist = 1, target = 0, f = 250, t = "grass"},
      move8 = {name = "Metronome", level = 100, cd = 40, dist = 1, target = 0, f = 0, t = "normal"},
      move9 = {name = "Barrier", level = 100, cd = 35, dist = 1, target = 0, f = 0, t = "psychic"},
      move10 = {name = "Reflect", level = 100, cd = 60, dist = 1, target = 0, f = 0, t = "psychic"},
      move11 = {name = "Restore", level = 350, cd = 180, dist = 1, target = 0, f = 0, t = "normal"},
    },
  
  ["Mewtwo"] = {move1 = {name = "Swift", level = 100, cd = 20, dist = 4, target = 1, f = 200, t = "normal"},
      move2 = {name = "Shadow Ball", level = 100, cd = 8, dist = 4, target = 1, f = 200, t = "ghost"},
      move3 = {name = "Psybeam", level = 100, cd = 25, dist = 1, target = 0, f = 200, t = "psychic"},
      move4 = {name = "Psywave", level = 100, cd = 20, dist = 1, target = 0, f = 200, t = "psychic"},
      move5 = {name = "Confusion", level = 100, cd = 35, dist = 1, target = 0, f = 220, t = "psychic"},
      move6 = {name = "Psychic", level = 100, cd = 40, dist = 1, target = 0, f = 250, t = "psychic"},
      move7 = {name = "Divine Punishment", level = 100, cd = 70, dist = 1, target = 0, f = 250, t = "psychic"},
      move8 = {name = "Restore", level = 100, cd = 180, dist = 1, target = 0, f = 0, t = "normal"},
      move9 = {name = "Barrier", level = 100, cd = 35, dist = 1, target = 0, f = 0, t = "psychic"},
      move10 = {name = "Fear", level = 100, cd = 45, dist = 1, target = 0, f = 0, t = "ghost"},
      move11 = {name = "Reflect", level = 100, cd = 60, dist = 1, target = 0, f = 0, t = "psychic"},
      move12 = {name = "Miracle Eye", level = 100, cd = 40, dist = 1, target = 0, f = 0, t = "psychic"},
    },
  ---------------------------------------------------------------------- SHINIES ----------------------------------------------------------------------------------
  ["Shiny Venusaur"] =  {move1 = {name = "Tackle", level = 100, cd = 10, dist = 1, target = 1, f = 50, t = "normal"},
       move2 = {name = "Razor Leaf", level = 100, cd = 7, dist = 10, target = 1, f = 33, t = "grass"},
       move3 = {name = "Vine Whip", level = 100, cd = 16, dist = 1, target = 0, f = 65, t = "grass"},
       move4 = {name = "Headbutt", level = 100, cd = 12, dist = 1, target = 1, f = 50, t = "normal"},
       move5 = {name = "Leech Seed", level = 100, cd = 28, dist = 10, target = 1, f = 1, t = "grass"},
       move6 = {name = "Bullet Seed", level = 100, cd = 28, dist = 1, target = 0, f = 95, t = "grass"},
       move7 = {name = "Solar Beam", level = 100, cd = 54, dist = 1, target = 0, f = 190, t = "grass"},
              move8 = {name = "Giga Drain", level = 105, cd = 25, dist = 1, target = 1, f = 120, t = "grass"},
       move9 = {name = "Sleep Powder", level = 100, cd = 72, dist = 1, target = 0, f = 0, t = "normal"},
       move10 = {name = "Poison Powder", level = 100, cd = 36, dist = 1, target = 0, f = 0, t = "normal"},
       move11 = {name = "Leaf Storm", level = 110, cd = 81, dist = 1, target = 0, f = 150, t = "grass"},
       move12 = {name = "Mega - Venusaur", level = 0, cd = 0, dist = 1, target = 0, f = 0, t = "grass", mega = 1},
       },
  ["Shiny Charizard"] =  {move1 = {name = "Ember", level = 100, cd = 10, dist = 10, target = 1, f = 40, t = "fire"},
        move2 = {name = "Flamethrower", level = 100, cd = 16, dist = 1, target = 0, f = 80, t = "fire"},
        move3 = {name = "Fireball", level = 100, cd = 20, dist = 10, target = 1, f = 75, t = "fire"},
        move4 = {name = "Fire Fang", level = 100, cd = 16, dist = 1, target = 1, f = 65, t = "fire"},
        move5 = {name = "Flame Burst", level = 100, cd = 28, dist = 1, target = 0, f = 100, t = "fire"},
        move6 = {name = "Fire Blast", level = 100, cd = 54, dist = 1, target = 0, f = 120, t = "fire"},
                move7 = {name = "Air Slash", level = 103, cd = 40, dist = 1, target = 0, f = 100, t = "flying"},
        move8 = {name = "Wing Attack", level = 100, cd = 28, dist = 1, target = 0, f = 75, t = "flying"},
        move9 = {name = "Magma Storm", level = 100, cd = 81, dist = 1, target = 0, f = 150, t = "fire"},
        move10 = {name = "Scary Face", level = 102, cd = 45, dist = 1, target = 0, f = 0, t = "ghost"},
        move11 = {name = "Ancient Fury", level = 100, cd = 32, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Shiny Blastoise"] =  {move1 = {name = "Headbutt", level = 100, cd = 12, dist = 1, target = 1, f = 50, t = "normal"},
        move2 = {name = "Bubbles", level = 100, cd = 8, dist = 10, target = 1, f = 40, t = "water"},
        move3 = {name = "Water Gun", level = 100, cd = 16, dist = 1, target = 0, f = 55, t = "water"},
        move4 = {name = "Waterball", level = 100, cd = 20, dist = 10, target = 1, f = 65, t = "water"},
        move5 = {name = "Water Pulse", level = 100, cd = 25, dist = 1, target = 0, f = 70, t = "water"},
        move6 = {name = "Brine", level = 100, cd = 32, dist = 1, target = 0, f = 100, t = "water"},
        move7 = {name = "Hydro Cannon", level = 100, cd = 54, dist = 1, target = 0, f = 95, t = "water"},
        move8 = {name = "Skull Bash", level = 105, cd = 36, dist = 1, target = 0, f = 100, t = "normal"},
        move9 = {name = "Hydropump", level = 110, cd = 81, dist = 1, target = 0, f = 125, t = "water"},
        move10 = {name = "Ancient Fury", level = 100, cd = 32, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Shiny Butterfree"] = {move1 = {name = "Super Sonic", level = 60, cd = 15, dist = 10, target = 1, f = 0, t = "normal"},
        move2 = {name = "Silver Wind", level = 60, cd = 25, dist = 10, target = 1, f = 70, t = "bug"}, 
        move3 = {name = "Whirlwind", level = 62, cd = 25, dist = 1, target = 0, f = 80, t = "flying"},
        move4 = {name = "Confusion", level = 64, cd = 30, dist = 1, target = 0, f = 50, t = "psychic"},
        move5 = {name = "Psybeam", level = 66, cd = 15, dist = 1, target = 0, f = 75, t = "psychic"},
        move6 = {name = "Air Cutter", level = 68, cd = 40, dist = 1, target = 0, f = 70, t = "flying"},
        move7 = {name = "Sleep Powder", level = 60, cd = 60, dist = 1, target = 0, f = 0, t = "normal"},
        move8 = {name = "Safeguard", level = 70, cd = 40, dist = 1, target = 0, f = 0, t = "normal"},
        move9 = {name = "Poison Powder", level = 60, cd = 20, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Shiny Beedrill"] =   {move1 = {name = "String Shot", level = 60, cd = 10, dist = 10, target = 1, f = 0, t = "normal"},
        move2 = {name = "Poison Jab", level = 60, cd = 16, dist = 10, target = 1, f = 85, t = "poison"},
        move3 = {name = "Poison Sting", level = 60, cd = 10, dist = 2, target = 1, f = 40, t = "poison"},
        move4 = {name = "Fury Cutter", level = 65, cd = 15, dist = 1, target = 0, f = 65, t = "bug"},
        move5 = {name = "Pin Missile", level = 65, cd = 20, dist = 1, target = 0, f = 80, t = "bug"},
        move6 = {name = "Toxic Spikes", level = 62, cd = 25, dist = 10, target = 1, f = 50, t = "poison"},
        move7 = {name = "Rage", level = 60, cd = 25, dist = 1, target = 0, f = 0, t = "dragon"},
        move8 = {name = "Strafe", level = 68, cd = 25, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Shiny Pidgeot"] =    {move1 = {name = "Quick Attack", level = 100, cd = 8, dist = 2, target = 1, f = 40, t = "normal"},
        move2 = {name = "Sand Attack", level = 100, cd = 12, dist = 1, target = 0, f = 0, t = "ground"},
        move3 = {name = "Whirlwind", level = 100, cd = 18, dist = 1, target = 0, f = 80, t = "flying"},
        move4 = {name = "Drill Peck", level = 100, cd = 16, dist = 1, target = 1, f = 35, t = "flying"},
        move5 = {name = "Wing Attack", level = 102, cd = 24, dist = 1, target = 0, f = 75, t = "flying"},
        move6 = {name = "Hurricane", level = 110, cd = 50, dist = 1, target = 0, f = 15, t = "flying"},
        move7 = {name = "Aeroblast", level = 104, cd = 90, dist = 1, target = 0, f = 190, t = "flying"},
        move8 = {name = "Agility", level = 100, cd = 20, dist = 1, target = 0, f = 0, t = "flying"},
        move9 = {name = "Roost", level = 105, cd = 60, dist = 1, target = 0, f = 0, t = "flying"},
       },
  ["Shiny Rattata"] =    {move1 = {name = "Quick Attack", level = 10, cd = 8, dist = 2, target = 1, f = 40, t = "normal"},
        move2 = {name = "Bite", level = 10, cd = 10, dist = 12, target = 1, f = 50, t = "dark"},
        move3 = {name = "Scratch", level = 10, cd = 13, dist = 12, target = 1, f = 40, t = "normal"},
               move4 = {name = "Pursuit", level = 10, cd = 20, dist = 10, target = 1, f = 65, t = "dark"},
        move5 = {name = "Super Fang", level = 10, cd = 20, dist = 1, target = 1, f = 65, t = "normal"},
        move6 = {name = "Scary Face", level = 12, cd = 45, dist = 1, target = 0, f = 0, t = "ghost"},
       },
  ["Shiny Raticate"] =   {move1 = {name = "Quick Attack", level = 60, cd = 8, dist = 2, target = 1, f = 40, t = "normal"},
        move2 = {name = "Bite", level = 60, cd = 10, dist = 12, target = 1, f = 50, t = "dark"},
        move3 = {name = "Scratch", level = 60, cd = 13, dist = 12, target = 1, f = 40, t = "normal"},
               move4 = {name = "Pursuit", level = 60, cd = 20, dist = 10, target = 1, f = 65, t = "dark"},
               move5 = {name = "Sucker Punch", level = 63, cd = 30, dist = 1, target = 1, f = 65, t = "dark"},
        move5 = {name = "Super Fang", level = 60, cd = 20, dist = 1, target = 1, f = 65, t = "normal"},
        move6 = {name = "Scary Face", level = 62, cd = 45, dist = 1, target = 0, f = 0, t = "ghost"},
       },
  ["Shiny Fearow"] =     {move1 = {name = "Peck", level = 120, cd = 10, dist = 1, target = 1, f = 50, t = "flying"},
        move2 = {name = "Sand Attack", level = 120, cd = 10, dist = 1, target = 0, f = 0, t = "ground"},
        move3 = {name = "Feather Dance", level = 120, cd = 8, dist = 10, target = 1, f = 45, t = "flying"},
        move4 = {name = "Drill Peck", level = 120, cd = 10, dist = 1, target = 1, f = 55, t = "flying"},
        move5 = {name = "Whirlwind", level = 120, cd = 10, dist = 1, target = 0, f = 100, t = "flying"},
        move6 = {name = "Air Cutter", level = 128, cd = 30, dist = 1, target = 0, f = 80, t = "flying"},
        move7 = {name = "Wing Attack", level = 120, cd = 15, dist = 1, target = 0, f = 85, t = "flying"},
        move8 = {name = "Aerial Ace", level = 124, cd = 60, dist = 1, target = 0, f = 190, t = "flying"},
        move9 = {name = "Air Slash", level = 83, cd = 40, dist = 1, target = 0, f = 100, t = "flying"},
        move10 = {name = "Agility", level = 120, cd = 20, dist = 1, target = 0, f = 0, t = "flying"},
       },
  ["Shiny Raichu"] =     {move1 = {name = "Mega Kick", level = 100, cd = 32, dist = 1, target = 1, f = 95, t = "fighting"},
        move2 = {name = "Thunder Shock", level = 100, cd = 8, dist = 10, target = 1, f = 65, t = "electric"},
        move3 = {name = "Thunder Bolt", level = 100, cd = 16, dist = 10, target = 1, f = 63, t = "electric"},
        move4 = {name = "Thunder Wave", level = 100, cd = 20, dist = 1, target = 0, f = 80, t = "electric"},
        move5 = {name = "Thunder Punch", level = 100, cd = 32, dist = 1, target = 1, f = 85, t = "electric"},
        move6 = {name = "Iron Tail", level = 100, cd = 16, dist = 1, target = 1, f = 80, t = "steel"},
        move7 = {name = "Body Slam", level = 105, cd = 20, dist = 1, target = 1, f = 80, t = "normal"},
        move8 = {name = "Thunder", level = 100, cd = 54, dist = 1, target = 0, f = 125, t = "electric"},
        move9 = {name = "Electric Storm", level = 110, cd = 25, dist = 1, target = 0, f = 150, t = "electric"},
        move10 = {name = "Agility", level = 100, cd = 54, dist = 1, target = 0, f = 0, t = "flying"},
       },
  ["Shiny Nidoking"] =   {move1 = {name = "Quick Attack", level = 120, cd = 8, dist = 2, target = 1, f = 50, t = "normal"},
        move2 = {name = "Horn Attack", level = 120, cd = 10, dist = 2, target = 1, f = 65, t = "normal"},
        move3 = {name = "Poison Fang", level = 120, cd = 10, dist = 1, target = 1, f = 75, t = "poison"},
        move4 = {name = "Poison Jab", level = 120, cd = 15, dist = 10, target = 1, f = 95, t = "poison"},   --alterado v1.7 achu q eh assim kk
        move5 = {name = "Toxic Spikes", level = 120, cd = 15, dist = 10, target = 1, f = 60, t = "poison"},
        move6 = {name = "Sludge Wave", level = 120, cd = 30, dist = 1, target = 0, f = 105, t = "poison"},
        move7 = {name = "Sludge Rain", level = 132, cd = 40, dist = 1, target = 0, f = 150, t = "poison"},
        move8 = {name = "Cross Poison", level = 124, cd = 40, dist = 1, target = 0, f = 80, t = "poison"}, 
        move9 = {name = "Rage", level = 120, cd = 16, dist = 1, target = 0, f = 0, t = "dragon"},
        move10 = {name = "Fear", level = 120, cd = 24, dist = 1, target = 0, f = 0, t = "ghost"},
       },
  ["Shiny Ninetales"] =  {move1 = {name = "Quick Attack", level = 150, cd = 10, dist = 2, target = 1, f = 40, t = "normal"},
        move2 = {name = "Iron Tail", level = 150, cd = 15, dist = 1, target = 1, f = 70, t = "steel"},
        move3 = {name = "Ember", level = 150, cd = 15, dist = 10, target = 1, f = 42, t = "fire"},
        move4 = {name = "Flamethrower", level = 150, cd = 20, dist = 1, target = 0, f = 80, t = "fire"},
        move5 = {name = "Flame Circle", level = 150, cd = 20, dist = 1, target = 0, f = 85, t = "fire"},
        move6 = {name = "Fireball", level = 150, cd = 20, dist = 10, target = 1, f = 75, t = "fire"},
        move7 = {name = "Confuse Ray", level = 150, cd = 25, dist = 10, target = 1, f = 65, t = "ghost"},
        move8 = {name = "Fire Blast", level = 154, cd = 30, dist = 1, target = 0, f = 105, t = "fire"},
        move9 = {name = "Magma Storm", level = 158, cd = 60, dist = 1, target = 0, f = 150, t = "fire"},
        move10 = {name = "Safeguard", level = 160, cd = 40, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Shiny Zubat"] =      {move1 = {name = "Super Sonic", level = 20, cd = 15, dist = 10, target = 1, f = 0, t = "normal"},
        move2 = {name = "Bite", level = 20, cd = 10, dist = 1, target = 1, f = 50, t = "dark"},
        move3 = {name = "Poison Fang", level = 20, cd = 10, dist = 1, target = 1, f = 65, t = "poison"},
        move4 = {name = "Toxic", level = 20, cd = 20, dist = 1, target = 0, f = 50, t = "poison"},
        move5 = {name = "Whirlwind", level = 20, cd = 22, dist = 1, target = 0, f = 80, t = "flying"},
        move6 = {name = "Wing Attack", level = 20, cd = 30, dist = 1, target = 0, f = 75, t = "flying"},
        move7 = {name = "Air Cutter", level = 24, cd = 40, dist = 1, target = 0, f = 70, t = "flying"},
       },
  ["Shiny Golbat"] =     {move1 = {name = "Super Sonic", level = 40, cd = 15, dist = 10, target = 1, f = 0, t = "normal"},
        move2 = {name = "Bite", level = 40, cd = 10, dist = 1, target = 1, f = 50, t = "dark"},
        move3 = {name = "Poison Fang", level = 40, cd = 10, dist = 1, target = 1, f = 65, t = "poison"},
        move4 = {name = "Toxic", level = 40, cd = 20, dist = 1, target = 0, f = 50, t = "poison"},
        move5 = {name = "Whirlwind", level = 40, cd = 22, dist = 1, target = 0, f = 80, t = "flying"},
        move6 = {name = "Wing Attack", level = 40, cd = 30, dist = 1, target = 0, f = 75, t = "flying"},
        move7 = {name = "Air Cutter", level = 44, cd = 40, dist = 1, target = 0, f = 70, t = "flying"},
       },
  ["Shiny Oddish"] =     {move1 = {name = "Absorb", level = 20, cd = 10, dist = 1, target = 1, f = 40, t = "grass"},
        move2 = {name = "Acid", level = 20, cd = 10, dist = 10, target = 1, f = 45, t = "poison"},
        move3 = {name = "Leech Seed", level = 20, cd = 15, dist = 10, target = 1, f = 1, t = "grass"},
        move4 = {name = "Poison Bomb", level = 22, cd = 15, dist = 10, target = 1, f = 70, t = "poison"},
        move5 = {name = "Poison Gas", level = 27, cd = 32, dist = 1, target = 0, f = 10, t = "poison"},
        move6 = {name = "Sleep Powder", level = 20, cd = 50, dist = 1, target = 0, f = 0, t = "normal"},
        move7 = {name = "Poison Powder", level = 20, cd = 10, dist = 1, target = 0, f = 0, t = "normal"},
        move8 = {name = "Stun Spore", level = 20, cd = 20, dist = 1, target = 0, f = 0, t = "normal"},
        move9 = {name = "Mega Drain", level = 1, cd = 0, dist = 10, target = 0, f = 20, t = "grass", passive = "sim"},
        move10 = {name = "Spores Reaction", level = 1, cd = 0, dist = 10, target = 0, f = 0, t = "normal", passive = "sim"},
       },
  ["Shiny Vileplume"] =  {move1 = {name = "Absorb", level = 120, cd = 10, dist = 1, target = 1, f = 50, t = "grass"},
        move2 = {name = "Leech Seed", level = 120, cd = 16, dist = 10, target = 1, f = 1, t = "grass"},
        move3 = {name = "Magical Leaf", level = 120, cd = 10, dist = 10, target = 1, f = 43, t = "grass"},
        move4 = {name = "Leaf Blade", level = 120, cd = 8, dist = 10, target = 1, f = 70, t = "grass"},
        move5 = {name = "Petal Dance", level = 120, cd = 16, dist = 1, target = 0, f = 80, t = "grass"},
        move6 = {name = "Petal Tornado", level = 135, cd = 80, dist = 1, target = 0, f = 40, t = "grass"},
        move7 = {name = "Solar Beam", level = 130, cd = 30, dist = 1, target = 0, f = 190, t = "grass"},
        move8 = {name = "Poison Powder", level = 125, cd = 20, dist = 1, target = 0, f = 0, t = "normal"},
        move9 = {name = "Stun Spore", level = 120, cd = 20, dist = 1, target = 0, f = 0, t = "normal"},
        move10 = {name = "Aromateraphy", level = 125, cd = 45, dist = 1, target = 0, f = 0, t = "grass"},
        move11 = {name = "Mega Drain", level = 1, cd = 0, dist = 10, target = 0, f = 30, t = "grass", passive = "sim"},
        move12 = {name = "Spores Reaction", level = 1, cd = 0, dist = 10, target = 0, f = 0, t = "normal", passive = "sim"},
       },
  ["Shiny Paras"] =      {move1 = {name = "Scratch", level = 20, cd = 8, dist = 1, target = 1, f = 40, t = "normal"},
        move2 = {name = "Poison Sting", level = 20, cd = 8, dist = 2, target = 1, f = 40, t = "poison"},
        move3 = {name = "Slash", level = 20, cd = 12, dist = 1, target = 1, f = 60, t = "normal"},
        move4 = {name = "Stun Spore", level = 20, cd = 20, dist = 1, target = 0, f = 0, t = "normal"},
        move5 = {name = "Poison Powder", level = 22, cd = 12, dist = 1, target = 0, f = 0, t = "normal"},
        move6 = {name = "Sleep Powder", level = 27, cd = 72, dist = 1, target = 0, f = 0, t = "normal"},
        move7 = {name = "Mega Drain", level = 1, cd = 0, dist = 10, target = 0, f = 20, t = "grass", passive = "sim"},
        move8 = {name = "Spores Reaction", level = 1, cd = 0, dist = 10, target = 0, f = 0, t = "normal", passive = "sim"},
       },
  ["Shiny Parasect"] =   {move1 = {name = "Absorb", level = 60, cd = 16, dist = 1, target = 1, f = 40, t = "grass"},
        move2 = {name = "Scratch", level = 65, cd = 8, dist = 1, target = 1, f = 40, t = "normal"},
        move3 = {name = "Poison Sting", level = 60, cd = 8, dist = 10, target = 1, f = 40, t = "poison"},
        move4 = {name = "Slash", level = 60, cd = 12, dist = 1, target = 0, f = 60, t = "normal"},
        move5 = {name = "Poison Bomb", level = 60, cd = 16, dist = 10, target = 1, f = 70, t = "poison"},
        move6 = {name = "Stun Spore", level = 60, cd = 20, dist = 1, target = 0, f = 0, t = "normal"},
        move7 = {name = "Poison Powder", level = 60, cd = 16, dist = 10, target = 0, f = 0, t = "normal"},
        move8 = {name = "Sleep Powder", level = 60, cd = 72, dist = 1, target = 0, f = 0, t = "normal"},
        move9 = {name = "Fury Cutter", level = 66, cd = 20, dist = 1, target = 0, f = 65, t = "bug"},
        move10 = {name = "X-Scissor", level = 68, cd = 20, dist = 1, target = 0, f = 70, t = "bug"},
        move11 = {name = "Mega Drain", level = 1, cd = 0, dist = 10, target = 0, f = 20, t = "grass", passive = "sim"},
        move12 = {name = "Spores Reaction", level = 1, cd = 0, dist = 10, target = 0, f = 0, t = "normal", passive = "sim"},
       },
  ["Shiny Venonat"] =    {move1 = {name = "Super Sonic", level = 20, cd = 15, dist = 10, target = 1, f = 0, t = "normal"},
        move2 = {name = "Psybeam", level = 20, cd = 20, dist = 1, target = 0, f = 75, t = "psychic"},
        move3 = {name = "Silver Wind", level = 20, cd = 25, dist = 10, target = 1, f = 70, t = "bug"}, 
        move4 = {name = "Confusion", level = 26, cd = 25, dist = 1, target = 0, f = 50, t = "psychic"},
        move5 = {name = "Psychic", level = 20, cd = 20, dist = 1, target = 0, f = 90, t = "psychic"},
               move6 = {name = "U-Turn", level = 26, cd = 15, dist = 10, target = 1, f = 90, t = "bug"},  
        move7 = {name = "Bug Buzz", level = 24, cd = 20, dist = 1, target = 0, f = 70, t = "bug"},
        move8 = {name = "Sleep Powder", level = 20, cd = 60, dist = 1, target = 0, f = 0, t = "normal"},
        move9 = {name = "Poison Powder", level = 20, cd = 20, dist = 1, target = 0, f = 0, t = "normal"},
        move10 = {name = "Mega Drain", level = 1, cd = 0, dist = 10, target = 0, f = 20, t = "grass", passive = "sim"},
        move11 = {name = "Spores Reaction", level = 1, cd = 0, dist = 10, target = 0, f = 0, t = "normal", passive = "sim"},
       },
  ["Shiny Venomoth"] =   {move1 = {name = "Super Sonic", level = 100, cd = 15, dist = 10, target = 1, f = 0, t = "normal"},
        move2 = {name = "Psybeam", level = 105, cd = 12, dist = 10, target = 0, f = 60, t = "bug"},
        move3 = {name = "Silver Wind", level = 100, cd = 25, dist = 10, target = 1, f = 70, t = "bug"}, 
        move4 = {name = "Confusion", level = 106, cd = 25, dist = 1, target = 0, f = 50, t = "psychic"},
        move5 = {name = "Psychic", level = 100, cd = 20, dist = 1, target = 0, f = 90, t = "psychic"},
               move6 = {name = "Pin Missile", level = 100, cd = 15, dist = 10, target = 0, f = 90, t = "bug"},  
        move7 = {name = "Bug Buzz", level = 106, cd = 20, dist = 1, target = 0, f = 70, t = "bug"},
        move8 = {name = "Sleep Powder", level = 100, cd = 60, dist = 1, target = 0, f = 0, t = "normal"},
        move9 = {name = "Poison Powder", level = 100, cd = 20, dist = 1, target = 0, f = 0, t = "normal"},
        move10 = {name = "Mega Drain", level = 1, cd = 0, dist = 10, target = 0, f = 20, t = "grass", passive = "sim"},
        move11 = {name = "Spores Reaction", level = 1, cd = 0, dist = 10, target = 0, f = 0, t = "normal", passive = "sim"},
       },
  ["Shiny Growlithe"] =  {move1 = {name = "Roar", level = 40, cd = 16, dist = 1, target = 0, f = 0, t = "normal"},
        move2 = {name = "Bite", level = 30, cd = 8, dist = 1, target = 1, f = 50, t = "dark"},
        move3 = {name = "Ember", level = 30, cd = 12, dist = 10, target = 1, f = 40, t = "fire"},
        move4 = {name = "Flamethrower", level = 30, cd = 16, dist = 1, target = 130, f = 0, t = "fire"},
        move5 = {name = "Fireball", level = 30, cd = 16, dist = 10, target = 1, f = 70, t = "fire"},
        move6 = {name = "Fire Fang", level = 30, cd = 20, dist = 1, target = 1, f = 65, t = "fire"},
        move7 = {name = "ExtremeSpeed", level = 30, cd = 15, dist = 10, target = 1, f = 65, t = "normal"},
        move8 = {name = "Fire Blast", level = 32, cd = 54, dist = 1, target = 0, f = 120, t = "fire"},
        move9 = {name = "Tri Flames", level = 34, cd = 36, dist = 1, target = 0, f = 90, t = "fire"},
        move10 = {name = "War Dog", level = 36, cd = 24, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Shiny Arcanine"] =   {move1 = {name = "Roar", level = 110, cd = 16, dist = 1, target = 0, f = 0, t = "normal"},
        move2 = {name = "Bite", level = 100, cd = 8, dist = 1, target = 1, f = 50, t = "dark"},
        move3 = {name = "Ember", level = 100, cd = 12, dist = 10, target = 1, f = 40, t = "fire"},
        move4 = {name = "Flamethrower", level = 100, cd = 16, dist = 1, target = 130, f = 50, t = "fire"},
        move5 = {name = "Fireball", level = 100, cd = 16, dist = 10, target = 1, f = 70, t = "fire"},
        move6 = {name = "Fire Fang", level = 100, cd = 20, dist = 1, target = 1, f = 65, t = "fire"},
        move7 = {name = "ExtremeSpeed", level = 100, cd = 15, dist = 10, target = 1, f = 65, t = "normal"},
        move8 = {name = "Fire Blast", level = 102, cd = 54, dist = 1, target = 0, f = 120, t = "fire"},
        move9 = {name = "Tri Flames", level = 104, cd = 36, dist = 1, target = 0, f = 90, t = "fire"},
        move10 = {name = "War Dog", level = 106, cd = 24, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Shiny Abra"] =   {move1 = {name = "Shadow Ball", level = 120, cd = 8, dist = 10, target = 1, f = 60, t = "ghost"},
               move2 = {name = "Shadowave", level = 120, cd = 15, dist = 1, target = 0, f = 65, t = "dark"},
               move3 = {name = "Dark Pulse", level = 120, cd = 15, dist = 10, target = 1, f = 35, t = "dark"},
        move4 = {name = "Night Shade", level = 120, cd = 28, dist = 1, target = 0, f = 100, t = "ghost"},
        move5 = {name = "Psychic", level = 120, cd = 32, dist = 1, target = 0, f = 90, t = "psychic"},
        move6 = {name = "Invisible", level = 120, cd = 12, dist = 1, target = 0, f = 0, t = "ghost"},
        move7 = {name = "Nightmare", level = 120, cd = 63, dist = 10, target = 1, f = 90, t = "ghost"},
        move8 = {name = "Hypnosis", level = 120, cd = 72, dist = 10, target = 1, f = 0, t = "psychic"},
        move9 = {name = "Reflect", level = 120, cd = 54, dist = 1, target = 0, f = 0, t = "psychic"},
        move10 = {name = "Restore", level = 120, cd = 100, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Shiny Alakazam"] =   {move1 = {name = "Psybeam", level = 100, cd = 12, dist = 1, target = 0, f = 75, t = "psychic"},
        move2 = {name = "Psywave", level = 100, cd = 16, dist = 1, target = 0, f = 75, t = "psychic"},
        move3 = {name = "Psy Pulse", level = 100, cd = 12, dist = 10, target = 1, f = 35, t = "psychic"},
        move4 = {name = "Confusion", level = 100, cd = 28, dist = 1, target = 0, f = 50, t = "psychic"},
        move5 = {name = "Psychic", level = 100, cd = 32, dist = 1, target = 0, f = 80, t = "psychic"},
        move6 = {name = "Psyusion", level = 115, cd = 81, dist = 1, target = 0, f = 70, t = "psychic"},
        move7 = {name = "Calm Mind", level = 100, cd = 45, dist = 1, target = 0, f = 0, t = "psychic"},
        move8 = {name = "Hypnosis", level = 100, cd = 72, dist = 10, target = 1, f = 0, t = "psychic"},
        move9 = {name = "Reflect", level = 105, cd = 54, dist = 1, target = 0, f = 0, t = "psychic"},
        move10 = {name = "Restore", level = 105, cd = 150, dist = 1, target = 0, f = 0, t = "normal"},
        move11 = {name = "Miracle Eye", level = 100, cd = 40, dist = 1, target = 0, f = 0, t = "psychic"},
       },
  ["Shiny Machamp"] =    {move1 = {name = "Triple Punch", level = 100, cd = 10, dist = 1, target = 1, f = 60, t = "fighting"},
            move2 = {name = "Karate Chop", level = 100, cd = 15, dist = 1, target = 1, f = 50, t = "fighting"},
            move3 = {name = "Mega Punch", level = 100, cd = 22, dist = 1, target = 1, f = 85, t = "fighting"},
            move4 = {name = "Focus Blast", level = 100, cd = 30, dist = 1, target = 0, f = 100, t = "fighting"},
            move5 = {name = "Fist Machine", level = 100, cd = 30, dist = 1, target = 0, f = 105, t = "fighting"},
            move6 = {name = "Close Combat", level = 100, cd = 20, dist = 1, target = 1, f = 85, t = "fighting"},
            move7 = {name = "Mega Kick", level = 100, cd = 15, dist = 1, target = 1, f = 85, t = "fighting"},
            move8 = {name = "Agility", level = 100, cd = 30, dist = 1, target = 0, f = 0, t = "normal"},
            move9 = {name = "Foresight", level = 1, cd = 0, dist = 1, target = 1, f = 45, t = "fighting", passive = "sim"},
           },
  ["Shiny Tentacool"] =  {move1 = {name = "Super Sonic", level = 20, cd = 15, dist = 10, target = 1, f = 0, t = "normal"},
               move2 = {name = "Wrap", level = 20, cd = 20, dist = 10, target = 1, f = 0, t = "normal"}, 
        move3 = {name = "Bubbles", level = 20, cd = 10, dist = 10, target = 1, f = 40, t = "water"},
        move4 = {name = "Poison Jab", level = 20, cd = 16, dist = 10, target = 1, f = 85, t = "poison"},
        move5 = {name = "Waterball", level = 20, cd = 20, dist = 10, target = 1, f = 65, t = "water"},
        move6 = {name = "Bubblebeam", level = 20, cd = 20, dist = 10, target = 1, f = 60, t = "water"},
        move7 = {name = "Acid", level = 20, cd = 15, dist = 10, target = 1, f = 45, t = "poison"},
        move8 = {name = "Poison Bomb", level = 20, cd = 25, dist = 10, target = 1, f = 70, t = "poison"},
        move9 = {name = "Mortal Gas", level = 28, cd = 45, dist = 1, target = 0, f = 90, t = "poison"},
        move10 = {name = "Hydropump", level = 30, cd = 60, dist = 1, target = 0, f = 125, t = "water"},
       },
  ["Shiny Tentacruel"] = {move1 = {name = "Super Sonic", level = 100, cd = 15, dist = 10, target = 1, f = 0, t = "normal"},
               move2 = {name = "Wrap", level = 100, cd = 20, dist = 10, target = 1, f = 0, t = "normal"}, 
        move3 = {name = "Bubbles", level = 100, cd = 10, dist = 10, target = 1, f = 40, t = "water"},
        move4 = {name = "Poison Jab", level = 100, cd = 16, dist = 10, target = 1, f = 85, t = "poison"},
        move5 = {name = "Waterball", level = 100, cd = 20, dist = 10, target = 1, f = 65, t = "water"},
        move6 = {name = "Bubblebeam", level = 100, cd = 20, dist = 10, target = 1, f = 60, t = "water"},
        move7 = {name = "Acid", level = 100, cd = 15, dist = 10, target = 1, f = 45, t = "poison"},
        move8 = {name = "Poison Bomb", level = 100, cd = 25, dist = 10, target = 1, f = 70, t = "poison"},
        move9 = {name = "Mortal Gas", level = 110, cd = 45, dist = 1, target = 0, f = 90, t = "poison"},
        move10 = {name = "Hydropump", level = 105, cd = 60, dist = 1, target = 0, f = 125, t = "water"},
       },
  ["Shiny Golem"] =      {move1 = {name = "Rock Throw", level = 120, cd = 8, dist = 10, target = 1, f = 75, t = "rock"},
        move2 = {name = "Rock Slide", level = 122, cd = 12, dist = 10, target = 1, f = 55, t = "rock"},
        move3 = {name = "Stone Edge", level = 120, cd = 20, dist = 10, target = 1, f = 87, t = "rock"},
        move4 = {name = "Mega Punch", level = 120, cd = 24, dist = 1, target = 1, f = 105, t = "fighting"},
        move5 = {name = "Earth Power", level = 120, cd = 72, dist = 1, target = 0, f = 95, t = "ground"},
        move6 = {name = "Power Gem", level = 120, cd = 40, dist = 1, target = 0, f = 110, t = "rock"},
        move7 = {name = "Falling Rocks", level = 120, cd = 90, dist = 1, target = 0, f = 190, t = "rock"},
        move8 = {name = "Harden", level = 120, cd = 45, dist = 1, target = 0, f = 0, t = "normal"},
        move9 = {name = "Rollout", level = 120, cd = 54, dist = 1, target = 0, f = 30, t = "rock"},
        move10 = {name = "Selfdestruct", level = 120, cd = 120, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Shiny Magneton"] =   {move1 = {name = "Super Sonic", level = 120, cd = 35, dist = 10, target = 1, f = 0, t = "normal"},
        move2 = {name = "Thunder Shock", level = 120, cd = 10, dist = 10, target = 1, f = 55, t = "electric"},
        move3 = {name = "Spark", level = 120, cd = 15, dist = 10, target = 1, f = 50, t = "electric"},
        move4 = {name = "Tri-Attack", level = 130, cd = 25, dist = 10, target = 1, f = 25, t = "normal"},
        move5 = {name = "Thunder", level = 125, cd = 35, dist = 1, target = 0, f = 125, t = "electric"},
        move6 = {name = "Electric Storm", level = 120, cd = 50, dist = 1, target = 0, f = 150, t = "electric"},
        move7 = {name = "Zap Cannon", level = 120, cd = 40, dist = 1, target = 0, f = 80, t = "electric"},
        move8 = {name = "Hyper Beam", level = 135, cd = 25, dist = 1, target = 0, f = 190, t = "normal"},
        move9 = {name = "Sonicboom", level = 130, cd = 30, dist = 10, target = 1, f = 55, t = "normal"},
       },
  ["Shiny Farfetch'd"] = {move1 = {name = "Sand Attack", level = 100, cd = 15, dist = 1, target = 0, f = 0, t = "ground"},
        move2 = {name = "Drill Peck", level = 100, cd = 20, dist = 1, target = 1, f = 55, t = "flying"},
        move3 = {name = "Stick Throw", level = 104, cd = 20, dist = 1, target = 0, f = 75, t = "flying"},
        move4 = {name = "Stickslash", level = 102, cd = 25, dist = 1, target = 0, f = 70, t = "flying"},
        move5 = {name = "Stickmerang", level = 106, cd = 15, dist = 10, target = 1, f = 75, t = "flying"},
        move6 = {name = "Night Slash", level = 100, cd = 20, dist = 1, target = 0, f = 70, t = "dark"},
                move7 = {name = "Air Slash", level = 103, cd = 40, dist = 1, target = 0, f = 100, t = "flying"},
        move8 = {name = "Agility", level = 100, cd = 40, dist = 1, target = 0, f = 0, t = "flying"},
        move9 = {name = "Swords Dance", level = 108, cd = 60, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Shiny Dodrio"] =     {move1 = {name = "Sand Attack", level = 120, cd = 15, dist = 1, target = 0, f = 0, t = "ground"},
        move2 = {name = "Quick Attack", level = 120, cd = 10, dist = 2, target = 1, f = 40, t = "normal"},
        move3 = {name = "Drill Peck", level = 120, cd = 20, dist = 1, target = 1, f = 35, t = "flying"},
        move4 = {name = "Pluck", level = 125, cd = 15, dist = 1, target = 1, f = 60, t = "flying"},
        move5 = {name = "Tri-Attack", level = 135, cd = 25, dist = 10, target = 1, f = 25, t = "normal"},
         move6 = {name = "Roost", level = 125, cd = 60, dist = 1, target = 0, f = 0, t = "flying"},
        move7 = {name = "Aerial Ace", level = 124, cd = 60, dist = 1, target = 0, f = 190, t = "flying"},
        move8 = {name = "Rage", level = 120, cd = 20, dist = 1, target = 0, f = 0, t = "dragon"},
        move9 = {name = "Strafe", level = 120, cd = 20, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Shiny Grimer"] =     {move1 = {name = "Mud Shot", level = 20, cd = 12, dist = 10, target = 1, f = 40, t = "ground"},
        move2 = {name = "Acid", level = 20, cd = 8, dist = 10, target = 1, f = 45, t = "poison"},
        move3 = {name = "Sludge", level = 20, cd = 16, dist = 10, target = 1, f = 65, t = "poison"},
        move4 = {name = "Mud Bomb", level = 20, cd = 16, dist = 10, target = 1, f = 60, t = "ground"},
        move5 = {name = "Poison Bomb", level = 20, cd = 24, dist = 10, target = 1, f = 70, t = "poison"},
        move6 = {name = "Sludge Rain", level = 32, cd = 54, dist = 1, target = 0, f = 150, t = "poison"},
        move7 = {name = "Sludge Wave", level = 20, cd = 45, dist = 1, target = 0, f = 95, t = "poison"},
        move8 = {name = "Harden", level = 35, cd = 32, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Shiny Muk"] =        {move1 = {name = "Mud Shot", level = 100, cd = 12, dist = 10, target = 1, f = 40, t = "ground"},
        move2 = {name = "Acid", level = 100, cd = 8, dist = 10, target = 1, f = 45, t = "poison"},
        move3 = {name = "Sludge", level = 100, cd = 16, dist = 10, target = 1, f = 65, t = "poison"},
        move4 = {name = "Mud Bomb", level = 100, cd = 16, dist = 10, target = 1, f = 60, t = "ground"},
        move5 = {name = "Poison Bomb", level = 100, cd = 24, dist = 10, target = 1, f = 70, t = "poison"},
        move6 = {name = "Sludge Rain", level = 112, cd = 54, dist = 1, target = 0, f = 150, t = "poison"},
        move7 = {name = "Sludge Wave", level = 100, cd = 45, dist = 1, target = 0, f = 95, t = "poison"},
        move8 = {name = "Harden", level = 115, cd = 32, dist = 1, target = 0, f = 0, t = "normal"},
        move9 = {name = "Acid Armor", level = 108, cd = 50, dist = 1, target = 0, f = 0, t = "poison"},
       },
  ["Shiny Gengar"] =     {move1 = {name = "Lick", level = 100, cd = 32, dist = 1, target = 1, f = 0, t = "normal"},
        move2 = {name = "Shadow Ball", level = 100, cd = 12, dist = 10, target = 1, f = 60, t = "ghost"},
        move3 = {name = "Shadow Punch", level = 104, cd = 32, dist = 1, target = 1, f = 75, t = "ghost"},
        move4 = {name = "Night Shade", level = 100, cd = 28, dist = 1, target = 0, f = 80, t = "ghost"},
        move5 = {name = "Shadow Storm", level = 106, cd = 100, dist = 1, target = 0, f = 95, t = "ghost"},
        move6 = {name = "Invisible", level = 100, cd = 12, dist = 1, target = 0, f = 0, t = "ghost"},
        move7 = {name = "Nightmare", level = 100, cd = 63, dist = 10, target = 1, f = 80, t = "ghost"}, 
        move8 = {name = "Hypnosis", level = 100, cd = 72, dist = 10, target = 1, f = 0, t = "psychic"},
        move9 = {name = "Fear", level = 100, cd = 32, dist = 1, target = 0, f = 0, t = "ghost"},
        move10 = {name = "Dark Eye", level = 100, cd = 28, dist = 1, target = 0, f = 0, t = "ghost"},
       },
  ["Shiny Onix"] =       {move1 = {name = "Sand Attack", level = 100, cd = 12, dist = 1, target = 0, f = 0, t = "ground"},
        move2 = {name = "Iron Tail", level = 100, cd = 8, dist = 1, target = 1, f = 70, t = "steel"},  --alterado v1.9
        move3 = {name = "Rock Throw", level = 100, cd = 8, dist = 10, target = 1, f = 55, t = "rock"},
        move4 = {name = "Rock Slide", level = 100, cd = 12, dist = 10, target = 1, f = 35, t = "rock"},
        move5 = {name = "Earth Power", level = 100, cd = 24, dist = 1, target = 0, f = 75, t = "ground"},
        move6 = {name = "Falling Rocks", level = 100, cd = 45, dist = 1, target = 0, f = 190, t = "rock"},
        move7 = {name = "Earthquake", level = 100, cd = 36, dist = 1, target = 0, f = 15, t = "ground"},
        move8 = {name = "Harden", level = 100, cd = 28, dist = 1, target = 0, f = 0, t = "normal"},
        move9 = {name = "Camouflage", level = 104, cd = 40, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Shiny Hypno"] =      {move1 = {name = "Psy Pulse", level = 120, cd = 12, dist = 10, target = 1, f = 33, t = "psychic"},
        move2 = {name = "Psybeam", level = 120, cd = 12, dist = 1, target = 0, f = 75, t = "psychic"},
        move3 = {name = "Psywave", level = 120, cd = 12, dist = 1, target = 0, f = 75, t = "psychic"},
        move4 = {name = "Confusion", level = 120, cd = 20, dist = 1, target = 0, f = 50, t = "psychic"},
        move5 = {name = "Psychic", level = 120, cd = 24, dist = 1, target = 0, f = 80, t = "psychic"},
        move6 = {name = "Psyshock", level = 120, cd = 35, dist = 1, target = 0, f = 80, t = "psychic"},
        move7 = {name = "Dream Eater", level = 120, cd = 32, dist = 10, target = 1, f = 80, t = "psychic"},
        move8 = {name = "Hypnosis", level = 120, cd = 32, dist = 10, target = 1, f = 0, t = "psychic"},
        move9 = {name = "Focus", level = 120, cd = 24, dist = 1, target = 0, f = 0, t = "normal"},
        move10 = {name = "Miracle Eye", level = 120, cd = 40, dist = 1, target = 0, f = 0, t = "psychic"},
       },
  ["Shiny Krabby"] =     {move1 = {name = "Bubbles", level = 20, cd = 8, dist = 10, target = 1, f = 40, t = "water"},
        move2 = {name = "Bubblebeam", level = 20, cd = 16, dist = 10, target = 1, f = 40, t = "water"},
        move3 = {name = "Mud Shot", level = 20, cd = 16, dist = 10, target = 1, f = 40, t = "gound"},
        move4 = {name = "Crabhammer", level = 22, cd = 20, dist = 1, target = 1, f = 60, t = "normal"},
        move5 = {name = "Harden", level = 20, cd = 72, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Shiny Kingler"] =    {move1 = {name = "Bubbles", level = 60, cd = 10, dist = 10, target = 1, f = 40, t = "water"},
        move2 = {name = "Bubblebeam", level = 60, cd = 20, dist = 10, target = 1, f = 40, t = "water"},
        move3 = {name = "Mud Shot", level = 60, cd = 20, dist = 10, target = 1, f = 40, t = "ground"},
        move4 = {name = "Crabhammer", level = 60, cd = 30, dist = 1, target = 1, f = 60, t = "normal"},
        move5 = {name = "Metal Claw", level = 67, cd = 15, dist = 1, target = 1, f = 60, t = "steel"},   
        move6 = {name = "Brine", level = 60, cd = 40, dist = 1, target = 0, f = 100, t = "water"},
        move7 = {name = "Hyper Beam", level = 69, cd = 25, dist = 1, target = 0, f = 190, t = "normal"},
        move8 = {name = "Guillotine", level = 62, cd = 20, dist = 1, target = 1, f = 70, t = "normal"},
        move9 = {name = "Harden", level = 60, cd = 80, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Shiny Voltorb"] =    {move1 = {name = "Thunder Shock", level = 10, cd = 10, dist = 10, target = 1, f = 55, t = "electric"},
        move2 = {name = "Spark", level = 10, cd = 15, dist = 10, target = 1, f = 50, t = "electric"},
        move3 = {name = "Thunder Wave", level = 10, cd = 14, dist = 1, target = 0, f = 70, t = "electric"},
        move4 = {name = "Rollout", level = 10, cd = 45, dist = 1, target = 0, f = 15, t = "rock"},
        move5 = {name = "Charge Beam", level = 10, cd = 30, dist = 1, target = 0, f = 80, t = "electric"},
        move6 = {name = "Electric Storm", level = 15, cd = 60, dist = 1, target = 0, f = 150, t = "electric"},
        move7 = {name = "Selfdestruct", level = 10, cd = 120, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Shiny Electrode"] =  {move1 = {name = "Magic Coat", level = 80, cd = 60, dist = 1, target = 0, f = 0, t = "psychic"}, 
          move2 = {name = "Thunder Shock", level = 80, cd = 8, dist = 10, target = 1, f = 55, t = "electric"},
        move3 = {name = "Spark", level = 80, cd = 12, dist = 10, target = 1, f = 50, t = "electric"},
        move4 = {name = "Thunder Wave", level = 80, cd = 12, dist = 1, target = 0, f = 70, t = "electric"},
        move5 = {name = "Rollout", level = 80, cd = 36, dist = 1, target = 0, f = 15, t = "rock"},
        move6 = {name = "Charge Beam", level = 84, cd = 24, dist = 1, target = 0, f = 80, t = "electric"},
            move7 = {name = "Elecball", level = 92, cd = 45, dist = 1, target = 0, f = 70, t = "electric"},
        move8 = {name = "Electric Storm", level = 88, cd = 54, dist = 1, target = 0, f = 150, t = "electric"},
        move9 = {name = "Selfdestruct", level = 80, cd = 120, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Shiny Cubone"] =     {move1 = {name = "Mud Shot", level = 100, cd = 12, dist = 10, target = 1, f = 50, t = "ground"},
        move2 = {name = "Headbutt", level = 20, cd = 8, dist = 1, target = 1, f = 60, t = "normal"},
        move3 = {name = "Bonemerang", level = 20, cd = 12, dist = 10, target = 1, f = 70, t = "ground"},
        move4 = {name = "Bone Club", level = 20, cd = 16, dist = 10, target = 1, f = 80, t = "ground"},
        move5 = {name = "Bone Rush", level = 20, cd = 25, dist = 1, target = 0, f = 120, t = "ground"},
        move6 = {name = "Earth Power", level = 24, cd = 24, dist = 1, target = 0, f = 85, t = "ground"},
        move7 = {name = "Bulldoze", level = 26, cd = 28, dist = 1, target = 0, f = 95, t = "ground"},
        move8 = {name = "Rage", level = 30, cd = 20, dist = 1, target = 0, f = 0, t = "dragon"},
        move9 = {name = "Bone-Spin", level = 1, cd = 0, dist = 10, target = 0, f = 50, t = "ground", passive = "sim"},
       },
  ["Shiny Marowak"] =    {move1 = {name = "Mud Shot", level = 100, cd = 12, dist = 10, target = 1, f = 50, t = "ground"},
        move2 = {name = "Headbutt", level = 100, cd = 8, dist = 1, target = 1, f = 60, t = "normal"},
        move3 = {name = "Bonemerang", level = 100, cd = 12, dist = 10, target = 1, f = 70, t = "ground"},
        move4 = {name = "Bone Club", level = 100, cd = 16, dist = 10, target = 1, f = 80, t = "ground"},
        move5 = {name = "Bone Rush", level = 100, cd = 25, dist = 1, target = 0, f = 60, t = "ground"},
        move6 = {name = "Earth Power", level = 104, cd = 24, dist = 1, target = 0, f = 85, t = "ground"},
        move7 = {name = "Bulldoze", level = 106, cd = 28, dist = 1, target = 0, f = 95, t = "ground"},
        move8 = {name = "Rage", level = 110, cd = 20, dist = 1, target = 0, f = 0, t = "dragon"},
        move9 = {name = "Bone-Spin", level = 1, cd = 0, dist = 10, target = 0, f = 50, t = "ground", passive = "sim"},
       },
  ["Shiny Hitmonlee"] =  {move1 = {name = "Triple Kick Lee", level = 120, cd = 12, dist = 1, target = 1, f = 80, t = "fighting"},
        move2 = {name = "Mega Kick", level = 120, cd = 16, dist = 1, target = 1, f = 95, t = "fighting"},
        move3 = {name = "Multi-Kick", level = 120, cd = 20, dist = 1, target = 0, f = 125, t = "fighting"},
        move4 = {name = "Furious Legs", level = 120, cd = 24, dist = 1, target = 0, f = 0, t = "fighting"},
        move5 = {name = "Demon Kicker", level = 1, cd = 0, dist = 1, target = 1, f = 45, t = "fighting", passive = "sim"},
       },
  ["Shiny Hitmonchan"] = {move1 = {name = "Triple Punch", level = 120, cd = 12, dist = 1, target = 1, f = 80, t = "fighting"},
        move2 = {name = "Mega Punch", level = 120, cd = 16, dist = 1, target = 1, f = 95, t = "fighting"},
        move3 = {name = "Multi-Punch", level = 120, cd = 20, dist = 1, target = 0, f = 125, t = "fighting"},
        move4 = {name = "Ultimate Champion", level = 120, cd = 24, dist = 1, target = 0, f = 0, t = "fighting"},
        move5 = {name = "Elemental Hands", level = 120, cd = 1, dist = 1, target = 0, f = 0, t = "unknow"},
        move6 = {name = "Demon Puncher", level = 1, cd = 0, dist = 1, target = 1, f = 65, t = "unknow", passive = "sim"},
       },
  ["Shiny Rhydon"] =     {move1 = {name = "Horn Attack", level = 120, cd = 25, dist = 2, target = 1, f = 70, t = "normal"},
        move2 = {name = "Stone Edge", level = 120, cd = 20, dist = 10, target = 1, f = 67, t = "rock"}, 
        move3 = {name = "Rock Throw", level = 120, cd = 25, dist = 10, target = 1, f = 55, t = "rock"},
        move4 = {name = "Crusher Stomp", level = 120, cd = 45, dist = 1, target = 0, f = 110, t = "ground"},
        move5 = {name = "Horn Drill", level = 120, cd = 30, dist = 2, target = 1, f = 60, t = "normal"},
        move6 = {name = "Bulldoze", level = 123, cd = 50, dist = 1, target = 0, f = 90, t = "ground"},
        move7 = {name = "Hammer Arm", level = 120, cd = 60, dist = 1, target = 0, f = 80, t = "fighting"},
        move8 = {name = "Falling Rocks", level = 125, cd = 80, dist = 1, target = 0, f = 190, t = "rock"},
        move9 = {name = "Rock Drill", level = 127, cd = 35, dist = 1, target = 0, f = 90, t = "rock"},
       },
  ["Shiny Tangela"] =    {move1 = {name = "Absorb", level = 100, cd = 12, dist = 1, target = 1, f = 40, t = "grass"},
        move2 = {name = "Leech Seed", level = 100, cd = 8, dist = 10, target = 1, f = 1, t = "grass"},
        move3 = {name = "Vine Whip", level = 100, cd = 8, dist = 1, target = 0, f = 65, t = "grass"},
        move4 = {name = "Super Vines", level = 108, cd = 18, dist = 1, target = 0, f = 95, t = "grass"},
               move5 = {name = "Wrap", level = 100, cd = 30, dist = 10, target = 1, f = 0, t = "normal"},
        move6 = {name = "Poison Powder", level = 100, cd = 8, dist = 1, target = 0, f = 0, t = "normal"},
        move7 = {name = "Sleep Powder", level = 105, cd = 72, dist = 1, target = 0, f = 0, t = "normal"},
        move8 = {name = "Stun Spore", level = 100, cd = 24, dist = 1, target = 0, f = 0, t = "normal"},
        move9 = {name = "Mega Drain", level = 1, cd = 0, dist = 10, target = 0, f = 20, t = "grass", passive = "sim"},
        move10 = {name = "Spores Reaction", level = 1, cd = 0, dist = 10, target = 0, f = 0, t = "normal", passive = "sim"},
       },
  ["Shiny Horsea"] =     {move1 = {name = "Mud Shot", level = 10, cd = 15, dist = 10, target = 1, f = 40, t = "ground"},
        move2 = {name = "SmokeScreen", level = 10, cd = 40, dist = 1, target = 0, f = 0, t = "normal"},
        move3 = {name = "Quick Attack", level = 10, cd = 10, dist = 2, target = 1, f = 40, t = "normal"},
        move4 = {name = "Bubbles", level = 10, cd = 15, dist = 10, target = 1, f = 40, t = "water"},
        move5 = {name = "Bubblebeam", level = 10, cd = 20, dist = 10, target = 1, f = 40, t = "water"},
        move6 = {name = "Water Gun", level = 10, cd = 25, dist = 1, target = 0, f = 55, t = "water"},
        move7 = {name = "Dragon Pulse", level = 15, cd = 45, dist = 1, target = 0, f = 60, t = "dragon"},
        move8 = {name = "Hydro Cannon", level = 20, cd = 35, dist = 1, target = 0, f = 95, t = "water"},
       },
  ["Shiny Seadra"] =     {move1 = {name = "Mud Shot", level = 60, cd = 15, dist = 10, target = 1, f = 40, t = "ground"},
        move2 = {name = "SmokeScreen", level = 60, cd = 40, dist = 1, target = 0, f = 0, t = "normal"},
        move3 = {name = "Quick Attack", level = 60, cd = 10, dist = 2, target = 1, f = 40, t = "normal"},
        move4 = {name = "Bubbles", level = 60, cd = 15, dist = 10, target = 1, f = 40, t = "water"},
        move5 = {name = "Bubblebeam", level = 60, cd = 20, dist = 10, target = 1, f = 40, t = "water"},
        move6 = {name = "Water Gun", level = 60, cd = 25, dist = 1, target = 0, f = 55, t = "water"},
        move7 = {name = "Dragon Pulse", level = 65, cd = 45, dist = 1, target = 0, f = 60, t = "dragon"},
        move8 = {name = "Hydro Cannon", level = 65, cd = 35, dist = 1, target = 0, f = 95, t = "water"},
       },
  ["Shiny Mr. Mime"] =   {move1 = {name = "Doubleslap", level = 100, cd = 10, dist = 1, target = 1, f = 25, t = "normal"},
                move2 = {name = "Psywave", level = 100, cd = 15, dist = 1, target = 0, f = 75, t = "psychic"},
                move3 = {name = "Magical Leaf", level = 100, cd = 15, dist = 10, target = 1, f = 35, t = "grass"},
        move4 = {name = "Confusion", level = 100, cd = 35, dist = 1, target = 0, f = 50, t = "psychic"},
        move5 = {name = "Psychic", level = 100, cd = 30, dist = 1, target = 0, f = 90, t = "psychic"},
        move6 = {name = "Psyusion", level = 115, cd = 60, dist = 1, target = 0, f = 70, t = "psychic"},
        move7 = {name = "Ice Punch", level = 100, cd = 25, dist = 1, target = 1, f = 75, t = "ice"},
        move8 = {name = "Reflect", level = 100, cd = 35, dist = 1, target = 0, f = 0, t = "psychic"},
        move9 = {name = "Barrier", level = 120, cd = 25, dist = 1, target = 0, f = 0, t = "psychic"},
        move10 = {name = "Mimic Wall", level = 100, cd = 3, dist = 1, target = 0, f = 0, t = "psychic"},
        move11 = {name = "Miracle Eye", level = 100, cd = 40, dist = 1, target = 0, f = 0, t = "psychic"},
       },
  ["Shiny Scyther"] =    {move1 = {name = "Quick Attack", level = 100, cd = 8, dist = 2, target = 1, f = 40, t = "normal"},
        move2 = {name = "Slash", level = 100, cd = 20, dist = 1, target = 1, f = 60, t = "normal"},
        move3 = {name = "Wing Attack", level = 100, cd = 28, dist = 1, target = 0, f = 75, t = "flying"},
        move4 = {name = "Fury Cutter", level = 105, cd = 12, dist = 1, target = 0, f = 65, t = "bug"},
        move5 = {name = "Shredder Team", level = 115, cd = 32, dist = 1, target = 0, f = 0, t = "normal"},
        move6 = {name = "Air Slash", level = 110, cd = 30, dist = 1, target = 0, f = 100, t = "flying"},
        move7 = {name = "Agility", level = 100, cd = 32, dist = 1, target = 0, f = 0, t = "flying"},
        move8 = {name = "Team Slice", level = 118, cd = 5, dist = 10, target = 1, f = 80, t = "bug"},
        move9 = {name = "Counter Helix", level = 1, cd = 0, dist = 10, target = 0, f = 55, t = "bug", passive = "sim"},
       },
  ["Shiny Jynx"] =       {move1 = {name = "Lovely Kiss", level = 100, cd = 12, dist = 10, target = 1, f = 0, t = "normal"},
        move2 = {name = "Doubleslap", level = 100, cd = 8, dist = 1, target = 1, f = 25, t = "normal"},
        move3 = {name = "Psywave", level = 100, cd = 16, dist = 1, target = 0, f = 75, t = "psychic"},
        move4 = {name = "Psy Pulse", level = 100, cd = 12, dist = 10, target = 1, f = 33, t = "psychic"},
        move5 = {name = "Ice Punch", level = 100, cd = 20, dist = 1, target = 1, f = 75, t = "ice"},
        move6 = {name = "Ice Beam", level = 100, cd = 20, dist = 1, target = 0, f = 195, t = "ice"},
        move7 = {name = "Icy Wind", level = 100, cd = 28, dist = 1, target = 0, f = 45, t = "ice"},
        move8 = {name = "Aurora Beam", level = 104, cd = 16, dist = 1, target = 0, f = 190, t = "ice"},
        move9 = {name = "Blizzard", level = 106, cd = 54, dist = 1, target = 0, f = 150, t = "ice"},
        move10 = {name = "Great Love", level = 108, cd = 45, dist = 1, target = 0, f = 50, t = "normal"},
       },
  ["Shiny Electabuzz"] = {move1 = {name = "Quick Attack", level = 100, cd = 8, dist = 2, target = 1, f = 50, t = "normal"},
        move2 = {name = "Low Kick", level = 100, cd = 25, dist = 1, target = 1, f = 75, t = "fighting"},
        move3 = {name = "Thunder Punch", level = 100, cd = 16, dist = 1, target = 1, f = 85, t = "electric"},
        move4 = {name = "Thunder Shock", level = 100, cd = 8, dist = 10, target = 1, f = 65, t = "electric"},
        move5 = {name = "Thunder Bolt", level = 100, cd = 20, dist = 10, target = 1, f = 73, t = "electric"},
        move6 = {name = "Thunder Wave", level = 100, cd = 20, dist = 1, target = 0, f = 70, t = "electric"},
        move7 = {name = "Thunder", level = 100, cd = 28, dist = 1, target = 0, f = 125, t = "electric"},
        move8 = {name = "Electric Storm", level = 105, cd = 72, dist = 1, target = 0, f = 150, t = "electric"},
        move9 = {name = "Shock-Counter", level = 1, cd = 0, dist = 10, target = 0, f = 50, t = "electric", passive = "sim"},
       },
  ["Shiny Magmar"] =     {move1 = {name = "Scratch", level = 100, cd = 10, dist = 1, target = 1, f = 40, t = "normal"},
        move2 = {name = "Fire Punch", level = 100, cd = 30, dist = 1, target = 1, f = 75, t = "fire"},
        move3 = {name = "Ember", level = 100, cd = 10, dist = 10, target = 1, f = 40, t = "fire"},
        move4 = {name = "Flamethrower", level = 100, cd = 15, dist = 1, target = 0, f = 80, t = "fire"},
        move5 = {name = "Fireball", level = 100, cd = 20, dist = 10, target = 1, f = 65, t = "fire"},
        move6 = {name = "Fire Blast", level = 100, cd = 40, dist = 1, target = 0, f = 120, t = "fire"},
        move7 = {name = "Magma Storm", level = 105, cd = 90, dist = 1, target = 0, f = 150, t = "fire"},
        move8 = {name = "Sunny Day", level = 106, cd = 60, dist = 1, target = 0, f = 0, t = "fire"},
        move9 = {name = "Lava-Counter", level = 1, cd = 0, dist = 10, target = 0, f = 50, t = "fire", passive = "sim"},
       },
  ["Shiny Pinsir"] =     {move1 = {name = "Bug Bite", level = 100, cd = 10, dist = 1, target = 1, f = 50, t = "bug"},
        move2 = {name = "Hammer Arm", level = 100, cd = 60, dist = 1, target = 0, f = 80, t = "fighting"},
        move3 = {name = "X-Scissor", level = 105, cd = 25, dist = 1, target = 0, f = 65, t = "bug"},
        move4 = {name = "Fury Cutter", level = 108, cd = 25, dist = 1, target = 0, f = 65, t = "bug"},
        move5 = {name = "Guillotine", level = 110, cd = 20, dist = 1, target = 1, f = 70, t = "normal"}, 
        move6 = {name = "Revenge", level = 112, cd = 25, dist = 1, target = 0, f = 100, t = "fighting"},
        move7 = {name = "Megahorn", level = 110, cd = 35, dist = 1, target = 0, f = 90, t = "bug"},
        move8 = {name = "Harden", level = 102, cd = 25, dist = 1, target = 0, f = 0, t = "normal"},
        move9 = {name = "Rage", level = 115, cd = 25, dist = 1, target = 0, f = 0, t = "dragon"},
        move10 = {name = "Swords Dance", level = 108, cd = 60, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Shiny Tauros"] =     {move1 = {name = "Headbutt", level = 50, cd = 10, dist = 1, target = 1, f = 50, t = "normal"},
        move2 = {name = "Body Slam", level = 50, cd = 15, dist = 1, target = 1, f = 80, t = "normal"},
        move3 = {name = "Horn Attack", level = 50, cd = 15, dist = 2, target = 1, f = 60, t = "normal"},
        move4 = {name = "Hyper Beam", level = 55, cd = 25, dist = 1, target = 0, f = 190, t = "normal"},
        move5 = {name = "Thrash", level = 56, cd = 25, dist = 1, target = 0, f = 80, t = "normal"},
        move6 = {name = "Rage", level = 50, cd = 20, dist = 1, target = 0, f = 0, t = "dragon"},
        move7 = {name = "Rest", level = 60, cd = 60, dist = 1, target = 0, f = 0, t = "normal"},
        move8 = {name = "Fear", level = 58, cd = 25, dist = 1, target = 0, f = 0, t = "ghost"},
       },
  ["Shiny Magikarp"] =   {move1 = {name = "Tackle", level = 30, cd = 10, dist = 1, target = 1, f = 50, t = "normal"},
        move2 = {name = "Splash", level = 30, cd = 5, dist = 1, target = 0, f = 70, t = "water"},
        move3 = {name = "Waterfall", level = 30, cd = 15, dist = 1, target = 0, f = 45, t = "water"}, 
       },
  ["Shiny Gyarados"] =   {move1 = {name = "Roar", level = 130, cd = 30, dist = 1, target = 0, f = 0, t = "normal"},
        move2 = {name = "Bite", level = 120, cd = 15, dist = 1, target = 1, f = 40, t = "dark"},
        move3 = {name = "Aqua Tail", level = 120, cd = 15, dist = 1, target = 1, f = 50, t = "water"},
        move4 = {name = "Waterball", level = 120, cd = 20, dist = 10, target = 1, f = 60, t = "water"},
        move5 = {name = "Twister", level = 124, cd = 30, dist = 1, target = 0, f = 80, t = "dragon"},
        move6 = {name = "Hydro Cannon", level = 120, cd = 45, dist = 1, target = 0, f = 95, t = "water"},
        move7 = {name = "Dragon Breath", level = 120, cd = 30, dist = 1, target = 0, f = 80, t = "dragon"},
        move8 = {name = "Hyper Beam", level = 120, cd = 45, dist = 1, target = 0, f = 190, t = "normal"},
        move9 = {name = "Hydropump", level = 128, cd = 70, dist = 1, target = 0, f = 120, t = "water"},
        move10 = {name = "Rain Dance", level = 130, cd = 50, dist = 1, target = 0, f = 0, t = "water"},
       },
  ["Shiny Ditto"] =      {},
  ["Shiny Vaporeon"] =   {move1 = {name = "Quick Attack", level = 120, cd = 8, dist = 10, target = 1, f = 40, t = "normal"},
        move2 = {name = "Bite", level = 120, cd = 12, dist = 1, target = 1, f = 50, t = "dark"},
        move3 = {name = "Water Gun", level = 120, cd = 16, dist = 1, target = 0, f = 55, t = "water"},
        move4 = {name = "Bubblebeam", level = 120, cd = 16, dist = 10, target = 1, f = 40, t = "water"},
        move5 = {name = "Water Pulse", level = 120, cd = 16, dist = 1, target = 0, f = 70, t = "water"},
        move6 = {name = "Muddy Water", level = 120, cd = 20, dist = 1, target = 0, f = 125, t = "water"},
        move7 = {name = "Aurora Beam", level = 120, cd = 20, dist = 1, target = 0, f = 190, t = "ice"},
        move8 = {name = "Hydro Cannon", level = 120, cd = 32, dist = 1, target = 0, f = 95, t = "water"},
        move9 = {name = "Hydropump", level = 120, cd = 63, dist = 1, target = 0, f = 120, t = "water"},
        move10 = {name = "Safeguard", level = 70, cd = 40, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Shiny Jolteon"] =    {move1 = {name = "Quick Attack", level = 120, cd = 8, dist = 2, target = 1, f = 70, t = "normal"},
        move2 = {name = "Bite", level = 120, cd = 10, dist = 1, target = 1, f = 70, t = "dark"},
        move3 = {name = "Thunder Bolt", level = 120, cd = 16, dist = 10, target = 1, f = 75, t = "electric"},
        move4 = {name = "Thunder Fang", level = 120, cd = 16, dist = 1, target = 1, f = 65, t = "electric"},
        move5 = {name = "Thunder Wave", level = 120, cd = 16, dist = 1, target = 0, f = 90, t = "electric"},
        move6 = {name = "Pin Missile", level = 120, cd = 20, dist = 1, target = 0, f = 110, t = "bug"},
        move7 = {name = "Zap Cannon", level = 120, cd = 32, dist = 1, target = 0, f = 90, t = "electric"},
        move8 = {name = "Thunder", level = 120, cd = 24, dist = 1, target = 0, f = 125, t = "electric"},
        move9 = {name = "Electric Storm", level = 120, cd = 63, dist = 1, target = 0, f = 150, t = "electric"},
        move10 = {name = "Safeguard", level = 70, cd = 40, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Shiny Flareon"] =    {move1 = {name = "Quick Attack", level = 120, cd = 8, dist = 2, target = 1, f = 70, t = "normal"},
        move2 = {name = "Bite", level = 120, cd = 12, dist = 1, target = 1, f = 70, t = "dark"},
        move3 = {name = "Flamethrower", level = 120, cd = 16, dist = 1, target = 0, f = 90, t = "fire"},
        move4 = {name = "Sacred Fire", level = 120, cd = 16, dist = 10, target = 1, f = 90, t = "fire"},
        move5 = {name = "Blaze Kick", level = 120, cd = 16, dist = 1, target = 0, f = 90, t = "fire"},
        move6 = {name = "Flame Burst", level = 120, cd = 20, dist = 1, target = 0, f = 90, t = "fire"},
        move7 = {name = "Overheat", level = 120, cd = 24, dist = 1, target = 0, f = 90, t = "fire"}, 
        move8 = {name = "Fire Blast", level = 120, cd = 32, dist = 1, target = 0, f = 140, t = "fire"},
        move9 = {name = "Magma Storm", level = 120, cd = 63, dist = 1, target = 0, f = 150, t = "fire"},
        move10 = {name = "Safeguard", level = 70, cd = 40, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Shiny Snorlax"] =    {move1 = {name = "Lick", level = 200, cd = 30, dist = 1, target = 1, f = 0, t = "normal"},
        move2 = {name = "Bite", level = 200, cd = 15, dist = 1, target = 1, f = 50, t = "dark"},
        move3 = {name = "Crunch", level = 200, cd = 10, dist = 1, target = 0, f = 65, t = "dark"},  
        move4 = {name = "Focus Blast", level = 200, cd = 25, dist = 1, target = 0, f = 65, t = "fighting"},
        move5 = {name = "Body Slam", level = 200, cd = 20, dist = 1, target = 1, f = 80, t = "normal"},
        move6 = {name = "Ground Chop", level = 200, cd = 25, dist = 1, target = 0, f = 100, t = "fighting"},
        move7 = {name = "Hyper Beam", level = 200, cd = 30, dist = 1, target = 0, f = 190, t = "normal"},
        move8 = {name = "Crusher Stomp", level = 200, cd = 45, dist = 1, target = 0, f = 110, t = "ground"},
        move9 = {name = "Rest", level = 200, cd = 60, dist = 1, target = 0, f = 0, t = "normal"},
       },
  ["Shiny Dratini"] =    {move1 = {name = "Aqua Tail", level = 20, cd = 12, dist = 1, target = 1, f = 70, t = "water"},
        move2 = {name = "Thunder Wave", level = 20, cd = 16, dist = 1, target = 0, f = 90, t = "electric"},
        move3 = {name = "Body Slam", level = 20, cd = 12, dist = 1, target = 1, f = 90, t = "normal"},
               move4 = {name = "Wrap", level = 20, cd = 20, dist = 10, target = 1, f = 0, t = "normal"},
        move5 = {name = "Dragon Claw", level = 20, cd = 16, dist = 1, target = 1, f = 80, t = "dragon"},
        move6 = {name = "Dragon Breath", level = 22, cd = 16, dist = 1, target = 0, f = 100, t = "dragon"},
        move7 = {name = "Twister", level = 24, cd = 24, dist = 1, target = 0, f = 100, t = "dragon"},
        move8 = {name = "Hyper Beam", level = 28, cd = 20, dist = 1, target = 0, f = 190, t = "normal"},
       },
  ["Shiny Dragonair"] =  {move1 = {name = "Aqua Tail", level = 100, cd = 12, dist = 1, target = 1, f = 70, t = "water"},
        move2 = {name = "Thunder Wave", level = 100, cd = 16, dist = 1, target = 0, f = 90, t = "electric"},
        move3 = {name = "Body Slam", level = 100, cd = 12, dist = 1, target = 1, f = 90, t = "normal"},
               move4 = {name = "Wrap", level = 100, cd = 20, dist = 10, target = 1, f = 0, t = "normal"},
        move5 = {name = "Dragon Claw", level = 100, cd = 16, dist = 1, target = 1, f = 80, t = "dragon"},
        move6 = {name = "Dragon Breath", level = 102, cd = 16, dist = 1, target = 0, f = 100, t = "dragon"},
        move7 = {name = "Twister", level = 104, cd = 24, dist = 1, target = 0, f = 100, t = "dragon"},
        move8 = {name = "Hyper Beam", level = 108, cd = 20, dist = 1, target = 0, f = 190, t = "normal"},
              move9 = {name = "Draco Meteor", level = 115, cd = 60, dist = 1, target = 0, f = 150, t = "dragon"},
       },
  }
  