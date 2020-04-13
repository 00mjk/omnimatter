if not omni then omni={} end
if not omni.marathon then omni.marathon={} end

standardized_recipes={}

local function set_loc_name(item) --pass full table
	if item then
		if item.localised_name then
			loc_name = table.deepcopy(item.localised_name)
		elseif item.type == item and item.place_result then
			loc_name = {"entity-name."..item.place_result}
		elseif item.place_result then
			loc_name = {"entity-name."..item.name}
		elseif string.find(item.name,"equipment") ~= nil then
			loc_name = {"equipment-name."..item.name}
		elseif item.type == "fluid" then
			 loc_name = {item.type.."-name."..item.name}
		else --should cover items, fluids etc...
 			loc_name = {item.type.."-name."..item.name}
 		end
	end
return loc_name
end

function omni.marathon.standardise(recipe)
	if recipe == nil then return nil end
	if recipe.result or (recipe.normal and recipe.normal.result) then --if the recipe was changed after initial standardisation, re-standardise
		standardized_recipes[recipe.name]=false
	end
	if standardized_recipes[recipe.name] then return recipe end
	--local new = table.deepcopy(recipe)
	if not recipe.expensive then recipe.expensive={} end
	if not recipe.normal then recipe.normal={} end
	local ingredients = {}
	--ingredients.normal = recipe.ingredients
	if recipe.normal and recipe.normal.ingredients and recipe.expensive and recipe.expensive.ingredients then
		ingredients.normal = table.deepcopy(recipe.normal.ingredients)
		ingredients.expensive = table.deepcopy(recipe.expensive.ingredients)
	elseif recipe.normal and recipe.normal.ingredients and not (recipe.expensive and recipe.expensive.ingredients) then
		ingredients.normal = table.deepcopy(recipe.normal.ingredients)
		ingredients.expensive = table.deepcopy(recipe.normal.ingredients)
	else
		ingredients = {expensive=table.deepcopy(recipe.ingredients),normal=table.deepcopy(recipe.ingredients)}
	end
	local std_ingredients = {normal = {}, expensive = {}}
	local it={}
	if recipe.localized_name == nil and recipe.main_product and recipe.main_product~="" then
		it = omni.lib.find_prototype(recipe.main_product)
		recipe.localised_name=set_loc_name(it)
	elseif recipe.localized_name == nil and recipe.normal and recipe.normal.main_product and recipe.normal.main_product~="" then
		local it = omni.lib.find_prototype(recipe.normal.main_product)
		recipe.localised_name=set_loc_name(it)
	end
	--[[if recipe.localized_name == nil and recipe.expensive and recipe.expensive.main_product and recipe.expensive.main_product~="" then
		local it = omni.lib.find_prototype(recipe.expensive.main_product)
	end]]
	recipe.normal.ingredients={}
	recipe.expensive.ingredients={}
	for _, diff in pairs({"normal","expensive"}) do
		if ingredients[diff] then
			for i,ing in pairs(ingredients[diff]) do
				local temp = {}
				if ing.name then
					temp = {type = ing.type, name=ing.name,amount=ing.amount,maximum_temperature=ing.maximum_temperature,minimum_temperature=ing.minimum_temperature,fluidbox_index=ing.fluidbox_index}
					if not temp.type then temp.type ="item" end
				else
					temp = {type = "item", name=ing[1],amount=ing[2]}
				end
				recipe[diff].ingredients[i]=table.deepcopy(temp)
			end
		end
	end
	local results = {}
	if recipe.normal and (recipe.normal.results or recipe.normal.result)then
		if recipe.normal.results then
			results.normal = table.deepcopy(recipe.normal.results)
		else
			results.normal = {{recipe.normal.result,recipe.normal.result_count or 1}}
			if not results.normal[1][2] then results.normal[1][2]=1 end
		end
	end
	if recipe.expensive and (recipe.expensive.results or recipe.expensive.result)then
		if recipe.expensive.results then
			results.expensive = table.deepcopy(recipe.expensive.results)
		else
			results.expensive = {{recipe.expensive.result,recipe.expensive.result_count}}
			if not results.expensive[1][2] then results.expensive[1][2]=1 end
		end
	end
	if recipe.results or recipe.result then
		if recipe.results then
			if not results.expensive then results.expensive = table.deepcopy(recipe.results) end
			if not results.normal then results.normal = table.deepcopy(recipe.results) end
		else
			if not results.expensive then results.expensive = {{recipe.result,recipe.result_count or 1}} end
			if not results.normal then results.normal = {{recipe.result,recipe.result_count or 1}} end
			if not (results.expensive[1] and results.expensive[1][2]) then results.expensive[1][2]=1 end
			if not results.normal[1][2] then results.normal[1][2]=1 end
		end
	end
	if not results.expensive then results.expensive = table.deepcopy(results.normal) end
	std_results = {normal={},expensive={}}
	recipe.normal.results={}
	recipe.expensive.results={}
	for i, diff in pairs({"normal","expensive"}) do
		if results[diff] then
			for j,res in pairs(results[diff]) do
				local temp = {}
				if res.name then
					temp = {type = res.type, name=res.name,amount=res.amount,probability = res.probability, amount_min = res.amount_min, amount_max = res.amount_max,temperature=res.temperature,fluidbox_index=res.fluidbox_index}
					if not temp.type then temp.type ="item" end
				else
					temp = {type = "item", name=res[1],amount=res[2]}
				end
				recipe[diff].results[j] = table.deepcopy(temp)
			end
		end
	end
	recipe.result = nil
	recipe.result_count = nil
	recipe.results = nil
	recipe.ingredients = nil
	if recipe.localised_name == nil and #recipe.normal.results==1 then
		local it = omni.lib.find_prototype(recipe.normal.results[1].name)
		set_loc_name(it)
		--[[if it then
			if it.localised_name then
				recipe.localised_name = table.deepcopy(it.localised_name)
			elseif it.place_result then
				 recipe.localised_name = {"entity-name."..it.name}
			elseif it.type == "fluid" then
				 recipe.localised_name = {it.type.."-name."..it.name}
			else
				recipe.localised_name = {"item-name."..it.name}
			end
		end]]
	end

	--new.normal.ingredients=std_ingredients.normal
	--new.normal.results=std_results.normal
	--new.expensive.ingredients=std_ingredients.expensive
	--new.expensive.results=std_results.expensive

	--if #recipe.normal.results==1 then recipe.normal.main_product = recipe.normal.results[1].name end
	--if #recipe.expensive.results==1 then recipe.expensive.main_product = recipe.expensive.results[1].name end

	for _, flag in pairs({"hidden", "enabled", "allow_decomposition", "hide_from_player_crafting", "allow_as_intermediate", "allow_intermediates"}) do
		for _, difficulty in pairs({"normal", "expensive"}) do
			if recipe[difficulty][flag] == nil then recipe[difficulty][flag] = recipe[flag] end
		end
	end

	-- if recipe.normal.hidden == nil then recipe.normal.hidden = recipe.hidden end
	-- if recipe.expensive.hidden == nil then recipe.expensive.hidden = recipe.hidden end
	-- if recipe.normal.enabled == nil then recipe.normal.enabled = recipe.enabled end
	-- if recipe.expensive.enabled == nil then recipe.expensive.enabled = recipe.enabled end

	if not recipe.subgroup and recipe.main_product and recipe.main_product ~="" then
		local it = omni.lib.find_prototype(recipe.main_product)
		if it then
			if it.subgroup then
				recipe.subgroup = it.subgroup
			elseif it.type=="fluid" then
				recipe.subgroup="fluid-recipes"
			end
		end
	elseif not recipe.subgroup and #recipe.normal.results == 1 then
		local it = omni.lib.find_prototype(recipe.normal.results[1].name)
		if it then
			if it.subgroup then
				recipe.subgroup = it.subgroup
			elseif it.type=="fluid" then
				recipe.subgroup="fluid-recipes"
			end
		end
	end

	--[[
	if recipe.normal.subgroup == nil then
		if recipe.subgroup then
			recipe.normal.subgroup = recipe.subgroup
		elseif #recipe.normal.results == 1 then
			local proto = omni.lib.find_prototype(recipe.normal.results[1].name)
			if proto then
				recipe.normal.subgroup = proto.subgroup
			end
		end
	end
	if recipe.expensive.subgroup == nil then
		if recipe.subgroup then
			recipe.expensive.subgroup = recipe.subgroup
		elseif #recipe.expensive.results == 1 then
			local proto = omni.lib.find_prototype(recipe.expensive.results[1].name)
			recipe.expensive.subgroup = proto.subgroup
		end
	end]]

	--recipe.main_product = recipe.main_product or recipe.normal.main_product or recipe.expensive.main_product
	--recipe.normal.main_product=recipe.main_product or recipe.normal.main_product or recipe.expensive.main_product
	--recipe.expensive.main_product=recipe.main_product or recipe.normal.main_product or recipe.expensive.main_product


	if recipe.normal.category == nil then recipe.normal.category = recipe.category end
	if recipe.expensive.category == nil then recipe.expensive.category = recipe.category end

	--recipe.normal.main_product = recipe.normal.main_product or recipe.main_product
	--recipe.expensive.main_product = recipe.expensive.main_product or recipe.main_product

	if recipe.normal.energy_required == nil then recipe.normal.energy_required = recipe.energy_required or 0.5 end
	if recipe.expensive.energy_required == nil then recipe.expensive.energy_required = recipe.energy_required or 0.5 end
	recipe.hidden = nil
	recipe.enabled = nil

	if recipe.normal == false then recipe.normal = table.deepcopy(recipe.expensive) end

	recipe.energy_required = nil
	if (recipe.main_product and recipe.main_product ~= "") or (recipe.normal.main_product and recipe.normal.main_product ~= "") or (recipe.expensive.main_product and recipe.expensive.main_product ~= "") then
		local item = omni.lib.find_prototype(recipe.main_product or recipe.normal.main_product or recipe.expensive.main_product)
		if item then
			if item.icon then recipe.icon = item.icon end
			if item.icons then recipe.icons = item.icons end
			if item.icon_size then recipe.icon_size = item.icon_size end
		end
	else
		if recipe.result and recipe.result.name then
			res=recipe.result.name
		elseif recipe.result then
			res=recipe.result 
		elseif recipe.results and recipe.results[1] and recipe.results[1].name then
			res=recipe.results[1].name
		elseif 	recipe.normal.results and recipe.normal.results[1] and recipe.normal.results[1].name then
			res=recipe.normal.results[1].name
		else
			res=recipe.name
		end
		local item = omni.lib.find_prototype(res)
		if item then
			if item.icon then recipe.icon = item.icon end
			if item.icons then recipe.icons = item.icons end
			if item.icon_size then recipe.icon_size = item.icon_size end
		end
	end
	if recipe.icon and recipe.icon ~= "" then
		recipe.icons = {{icon=recipe.icon,icon_size=recipe.icon_size}}
		recipe.icon=nil
	end
	recipe.main_product=nil
	recipe.normal.main_product=nil
	recipe.expensive.main_product=nil
	standardized_recipes[recipe.name] = true
	return table.deepcopy(recipe)
end
