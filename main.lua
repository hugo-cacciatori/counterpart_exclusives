-- Counterpart Exclusives Mod
-- Makes counterpart version-exclusive wild Pokémon available in all games of
-- each generation family (FRLG, RSE, Red/Blue, Gold/Silver) by sharing encounter
-- probability on the exact routes and biomes where they naturally occur.

local PAIRS_NUMERIC = {
  -- Gen 1 / 3 Kanto pairs
  [23] = 27,   -- Ekans <-> Sandshrew
  [27] = 23,
  [24] = 28,   -- Arbok <-> Sandslash
  [28] = 24,
  [43] = 69,   -- Oddish <-> Bellsprout
  [69] = 43,
  [44] = 70,   -- Gloom <-> Weepinbell
  [70] = 44,
  [45] = 71,   -- Vileplume <-> Victreebel
  [71] = 45,
  [54] = 79,   -- Psyduck <-> Slowpoke
  [79] = 54,
  [55] = 80,   -- Golduck <-> Slowbro
  [80] = 55,
  [58] = 37,   -- Growlithe <-> Vulpix
  [37] = 58,
  [59] = 38,   -- Arcanine <-> Ninetales
  [38] = 59,
  [90] = 120,  -- Shellder <-> Staryu
  [120] = 90,
  [91] = 121,  -- Cloyster <-> Starmie
  [121] = 91,
  [123] = 127, -- Scyther <-> Pinsir
  [127] = 123,
  [125] = 126, -- Electabuzz <-> Magmar
  [126] = 125,
  [56] = 52,   -- Mankey <-> Meowth (Gen 1 Red/Blue)
  [52] = 56,
  [57] = 53,   -- Primeape <-> Persian
  [53] = 57,

  -- Gen 2 pairs (and FRLG Sevii post-game)
  [167] = 165, -- Spinarak <-> Ledyba
  [165] = 167,
  [168] = 166, -- Ariados <-> Ledian
  [166] = 168,
  [194] = 183, -- Wooper <-> Marill
  [183] = 194,
  [195] = 184, -- Quagsire <-> Azumarill
  [184] = 195,
  [198] = 200, -- Murkrow <-> Misdreavus
  [200] = 198,
  [211] = 223, -- Qwilfish <-> Remoraid
  [223] = 211,
  [225] = 226, -- Delibird <-> Mantine (FRLG)
  [226] = 225,
  [207] = 225, -- Gligar <-> Delibird
  [216] = 231, -- Teddiursa <-> Phanpy
  [231] = 216,
  [217] = 232, -- Ursaring <-> Donphan
  [232] = 217,

  -- Gen 3 Hoenn pairs (RSE)
  [270] = 273, -- Lotad <-> Seedot
  [273] = 270,
  [271] = 274, -- Lombre <-> Nuzleaf
  [274] = 271,
  [272] = 275, -- Ludicolo <-> Shiftry
  [275] = 272,
  [302] = 303, -- Sableye <-> Mawile
  [303] = 302,
  [335] = 336, -- Zangoose <-> Seviper
  [336] = 335,
  [337] = 338, -- Lunatone <-> Solrock
  [338] = 337,
}

