$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$addon = Join-Path $root 'ashitabars\ashitabars.lua'
$readme = Join-Path $root 'README.md'
$fishIcon = Join-Path $root 'ashitabars\assets\icons\fish.png'

foreach ($path in @($addon, $readme, $fishIcon)) {
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

$themeDefinition = $lua.IndexOf('local function current_theme()')
$fishingRender = $lua.IndexOf('function FISHING.render()')
if ($themeDefinition -lt 0 -or $fishingRender -lt 0 -or $themeDefinition -gt $fishingRender) {
    throw 'current_theme must be declared before the Fishing Quick Strip render path.'
}

foreach ($needle in @(
    "['/fish'] = true",
    "'camera', 'fish'",
    'PARTY_PICKER.try_start',
    'PARTY_PICKER.handle_key',
    'PARTY_PICKER.confirm',
    'PARTY_PICKER.clear_directinput_state',
    'PARTY_PICKER.block_directinput_key',
    "ashita.events.register('key_data'",
    'VK.DIK_PARTY_PICKER',
    'keyptr[DIK_BLOCKED_MODIFIERS[index]] = 0',
    'local suppress_alt = settings.suppress_native_macro_alt == true',
    "PROTOCOL_COMMAND = '/ashitaui'",
    "('<p%d>'):fmt(member.slot)",
    'PARTY_PICKER.same_member(member, picker)',
    'settings.show_party_picker == false',
    'fishing_strip == true',
    'FISHING.scan_items',
    'FISHING.toggle',
    'FISHING.render',
    "('/lac fwd fishon %d %d')",
    "'/lac fwd fishoff'",
    "'/lac fwd fishrod %d'",
    "'/lac fwd fishbait %d'",
    "'fishing_state.lua'"
)) {
    if (-not $lua.Contains($needle)) {
        throw "Expected attended party-picker pattern not found: $needle"
    }
}

foreach ($needle in @('`/fish`', '`asset_fish`', 'Pressing or clicking that button opens', '<p0>`-`<p5>', 'server ID', 'show_party_picker = false', 'suppress_native_macro_alt = true', 'Fishing Quick Strip', '`fishing_strip = true`', '`fishrod`', '`fishbait`', 'fishing_state.lua', 'never')) {
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
