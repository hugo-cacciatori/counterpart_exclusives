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
assert(require("src.core.Version").engine == "0.3.96", "wrong installed engine")

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

  -- 6) Rollback
  loader:_rollback("counterpart_exclusives")
  local resRollback = loader.hooks:call("encounter.species", function(e) return e end, enc1, { forceSwap = true })
  assert(resRollback.species == 58, "Rollback did not restore vanilla species")

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
