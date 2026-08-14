[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'Programs\ReelArrange'),
    [switch]$RemoveUserData
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$running = @(Get-Process -Name 'ReelArrange' -ErrorAction SilentlyContinue)
if ($running.Count -gt 0) {
    throw 'ReelArrange is currently running. Close it before uninstalling.'
}

$desktop = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktop 'ReelArrange.lnk'
$startMenuPrograms = [Environment]::GetFolderPath('Programs')
$startMenuFolder = Join-Path $startMenuPrograms 'ReelArrange'
$userDataRoot = Join-Path $env:LOCALAPPDATA 'ReelArrange'
$expectedInstallParent = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Programs')).TrimEnd('\') + '\'
$resolvedInstallRoot = [IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')

if (-not $resolvedInstallRoot.StartsWith($expectedInstallParent, [StringComparison]::OrdinalIgnoreCase)) {
    throw "The install root must remain under $expectedInstallParent"
}

if (Test-Path -LiteralPath $shortcutPath -PathType Leaf) {
    $wsh = New-Object -ComObject WScript.Shell
    $shortcut = $wsh.CreateShortcut($shortcutPath)
    if ($shortcut.TargetPath -ieq (Join-Path $resolvedInstallRoot 'ReelArrange.exe')) {
        if ($PSCmdlet.ShouldProcess($shortcutPath, 'Remove Desktop shortcut')) {
            Remove-Item -LiteralPath $shortcutPath -Force
        }
    }
}

if (Test-Path -LiteralPath $startMenuFolder -PathType Container) {
    $wsh = New-Object -ComObject WScript.Shell
    foreach ($menuShortcutPath in @(Get-ChildItem -LiteralPath $startMenuFolder -File -Filter '*.lnk' | ForEach-Object { $_.FullName })) {
        $menuShortcut = $wsh.CreateShortcut($menuShortcutPath)
        if ($menuShortcut.TargetPath -ieq (Join-Path $resolvedInstallRoot 'ReelArrange.exe')) {
            if ($PSCmdlet.ShouldProcess($menuShortcutPath, 'Remove Start menu shortcut')) {
                Remove-Item -LiteralPath $menuShortcutPath -Force
            }
        }
    }
    if (@(Get-ChildItem -LiteralPath $startMenuFolder -Force).Count -eq 0) {
        if ($PSCmdlet.ShouldProcess($startMenuFolder, 'Remove empty Start menu folder')) {
            Remove-Item -LiteralPath $startMenuFolder -Force
        }
    }
}

if (Test-Path -LiteralPath $resolvedInstallRoot -PathType Container) {
    if ($PSCmdlet.ShouldProcess($resolvedInstallRoot, 'Remove installed application')) {
        Remove-Item -LiteralPath $resolvedInstallRoot -Recurse -Force
    }
}

if ($RemoveUserData -and (Test-Path -LiteralPath $userDataRoot -PathType Container)) {
    $resolvedDataRoot = [IO.Path]::GetFullPath($userDataRoot).TrimEnd('\')
    $expectedDataRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'ReelArrange')).TrimEnd('\')
    if ($resolvedDataRoot -ne $expectedDataRoot) { throw 'Unexpected user-data path; removal was stopped.' }
    if ($PSCmdlet.ShouldProcess($resolvedDataRoot, 'Remove settings and activity logs')) {
        Remove-Item -LiteralPath $resolvedDataRoot -Recurse -Force
    }
}

if ($WhatIfPreference) {
    Write-Host 'Uninstall preview completed. Nothing was removed.'
}
else {
    Write-Host 'ReelArrange was uninstalled.'
    if (-not $RemoveUserData) {
        Write-Host "Settings and logs were kept at $userDataRoot"
    }
}
