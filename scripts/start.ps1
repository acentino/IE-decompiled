#Requires -Version 5.1
<#
  Windows development launcher for IE-decompiled.
  Checks the configured, pinned GitHub repository for updates when launched
  from a clone; only updates after affirmative user consent and only fast-forwards.
  Rebuilds the host-native ROM inspection tool, then runs it.
  It does NOT run the Nintendo DS game yet.
#>
param([Parameter(ValueFromRemainingArguments = $true)][string[]] $ToolArgs)
$ErrorActionPreference = 'Stop'
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Set-Location -LiteralPath $repoRoot
$expectedRemote = 'acentino/IE-decompiled'

function Has-Command([string]$name) {
    return $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
}
function Invoke-Git([string[]]$gitArgs) {
    # Windows PowerShell 5.1 turns Git's ordinary stderr progress output (e.g.
    # "From https://github.com/...") into non-terminating PowerShell errors.
    # With script-wide ErrorActionPreference='Stop', that aborts an otherwise
    # successful fetch before we can check Git's actual exit status.
    # Keep the override scoped to this function and always check LASTEXITCODE.
    $ErrorActionPreference = 'Continue'
    $out = & git -C $repoRoot @gitArgs 2>$null
    $gitExitCode = $LASTEXITCODE
    return @{ Output = @($out | Where-Object { $null -ne $_ -and [string]$_ -ne '' }); ExitCode = $gitExitCode }
}
function Ask-To-Update([string]$sha) {
    $message = "An update to IE-decompiled is available on GitHub (main: $($sha.Substring(0, 8))).`n`nUpdate your local source and rebuild before launching?"
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $answer = [System.Windows.Forms.MessageBox]::Show(
            $message, 'Inazuma Eleven - Update available',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question)
        return $answer -eq [System.Windows.Forms.DialogResult]::Yes
    } catch {
        Write-Host $message
        return ((Read-Host 'Update now? [y/N]') -match '^(?i:y|yes)$')
    }
}

Write-Host 'IE-decompiled - native ROM tool development launcher'
if ((Test-Path -LiteralPath (Join-Path $repoRoot '.git')) -and (Has-Command git)) {
    $remoteResult = Invoke-Git -gitArgs @('remote', 'get-url', 'origin')
    $remote = if ($remoteResult.ExitCode -eq 0) { [string]($remoteResult.Output | Select-Object -First 1) } else { '' }
    # Accept HTTPS or SSH references to the designated repository, not an arbitrary remote.
    if ($remote -match '^(?:https://github\.com/|git@github\.com:|ssh://git@github\.com/)(?<repo>[^\s]+?)(?:\.git)?/?$' -and
        $Matches.repo -eq $expectedRemote) {
        $currentResult = Invoke-Git -gitArgs @('rev-parse', 'HEAD')
        $remoteHead = Invoke-Git -gitArgs @('ls-remote', '--exit-code', 'origin', 'refs/heads/main')
        if ($currentResult.ExitCode -eq 0 -and $remoteHead.ExitCode -eq 0 -and
            $remoteHead.Output.Count -gt 0 -and
            ([string]$remoteHead.Output[0]) -match '^([a-fA-F0-9]{40})\s') {
            $latestSha = $Matches[1]
            $localSha = ([string]$currentResult.Output[0]).Trim()
            if ($localSha -ne $latestSha) {
                if (Ask-To-Update $latestSha) {
                    $branch = Invoke-Git -gitArgs @('branch', '--show-current')
                    $changes = Invoke-Git -gitArgs @('status', '--porcelain', '--untracked-files=no')
                    if ($branch.ExitCode -ne 0 -or @($branch.Output | Select-Object -First 1)[0] -ne 'main') {
                        Write-Warning 'Only main can be updated automatically. Switch to main to enable updates.'
                    } elseif ($changes.ExitCode -ne 0 -or @($changes.Output).Count -gt 0) {
                        Write-Warning 'Uncommitted changes detected. Stopping the update to protect your work.'
                    } else {
                        Write-Host 'Fetching GitHub main without modifying origin/main...'
                        # A stale/colliding refs/remotes/origin/main can make an otherwise
                        # successful Git fetch fail with "reference already exists".
                        # --refmap= overrides the configured remote-tracking mapping.
                        # The explicit source-only refspec writes FETCH_HEAD, not
                        # refs/remotes/origin/main; a later ff-only merge uses FETCH_HEAD.
                        $fetch = Invoke-Git -gitArgs @('fetch', '--quiet', '--no-tags', '--refmap=', 'origin', 'refs/heads/main')
                        if ($fetch.ExitCode -ne 0) {
                            Write-Warning 'Fetch failed. Continuing with local source.'
                        } else {
                            $ancestry = Invoke-Git -gitArgs @('merge-base', '--is-ancestor', 'HEAD', 'FETCH_HEAD')
                            if ($ancestry.ExitCode -ne 0) {
                                Write-Warning 'Branches have diverged; automatic update refused (fast-forward only).'
                            } else {
                                $merge = Invoke-Git -gitArgs @('merge', '--ff-only', 'FETCH_HEAD')
                                if ($merge.ExitCode -eq 0) {
                                    Write-Host 'Source updated successfully.'
                                } else {
                                    Write-Warning 'Fast-forward update failed. Local changes are preserved.'
                                }
                            }
                        }
                    }
                } else {
                    Write-Host 'Update skipped.'
                }
            } else {
                Write-Host 'Repository is up to date.'
            }
        } else {
            Write-Warning 'Could not check GitHub; continuing offline using local source.'
        }
    } else {
        Write-Warning 'origin is not the official acentino/IE-decompiled repository. Automatic updates are disabled.'
    }
} else {
    Write-Warning 'Not a Git checkout (or Git is missing); no updates can be fetched from GitHub.'
}

