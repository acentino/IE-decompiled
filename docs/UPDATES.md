# Windows launcher and update prompts

For the first upload from an extracted project ZIP, double-click **`Upload-to-GitHub.cmd`**.
It initializes Git if necessary, stages only project source/metadata (not the ROM),
and pushes `main` after GitHub authentication. Never place game data in the repo.

Use **`Start-IE.cmd`** as the entry point, not `build/Release/ie1_romtool.exe`.
This is a developer utility: it does **not** launch the Nintendo DS game.

## First-time installation

1. Install Git for Windows, CMake and Visual Studio 2022 with Desktop development with C++.
2. Clone the project (required for detecting and applying future source updates):

   ```powershell
   git clone https://github.com/acentino/IE-decompiled.git
   cd IE-decompiled
   ```

3. Run `Start-IE.cmd`. It builds the native ROM tool and checks the GitHub `main` branch **every time it starts**.
4. Place your own legally obtained `*.nds` ROM under `input/` (ignored by Git) or pass a ROM path:

   ```powershell
   .\Start-IE.cmd "C:\ROMs\Inazuma Eleven.nds" info
   .\Start-IE.cmd "C:\ROMs\Inazuma Eleven.nds" check-overlays
   ```

## How updates work

- A Git checkout with Git for Windows is required. Downloaded GitHub *ZIP* files have no `.git` history; use `Upload-to-GitHub.cmd` first to initialize it or clone the repository instead.
- Each launch checks `origin/main` with `git ls-remote` (network access required).
- When the remote tip differs, a **Yes/No prompt** asks whether to update.
- **No** skips the update and continues using the local code.
- **Yes** fetches and applies a **fast-forward-only** update, then recompiles the utility.
- If the working tree has local changes, `main` is not checked out, GitHub is offline or history diverges, the launcher does **not** overwrite user work.
- Updates only happen from the pinned GitHub repository `acentino/IE-decompiled`. Changes on other branches or open PRs are not considered released updates.
- There are no silent binary downloads, automatic elevation, or automatic destructive resets.

The launcher uses PowerShell 5.1 available on Windows. The GitHub update check and Windows message-box behavior still need to be exercised on a real Windows installation.

To run the tool with no update check, launch `build/Release/ie1_romtool.exe` directly.
