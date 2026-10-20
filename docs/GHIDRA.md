# Ghidra manual import recipe

1. Extract the user-owned ROM ZIP to `.nds`.
2. Build `ie1_romtool` (see README) and run:

   `ie1_romtool path/to/game.nds dump-code dumps/code`

3. In Ghidra, create an ARM9 project/program by importing `arm9.bin` as a **Raw Binary**.
   Choose **ARM:LE:32** with the correct ARM9 ARMv5TE processor variant if available.
   **Base/load address:** `0x02000000`. **Entry point:** `0x02000800`.
4. Import `arm7.bin` into **a separate program**, ARM little-endian **ARMv4T**
   family. Base/load `0x02380000`, entry `0x02380000`.
5. Decompressed overlays are in `dumps/code/overlays/overlay_N.bin`. Use
   `dumps/code/overlays.csv` or `analysis/manifest.json` for each overlay's base address,
   BSS, static-initializer range, and file ID. Initially **create a separate program
   for each overlay** because addresses overlap (overlay 0 and 1 both use `0x020FCD40`).
6. Configure disassembly ARM/Thumb mode by observed branch-exchange instructions;
   a Thumb function cannot just be disassembled as ARM. Ghidra's analysis is heuristic.
7. Record function names, call relationships, and overlay loading events in a separate
   symbol database. Keep those discoveries independent from copied Nintendo code.

All exported code binaries are derived from the uploaded ROM and **are intentionally NOT
included** in the starter archive.
