$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$addon = Join-Path $root 'ashitabars\ashitabars.lua'
$config = Join-Path $root 'ashitabars\ashitabars_config.lua'
$readme = Join-Path $root 'README.md'
$fishIcon = Join-Path $root 'ashitabars\assets\icons\fish.png'

foreach ($path in @($addon, $config, $readme, $fishIcon)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required file: $path"
    }
}

$lua = Get-Content -LiteralPath $addon -Raw
$configText = Get-Content -LiteralPath $config -Raw
$readmeText = Get-Content -LiteralPath $readme -Raw
$topLevelLocalCount = ([regex]::Matches($lua, '(?m)^local\s+')).Count
if ($topLevelLocalCount -gt 199) {
    throw "Addon has $topLevelLocalCount top-level local declarations; keep this below Lua 5.1's 200-local chunk limit."
}

foreach ($needle in @('item_bar = {', 'excluded_item_ids = {}', 'buttons_per_row = 10', "potency_order = 'highest'", 'show_recovery_amounts = true')) {
    if (-not $configText.Contains($needle)) {
        throw "Expected dynamic Item Bar configuration not found: $needle"
    }
}

foreach ($needle in @(
    'COMMAND_MODE.render_item_resource_tooltip({',
    'source = item_source_for_command(slot.command)',
    'function ITEM_BAR.scan(force)',
    'function ITEM_BAR.category_for_item(entry)',
    'function ITEM_BAR.sort_items(items)',
    'ITEM_BAR.RECOVERY_BY_ID',
    'ITEM_BAR.draw_group_header',
    'ITEM_BAR.draw_recovery_badge',
    'resource.Type',
    'item_type == 7',
    'ITEM_BAR.CAN_USE_FLAG = 0x0200',
    'temporary == true and bit.band(item_flags, ITEM_BAR.CAN_USE_FLAG) ~= 0',
    'function ITEM_BAR.render_config_tab()',
    'excluded_item_ids',
    'ITEM_BAR.render();'
)) {
    if (-not $lua.Contains($needle)) {
        throw "Expected dynamic Item Bar integration not found: $needle"
    }
}

$itemHandleIndex = $lua.IndexOf('local item_handle = COMMAND_MODE.item_icon_handle_for_slot(slot);')
$assetHandleIndex = $lua.IndexOf('local asset_handle = ICON_ART_STYLE.icon_handle(icon_def);', $itemHandleIndex)
if ($itemHandleIndex -lt 0 -or $assetHandleIndex -lt 0 -or $itemHandleIndex -gt $assetHandleIndex) {
    throw 'Real item texture must be attempted before the generic inferred icon asset.'
}

foreach ($needle in @(
    "['/fish'] = true",
    "['/afishing'] = true",
    "['/aminimap'] = true",
    "command:lower():match('^%s*/aminimap%s+toggle%s*$')",
    'ashitabars_slot_overlay_event_t',
    "e.name ~= 'ashitabars_slot_overlay_v1'",
    "RaiseEvent('ashitabars_slot_overlay_query_v1'",
    'EXTERNAL_OVERLAY.apply',
    'external_slot_overlays',
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
    'settings.show_party_picker == false'
)) {
    if (-not $lua.Contains($needle)) {
        throw "Expected attended party-picker pattern not found: $needle"
    }
}

foreach ($needle in @('`/fish`', '`asset_fish`', 'Pressing or clicking that button opens', '<p0>`-`<p5>', 'server ID', 'show_party_picker = false', 'suppress_native_macro_alt = true', 'Temporary addon overlays', '`/afishing cast`', '`/aminimap toggle`', 'never')) {
    if (-not $readmeText.Contains($needle)) {
        throw "Expected party-picker documentation not found: $needle"
    }
}

foreach ($forbidden in @('AddOutgoingPacket', 'ashita.memory.write_', 'SetTargetIndex', 'FISHING.', 'fishing_strip', 'fishing_state.lua', '/lac fwd fishon')) {
    if ($lua.Contains($forbidden)) {
        throw "Forbidden active-helper surface found in addon: $forbidden"
    }
}

Write-Host 'AshitaBars validation passed.'
