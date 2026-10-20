# Native Windows port: milestones and acceptance criteria

## Phase 1 — cartridge and executable research (current)

**Complete:** Parse `YEEF`, extract ARM9/ARM7 binaries, index 1,846 FAT IDs, decode all
91 BLZ overlays, decompress an actual NSBMD asset, generate reproducible manifests, and
compile the native host-side loader. This is not gameplay.

## Phase 2 — execute original game logic on PC

**Not started:** Prototype a title-specific static-recompiled-bank build with
[ndsrecomp](https://github.com/RetroPortingToolKit/ndsrecomp), or independently reconstruct
the game engine if the toolchain is incompatible. Required tasks:

- Map ARM9 and ARM7 function boundaries, ARM/Thumb control flow, relocations, IRQs, SWIs,
  DMA, shared memory, and input on the verified original ROM.
- Determine which executable overlays load during each mode and when banks are invalidated.
- Generate native code banks for the executable regions (including safe dispatch paths for
  dynamically loaded code) and link to dual-CPU memory/I/O scheduling.
- Establish automated differential comparisons with a faithful DS reference; use original
  ROM checksum to refuse incompatible code banks.
- Verify the first menu frame, user interaction, and progression to a save-able game state.

**Acceptance criterion:** original interactive title screen reached by a Windows executable
compiled from recompiled C/C++ game code; no generic DS interpreter as the primary CPU
execution path. Some DS hardware modeling can remain initially.

## Phase 3 — playing one complete match

- RPG traversal, dialogue and story/event scripting; match state machine and technique animation.
- Audio, save data, touchscreen actions, and DS display correctness.
- Correct physics/timing verified against the original at baseline rendering speed.

**Acceptance criterion:** player can start, finish and save a match with comparable gameplay.

## Phase 4 — PC-specific capabilities

- Keyboard/mouse and XInput-compatible controller abstraction, including stylus-to-pointer/analog input design.
- Single-screen UI redesign without removing gameplay information from the bottom display.
- Render enhancement at 1080p+ where source assets allow it; frame-rate separation to avoid speeding up gameplay.
- PC audio, save-data paths, optional mod API for new player data, teams, techniques, scenes.

**Acceptance criterion:** actual standalone user-facing port with no need to launch an emulator.

## Constraints and licensing

A `ndsrecomp` runner is a **static-recompiled game plus a hardware compatibility runtime**,
not a fully rewritten PC engine. It may be an excellent intermediate state but will not
magically replace dual screens or improve asset quality. Upstream currently warns that
commercial-game bring-up is title-specific and not turnkey. Inspect its current licenses
(GPL and PolyForm Noncommercial portions) before redistribution.

Game code/assets, BIOS, and firmware are never committed here. Each end user must supply
lawfully obtained game data; distribution of a finished executable containing Nintendo/Level-5
code and assets can raise separate rights questions.
