[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$version = (Get-Content -LiteralPath (Join-Path $projectRoot 'VERSION') -Raw).Trim()
$distRoot = Join-Path $projectRoot 'dist'
$stageParent = Join-Path ([IO.Path]::GetTempPath()) ('ReelArrangePackage-' + [guid]::NewGuid().ToString('N'))
$stageRoot = Join-Path $stageParent "ReelArrange-$version"
$archive = Join-Path $distRoot "ReelArrange-$version.zip"
$resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$compiler = Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$automationAssembly = (& $windowsPowerShell -NoProfile -Command '[Management.Automation.PSObject].Assembly.Location').Trim()
$launcherSource = Join-Path $projectRoot 'src\ReelArrangeLauncher.cs'
$sourceScript = Join-Path $projectRoot 'src\ReelArrange.ps1'
$logoIcon = Join-Path $projectRoot 'assets\ReelArrange.ico'

& (Join-Path $PSScriptRoot 'test.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Tests failed; package creation was stopped.' }

try {
    New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null
    foreach ($file in @('README.md', 'LICENSE', 'NOTICE.md', 'VERSION', 'CHANGELOG.md', 'SECURITY.md', 'SUPPORT.md')) {
        Copy-Item -LiteralPath (Join-Path $projectRoot $file) -Destination (Join-Path $stageRoot $file)
    }
    foreach ($directory in @('src', 'scripts', 'docs', 'assets')) {
        Copy-Item -LiteralPath (Join-Path $projectRoot $directory) -Destination (Join-Path $stageRoot $directory) -Recurse
    }
    Copy-Item -LiteralPath $sourceScript -Destination (Join-Path $stageRoot 'ReelArrange.ps1')
    $portableLauncher = Join-Path $stageRoot 'ReelArrange.exe'
    & $compiler /nologo /target:winexe /optimize+ "/reference:$automationAssembly" "/win32icon:$logoIcon" "/out:$portableLauncher" $launcherSource
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $portableLauncher -PathType Leaf)) {
        throw 'The portable ReelArrange executable did not compile.'
    }
    if (-not (Test-Path -LiteralPath $distRoot)) { New-Item -ItemType Directory -Path $distRoot -Force | Out-Null }
    if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
    Compress-Archive -LiteralPath $stageRoot -DestinationPath $archive -CompressionLevel Optimal
}
finally {
    $resolvedStageParent = [IO.Path]::GetFullPath($stageParent)
    if ($resolvedStageParent.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedStageParent)) {
        Remove-Item -LiteralPath $resolvedStageParent -Recurse -Force
    }
}

Write-Host "Created $archive"
