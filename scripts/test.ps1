[CmdletBinding()]
param(
    [switch]$Ci,
    [switch]$WindowsPowerShellOnly
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceScript = Join-Path $projectRoot 'src\ReelArrange.ps1'
$launcherSource = Join-Path $projectRoot 'src\ReelArrangeLauncher.cs'
$logoIcon = Join-Path $projectRoot 'assets\ReelArrange.ico'
$logoPng = Join-Path $projectRoot 'assets\ReelArrange.png'
$requiredFiles = @(
    $sourceScript,
    $launcherSource,
    $logoIcon,
    $logoPng,
    (Join-Path $projectRoot 'README.md'),
    (Join-Path $projectRoot 'LICENSE'),
    (Join-Path $projectRoot 'SECURITY.md'),
    (Join-Path $projectRoot 'VERSION'),
    (Join-Path $projectRoot '.github\workflows\test.yml'),
    (Join-Path $projectRoot '.github\ISSUE_TEMPLATE\bug_report.yml'),
    (Join-Path $projectRoot '.github\ISSUE_TEMPLATE\feature_request.yml')
)

foreach ($required in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required project file is missing: $required"
    }
}

$version = (Get-Content -LiteralPath (Join-Path $projectRoot 'VERSION') -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw "VERSION is not semantic: $version" }

Add-Type -AssemblyName System.Drawing
$logoImage = New-Object Drawing.Bitmap $logoPng
try {
    if ($logoImage.Width -lt 256 -or $logoImage.Height -lt 256 -or $logoImage.PixelFormat -notmatch 'Argb' -or $logoImage.GetPixel(0, 0).A -ne 0) {
        throw 'The ReelArrange PNG logo must be at least 256x256 with alpha transparency.'
    }
}
finally {
    $logoImage.Dispose()
}
$logoResource = New-Object Drawing.Icon $logoIcon
try {
    if ($logoResource.Width -lt 16 -or $logoResource.Height -lt 16) { throw 'The ReelArrange ICO resource is invalid.' }
}
finally {
    $logoResource.Dispose()
}

$tokens = $null
$parseErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile($sourceScript, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) {
    $messages = ($parseErrors | ForEach-Object { $_.Message }) -join [Environment]::NewLine
    throw "PowerShell parse errors:`r`n$messages"
}

$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
& $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $sourceScript -SelfTest
if ($LASTEXITCODE -ne 0) { throw 'Windows PowerShell self-tests failed.' }

if (-not $WindowsPowerShellOnly) {
    $pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    if ($null -ne $pwsh) {
        & $pwsh.Source -NoProfile -File $sourceScript -SelfTest
        if ($LASTEXITCODE -ne 0) { throw 'PowerShell 7 self-tests failed.' }
    }
}

$compiler = Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) {
    throw 'The .NET Framework C# compiler was not found.'
}
$automationAssembly = (& $windowsPowerShell -NoProfile -Command '[Management.Automation.PSObject].Assembly.Location').Trim()
if (-not (Test-Path -LiteralPath $automationAssembly -PathType Leaf)) {
    throw 'The Windows PowerShell automation assembly was not found.'
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('ReelArrangeBuildTest-' + [guid]::NewGuid().ToString('N'))
$resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
try {
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    $testLauncher = Join-Path $testRoot 'ReelArrange.exe'
    & $compiler /nologo /target:winexe /optimize+ "/reference:$automationAssembly" "/win32icon:$logoIcon" "/out:$testLauncher" $launcherSource
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $testLauncher -PathType Leaf)) {
        throw 'Launcher compilation test failed.'
    }
    $fileInfo = [Diagnostics.FileVersionInfo]::GetVersionInfo($testLauncher)
    if ($fileInfo.ProductName -ne 'ReelArrange' -or $fileInfo.FileVersion -ne "$version.0") {
        throw "Launcher metadata is not aligned with VERSION. Product=$($fileInfo.ProductName), FileVersion=$($fileInfo.FileVersion)"
    }
    Copy-Item -LiteralPath $sourceScript -Destination (Join-Path $testRoot 'ReelArrange.ps1')
    $launcherTest = Start-Process -FilePath $testLauncher -ArgumentList '--self-test' -Wait -PassThru
    if ($launcherTest.ExitCode -ne 0) {
        throw "In-process launcher self-test failed with exit code $($launcherTest.ExitCode)."
    }
}
finally {
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    if ($resolvedTestRoot.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedTestRoot)) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}

Write-Host "ReelArrange $version tests passed."
