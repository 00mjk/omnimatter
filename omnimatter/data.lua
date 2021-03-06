--INITIALIZE
if not omni then omni = {} end
if not omni.matter then omni.matter = {} end

--LOAD CONSTANT, CATEGORY AND FUNCTION PROTOTYPES
require("prototypes.constants")
require("prototypes.categories")
require("prototypes.compat.extraction-functions")

--LOAD ALL OTHER PROTOTYPES
require("prototypes.omniore")
require("prototypes.generation.omnite")
require("prototypes.generation.omnite-inf")
require("prototypes.compat.extraction-resources")

require("prototypes.buildings.omnitractor")
require("prototypes.buildings.omniphlog")
require("prototypes.buildings.omnifurnace")

require("prototypes.recipes.omnicium")
require("prototypes.recipes.omnibrick")
require("prototypes.recipes.omnic-acid")