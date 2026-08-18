[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'Programs\ReelArrange'),
    [switch]$NoDesktopShortcut,
    [switch]$SkipTests
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceScript = Join-Path $projectRoot 'src\ReelArrange.ps1'
$launcherSource = Join-Path $projectRoot 'src\ReelArrangeLauncher.cs'
$versionPath = Join-Path $projectRoot 'VERSION'
$logoIcon = Join-Path $projectRoot 'assets\ReelArrange.ico'
$logoPng = Join-Path $projectRoot 'assets\ReelArrange.png'
$compiler = Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$automationAssembly = (& $windowsPowerShell -NoProfile -Command '[Management.Automation.PSObject].Assembly.Location').Trim()
$desktop = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktop 'ReelArrange.lnk'
$startMenuPrograms = [Environment]::GetFolderPath('Programs')
$startMenuFolder = Join-Path $startMenuPrograms 'ReelArrange'
$startMenuShortcut = Join-Path $startMenuFolder 'ReelArrange.lnk'
$startMenuAboutShortcut = Join-Path $startMenuFolder 'About ReelArrange.lnk'
$legacyShortcutPath = Join-Path $desktop 'Jellyfin Media Prep.lnk'

foreach ($required in @($sourceScript, $launcherSource, $versionPath, $logoIcon, $logoPng, $compiler, $windowsPowerShell, $automationAssembly)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required installation file is missing: $required"
    }
}

$running = @(Get-Process -Name 'ReelArrange' -ErrorAction SilentlyContinue)
if ($running.Count -gt 0) {
    throw 'ReelArrange is currently running. Close it and run the installer again.'
}

if (-not $SkipTests) {
    & (Join-Path $PSScriptRoot 'test.ps1') -WindowsPowerShellOnly
    if ($LASTEXITCODE -ne 0) { throw 'Tests failed; installation was stopped.' }
}

if (-not (Test-Path -LiteralPath $InstallRoot)) {
    New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
}

$installedScript = Join-Path $InstallRoot 'ReelArrange.ps1'
$installedLauncher = Join-Path $InstallRoot 'ReelArrange.exe'
$temporaryLauncher = Join-Path $InstallRoot 'ReelArrange.new.exe'

Copy-Item -LiteralPath $sourceScript -Destination $installedScript -Force
Copy-Item -LiteralPath $versionPath -Destination (Join-Path $InstallRoot 'VERSION') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'LICENSE') -Destination (Join-Path $InstallRoot 'LICENSE') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'NOTICE.md') -Destination (Join-Path $InstallRoot 'NOTICE.md') -Force
$installedAssets = Join-Path $InstallRoot 'assets'
if (-not (Test-Path -LiteralPath $installedAssets)) { New-Item -ItemType Directory -Path $installedAssets -Force | Out-Null }
Copy-Item -LiteralPath $logoIcon -Destination (Join-Path $installedAssets 'ReelArrange.ico') -Force
Copy-Item -LiteralPath $logoPng -Destination (Join-Path $installedAssets 'ReelArrange.png') -Force

if (Test-Path -LiteralPath $temporaryLauncher) {
    Remove-Item -LiteralPath $temporaryLauncher -Force
}
& $compiler /nologo /target:winexe /optimize+ "/reference:$automationAssembly" "/win32icon:$logoIcon" "/out:$temporaryLauncher" $launcherSource
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $temporaryLauncher)) {
    throw 'The windowless launcher did not compile.'
}
Move-Item -LiteralPath $temporaryLauncher -Destination $installedLauncher -Force

$newDataRoot = Join-Path $env:LOCALAPPDATA 'ReelArrange'
$legacyDataRoot = Join-Path $env:LOCALAPPDATA 'Jellyfin Media Prep'
$newSettings = Join-Path $newDataRoot 'settings.json'
$legacySettings = Join-Path $legacyDataRoot 'settings.json'
if (-not (Test-Path -LiteralPath $newDataRoot)) {
    New-Item -ItemType Directory -Path $newDataRoot -Force | Out-Null
}
if ((Test-Path -LiteralPath $legacySettings -PathType Leaf) -and -not (Test-Path -LiteralPath $newSettings)) {
    Copy-Item -LiteralPath $legacySettings -Destination $newSettings
    Write-Host 'Migrated the saved TMDB credential and library roots from Jellyfin Media Prep.'
}

$wsh = New-Object -ComObject WScript.Shell
if (-not $NoDesktopShortcut) {
    $shortcut = $wsh.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $installedLauncher
    $shortcut.Arguments = ''
    $shortcut.WorkingDirectory = $InstallRoot
    $shortcut.Description = 'Prepare movies and TV shows for Jellyfin using TMDB metadata'
    $shortcut.IconLocation = "$installedLauncher,0"
    $shortcut.Save()
}

if (-not (Test-Path -LiteralPath $startMenuFolder)) {
    New-Item -ItemType Directory -Path $startMenuFolder -Force | Out-Null
}
$menuShortcut = $wsh.CreateShortcut($startMenuShortcut)
$menuShortcut.TargetPath = $installedLauncher
$menuShortcut.Arguments = ''
$menuShortcut.WorkingDirectory = $InstallRoot
$menuShortcut.Description = 'Prepare movies and TV shows for Jellyfin using TMDB metadata'
$menuShortcut.IconLocation = "$installedLauncher,0"
$menuShortcut.Save()

$aboutShortcut = $wsh.CreateShortcut($startMenuAboutShortcut)
$aboutShortcut.TargetPath = $installedLauncher
$aboutShortcut.Arguments = '--about'
$aboutShortcut.WorkingDirectory = $InstallRoot
$aboutShortcut.Description = 'About ReelArrange'
$aboutShortcut.IconLocation = "$installedLauncher,0"
$aboutShortcut.Save()

if (Test-Path -LiteralPath $legacyShortcutPath -PathType Leaf) {
    try {
        $legacyShortcut = $wsh.CreateShortcut($legacyShortcutPath)
        $ownedLegacyShortcut =
            $legacyShortcut.TargetPath -like '*JellyfinMediaPrepLauncher.exe' -or
            $legacyShortcut.Arguments -like '*JellyfinMediaPrep*'
        if ($ownedLegacyShortcut) {
            Remove-Item -LiteralPath $legacyShortcutPath -Force
            Write-Host 'Removed the legacy Jellyfin Media Prep Desktop shortcut.'
        }
    }
    catch {
        Write-Warning "The legacy Desktop shortcut could not be inspected: $($_.Exception.Message)"
    }
}

$version = (Get-Content -LiteralPath $versionPath -Raw).Trim()
Write-Host ''
Write-Host "ReelArrange $version installed successfully."
Write-Host "Application: $installedLauncher"
if (-not $NoDesktopShortcut) { Write-Host "Desktop shortcut: $shortcutPath" }
Write-Host "Start menu: $startMenuFolder"
