-- Counterpart Exclusives Mod
-- Makes counterpart version-exclusive wild Pokémon available in all games of
-- each generation family (FRLG, RSE, Red/Blue, Gold/Silver) by sharing encounter
-- probability on the exact routes and biomes where they naturally occur.
-- The logic lives in the bundled `wild_tables` lib (lib/wild_tables/); this file only wires it.
return function(mod)
  local use = assert(load(assert(mod:read("lib/init.lua"), "missing lib/init.lua"), "@lib/init.lua"))(mod)
  use("wild_tables").install(mod)
end
