local fluid_solid = {}

local solid_contain = 60

local top_value = 50000
local roundFluidValues = {}
local b,c,d = math.log(5),math.log(3),math.log(2)
for i=0,math.floor(math.log(top_value)/b) do
    local pow5 = math.pow(5,i)
    for j=0,math.floor(math.log(top_value/pow5)/c) do
        local pow3=math.pow(3,j)
        for k=0,math.floor(math.log(top_value/pow5/pow3)/d) do
            roundFluidValues[#roundFluidValues+1] = pow5*pow3*math.pow(2,k)
        end
    end
end
table.sort(roundFluidValues)

local round_fluid = function(nr)
	local t = omni.lib.round(nr)
	local mod={30,20,15, 12, 10,6}
	local pick = 1
	local dif = 1
	for j,m in pairs(mod) do
		local ch = t%m
		if math.min(ch,m-ch)/m < dif then
			pick = m
			dif = math.min(ch,m-ch)/m
		end
	end
	local val = 0
	local ch = t%pick
	if pick-ch < ch then val = t+pick-ch else val = t-ch end
	local newval = val
	for p,inner in pairs(primeRound) do
		local prime = tonumber(p)
		if val%prime == 0 then
			local cval= newval/prime
			if cval * inner.above-newval < newval-cval * inner.below then
				newval = newval / prime * inner.above
			else
				newval = newval / prime * inner.above
			end
		end
	end
	return math.max(newval,60)
end

local round_fluid = function(nr)
	local t = omni.lib.round(nr)
	local newval = t
	for i=1,#roundFluidValues do
		if roundFluidValues[i]< t and roundFluidValues[i+1]>t then
			if t-roundFluidValues[i] < roundFluidValues[i+1]-t then
				newval = roundFluidValues[i]
			else
				newval = roundFluidValues[i+1]
			end
		end
	end
	return math.max(newval,60)
end

local convert_mj=function(value)
	local unit = string.sub(value,string.len(value)-1,string.len(value)-1)
	local val = tonumber(string.sub(value,1,string.len(value)-2))
	if unit == "K" or unit == "k" then
		return val/1000
	elseif unit == "M" then
		return val
	elseif unit=="G" then
		return val*1000
	elseif tonumber(unit) ~= nil then
		return tonumber(string.sub(value,1,string.len(value)-1))
	end
end

local generator_fluid={}
for _, gen in pairs(data.raw.generator) do
	if not string.find(gen.name,"creative") then
		if not gen.burns_fluid and gen.fluid_box and gen.fluid_box.filter then
			if not generator_fluid[gen.fluid_box.filter] then
				generator_fluid[gen.fluid_box.filter]={name=gen.fluid_box.filter,temperature={}}
				generator_fluid[gen.fluid_box.filter].temperature[1]={min = gen.fluid_box.minimum_temperature, max=gen.maximum_temperature}
			else
				table.insert(generator_fluid[gen.fluid_box.filter].temperature,{min = gen.fluid_box.minimum_temperature, max=gen.maximum_temperature})
			end
		end
	end
end

local new_boiler = {}

local fix_boilers_recipe = {}
local fix_boilers_item = {}

for _,boiler in pairs(data.raw.boiler) do
	if generator_fluid[boiler.output_fluid_box.filter] then
		generator_fluid[boiler.output_fluid_box.filter] = nil
	end
	
	if not forbidden_boilers[boiler.name] and data.raw.fluid[boiler.fluid_box.filter] and data.raw.fluid[boiler.fluid_box.filter].heat_capacity and boiler.minable then
		local rec = omni.lib.find_recipe(boiler.minable.result)
		--log(boiler.name)
		new_boiler[#new_boiler+1]={
			type = "recipe-category",
			name = "boiler-omnifluid-"..boiler.name,
		}
		if standardized_recipes[boiler.name] == nil then
			omni.marathon.standardise(data.raw.recipe[boiler.name])
		end
		fix_boilers_recipe[#fix_boilers_recipe+1]=rec.name
		fix_boilers_item[boiler.minable.result]=true
		
		data.raw.recipe[rec.name].normal.results[1].name=boiler.name.."-converter"
		data.raw.recipe[rec.name].normal.main_product=boiler.name.."-converter"
		data.raw.recipe[rec.name].expensive.results[1].name=boiler.name.."-converter"
		data.raw.recipe[rec.name].expensive.main_product=boiler.name.."-converter"
		data.raw.recipe[rec.name].main_product=boiler.name.."-converter"
		
		local water = boiler.fluid_box.filter or "water"
		local water_cap = convert_mj(data.raw.fluid[water].heat_capacity)
		local water_delta_tmp = data.raw.fluid[water].max_temperature-data.raw.fluid[water].default_temperature
		local steam = boiler.output_fluid_box.filter or "steam"
		local steam_cap = convert_mj(data.raw.fluid[steam].heat_capacity)
		local steam_delta_tmp = boiler.target_temperature-data.raw.fluid[water].max_temperature
		local prod_steam = round_fluid(omni.lib.round(convert_mj(boiler.energy_consumption)/(water_delta_tmp*water_cap+steam_delta_tmp*steam_cap)))
		local lcm = omni.lib.lcm(prod_steam,solid_contain)
		local prod = lcm/solid_contain
		local tid=lcm/prod_steam
		
		--omni.lib.replace_all_ingredient(boiler.name,boiler.name.."-converter")
		
		new_boiler[#new_boiler+1]={
		type = "recipe",
		name = boiler.name.."-boiling-steam-"..boiler.target_temperature,
		icon = "__base__/graphics/icons/fluid/steam.png",
		subgroup = "fluid-recipes",
		category = "boiler-omnifluid-"..boiler.name,
		order = "g[hydromnic-acid]",
		energy_required = tid,
		enabled = true,
		icon_size = 32,
		main_product= "steam",
		ingredients =
		{
		  {type = "item", name = "solid-water", amount = prod},
		},
		results =
		{
		  {type = "fluid", name = "steam", amount = solid_contain*prod, temperature = boiler.target_temperature},
		},
	  }
		new_boiler[#new_boiler+1]={
		type = "recipe",
		name = boiler.name.."-boiling-solid-steam-"..boiler.target_temperature,
		icon = "__base__/graphics/icons/fluid/steam.png",
		subgroup = "fluid-recipes",
		category = "boiler-omnifluid-"..boiler.name,
		order = "g[hydromnic-acid]",
		energy_required = tid,
		enabled = true,
		icon_size = 32,
		main_product= "steam",
		ingredients =
		{
		  {type = "item", name = "solid-water", amount = prod},
		},
		results =
		{
		  {type = "item", name = "solid-steam", amount = prod},
		},
	  }
		if mods["omnimatter_marathon"] then omni.marathon.exclude_recipe(boiler.name.."-boiling-solid-steam-"..boiler.target_temperature) end
		if mods["omnimatter_marathon"] then omni.marathon.exclude_recipe(boiler.name.."-boiling-steam-"..boiler.target_temperature) end
		
		local loc_key={"entity-name."..boiler.name}
		local new_item = table.deepcopy(data.raw.item[boiler.name])
		new_item.name = boiler.name.."-converter"
		new_item.place_result = boiler.name.."-converter"
		new_item.localised_name = {"item-name.boiler-converter", loc_key}
		new_boiler[#new_boiler+1]=new_item
		
		boiler.minable.result=boiler.name.."-converter"
		
		loc_key={"entity-name."..boiler.name}
		forbidden_assembler[boiler.name.."-converter"]=true
		local new = {
		type = "assembling-machine",
		name = boiler.name.."-converter",
		localised_name = {"entity-name.boiler-converter", loc_key},
		icon = boiler.icon,
		icons = boiler.icons,
		icon_size = 32,
		flags = {"placeable-neutral","placeable-player", "player-creation"},
		minable = {hardness = 0.2, mining_time = 0.5, result = boiler.name.."-converter"},
		max_health = 300,
		corpse = "big-remnants",
		dying_explosion = "medium-explosion",
		collision_box = {{-1.29, -1.29}, {1.29, 1.29}},
		selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
		
		animation = make_4way_animation_from_spritesheet({ layers =
		{
		  {
			filename = "__omnimatter_fluid__/graphics/boiler-off.png",
			width = 160,
			height = 160,
			frame_count = 1,
			shift = util.by_pixel(-5, -4.5),
		  },
		}}),
		working_visualisations =
		{
		  {
			north_position = util.by_pixel(30, -24),
			west_position = util.by_pixel(1, -49.5),
			south_position = util.by_pixel(-30, -48),
			east_position = util.by_pixel(-11, -1),
			apply_recipe_tint = "primary",
		  {
			apply_recipe_tint = "tertiary",
			north_position = {0, 0},
			west_position = {0, 0},
			south_position = {0, 0},
			east_position = {0, 0},
			north_animation =
			{
			  filename = "__omnimatter_fluid__/graphics/boiler-north-off.png",
			  frame_count = 1,
			  width = 160,
			  height = 160,
			},
			east_animation =
			{
			  filename = "__omnimatter_fluid__/graphics/boiler-east-off.png",
			  frame_count = 1,
			  width = 160,
			  height = 160,
			},
			west_animation =
			{
			  filename = "__omnimatter_fluid__/graphics/boiler-west-off.png",
			  frame_count = 1,
			  width = 160,
			  height = 160,
			},
			south_animation =
			{
			  filename = "__omnimatter_fluid__/graphics/boiler-south-off.png",
			  frame_count = 1,
			  width = 160,
			  height = 160,
			}
			}
		  }
		},
		vehicle_impact_sound =  { filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65 },
		working_sound =
		{
		  sound =
		  {
			{
			  filename = "__base__/sound/chemical-plant.ogg",
			  volume = 0.8
			}
		  },
		  idle_sound = { filename = "__base__/sound/idle1.ogg", volume = 0.6 },
		  apparent_volume = 1.5,
		},
		crafting_speed = 1,
		energy_source = boiler.energy_source,
		energy_usage = boiler.energy_consumption,
		ingredient_count = 4,
		crafting_categories = {"boiler-omnifluid-"..boiler.name,"general-omni-boiler"},
		fluid_boxes =
		{
		  {
			production_type = "output",
			pipe_covers = pipecoverspictures(),
			base_level = 1,
			pipe_connections = {{type = "output", position = {0, -2}}}
		  }
		}
	  }
	  
		
		new_boiler[#new_boiler+1]=new
	end
end



local get_icons = function(item)
    --Build the icons table
    local icons = {}
    if item.icons then
        for _ , icon in pairs(item.icons) do
            local shrink = icon
			--local scale = icon.scale or 1
            --shrink.scale = scale*0.65
            icons[#icons+1] = shrink
        end
    else
        icons[#icons+1] = {icon = item.icon}
    end
    return icons
end

	new_boiler[#new_boiler+1]={
		type = "recipe-category",
		name = "general-omni-boiler",
	}
if #new_boiler > 0 then
	data:extend(new_boiler)
end

local generator_recipe={}
local generator_cat={}

local cat_add = {}

local fuel_fluid = {}

for _,fluid in pairs(data.raw.fluid) do
	local loc_key={}
	if type(fluid.localised_name)=="string" then
		loc_key={"fluid-name."..fluid.name}
	elseif type(fluid.localised_name)=="table" then
		loc_key=fluid.localised_name
	else
		loc_key={"fluid-name."..fluid.name}
	end
	if fluid.fuel_value then
		fuel_fluid[fluid.name]=true
	end
	fluid_solid[#fluid_solid+1] = {
		type = "item",
		name = "solid-"..fluid.name,
		localised_name = {"item-name.solid-fluid", loc_key},
		localised_description = {"item-description.solid-fluid", loc_key},
		icons = get_icons(fluid),
		icon_size = 32,
		subgroup = "omni-solid-fluids",
		order = "a",
		stack_size = 360,
		flags={}
		--inter_item_count = item_count,
    }
end

fluid_solid[#fluid_solid+1]={
    type = "item-subgroup",
    name = "omni-solid-fluids",
	group = "intermediate-products",
	order = "aa",
}
data:extend(fluid_solid)

for _,rec in pairs(data.raw.recipe) do
	omni.marathon.standardise(rec)
	if rec.category then
		cat_add[rec.category] = {ingredients = 0,results=0}
		for _, dif in pairs({"normal","expensive"}) do
			for _, ingres in pairs({"ingredients","results"}) do
				local count = 0
				for _, ing in pairs(rec[dif][ingres]) do
					count=count+1
					if ingres=="results" and ing.type=="fluid" and (generator_fluid[ing.name]~= nil or fuel_fluid[ing.name] ~= nil) then
						generator_recipe[rec.name] = {}
						if not generator_cat[rec.category] then
							generator_cat[rec.category] = {fluid={}}
						end
						generator_cat[rec.category].fluid[ing.name] = true
					end
				end
				if count > cat_add[rec.category][ingres] then cat_add[rec.category][ingres] = count end
			end
		end
	end
end

for _,build in pairs(data.raw["furnace"]) do
	if not string.find(build.name,"creative") and not forbidden_assembler[build.name] then
		build.fluid_boxes=nil
		if not build.source_inventory_size then build.source_inventory_size = 0 end
		if not build.result_inventory_size then build.result_inventory_size = 0 end
		for _, c in pairs(build.crafting_categories) do
			if cat_add[c] then 
				if cat_add[c].ingredients and cat_add[c].ingredients > build.source_inventory_size then
					build.source_inventory_size = cat_add[c].ingredients
				end
				if cat_add[c].ingredients and cat_add[c].ingredients > build.source_inventory_size then
					build.result_inventory_size = cat_add[c].results
				end
				if cat_add[c] and (build.ingredient_count and cat_add[c].ingredients > build.ingredient_count) then 
					build.ingredient_count = cat_add[c].ingredients
				end
			end
		end
	end
end


local dont_remove = {}


for _,pump in pairs(data.raw["offshore-pump"]) do	
	if not (mods["omnimatter_water"] and mods["aai-industry"]) then
		if data.raw.item[pump.name] then
			local new={}
			
			new[#new+1]={
					type = "recipe-category",
					name = "pump-fluid-source-"..pump.name,
				}
			
			new[#new+1]={
				type = "recipe",
				name = pump.name.."-fluid-production",
				icon = data.raw.fluid[pump.fluid].icon,
				icons = data.raw.fluid[pump.fluid].icons,
				subgroup = "fluid-recipes",
				category = "pump-fluid-source-"..pump.name,
				order = "g[hydromnic-acid]",
				energy_required = 0.5,
				icon_size = 32,
				enabled = true,
				main_product= pump.fluid,
				ingredients =
				{
				},
				results =
				{
				  {type = "item", name = "solid-"..pump.fluid, amount = 20},
				},
			  }
			local loc_key={"entity-name."..pump.name}
			
			local new_item = table.deepcopy(data.raw.item[pump.name])
				new_item.name = pump.name.."-source"
				new_item.place_result = pump.name.."-source"
				new_item.localised_name = {"item-name.fluid-source", loc_key}
			new[#new+1] = new_item
			
			if standardized_recipes[pump.name] == nil then
				omni.marathon.standardise(data.raw.recipe[pump.name])
			end
			dont_remove[pump.fluid]={true}
			data.raw.recipe[pump.name].normal.results[1].name=pump.name.."-source"
			data.raw.recipe[pump.name].normal.main_product=pump.name.."-source"
			data.raw.recipe[pump.name].expensive.results[1].name=pump.name.."-source"
			data.raw.recipe[pump.name].expensive.main_product=pump.name.."-source"
			data.raw.recipe[pump.name].main_product=pump.name.."-source"
			
			pump.minable.result=pump.name.."-source"
			new[#new+1] = {
				type = "assembling-machine",
				name = pump.name.."-source",
				icon_size = 32,
				localised_name = {"entity-name.fluid-source", loc_key},
				icon = pump.icon,
				icons = pump.icons,
				flags = {"placeable-neutral","placeable-player", "player-creation"},
				minable = {hardness = 0.2, mining_time = 0.5, result = pump.name.."-source"},
				max_health = 300,
				corpse = "big-remnants",
				dying_explosion = "medium-explosion",
				collision_box = {{-0.9, -0.9}, {0.9, 0.9}},
				selection_box = {{-1, -1}, {1, 1}},
				
				animation = make_4way_animation_from_spritesheet({ layers =
				{
				  {
					filename = "__base__/graphics/entity/offshore-pump/offshore-pump.png",
					width = 160,
					height = 102,
					frame_count = 1,
					--shift = util.by_pixel(-5, -4.5),
				  },
				}}),
					
				vehicle_impact_sound =  { filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65 },
				working_sound =
				{
				  sound =
				  {
					{
					  filename = "__base__/sound/chemical-plant.ogg",
					  volume = 0.8
					}
				  },
				  idle_sound = { filename = "__base__/sound/idle1.ogg", volume = 0.6 },
				  apparent_volume = 1.5,
				},
				crafting_speed = 1,
				energy_source =     {
			  type = "burner",
			  fuel_category = "chemical",
				  effectivity = 1,
			  fuel_inventory_size = 7,
			  emissions = 0.00,
			  smoke = nil
			  
			},
				energy_usage = "1W",
				ingredient_count = 4,
				crafting_categories = {"pump-fluid-source-"..pump.name},
				fluid_boxes =
				{
				  {
					production_type = "output",
					pipe_covers = pipecoverspictures(),
					base_level = 1,
					pipe_connections = {{type = "output", position = {0, 1}}}
				  }
				}
			  }
			data:extend(new)
		end
	else
		data.raw.recipe[pump.name] = nil
		omni.lib.remove_recipe_all_techs(pump.name)
	end
end



local make_tmp_sluid = function(name,tmp)
	local loc_key={"item-name.solid-fluid-tmp"}
	local fluid = data.raw.fluid[name]
	if type(fluid.localised_name)=="string" then
		loc_key[#loc_key+1]={"fluid-name."..fluid.name}
	elseif type(fluid.localised_name)=="table" then
		loc_key[#loc_key+1]=fluid.localised_name
	else
		loc_key[#loc_key+1]={"fluid-name."..fluid.name}
	end
	loc_key[#loc_key+1]=tostring(tmp)
	data:extend({{
		type = "item",
		name = "solid-"..name.."-"..tmp,
		localised_name = loc_key,
		--localised_description = {"item-description.solid-fluid", loc_key},
		icons = data.raw.fluid[name].icons,
		icon = data.raw.fluid[name].icon,
		icon_size = 32,
		subgroup = "omni-solid-fluids",
		order = "a",
		stack_size = 200,
		flags={}
		--inter_item_count = item_count,
    }})
end


local resource_fluid = {}

for _,resource in pairs(data.raw.resource) do
	local auto = resource.minable.result
	if resource.minable and resource.minable.required_fluid and data.raw["autoplace-control"][auto] then
		resource_fluid[#resource_fluid+1]={
		type = "recipe",
		name = resource.minable.required_fluid.."-solid-fluid-conversion",
		icon = data.raw.fluid[resource.minable.required_fluid].icon,
		icons = data.raw.fluid[resource.minable.required_fluid].icons,
		subgroup = "fluid-recipes",
		category = "general-omni-boiler",
		order = "g[hydromnic-acid]",
		energy_required = tid,
		enabled = true,
		icon_size = 32,
		main_product= resource.minable.required_fluid,
		ingredients =
		{
		  {type = "item", name = "solid-"..resource.minable.required_fluid, amount = 12},
		},
		results =
		{
		  {type = "fluid", name = resource.minable.required_fluid, amount = solid_contain*12},
		},
	  }
	  dont_remove[resource.minable.required_fluid]={true}
	  if mods["omnimatter_marathon"] then omni.marathon.exclude_recipe(resource.minable.required_fluid.."-solid-fluid-conversion") end
	elseif resource.minable and resource.minable.results and resource.minable.results[1] and resource.minable.results[1].type == "fluid" then
		resource.minable.results[1].type = "item"
		resource.minable.results[1].name="solid-"..resource.minable.results[1].name
		resource.minable.mining_time=resource.minable.mining_time*60
	end
end
if #resource_fluid > 0 then
	data:extend(resource_fluid)
end

for _, jack in pairs(data.raw["mining-drill"]) do
	if string.find(jack.name, "jack") then
		if jack.output_fluid_box then jack.output_fluid_box=nil end
		jack.vector_to_place_result = {0, -1.85}
	end
end



--"autoplace-control"
--name,ore in pairs(data.raw.resource) 


for _,build in pairs(data.raw["assembling-machine"]) do
	if not string.find(build.name,"creative") and not forbidden_assembler[build.name] then
		local found_generator = false
		if not build.ingredient_count then build.ingredient_count = 0 end
		for _, c in pairs(build.crafting_categories) do
			if cat_add[c] and cat_add[c].ingredients > build.ingredient_count then 
				build.ingredient_count = cat_add[c].ingredients
			end
			if generator_cat[c] then found_generator = true end
		end
		if found_generator then
			local found_out = false
			for i,box in pairs(build.fluid_boxes) do
				if type(box)=="table"  and box.production_type == "output" and not found_out then
					found_out = true
				else
					data.raw["assembling-machine"][build.name].fluid_boxes[i]=nil
				end
			end
		else
			build.fluid_boxes=nil		
		end
	end
end
local has_fluid = function(recipe)
	for _,ingres in pairs({"ingredients","results"}) do
		for _,component in pairs(recipe.normal[ingres]) do
			if component.type == "fluid" then return true end
		end
	end
	return false
end

local excluded_subgroups = {"empty-barrel","fill-barrel","barreling-pump"}
local excluded_names = {"creative",{"boiling","steam"},{"solid","fluid","conversion"},{"fluid","production"}}
local temperature_fluids = {}

local extra_fluid_rec = {}

local energy_fluid = {}
--log("zombie damn it!")
for _,recipe in pairs(data.raw.recipe) do
	omni.marathon.standardise(recipe)
	if generator_recipe[recipe.name] then extra_fluid_rec[#extra_fluid_rec+1]=table.deepcopy(recipe) end
	if not forbidden_recipe[recipe.name] and has_fluid(recipe) and not omni.lib.is_in_table(recipe.subgroup,excluded_subgroups) and not omni.lib.is_in_table(recipe.name,excluded_names) and recipe.category ~= "creative-mode_free-fluids" and recipe.category ~= "general-omni-boiler" and ((recipe.category and not omni.lib.start_with(recipe.category,"boiler-omnifluid-")) or recipe.category==nil) then
		local fluids = {normal={ingredients={},results={}},expensive={ingredients={},results={}}}
		local lcm = 1
		local mult={normal=1,expensive=1}
		--log(recipe.name)
		for _,dif in pairs({"normal","expensive"}) do
			for _,ingres in pairs({"ingredients","results"}) do
				for j,component in pairs(recipe[dif][ingres]) do
					if component.type == "fluid" then 
						if fuel_fluid[component.name] then energy_fluid[#energy_fluid+1]=table.deepcopy(recipe) end
						if component.amount then
							fluids[dif][ingres][j] = {name=component.name,amount=round_fluid(component.amount)}
							--log(serpent.block(fluids[dif][ingres][j]))
							mult[dif]=omni.lib.lcm(omni.lib.lcm(solid_contain,fluids[dif][ingres][j].amount)/fluids[dif][ingres][j].amount,mult[dif])
						else
							--Temporary, need improvement
							local avg = (component.amount_max+component.amount_min)/2
							fluids[dif][ingres][j] = {name=component.name,amount=round_fluid(avg)}
							mult[dif]=omni.lib.lcm(omni.lib.lcm(solid_contain,fluids[dif][ingres][j].amount)/fluids[dif][ingres][j].amount,mult[dif])
						end
					end
				end
			end
		end
		--temporary solution
		--log(serpent.block(recipe))
		for _,dif in pairs({"normal","expensive"}) do
			local div = 1
			local need_adjustment = nil
			for _,ingres in pairs({"results"}) do
				for j,component in pairs(recipe[dif][ingres]) do
					if component.type == "fluid" then 
						local c = fluids[dif][ingres][j].amount*mult[dif]/solid_contain
						if c > 500 and (not need_adjustment or c > need_adjustment) then
							need_adjustment = c
						end
					end
				end
			end
			if need_adjustment then
				local modMult = mult[dif]*500/need_adjustment
				local multPrimes = omni.lib.factorize(mult[dif])
				local addPrimes = {}
				local checkPrimes = mult[dif]
				for i = 0,multPrimes["2"] do
					for j = 0,multPrimes["3"] do
						for k = 0,multPrimes["5"] do
							local c = math.pow(2,i)*math.pow(3,j)*math.pow(5,k)
							--log(c)
							if c > modMult and c < checkPrimes then
								checkPrimes = c
								--log("Yes")
							end
						end
					end
				end
				--log("Prime-ahoy!")
				--log(checkPrimes)
				--log(modMult)
				--log(need_adjustment)
				--log(serpent.block(mult))
				local primes = {normal={ingredients={},results={}},expensive={ingredients={},results={}}}
				local prime60 = {}
				checkPrimes=omni.lib.factorize(checkPrimes)
				prime60["2"]=2
				prime60["3"]=1
				prime60["5"]=1
				local multprime = prime60
				for _,ingres in pairs({"ingredients","results"}) do
					for j,component in pairs(recipe[dif][ingres]) do
						if component.type == "fluid" then 
							primes[dif][ingres][j]=omni.lib.factorize(fluids[dif][ingres][j].amount)
							multprime=omni.lib.prime.div(omni.lib.prime.lcm(primes[dif][ingres][j],multprime),primes[dif][ingres][j])
						end
					end
				end
				--log(serpent.block(multprime))
				local primeunion = table.deepcopy(prime60)
				local primeinter = table.deepcopy(prime60)
				--log(serpent.block(primes[dif]))
				--log(serpent.block(primeunion))
				--log(serpent.block(primeinter))
			end
			mult[dif]=math.max(math.floor(mult[dif]*div),1)
			
		end
		
		--log("mult is  "..serpent.block(mult))
		for _,dif in pairs({"normal","expensive"}) do
			for _,ingres in pairs({"ingredients","results"}) do
				for j,component in pairs(recipe[dif][ingres]) do
					if component.type == "fluid" then 
						component.amount = omni.lib.round(fluids[dif][ingres][j].amount*mult[dif]/solid_contain)
						component.type="item"
						local new_name = "solid-"..component.name
						if component.temperature or component.maximum_temperature or component.minimum_temperature then
							local tp = component.temperature or component.minimum_temperature or component.maximum_temperature 
							--new_name=new_name.."-"..tp
							if not temperature_fluids[component.name] then
								temperature_fluids[component.name]={name = component.name, recipes = {},temperatures={},used={}}
							end
							if not temperature_fluids[component.name].recipes[recipe.name] then
								temperature_fluids[component.name].recipes[recipe.name] = { name=recipe.name, normal = {ingredients={},results={}}, expensive={ingredients={},results={}}}
							end
							local dat = {pos = j, tmp = {base = component.temperature, mini = component.minimum_temperature, maxi = component.maximum_temperature}}
							omni.lib.insert(temperature_fluids[component.name].recipes[recipe.name][dif][ingres],dat)
							if ingres == "results" then
								if #temperature_fluids[component.name].temperatures > 0 then
									for i = 1, #temperature_fluids[component.name].temperatures do
										if not omni.lib.is_in_table(tp,temperature_fluids[component.name].temperatures) and temperature_fluids[component.name].temperatures[i] > tp and ((temperature_fluids[component.name].temperatures[i+1] ~= nil and temperature_fluids[component.name].temperatures[i+1]<tp) or temperature_fluids[component.name][i+1]== nil) then
											table.insert(temperature_fluids[component.name].temperatures,i,tp)
											break	
										end
									end
								else
									temperature_fluids[component.name].temperatures={tp}
								end
							else
								temperature_fluids[component.name].used[tostring(tp)]=true
							end
						end
						if ingres ~= "ingredients" and recipe[dif].main_product==component.name then
							recipe[dif].main_product=new_name
						end
						component.name=new_name
						if component.maximum_temperature then component.maximum_temperature=nil end
						if component.minimum_temperature then component.minimum_temperature=nil end
						if component.temperature then component.temperature=nil end
					else
						if component.amount then
							component.amount=omni.lib.round(component.amount*mult[dif])
						else
							if component.amount_min then component.amount_min=omni.lib.round(component.amount_min*mult[dif]) end
							if component.amount_max then component.amount_max=omni.lib.round(component.amount_max*mult[dif]) end
						end
					end
				end
			end
			recipe[dif].energy_required=recipe[dif].energy_required*mult[dif]
		end
	end
end
--log("pyc is shit")


for _,f in pairs(temperature_fluids) do
	for _,r in pairs(f.recipes) do
		if #f.used > 1 and #f.temperatures > 1 then
			for _,ingres in pairs({"ingredients","results"}) do
				for _, dif in pairs({"normal","expensive"}) do
					for _,p in pairs(r[dif][ingres]) do
						if ingres=="ingredients" then
							local found_tmp = f.temperatures[1]
							for _,t in pairs(f.temperatures) do
								if p.tmp.mini and p.tmp.maxi and t>=p.tmp.mini and t<p.tmp.maxi  then
									found_tmp = t 
									break
								elseif p.tmp.mini and t>=p.tmp.mini and not p.tmp.maxi then
									found_tmp = t 
									break						
								elseif p.tmp.maxi and t<p.tmp.maxi and not p.tmp.mini then
									found_tmp = t 
									break
								elseif p.tmp.base and t>=p.tmp.base and not p.tmp.mini and not p.tmp.maxi then
									found_tmp = t 
									break
								end
							end
							data.raw.recipe[r.name][dif][ingres][p.pos].name = "solid-"..f.name.."-"..found_tmp
							if not data.raw.item["solid-"..f.name.."-"..found_tmp] then make_tmp_sluid(f.name,found_tmp) end
						else
							data.raw.recipe[r.name][dif][ingres][p.pos].name = "solid-"..f.name.."-"..p.tmp.base
							if not data.raw.item["solid-"..f.name.."-"..p.tmp.base] then make_tmp_sluid(f.name,p.tmp.base) end 
						end
					end
				end
			end
		else
			for _,ingres in pairs({"ingredients","results"}) do
				for _, dif in pairs({"normal","expensive"}) do
					for _,component in pairs(data.raw.recipe[r.name][dif][ingres]) do
						local dash_split_fluid = omni.lib.split(f.name,"-")
						local underscore_split_fluid = omni.lib.split(f.name,"_")
						local dash_split_component = omni.lib.split(component.name,"-")
						local underscore_split_component = omni.lib.split(component.name,"_")
						if omni.lib.is_number(dash_split_fluid[#dash_split_fluid]) then
							--dash_split_fluid[#dash_split_fluid]=nil
						end
						if omni.lib.is_number(underscore_split_fluid[#underscore_split_fluid]) then
							--underscore_split_fluid[#underscore_split_fluid]=nil
						end
						if string.find(component.name,"solid") and ((#dash_split_component-#dash_split_fluid) <= 2 and (omni.lib.string_contained_entire_list(component.name,dash_split_fluid)) or ((#underscore_split_component-#underscore_split_fluid) <= 2 and  omni.lib.string_contained_entire_list(component.name,underscore_split_fluid))) then
							component.name="solid-"..f.name
						end
					end
					if ingres == "results" then
						if data.raw.recipe[r.name].normal and data.raw.recipe[r.name].normal.main_product and (omni.lib.string_contained_entire_list(data.raw.recipe[r.name].normal.main_product,omni.lib.split(f.name,"-")) or omni.lib.string_contained_entire_list(data.raw.recipe[r.name].normal.main_product,omni.lib.split(f.name,"_"))) then
							data.raw.recipe[r.name].normal.main_product = "solid-"..f.name
						end
						if data.raw.recipe[r.name].main_product and (omni.lib.string_contained_entire_list(data.raw.recipe[r.name].main_product,omni.lib.split(f.name,"-")) or omni.lib.string_contained_entire_list(data.raw.recipe[r.name].main_product,omni.lib.split(f.name,"_"))) then
							data.raw.recipe[r.name].main_product = "solid-"..f.name
						end
						if data.raw.recipe[r.name].expensive and data.raw.recipe[r.name].expensive.main_product and (omni.lib.string_contained_entire_list(data.raw.recipe[r.name].expensive.main_product,omni.lib.split(f.name,"-")) or omni.lib.string_contained_entire_list(data.raw.recipe[r.name].expensive.main_product,omni.lib.split(f.name,"_"))) then
							data.raw.recipe[r.name].expensive.main_product = "solid-"..f.name
						end
					end
				end
			end
			
		end
	end
end

--Extra recipes for generators
--log("yuoki is a pain")
--log(serpent.block(extra_fluid_rec))
for _, recipe in pairs(extra_fluid_rec) do
	for _,tech in pairs(data.raw.technology) do
		if tech.effects then
			for _,eff in pairs(tech.effects) do
				if eff.type=="unlock-recipe" and eff.recipe==recipe.name then
					omni.lib.add_unlock_recipe(tech.name,recipe.name.."-generator-fluid")
					break
				end
			end
		end
	end
	recipe.name = recipe.name.."-generator-fluid"
	if mods["omnimatter_marathon"] then omni.marathon.exclude_recipe(recipe.name) end
	local fluids = {normal={ingredients={},results={}},expensive={ingredients={},results={}}}
	local lcm = 1
	local mult=1		
	for _,dif in pairs({"normal","expensive"}) do
		for _,ingres in pairs({"ingredients","results"}) do
			for j,component in pairs(recipe[dif][ingres]) do
				if component.type == "fluid" and not generator_fluid[component.name]  then 
					fluids[dif][ingres][j] = {name=component.name,amount=round_fluid(component.amount)}
					mult=omni.lib.lcm(omni.lib.lcm(solid_contain,fluids[dif][ingres][j].amount)/fluids[dif][ingres][j].amount,mult)
				end
			end
		end
	end
	for _,dif in pairs({"normal","expensive"}) do
		for _,ingres in pairs({"ingredients","results"}) do
			for j,component in pairs(recipe[dif][ingres]) do
				if component.type == "fluid" and not generator_fluid[component.name] then 
					component.amount = fluids[dif][ingres][j].amount*mult/solid_contain
					component.type="item"
					local new_name = "solid-"..component.name
					if temperature_fluids[component.name] and #temperature_fluids[component.name].used > 1 and (component.temperature or component.maximum_temperature or component.minimum_temperature) then
						local tp = component.temperature or component.minimum_temperature or component.maximum_temperature 
						
						new_name=new_name.."-"..tp
						if not temperature_fluids[component.name] then
							temperature_fluids[component.name]={name = component.name, recipes = {},temperatures={}}
						end
						if not temperature_fluids[component.name].recipes[recipe.name] then
							temperature_fluids[component.name].recipes[recipe.name] = { name=recipe.name, normal = {ingredients={},results={}}, expensive={ingredients={},results={}}}
						end
						local dat = {pos = j, tmp = {base = component.temperature, mini = component.minimum_temperature, maxi = component.maximum_temperature}}
						omni.lib.insert(temperature_fluids[component.name].recipes[recipe.name][dif][ingres],dat)
						if ingres == "results" then
							if #temperature_fluids[component.name].temperatures > 0 then
								for i = 1, #temperature_fluids[component.name].temperatures do
									if not omni.lib.is_in_table(tp,temperature_fluids[component.name].temperatures) and temperature_fluids[component.name].temperatures[i] > tp and ((temperature_fluids[component.name].temperatures[i+1] ~= nil and temperature_fluids[component.name].temperatures[i+1]<tp) or temperature_fluids[component.name][i+1]== nil) then
										table.insert(temperature_fluids[component.name].temperatures,i,tp)
										break	
									end
								end
							else
								temperature_fluids[component.name].temperatures={tp}
							end
						else
							temperature_fluids[component.name].used={}
						end
					end
					if ingres ~= "ingredients" and recipe[dif].main_product==component.name then
						recipe[dif].main_product=new_name
					end
					component.name=new_name
					if component.maximum_temperature then component.maximum_temperature=nil end
					if component.minimum_temperature then component.minimum_temperature=nil end
					if component.temperature then component.temperature=nil end
				else
					if component.amount then
						component.amount=component.amount*mult
					else
						if component.amount_min then component.amount_min=component.amount_min*mult end
						if component.amount_max then component.amount_max=component.amount_max*mult end
					end
				end
			end
		end
		recipe[dif].energy_required=recipe[dif].energy_required*mult
	end
end

--Extra recipes for fluids withfuel value
for _, recipe in pairs(energy_fluid) do
	for _,tech in pairs(data.raw.technology) do
		if tech.effects then
			for _,eff in pairs(tech.effects) do
				if eff.type=="unlock-recipe" and eff.recipe==recipe.name then
					omni.lib.add_unlock_recipe(tech.name,recipe.name.."-fueled_fluid")
					break
				end
			end
		end
	end
	recipe.name = recipe.name.."-fueled_fluid"
	if mods["omnimatter_marathon"] then omni.marathon.exclude_recipe(recipe.name) end
	local fluids = {normal={ingredients={},results={}},expensive={ingredients={},results={}}}
	local lcm = 1
	local mult=1		
	for _,dif in pairs({"normal","expensive"}) do
		for _,ingres in pairs({"ingredients","results"}) do
			for j,component in pairs(recipe[dif][ingres]) do
				if component.type == "fluid" and not fuel_fluid[component.name]  then 
					fluids[dif][ingres][j] = {name=component.name,amount=round_fluid(component.amount)}
					mult=omni.lib.lcm(omni.lib.lcm(solid_contain,fluids[dif][ingres][j].amount)/fluids[dif][ingres][j].amount,mult)
				end
			end
		end
	end
	for _,dif in pairs({"normal","expensive"}) do
		for _,ingres in pairs({"ingredients","results"}) do
			for j,component in pairs(recipe[dif][ingres]) do
				if component.type == "fluid" and not fuel_fluid[component.name] then 
					component.amount = fluids[dif][ingres][j].amount*mult/solid_contain
					component.type="item"
					local new_name = "solid-"..component.name
					if temperature_fluids[component.name] and temperature_fluids[component.name].used ~= nil and (component.temperature or component.maximum_temperature or component.minimum_temperature) then
						local tp = component.temperature or component.minimum_temperature or component.maximum_temperature 
						if omni.lib.is_in_table(tp,temperature_fluids[component.name].used) then
							new_name=new_name.."-"..tp
						end
						if not temperature_fluids[component.name] then
							temperature_fluids[component.name]={name = component.name, recipes = {},temperatures={}}
						end
						if not temperature_fluids[component.name].recipes[recipe.name] then
							temperature_fluids[component.name].recipes[recipe.name] = { name=recipe.name, normal = {ingredients={},results={}}, expensive={ingredients={},results={}}}
						end
						local dat = {pos = j, tmp = {base = component.temperature, mini = component.minimum_temperature, maxi = component.maximum_temperature}}
						omni.lib.insert(temperature_fluids[component.name].recipes[recipe.name][dif][ingres],dat)
						if ingres == "results" then
							if #temperature_fluids[component.name].temperatures > 0 then
								for i = 1, #temperature_fluids[component.name].temperatures do
									if not omni.lib.is_in_table(tp,temperature_fluids[component.name].temperatures) and temperature_fluids[component.name].temperatures[i] > tp and ((temperature_fluids[component.name].temperatures[i+1] ~= nil and temperature_fluids[component.name].temperatures[i+1]<tp) or temperature_fluids[component.name][i+1]== nil) then
										table.insert(temperature_fluids[component.name].temperatures,i,tp)
										break	
									end
								end
							else
								temperature_fluids[component.name].temperatures={tp}
							end
						else
							temperature_fluids[component.name].used={}
						end
					end
					if ingres ~= "ingredients" and recipe[dif].main_product==component.name then
						recipe[dif].main_product=new_name
					end
					component.name=new_name
					if component.maximum_temperature then component.maximum_temperature=nil end
					if component.minimum_temperature then component.minimum_temperature=nil end
					if component.temperature then component.temperature=nil end
				else
					if component.amount then
						component.amount=component.amount*mult
					else
						if component.amount_min then component.amount_min=component.amount_min*mult end
						if component.amount_max then component.amount_max=component.amount_max*mult end
					end
				end
			end
		end
		recipe[dif].energy_required=recipe[dif].energy_required*mult
	end
end
if #energy_fluid > 0 then
	data:extend(energy_fluid)
end
for _,fix in pairs(data.raw.recipe) do
	for _,dif in pairs({"normal","expensive"}) do
		for _,ing in pairs(fix[dif].ingredients) do
			if fix_boilers_item[ing.name] then
				ing.name=ing.name.."-converter"
			end
		end
	end
end


if #extra_fluid_rec > 0 then
	data:extend(extra_fluid_rec)
end

for _,fluid in pairs(data.raw.fluid) do
	if dont_remove[fluid.name]==nil then fluid=nil end
end