
if mods["aai-industry-sp0"] then
	industry.add_tech("omniwaste")
end

if mods["angelsbioprocessing"] and mods["bob-greenhouse"] then
	omni.lib.replace_all_ingredient("seedling","omniseedling")
	omni.lib.replace_recipe_result("wood-sawing-manual","wood","omniwood")

	data.raw.recipe["wood-sawing-manual"].icons[1].icon = data.raw.item["omniwood"].icons[1].icon
	data.raw.recipe["wood-sawing-manual"].icons[1].icon_size = 32
	data.raw.recipe["wood-sawing-manual"].icons[1].scale = 1
	data.raw.recipe["wood-sawing-manual"].localised_name = {"item-name.omniwood"}
end

if mods["omnimatter_marathon"] then
	omni.marathon.equalize("burner-omniphlog","omni-mutator")
end
