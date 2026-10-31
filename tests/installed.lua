package.path = "./?.lua;./?/init.lua;" .. package.path
love = {
  data = {
    compress = function(_, _, bytes, level) return deflate(bytes, level) end,
    decompress = function(_, _, bytes) return inflate(bytes) end,
  },
  graphics = {
    newQuad = function() return {} end,
    newImage = function() return { getDimensions = function() return 256, 256 end } end,
  },
}
local GameVersion = require("src.core.GameVersion")
GameVersion.set(TEST_VERSION)
assert(require("src.core.Version").engine == INSTALLED_ENGINE, "staged engine is not the installed one")

local fs, overlay = {}, {}
function fs.read(p) return overlay[p] or fs_read(p) end
function fs.getInfo(p) return overlay[p] and { type = "file" } or fs_info(p) end
function fs.getDirectoryItems(p) return fs_list(p) end
function fs.load(p)
  local bytes = fs.read(p)
  return bytes and loadstring(bytes, "@" .. p)
end
function fs.write(p, bytes) overlay[p] = bytes return true end
function fs.createDirectory() return true end
fs.root = "."

local generation = GameVersion.generation()
local Loader = require("src.mods.Loader")
local game = { data = {} }

if generation == 3 then
  local Dataset = require("src.core.game3.dataset")
  Dataset.cacheRootOverride = CACHE_ROOT
  assert(Dataset.hydrate(game), "installed dataset did not hydrate")
else
  local dir = TEST_VERSION .. "/data/generated/"
  for _, name in ipairs({ "constants", "moves", "items", "pokemon", "type_chart" }) do
    local chunk = fs.load(dir .. name .. ".lua")
    if chunk then game.data[name] = chunk() end
  end
end

