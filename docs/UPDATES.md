# Windows launcher and update prompts

For the first upload from an extracted project ZIP, double-click **`Upload-to-GitHub.cmd`**.
It initializes Git if necessary, stages only project source/metadata (not the ROM),
and pushes `main` using GitHub CLI's **browser authentication**, not a GitHub password.

The upload script:

1. Detects `gh` and offers to install GitHub CLI through Windows `winget` if necessary.
2. If not signed in, starts `gh auth login --web --clipboard`, opening the GitHub sign-in
   page and showing/copying the one-time device code.
3. Configures `gh` as Git's credential helper and bypasses a broken global
   `credential-manager` **for the upload command only**.
4. Commits changed project files and pushes to `acentino/IE-decompiled` without
   force-pushing or resetting your repository. Existing local commits are retained.

If the login is already active, it is reused. If you have another GitHub account
active, check the username shown in the upload window and switch accounts via
`gh auth switch --hostname github.com --user acentino` before retrying.

Never place game data in the repo.

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

## Fix for CMake errors with mixed `/e/...` and `E:/...` paths

The Windows launcher now configures CMake from the repository root using
`cmake -S . -B build`, which avoids accidental MSYS/Windows absolute-path
concatenation. The launcher no longer forces `-A x64` on generators that
don't support it.

If you configured the project with the old script and receive a
`CMakeCache.txt` generator mismatch, delete **only** the local `build`
directory and launch `Start-IE.cmd` again. Never delete your source,
`.git`, or your legally obtained game files.

Note: you still need a working C++ compiler toolchain (Visual Studio C++
Build Tools or a compatible MinGW toolchain).

## PowerShell 5.1: `git.exe : From https://github.com/...` during update

Some Git for Windows versions print normal fetch information to **stderr**.
Windows PowerShell 5.1 wraps native stderr as an error record; with
`$ErrorActionPreference = 'Stop'`, the old launcher stopped immediately.
The Git invocation now scopes error handling so only Git's **actual exit code**
determines whether an operation succeeded, and fetch is run with `--quiet`.

If you have the old launcher, it cannot fetch its own fix. **Once**, open
PowerShell inside your existing Git checkout (the folder containing
`Start-IE.cmd` and `.git`) and run:

```powershell
git pull --ff-only origin main
```

Then run `Start-IE.cmd` again. If Git refuses to pull because you have
uncommitted edits or divergent history, preserve those changes rather than
resetting or force-pulling; inspect with `git status` first.

## Git fetch fails with `reference already exists` for `origin/main`

On some local Git installations, fetching can download all objects but fail
while updating `refs/remotes/origin/main`:

```
error: fetching ref refs/remotes/origin/main failed: reference already exists
```

The launcher now bypasses that remote-tracking ref with
`git fetch --quiet --no-tags --refmap= origin refs/heads/main`,
then applies a fast-forward-only merge using `FETCH_HEAD`. The `--refmap=`
option prevents configured tracking refspecs from rewriting `origin/main`.
`git ls-remote` still checks the actual remote branch before prompting.

For **one-time recovery** from an older launcher, run these in CMD from the
existing repository directory:

```bat
git fetch --no-tags --refmap= origin refs/heads/main
git merge --ff-only FETCH_HEAD
```

These commands do not reset local commits or overwrite uncommitted work. A
non-fast-forward or conflicting local modification will cause the merge to
stop; inspect `git status` instead of forcing it. The problematic tracking
ref can remain stale, but the launcher no longer needs it for update checks.
