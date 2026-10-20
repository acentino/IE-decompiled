@echo off
setlocal
cd /d "%~dp0"
where git >nul 2>&1
if errorlevel 1 (
  echo Git for Windows is required: https://git-scm.com/download/win
  pause
  exit /b 1
)
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
  pause
  exit /b 1
)
git branch -M main
if errorlevel 1 goto :failed
REM Never stage the user's game ROM, saves, compiled executables, or local build outputs.
git add -- .gitignore .github CMakeLists.txt README.md Start-IE.cmd Upload-to-GitHub.cmd analysis docs scripts src tools
if errorlevel 1 goto :failed
git diff --cached --quiet
if errorlevel 1 (
  git commit -m "Add native ROM tools and launch-time GitHub update prompts"
  if errorlevel 1 goto :failed
) else (
  echo Nothing new to commit.
)
echo Uploading to https://github.com/acentino/IE-decompiled ...
git push -u origin main
if errorlevel 1 goto :failed
echo.
echo Upload succeeded. Use Start-IE.cmd to build, launch and check for updates.
pause
exit /b 0
:failed
echo.
echo Git operation failed. Nothing was force-pushed or reset.
echo Check your GitHub sign-in, write permissions, and existing remote branch.
pause
exit /b 1