local loader = Loader.new({ fs = fs, generation = generation })
loader:load(game.data)
assert(#loader.errors == 0, table.concat(loader.errors, "\n"))
local mod = loader.mods.counterpart_exclusives
assert(mod and mod.state == "loaded", "installed mod did not load for " .. TEST_VERSION)

if generation == 3 then
  -- 1) Growlithe -> Vulpix
  local enc1 = { species = 58, level = 18 }
  local res1 = loader.hooks:call("encounter.species", function(e) return e end, enc1, { forceSwap = true })
  assert(res1.species == 37, "Growlithe not swapped to Vulpix")

  -- 2) Reverse Vulpix -> Growlithe
  local enc2 = { species = 37, level = 18 }
  local res2 = loader.hooks:call("encounter.species", function(e) return e end, enc2, { forceSwap = true })
  assert(res2.species == 58, "Vulpix not swapped to Growlithe")

  -- 3) Hoenn pair: Seedot (273) -> Lotad (270)
  local enc3 = { species = 273, level = 5 }
  local res3 = loader.hooks:call("encounter.species", function(e) return e end, enc3, { forceSwap = true })
  assert(res3.species == 270, "Seedot not swapped to Lotad")

  -- 4) Non-exclusive: Pidgey (16) unchanged
  local enc4 = { species = 16, level = 3 }
  local res4 = loader.hooks:call("encounter.species", function(e) return e end, enc4, { forceSwap = true })
  assert(res4.species == 16, "Pidgey swapped")

  -- 5) encounter.table split
  local distIn = { [58] = 20, [16] = 80 }
  local distOut = loader.hooks:call("encounter.table", function(d) return d end, distIn, {})
  assert(distOut[58] == 10 and distOut[37] == 10 and distOut[16] == 80, "distribution not split 50/50")

  -- 5b) Real Super Rod rolls (FireRed): Vermilion City's pool holds Shellder and Psyduck.
  if TEST_VERSION == "firered" then
    local Encounters = require("src.core.game3.encounters")
    Encounters.ensureLoaded()
    local PAIRS = { SHELLDER = "STARYU", PSYDUCK = "SLOWPOKE", QWILFISH = "REMORAID" }
    local rolled, final
    local removeInner = loader.hooks:wrap("encounter.fishing", function(next)
      local enc = next(); rolled = enc and enc.species; return enc
    end, -100000, "installed_test")
    local removeOuter = loader.hooks:wrap("encounter.fishing", function(next)
      local enc = next(); final = enc and enc.species; return enc
    end, 100000, "installed_test")
    local function fish(forced)
      love.math = { random = function() return forced end }
      local swaps, bites = 0, 0
      for _ = 1, 400 do
        rolled, final = nil, nil
        local enc = Encounters.rollFishing("FR_VERMILION_CITY", 2, {})
        if enc then
          bites = bites + 1
          local want = (forced == 1 and PAIRS[rolled]) or rolled
          assert(final == want, string.format("fishing: rolled %s, mods returned %s, want %s", tostring(rolled), tostring(final), tostring(want)))
          local Pokemon = require("src.core.game3.pokemon")
          assert(enc.species == Pokemon.speciesFromName(want), "engine encounter species differs from the swapped name")
          if want ~= rolled then swaps = swaps + 1 end
        end
      end
      love.math = nil
      return swaps, bites
    end
    local swaps, bites = fish(1)
    assert(bites > 0 and swaps > 0, string.format("no fishing swap in %d bites", bites))
    local kept = fish(0)
    assert(kept == 0, "fishing swapped although the roll said no")
    removeInner(); removeOuter()
  end

  -- 5c) Sweet Scent and Rock Smash: the engine's own rolls go through the mod (bridged hooks)
  local Encounters = require("src.core.game3.encounters")
  local Pokemon = require("src.core.game3.pokemon")
  Encounters.ensureLoaded()
  local Runtime = require("src.mods.Runtime")
  assert(Runtime.wantsHook("wild_tables.sweet_scent") and Runtime.wantsHook("wild_tables.rock_smash"), "Gen 3 rolls bridged")
  local growlithe, vulpix = Pokemon.speciesFromName("GROWLITHE"), Pokemon.speciesFromName("VULPIX")
  local forcedRemove = {}
  for _, hook in ipairs({ "wild_tables.sweet_scent", "wild_tables.rock_smash" }) do
    forcedRemove[#forcedRemove + 1] = loader.hooks:wrap(hook, function() return { species = growlithe, level = 12 } end,
      -100000, "installed_test")
  end
  love.math = { random = function() return 1 end }
  local ss = Encounters.rollSweetScent("any", "land")
  local rs = Encounters.rollRocks("any")
  assert(ss and ss.species == vulpix and ss.level == 12, "Sweet Scent roll not swapped: " .. tostring(ss and ss.species))
  assert(rs and rs.species == vulpix, "Rock Smash roll not swapped: " .. tostring(rs and rs.species))
  love.math = { random = function() return 0 end }
  assert(Encounters.rollSweetScent("any", "land").species == growlithe, "Sweet Scent swapped although the roll said no")
  love.math = nil
  for _, remove in ipairs(forcedRemove) do remove() end

  -- 5d) A real Sweet Scent roll on a map whose land table holds an exclusive
  local mapId, rolledSs, finalSs
  for id, t in pairs(Encounters._tables) do
    local land = type(t) == "table" and (t.land or t.grass)
    for _, slot in ipairs(type(land) == "table" and (land.slots or land) or {}) do
      local sp = type(slot) == "table" and (slot.species or slot[1])
      local name = sp and (type(sp) == "string" and sp or Pokemon.keyName(sp))
      if name and ({ GROWLITHE = 1, VULPIX = 1, EKANS = 1, SANDSHREW = 1, ODDISH = 1, BELLSPROUT = 1, MEOWTH = 1,
        MANKEY = 1, SEEDOT = 1, LOTAD = 1, ZANGOOSE = 1, SEVIPER = 1 })[name] then mapId = id break end
    end
    if mapId then break end
  end
  if mapId then
    local removeIn = loader.hooks:wrap("wild_tables.sweet_scent", function(next, ...)
      local e = next(...); rolledSs = e and e.species; return e
    end, -100000, "installed_test")
    love.math = { random = function() return 1 end }
    local swaps, rolls = 0, 0
    for _ = 1, 200 do
      rolledSs = nil
      local e = Encounters.rollSweetScent(mapId, "land")
      if e and rolledSs then
        rolls = rolls + 1
        if e.species ~= rolledSs then swaps = swaps + 1 end
      end
    end
    love.math = nil
    removeIn()
    assert(rolls > 0 and swaps > 0, string.format("%s: no Sweet Scent swap in %d rolls", tostring(mapId), rolls))
    print(string.format("  %s: real Sweet Scent on %s, %d of %d rolls swapped", TEST_VERSION, tostring(mapId), swaps, rolls))
  else
    error("no map with an exclusive in its land table")
  end

  -- 6) Rollback
  loader:_rollback("counterpart_exclusives")
  local resRollback = loader.hooks:call("encounter.species", function(e) return e end, enc1, { forceSwap = true })
  assert(resRollback.species == 58, "Rollback did not restore vanilla species")
  local removeFixed = loader.hooks:wrap("wild_tables.sweet_scent", function() return { species = growlithe, level = 12 } end,
    -100000, "installed_test")
  love.math = { random = function() return 1 end }
  assert(Encounters.rollSweetScent("any", "land").species == growlithe, "Rollback did not restore the vanilla Sweet Scent roll")
  love.math = nil
  removeFixed()

  print("PASS installed " .. TEST_VERSION .. ": Counterpart wild encounters and rollback")
  return
