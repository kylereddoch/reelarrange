[CmdletBinding()]
param(
    [switch]$Ci,
    [switch]$WindowsPowerShellOnly
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceScript = Join-Path $projectRoot 'src\Reelarrange.ps1'
$launcherSource = Join-Path $projectRoot 'src\ReelarrangeLauncher.cs'
$requiredFiles = @(
    $sourceScript,
    $launcherSource,
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

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('ReelarrangeBuildTest-' + [guid]::NewGuid().ToString('N'))
$resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
try {
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    $testLauncher = Join-Path $testRoot 'Reelarrange.exe'
    & $compiler /nologo /target:winexe /optimize+ "/out:$testLauncher" $launcherSource
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $testLauncher -PathType Leaf)) {
        throw 'Launcher compilation test failed.'
    }
}
finally {
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    if ($resolvedTestRoot.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedTestRoot)) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}

$version = (Get-Content -LiteralPath (Join-Path $projectRoot 'VERSION') -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw "VERSION is not semantic: $version" }

Write-Host "Reelarrange $version tests passed."
