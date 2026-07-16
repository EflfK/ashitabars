param(
    [string]$AshitaRoot = 'C:\Games\CatsEyeXI\catseyexi-client\Ashita'
)

$ErrorActionPreference = 'Stop'

$sourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = Join-Path $sourceRoot 'ashitabars'
$addonsRoot = Join-Path $AshitaRoot 'addons'
$target = Join-Path $addonsRoot 'ashitabars'
$backupRoot = Join-Path $sourceRoot '.local-backups'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

function Assert-UnderRoot {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Label
    )

    $resolvedRoot = [IO.Path]::GetFullPath($Root)
    $resolvedPath = [IO.Path]::GetFullPath($Path)
    if (-not $resolvedPath.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label path is outside expected root. Path: $resolvedPath Root: $resolvedRoot"
    }

    return $resolvedPath
}

if (-not (Test-Path -LiteralPath $AshitaRoot)) {
    throw "Ashita root does not exist: $AshitaRoot"
}

if (-not (Test-Path -LiteralPath $source)) {
    throw "Addon source does not exist: $source"
}

$addonsRoot = Assert-UnderRoot -Path $addonsRoot -Root $AshitaRoot -Label 'Ashita addons root'
$target = Assert-UnderRoot -Path $target -Root $addonsRoot -Label 'AshitaBars install target'

New-Item -ItemType Directory -Force -Path $addonsRoot | Out-Null
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

if (Test-Path -LiteralPath $target) {
    $backup = Join-Path $backupRoot "ashitabars-$stamp"
    Move-Item -LiteralPath $target -Destination $backup
    Write-Host "Backed up existing addon to: $backup"
}

Copy-Item -LiteralPath $source -Destination $target -Recurse -Force
Write-Host "Installed AshitaBars addon: $target"

