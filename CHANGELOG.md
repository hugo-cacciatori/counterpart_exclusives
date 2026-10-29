# Changelog

All notable changes to the Counterpart Exclusives mod will be documented in this file.

## [0.1.1] - 2026-10-29

### Fixed
- Fishing encounters are swapped too, on every generation (for example Psyduck, Shellder and Qwilfish from FireRed's Super Rod). On Gen 3, Sweet Scent and Rock Smash encounters still keep their original species.

### Changed
- The logic now ships as a library bundled inside the mod.

## [0.1.0] - 2026-10-25

### Added
- Native encounter interception via `encounter.species` and `encounter.table` hooks across Gen 1, Gen 2, and Gen 3.
- Counterpart species substitutions sharing 50% encounter probability for version-exclusive pairs:
  - Gen 3 FireRed & LeafGreen: Ekans/Sandshrew, Oddish/Bellsprout, Psyduck/Slowpoke, Growlithe/Vulpix, Shellder/Staryu, Scyther/Pinsir, Electabuzz/Magmar, Wooper/Marill, Murkrow/Misdreavus, Qwilfish/Remoraid, Delibird/Mantine, Skarmory.
  - Gen 3 Ruby, Sapphire & Emerald: Seedot/Lotad, Mawile/Sableye, Zangoose/Seviper, Solrock/Lunatone.
  - Gen 1 Red & Blue: Ekans/Sandshrew, Oddish/Bellsprout, Mankey/Meowth, Growlithe/Vulpix, Scyther/Pinsir, Electabuzz/Magmar.
  - Gen 2 Gold & Silver: Spinarak/Ledyba, Vulpix/Growlithe, Mankey/Meowth, Gligar/Delibird, Mantine/Skarmory, Teddiursa/Phanpy.
- Clean hook restoration and unregistering on mod disable or rollback.