end

if generation == 1 then
  local enc1 = { species = "GROWLITHE", level = 18 }
  local res1 = loader.hooks:call("encounter.species", function(e) return e end, enc1, { forceSwap = true })
  assert(res1.species == "VULPIX", "Gen 1 GROWLITHE not swapped to VULPIX")

  local distIn = { GROWLITHE = 20, PIDGEY = 80 }
  local distOut = loader.hooks:call("encounter.table", function(d) return d end, distIn, {})
  assert(distOut.GROWLITHE == 10 and distOut.VULPIX == 10 and distOut.PIDGEY == 80, "distribution not split")

  loader:_rollback("counterpart_exclusives")
  local resRollback = loader.hooks:call("encounter.species", function(e) return e end, enc1, { forceSwap = true })
  assert(resRollback.species == "GROWLITHE", "Rollback did not restore GROWLITHE")

  print("PASS installed " .. TEST_VERSION .. ": Gen 1 counterpart wild encounters and rollback")
  return
end

if generation == 2 then
  local enc1 = { species = "SPINARAK", level = 3 }
  local res1 = loader.hooks:call("encounter.species", function(e) return e end, enc1, { forceSwap = true })
  assert(res1.species == "LEDYBA", "Gen 2 SPINARAK not swapped to LEDYBA")

  local enc2 = { species = "TEDDIURSA", level = 10 }
  local res2 = loader.hooks:call("encounter.species", function(e) return e end, enc2, { forceSwap = true })
  assert(res2.species == "PHANPY", "Gen 2 TEDDIURSA not swapped to PHANPY")

  local distIn = { SPINARAK = 20, PIDGEY = 80 }
  local distOut = loader.hooks:call("encounter.table", function(d) return d end, distIn, {})
  assert(distOut.SPINARAK == 10 and distOut.LEDYBA == 10 and distOut.PIDGEY == 80, "distribution not split")

  loader:_rollback("counterpart_exclusives")
  local resRollback = loader.hooks:call("encounter.species", function(e) return e end, enc1, { forceSwap = true })
  assert(resRollback.species == "SPINARAK", "Rollback did not restore SPINARAK")

  print("PASS installed " .. TEST_VERSION .. ": Gen 2 counterpart wild encounters and rollback")
  return
end
