
local compress_recipes, uncompress_recipes, compress_items = {}, {}, {}
local item_count = 0
compressed_item_names = {}
random_recipes = {}

local max_module_speed = 0
local max_module_prod = 0
for _,modul in pairs(data.raw.module) do
	if modul.effect.speed and modul.effect.speed.bonus > max_module_speed then max_module_speed=modul.effect.speed.bonus end
	if modul.effect.productivity and modul.effect.productivity.bonus > max_module_prod then max_module_prod=modul.effect.productivity.bonus end
end
local max_cat = {}

local building_list = {"assembling-machine","furnace"}

for _,cat in pairs(data.raw["recipe-category"]) do
	max_cat[cat.name] = {speed = 0,modules = 0}
	for _,bcat in pairs(building_list) do
		for _,build in pairs(data.raw[bcat]) do
			if omni.lib.is_in_table(cat.name,build.crafting_categories) then
				if build.crafting_speed and build.crafting_speed > max_cat[cat.name].speed then max_cat[cat.name].speed = build.crafting_speed end
				if build.module_specification and build.module_specification.module_slots and build.module_specification.module_slots > max_cat[cat.name].modules then max_cat[cat.name].modules=build.module_specification.module_slots end
				--new.module_specification.module_slots
			end
		end
	end
end

-------------------------------------------------------------------------------
--[[Create Dynamic Recipes from Items]]--
-------------------------------------------------------------------------------
--Config variables
local compressed_item_stack_size = 120 -- stack size for compressed items (not the items returned that is dynamic)
local max_stack_size_to_compress = 2000 -- Don't compress items over this stack size
local speed_div = 8 --Recipe speed is stack_size/speed_div

local hcn = {1, 2, 4, 6, 12, 24, 36, 48, 60, 120, 180, 240, 360, 720, 840, 1260, 1680, 2520}
function roundHcn(nr)
	if math.floor(nr)==nr then
		for i=1,#hcn-1 do
			if hcn[i+1]>nr and hcn[i]<=nr then
				if hcn[i+1]-nr<= nr-hcn[i] then
					return hcn[i+1]
				else
					return hcn[i]
				end
			end
		end
	else
		return nr
	end
end
function roundUpHcn(nr)
	if math.floor(nr)==nr then
		for i=1,#hcn-1 do
			if hcn[i+1]>=nr and hcn[i]<nr then
				return hcn[i+1]
			end
		end
	else
		return nr
	end
end

local get_icons = function(item)
    --Build the icons table
    local icons = {{icon = "__omnimatter_compression__/graphics/compress.png"}}
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

local find_icon = function(item)
	for _, p in pairs({"item","mining-tool","gun","ammo","armor","repair-tool","capsule","module","tool","rail-planner","item-with-entity-data","fluid"}) do
		if data.raw[p][item] then
			if data.raw[p][item].icons then
				return data.raw[p][item].icons
			else
				return {{icon=data.raw[p][item].icon}}
			end
		end
	end
end


