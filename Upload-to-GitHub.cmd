@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title IE-decompiled - GitHub browser upload

where git >nul 2>&1
if errorlevel 1 (
  echo ERROR: Git for Windows is required: https://git-scm.com/download/win
  goto :failed
)

REM Prefer the official GitHub CLI: its device flow opens a browser, no password or PAT needed.
call :find_gh
if not defined GH_EXE (
  echo GitHub CLI ^(gh^) is not installed or was not found on PATH.
  where winget >nul 2>&1
  if errorlevel 1 (
    echo Install GitHub CLI from https://cli.github.com/ and run this file again.
    goto :failed
  )
  choice /C YN /M "Install GitHub CLI automatically with winget?"
  if errorlevel 2 (
    echo Install GitHub CLI from https://cli.github.com/ and run this file again.
    goto :failed
  )
  winget install --id GitHub.cli --exact --source winget --accept-source-agreements --accept-package-agreements
  if errorlevel 1 goto :failed
  call :find_gh
  if not defined GH_EXE (
    echo GitHub CLI was installed, but this terminal cannot locate gh.exe yet.
    echo Close this window, then double-click Upload-to-GitHub.cmd again.
    goto :failed
  )
)

"%GH_EXE%" auth status --hostname github.com >nul 2>&1
if errorlevel 1 (
  echo.
  echo GitHub browser sign-in is required. No password needs to be typed here.
  echo Sign in as acentino in the browser and authorize GitHub CLI.
  echo If shown a one-time code, it will also be copied to the clipboard.
  echo.
  "%GH_EXE%" auth login --hostname github.com --git-protocol https --web --clipboard
  if errorlevel 1 goto :failed
) else (
  echo GitHub CLI is already authenticated.
)

REM Enable GitHub CLI credentials for future normal Git operations as well.
"%GH_EXE%" auth setup-git --hostname github.com
if errorlevel 1 goto :failed

echo.
echo Connected GitHub account:
"%GH_EXE%" api user --jq .login
if errorlevel 1 goto :failed

echo.
if not exist ".git" (
  git init -b main
  if errorlevel 1 goto :failed
)
git remote get-url origin >nul 2>&1
if errorlevel 1 (
  git remote add origin https://github.com/acentino/IE-decompiled.git
  if errorlevel 1 goto :failed
)
for /f "delims=" %%R in ('git remote get-url origin') do set "current_remote=%%R"
if /I not "%current_remote%"=="https://github.com/acentino/IE-decompiled.git" if /I not "%current_remote%"=="git@github.com:acentino/IE-decompiled.git" (
  echo ERROR: origin is not acentino/IE-decompiled. Refusing to push.
  goto :failed
)

git branch -M main
if errorlevel 1 goto :failed
REM Stage only the source and analysis files; never stage the ROM, saves, dumps or builds.
git add -- .gitignore .github CMakeLists.txt README.md Start-IE.cmd Upload-to-GitHub.cmd analysis docs scripts src tools
if errorlevel 1 goto :failed
git diff --cached --quiet
if errorlevel 1 (
  git commit -m "Add browser-based GitHub login to uploader"
  if errorlevel 1 goto :failed
) else (
  echo Nothing new to commit.
)

echo.
echo Uploading to https://github.com/acentino/IE-decompiled ...
REM The first empty helper clears broken global helpers such as 'credential-manager'.
REM The second uses GitHub CLI auth for THIS push only; no credentials are stored in source.
git -c credential.helper= -c "credential.helper=!gh auth git-credential" push -u origin main
if errorlevel 1 goto :failed

echo.
echo Upload succeeded! Use Start-IE.cmd to build, launch and check for updates.
pause
exit /b 0

:find_gh
set "GH_EXE="
for /f "delims=" %%G in ('where gh 2^>nul') do if not defined GH_EXE set "GH_EXE=%%G"
if defined GH_EXE exit /b 0
if exist "%ProgramFiles%\GitHub CLI\gh.exe" (
  set "GH_EXE=%ProgramFiles%\GitHub CLI\gh.exe"
  set "PATH=%ProgramFiles%\GitHub CLI;%PATH%"
  exit /b 0
)
if exist "%LOCALAPPDATA%\Programs\GitHub CLI\gh.exe" (
  set "GH_EXE=%LOCALAPPDATA%\Programs\GitHub CLI\gh.exe"
  set "PATH=%LOCALAPPDATA%\Programs\GitHub CLI;%PATH%"
  exit /b 0
)
if exist "%LOCALAPPDATA%\Microsoft\WinGet\Links\gh.exe" (
  set "GH_EXE=%LOCALAPPDATA%\Microsoft\WinGet\Links\gh.exe"
  set "PATH=%LOCALAPPDATA%\Microsoft\WinGet\Links;%PATH%"
  exit /b 0
)
exit /b 0

:failed
echo.
echo Upload not completed. No force-push or reset was performed.
echo Your local commits are safe. After fixing the issue, rerun this file.
pause
exit /b 1
