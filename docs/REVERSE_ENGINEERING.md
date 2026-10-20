# Verified YEEF ROM examination

Input: one user-supplied 256 MiB Nintendo DS cartridge image inside a ZIP.
Verification performed against the uploaded ROM in October 2026.

## Executables and code banks

| Component | File/ROM location | RAM load | Entrypoint | Packed size |
|---|---|---|---|---|
| ARM9 | ROM `0x00004000` | `0x02000000` | `0x02000800` | `499476` bytes |
| ARM7 | ROM `0x001B3C00` | `0x02380000` | `0x02380000` | `156716` bytes |
| ARM9 overlay table | ROM `0x0007E000` | varies | n/a | `2912` bytes (91 x 32) |
| ARM7 overlay table | none | n/a | n/a | zero |

There are 91 ARM9 overlays in FAT IDs 0–90. Every overlay has the code-compression flag set,
and each decodes to its declared in-memory code-section length, using Nintendo's backwards
LZ (BLZ) format. Many reuse the **same RAM addresses**, which means they're loaded at different
times. Concatenating them into one executable region or one memory map would be incorrect.

Example: overlay 0 loads to `0x020FCD40`, expands from 69,272 to 114,400 bytes, and has
576 bytes of BSS. Overlay 1 **also** loads to `0x020FCD40` but has a different size.

## Filesystem and assets

- FAT has **1,846** entries, with **1,755** normal named files and **91** unnamed overlay files.
- FNT has **48** directories.
- **1,026** named files have a leading LZ10-like `0x10` marker and size field. Not all have
  been individually checked; an actual test decompressing `data_iz/model/obj/ball0010.nsbmd_`
  produced a 1,356-byte `BMD0` Nitro 3D model container from a 696-byte compressed file.
- Distribution highlights by filename: 911 `.pac_`, 172 `.dat`, 95 `.mbld`, 95 `.mdjd`, 94
  `.bcd`, 72 `.sad`, 62 `.spf_`, 58 `.pkb`, 58 `.pkh`.
- Most game data is under `data_iz/`. It includes `logic`, `model`, `map2d`, `movie`,
  `pic2d`, `pic3d`, `script`, `sound`, `spr`, and language-specific `/fr` subdirectories.

## Developer-facing information in the ROM

- `data_iz/INAZUMA.INI`: human-readable gameplay and renderer settings such as
  `RPG_MOVESPEED=320`, `RPG_CAMERA_DISTANCE=116736`, `RPG_SCRIPT_NO=91010000` and
  `FARCLIP_LENGTH=1024`. These are extracted text values, not yet proven to be live PC engine variables.
- `data_iz/SCRIPTINFO.TXT`: filename and display-name listing for event/special-move scripts;
  e.g. `act101000.ssd` corresponds to `Clone Faker`, and `act102000.ssd` to `The Wall`.
- `data_iz/EVENTINFO.TXT`: story/chapter event index (Japanese annotations included).
- `data_iz/DEBUG_SCRIPT_LIST.txt`: chapter-indexed event IDs.
- `data_iz/ROM_TIME.TXT` contains `10/12/03 14:15` (the specific date format is not verified).

These indices make it easier to identify script-related data, but **do not** mean the
script formats (`.mbld`, `.mdjd`, etc.) have been reverse-engineered yet.

## Validated operations

1. ROM header + FNT/FAT traversal of all 1,846 file IDs.
2. Dumping ARM9 and ARM7 images.
3. All 91 compressed ARM9 overlays decoded and validated against RAM-size declarations.
4. Decompressing at least one LZ10-wrapped Nintendo Nitro model.
5. Building and executing the C++ extractor on Linux; source is portable to Windows/CMake,
   but a Windows build was **not performed** in this environment.

## Still unknown / prerequisites to gameplay

- ARM9 section tables, static constructors, exact binary relocation details, ARM-to-Thumb entry transitions.
- Overlay function dispatch and life-cycle; which overlays handle RPG, matches, menus, etc.
- Scripts/data codecs beyond LZ10 and BLZ; packed `.pac_` structures and Level-5-specific formats.
- ARM7 I/O, sound drivers, firmware and save-device parameters.
- Required compatibility fixes in `ndsrecomp` to run this precise YEEF revision.

The original 2010-era Nintendo DS logic cannot run natively simply by extracting its data.
