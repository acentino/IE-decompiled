# Inazuma Eleven 1 (FR) — Native PC Port Research Starter

**Status: phase 1 verified. NOT A PLAYABLE PORT.**

This project is the first reproducible building block for a native Windows port of the French
Nintendo DS game *Inazuma Eleven 1* (`YEEF`). Its compiled C++ code runs natively on the
host computer; **it only reads, extracts, and validates game data**. The original football
engine is not yet recompiled or running on PC. No emulator, game ROM, or copyrighted game
binary is included in this archive.

## Verified ROM

- Internal title: `INAZUMA11`, game code `YEEF`
- Size: 268,435,456 bytes (256 MiB)
- SHA-1: `7fd6dfbd3821b17e0f8dbbf0bcea151c659d2b52`
- SHA-256: `1dea99c0c5ff6546c5b79ae9b9dc26a2e22205126ceeb7cba34b36d02d0ac238`
- 1,846 FAT file IDs; 1,755 named NitroFS files; 48 directories
- 91 ARM9 overlays, all successfully BLZ-decompressed and verified against declared sizes
- 1,026 named data files begin with an LZ10-like header; an NSBMD model was successfully decompressed and identified as `BMD0`

See `docs/REVERSE_ENGINEERING.md`, `analysis/manifest.json` and `docs/ROADMAP.md`.

## Launch with update prompts (Windows)

Clone this repository via Git (or initialize/upload a fresh project ZIP using `Upload-to-GitHub.cmd`), then run **`Start-IE.cmd`**. It checks
`acentino/IE-decompiled` `main` on every launch, asks before performing an
update, and rebuilds the tool. The prompt is only active when starting through
this launcher, not by double-clicking the compiled `ie1_romtool.exe`.

See [docs/UPDATES.md](docs/UPDATES.md) for installation and safeguards.

## Windows build (Visual Studio 2022, C++ tools + CMake)

```powershell
cmake -S . -B build -A x64
cmake --build build --config Release
.\build\Release\ie1_romtool.exe "C:\Games\Inazuma Eleven (France).nds" info
.\build\Release\ie1_romtool.exe "C:\Games\Inazuma Eleven (France).nds" check-overlays
```

Extract the `.nds` file from your ZIP first; the C++ utility takes an `.nds` path, not ZIP.

## Linux build (tested)

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/ie1_romtool /path/to/your/game.nds info
```

## Native ROM library / analysis tools

```powershell
# List filenames in the game's model directory
.\build\Release\ie1_romtool.exe "C:\Games\Inazuma Eleven (France).nds" list data_iz/model/

# Unpack a compressed DS BMD0 model, not a PC-format mesh yet
.\build\Release\ie1_romtool.exe "C:\Games\Inazuma Eleven (France).nds" extract data_iz/model/obj/ball0010.nsbmd_ dumps/ball0010.nsbmd --lz10

# Prepare game code for reversing (writes ARM9, ARM7 and 91 decompressed overlays)
.\build\Release\ie1_romtool.exe "C:\Games\Inazuma Eleven (France).nds" dump-code dumps/code

# Create a full metadata manifest (also accepts the ZIP without extraction)
python tools/make_manifest.py "C:\Games\Inazuma Eleven (FR)-1734161864.zip" --output analysis/manifest.json
```

**Note:** `dump-code` creates binaries derived from the game ROM **locally**. Do not commit or
redistribute them. Most overlays share load addresses and should initially be examined in
separate Ghidra projects. See `docs/GHIDRA.md`.

The `ie1::NdsRom` native C++ library (`src/nds_rom.hpp`, `src/nds_rom.cpp`) offers:

- ROM header, ARM9/ARM7 regions, NitroFS/FAT/FNT directory parsing
- direct asset access by numeric file ID or named NitroFS path
- Nintendo LZ10 decoding and backwards-LZ (BLZ) overlay decoding
- bounds checking and game-code validation; no guest code execution

### Source tree

- `src/nds_rom.hpp`, `src/nds_rom.cpp`: cross-platform host-native ROM access library
- `src/main.cpp`: command-line verification / extraction utility
- `tools/make_manifest.py`: standalone standard-library-only metadata generator
- `analysis/manifest.json`: independently reproducible data and code-offset inventory
- `docs/`: reverse-engineering results, Ghidra addresses, and executable-port roadmap
- `.github/workflows/windows.yml`: Windows compile and artifact CI

## Static recompilation path

The most promising *candidate* for an actual native gameplay build is
[RetroPortingToolKit/ndsrecomp](https://github.com/RetroPortingToolKit/ndsrecomp), a **very early
pre-alpha** static recompiler with a two-CPU NDS runtime. It has **not been validated for this
Inazuma Eleven ROM**. It is not an emulator-free implementation of the hardware: ARM code is
lifted ahead of time, while the runtime still models the DS hardware and dual CPU scheduling.

Next technical milestone: generate verified ARM9/ARM7/overlay native banks for this exact ROM,
link those into a compatible runner and reach an interactive title screen. This requires new
work on title-specific function discovery and overlay handling; there is no turnkey support.
The more ambitious later stage is substituting PC-native graphics, sound, UI and control layers.

All supplied code in this starter is original, independent host-side parsing code. The starter
has no dependencies on `ndsrecomp`; review that project's licensing before linking it.
