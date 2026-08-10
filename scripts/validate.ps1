$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$addon = Join-Path $root 'ashitabars\ashitabars.lua'
$config = Join-Path $root 'ashitabars\ashitabars_config.lua'
$readme = Join-Path $root 'README.md'
$fishIcon = Join-Path $root 'ashitabars\assets\icons\fish.png'
$bstIconNames = @(
    'bst_pet_courier_carrie', 'bst_pet_coldblood_como', 'bst_pet_lullaby_melodia',
    'bst_ready_metallic_body', 'bst_ready_bubble_shower', 'bst_ready_bubble_curtain',
    'bst_ready_scissor_guard', 'bst_ready_big_scissors', 'bst_ready_tail_blow',
    'bst_ready_fireball', 'bst_ready_blockhead', 'bst_ready_brain_crush',
    'bst_ready_infrasonics', 'bst_ready_secretion', 'bst_ready_sheep_charge',
    'bst_ready_lamb_chop', 'bst_ready_rage', 'bst_ready_sheep_song'
)
$bstIcons = $bstIconNames | ForEach-Object { Join-Path $root "ashitabars\assets\icons\$_.png" }

foreach ($path in @($addon, $config, $readme, $fishIcon) + $bstIcons) {
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

foreach ($needle in @('item_bar = {', 'excluded_item_ids = {}', 'buttons_per_row = 10', "potency_order = 'highest'", 'show_recovery_amounts = true', 'show_category_headers = true', 'bst_companion_bar = {', 'buttons_per_row = 7')) {
    if (-not $configText.Contains($needle)) {
        throw "Expected dynamic Item Bar configuration not found: $needle"
    }
}

foreach ($needle in @(
    'BST_BAR.PROTECTED_JUGS',
    "icon = 'bst_pet_courier_carrie'",
    "icon = 'bst_pet_coldblood_como'",
    "icon = 'bst_pet_lullaby_melodia'",
    'function BST_BAR.queue_picker_toggle()',
    'function BST_BAR.queue_jug_selection(item_id)',
    'function BST_BAR.apply_pending_picker_change()',
    'BST_BAR.PICKER_RELEASE_GUARD_SECONDS = 0.25',
    'bst_jug_choice = true',
    'state.bst_picker_pending_jug_id = jug.id',
    "bst_widget_id = ('jug-choice-%d'):fmt(jug.id)",
    "bst_widget_id = 'jug-picker-toggle'",
    "bst_widget_id = 'bestial-loyalty'",
    'local commandless_picker = slot.bst_picker_toggle == true or slot.bst_jug_choice == true;',
    "if ((type(slot.command) ~= 'string' or slot.command == '') and not commandless_picker) then",
    "bst_widget_id = 'ready-' .. key:gsub('[^a-z0-9]', '-')",
    'state.bst_action_suppressed_until = os.clock() + BST_BAR.PICKER_RELEASE_GUARD_SECONDS',
    'Bestial Loyalty jug selected: %s (%s).',
    'if os.clock() < (tonumber(state.bst_action_suppressed_until) or 0) then',
    "('##ashitabars_%s_%s'):fmt(row.id, tostring(widget_id))",
    'BST_BAR.PET_READY_BY_NAME',
    "['crabfamiliar'] = 'crab'",
    "['couriercarrie'] = 'crab'",
    "['coldbloodcomo'] = 'lizard'",
    "['lullabymelodia'] = 'sheep'",
    "crab = { 'Metallic Body', 'Bubble Shower', 'Bubble Curtain', 'Scissor Guard', 'Big Scissors' }",
    "lizard = { 'Tail Blow', 'Fireball', 'Blockhead', 'Brain Crush', 'Infrasonics', 'Secretion' }",
    "sheep = { 'Sheep Charge', 'Lamb Chop', 'Rage', 'Sheep Song' }",
    'function BST_BAR.ready_slots(pet)',
    "icon = 'bst_ready_' .. key:gsub('[^a-z0-9]+', '_')",
    "('/lac fwd bstjug %d'):fmt(jug_id)",
    '''/ja "Bestial Loyalty" <me>''',
    'BST_BAR.render();'
)) {
    if (-not $lua.Contains($needle)) {
        throw "Expected BST companion integration not found: $needle"
    }
}

$bstSlotsStart = $lua.IndexOf('function BST_BAR.slots(force)')
$bstSlotsEnd = $lua.IndexOf('function BST_BAR.slot(index)', $bstSlotsStart)
if ($bstSlotsStart -lt 0 -or $bstSlotsEnd -le $bstSlotsStart) {
    throw 'Could not isolate the BST companion slot builder.'
}
$bstSlotsText = $lua.Substring($bstSlotsStart, $bstSlotsEnd - $bstSlotsStart)
if ($bstSlotsText.Contains("label = 'Call Beast'")) {
    throw 'Call Beast must remain absent from the BST companion palette.'
}
if ($lua.Contains('function BST_BAR.cycle_jug(direction)') -or $lua.Contains('bst_selector = true')) {
    throw 'Legacy jug cycling must remain absent from the direct BST picker.'
}
if ($lua.Contains('imgui.IsWindowHovered()')) {
    throw 'The BST picker must not close from an unavailable window-hover fallback before mouse release.'
}

$readySlotsStart = $lua.IndexOf('function BST_BAR.ready_slots(pet)')
$readySlotsEnd = $lua.IndexOf('function BST_BAR.slots(force)', $readySlotsStart)
if ($readySlotsStart -lt 0 -or $readySlotsEnd -le $readySlotsStart) {
    throw 'Could not isolate the BST Ready slot builder.'
}
$readySlotsText = $lua.Substring($readySlotsStart, $readySlotsEnd - $readySlotsStart)
if ($readySlotsText.Contains('pet_command_actions') -or $readySlotsText.Contains('HasPetCommand')) {
    throw 'BST companion Ready slots must not enumerate the job-wide pet-command catalog.'
}
if ($bstSlotsText.Contains('item_icon_id = jug.id') -or $bstSlotsText.Contains('item_icon_id = selected.id')) {
    throw 'BST jug choices must render their pet portraits instead of broth item textures.'
}

foreach ($needle in @(
    'COMMAND_MODE.render_item_resource_tooltip({',
    'source = item_source_for_command(slot.command)',
    'function ITEM_BAR.scan(force)',
    'function ITEM_BAR.category_for_item(entry)',
    'function ITEM_BAR.sort_items(items)',
    'ITEM_BAR.RECOVERY_BY_ID',
    'ITEM_BAR.draw_group_header',
    'show_category_headers',
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

foreach ($needle in @('## BST Companion Palette', '`BL Jug` picker', 'Carrie, Como, and Melodia', 'gold border and check', 'distinct portrait', 'Every supported Ready move has its own ability artwork', 'complete mouse press and release', 'release guard', 'cannot fall through', 'Fish Oil Broth', 'C. Carrion', 'S. Herbal', 'Call Beast is intentionally absent', 'job-wide', '`HasPetCommand` catalog', 'five crab', 'six lizard', 'four sheep')) {
    if (-not $readmeText.Contains($needle)) {
        throw "Expected BST companion documentation not found: $needle"
    }
}

foreach ($forbidden in @('AddOutgoingPacket', 'ashita.memory.write_', 'SetTargetIndex', 'FISHING.', 'fishing_strip', 'fishing_state.lua', '/lac fwd fishon')) {
    if ($lua.Contains($forbidden)) {
        throw "Forbidden active-helper surface found in addon: $forbidden"
    }
}

Write-Host 'AshitaBars validation passed.'