if (-not (Has-Command cmake)) {
    Write-Error 'CMake is missing. Install CMake and Visual Studio C++ build tools before launching.'
    exit 1
}

# Determine a working native C++ toolchain before running CMake. Some users have
# MSYS CMake in PATH, which defaults to Makefiles and cannot discover a Visual
# Studio installation automatically. Use VS generators when their C++ tools exist.
$vswhere = Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Microsoft Visual Studio\Installer\vswhere.exe'
# Prefer native Kitware CMake or the Visual Studio-bundled CMake over an MSYS
# CMake on PATH, which may not offer any Visual Studio generators.
$cmakeExecutable = (Get-Command cmake).Source
$kitwareCmake = Join-Path $env:ProgramFiles 'CMake\bin\cmake.exe'
if (Test-Path -LiteralPath $kitwareCmake) {
    $cmakeExecutable = $kitwareCmake
} elseif (Test-Path -LiteralPath $vswhere) {
    $vsLocations = @(& $vswhere -latest -products '*' -requires 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64' -property installationPath 2>$null)
    if ($LASTEXITCODE -eq 0 -and $vsLocations.Count -gt 0 -and $vsLocations[0]) {
        $vsBundledCmake = Join-Path ([string]$vsLocations[0]) 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
        if (Test-Path -LiteralPath $vsBundledCmake) { $cmakeExecutable = $vsBundledCmake }
    }
}
$cmakeHelp = (& $cmakeExecutable --help 2>$null | Out-String)
$vsBuild = $null
$vsToolsFound = $false
if (Test-Path -LiteralPath $vswhere) {
    $versions = @(
        @{ Range = '[18.0,19.0)'; Generator = 'Visual Studio 18 2026'; Build = 'build/windows-vs2026' },
        @{ Range = '[17.0,18.0)'; Generator = 'Visual Studio 17 2022'; Build = 'build/windows-vs2022' }
    )
    foreach ($version in $versions) {
        $vsInstall = @(& $vswhere -latest -products '*' -version $version.Range -requires 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64' -property installationPath 2>$null)
        if ($LASTEXITCODE -eq 0 -and $vsInstall.Count -gt 0 -and $vsInstall[0]) {
            $vsToolsFound = $true
            if ($cmakeHelp.Contains($version.Generator)) {
                $vsBuild = $version
                break
            }
        }
    }
}

if ($null -ne $vsBuild) {
    Write-Host ('Using ' + $vsBuild.Generator + ' C++ toolchain.')
    $relativeBuild = $vsBuild.Build
    $cmakeArgs = @('-S', '.', '-B', $relativeBuild, '-G', $vsBuild.Generator, '-A', 'x64')
} else {
    # For MinGW/Clang setups with a compiler on PATH, let the local CMake
    # installation select the default generator as before.
    $hasCxx = (Has-Command 'g++') -or (Has-Command 'clang++') -or (Has-Command 'cl')
    if (-not $hasCxx) {
        Write-Host ''
        if ($vsToolsFound) {
            Write-Host 'Visual Studio C++ tools are installed, but CMake does not expose a matching Visual Studio generator.' -ForegroundColor Yellow
            Write-Host ('Selected CMake: ' + $cmakeExecutable)
            Write-Host 'Install native Kitware CMake (winget install --id Kitware.CMake -e), then restart the launcher.'
            exit 1
        }
        Write-Host 'No C++ compiler was found for this Windows environment.' -ForegroundColor Yellow
        Write-Host 'Install Visual Studio 2022 Build Tools, selecting "Desktop development with C++".'
        Write-Host 'Official Microsoft downloads: https://visualstudio.microsoft.com/vs/older-downloads/'
        if (Has-Command 'winget') {
            Write-Host 'Optional command line install:'
            Write-Host '  winget install --id Microsoft.VisualStudio.2022.BuildTools --exact --source winget --override "--passive --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"'
        } else {
            Write-Host 'winget is not installed on this PC; it is NOT required.'
            Write-Host 'Alternatively download the official bootstrapper from:'
            Write-Host '  https://aka.ms/vs/17/release/vs_BuildTools.exe'
        }
        Write-Host 'If Build Tools is already installed, choose Modify in Visual Studio Installer to add C++.'
        try {
            $openInstaller = Read-Host 'Open Microsoft Build Tools download page in your browser? [y/N]'
            if ($openInstaller -match '^(?i:y|yes|o|oui)
    }
    Write-Host 'Using compiler tools available on PATH.'
    $relativeBuild = 'build'
    $cmakeArgs = @('-S', '.', '-B', $relativeBuild)
}
$buildDir = Join-Path $repoRoot $relativeBuild

Write-Host 'Configuring and building the native tool...'
# Always pass repo-relative paths: some MSYS versions of CMake treat E:/...
# Windows paths as relative /e/... paths and generate an invalid source path.
& $cmakeExecutable @cmakeArgs
if ($LASTEXITCODE -ne 0) {
    Write-Warning 'CMake failed. If an older generator is cached, remove ONLY its build directory and retry.'
    Write-Error 'CMake configure failed.'
    exit 1
}
& $cmakeExecutable --build $relativeBuild --config Release
if ($LASTEXITCODE -ne 0) { Write-Error 'Build failed; no older executable will be launched.'; exit 1 }

$executable = Join-Path $buildDir 'Release\ie1_romtool.exe'
if (-not (Test-Path -LiteralPath $executable)) {
    $executable = Join-Path $buildDir 'ie1_romtool.exe'
}
if (-not (Test-Path -LiteralPath $executable)) {
    Write-Error 'Build completed but ie1_romtool.exe is missing.'
    exit 1
}

if (-not $ToolArgs -or $ToolArgs.Count -eq 0) {
    $romDir = Join-Path $repoRoot 'input'
    $roms = @(Get-ChildItem -LiteralPath $romDir -Filter '*.nds' -File -ErrorAction SilentlyContinue)
    if ($roms.Count -eq 1) {
        $ToolArgs = @($roms[0].FullName, 'info')
    } else {
        Write-Host ''
        Write-Host 'Build succeeded. This is a ROM analysis utility, NOT a playable PC port.'
        Write-Host 'Put one legally obtained .nds file into input\, or pass a ROM path:'
        Write-Host '  Start-IE.cmd "C:\path\game.nds" info'
        Write-Host '  Start-IE.cmd "C:\path\game.nds" check-overlays'
        exit 0
    }
}
& $executable @ToolArgs
exit $LASTEXITCODE
) {
                Start-Process 'https://visualstudio.microsoft.com/vs/older-downloads/'
            }
        } catch {
            Write-Warning 'Could not open the browser. Use the Microsoft URL shown above.'
        }
        Write-Host 'After installation, restart this launcher.'
        exit 1
    }
    Write-Host 'Using compiler tools available on PATH.'
    $relativeBuild = 'build'
    $cmakeArgs = @('-S', '.', '-B', $relativeBuild)
}
$buildDir = Join-Path $repoRoot $relativeBuild