local get_icons_rec = function(rec)
    --Build the icons table
    local icons = {{icon = "__omnimatter_compression__/graphics/compress.png"}}
    if rec.icons then
        for _ , icon in pairs(rec.icons) do
            local shrink = icon
			--local scale = icon.scale or 1
            --shrink.scale = 0.65*scale
            icons[#icons+1] = shrink
        end
    else
		if rec.icon then
			icons[#icons+1] = {icon=rec.icon}
		else
			local process = {}
			if rec.result or (rec.normal and rec.normal.result) then
				if rec.result then
					process = find_icon(rec.result)
				else
					process = find_icon(rec.normal.result)	
				end
			else
				if rec.results then
					process = find_icon(rec.results[1].name)
				else
					process = find_icon(rec.normal.results[1].name)
				end			
			end
			for _,p in pairs(process) do
				--local scale = p.scale or 1
				icons[#icons+1]=p
				--icons[#icons].scale=0.65*scale
			end
			--icons[#icons+1] = {icon = find_icon(rec.normal.results[1].name), scale = .65}	
		end
    end
	icons[#icons+1]={icon = "__omnimatter_compression__/graphics/compress.png"}
    return icons
end

local uncompress_icons = function(item)
    local icons = {{icon = "__omnimatter_compression__/graphics/compress-out-arrow.png"}}
	icons[#icons+1] = {icon = "__omnimatter_compression__/graphics/compress.png"}
    if item.icons then
        for _ , icon in pairs(item.icons) do
            local shrink = icon
            --shrink.scale = .65
            icons[#icons+1] = shrink
        end
    else
        icons[#icons+1] = {icon = item.icon}
    end
    return icons
end

local new_fuel_value = function(effect,stack)
	if not effect then return nil end
	local eff = string.sub(effect,1,string.len(effect)-2)
	local value = string.sub(effect,string.len(effect)-1,string.len(effect)-1)
	if string.len(effect)==2 then
		eff = string.sub(effect,1,1)
		value = ""
	end
	eff=tonumber(eff)*stack
	if eff > 1000 then
		eff=eff/1000
		if value == "k" then value = "M" elseif value == "M" then value = "G" end
	end
	return eff..value.."J"
end

local is_science = function(item)
	for _, lab in pairs(data.raw.lab) do
		for _, input in pairs(lab.inputs) do
			if item.name == input then return true end
		end
	end
	return false
end

--Loop through all of these item categories
for _, group in pairs({"item", "ammo", "module", "rail-planner", "repair-tool", "capsule", "mining-tool", "tool","gun","armor"}) do
    --Loop through all of the items in the category
    for _, item in pairs(data.raw[group]) do
        --Check for hidden flag to skip later
        local hidden = false
        for _, flag in ipairs(item.flags) do
            if flag == "hidden" then hidden = true end
        end
		--log("compressing item: "..item.name..":"..item.stack_size)
        --Don't compress items that only stack to 1
        --Skip items with a super high stack size, Why compress something already this compressed!!!! (also avoids errors)
        --Skip hidden items and creative mode mod items
        if item.stack_size > 1 and item.stack_size <= max_stack_size_to_compress and not (hidden or item.name:find("creative-mode")) then
            --Not really needed but we will save into the item in case we want to use it before we extend the items/recipes
            item_count = item_count + 1

			item.stack_size=omni.lib.round_up(item.stack_size/60)*60
			
            --Variables to use on each iteration
            local sub_group = "items"
            local order = "compressed-"..item.name
            local icons = get_icons(item)

            --Try the best option to get a valid localised name
            local loc_key = {"item-name."..item.name}
            if item.localised_name then
                loc_key = item.localised_name
            elseif item.place_result then
                loc_key = {"entity-name."..item.place_result}
            elseif item.placed_as_equipment_result then
                loc_key = {"equipment-name."..item.placed_as_equipment_result}
            end
            --Get the techname to assign this too
			local it_type = "item"
			if is_science(item) then it_type = "tool" end
            local new_item = {
                type = it_type,
                name = "compressed-"..item.name,
                localised_name = {"item-name.compressed-item", loc_key},
                localised_description = {"item-description.compressed-item", loc_key},
                flags = item.flags,
                icons = icons,
				icon_size = 32,
                subgroup = item.subgroup,
                order = order,
                stack_size = compressed_item_stack_size,
                inter_item_count = item_count,
				fuel_value = new_fuel_value(item.fuel_value,item.stack_size),
				fuel_category = item.fuel_category,
				fuel_acceleration_multiplier = item.fuel_acceleration_multiplier,
				fuel_top_speed_multiplier = item.fuel_top_speed_multiplier,
				durability=item.durability
            }

            --The compress recipe
            local compress = {
                type = "recipe",
                name = "compress-"..item.name,
                localised_name = {"recipe-name.compress-item", loc_key},
                localised_description = {"recipe-description.compress-item", loc_key},
                category = "compression",
                enabled = true,
				hidden=true,
                ingredients = {
                    {item.name, item.stack_size}
                },
                subgroup = "compressor-"..sub_group,
				icons=icons,
				icon_size = 32,
                order = order,
                inter_item_count = item_count,
                result = "compressed-"..item.name,
                energy_required = item.stack_size / speed_div,
            }
			
			icons = uncompress_icons(item)
            --The uncompress recipe
            local uncompress = {
                type = "recipe",
                name = "uncompress-"..item.name,
                localised_name = {"recipe-name.uncompress-item", loc_key},
                localised_description = {"recipe-description.uncompress-item", loc_key},
                icons = icons,
				icon_size = 32,
                category = "compression",
                enabled = true,
				hidden = true,
                ingredients = {
                    {"compressed-"..item.name, 1}
                },
                subgroup = "compressor-out-"..sub_group,
                order = order,
                result = item.name,
                result_count = item.stack_size,
                inter_item_count = item_count,
                energy_required = item.stack_size / speed_div,
            }
			omni.marathon.standardise(compress)
			omni.marathon.standardise(uncompress)
            --The compressed item
			
            --Insert the recipes and item into tables that we will extend into the game later.
			compressed_item_names[#compressed_item_names+1]="compressed-"..item.name
            compress_recipes[#compress_recipes+1] = compress
            uncompress_recipes[#uncompress_recipes+1] = uncompress
            compress_items[#compress_items+1] = new_item
			--add_compression_tech(item.name)
            --Get the technology we want to use and add our recipes as unlocks
        end
    end
end
data:extend(compress_items)

local compressed_recipes = {}

local not_only_fluids = function(recipe)
	local all_ing = {}
	local all_res = {}
	if recipe.normal and recipe.normal.ingredients then
		all_ing=recipe.normal.ingredients
	else
		all_ing=recipe.ingredients
	end
	if recipe.normal and recipe.normal.results then
		all_res=recipe.normal.results
	elseif recipe.results then
		all_res=recipe.results
	elseif recipe.normal and recipe.normal.result then
		all_res=recipe.normal.result
	elseif recipe.result then
		all_res=recipe.result
	end
	if type(all_ing)=="table" then
		for _,ing in pairs(all_ing) do
			if ing[1] or (ing.type ~= "fluid") then return true end
		end
	elseif type(all_ing)=="string" then
		return true
	end
	if type(all_res)=="table" then
		for _,ing in pairs(all_res) do
			if ing[1] or (ing.type ~= "fluid") then return true end
		end
	else
		if type(all_res) == "string" or all_res[1] or all_res.type~="fluid" then
			return true
		end
	end
	return false
end

local compress_based_recipe = {}

local not_random = function(recipe)
	local results = {}
	if recipe.normal and recipe.normal.results then
		results = recipe.normal.results
	elseif recipe.results then
		results = recipe.results
	elseif recipe.result then
		return true
	end
	for _,r in pairs(results) do
		if r.amount_min or (r.probability and r.probability > 0)then
			return false
		end
	end
	return true
end

local seperate_fluid_solid = function(collection)
	local fluid = {}
	local solid = {}
	if type(collection) == "table" then
		for _,thing in pairs(collection) do
			if thing.type and thing.type == "fluid" then
				fluid[#fluid+1]=thing
			else
				if type(thing)=="table" then
					if thing.type then
						solid[#solid+1] = thing
					elseif thing[1] then
						solid[#solid+1] = {type="item",name=thing[1],amount=thing[2]}
					elseif thing.name then
						solid[#solid+1] = {type="item",name=thing.name,amount=thing.amount}
					end
				else
					solid[#solid+1] = {type="item",name=thing[1],amount=1}
				end
			end
		end
	else
		solid[#solid+1] = {type="item",name=collection,amount=1}
	end
	return {fluid = fluid,solid = solid}
end


function get_recipe_values(ingredients,results)
	local parts={}
	local lng = {0,0}
	
	local all_ing = seperate_fluid_solid(ingredients)
	local all_res = seperate_fluid_solid(results)
	
	
	for _,comp in pairs({all_ing.solid,all_res.solid}) do
		for _,  resing in pairs(comp) do
			parts[#parts+1]={name=resing.name,amount=resing.amount}
		end
	end
	
	local lcm_rec = 1
	local gcd_rec = 0
	local mult_rec = 1
	local lcm_stack = 1
	local gcd_stack = 0
	local mult_stack = 1
	--calculate lcm of the parts and stacks
	for _, p in pairs(parts) do
		if gcd_rec==0 then
			gcd_rec=p.amount
		else
			gcd_rec = omni.lib.gcd(gcd_rec,p.amount)
		end
		lcm_rec=omni.lib.lcm(lcm_rec,p.amount)
		mult_rec = mult_rec*p.amount
		local stacksize = omni.lib.find_stacksize(p.name)
		if gcd_stack == 0 then
			gcd_stack=stacksize
		else
			gcd_stack = omni.lib.gcd(gcd_stack,stacksize)		
		end
		lcm_stack=omni.lib.lcm(lcm_stack,stacksize)
		mult_stack = mult_stack*stacksize
	end
	--lcm_rec = mult_rec/gcd_rec
	--lcm_stack = mult_stack/gcd_stack
	local new_parts = {}
	local new_stacks = {}
	for i, p in pairs(parts) do
		new_parts[i]={name = p.name, amount = lcm_rec/p.amount}
		local stacksize = omni.lib.find_stacksize(p.name)
		new_stacks[i]={name = p.name, amount = lcm_stack/stacksize}
	end
	local new = {}
	local new_gcd = 0
	local new_lcm = lcm_rec*lcm_stack--rec_max*stack_max/omni.lib.gcd(rec_max,stack_max)
	for i,p in pairs(new_parts) do
		new[i]=new_lcm*new_stacks[i].amount/new_parts[i].amount
		if new_gcd == 0 then
			new_gcd = new[i]
		else
			new_gcd=omni.lib.gcd(new_gcd,new[i])
		end
	end
	for i,p in pairs(new_parts) do
		new[i]=new[i]/new_gcd
	end
	
	local total_mult = new[1]*omni.lib.find_stacksize(parts[1].name)/parts[1].amount
	local newing = {}
	for i=1,#all_ing.solid do
		newing[#newing+1]={type="item",name="compressed-"..parts[i].name,amount=new[i]}
	end
	for _,f in pairs(all_ing.fluid) do
		newing[#newing+1]={type="fluid",name=f.name,amount=f.amount*total_mult, minimum_temperature = f.minimum_temperature, maximum_temperature = f.maximum_temperature}
	end
	local newres = {}
	for i=1,#all_res.solid do
		newres[#newres+1]={type="item",name="compressed-"..parts[#all_ing.solid+i].name,amount=new[#all_ing.solid+i]}
	end
	for _,f in pairs(all_res.fluid) do
		newres[#newres+1]={type="fluid",name=f.name,amount=f.amount*total_mult, temperature = f.temperature}
	end
	return {ingredients = newing , results = newres}
end

local more_than_one = function(recipe)
	if recipe.result or (recipe.normal and recipe.normal.result) then
		if recipe.result then
			if type(recipe.result)=="table" then
				if recipe.result[1] then
					return omni.lib.find_stacksize(recipe.result[1]) > 1
				else
					return omni.lib.find_stacksize(recipe.result.name) > 1
				end
			else
				return omni.lib.find_stacksize(recipe.result) > 1
			end
		else
			if type(recipe.normal.result)=="table" then
				if recipe.normal.result[1] then
					return omni.lib.find_stacksize(recipe.normal.result[1]) > 1
				else
					return omni.lib.find_stacksize(recipe.normal.result.name) > 1
				end
			else
				return omni.lib.find_stacksize(recipe.normal.result) > 1
			end
		end
	else
		if (recipe.results and #recipe.results > 1) or (recipe.normal and recipe.normal.results and #recipe.normal.results>1) then
			return true
		else
			if recipe.results then
				if type(recipe.results[1])=="table" then
					if recipe.results[1][1] then
						return omni.lib.find_stacksize(recipe.results[1][1]) > 1
					else
						return omni.lib.find_stacksize(recipe.results[1].name) > 1
					end
				else
					return omni.lib.find_stacksize(recipe.results[1]) > 1
				end
			else
				if type(recipe.normal.results[1])=="table" then
					if recipe.normal.results[1][1] then
						return omni.lib.find_stacksize(recipe.normal.results[1][1]) > 1
					elseif omni.lib.find_stacksize(recipe.normal.results[1].name) then
						return omni.lib.find_stacksize(recipe.normal.results[1].name) > 1
					else
						return false
					end
				else
					if omni.lib.find_stacksize(recipe.normal.results[1].name) then
						return omni.lib.find_stacksize(recipe.normal.results[1].name) > 1
					else
						--log("Something is not right, item  "..recipe.normal.results[1].name.." has no stacksize.")
						return false
					end
				end
			end
		end
	end
end

local compressed_ingredients_exist = function(ingredients,results)
	if #ingredients > 0 then
		for _, ing in pairs(ingredients) do
			if not omni.lib.is_in_table("compressed-"..ing.name,compressed_item_names) then return false end
		end
	end
	if type(results)=="table" then
		if #results > 0 then
			for _, res in pairs(results) do
				if not omni.lib.is_in_table("compressed-"..res.name,compressed_item_names) then return false end
			end
		end
	else
		if not omni.lib.is_in_table("compressed-"..results,compressed_item_names) then return false end
	end
	return true
end

local check_output_size = function(recipe)
	local rec = table.deepcopy(recipe)
	for _, state in pairs({"normal","expensive"}) do
		local split = false
		local it = ""
		if #rec[state].results == 1 then
			it = rec[state].results[1].name
		end
		for _,res in pairs(rec[state].results) do
			if res.type ~= "fluid" then
				if res.amount_min or res.probability then
					if res.amount and res.amount > compressed_item_stack_size then
						split = true
						local amount = res.amount
						res.amount=compressed_item_stack_size
						while amount > compressed_item_stack_size do
							local extra = table.deepcopy(res)
							amount=amount-compressed_item_stack_size
							if amount > compressed_item_stack_size then
								extra.amount = compressed_item_stack_size
							else
								extra.amount = amount
							end
							table.insert(rec[state].results,extra)
						end				
					else
						local amount = res.amount_min+res.amount_max
						res.amount_max=compressed_item_stack_size
						res.amount_min=compressed_item_stack_size/2+amount%2
						amount=amount-compressed_item_stack_size-res.amount_min
						while amount>compressed_item_stack_size*1.5 do
							local extra = table.deepcopy(res)
							extra.amount_max=compressed_item_stack_size
							extra.amount_min=compressed_item_stack_size/2+amount%2
							amount=amount-compressed_item_stack_size-extra.amount_min
							table.insert(rec[state].results,extra)
							split = true
						end
						local extra = table.deepcopy(res)
						extra.amount_max=math.random(math.floor(amount/2),amount)
						extra.amount_min=amount-extra.amount_max
						table.insert(rec[state].results,extra)
					end
				else
					if res.amount > compressed_item_stack_size then
						split = true
						local extra = table.deepcopy(res)
						extra.amount=res.amount-compressed_item_stack_size
						res.amount = compressed_item_stack_size
						table.insert(rec[state].results,extra)
					end
				end
			end
		end
	end
	return rec
end

function create_compression_recipe(recipe)
if recipe.normal.ingredients and #recipe.normal.ingredients > 0 and recipe.normal.results and #recipe.normal.results > 0 and not_only_fluids(recipe) and not_random(recipe) and not omni.lib.is_in_table(recipe.name,excluded_recipes) and (more_than_one(recipe) or omni.lib.is_in_table(recipe.name,include_recipes)) and not string.find(recipe.name,"creative_mode") then
		local parts = {}
		--get list of ingredients and results
				
		local res = {}
		local ing = {}
		
		local subgr = {regular = {}}
		ing={normal=table.deepcopy(recipe.normal.ingredients),expensive=table.deepcopy(recipe.expensive.ingredients)}
		
		res={normal=table.deepcopy(recipe.normal.results),expensive=table.deepcopy(recipe.expensive.results)}
		local gcd = {normal = 0, expensive = 0}
		for _,dif in pairs({"normal","expensive"}) do
			for _,ingres in pairs({"ingredients","results"}) do
				for _,component in pairs(recipe[dif][ingres]) do
					if component.type ~= "fluid" then
						if gcd[dif]==0 then
							gcd[dif]=component.amount
						else
							gcd[dif]=omni.lib.gcd(gcd[dif],component.amount)
						end
					end
				end
			end
		end
		for _,dif in pairs({"normal","expensive"}) do
			for _,ingres in pairs({ing,res}) do
				for _,component in pairs(ingres[dif]) do
					component.amount=component.amount/gcd[dif]
				end
			end
		end
		if recipe.subgroup or recipe.normal.subgroup then
			if recipe.subgroup then
				recipe.normal.subgroup =recipe.subgroup
				recipe.expensive.subgroup =recipe.subgroup
			else
				subgr.normal = recipe.normal.subgroup
				subgr.expensive = recipe.expensive.subgroup
			end
		else
			subgr.normal = subgr.regular
			subgr.expensive = subgr.regular		
		end
		
		local check = {{seperate_fluid_solid(ing.normal),seperate_fluid_solid(res.normal)},{seperate_fluid_solid(ing.expensive),seperate_fluid_solid(res.expensive)}}
		if compressed_ingredients_exist(check[1][1].solid,check[1][2].solid) and compressed_ingredients_exist(check[2][1].solid,check[2][2].solid) then
			----log(serpent.block(recipe))
			local new_val_norm = get_recipe_values(ing.normal,res.normal)
			local new_val_exp = get_recipe_values(ing.expensive,res.expensive)
			local mult = {}
			if check[1][1].solid[1] then
				mult = {normal=new_val_norm.ingredients[1].amount/check[1][1].solid[1].amount*omni.lib.find_stacksize(check[1][1].solid[1].name),
						expensive=new_val_exp.ingredients[1].amount/check[2][1].solid[1].amount*omni.lib.find_stacksize(check[2][1].solid[1].name)}
			else
				mult = {normal=new_val_norm.results[1].amount/check[1][2].solid[1].amount*omni.lib.find_stacksize(check[1][2].solid[1].name),
						expensive = new_val_exp.results[1].amount/check[2][2].solid[1].amount*omni.lib.find_stacksize(check[2][2].solid[1].name)}
			end
			local tid = {}
			if recipe.normal and recipe.normal.energy_required then
				tid = {normal = recipe.normal.energy_required*mult.normal,expensive = recipe.expensive.energy_required*mult.expensive}
			else
				tid = {normal = mult.normal,expensive = mult.expensive}
			end
			tid.normal = tid.normal/gcd.normal
			tid.expensive = tid.expensive/gcd.expensive
			local icons = get_icons_rec(recipe)
			
			if recipe.normal.category and not data.raw["recipe-category"][recipe.normal.category.."-compressed"] then
				data:extend({{type = "recipe-category",name = recipe.normal.category.."-compressed"}})
			elseif not data.raw["recipe-category"]["general-compressed"] then
				data:extend({{type = "recipe-category",name = "general-compressed"}})
			end
			
			local new_cat = "crafting-compressed"
			if recipe.normal.category then new_cat = recipe.normal.category.."-compressed" end
			
			local loc = {"recipe-name."..recipe.name}
			local r = {
			type = "recipe",
			icons = icons,
			icon_size = 32,
			name = recipe.name.."-compression",
			enabled = false,
			hidden = recipe.hidden,
			normal = {
				ingredients = new_val_norm.ingredients,
				results = new_val_norm.results,	
				energy_required = tid.normal,
				subgroup = subgr.normal				
			},
			expensive = {
				ingredients = new_val_exp.ingredients,
				results = new_val_exp.results,	
				energy_required = tid.expensive,
				subgroup = subgr.expensive
			},
			category = new_cat,
			subgroup = subgr.regular,
			order = recipe.order,
			}
			
			--if not r.subgroup then 
			if recipe.localised_name then
				local loc = recipe.localised_name
				r.localised_name = {"recipe-name.compressed-recipe",loc}
			end
			if true or settings.startup["omnicompression_one_list"].value then
				r.subgroup = "compressor-".."items"
				r.normal.subgroup = "compressor-".."items"
				r.expensive.subgroup = "compressor-".."items"
			end
			
			r.normal.hidden = recipe.normal.hidden
			r.normal.enabled = false
			r.normal.category= new_cat
			if r.main_product and r.main_product ~= "" then
				r.main_product = recipe.main_product
				if not data.raw.fluid[r.main_product] then r.main_product="compressed-"..r.main_product end
			end
			if #r.normal.results==1 then r.normal.main_product = r.normal.results[1].name end
			if #r.expensive.results==1 then r.expensive.main_product = r.expensive.results[1].name end
			r.expensive.enabled = false
			r.expensive.hidden = recipe.expensive.hidden
			r.expensive.category = new_cat
			if r.main_product == "compressed-" or (r.normal and r.normal.main_product == "compressed-") or (r.expensive and r.expensive.main_product == "compressed-") then
				if r.normal then r.normal.main_product = nil end
				if r.expensive then r.expensive.main_product = nil end
				r.main_product = nil
			end
			for _, module in pairs(data.raw.module) do
				if module.limitation then
					for _,lim in pairs(module.limitation) do
						if lim==recipe.name then
							table.insert(module.limitation, r.name)
							break
						end
					end
				end
			end
			r.main_product = nil
			r.normal.main_product = nil
			r.expensive.main_product = nil
			omni.marathon.standardise(r)
			return check_output_size(r)
		end
	end
	return nil
end

local create_void = function(recipe)
	local continue = false
	for _, dif in pairs({"normal","expensive"}) do
		if #recipe[dif].results == 1 and recipe[dif].results[1].type=="item" and #recipe[dif].ingredients == 1 and recipe[dif].ingredients[1].type=="item" and recipe[dif].results[1].probability and recipe[dif].results[1].probability == 0 then continue = true end
	end
	if continue==true then
		local icons = get_icons_rec(recipe)
		local new_cat = "crafting-compressed"
		if recipe.normal.category then new_cat = recipe.normal.category.."-compressed" end
		if recipe.normal.category and not data.raw["recipe-category"][recipe.normal.category.."-compressed"] then
			data:extend({{type = "recipe-category",name = recipe.normal.category.."-compressed"}})
		elseif not data.raw["recipe-category"]["general-compressed"] then
			data:extend({{type = "recipe-category",name = "general-compressed"}})
		end
		local new_rc = table.deepcopy(recipe)
		new_rc.name = recipe.name.."-compression"
		new_rc.category = new_cat
		new_rc.normal.ingredients[1].name="compressed-"..new_rc.normal.ingredients[1].name
		new_rc.expensive.ingredients[1].name="compressed-"..new_rc.expensive.ingredients[1].name
		
		return table.deepcopy(new_rc)
	end
	return nil
end
local adjust_time = function(rec)
	local mcat = max_cat[string.sub(rec.category,1,1+string.len(rec.category)-string.len("-compression"))]
	--log("fixing compressed ratios: "..rec.name)
	for _,dif in pairs({"normal","expensive"}) do
		if rec[dif].energy_required > 15000 then
			local gcd_ing = 0
			for _,ing in pairs(rec[dif].ingredients) do
				if gcd_ing==0 then
					gcd_ing=ing.amount
				else
					gcd_ing=omni.lib.gcd(gcd_ing,ing.amount)
				end
			end
			if gcd_ing > 1 then
				local n_speed = omni.lib.round((max_module_speed-max_module_prod+max_module_prod*max_module_speed*mcat.modules)/(2*max_module_prod*max_module_speed))
				local craft_time = rec[dif].energy_required/(mcat.speed*(1+max_module_speed*n_speed))
				--local div = omni.lib.divisors(gcd)
				local f = {1,gcd_ing}
				local possible = false
				for i=1,gcd_ing do
					if craft_time*60*i/f[2] > 1 then
						f[1]=i
						possible = true
						break
					end
				end
				if possible then
					rec[dif].energy_required=rec[dif].energy_required*f[1]/f[2]
					for i,ing in pairs(rec[dif].ingredients) do
						rec[dif].ingredients[i].amount = ing.amount*f[1]/f[2]
					end
					for i,res in pairs(rec[dif].results) do
						local divisors = omni.lib.divisors(rec[dif].results[i].amount)
						local m = 1
						for _,d in pairs(divisors) do
							if f[1]/f[2]*d<1 then
								if d>m then m=d end
							else
								--break
							end
						end
						rec[dif].results[i].probability = f[1]/f[2]*m
						rec[dif].results[i].amount=rec[dif].results[i].amount/m
					end
				end
			end
		end
	end
	return rec
end

for _,recipe in pairs(data.raw.recipe) do
	--omni.lib.gcd(m,n)
	--Start with the ingredients
	--log("calc compressed recipe of "..recipe.name)
	if not mods["omnimatter_marathon"] then omni.marathon.standardise(recipe) end
	if recipe.subgroup ~= "y_personal_equip" then
		local rc = create_compression_recipe(recipe)
		if not rc and string.find(recipe.name,"void") then rc=create_void(recipe) end
		if rc then
			compress_based_recipe[#compress_based_recipe+1] = table.deepcopy(adjust_time(rc))
		else
			if not not_random(recipe) then random_recipes[#random_recipes+1]=recipe.name end
		end
	end
end


data:extend(compress_recipes)
data:extend(uncompress_recipes)
data:extend(compress_based_recipe)
