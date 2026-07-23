$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$addon = Join-Path $root 'ashitabars\ashitabars.lua'
$readme = Join-Path $root 'README.md'

foreach ($path in @($addon, $readme)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required file: $path"
    }
}

$lua = Get-Content -LiteralPath $addon -Raw
$readmeText = Get-Content -LiteralPath $readme -Raw
$topLevelLocalCount = ([regex]::Matches($lua, '(?m)^local\s+')).Count
if ($topLevelLocalCount -gt 199) {
    throw "Addon has $topLevelLocalCount top-level local declarations; keep this below Lua 5.1's 200-local chunk limit."
}

foreach ($needle in @(
    'PARTY_PICKER.try_start',
    'PARTY_PICKER.handle_key',
    'PARTY_PICKER.confirm',
    'PARTY_PICKER.clear_directinput_state',
    'PARTY_PICKER.block_directinput_key',
    "ashita.events.register('key_data'",
    'VK.DIK_PARTY_PICKER',
    "PROTOCOL_COMMAND = '/ashitaui'",
    "('<p%d>'):fmt(member.slot)",
    'PARTY_PICKER.same_member(member, picker)',
    'settings.show_party_picker == false'
)) {
    if (-not $lua.Contains($needle)) {
        throw "Expected attended party-picker pattern not found: $needle"
    }
}

foreach ($needle in @('Pressing or clicking that button opens', '<p0>`-`<p5>', 'server ID', 'show_party_picker = false', 'never')) {
    if (-not $readmeText.Contains($needle)) {
        throw "Expected party-picker documentation not found: $needle"
    }
}

foreach ($forbidden in @('AddOutgoingPacket', 'ashita.memory.write_', 'SetTargetIndex')) {
    if ($lua.Contains($forbidden)) {
        throw "Forbidden active-helper surface found in addon: $forbidden"
    }
}

Write-Host 'AshitaBars validation passed.'
