package.path = "./?.lua;./?/init.lua;" .. package.path
love = love or require("tests.love_stub")
local Sdk = require("tests.modkit.sdk")
local GameVersion = require("src.core.GameVersion")
local Runtime = require("src.mods.Runtime")
local Logger = require("src.core.Logger")
if Logger.warn then Logger.warn = function() end end

local total = 0
local function check(value, message)
  total = total + 1
  assert(value, message)
end

local PROFILES = {
  { version = "firered", gen = 3 },
  { version = "leafgreen", gen = 3 },
  { version = "ruby", gen = 3 },
  { version = "sapphire", gen = 3 },
  { version = "emerald", gen = 3 },
  { version = "red", gen = 1 },
  { version = "blue", gen = 1 },
  { version = "yellow", gen = 1 },
  { version = "gold", gen = 2 },
  { version = "silver", gen = 2 },
  { version = "crystal", gen = 2 },
}

for _, p in ipairs(PROFILES) do
  GameVersion.set(p.version)
  Runtime.reset()

  local opts = {
    version = p.version,
    generation = p.gen,
    data = (p.gen == 3 and Sdk.gen3Data()) or {},
  }

  local run = Sdk.loadMod(MOD_PATH, opts)
  check(#run.errors == 0, p.version .. ": load error: " .. table.concat(run.errors, "\n"))
  check(run.mod and run.mod.state == "loaded", p.version .. ": mod loaded")

  local loader = run.loader

  if p.gen == 3 then
    -- Numeric species testing
    -- 1) Force swap: Growlithe (58) -> Vulpix (37)
    local enc1 = { species = 58, level = 18, item = 0 }
    local ctxSwap = { mapId = "FR_ROUTE_8", forceSwap = true }
    local res1 = loader.hooks:call("encounter.species", function(e) return e end, enc1, ctxSwap)
    check(res1.species == 37, p.version .. ": Growlithe swapped to Vulpix")
    check(res1.level == 18, p.version .. ": Level preserved")

    -- 2) Reverse force swap: Vulpix (37) -> Growlithe (58)
    local enc2 = { species = 37, level = 18 }
    local res2 = loader.hooks:call("encounter.species", function(e) return e end, enc2, ctxSwap)
    check(res2.species == 58, p.version .. ": Vulpix swapped to Growlithe")

    -- 3) Hoenn pairs: Seedot (273) -> Lotad (270), Zangoose (335) -> Seviper (336)
    local encSeedot = { species = 273, level = 5 }
    local resSeedot = loader.hooks:call("encounter.species", function(e) return e end, encSeedot, ctxSwap)
    check(resSeedot.species == 270, p.version .. ": Seedot swapped to Lotad")

    local encZangoose = { species = 335, level = 16 }
    local resZangoose = loader.hooks:call("encounter.species", function(e) return e end, encZangoose, ctxSwap)
    check(resZangoose.species == 336, p.version .. ": Zangoose swapped to Seviper")

    -- 4) Non-exclusive species: Pidgey (16) -> stays Pidgey (16)
    local encPidgey = { species = 16, level = 3 }
    local resPidgey = loader.hooks:call("encounter.species", function(e) return e end, encPidgey, ctxSwap)
    check(resPidgey.species == 16, p.version .. ": Non-exclusive Pidgey unchanged")

    -- 5) No swap when forceSwap is false
    local encNoSwap = { species = 58, level = 18 }
    local ctxNoSwap = { mapId = "FR_ROUTE_8", forceSwap = false }
    local resNoSwap = loader.hooks:call("encounter.species", function(e) return e end, encNoSwap, ctxNoSwap)
    check(resNoSwap.species == 58, p.version .. ": Growlithe stays Growlithe when not swapped")

    -- 6) encounter.table distribution split
    local distIn = { [58] = 20, [16] = 80 } -- 20% Growlithe, 80% Pidgey
    local distOut = loader.hooks:call("encounter.table", function(d) return d end, distIn, {})
    check(distOut[58] == 10, p.version .. ": Growlithe weight halved to 10")
    check(distOut[37] == 10, p.version .. ": Counterpart Vulpix receives 10 weight")
    check(distOut[16] == 80, p.version .. ": Pidgey weight unchanged at 80")
  else
    -- String species testing (Gen 1 & 2)
    -- 1) Force swap: GROWLITHE -> VULPIX
    local enc1 = { species = "GROWLITHE", level = 18 }
    local ctxSwap = { mapId = "ROUTE_8", forceSwap = true }
    local res1 = loader.hooks:call("encounter.species", function(e) return e end, enc1, ctxSwap)
    check(res1.species == "VULPIX", p.version .. ": GROWLITHE swapped to VULPIX")

    -- 2) Gen 2 pairs: SPINARAK -> LEDYBA, TEDDIURSA -> PHANPY
    if p.gen == 2 then
      local encSpin = { species = "SPINARAK", level = 3 }
      local resSpin = loader.hooks:call("encounter.species", function(e) return e end, encSpin, ctxSwap)
      check(resSpin.species == "LEDYBA", p.version .. ": SPINARAK swapped to LEDYBA")

      local encTed = { species = "TEDDIURSA", level = 10 }
      local resTed = loader.hooks:call("encounter.species", function(e) return e end, encTed, ctxSwap)
      check(resTed.species == "PHANPY", p.version .. ": TEDDIURSA swapped to PHANPY")
    end

    -- 3) Non-exclusive species: PIDGEY -> stays PIDGEY
    local encPidgey = { species = "PIDGEY", level = 3 }
    local resPidgey = loader.hooks:call("encounter.species", function(e) return e end, encPidgey, ctxSwap)
    check(resPidgey.species == "PIDGEY", p.version .. ": PIDGEY unchanged")

    -- 4) encounter.table distribution split
    local distIn = { GROWLITHE = 20, PIDGEY = 80 }
    local distOut = loader.hooks:call("encounter.table", function(d) return d end, distIn, {})
    check(distOut.GROWLITHE == 10, p.version .. ": GROWLITHE weight halved to 10")
    check(distOut.VULPIX == 10, p.version .. ": VULPIX receives 10 weight")
    check(distOut.PIDGEY == 80, p.version .. ": PIDGEY weight unchanged at 80")
  end

  -- Rollback restores vanilla refusal
  loader:_rollback("counterpart_exclusives")
  local encAfter = { species = (p.gen == 3 and 58) or "GROWLITHE", level = 18 }
  local resAfter = loader.hooks:call("encounter.species", function(e) return e end, encAfter, { forceSwap = true })
  check(resAfter.species == ((p.gen == 3 and 58) or "GROWLITHE"), p.version .. ": Rollback restores unswapped species")

  run.release()
  Runtime.reset()
end

print(string.format("Integration suite passed: %d assertions across %d profiles", total, #PROFILES))
