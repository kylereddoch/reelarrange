[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'Programs\Reelarrange'),
    [switch]$RemoveUserData
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$running = @(Get-Process -Name 'Reelarrange' -ErrorAction SilentlyContinue)
if ($running.Count -gt 0) {
    throw 'Reelarrange is currently running. Close it before uninstalling.'
}

$desktop = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktop 'Reelarrange.lnk'
$userDataRoot = Join-Path $env:LOCALAPPDATA 'Reelarrange'
$expectedInstallParent = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Programs')).TrimEnd('\') + '\'
$resolvedInstallRoot = [IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')

if (-not $resolvedInstallRoot.StartsWith($expectedInstallParent, [StringComparison]::OrdinalIgnoreCase)) {
    throw "The install root must remain under $expectedInstallParent"
}

if (Test-Path -LiteralPath $shortcutPath -PathType Leaf) {
    $wsh = New-Object -ComObject WScript.Shell
    $shortcut = $wsh.CreateShortcut($shortcutPath)
    if ($shortcut.TargetPath -ieq (Join-Path $resolvedInstallRoot 'Reelarrange.exe')) {
        if ($PSCmdlet.ShouldProcess($shortcutPath, 'Remove Desktop shortcut')) {
            Remove-Item -LiteralPath $shortcutPath -Force
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
    $expectedDataRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Reelarrange')).TrimEnd('\')
    if ($resolvedDataRoot -ne $expectedDataRoot) { throw 'Unexpected user-data path; removal was stopped.' }
    if ($PSCmdlet.ShouldProcess($resolvedDataRoot, 'Remove settings and activity logs')) {
        Remove-Item -LiteralPath $resolvedDataRoot -Recurse -Force
    }
}

Write-Host 'Reelarrange was uninstalled.'
if (-not $RemoveUserData) {
    Write-Host "Settings and logs were kept at $userDataRoot"
}