local PAIRS_STRING = {
  EKANS = "SANDSHREW", SANDSHREW = "EKANS",
  ARBOK = "SANDSLASH", SANDSLASH = "ARBOK",
  ODDISH = "BELLSPROUT", BELLSPROUT = "ODDISH",
  GLOOM = "WEEPINBELL", WEEPINBELL = "GLOOM",
  VILEPLUME = "VICTREEBEL", VICTREEBEL = "VILEPLUME",
  PSYDUCK = "SLOWPOKE", SLOWPOKE = "PSYDUCK",
  GOLDUCK = "SLOWBRO", SLOWBRO = "GOLDUCK",
  GROWLITHE = "VULPIX", VULPIX = "GROWLITHE",
  ARCANINE = "NINETALES", NINETALES = "ARCANINE",
  SHELLDER = "STARYU", STARYU = "SHELLDER",
  CLOYSTER = "STARMIE", STARMIE = "CLOYSTER",
  SCYTHER = "PINSIR", PINSIR = "SCYTHER",
  ELECTABUZZ = "MAGMAR", MAGMAR = "ELECTABUZZ",
  MANKEY = "MEOWTH", MEOWTH = "MANKEY",
  PRIMEAPE = "PERSIAN", PERSIAN = "PRIMEAPE",

  SPINARAK = "LEDYBA", LEDYBA = "SPINARAK",
  ARIADOS = "LEDIAN", LEDIAN = "ARIADOS",
  WOOPER = "MARILL", MARILL = "WOOPER",
  QUAGSIRE = "AZUMARILL", AZUMARILL = "QUAGSIRE",
  MURKROW = "MISDREAVUS", MISDREAVUS = "MURKROW",
  QWILFISH = "REMORAID", REMORAID = "QWILFISH",
  DELIBIRD = "MANTINE", MANTINE = "DELIBIRD",
  GLIGAR = "DELIBIRD",
  TEDDIURSA = "PHANPY", PHANPY = "TEDDIURSA",
  URSARING = "DONPHAN", DONPHAN = "URSARING",

  LOTAD = "SEEDOT", SEEDOT = "LOTAD",
  LOMBRE = "NUZLEAF", NUZLEAF = "LOMBRE",
  LUDICOLO = "SHIFTRY", SHIFTRY = "LUDICOLO",
  SABLEYE = "MAWILE", MAWILE = "SABLEYE",
  ZANGOOSE = "SEVIPER", SEVIPER = "ZANGOOSE",
  LUNATONE = "SOLROCK", SOLROCK = "LUNATONE",
}

local function getCounterpart(species)
  if type(species) == "number" then
    return PAIRS_NUMERIC[species]
  end
  if type(species) == "string" then
    local upper = species:upper():gsub("%s+", "_"):gsub("%-", "_")
    return PAIRS_STRING[upper]
  end
  return nil
end

local function shouldSwap(ctx)
  if ctx and ctx.forceSwap ~= nil then
    return ctx.forceSwap == true
  end
  local rng = ctx and ctx.rng
  if type(rng) == "function" then
    local ok, r = pcall(rng, 0, 1)
    if ok and r ~= nil then return (r % 2) == 1 end
    local ok2, r2 = pcall(rng)
    if ok2 and r2 ~= nil then return (math.floor(tonumber(r2) or 0) % 2) == 1 end
  end
  if love and love.math and love.math.random then
    return love.math.random(0, 1) == 1
  end
  return math.random(0, 1) == 1
end

return function(mod)
  if not (mod and mod.hooks and mod.hooks.wrap) then return end

  -- 1) Hook live wild encounter species roll: `encounter.species`
  mod.hooks:wrap("encounter.species", function(nextFn, enc, ctx)
    local result = nextFn(enc, ctx)
    if not result or not result.species then return result end

    local cp = getCounterpart(result.species)
    if cp and shouldSwap(ctx) then
      local copy = {}
      for k, v in pairs(result) do copy[k] = v end
      copy.species = cp
      return copy
    end

    return result
  end)

  -- 2) Hook static area distribution preview: `encounter.table`
  mod.hooks:wrap("encounter.table", function(nextFn, dist, ctx)
    local d = nextFn(dist, ctx)
    if type(d) ~= "table" then return d end

    local out = {}
    for species, weight in pairs(d) do
      local cp = getCounterpart(species)
      if cp and not d[cp] then
        local half = (tonumber(weight) or 0) / 2
        out[species] = (out[species] or 0) + half
        out[cp] = (out[cp] or 0) + half
      else
        out[species] = (out[species] or 0) + weight
      end
    end

    return out
  end)
end