Write-Host 'Configuring and building the native tool...'
# Always pass repo-relative paths: some MSYS versions of CMake treat E:/...
# Windows paths as relative /e/... paths and generate an invalid source path.
& $cmakeExecutable @cmakeArgs
if ($LASTEXITCODE -ne 0) {
    Write-Warning 'CMake failed. If an older generator is cached, remove ONLY its build directory and retry.'
    Write-Error 'CMake configure failed.'
    exit 1
}
& $cmakeExecutable --build $relativeBuild --config Release
if ($LASTEXITCODE -ne 0) { Write-Error 'Build failed; no older executable will be launched.'; exit 1 }

$executable = Join-Path $buildDir 'Release\ie1_romtool.exe'
if (-not (Test-Path -LiteralPath $executable)) {
    $executable = Join-Path $buildDir 'ie1_romtool.exe'
}
if (-not (Test-Path -LiteralPath $executable)) {
    Write-Error 'Build completed but ie1_romtool.exe is missing.'
    exit 1
}

if (-not $ToolArgs -or $ToolArgs.Count -eq 0) {
    $romDir = Join-Path $repoRoot 'input'
    $roms = @(Get-ChildItem -LiteralPath $romDir -Filter '*.nds' -File -ErrorAction SilentlyContinue)
    if ($roms.Count -eq 1) {
        $ToolArgs = @($roms[0].FullName, 'info')
    } else {
        Write-Host ''
        Write-Host 'Build succeeded. This is a ROM analysis utility, NOT a playable PC port.'
        Write-Host 'Put one legally obtained .nds file into input\, or pass a ROM path:'
        Write-Host '  Start-IE.cmd "C:\path\game.nds" info'
        Write-Host '  Start-IE.cmd "C:\path\game.nds" check-overlays'
        exit 0
    }
}
& $executable @ToolArgs
exit $LASTEXITCODE
