addon.name      = 'ashitabars';
addon.author    = 'Eflfk';
addon.version   = '0.26.0';
addon.desc      = 'Configurable attended action bars for Ashita.';

require('common');

local bit   = require('bit');
local chat  = require('chat');
local ffi   = require('ffi');
local imgui = require('imgui');

pcall(ffi.cdef, 'short __stdcall GetKeyState(int nVirtKey);');
pcall(ffi.cdef, 'typedef int32_t (__cdecl* ashitabars_get_config_value_t)(int32_t);');

local VK = {
    CONTROL = 0x11,
    ALT     = 0x12,
    SHIFT   = 0x10,
    BACKSPACE = 0x08,
    DELETE    = 0x2E,
    ESCAPE    = 0x1B,
    OEM_3     = 0xC0,
    DIGITS  = {
        [0x31] = 1,
        [0x32] = 2,
        [0x33] = 3,
        [0x34] = 4,
        [0x35] = 5,
        [0x36] = 6,
        [0x37] = 7,
        [0x38] = 8,
        [0x39] = 9,
        [0x30] = 10,
    },
};

local DIK_BLOCKED_MODIFIERS = {
    0x1D, -- Left Ctrl
    0x9D, -- Right Ctrl
    0x38, -- Left Alt
    0xB8, -- Right Alt
};
local DIK_DIGITS = {
    0x02, -- 1
    0x03, -- 2
    0x04, -- 3
    0x05, -- 4
    0x06, -- 5
    0x07, -- 6
    0x08, -- 7
    0x09, -- 8
    0x0A, -- 9
    0x0B, -- 0
};

local KEY_UP_MASK       = bit.lshift(0x8000, 16);
local KEY_WAS_DOWN_MASK = bit.lshift(0x4000, 16);
local DIGIT_LABELS      = { '1', '2', '3', '4', '5', '6', '7', '8', '9', '0' };
local ROWS              = {
    { id = 'base', label = 'Main', keyPrefix = ''  },
    { id = 'ctrl', label = 'Ctrl', keyPrefix = 'C', parent = 'base', modifier = 'ctrl' },
    { id = 'alt',  label = 'Alt',  keyPrefix = 'A', parent = 'base', modifier = 'alt' },
    { id = 'shift', label = 'Shift', keyPrefix = 'S', parent = 'base', modifier = 'shift' },
};
local CLICK_ROW         = { id = 'click', label = 'Click', keyPrefix = '', showHotkeys = false };
local BUTTON_ROWS       = {
    ROWS[1],
    ROWS[2],
    ROWS[3],
    ROWS[4],
    CLICK_ROW,
    { id = 'click2', label = 'Click 2', keyPrefix = '', showHotkeys = false },
    { id = 'click3', label = 'Click 3', keyPrefix = '', showHotkeys = false },
    { id = 'click4', label = 'Click 4', keyPrefix = '', showHotkeys = false },
    { id = 'click_ctrl', label = 'Ctrl', keyPrefix = 'C', parent = 'click', modifier = 'ctrl', showHotkeys = false },
    { id = 'click_alt', label = 'Alt', keyPrefix = 'A', parent = 'click', modifier = 'alt', showHotkeys = false },
    { id = 'click_shift', label = 'Shift', keyPrefix = 'S', parent = 'click', modifier = 'shift', showHotkeys = false },
    { id = 'click2_ctrl', label = 'Ctrl', keyPrefix = 'C', parent = 'click2', modifier = 'ctrl', showHotkeys = false },
    { id = 'click2_alt', label = 'Alt', keyPrefix = 'A', parent = 'click2', modifier = 'alt', showHotkeys = false },
    { id = 'click2_shift', label = 'Shift', keyPrefix = 'S', parent = 'click2', modifier = 'shift', showHotkeys = false },
    { id = 'click3_ctrl', label = 'Ctrl', keyPrefix = 'C', parent = 'click3', modifier = 'ctrl', showHotkeys = false },
    { id = 'click3_alt', label = 'Alt', keyPrefix = 'A', parent = 'click3', modifier = 'alt', showHotkeys = false },
    { id = 'click3_shift', label = 'Shift', keyPrefix = 'S', parent = 'click3', modifier = 'shift', showHotkeys = false },
    { id = 'click4_ctrl', label = 'Ctrl', keyPrefix = 'C', parent = 'click4', modifier = 'ctrl', showHotkeys = false },
    { id = 'click4_alt', label = 'Alt', keyPrefix = 'A', parent = 'click4', modifier = 'alt', showHotkeys = false },
    { id = 'click4_shift', label = 'Shift', keyPrefix = 'S', parent = 'click4', modifier = 'shift', showHotkeys = false },
};
local ROW_BY_ID         = {};
for _, row in ipairs(BUTTON_ROWS) do
    ROW_BY_ID[row.id] = row;
end
local JOB_ABBRS         = T{
    [1]  = 'WAR',
    [2]  = 'MNK',
    [3]  = 'WHM',
    [4]  = 'BLM',
    [5]  = 'RDM',
    [6]  = 'THF',
    [7]  = 'PLD',
    [8]  = 'DRK',
    [9]  = 'BST',
    [10] = 'BRD',
    [11] = 'RNG',
    [12] = 'SAM',
    [13] = 'NIN',
    [14] = 'DRG',
    [15] = 'SMN',
    [16] = 'BLU',
    [17] = 'COR',
    [18] = 'PUP',
    [19] = 'DNC',
    [20] = 'SCH',
    [21] = 'GEO',
    [22] = 'RUN',
};

local ALLOWED_PREFIXES = T{
    ['/ma'] = true,
    ['/magic'] = true,
    ['/ja'] = true,
    ['/jobability'] = true,
    ['/pet'] = true,
    ['/ws'] = true,
    ['/weaponskill'] = true,
    ['/ra'] = true,
    ['/range'] = true,
    ['/shoot'] = true,
    ['/item'] = true,
    ['/mount'] = true,
    ['/dismount'] = true,
    ['/wait'] = true,
    ['/equip'] = true,
    ['/lac'] = true,
    ['/heal'] = true,
    ['/target'] = true,
    ['/targetnpc'] = true,
    ['/targetbnpc'] = true,
    ['/assist'] = true,
    ['/attack'] = true,
    ['/check'] = true,
    ['/map'] = true,
    ['/config'] = true,
    ['/trusts'] = true,
    ['/echo'] = true,
    ['/p'] = true,
    ['/party'] = true,
    ['/l'] = true,
    ['/linkshell'] = true,
    ['/s'] = true,
    ['/say'] = true,
    ['/tell'] = true,
};

local WHITE_MAGIC_HINTS = {
    'bar',
    'banish',
    'cure',
    'curaga',
    'deodorize',
    'dia',
    'erase',
    'invisible',
    'paralyna',
    'poisona',
    'protect',
    'raise',
    'regen',
    'reraise',
    'shell',
    'silena',
    'sneak',
};

local ROW_THEME = {
    base = { 0.92, 0.74, 0.32, 1.00 },
    ctrl = { 0.35, 0.70, 1.00, 1.00 },
    alt  = { 1.00, 0.55, 0.26, 1.00 },
    shift = { 0.72, 0.56, 1.00, 1.00 },
    click = { 0.55, 0.86, 0.64, 1.00 },
};

local LIMITS = {
    item_count_containers = { 0, 3 },
    item_count_cache_seconds = 0.40,
    slot_size_min = 40,
    slot_size_max = 96,
    button_count_min = 1,
    button_count_max = 20,
    buttons_per_row_min = 1,
    buttons_per_row_max = 20,
    button_gap_min = 0,
    button_gap_max = 24,
    slot_glow_size_min = 0,
    slot_glow_size_max = 200,
    slot_glow_opacity_min = 0,
    slot_glow_opacity_max = 100,
    weaponskill_effect_intensity_min = 0,
    weaponskill_effect_intensity_max = 100,
    weaponskill_effect_opacity_min = 0,
    weaponskill_effect_opacity_max = 100,
    weaponskill_effect_frequency_min = 25,
    weaponskill_effect_frequency_max = 200,
    label_vertical_position_min = 0,
    label_vertical_position_max = 100,
    macro_label_max = 32,
    macro_command_max = 256,
    macro_commands_text_max = 4096,
    macro_icon_max = 32,
    command_list_cache_seconds = 3.0,
    frameless_window_padding = 4,
};
local BAR = {};
function BAR.slot_index_label(index)
    return DIGIT_LABELS[index] or tostring(index);
end
local MACRO = {
    COMMANDS_TEXT_MAX = LIMITS.macro_commands_text_max,
};
local COMMAND_MODE = {};
local SHARED = {
    NAME_MAX = 48,
};
local UI_COLORS = {
    config_header = { 1.00, 0.70, 0.36, 1.00 },
    success = { 0.45, 1.00, 0.58, 1.00 },
    error = { 1.00, 0.36, 0.30, 1.00 },
    edit_handle = { 0.92, 0.72, 0.32, 0.92 },
    edit_handle_hover = { 1.00, 0.88, 0.48, 1.00 },
};

local THEMES = {
    ffxi = {
        window_bg = { 0.025, 0.022, 0.018, 0.72 },
        window_border = { 0.58, 0.44, 0.20, 0.88 },
        icon_border = { 1.00, 0.86, 0.54, 1.00 },
        icon_highlight = { 1.00, 1.00, 1.00, 1.00 },
        empty_bg = { 0.03, 0.03, 0.04, 0.82 },
        empty_line = { 0.36, 0.36, 0.40, 0.40 },
        empty_dim = { 0.22, 0.22, 0.25, 0.44 },
        empty_crystal = { 0.50, 0.48, 0.42, 1.00 },
        hotkey_bg = { 0.00, 0.00, 0.00, 1.00 },
        hotkey_dim_text = { 0.62, 0.62, 0.66, 0.88 },
        label_text = { 0.96, 0.93, 0.84, 1.00 },
        recast_overlay = { 0.00, 0.00, 0.00, 0.68 },
        recast_text = { 1.00, 0.96, 0.78, 1.00 },
        recast_line = { 1.00, 0.86, 0.54, 0.70 },
        count_bg = { 0.00, 0.00, 0.00, 0.78 },
        count_text = { 1.00, 0.97, 0.84, 1.00 },
        unavailable_overlay = { 0.00, 0.00, 0.00, 0.58 },
        unavailable_text = { 1.00, 0.42, 0.32, 1.00 },
        unavailable_line = { 1.00, 0.28, 0.18, 0.66 },
        text_shadow = { 0.00, 0.00, 0.00, 0.90 },
        unsupported = { 1.00, 0.24, 0.18, 1.00 },
        hover_border = { 1.00, 0.96, 0.72, 0.52 },
    },
    jeuno = {
        window_bg = { 0.020, 0.026, 0.034, 0.74 },
        window_border = { 0.45, 0.62, 0.76, 0.86 },
        icon_border = { 0.70, 0.86, 1.00, 1.00 },
        icon_highlight = { 1.00, 1.00, 1.00, 1.00 },
        empty_bg = { 0.025, 0.030, 0.040, 0.84 },
        empty_line = { 0.34, 0.42, 0.50, 0.40 },
        empty_dim = { 0.18, 0.24, 0.30, 0.46 },
        empty_crystal = { 0.38, 0.48, 0.56, 1.00 },
        hotkey_bg = { 0.00, 0.00, 0.00, 1.00 },
        hotkey_dim_text = { 0.60, 0.66, 0.72, 0.88 },
        label_text = { 0.88, 0.94, 1.00, 1.00 },
        recast_overlay = { 0.00, 0.00, 0.00, 0.68 },
        recast_text = { 0.90, 0.96, 1.00, 1.00 },
        recast_line = { 0.70, 0.86, 1.00, 0.70 },
        count_bg = { 0.00, 0.00, 0.00, 0.78 },
        count_text = { 0.92, 0.97, 1.00, 1.00 },
        unavailable_overlay = { 0.00, 0.00, 0.00, 0.58 },
        unavailable_text = { 1.00, 0.46, 0.36, 1.00 },
        unavailable_line = { 1.00, 0.30, 0.22, 0.66 },
        text_shadow = { 0.00, 0.00, 0.00, 0.90 },
        unsupported = { 1.00, 0.24, 0.18, 1.00 },
        hover_border = { 0.80, 0.94, 1.00, 0.54 },
    },
    sandoria = {
        window_bg = { 0.034, 0.018, 0.018, 0.74 },
        window_border = { 0.72, 0.42, 0.30, 0.88 },
        icon_border = { 1.00, 0.68, 0.48, 1.00 },
        icon_highlight = { 1.00, 1.00, 1.00, 1.00 },
        empty_bg = { 0.04, 0.025, 0.026, 0.84 },
        empty_line = { 0.48, 0.34, 0.34, 0.40 },
        empty_dim = { 0.28, 0.18, 0.18, 0.46 },
        empty_crystal = { 0.58, 0.42, 0.36, 1.00 },
        hotkey_bg = { 0.00, 0.00, 0.00, 1.00 },
        hotkey_dim_text = { 0.70, 0.60, 0.58, 0.88 },
        label_text = { 1.00, 0.90, 0.82, 1.00 },
        recast_overlay = { 0.00, 0.00, 0.00, 0.68 },
        recast_text = { 1.00, 0.90, 0.80, 1.00 },
        recast_line = { 1.00, 0.68, 0.48, 0.70 },
        count_bg = { 0.00, 0.00, 0.00, 0.78 },
        count_text = { 1.00, 0.92, 0.84, 1.00 },
        unavailable_overlay = { 0.00, 0.00, 0.00, 0.58 },
        unavailable_text = { 1.00, 0.48, 0.38, 1.00 },
        unavailable_line = { 1.00, 0.30, 0.20, 0.66 },
        text_shadow = { 0.00, 0.00, 0.00, 0.90 },
        unsupported = { 1.00, 0.24, 0.18, 1.00 },
        hover_border = { 1.00, 0.78, 0.58, 0.54 },
    },
};

local THEME_ALIASES = {
    default = 'ffxi',
    classic = 'ffxi',
    bastok = 'jeuno',
    dark = 'jeuno',
    sandy = 'sandoria',
    san_doria = 'sandoria',
};

local COMMAND_THEME = {
    empty       = { 0.14, 0.14, 0.16, 1.00 },
    white_magic = { 0.70, 0.94, 1.00, 1.00 },
    black_magic = { 0.60, 0.45, 0.92, 1.00 },
    ability     = { 1.00, 0.74, 0.30, 1.00 },
    weapon      = { 0.95, 0.38, 0.30, 1.00 },
    item        = { 0.48, 0.84, 0.48, 1.00 },
    mount       = { 0.95, 0.78, 0.36, 1.00 },
    server      = { 0.78, 0.96, 0.72, 1.00 },
    target      = { 0.58, 0.80, 0.98, 1.00 },
    chat        = { 0.82, 0.82, 0.88, 1.00 },
    command     = { 0.72, 0.66, 0.52, 1.00 },
};

local ICON_ALIASES = {
    cure = 'cure',
    curaga = 'cure',
    healing = 'cure',
    heal = 'rest',
    rest = 'rest',
    dia = 'holy',
    banish = 'holy',
    holy = 'holy',
    light = 'light',
    protect = 'buff',
    shell = 'buff',
    barspell = 'buff',
    buff = 'buff',
    signet = 'buff',
    sanction = 'buff',
    sigil = 'buff',
    ionis = 'buff',
    server = 'buff',
    status = 'status',
    cleanse = 'status',
    na = 'status',
    erase = 'status',
    debuff = 'debuff',
    enfeeble = 'debuff',
    paralyze = 'debuff',
    slow = 'debuff',
    blind = 'debuff',
    silence = 'debuff',
    sleep = 'debuff',
    poison = 'debuff',
    raise = 'raise',
    reraise = 'raise',
    sneak = 'stealth',
    invisible = 'stealth',
    invis = 'stealth',
    deodorize = 'stealth',
    stealth = 'stealth',
    white_magic = 'white_magic',
    black_magic = 'black_magic',
    nuke = 'black_magic',
    fire = 'fire',
    flame = 'fire',
    blizzard = 'ice',
    ice = 'ice',
    aero = 'wind',
    wind = 'wind',
    stone = 'earth',
    earth = 'earth',
    thunder = 'lightning',
    lightning = 'lightning',
    water = 'water',
    dark = 'dark',
    darkness = 'dark',
    ability = 'ability',
    ja = 'ability',
    song = 'song',
    bard = 'song',
    summon = 'summon',
    trust = 'summon',
    trusts = 'summon',
    fancytrusts = 'summon',
    avatar = 'summon',
    pet = 'pet',
    fight = 'fight',
    charm = 'charm',
    reward = 'reward',
    weapon = 'weapon',
    weaponskill = 'weapon',
    weapon_skill = 'weapon',
    ws = 'weapon',
    ranged = 'ranged',
    range = 'ranged',
    shoot = 'ranged',
    item = 'item',
    mount = 'mount',
    chocobo = 'mount',
    target = 'target',
    assist = 'assist',
    check = 'check',
    chat = 'chat',
    echo = 'test',
    test = 'test',
    command = 'command',
};

local ICON_DEFS = {
    cure        = { family = 'white_magic', mark = 'plus',    accent = { 0.82, 1.00, 0.96, 1.00 } },
    rest        = { family = 'item',        mark = 'text',    text = 'Z', accent = { 0.58, 0.90, 0.58, 1.00 } },
    holy        = { family = 'white_magic', mark = 'spark',   accent = { 1.00, 0.94, 0.52, 1.00 } },
    buff        = { family = 'white_magic', mark = 'shield',  accent = { 0.86, 0.92, 1.00, 1.00 } },
    status      = { family = 'white_magic', mark = 'diamond', accent = { 0.64, 1.00, 0.86, 1.00 } },
    raise       = { family = 'white_magic', mark = 'spark',   accent = { 0.95, 1.00, 0.88, 1.00 } },
    stealth     = { family = 'white_magic', mark = 'diamond', accent = { 0.74, 0.84, 1.00, 1.00 } },
    white_magic = { family = 'white_magic', mark = 'diamond', accent = { 0.70, 0.94, 1.00, 1.00 } },
    black_magic = { family = 'black_magic', mark = 'burst',   accent = { 0.78, 0.56, 1.00, 1.00 } },
    fire        = { family = 'black_magic', mark = 'flame',   accent = { 1.00, 0.38, 0.18, 1.00 } },
    ice         = { family = 'black_magic', mark = 'snow',    accent = { 0.70, 0.92, 1.00, 1.00 } },
    wind        = { family = 'black_magic', mark = 'wind',    accent = { 0.62, 1.00, 0.74, 1.00 } },
    earth       = { family = 'black_magic', mark = 'stone',   accent = { 0.82, 0.66, 0.38, 1.00 } },
    lightning   = { family = 'black_magic', mark = 'bolt',    accent = { 1.00, 0.88, 0.26, 1.00 } },
    water       = { family = 'black_magic', mark = 'wave',    accent = { 0.42, 0.80, 1.00, 1.00 } },
    light       = { family = 'white_magic', mark = 'ray',     accent = { 1.00, 0.96, 0.66, 1.00 } },
    dark        = { family = 'black_magic', mark = 'moon',    accent = { 0.62, 0.48, 0.90, 1.00 } },
    debuff      = { family = 'black_magic', mark = 'snare',   accent = { 0.86, 0.48, 1.00, 1.00 } },
    ability     = { family = 'ability',     mark = 'spark',   accent = { 1.00, 0.76, 0.32, 1.00 } },
    song        = { family = 'ability',     mark = 'note',    accent = { 1.00, 0.82, 0.46, 1.00 } },
    summon      = { family = 'ability',     mark = 'avatar',  accent = { 0.64, 0.92, 1.00, 1.00 } },
    pet         = { family = 'ability',     mark = 'paw',     accent = { 1.00, 0.70, 0.34, 1.00 } },
    fight       = { family = 'ability',     mark = 'claw',    accent = { 1.00, 0.58, 0.28, 1.00 } },
    charm       = { family = 'ability',     mark = 'heart',   accent = { 1.00, 0.50, 0.72, 1.00 } },
    reward      = { family = 'item',        mark = 'gift',    accent = { 0.76, 1.00, 0.58, 1.00 } },
    weapon      = { family = 'weapon',      mark = 'blade',   accent = { 1.00, 0.48, 0.36, 1.00 } },
    ranged      = { family = 'weapon',      mark = 'ranged',  accent = { 0.98, 0.64, 0.34, 1.00 } },
    item        = { family = 'item',        mark = 'bag',     accent = { 0.54, 0.94, 0.54, 1.00 } },
    mount       = { family = 'mount',       mark = 'text',    text = 'M', accent = { 1.00, 0.84, 0.38, 1.00 } },
    target      = { family = 'target',      mark = 'reticle', accent = { 0.62, 0.86, 1.00, 1.00 } },
    assist      = { family = 'target',      mark = 'arrow',   accent = { 0.62, 0.86, 1.00, 1.00 } },
    check       = { family = 'target',      mark = 'text',    text = '?', accent = { 0.76, 0.90, 1.00, 1.00 } },
    chat        = { family = 'chat',        mark = 'chat',    accent = { 0.90, 0.90, 0.98, 1.00 } },
    test        = { family = 'chat',        mark = 'text',    text = 'T', accent = { 0.88, 0.84, 0.72, 1.00 } },
    command     = { family = 'command',     mark = 'diamond', accent = { 0.76, 0.70, 0.54, 1.00 } },
    asset_crystal_compass = { family = 'white_magic', asset = 'crystal_compass.png', accent = { 0.56, 1.00, 0.92, 1.00 } },
    asset_aegis_shield    = { family = 'ability',     asset = 'aegis_shield.png',    accent = { 0.58, 0.82, 1.00, 1.00 } },
    asset_aether_orb      = { family = 'white_magic', asset = 'aether_orb.png',      accent = { 0.64, 1.00, 0.74, 1.00 } },
    asset_holy_ascent     = { family = 'white_magic', asset = 'holy_ascent.png',     accent = { 1.00, 0.92, 0.64, 1.00 } },
    asset_shadow_hood     = { family = 'black_magic', asset = 'shadow_hood.png',     accent = { 0.74, 0.54, 1.00, 1.00 } },
    asset_void_burst      = { family = 'black_magic', asset = 'void_burst.png',      accent = { 0.92, 0.36, 1.00, 1.00 } },
    asset_fire_flame      = { family = 'black_magic', asset = 'fire_flame.png',      accent = { 1.00, 0.42, 0.18, 1.00 } },
    asset_ice_crystal     = { family = 'black_magic', asset = 'ice_crystal.png',     accent = { 0.68, 0.92, 1.00, 1.00 } },
    asset_wind_gale       = { family = 'black_magic', asset = 'wind_gale.png',       accent = { 0.64, 1.00, 0.52, 1.00 } },
    asset_earth_rocks     = { family = 'black_magic', asset = 'earth_rocks.png',     accent = { 0.78, 0.62, 0.34, 1.00 } },
    asset_lightning_bolt  = { family = 'black_magic', asset = 'lightning_bolt.png',  accent = { 1.00, 0.84, 0.20, 1.00 } },
    asset_water_drop      = { family = 'black_magic', asset = 'water_drop.png',      accent = { 0.40, 0.82, 1.00, 1.00 } },
    asset_holy_star       = { family = 'white_magic', asset = 'holy_star.png',       accent = { 1.00, 0.92, 0.56, 1.00 } },
    asset_dark_vortex     = { family = 'black_magic', asset = 'dark_vortex.png',     accent = { 0.78, 0.42, 1.00, 1.00 } },
    asset_pink_crystal    = { family = 'black_magic', asset = 'pink_crystal.png',    accent = { 1.00, 0.42, 0.78, 1.00 } },
    asset_weapon_crest    = { family = 'weapon',      asset = 'weapon_crest.png',    accent = { 0.86, 0.86, 0.82, 1.00 } },
    asset_song_harp       = { family = 'ability',     asset = 'song_harp.png',       accent = { 1.00, 0.82, 0.46, 1.00 } },
    asset_summon_avatar   = { family = 'ability',     asset = 'summon_avatar.png',   accent = { 0.62, 0.84, 1.00, 1.00 } },
    asset_pet_paw         = { family = 'ability',     asset = 'pet_paw.png',         accent = { 0.98, 0.78, 0.42, 1.00 } },
    asset_weapon_swords   = { family = 'weapon',      asset = 'weapon_swords.png',   accent = { 1.00, 0.38, 0.28, 1.00 } },
    asset_ranged_bow      = { family = 'weapon',      asset = 'ranged_bow.png',      accent = { 1.00, 0.58, 0.28, 1.00 } },
    asset_item_bag        = { family = 'item',        asset = 'item_bag.png',        accent = { 0.78, 0.94, 0.52, 1.00 } },
    asset_mount_chocobo   = { family = 'mount',       asset = 'mount_chocobo.png',   accent = { 1.00, 0.82, 0.38, 1.00 } },
    asset_target_mark     = { family = 'target',      asset = 'target_mark.png',     accent = { 0.58, 0.84, 1.00, 1.00 } },
};

local ICON_ASSET_CATEGORIES = {
    { label = 'White Mage', family = 'white_magic', tokens = { 'whm_aquaveil', 'whm_banish', 'whm_banish_2', 'whm_banishga', 'whm_baraera', 'whm_barblindra', 'whm_barblizzara', 'whm_barfira', 'whm_barparalyzra', 'whm_barpoisonra', 'whm_barsilencera', 'whm_barsleepra', 'whm_barstonra', 'whm_barthundra', 'whm_barwatera', 'whm_blindna', 'whm_blink', 'whm_curaga', 'whm_cure', 'whm_cure_2', 'whm_cure_3', 'whm_cursna', 'whm_deodorize', 'whm_dia', 'whm_diaga', 'whm_invisible', 'whm_paralyna', 'whm_paralyze', 'whm_poisona', 'whm_protect', 'whm_protect_2', 'whm_protectra', 'whm_protectra_2', 'whm_raise', 'whm_regen', 'whm_reraise', 'whm_shell', 'whm_shellra', 'whm_silena', 'whm_silence', 'whm_slow', 'whm_sneak', 'whm_stoneskin' } },
    { label = 'Beastmaster', family = 'ability', tokens = { 'bst_bestial_loyalty', 'bst_call_beast', 'bst_charm', 'bst_familiar', 'bst_feral_howl', 'bst_fight', 'bst_gauge', 'bst_heel', 'bst_killer_instinct', 'bst_leave', 'bst_ready', 'bst_reward', 'bst_run_wild', 'bst_sic', 'bst_snarl', 'bst_spur', 'bst_stay', 'bst_tame', 'bst_unleash' } },
    { label = 'Cure', family = 'white_magic', tokens = { 'cure_1', 'cure_2', 'cure_3', 'cure_4' } },
    { label = 'Support', family = 'white_magic', tokens = { 'protect_1', 'protect_2', 'protect_3', 'protect_4', 'raise_1', 'raise_2', 'raise_3', 'raise_4', 'shell_1', 'shell_2', 'shell_3', 'shell_4', 'status_1', 'status_2', 'status_3', 'status_4', 'stealth_1', 'stealth_2', 'stealth_3', 'stealth_4', 'signet', 'sigil', 'sanction', 'ionis' } },
    { label = 'Enfeebling', family = 'black_magic', tokens = { 'debuff_1', 'debuff_2', 'debuff_3', 'debuff_4' } },
    { label = 'Elements', family = 'black_magic', tokens = { 'dark_1', 'dark_2', 'dark_3', 'dark_4', 'earth_1', 'earth_2', 'earth_3', 'earth_4', 'fire_1', 'fire_2', 'fire_3', 'fire_4', 'ice_1', 'ice_2', 'ice_3', 'ice_4', 'light_1', 'light_2', 'light_3', 'light_4', 'lightning_1', 'lightning_2', 'lightning_3', 'lightning_4', 'water_1', 'water_2', 'water_3', 'water_4', 'wind_1', 'wind_2', 'wind_3', 'wind_4' } },
    { label = 'Magic Art', family = 'black_magic', tokens = { 'aether_orb', 'crystal_compass', 'dark_vortex', 'earth_rocks', 'fire_flame', 'holy_ascent', 'holy_star', 'ice_crystal', 'lightning_bolt', 'pink_crystal', 'void_burst', 'water_drop', 'wind_gale' } },
    { label = 'Combat Art', family = 'weapon', tokens = { 'aegis_shield', 'pet_paw', 'ranged_bow', 'shadow_hood', 'summon_avatar', 'weapon_crest', 'weapon_swords' } },
    { label = 'Weapon Skills - Archery', family = 'weapon', tokens = { 'ws_archery_apex_arrow', 'ws_archery_arching_arrow', 'ws_archery_blast_arrow', 'ws_archery_dulling_arrow', 'ws_archery_empyreal_arrow', 'ws_archery_flaming_arrow', 'ws_archery_jishnus_radiance', 'ws_archery_namas_arrow', 'ws_archery_piercing_arrow', 'ws_archery_refulgent_arrow', 'ws_archery_sarv', 'ws_archery_sidewinder' } },
    { label = 'Weapon Skills - Automaton', family = 'weapon', tokens = { 'ws_automaton_arcuballista', 'ws_automaton_armor_piercer', 'ws_automaton_armor_shatterer', 'ws_automaton_bone_crusher', 'ws_automaton_cannibal_blade', 'ws_automaton_chimera_ripper', 'ws_automaton_daze', 'ws_automaton_knockout', 'ws_automaton_magic_mortar', 'ws_automaton_slapstick', 'ws_automaton_string_clipper', 'ws_automaton_string_shredder' } },
    { label = 'Weapon Skills - Axe', family = 'weapon', tokens = { 'ws_axe_avalanche_axe', 'ws_axe_blitz', 'ws_axe_bora_axe', 'ws_axe_calamity', 'ws_axe_cloudsplitter', 'ws_axe_decimation', 'ws_axe_gale_axe', 'ws_axe_mistral_axe', 'ws_axe_onslaught', 'ws_axe_primal_rend', 'ws_axe_raging_axe', 'ws_axe_rampage', 'ws_axe_ruinator', 'ws_axe_smash_axe', 'ws_axe_spinning_axe' } },
    { label = 'Weapon Skills - Club', family = 'weapon', tokens = { 'ws_club_black_halo', 'ws_club_brainshaker', 'ws_club_dagan', 'ws_club_dagda', 'ws_club_exudation', 'ws_club_flash_nova', 'ws_club_hexa_strike', 'ws_club_judgment', 'ws_club_moonlight', 'ws_club_mystic_boon', 'ws_club_randgrith', 'ws_club_realmrazer', 'ws_club_seraph_strike', 'ws_club_shining_strike', 'ws_club_skullbreaker', 'ws_club_starlight', 'ws_club_true_strike' } },
    { label = 'Weapon Skills - Dagger', family = 'weapon', tokens = { 'ws_dagger_aeolian_edge', 'ws_dagger_cyclone', 'ws_dagger_dancing_edge', 'ws_dagger_energy_drain', 'ws_dagger_energy_steal', 'ws_dagger_evisceration', 'ws_dagger_exenterator', 'ws_dagger_gust_slash', 'ws_dagger_mandalic_stab', 'ws_dagger_mercy_stroke', 'ws_dagger_mordant_rime', 'ws_dagger_pyrrhic_kleos', 'ws_dagger_rudras_storm', 'ws_dagger_ruthless_stroke', 'ws_dagger_shadowstitch', 'ws_dagger_shark_bite', 'ws_dagger_viper_bite', 'ws_dagger_wasp_sting' } },
    { label = 'Weapon Skills - Great Axe', family = 'weapon', tokens = { 'ws_great_axe_armor_break', 'ws_great_axe_disaster', 'ws_great_axe_fell_cleave', 'ws_great_axe_full_break', 'ws_great_axe_iron_tempest', 'ws_great_axe_keen_edge', 'ws_great_axe_kings_justice', 'ws_great_axe_metatron_torment', 'ws_great_axe_raging_rush', 'ws_great_axe_shield_break', 'ws_great_axe_steel_cyclone', 'ws_great_axe_sturmwind', 'ws_great_axe_ukkos_fury', 'ws_great_axe_upheaval', 'ws_great_axe_weapon_break' } },
    { label = 'Weapon Skills - Great Katana', family = 'weapon', tokens = { 'ws_great_katana_tachi_ageha', 'ws_great_katana_tachi_enpi', 'ws_great_katana_tachi_fudo', 'ws_great_katana_tachi_gekko', 'ws_great_katana_tachi_goten', 'ws_great_katana_tachi_hobaku', 'ws_great_katana_tachi_jinpu', 'ws_great_katana_tachi_kagero', 'ws_great_katana_tachi_kaiten', 'ws_great_katana_tachi_kasha', 'ws_great_katana_tachi_koki', 'ws_great_katana_tachi_mumei', 'ws_great_katana_tachi_rana', 'ws_great_katana_tachi_shoha', 'ws_great_katana_tachi_yukikaze' } },
    { label = 'Weapon Skills - Great Sword', family = 'weapon', tokens = { 'ws_great_sword_crescent_moon', 'ws_great_sword_dimidiation', 'ws_great_sword_fimbulvetr', 'ws_great_sword_freezebite', 'ws_great_sword_frostbite', 'ws_great_sword_ground_strike', 'ws_great_sword_hard_slash', 'ws_great_sword_herculean_slash', 'ws_great_sword_power_slash', 'ws_great_sword_resolution', 'ws_great_sword_scourge', 'ws_great_sword_shockwave', 'ws_great_sword_sickle_moon', 'ws_great_sword_spinning_slash', 'ws_great_sword_torcleaver' } },
    { label = 'Weapon Skills - Hand-to-Hand', family = 'weapon', tokens = { 'ws_hand_to_hand_ascetics_fury', 'ws_hand_to_hand_asuran_fists', 'ws_hand_to_hand_backhand_blow', 'ws_hand_to_hand_combo', 'ws_hand_to_hand_dragon_kick', 'ws_hand_to_hand_final_heaven', 'ws_hand_to_hand_howling_fist', 'ws_hand_to_hand_maru_kala', 'ws_hand_to_hand_one_inch_punch', 'ws_hand_to_hand_raging_fists', 'ws_hand_to_hand_shijin_spiral', 'ws_hand_to_hand_shoulder_tackle', 'ws_hand_to_hand_spinning_attack', 'ws_hand_to_hand_stringing_pummel', 'ws_hand_to_hand_tornado_kick', 'ws_hand_to_hand_victory_smite' } },
    { label = 'Weapon Skills - Katana', family = 'weapon', tokens = { 'ws_katana_blade_chi', 'ws_katana_blade_ei', 'ws_katana_blade_hi', 'ws_katana_blade_jin', 'ws_katana_blade_kamu', 'ws_katana_blade_ku', 'ws_katana_blade_metsu', 'ws_katana_blade_retsu', 'ws_katana_blade_rin', 'ws_katana_blade_shun', 'ws_katana_blade_teki', 'ws_katana_blade_ten', 'ws_katana_blade_to', 'ws_katana_blade_yu', 'ws_katana_zesho_meppo' } },
    { label = 'Weapon Skills - Marksmanship', family = 'weapon', tokens = { 'ws_marksmanship_blast_shot', 'ws_marksmanship_coronach', 'ws_marksmanship_detonator', 'ws_marksmanship_heavy_shot', 'ws_marksmanship_hot_shot', 'ws_marksmanship_last_stand', 'ws_marksmanship_leaden_salute', 'ws_marksmanship_numbing_shot', 'ws_marksmanship_slug_shot', 'ws_marksmanship_sniper_shot', 'ws_marksmanship_split_shot', 'ws_marksmanship_terminus', 'ws_marksmanship_trueflight', 'ws_marksmanship_wildfire' } },
    { label = 'Weapon Skills - Polearm', family = 'weapon', tokens = { 'ws_polearm_camlanns_torment', 'ws_polearm_diarmuid', 'ws_polearm_double_thrust', 'ws_polearm_drakesbane', 'ws_polearm_geirskogul', 'ws_polearm_impulse_drive', 'ws_polearm_leg_sweep', 'ws_polearm_penta_thrust', 'ws_polearm_raiden_thrust', 'ws_polearm_skewer', 'ws_polearm_sonic_thrust', 'ws_polearm_stardiver', 'ws_polearm_thunder_thrust', 'ws_polearm_vorpal_thrust', 'ws_polearm_wheeling_thrust' } },
    { label = 'Weapon Skills - Scythe', family = 'weapon', tokens = { 'ws_scythe_catastrophe', 'ws_scythe_cross_reaper', 'ws_scythe_dark_harvest', 'ws_scythe_entropy', 'ws_scythe_guillotine', 'ws_scythe_infernal_scythe', 'ws_scythe_insurgency', 'ws_scythe_nightmare_scythe', 'ws_scythe_origin', 'ws_scythe_quietus', 'ws_scythe_shadow_of_death', 'ws_scythe_slice', 'ws_scythe_spinning_scythe', 'ws_scythe_spiral_hell', 'ws_scythe_vorpal_scythe' } },
    { label = 'Weapon Skills - Staff', family = 'weapon', tokens = { 'ws_staff_cataclysm', 'ws_staff_earth_crusher', 'ws_staff_full_swing', 'ws_staff_garland_of_bliss', 'ws_staff_gate_of_tartarus', 'ws_staff_heavy_swing', 'ws_staff_myrkr', 'ws_staff_omniscience', 'ws_staff_oshala', 'ws_staff_retribution', 'ws_staff_rock_crusher', 'ws_staff_shattersoul', 'ws_staff_shell_crusher', 'ws_staff_spirit_taker', 'ws_staff_starburst', 'ws_staff_sunburst', 'ws_staff_vidohunir' } },
    { label = 'Weapon Skills - Sword', family = 'weapon', tokens = { 'ws_sword_atonement', 'ws_sword_burning_blade', 'ws_sword_chant_du_cygne', 'ws_sword_circle_blade', 'ws_sword_death_blossom', 'ws_sword_expiacion', 'ws_sword_fast_blade', 'ws_sword_flat_blade', 'ws_sword_imperator', 'ws_sword_knights_of_round', 'ws_sword_red_lotus_blade', 'ws_sword_requiescat', 'ws_sword_sanguine_blade', 'ws_sword_savage_blade', 'ws_sword_seraph_blade', 'ws_sword_shining_blade', 'ws_sword_spirits_within', 'ws_sword_swift_blade', 'ws_sword_vorpal_blade' } },
    { label = 'Utility Art', family = 'item', tokens = { 'item_bag', 'maps', 'mount_chocobo', 'raptor_mount', 'song_harp', 'target_mark', 'warp_ring', 'moogle' } },
};

local function register_icon_asset(token, family)
    if (type(token) ~= 'string' or token == '') then
        return;
    end

    local def = {
        family = family or 'command',
        asset = token .. '.png',
        accent = COMMAND_THEME[family or 'command'] or COMMAND_THEME.command,
    };

    ICON_DEFS[token] = def;
    ICON_DEFS['asset_' .. token] = ICON_DEFS['asset_' .. token] or def;
end

for _, category in ipairs(ICON_ASSET_CATEGORIES) do
    for _, token in ipairs(category.tokens) do
        register_icon_asset(token, category.family);
    end
end

local ICON_TOKEN_ASSET_OVERRIDES = {
    cure = 'whm_cure',
    curaga = 'whm_curaga',
    rest = 'item_bag',
    holy = 'holy_star',
    buff = 'protect_1',
    signet = 'signet',
    sigil = 'sigil',
    sanction = 'sanction',
    ionis = 'ionis',
    server = 'signet',
    status = 'status_1',
    raise = 'whm_raise',
    stealth = 'whm_sneak',
    white_magic = 'whm_cure',
    black_magic = 'void_burst',
    fire = 'fire_1',
    ice = 'ice_1',
    wind = 'wind_1',
    earth = 'earth_1',
    lightning = 'lightning_1',
    water = 'water_1',
    light = 'light_1',
    dark = 'dark_1',
    debuff = 'debuff_1',
    ability = 'aegis_shield',
    song = 'song_harp',
    summon = 'summon_avatar',
    pet = 'pet_paw',
    fight = 'bst_fight',
    charm = 'bst_charm',
    reward = 'bst_reward',
    weapon = 'weapon_swords',
    ranged = 'ranged_bow',
    item = 'item_bag',
    mount = 'mount_chocobo',
    raptor = 'raptor_mount',
    map = 'maps',
    target = 'target_mark',
    assist = 'target_mark',
    check = 'target_mark',
    chat = 'crystal_compass',
    test = 'crystal_compass',
    command = 'crystal_compass',
};

for token, asset_token in pairs(ICON_TOKEN_ASSET_OVERRIDES) do
    if (ICON_DEFS[asset_token] ~= nil) then
        ICON_DEFS[token] = ICON_DEFS[asset_token];
    end
end

local ICON_SELECTOR_CATEGORIES = ICON_ASSET_CATEGORIES;

MACRO.ICON_PICKER_FAMILY_FILTERS = {
    { key = 'all', label = 'All Types' },
    { key = 'white_magic', label = 'White Magic' },
    { key = 'black_magic', label = 'Black Magic' },
    { key = 'ability', label = 'Ability' },
    { key = 'weapon', label = 'Weapon' },
    { key = 'item', label = 'Item' },
    { key = 'mount', label = 'Mount' },
    { key = 'target', label = 'Target' },
    { key = 'chat', label = 'Chat' },
    { key = 'command', label = 'Command' },
};

local KEYBIND = {
    BAR_KEYS = { 'main', 'extra1', 'extra2', 'extra3', 'extra4' },
    EXTRA_ROWS = { CLICK_ROW },
    MODIFIER_ROWS = { 'ctrl', 'alt', 'shift' },
    MODIFIER_PREFIXES = {
        ctrl = 'Ctrl',
        alt = 'Alt',
        shift = 'Shift',
    },
    EVENT_LABELS = {
        [0x09] = 'Tab',
        [0x0D] = 'Enter',
        [0x20] = 'Space',
        [0x21] = 'PageUp',
        [0x22] = 'PageDown',
        [0x23] = 'End',
        [0x24] = 'Home',
        [0x25] = 'Left',
        [0x26] = 'Up',
        [0x27] = 'Right',
        [0x28] = 'Down',
        [0x2D] = 'Insert',
        [0x2E] = 'Delete',
        [0xC0] = '`',
    },
    KEY_ALIASES = {
        ['`'] = '`',
        ['~'] = '`',
        backspace = 'Backspace',
        backtick = '`',
        bksp = 'Backspace',
        del = 'Delete',
        delete = 'Delete',
        down = 'Down',
        ['end'] = 'End',
        endkey = 'End',
        enter = 'Enter',
        escape = 'Escape',
        esc = 'Escape',
        grave = '`',
        graveaccent = '`',
        home = 'Home',
        insert = 'Insert',
        ins = 'Insert',
        left = 'Left',
        pagedown = 'PageDown',
        pageup = 'PageUp',
        pgdn = 'PageDown',
        pgup = 'PageUp',
        ['return'] = 'Enter',
        returnkey = 'Enter',
        right = 'Right',
        space = 'Space',
        spacebar = 'Space',
        tab = 'Tab',
        up = 'Up',
    },
};

local DEFAULT_CONFIG = {
    settings = {
        visible = true,
        display_mode = 'single',
        theme = 'ffxi',
        show_hotkeys = true,
        show_labels = true,
        show_recasts = true,
        show_counts = true,
        show_availability = true,
        show_weaponskill_pulse = true,
        weaponskill_tp_threshold = 1000,
        icon_style = 'auto',
        bars_unlocked = false,
        slot_size = 64,
        button_gap = 6,
        slot_glow_size = 100,
        slot_glow_opacity = 100,
        label_vertical_position = 100,
        show_click_bar = true,
        row_gap = 6,
        window_x = 820,
        window_y = 760,
        click_bar_window_x = 820,
        click_bar_window_y = 680,
        block_native_macro_modifiers = true,
        main_bar = {
            visible = true,
            display_mode = 'single',
            profile_scope = 'job',
            button_count = 10,
            buttons_per_row = 10,
            keybinds = {
                base = { [1] = '1', [2] = '2', [3] = '3', [4] = '4', [5] = '5', [6] = '6', [7] = '7', [8] = '8', [9] = '9', [10] = '0' },
            },
            slot_size = 64,
            button_gap = 6,
            slot_glow_size = 100,
            slot_glow_opacity = 100,
            label_vertical_position = 100,
            window_x = 820,
            window_y = 760,
        },
        extra_bar_1 = {
            visible = true,
            profile_scope = 'job',
            button_count = 10,
            buttons_per_row = 10,
            keybinds = {
                click = {},
            },
            slot_size = 64,
            button_gap = 6,
            slot_glow_size = 100,
            slot_glow_opacity = 100,
            label_vertical_position = 100,
            window_x = 820,
            window_y = 680,
        },
        extra_bar_2 = {
            visible = false,
            profile_scope = 'job',
            button_count = 10,
            buttons_per_row = 10,
            keybinds = {
                click2 = {},
            },
            slot_size = 64,
            button_gap = 6,
            slot_glow_size = 100,
            slot_glow_opacity = 100,
            label_vertical_position = 100,
            window_x = 820,
            window_y = 600,
        },
        extra_bar_3 = {
            visible = false,
            profile_scope = 'job',
            button_count = 10,
            buttons_per_row = 10,
            keybinds = {
                click3 = {},
            },
            slot_size = 64,
            button_gap = 6,
            slot_glow_size = 100,
            slot_glow_opacity = 100,
            label_vertical_position = 100,
            window_x = 820,
            window_y = 520,
        },
        extra_bar_4 = {
            visible = false,
            profile_scope = 'job',
            button_count = 10,
            buttons_per_row = 10,
            keybinds = {
                click4 = {},
            },
            slot_size = 64,
            button_gap = 6,
            slot_glow_size = 100,
            slot_glow_opacity = 100,
            label_vertical_position = 100,
            window_x = 820,
            window_y = 440,
        },
    },
    profiles = {
        DEFAULT = {
            base = {},
            ctrl = {},
            alt = {},
            shift = {},
            click = {},
            click2 = {},
            click3 = {},
            click4 = {},
        },
    },
    bars = {
        base = {},
        ctrl = {},
        alt = {},
        shift = {},
        click = {},
        click2 = {},
        click3 = {},
        click4 = {},
    },
};

local state = {
    config = DEFAULT_CONFIG,
    macro_overrides = { profiles = {}, shared = {} },
    visible = T{ true },
    config_visible = T{ false },
    bar_frames_visible = false,
    config_save_message = nil,
    config_save_message_color = UI_COLORS.success,
    config_error = nil,
    profile = nil,
    display_mode_override = nil,
    slot_size_override = nil,
    button_gap_override = nil,
    slot_glow_size_override = nil,
    slot_glow_opacity_override = nil,
    label_vertical_position_override = nil,
    keybind_overrides = {},
    keybind_capture = nil,
    keybind_message = nil,
    keybind_message_color = UI_COLORS.success,
    main_bar_profile_scope_override = nil,
    main_bar_visible_override = nil,
    main_bar_button_count_override = nil,
    main_bar_buttons_per_row_override = nil,
    bar_window_x = nil,
    bar_window_y = nil,
    bar_anchor_x = nil,
    bar_anchor_y = nil,
    bar_anchor_lock_x = nil,
    bar_anchor_lock_y = nil,
    bar_frame_offset_x = nil,
    bar_frame_offset_y = nil,
    bar_hidden_offset_x = LIMITS.frameless_window_padding,
    bar_hidden_offset_y = LIMITS.frameless_window_padding,
    click_bar_open = T{ true },
    click_bar_profile_scope_override = nil,
    click_bar_visible_override = nil,
    click_bar_button_count_override = nil,
    click_bar_buttons_per_row_override = nil,
    click_bar_slot_size_override = nil,
    click_bar_button_gap_override = nil,
    click_bar_slot_glow_size_override = nil,
    click_bar_slot_glow_opacity_override = nil,
    click_bar_label_vertical_position_override = nil,
    click_bar_window_x = nil,
    click_bar_window_y = nil,
    click_bar_anchor_x = nil,
    click_bar_anchor_y = nil,
    click_bar_anchor_lock_x = nil,
    click_bar_anchor_lock_y = nil,
    click_bar_frame_offset_x = nil,
    click_bar_frame_offset_y = nil,
    click_bar_hidden_offset_x = LIMITS.frameless_window_padding,
    click_bar_hidden_offset_y = LIMITS.frameless_window_padding,
    extra_bar_runtime = {},
    extra_bar_overrides = {},
    recast_cache = {},
    recast_totals = {},
    mount_recast_overlay = nil,
    macro_runs = {},
    item_source_cache = {},
    item_count_cache = {},
    item_texture_cache = {},
    item_texture_handles = {},
    icon_asset_texture_cache = {},
    icon_asset_texture_handles = {},
    command_mode_cache = {},
    macro_editor = {
        visible = T{ false },
        bar_key = nil,
        parent_group = nil,
        profile_key = nil,
        group = nil,
        index = nil,
        source = nil,
        shared_ref = nil,
        modifier_ctrl_enabled = T{ false },
        modifier_alt_enabled = T{ false },
        modifier_shift_enabled = T{ false },
        macro_mode = 'single',
        shared_name_buffer = T{ '' },
        label_buffer = T{ '' },
        command_buffer = T{ '' },
        commands_buffer = T{ '' },
        run_as_script = T{ false },
        icon_buffer = T{ '' },
        icon_picker_visible = T{ false },
        icon_picker_search_buffer = T{ '' },
        icon_picker_category_filter = 'all',
        icon_picker_family_filter = 'all',
        icon_picker_anchor_x = nil,
        icon_picker_anchor_y = nil,
        command_action = '',
        command_target = '<t>',
        target_action = '/target',
        use_action_name_label = T{ true },
        weaponskill_effect_enabled = T{ true },
        weaponskill_effect = 'pulse',
        weaponskill_effect_intensity = T{ 70 },
        weaponskill_effect_opacity = T{ 100 },
        weaponskill_effect_frequency = T{ 100 },
        spell_type_filter = 'all',
        spell_element_filter = 'all',
        spell_search_buffer = T{ '' },
        item_source_filter = 'all',
        item_search_buffer = T{ '' },
        weaponskill_search_buffer = T{ '' },
        ability_search_buffer = T{ '' },
        pet_search_buffer = T{ '' },
        mount_search_buffer = T{ '' },
        server_search_buffer = T{ '' },
        trusts_search_buffer = T{ '' },
        config_key_buffer = T{ '' },
        config_value_a_buffer = T{ '0' },
        config_value_b_buffer = T{ '1' },
        message = nil,
        message_color = UI_COLORS.success,
    },
    macro_clipboard = nil,
};

local ICON_ART_STYLE = {};

local function log_info(message)
    print(chat.header(addon.name):append(chat.message(message)));
end

local function log_warn(message)
    print(chat.header(addon.name):append(chat.warning(message)));
end

local function safe_read(callback, fallback)
    local ok, result = pcall(callback);
    if (not ok) then
        return fallback;
    end

    return result;
end

local function trim_string(value)
    if (type(value) ~= 'string') then
        return '';
    end

    return value:gsub('^%s+', ''):gsub('%s+$', '');
end

local function trim_one_line(value, max_length)
    local text = trim_string(value):gsub('[\r\n]+', ' ');
    max_length = tonumber(max_length) or #text;
    if (#text > max_length) then
        text = text:sub(1, max_length);
    end

    return text;
end

local function buffer_set(buffer, value)
    buffer[1] = value or '';
end

local function valid_row_id(value)
    return type(value) == 'string' and ROW_BY_ID[value] ~= nil;
end

function MACRO.normalize_mode(value)
    if (type(value) ~= 'string') then
        return 'single';
    end

    local mode = value:lower():gsub('%s+', ''):gsub('_', '-');
    if (mode == 'single' or mode == 'command' or mode == 'freeform' or mode == 'free-form') then
        return 'single';
    end
    if (mode == 'multi' or mode == 'multiline' or mode == 'multi-line' or mode == 'macro') then
        return 'multi';
    end
    if (mode == 'spell' or mode == 'magic' or mode == 'ma') then
        return 'spell';
    end
    if (mode == 'item') then
        return 'item';
    end
    if (mode == 'mount') then
        return 'mount';
    end
    if (mode == 'server' or mode == 'servercommand' or mode == 'server-command' or mode == 'catseye' or mode == 'catseyecommand' or mode == 'catseye-command' or mode == 'bang') then
        return 'server';
    end
    if (mode == 'configtoggle' or mode == 'config-toggle' or mode == 'toggleconfig' or mode == 'toggle-config' or mode == 'config') then
        return 'configtoggle';
    end
    if (mode == 'trusts' or mode == 'trust' or mode == 'trustaddon' or mode == 'trust-addon' or mode == 'fancytrusts' or mode == 'fancy-trusts') then
        return 'trusts';
    end
    if (mode == 'weaponskill' or mode == 'weapon-skill' or mode == 'ws') then
        return 'weaponskill';
    end
    if (mode == 'ability' or mode == 'jobability' or mode == 'job-ability' or mode == 'ja') then
        return 'ability';
    end
    if (mode == 'pet' or mode == 'petcommand' or mode == 'pet-command' or mode == 'petcommands' or mode == 'pet-commands') then
        return 'pet';
    end
    if (mode == 'ranged' or mode == 'rangedattack' or mode == 'ranged-attack' or mode == 'ra' or mode == 'shoot') then
        return 'ranged';
    end
    if (mode == 'target' or mode == 'targeting' or mode == 'assist') then
        return 'target';
    end

    return 'single';
end

function MACRO.normalize_line_endings(value)
    if (type(value) ~= 'string') then
        return '';
    end

    return value:gsub('\r\n', '\n'):gsub('\r', '\n');
end

function MACRO.sanitize_command_line(value)
    return trim_one_line(value, LIMITS.macro_command_max);
end

function MACRO.commands_from_text(value)
    local commands = {};
    local text = MACRO.normalize_line_endings(value);

    if (text == '') then
        return commands, false;
    end

    if (text:sub(-1) ~= '\n') then
        text = text .. '\n';
    end

    for line in text:gmatch('([^\n]*)\n') do
        local command = MACRO.sanitize_command_line(line);
        if (command ~= '') then
            table.insert(commands, command);
        end
    end

    return commands, false;
end

function MACRO.commands_from_table(value)
    local commands = {};

    if (type(value) ~= 'table') then
        return commands;
    end

    for _, line in ipairs(value) do
        local command = MACRO.sanitize_command_line(line);
        if (command ~= '') then
            table.insert(commands, command);
        end
    end

    return commands;
end

function MACRO.commands_to_text(commands)
    if (type(commands) ~= 'table' or #commands == 0) then
        return '';
    end

    return table.concat(commands, '\n');
end

function MACRO.script_enabled(slot)
    return type(slot) == 'table' and MACRO.slot_mode(slot) == 'multi' and slot.script == true;
end

local DEFERRED = {};

local function normalize_profile_key(value)
    if (type(value) ~= 'string') then
        return nil;
    end

    local key = value:upper():gsub('%s+', '');
    if (key == '') then
        return nil;
    end

    return key;
end

local function current_main_job_id()
    local job_id = safe_read(function ()
        return AshitaCore:GetMemoryManager():GetPlayer():GetMainJob();
    end, nil);

    if (type(job_id) ~= 'number' or job_id <= 0) then
        return nil;
    end

    return job_id;
end

function BAR.current_sub_job_id()
    local job_id = safe_read(function ()
        return AshitaCore:GetMemoryManager():GetPlayer():GetSubJob();
    end, nil);

    if (type(job_id) ~= 'number' or job_id <= 0) then
        return nil;
    end

    return job_id;
end

local function job_abbr(job_id)
    if (type(job_id) ~= 'number' or job_id <= 0) then
        return nil;
    end

    local resource_abbr = safe_read(function ()
        return AshitaCore:GetResourceManager():GetString('jobs.names_abbr', job_id);
    end, nil);

    if (type(resource_abbr) == 'string' and resource_abbr ~= '') then
        return resource_abbr:upper();
    end

    return JOB_ABBRS[job_id];
end

local function get_profile_by_key(profiles, key)
    local normalized = normalize_profile_key(key);
    if (type(profiles) ~= 'table' or normalized == nil) then
        return nil, nil;
    end

    if (type(profiles[normalized]) == 'table') then
        return profiles[normalized], normalized;
    end

    for profile_key, profile in pairs(profiles) do
        if (type(profile) == 'table' and normalize_profile_key(profile_key) == normalized) then
            return profile, tostring(profile_key);
        end
    end

    return nil, nil;
end

function BAR.normalize_profile_scope(value)
    if (type(value) ~= 'string') then
        return nil;
    end

    local scope = value:lower():gsub('%s+', ''):gsub('-', '_');
    if (scope == 'global' or scope == 'all' or scope == 'default') then
        return 'global';
    end
    if (scope == 'job' or scope == 'main' or scope == 'mainjob' or scope == 'main_job') then
        return 'job';
    end
    if (scope == 'job_sub' or scope == 'jobsub' or scope == 'main_sub' or scope == 'mainsub' or scope == 'mainjob_subjob' or scope == 'main_job_sub_job' or scope == 'subjob' or scope == 'job+sub') then
        return 'job_sub';
    end

    return nil;
end

function BAR.profile_scope(bar_key)
    bar_key = bar_key or BAR.current_key();
    local override = BAR.override(bar_key, 'profile_scope');
    local scope = BAR.normalize_profile_scope(override);
    if (scope ~= nil) then
        return scope, 'runtime';
    end

    local raw, source = BAR.raw_setting(bar_key, 'profile_scope');
    scope = BAR.normalize_profile_scope(raw);
    if (scope ~= nil) then
        return scope, source;
    end

    return 'job', 'default';
end

function BAR.profile_scope_label(scope)
    scope = BAR.normalize_profile_scope(scope) or 'job';
    if (scope == 'global') then return 'Global'; end
    if (scope == 'job_sub') then return 'Main + Subjob'; end
    return 'Main Job';
end

function BAR.profile_edit_key(scope, main_key, sub_key)
    scope = BAR.normalize_profile_scope(scope) or 'job';
    if (scope == 'global') then
        return 'DEFAULT';
    end
    if (scope == 'job_sub' and main_key ~= nil and sub_key ~= nil) then
        return normalize_profile_key(('%s_%s'):fmt(main_key, sub_key));
    end
    if (main_key ~= nil) then
        return normalize_profile_key(main_key);
    end

    return 'DEFAULT';
end

function BAR.profile_candidates(scope, main_key, sub_key)
    scope = BAR.normalize_profile_scope(scope) or 'job';
    local candidates = {};
    local seen = {};
    local function add(key, source)
        local normalized = normalize_profile_key(key);
        if (normalized ~= nil and seen[normalized] ~= true) then
            seen[normalized] = true;
            table.insert(candidates, { key = normalized, source = source });
        end
    end

    if (scope == 'global') then
        add('DEFAULT', 'global');
        return candidates;
    end

    if (scope == 'job_sub' and main_key ~= nil and sub_key ~= nil) then
        add(('%s_%s'):fmt(main_key, sub_key), 'job+sub');
        add(('%s/%s'):fmt(main_key, sub_key), 'job+sub');
        add(('%s-%s'):fmt(main_key, sub_key), 'job+sub');
        add(('%s+%s'):fmt(main_key, sub_key), 'job+sub');
        add(('%s%s'):fmt(main_key, sub_key), 'job+sub');
    end

    if (main_key ~= nil) then
        add(main_key, 'job');
    end
    add('DEFAULT', 'default');
    return candidates;
end

function BAR.group_modifier(group)
    local row = ROW_BY_ID[group];
    return row ~= nil and row.modifier or nil;
end

function BAR.parent_group(group)
    local row = ROW_BY_ID[group];
    if (row ~= nil and row.parent ~= nil) then
        return row.parent;
    end

    return group;
end

function BAR.modifier_row_id(parent_group, modifier)
    if (modifier ~= 'ctrl' and modifier ~= 'alt' and modifier ~= 'shift') then
        return nil;
    end

    if (parent_group == 'base') then
        return modifier;
    end

    local row_id = tostring(parent_group or '') .. '_' .. modifier;
    return ROW_BY_ID[row_id] ~= nil and row_id or nil;
end

function BAR.row_supports_modifiers(group)
    return BAR.modifier_row_id(group, 'ctrl') ~= nil;
end

function BAR.key_for_group(group)
    local parent_group = BAR.parent_group(group);
    for _, bar_key in ipairs(BAR.EXTRA_KEYS) do
        if (BAR.extra_row_id(bar_key) == parent_group) then
            return bar_key;
        end
    end

    return 'main';
end

function BAR.extra_runtime(bar_key)
    if (type(state.extra_bar_runtime) ~= 'table') then
        state.extra_bar_runtime = {};
    end
    if (type(state.extra_bar_runtime[bar_key]) ~= 'table') then
        state.extra_bar_runtime[bar_key] = {
            open = T{ true },
            window_x = nil,
            window_y = nil,
            anchor_x = nil,
            anchor_y = nil,
            anchor_lock_x = nil,
            anchor_lock_y = nil,
            frame_offset_x = nil,
            frame_offset_y = nil,
            hidden_offset_x = LIMITS.frameless_window_padding,
            hidden_offset_y = LIMITS.frameless_window_padding,
            measured_anchor_x = nil,
            measured_anchor_y = nil,
        };
    end

    return state.extra_bar_runtime[bar_key];
end

function BAR.reset_extra_runtime(bar_key)
    if (not BAR.is_extra_bar(bar_key)) then
        return;
    end

    local runtime = BAR.extra_runtime(bar_key);
    local settings = state.config.settings or {};
    local values = type(settings[BAR.SETTINGS_KEY[bar_key]]) == 'table' and settings[BAR.SETTINGS_KEY[bar_key]] or {};
    local default_values = DEFAULT_CONFIG.settings[BAR.SETTINGS_KEY[bar_key]] or {};
    local legacy_x = (bar_key == 'extra1') and tonumber(settings.click_bar_window_x) or nil;
    local legacy_y = (bar_key == 'extra1') and tonumber(settings.click_bar_window_y) or nil;
    runtime.open[1] = true;
    runtime.window_x = tonumber(values.window_x) or legacy_x or tonumber(default_values.window_x) or DEFAULT_CONFIG.settings.click_bar_window_x;
    runtime.window_y = tonumber(values.window_y) or legacy_y or tonumber(default_values.window_y) or DEFAULT_CONFIG.settings.click_bar_window_y;
    runtime.anchor_x = runtime.window_x;
    runtime.anchor_y = runtime.window_y;
    runtime.anchor_lock_x = nil;
    runtime.anchor_lock_y = nil;
    runtime.frame_offset_x = nil;
    runtime.frame_offset_y = nil;
    runtime.hidden_offset_x = LIMITS.frameless_window_padding;
    runtime.hidden_offset_y = LIMITS.frameless_window_padding;
    runtime.measured_anchor_x = nil;
    runtime.measured_anchor_y = nil;
end

function BAR.reset_all_extra_runtime()
    for _, bar_key in ipairs(BAR.EXTRA_KEYS) do
        BAR.reset_extra_runtime(bar_key);
    end
end

local function refresh_profile_context(bar_key)
    bar_key = bar_key or BAR.current_key();
    local config = state.config or DEFAULT_CONFIG;
    local profiles = config.profiles;
    local legacy_bars = config.bars;
    local job_id = current_main_job_id();
    local subjob_id = BAR.current_sub_job_id();
    local job_key = job_abbr(job_id);
    local subjob_key = job_abbr(subjob_id);
    local scope, scope_source = BAR.profile_scope(bar_key);
    local edit_key = BAR.profile_edit_key(scope, job_key, subjob_key);
    local bars = nil;
    local profile_key = nil;
    local base_key = nil;
    local source = 'built-in';

    for _, candidate in ipairs(BAR.profile_candidates(scope, job_key, subjob_key)) do
        bars, profile_key = get_profile_by_key(profiles, candidate.key);
        if (bars ~= nil) then
            base_key = profile_key;
            source = candidate.source;
            break;
        end
    end

    if (bars == nil and type(legacy_bars) == 'table') then
        bars = legacy_bars;
        base_key = 'bars';
        source = 'legacy';
    end

    if (bars == nil) then
        bars = DEFAULT_CONFIG.profiles.DEFAULT;
        base_key = 'DEFAULT';
    end

    state.profile = {
        bar_key = bar_key,
        bars = bars,
        key = edit_key or base_key or 'DEFAULT',
        edit_key = edit_key or base_key or 'DEFAULT',
        base_key = base_key or 'DEFAULT',
        job_id = job_id,
        subjob_id = subjob_id,
        job_key = job_key,
        subjob_key = subjob_key,
        scope = scope,
        scope_source = scope_source,
        source = source,
    };

    return state.profile;
end

local function load_config()
    package.loaded.ashitabars_config = nil;

    local ok, config = pcall(require, 'ashitabars_config');
    if (not ok or type(config) ~= 'table') then
        state.config_error = tostring(config);
        state.config = DEFAULT_CONFIG;
        if (DEFERRED.load_visual_settings ~= nil) then
            DEFERRED.load_visual_settings();
        end
        state.visible[1] = true;
        state.profile = nil;
        state.display_mode_override = nil;
        state.slot_size_override = nil;
        state.button_gap_override = nil;
        state.slot_glow_size_override = nil;
        state.slot_glow_opacity_override = nil;
        state.label_vertical_position_override = nil;
        state.keybind_overrides = {};
        state.keybind_capture = nil;
        state.keybind_message = nil;
        state.main_bar_profile_scope_override = nil;
        state.main_bar_visible_override = nil;
        state.main_bar_button_count_override = nil;
        state.main_bar_buttons_per_row_override = nil;
        local main_bar_settings = type(state.config.settings.main_bar) == 'table' and state.config.settings.main_bar or {};
        local extra_bar_settings = type(state.config.settings.extra_bar_1) == 'table' and state.config.settings.extra_bar_1 or {};
        state.visible[1] = main_bar_settings.visible ~= false;
        state.bar_window_x = tonumber(main_bar_settings.window_x) or tonumber(state.config.settings.window_x) or DEFAULT_CONFIG.settings.window_x;
        state.bar_window_y = tonumber(main_bar_settings.window_y) or tonumber(state.config.settings.window_y) or DEFAULT_CONFIG.settings.window_y;
        state.bar_anchor_x = state.bar_window_x;
        state.bar_anchor_y = state.bar_window_y;
        state.bar_anchor_lock_x = nil;
        state.bar_anchor_lock_y = nil;
        state.bar_frame_offset_x = nil;
        state.bar_frame_offset_y = nil;
        state.bar_hidden_offset_x = LIMITS.frameless_window_padding;
        state.bar_hidden_offset_y = LIMITS.frameless_window_padding;
        state.click_bar_open[1] = true;
        state.click_bar_profile_scope_override = nil;
        state.click_bar_visible_override = nil;
        state.click_bar_button_count_override = nil;
        state.click_bar_buttons_per_row_override = nil;
        state.click_bar_slot_size_override = nil;
        state.click_bar_button_gap_override = nil;
        state.click_bar_slot_glow_size_override = nil;
        state.click_bar_slot_glow_opacity_override = nil;
        state.click_bar_label_vertical_position_override = nil;
        state.click_bar_window_x = tonumber(extra_bar_settings.window_x) or tonumber(state.config.settings.click_bar_window_x) or DEFAULT_CONFIG.settings.click_bar_window_x;
        state.click_bar_window_y = tonumber(extra_bar_settings.window_y) or tonumber(state.config.settings.click_bar_window_y) or DEFAULT_CONFIG.settings.click_bar_window_y;
        state.click_bar_anchor_x = state.click_bar_window_x;
        state.click_bar_anchor_y = state.click_bar_window_y;
        state.click_bar_anchor_lock_x = nil;
        state.click_bar_anchor_lock_y = nil;
        state.click_bar_frame_offset_x = nil;
        state.click_bar_frame_offset_y = nil;
        state.click_bar_hidden_offset_x = LIMITS.frameless_window_padding;
        state.click_bar_hidden_offset_y = LIMITS.frameless_window_padding;
        state.extra_bar_overrides = {};
        BAR.reset_all_extra_runtime();
        state.recast_cache = {};
        state.recast_totals = {};
        state.macro_runs = {};
        state.item_source_cache = {};
        state.item_count_cache = {};
        state.command_mode_cache = {};
        if (DEFERRED.load_button_overrides ~= nil) then
            DEFERRED.load_button_overrides();
        end
        return;
    end

    state.config_error = nil;
    state.config = config;
    if (type(state.config.settings) ~= 'table') then
        state.config.settings = DEFAULT_CONFIG.settings;
    end
    if (type(state.config.profiles) ~= 'table') then
        state.config.profiles = nil;
    end
    if (type(state.config.bars) ~= 'table') then
        state.config.bars = DEFAULT_CONFIG.bars;
    end

    if (DEFERRED.load_visual_settings ~= nil) then
        DEFERRED.load_visual_settings();
    end

    local main_bar_settings = type(state.config.settings.main_bar) == 'table' and state.config.settings.main_bar or {};
    local extra_bar_settings = type(state.config.settings.extra_bar_1) == 'table' and state.config.settings.extra_bar_1 or {};
    if (main_bar_settings.visible ~= nil) then
        state.visible[1] = main_bar_settings.visible ~= false;
    else
        state.visible[1] = (state.config.settings.visible ~= false);
    end
    state.profile = nil;
    state.display_mode_override = nil;
    state.slot_size_override = nil;
    state.button_gap_override = nil;
    state.slot_glow_size_override = nil;
    state.slot_glow_opacity_override = nil;
    state.label_vertical_position_override = nil;
    state.keybind_overrides = {};
    state.keybind_capture = nil;
    state.keybind_message = nil;
    state.main_bar_profile_scope_override = nil;
    state.main_bar_visible_override = nil;
    state.main_bar_button_count_override = nil;
    state.main_bar_buttons_per_row_override = nil;
    state.bar_window_x = tonumber(main_bar_settings.window_x) or tonumber(state.config.settings.window_x) or DEFAULT_CONFIG.settings.window_x;
    state.bar_window_y = tonumber(main_bar_settings.window_y) or tonumber(state.config.settings.window_y) or DEFAULT_CONFIG.settings.window_y;
    state.bar_anchor_x = state.bar_window_x;
    state.bar_anchor_y = state.bar_window_y;
    state.bar_anchor_lock_x = nil;
    state.bar_anchor_lock_y = nil;
    state.bar_frame_offset_x = nil;
    state.bar_frame_offset_y = nil;
    state.bar_hidden_offset_x = LIMITS.frameless_window_padding;
    state.bar_hidden_offset_y = LIMITS.frameless_window_padding;
    state.click_bar_open[1] = true;
    state.click_bar_profile_scope_override = nil;
    state.click_bar_visible_override = nil;
    state.click_bar_button_count_override = nil;
    state.click_bar_buttons_per_row_override = nil;
    state.click_bar_slot_size_override = nil;
    state.click_bar_button_gap_override = nil;
    state.click_bar_slot_glow_size_override = nil;
    state.click_bar_slot_glow_opacity_override = nil;
    state.click_bar_label_vertical_position_override = nil;
    state.click_bar_window_x = tonumber(extra_bar_settings.window_x) or tonumber(state.config.settings.click_bar_window_x) or DEFAULT_CONFIG.settings.click_bar_window_x;
    state.click_bar_window_y = tonumber(extra_bar_settings.window_y) or tonumber(state.config.settings.click_bar_window_y) or DEFAULT_CONFIG.settings.click_bar_window_y;
    state.click_bar_anchor_x = state.click_bar_window_x;
    state.click_bar_anchor_y = state.click_bar_window_y;
    state.click_bar_anchor_lock_x = nil;
    state.click_bar_anchor_lock_y = nil;
    state.click_bar_frame_offset_x = nil;
    state.click_bar_frame_offset_y = nil;
    state.click_bar_hidden_offset_x = LIMITS.frameless_window_padding;
    state.click_bar_hidden_offset_y = LIMITS.frameless_window_padding;
    state.extra_bar_overrides = {};
    BAR.reset_all_extra_runtime();
    state.recast_cache = {};
    state.recast_totals = {};
    state.macro_runs = {};
    state.item_source_cache = {};
    state.item_count_cache = {};
    state.command_mode_cache = {};
    if (DEFERRED.load_button_overrides ~= nil) then
        DEFERRED.load_button_overrides();
    end
end

local function key_down(vk)
    return ffi.C.GetKeyState(vk) < 0;
end

local function is_initial_keydown(e)
    local is_up = bit.band(e.lparam, KEY_UP_MASK) == KEY_UP_MASK;
    local was_down = bit.band(e.lparam, KEY_WAS_DOWN_MASK) == KEY_WAS_DOWN_MASK;
    return (not is_up) and (not was_down);
end

local function input_is_closed()
    return AshitaCore:GetChatManager():IsInputOpen() == 0x00;
end

local function directinput_digit_index(keyptr)
    if (keyptr == nil) then
        return nil;
    end

    for index, scancode in ipairs(DIK_DIGITS) do
        if (bit.band(keyptr[scancode], 0x80) ~= 0) then
            return index;
        end
    end

    return nil;
end

local function clear_directinput_modifier_state(e)
    local settings = state.config.settings or {};
    if (settings.block_native_macro_modifiers == false or not input_is_closed() or e.data_raw == nil) then
        return;
    end

    local ctrl = key_down(VK.CONTROL);
    local alt = key_down(VK.ALT);
    if (not ctrl and not alt) then
        return;
    end

    local keyptr = ffi.cast('uint8_t*', e.data_raw);
    local index = directinput_digit_index(keyptr);
    if (index == nil) then
        return;
    end

    local combo = KEYBIND.combo_from_parts(DIGIT_LABELS[index], ctrl, alt, key_down(VK.SHIFT));
    if (combo == nil or not KEYBIND.combo_bound(combo)) then
        return;
    end

    for _, scancode in ipairs(DIK_BLOCKED_MODIFIERS) do
        keyptr[scancode] = 0;
    end
end

local function active_group()
    local ctrl = key_down(VK.CONTROL);
    local alt = key_down(VK.ALT);
    local shift = key_down(VK.SHIFT);

    if (ctrl and not alt and not shift) then return 'ctrl'; end
    if (alt and not ctrl and not shift) then return 'alt'; end
    if (shift and not ctrl and not alt) then return 'shift'; end
    if (not ctrl and not alt and not shift) then return 'base'; end
    return nil;
end

local function normalize_display_mode(value)
    if (type(value) ~= 'string') then
        return nil;
    end

    local mode = value:lower():gsub('%s+', '');
    if (mode == 'single') then return 'single'; end

    return nil;
end

BAR.EXTRA_KEYS = { 'extra1', 'extra2', 'extra3', 'extra4' };
BAR.CONFIG_KEYS = { 'main', 'extra1', 'extra2', 'extra3', 'extra4' };
BAR.EXTRA_ROW_ID = {
    extra1 = 'click',
    extra2 = 'click2',
    extra3 = 'click3',
    extra4 = 'click4',
};
BAR.EXTRA_LABEL = {
    extra1 = 'Extra Bar 1',
    extra2 = 'Extra Bar 2',
    extra3 = 'Extra Bar 3',
    extra4 = 'Extra Bar 4',
};

BAR.SETTINGS_KEY = {
    main = 'main_bar',
    extra1 = 'extra_bar_1',
    extra2 = 'extra_bar_2',
    extra3 = 'extra_bar_3',
    extra4 = 'extra_bar_4',
};

BAR.LEGACY_SETTING_KEY = {
    main = {
        visible = 'visible',
        display_mode = 'display_mode',
        button_count = 'button_count',
        buttons_per_row = 'buttons_per_row',
        slot_size = 'slot_size',
        button_gap = 'button_gap',
        slot_glow_size = 'slot_glow_size',
        slot_glow_opacity = 'slot_glow_opacity',
        label_vertical_position = 'label_vertical_position',
        window_x = 'window_x',
        window_y = 'window_y',
    },
    extra1 = {
        visible = 'show_click_bar',
        button_count = 'button_count',
        buttons_per_row = 'buttons_per_row',
        slot_size = 'slot_size',
        button_gap = 'button_gap',
        slot_glow_size = 'slot_glow_size',
        slot_glow_opacity = 'slot_glow_opacity',
        label_vertical_position = 'label_vertical_position',
        window_x = 'click_bar_window_x',
        window_y = 'click_bar_window_y',
    },
};

function BAR.settings(bar_key)
    local settings = state.config.settings or {};
    local key = BAR.SETTINGS_KEY[bar_key];
    local values = key ~= nil and settings[key] or nil;
    return type(values) == 'table' and values or nil;
end

function BAR.default_setting(bar_key, field)
    local defaults = DEFAULT_CONFIG.settings[BAR.SETTINGS_KEY[bar_key] or ''];
    if (type(defaults) == 'table' and defaults[field] ~= nil) then
        return defaults[field];
    end

    local legacy_key = BAR.LEGACY_SETTING_KEY[bar_key] and BAR.LEGACY_SETTING_KEY[bar_key][field] or nil;
    if (legacy_key ~= nil) then
        return DEFAULT_CONFIG.settings[legacy_key];
    end

    return nil;
end

function BAR.raw_setting(bar_key, field)
    local values = BAR.settings(bar_key);
    if (values ~= nil and values[field] ~= nil) then
        return values[field], 'config';
    end

    local settings = state.config.settings or {};
    local legacy_key = BAR.LEGACY_SETTING_KEY[bar_key] and BAR.LEGACY_SETTING_KEY[bar_key][field] or nil;
    if (legacy_key ~= nil and settings[legacy_key] ~= nil) then
        return settings[legacy_key], 'legacy';
    end

    return BAR.default_setting(bar_key, field), 'default';
end

function BAR.current_key()
    return state.render_bar_key or 'main';
end

function BAR.is_extra_bar(bar_key)
    return BAR.EXTRA_ROW_ID[bar_key] ~= nil;
end

function BAR.is_known_bar(bar_key)
    return bar_key == 'main' or BAR.is_extra_bar(bar_key);
end

function BAR.extra_row_id(bar_key)
    return BAR.EXTRA_ROW_ID[bar_key] or 'click';
end

function BAR.extra_label(bar_key)
    return BAR.EXTRA_LABEL[bar_key] or tostring(bar_key);
end

BAR.OVERRIDE_STATE_KEY = {
    main = {
        profile_scope = 'main_bar_profile_scope_override',
        visible = 'main_bar_visible_override',
        display_mode = 'display_mode_override',
        button_count = 'main_bar_button_count_override',
        buttons_per_row = 'main_bar_buttons_per_row_override',
        slot_size = 'slot_size_override',
        button_gap = 'button_gap_override',
        slot_glow_size = 'slot_glow_size_override',
        slot_glow_opacity = 'slot_glow_opacity_override',
        label_vertical_position = 'label_vertical_position_override',
    },
    extra1 = {
        profile_scope = 'click_bar_profile_scope_override',
        visible = 'click_bar_visible_override',
        button_count = 'click_bar_button_count_override',
        buttons_per_row = 'click_bar_buttons_per_row_override',
        slot_size = 'click_bar_slot_size_override',
        button_gap = 'click_bar_button_gap_override',
        slot_glow_size = 'click_bar_slot_glow_size_override',
        slot_glow_opacity = 'click_bar_slot_glow_opacity_override',
        label_vertical_position = 'click_bar_label_vertical_position_override',
    },
};

function BAR.override(bar_key, field)
    local state_key = BAR.OVERRIDE_STATE_KEY[bar_key] and BAR.OVERRIDE_STATE_KEY[bar_key][field] or nil;
    if (state_key ~= nil) then
        return state[state_key];
    end

    if (BAR.is_extra_bar(bar_key)) then
        local overrides = type(state.extra_bar_overrides) == 'table' and state.extra_bar_overrides[bar_key] or nil;
        return type(overrides) == 'table' and overrides[field] or nil;
    end

    return nil;
end

function BAR.set_override(bar_key, field, value)
    local state_key = BAR.OVERRIDE_STATE_KEY[bar_key] and BAR.OVERRIDE_STATE_KEY[bar_key][field] or nil;
    if (state_key ~= nil) then
        state[state_key] = value;
    elseif (BAR.is_extra_bar(bar_key)) then
        if (type(state.extra_bar_overrides) ~= 'table') then
            state.extra_bar_overrides = {};
        end
        if (type(state.extra_bar_overrides[bar_key]) ~= 'table') then
            state.extra_bar_overrides[bar_key] = {};
        end
        state.extra_bar_overrides[bar_key][field] = value;
    end
    if (field == 'profile_scope') then
        state.profile = nil;
    end
end

function BAR.override_source(bar_key, field)
    return BAR.override(bar_key, field) ~= nil and 'runtime' or nil;
end

local function configured_display_mode()
    local raw, source = BAR.raw_setting('main', 'display_mode');
    local mode = normalize_display_mode(raw);
    if (mode ~= nil) then
        return mode, source;
    end

    return 'single', 'fixed';
end

local function display_mode()
    return 'single';
end

local function display_mode_source()
    local _, source = configured_display_mode();
    return source;
end

function BAR.normalize_button_count(value)
    local count = tonumber(value);
    if (count == nil) then
        return nil;
    end

    count = math.floor(count + 0.5);
    if (count < LIMITS.button_count_min) then
        return LIMITS.button_count_min;
    end
    if (count > LIMITS.button_count_max) then
        return LIMITS.button_count_max;
    end

    return count;
end

function BAR.button_count(bar_key)
    bar_key = bar_key or BAR.current_key();
    local override = BAR.override(bar_key, 'button_count');
    if (override ~= nil) then
        local defaults = DEFAULT_CONFIG.settings[BAR.SETTINGS_KEY[bar_key] or ''];
        return BAR.normalize_button_count(override) or (type(defaults) == 'table' and defaults.button_count) or 10;
    end

    local raw = BAR.raw_setting(bar_key, 'button_count');
    return BAR.normalize_button_count(raw) or BAR.default_setting(bar_key, 'button_count') or 10;
end

function BAR.button_count_source(bar_key)
    bar_key = bar_key or BAR.current_key();
    local source = BAR.override_source(bar_key, 'button_count');
    if (source ~= nil) then
        return source;
    end

    local raw, raw_source = BAR.raw_setting(bar_key, 'button_count');
    if (BAR.normalize_button_count(raw) ~= nil) then
        return raw_source;
    end

    return 'default';
end

function BAR.normalize_buttons_per_row(value, count)
    local per_row = tonumber(value);
    if (per_row == nil) then
        return nil;
    end

    local max_value = BAR.normalize_button_count(count) or LIMITS.buttons_per_row_max;
    max_value = math.min(max_value, LIMITS.buttons_per_row_max);
    per_row = math.floor(per_row + 0.5);
    if (per_row < LIMITS.buttons_per_row_min) then
        return LIMITS.buttons_per_row_min;
    end
    if (per_row > max_value) then
        return max_value;
    end

    return per_row;
end

function BAR.buttons_per_row(bar_key)
    bar_key = bar_key or BAR.current_key();
    local count = BAR.button_count(bar_key);
    local override = BAR.override(bar_key, 'buttons_per_row');
    if (override ~= nil) then
        return BAR.normalize_buttons_per_row(override, count) or count;
    end

    local raw = BAR.raw_setting(bar_key, 'buttons_per_row');
    return BAR.normalize_buttons_per_row(raw, count) or BAR.normalize_buttons_per_row(BAR.default_setting(bar_key, 'buttons_per_row'), count) or count;
end

function BAR.buttons_per_row_source(bar_key)
    bar_key = bar_key or BAR.current_key();
    local source = BAR.override_source(bar_key, 'buttons_per_row');
    if (source ~= nil) then
        return source;
    end

    local raw, raw_source = BAR.raw_setting(bar_key, 'buttons_per_row');
    if (BAR.normalize_buttons_per_row(raw, BAR.button_count(bar_key)) ~= nil) then
        return raw_source;
    end

    return 'default';
end

local function normalize_slot_size(value)
    local size = tonumber(value);
    if (size == nil) then
        return nil;
    end

    size = math.floor(size + 0.5);
    if (size < LIMITS.slot_size_min) then
        return LIMITS.slot_size_min;
    end
    if (size > LIMITS.slot_size_max) then
        return LIMITS.slot_size_max;
    end

    return size;
end

local function slot_size(bar_key)
    bar_key = bar_key or BAR.current_key();
    local override = BAR.override(bar_key, 'slot_size');
    if (override ~= nil) then
        return override;
    end

    local raw = BAR.raw_setting(bar_key, 'slot_size');
    return normalize_slot_size(raw) or BAR.default_setting(bar_key, 'slot_size') or DEFAULT_CONFIG.settings.slot_size;
end

local function slot_size_source(bar_key)
    bar_key = bar_key or BAR.current_key();
    local source = BAR.override_source(bar_key, 'slot_size');
    if (source ~= nil) then
        return source;
    end

    local raw, raw_source = BAR.raw_setting(bar_key, 'slot_size');
    if (normalize_slot_size(raw) ~= nil) then
        return raw_source;
    end

    return 'default';
end

local function normalize_button_gap(value)
    local gap = tonumber(value);
    if (gap == nil) then
        return nil;
    end

    gap = math.floor(gap + 0.5);
    if (gap < LIMITS.button_gap_min) then
        return LIMITS.button_gap_min;
    end
    if (gap > LIMITS.button_gap_max) then
        return LIMITS.button_gap_max;
    end

    return gap;
end

local function configured_button_gap(bar_key)
    bar_key = bar_key or BAR.current_key();
    local raw, source = BAR.raw_setting(bar_key, 'button_gap');
    local gap = normalize_button_gap(raw);
    if (gap ~= nil) then
        return gap, source;
    end

    local settings = state.config.settings or {};
    gap = normalize_button_gap(settings.slot_gap);
    if (gap ~= nil and bar_key == 'main') then
        return gap, 'legacy';
    end

    return BAR.default_setting(bar_key, 'button_gap') or DEFAULT_CONFIG.settings.button_gap, 'default';
end

local function button_gap(bar_key)
    bar_key = bar_key or BAR.current_key();
    local override = BAR.override(bar_key, 'button_gap');
    if (override ~= nil) then
        return override;
    end

    local gap = configured_button_gap(bar_key);
    return gap;
end

local function button_gap_source(bar_key)
    bar_key = bar_key or BAR.current_key();
    local source = BAR.override_source(bar_key, 'button_gap');
    if (source ~= nil) then
        return source;
    end

    local _, source = configured_button_gap(bar_key);
    return source;
end

local function normalize_percent(value, min_value, max_value)
    local percent = tonumber(value);
    if (percent == nil) then
        return nil;
    end

    percent = math.floor(percent + 0.5);
    if (percent < min_value) then
        return min_value;
    end
    if (percent > max_value) then
        return max_value;
    end

    return percent;
end

local function normalize_slot_glow_size(value)
    return normalize_percent(value, LIMITS.slot_glow_size_min, LIMITS.slot_glow_size_max);
end

local function normalize_slot_glow_opacity(value)
    return normalize_percent(value, LIMITS.slot_glow_opacity_min, LIMITS.slot_glow_opacity_max);
end

local function slot_glow_size(bar_key)
    bar_key = bar_key or BAR.current_key();
    local override = BAR.override(bar_key, 'slot_glow_size');
    if (override ~= nil) then
        return override;
    end

    local raw = BAR.raw_setting(bar_key, 'slot_glow_size');
    return normalize_slot_glow_size(raw) or BAR.default_setting(bar_key, 'slot_glow_size') or DEFAULT_CONFIG.settings.slot_glow_size;
end

local function slot_glow_size_source(bar_key)
    bar_key = bar_key or BAR.current_key();
    local source = BAR.override_source(bar_key, 'slot_glow_size');
    if (source ~= nil) then
        return source;
    end

    local raw, raw_source = BAR.raw_setting(bar_key, 'slot_glow_size');
    if (normalize_slot_glow_size(raw) ~= nil) then
        return raw_source;
    end

    return 'default';
end

local function slot_glow_opacity(bar_key)
    bar_key = bar_key or BAR.current_key();
    local override = BAR.override(bar_key, 'slot_glow_opacity');
    if (override ~= nil) then
        return override;
    end

    local raw = BAR.raw_setting(bar_key, 'slot_glow_opacity');
    return normalize_slot_glow_opacity(raw) or BAR.default_setting(bar_key, 'slot_glow_opacity') or DEFAULT_CONFIG.settings.slot_glow_opacity;
end

local function slot_glow_opacity_source(bar_key)
    bar_key = bar_key or BAR.current_key();
    local source = BAR.override_source(bar_key, 'slot_glow_opacity');
    if (source ~= nil) then
        return source;
    end

    local raw, raw_source = BAR.raw_setting(bar_key, 'slot_glow_opacity');
    if (normalize_slot_glow_opacity(raw) ~= nil) then
        return raw_source;
    end

    return 'default';
end

local function slot_glow_scale(bar_key)
    return slot_glow_size(bar_key) / 100.0;
end

local function slot_glow_alpha_scale(bar_key)
    return slot_glow_opacity(bar_key) / 100.0;
end

local function normalize_label_vertical_position(value)
    return normalize_percent(value, LIMITS.label_vertical_position_min, LIMITS.label_vertical_position_max);
end

local function label_vertical_position(bar_key)
    bar_key = bar_key or BAR.current_key();
    local override = BAR.override(bar_key, 'label_vertical_position');
    if (override ~= nil) then
        return override;
    end

    local raw = BAR.raw_setting(bar_key, 'label_vertical_position');
    return normalize_label_vertical_position(raw) or BAR.default_setting(bar_key, 'label_vertical_position') or DEFAULT_CONFIG.settings.label_vertical_position;
end

local function label_vertical_position_source(bar_key)
    bar_key = bar_key or BAR.current_key();
    local source = BAR.override_source(bar_key, 'label_vertical_position');
    if (source ~= nil) then
        return source;
    end

    local raw, raw_source = BAR.raw_setting(bar_key, 'label_vertical_position');
    if (normalize_label_vertical_position(raw) ~= nil) then
        return raw_source;
    end

    return 'default';
end

local function bar_frame_visible()
    local settings = state.config.settings or {};
    return settings.bars_unlocked == true;
end

local function bar_frame_source()
    local settings = state.config.settings or {};
    if (settings.bars_unlocked ~= nil) then
        return 'config';
    end

    return 'default';
end

local function configured_main_bar_visible()
    local raw, source = BAR.raw_setting('main', 'visible');
    return raw ~= false, source;
end

local function main_bar_visible()
    local override = BAR.override('main', 'visible');
    if (override ~= nil) then
        return override == true;
    end

    return state.visible[1] ~= false;
end

local function main_bar_visible_source()
    local source = BAR.override_source('main', 'visible');
    if (source ~= nil) then
        return source;
    end

    local _, configured_source = configured_main_bar_visible();
    return configured_source;
end

function BAR.configured_extra_bar_visible(bar_key)
    local raw, source = BAR.raw_setting(bar_key, 'visible');
    return raw ~= false, source;
end

function BAR.extra_bar_visible(bar_key)
    local override = BAR.override(bar_key, 'visible');
    if (override ~= nil) then
        return override == true;
    end

    local visible = BAR.configured_extra_bar_visible(bar_key);
    return visible;
end

function BAR.extra_bar_visible_source(bar_key)
    local source = BAR.override_source(bar_key, 'visible');
    if (source ~= nil) then
        return source;
    end

    local _, source = BAR.configured_extra_bar_visible(bar_key);
    return source;
end

local function click_bar_visible()
    return BAR.extra_bar_visible('extra1');
end

local function click_bar_visible_source()
    return BAR.extra_bar_visible_source('extra1');
end

local function click_bar_frame_visible()
    return bar_frame_visible();
end

local function click_bar_frame_source()
    return bar_frame_source();
end

local function bar_window_position(settings)
    local raw_x = BAR.raw_setting('main', 'window_x');
    local raw_y = BAR.raw_setting('main', 'window_y');
    local x = tonumber(state.bar_anchor_x) or tonumber(raw_x) or tonumber(settings.window_x) or DEFAULT_CONFIG.settings.window_x;
    local y = tonumber(state.bar_anchor_y) or tonumber(raw_y) or tonumber(settings.window_y) or DEFAULT_CONFIG.settings.window_y;
    return math.floor(x + 0.5), math.floor(y + 0.5);
end

function BAR.extra_bar_window_position(bar_key, settings)
    settings = settings or state.config.settings or {};
    local runtime = BAR.extra_runtime(bar_key);
    local raw_x = BAR.raw_setting(bar_key, 'window_x');
    local raw_y = BAR.raw_setting(bar_key, 'window_y');
    local defaults = DEFAULT_CONFIG.settings[BAR.SETTINGS_KEY[bar_key]] or {};
    local legacy_x = (bar_key == 'extra1') and tonumber(settings.click_bar_window_x) or nil;
    local legacy_y = (bar_key == 'extra1') and tonumber(settings.click_bar_window_y) or nil;
    local x = tonumber(runtime.anchor_x) or tonumber(raw_x) or legacy_x or tonumber(defaults.window_x) or DEFAULT_CONFIG.settings.click_bar_window_x;
    local y = tonumber(runtime.anchor_y) or tonumber(raw_y) or legacy_y or tonumber(defaults.window_y) or DEFAULT_CONFIG.settings.click_bar_window_y;
    return math.floor(x + 0.5), math.floor(y + 0.5);
end

local function click_bar_window_position(settings)
    return BAR.extra_bar_window_position('extra1', settings);
end

local function estimated_frame_offset(label_width)
    local style = safe_read(function () return imgui.GetStyle(); end, nil);
    local pad_x = 8;
    local pad_y = 8;
    local title_h = 22;
    label_width = tonumber(label_width) or 52;

    if (style ~= nil) then
        if (style.WindowPadding ~= nil) then
            pad_x = tonumber(style.WindowPadding.x) or tonumber(style.WindowPadding[1]) or pad_x;
            pad_y = tonumber(style.WindowPadding.y) or tonumber(style.WindowPadding[2]) or pad_y;
        end

        if (style.FramePadding ~= nil) then
            local frame_y = tonumber(style.FramePadding.y) or tonumber(style.FramePadding[2]);
            local font_size = safe_read(function () return imgui.GetFontSize(); end, nil);
            if (frame_y ~= nil and font_size ~= nil) then
                title_h = font_size + (frame_y * 2);
            end
        end
    end

    return pad_x + label_width, pad_y + title_h;
end

local function frameless_window_padding()
    return math.max(LIMITS.frameless_window_padding, math.ceil((3 * slot_glow_scale()) + 1));
end

local function bar_window_offset(show_frame)
    if (show_frame) then
        local fallback_x, fallback_y = estimated_frame_offset(52);
        return tonumber(state.bar_frame_offset_x) or fallback_x, tonumber(state.bar_frame_offset_y) or fallback_y;
    end

    local pad = frameless_window_padding();
    return pad, pad;
end

function BAR.extra_bar_window_offset(bar_key, show_frame)
    local runtime = BAR.extra_runtime(bar_key);
    if (show_frame) then
        local fallback_x, fallback_y = estimated_frame_offset(0);
        return tonumber(runtime.frame_offset_x) or fallback_x, tonumber(runtime.frame_offset_y) or fallback_y;
    end

    local pad = frameless_window_padding();
    return pad, pad;
end

local function click_bar_window_offset(show_frame)
    return BAR.extra_bar_window_offset('extra1', show_frame);
end

local function lock_bar_anchor()
    local settings = state.config.settings or {};
    local anchor_x, anchor_y = bar_window_position(settings);
    state.bar_anchor_lock_x = anchor_x;
    state.bar_anchor_lock_y = anchor_y;
end

function BAR.lock_extra_bar_anchor(bar_key)
    local settings = state.config.settings or {};
    local runtime = BAR.extra_runtime(bar_key);
    local anchor_x, anchor_y = BAR.extra_bar_window_position(bar_key, settings);
    runtime.anchor_lock_x = anchor_x;
    runtime.anchor_lock_y = anchor_y;
end

local function lock_click_bar_anchor()
    BAR.lock_extra_bar_anchor('extra1');
end

function BAR.lock_all_extra_bar_anchors()
    for _, bar_key in ipairs(BAR.EXTRA_KEYS) do
        BAR.lock_extra_bar_anchor(bar_key);
    end
end

local function sync_bar_frame_visibility()
    local visible = bar_frame_visible();
    if (state.bar_frames_visible == visible) then
        return;
    end

    lock_bar_anchor();
    BAR.lock_all_extra_bar_anchors();
    state.bar_frames_visible = visible;
end

local function imgui_wants_keyboard()
    return safe_read(function ()
        local io = imgui.GetIO();
        return io ~= nil and (io.WantCaptureKeyboard == true or io.WantTextInput == true);
    end, false);
end

local function config_file_path()
    local source = safe_read(function ()
        local info = debug.getinfo(1, 'S');
        return (info ~= nil) and info.source or nil;
    end, nil);

    if (type(source) == 'string') then
        if (source:sub(1, 1) == '@') then
            source = source:sub(2);
        end

        local dir = source:match('^(.*[\\/])');
        if (dir ~= nil) then
            return dir .. 'ashitabars_config.lua';
        end
    end

    return 'ashitabars_config.lua';
end

local function read_text_file(path)
    local file, err = io.open(path, 'rb');
    if (file == nil) then
        return nil, err;
    end

    local contents = file:read('*a');
    file:close();
    return contents;
end

local function write_text_file(path, contents)
    local file, err = io.open(path, 'wb');
    if (file == nil) then
        return false, err;
    end

    local ok, write_err = file:write(contents);
    file:close();
    if (not ok) then
        return false, write_err;
    end

    return true;
end

function MACRO.ensure_script_dir()
    local install_path = safe_read(function ()
        return AshitaCore:GetInstallPath();
    end, nil);

    if (type(install_path) ~= 'string' or install_path == '') then
        return false, 'Ashita install path is unavailable.';
    end

    if (not install_path:match('[\\/]$')) then
        install_path = install_path .. '\\';
    end

    if (ashita == nil or ashita.fs == nil) then
        return false, 'Ashita filesystem helpers are unavailable.';
    end

    local scripts_dir = install_path .. 'scripts\\';
    if (not ashita.fs.exists(scripts_dir)) then
        ashita.fs.create_dir(scripts_dir);
    end

    return true, scripts_dir;
end

function MACRO.script_file_name(context)
    context = type(context) == 'table' and context or {};
    local profile_key = normalize_profile_key(context.profile_key) or 'DEFAULT';
    local group = valid_row_id(context.group) and context.group or 'base';
    local index = tonumber(context.index) or 0;
    local digit = BAR.slot_index_label(index);
    local name = ('%s_%s_%s'):fmt(profile_key, group, digit):gsub('[^A-Za-z0-9_-]+', '_');
    return ('%s_%s.txt'):fmt(addon.name, name);
end

function MACRO.run_key(context)
    if (type(context) ~= 'table') then
        return nil;
    end

    local profile_key = normalize_profile_key(context.profile_key) or 'DEFAULT';
    local group = valid_row_id(context.group) and context.group or nil;
    local index = tonumber(context.index);
    if (group == nil or index == nil or index < 1 or index > LIMITS.button_count_max) then
        return nil;
    end

    return ('%s:%s:%d'):fmt(profile_key, group, math.floor(index));
end

function MACRO.wait_total_seconds(commands)
    if (type(commands) ~= 'table' or #commands == 0) then
        return 0;
    end

    local total = 0;
    for _, command in ipairs(commands) do
        if (type(command) == 'string') then
            local wait_value = command:lower():match('^%s*/wait%s+([%d%.]+)');
            if (wait_value ~= nil) then
                local seconds = tonumber(wait_value) or 0;
                if (seconds > 0) then
                    total = total + seconds;
                end
            end
        end
    end

    return math.max(0, math.ceil(total));
end

function MACRO.start_run_overlay(commands, context)
    local key = MACRO.run_key(context);
    if (key == nil) then
        return;
    end

    local total = MACRO.wait_total_seconds(commands);
    if (total <= 0) then
        state.macro_runs[key] = nil;
        return;
    end

    local now = os.time();
    state.macro_runs[key] = {
        started_at = now,
        total = total,
        expires_at = now + total,
    };
end

function MACRO.write_script(commands, context)
    local ok, dir_or_err = MACRO.ensure_script_dir();
    if (not ok) then
        return false, ('Script failed: %s'):fmt(tostring(dir_or_err));
    end

    local file_name = MACRO.script_file_name(context);
    local contents = MACRO.commands_to_text(commands);
    if (contents ~= '') then
        contents = contents .. '\n';
    end

    local write_ok, write_err = write_text_file(dir_or_err .. file_name, contents);
    if (not write_ok) then
        return false, ('Script failed: could not write %s (%s).'):fmt(file_name, tostring(write_err));
    end

    return true, file_name;
end

function MACRO.queue_commands(commands, context)
    if (type(commands) ~= 'table' or #commands == 0) then
        return false, 'Nothing to run.';
    end

    if (type(context) == 'table' and context.script == true) then
        local ok, include_path_or_err = MACRO.write_script(commands, context);
        if (not ok) then
            return false, include_path_or_err;
        end

        AshitaCore:GetChatManager():QueueCommand(-1, '/exec ' .. include_path_or_err);
        MACRO.start_run_overlay(commands, context);
        return true, include_path_or_err;
    end

    for _, command in ipairs(commands) do
        AshitaCore:GetChatManager():QueueCommand(1, command);
    end

    return true, nil;
end

local function find_settings_table(contents)
    local start_pos, open_pos = contents:find('settings%s*=%s*{');
    if (start_pos == nil) then
        return nil, nil;
    end

    local depth = 0;
    for i = open_pos, #contents do
        local char = contents:sub(i, i);
        if (char == '{') then
            depth = depth + 1;
        elseif (char == '}') then
            depth = depth - 1;
            if (depth == 0) then
                return start_pos, i;
            end
        end
    end

    return nil, nil;
end

local function lua_string_literal(value)
    local text = tostring(value):gsub('\\', '\\\\'):gsub('\r', '\\r'):gsub('\n', '\\n'):gsub("'", "\\'");
    return ("'%s'"):fmt(text);
end

local function sorted_keys(tbl)
    local keys = {};
    if (type(tbl) ~= 'table') then
        return keys;
    end

    for key, _ in pairs(tbl) do
        table.insert(keys, key);
    end

    table.sort(keys, function (left, right)
        return tostring(left) < tostring(right);
    end);

    return keys;
end

function KEYBIND.rows_for_bar(bar_key)
    if (BAR.is_extra_bar(bar_key)) then
        return { ROW_BY_ID[BAR.extra_row_id(bar_key)] or CLICK_ROW };
    end

    return { ROW_BY_ID.base };
end

function KEYBIND.bar_label(bar_key)
    if (BAR.is_extra_bar(bar_key)) then
        return BAR.extra_label(bar_key);
    end

    return 'Main Bar';
end

function KEYBIND.row_label(row_id)
    local row = ROW_BY_ID[row_id];
    return row ~= nil and row.label or tostring(row_id);
end

function KEYBIND.slot_name(bar_key, row_id, index)
    return ('%s %s %s'):fmt(KEYBIND.bar_label(bar_key), KEYBIND.row_label(row_id), BAR.slot_index_label(index));
end

function KEYBIND.normalize_key_token(token)
    local raw = trim_string(token or '');
    if (raw == '') then
        return nil;
    end

    if (#raw == 1) then
        local upper = raw:upper();
        if (upper:match('^[A-Z0-9]$')) then
            return upper;
        end
    end

    local compact = raw:gsub('%s+', ''):gsub('[_%-]+', ''):lower();
    local fn = compact:match('^f(%d%d?)$');
    if (fn ~= nil) then
        local number = tonumber(fn);
        if (number ~= nil and number >= 1 and number <= 12) then
            return 'F' .. tostring(number);
        end
    end

    local numpad = compact:match('^numpad(%d)$') or compact:match('^num(%d)$');
    if (numpad ~= nil) then
        return 'Num' .. numpad;
    end

    return KEYBIND.KEY_ALIASES[compact];
end

function KEYBIND.normalize(value)
    local text = trim_string(value or '');
    if (text == '') then
        return nil;
    end

    local ctrl = false;
    local alt = false;
    local shift = false;
    local key = nil;

    for token in text:gmatch('[^+]+') do
        local compact = trim_string(token):gsub('%s+', ''):lower();
        if (compact == 'ctrl' or compact == 'control') then
            ctrl = true;
        elseif (compact == 'alt') then
            alt = true;
        elseif (compact == 'shift') then
            shift = true;
        else
            if (key ~= nil) then
                return nil;
            end
            key = KEYBIND.normalize_key_token(token);
            if (key == nil) then
                return nil;
            end
        end
    end

    if (key == nil) then
        return nil;
    end

    local parts = {};
    if (ctrl) then table.insert(parts, 'Ctrl'); end
    if (alt) then table.insert(parts, 'Alt'); end
    if (shift) then table.insert(parts, 'Shift'); end
    table.insert(parts, key);
    return table.concat(parts, '+');
end

function KEYBIND.event_key_label(wparam)
    local vk = tonumber(wparam);
    if (vk == nil or vk == VK.CONTROL or vk == VK.ALT or vk == VK.SHIFT) then
        return nil;
    end

    local digit = VK.DIGITS[vk];
    if (digit ~= nil) then
        return DIGIT_LABELS[digit];
    end

    if (vk >= 0x41 and vk <= 0x5A) then
        return string.char(vk);
    end

    if (vk >= 0x70 and vk <= 0x7B) then
        return 'F' .. tostring(vk - 0x6F);
    end

    if (vk >= 0x60 and vk <= 0x69) then
        return 'Num' .. tostring(vk - 0x60);
    end

    if (vk == VK.BACKSPACE) then return 'Backspace'; end
    if (vk == VK.ESCAPE) then return 'Escape'; end
    return KEYBIND.EVENT_LABELS[vk];
end

function KEYBIND.combo_from_parts(key_label, ctrl, alt, shift)
    local key = KEYBIND.normalize_key_token(key_label);
    if (key == nil) then
        return nil;
    end

    local parts = {};
    if (ctrl) then table.insert(parts, 'Ctrl'); end
    if (alt) then table.insert(parts, 'Alt'); end
    if (shift) then table.insert(parts, 'Shift'); end
    table.insert(parts, key);
    return table.concat(parts, '+');
end

function KEYBIND.combo_from_event(e)
    local key = KEYBIND.event_key_label(e.wparam);
    if (key == nil) then
        return nil;
    end

    return KEYBIND.combo_from_parts(key, key_down(VK.CONTROL), key_down(VK.ALT), key_down(VK.SHIFT));
end

function KEYBIND.display_label(combo)
    local normalized = KEYBIND.normalize(combo);
    if (normalized == nil) then
        return nil;
    end

    local parts = {};
    for token in normalized:gmatch('[^+]+') do
        if (token == 'Ctrl') then
            table.insert(parts, 'C');
        elseif (token == 'Alt') then
            table.insert(parts, 'A');
        elseif (token == 'Shift') then
            table.insert(parts, 'S');
        else
            table.insert(parts, token);
        end
    end

    return table.concat(parts, '+');
end

function KEYBIND.combo_key(combo)
    local normalized = KEYBIND.normalize(combo);
    if (normalized == nil) then
        return nil;
    end

    local key = nil;
    for token in normalized:gmatch('[^+]+') do
        if (token ~= 'Ctrl' and token ~= 'Alt' and token ~= 'Shift') then
            key = token;
        end
    end

    return key;
end

function KEYBIND.normalize_for_storage(bar_key, row_id, combo)
    local normalized = KEYBIND.normalize(combo);
    if (normalized == nil) then
        return nil;
    end

    if (BAR.row_supports_modifiers(row_id)) then
        return KEYBIND.combo_key(normalized);
    end

    return normalized;
end

function KEYBIND.modifier_id(row_id)
    local row = ROW_BY_ID[row_id];
    if (row ~= nil and row.modifier ~= nil) then
        return row.modifier;
    end
    if (KEYBIND.MODIFIER_PREFIXES[row_id] ~= nil) then
        return row_id;
    end
    return nil;
end

function KEYBIND.combo_with_modifier(base_combo, row_id)
    local modifier = KEYBIND.modifier_id(row_id);
    local prefix = modifier ~= nil and KEYBIND.MODIFIER_PREFIXES[modifier] or nil;
    if (prefix == nil) then
        return nil;
    end

    local key = KEYBIND.combo_key(base_combo);
    if (key == nil) then
        return nil;
    end

    return KEYBIND.normalize(('%s+%s'):fmt(prefix, key));
end

function KEYBIND.row_is_configurable_for_bar(bar_key, row_id)
    for _, row in ipairs(KEYBIND.rows_for_bar(bar_key)) do
        if (row.id == row_id) then
            return true;
        end
    end
    return false;
end

function KEYBIND.empty_bar_keybinds(bar_key)
    local result = {};
    for _, row in ipairs(KEYBIND.rows_for_bar(bar_key)) do
        result[row.id] = {};
    end
    return result;
end

function KEYBIND.overlay_bar_keybinds(target, source, bar_key)
    if (type(target) ~= 'table' or type(source) ~= 'table') then
        return target;
    end

    for _, row in ipairs(KEYBIND.rows_for_bar(bar_key)) do
        local row_source = source[row.id];
        if (type(row_source) == 'table') then
            if (type(target[row.id]) ~= 'table') then
                target[row.id] = {};
            end
            for index = 1, LIMITS.button_count_max do
                if (row_source[index] ~= nil) then
                    target[row.id][index] = KEYBIND.normalize_for_storage(bar_key, row.id, row_source[index]) or '';
                end
            end
        end
    end

    return target;
end

function KEYBIND.default_bar_keybinds(bar_key)
    local result = KEYBIND.empty_bar_keybinds(bar_key);
    local settings_key = BAR.SETTINGS_KEY[bar_key];
    local defaults = (settings_key ~= nil and DEFAULT_CONFIG.settings[settings_key]) or nil;
    if (type(defaults) == 'table') then
        KEYBIND.overlay_bar_keybinds(result, defaults.keybinds, bar_key);
    end
    return result;
end

function KEYBIND.config_bar_keybinds(bar_key)
    local settings = BAR.settings(bar_key);
    if (type(settings) == 'table' and type(settings.keybinds) == 'table') then
        return settings.keybinds;
    end
    return nil;
end

function KEYBIND.effective_bar_keybinds(bar_key)
    local result = KEYBIND.default_bar_keybinds(bar_key);
    KEYBIND.overlay_bar_keybinds(result, KEYBIND.config_bar_keybinds(bar_key), bar_key);
    if (type(state.keybind_overrides) == 'table') then
        KEYBIND.overlay_bar_keybinds(result, state.keybind_overrides[bar_key], bar_key);
    end
    return result;
end

function KEYBIND.slot_combo(bar_key, row_id, index)
    local keybinds = KEYBIND.effective_bar_keybinds(bar_key);
    local modifier = KEYBIND.modifier_id(row_id);
    local parent_row_id = BAR.parent_group(row_id);
    if (modifier ~= nil and parent_row_id ~= nil and parent_row_id ~= row_id) then
        local base_row = keybinds[parent_row_id];
        if (type(base_row) ~= 'table' or not BAR.modifier_slot_enabled(row_id, index)) then
            return nil;
        end
        return KEYBIND.combo_with_modifier(base_row[index], row_id);
    end

    local row = keybinds[row_id];
    if (type(row) ~= 'table') then
        return nil;
    end
    return KEYBIND.normalize(row[index]);
end

function KEYBIND.slot_display_label(bar_key, row_id, index)
    return KEYBIND.display_label(KEYBIND.slot_combo(bar_key, row_id, index));
end

function KEYBIND.set_slot_override(bar_key, row_id, index, combo)
    if (not BAR.is_known_bar(bar_key)) then
        return false;
    end
    local numeric_index = tonumber(index);
    if (not KEYBIND.row_is_configurable_for_bar(bar_key, row_id) or numeric_index == nil or numeric_index < 1 or numeric_index > LIMITS.button_count_max) then
        return false;
    end
    index = math.floor(numeric_index);

    if (type(state.keybind_overrides) ~= 'table') then
        state.keybind_overrides = {};
    end
    if (type(state.keybind_overrides[bar_key]) ~= 'table') then
        state.keybind_overrides[bar_key] = KEYBIND.effective_bar_keybinds(bar_key);
    end
    if (type(state.keybind_overrides[bar_key][row_id]) ~= 'table') then
        state.keybind_overrides[bar_key][row_id] = {};
    end

    state.keybind_overrides[bar_key][row_id][index] = KEYBIND.normalize_for_storage(bar_key, row_id, combo) or '';
    return true;
end

function KEYBIND.sanitize_for_storage(bar_key, keybinds)
    local result = KEYBIND.empty_bar_keybinds(bar_key);
    KEYBIND.overlay_bar_keybinds(result, keybinds, bar_key);
    return result;
end

function KEYBIND.apply_to_target(target, settings, bar_key)
    if (type(target) ~= 'table' or type(settings) ~= 'table' or settings.keybinds == nil) then
        return;
    end

    target.keybinds = KEYBIND.sanitize_for_storage(bar_key, settings.keybinds);
end

function KEYBIND.serialize_lines(keybinds, indent, bar_key)
    local lines = {
        indent .. 'keybinds = {',
    };

    for _, row in ipairs(KEYBIND.rows_for_bar(bar_key)) do
        local row_values = type(keybinds) == 'table' and keybinds[row.id] or nil;
        local parts = {};
        for index = 1, LIMITS.button_count_max do
            local combo = nil;
            if (type(row_values) == 'table') then
                combo = KEYBIND.normalize(row_values[index]);
            end
            table.insert(parts, ('[%d] = %s'):fmt(index, lua_string_literal(combo or '')));
        end
        table.insert(lines, ('%s    %s = { %s },'):fmt(indent, row.id, table.concat(parts, ', ')));
    end

    table.insert(lines, indent .. '},');
    return lines;
end

function KEYBIND.binding_map()
    local map = {};
    local conflicts = {};

    local function add_binding(combo, bar_key, row_id, index)
        local normalized = KEYBIND.normalize(combo);
        local enabled = KEYBIND.slot_enabled_for_binding == nil or KEYBIND.slot_enabled_for_binding(bar_key, row_id, index);
        if (normalized == nil or not enabled) then
            return;
        end

        local entry = {
            combo = normalized,
            bar_key = bar_key,
            group = row_id,
            index = index,
            name = KEYBIND.slot_name(bar_key, row_id, index),
        };
        if (map[normalized] == nil) then
            map[normalized] = entry;
        else
            if (conflicts[normalized] == nil) then
                conflicts[normalized] = { map[normalized] };
            end
            table.insert(conflicts[normalized], entry);
        end
    end

    for _, bar_key in ipairs(KEYBIND.BAR_KEYS) do
        local keybinds = KEYBIND.effective_bar_keybinds(bar_key);
        for _, row in ipairs(KEYBIND.rows_for_bar(bar_key)) do
            local row_values = keybinds[row.id];
            if (type(row_values) == 'table') then
                for index = 1, LIMITS.button_count_max do
                    local combo = KEYBIND.normalize(row_values[index]);
                    if (combo ~= nil) then
                        add_binding(combo, bar_key, row.id, index);
                        if (BAR.row_supports_modifiers(row.id)) then
                            for _, modifier_id in ipairs(KEYBIND.MODIFIER_ROWS) do
                                local modifier_row_id = BAR.modifier_row_id(row.id, modifier_id);
                                add_binding(KEYBIND.combo_with_modifier(combo, modifier_row_id), bar_key, modifier_row_id, index);
                            end
                        end
                    end
                end
            end
        end
    end

    return map, conflicts;
end

function KEYBIND.combo_bound(combo)
    local normalized = KEYBIND.normalize(combo);
    if (normalized == nil) then
        return false;
    end

    local map = KEYBIND.binding_map();
    return map[normalized] ~= nil;
end

function KEYBIND.conflict_messages()
    local _, conflicts = KEYBIND.binding_map();
    local combos = {};
    local messages = {};

    for combo, _ in pairs(conflicts) do
        table.insert(combos, combo);
    end
    table.sort(combos);

    for _, combo in ipairs(combos) do
        local names = {};
        for _, entry in ipairs(conflicts[combo]) do
            table.insert(names, entry.name);
        end
        table.insert(messages, ('%s: %s'):fmt(combo, table.concat(names, ', ')));
    end

    return messages;
end

function KEYBIND.summary(bar_key)
    local keybinds = KEYBIND.effective_bar_keybinds(bar_key);
    local rows = {};
    for _, row in ipairs(KEYBIND.rows_for_bar(bar_key)) do
        local values = {};
        local row_values = keybinds[row.id];
        for index = 1, BAR.button_count(bar_key) do
            values[index] = KEYBIND.display_label(type(row_values) == 'table' and row_values[index] or nil) or '-';
        end
        table.insert(rows, ('%s=%s'):fmt(row.id, table.concat(values, ',')));
    end
    return table.concat(rows, ';');
end

function KEYBIND.start_capture(bar_key, row_id, index)
    state.keybind_capture = {
        bar_key = bar_key,
        row_id = row_id,
        index = index,
    };
    state.keybind_message = ('Press a key for %s. Backspace clears, Esc cancels.'):fmt(KEYBIND.slot_name(bar_key, row_id, index));
    state.keybind_message_color = UI_COLORS.config_header;
end

function KEYBIND.handle_capture_event(e)
    local capture = state.keybind_capture;
    if (type(capture) ~= 'table') then
        return false;
    end

    if (e.wparam == VK.ESCAPE) then
        state.keybind_capture = nil;
        state.keybind_message = 'Keybind cancelled.';
        state.keybind_message_color = UI_COLORS.config_header;
        return true;
    end

    if (e.wparam == VK.BACKSPACE or e.wparam == VK.DELETE) then
        KEYBIND.set_slot_override(capture.bar_key, capture.row_id, capture.index, '');
        state.keybind_capture = nil;
        state.keybind_message = ('Unbound %s. Save to persist.'):fmt(KEYBIND.slot_name(capture.bar_key, capture.row_id, capture.index));
        state.keybind_message_color = UI_COLORS.success;
        return true;
    end

    local combo = KEYBIND.combo_from_event(e);
    if (combo == nil) then
        return true;
    end

    KEYBIND.set_slot_override(capture.bar_key, capture.row_id, capture.index, combo);
    state.keybind_capture = nil;
    local stored_combo = KEYBIND.slot_combo(capture.bar_key, capture.row_id, capture.index) or combo;
    state.keybind_message = ('Bound %s to %s. Save to persist.'):fmt(KEYBIND.slot_name(capture.bar_key, capture.row_id, capture.index), stored_combo);
    state.keybind_message_color = UI_COLORS.success;
    return true;
end

function KEYBIND.render_config_section(bar_key)
    imgui.Separator();
    imgui.TextColored(UI_COLORS.config_header, 'Keybinds');
    local rows = KEYBIND.rows_for_bar(bar_key);
    local parent_row = rows[1];
    if (parent_row ~= nil and BAR.row_supports_modifiers(parent_row.id)) then
        imgui.Text('Set the base key. Ctrl/Alt/Shift variants are implied by enabled modifier tabs.');
    else
        imgui.Text('Click a key, then press the new key. Backspace clears, Esc cancels.');
    end

    for _, row in ipairs(rows) do
        imgui.TextColored(UI_COLORS.config_header, KEYBIND.row_label(row.id));
        local visible_count = BAR.button_count(bar_key);
        local columns = BAR.buttons_per_row(bar_key);
        for index = 1, visible_count do
            if (index > 1 and ((index - 1) % columns) ~= 0) then
                imgui.SameLine(0, 4);
            end

            local capture = state.keybind_capture;
            local is_capture = type(capture) == 'table' and capture.bar_key == bar_key and capture.row_id == row.id and capture.index == index;
            local label = is_capture and '...' or (KEYBIND.slot_display_label(bar_key, row.id, index) or '-');
            if (imgui.Button(('%s##ashitabars_keybind_%s_%s_%d'):fmt(label, bar_key, row.id, index), { 44, 0 })) then
                KEYBIND.start_capture(bar_key, row.id, index);
            end
        end
    end

    local conflicts = KEYBIND.conflict_messages();
    if (#conflicts > 0) then
        imgui.TextColored(UI_COLORS.error, 'Keybind conflicts:');
        for index, message in ipairs(conflicts) do
            if (index > 4) then
                imgui.TextColored(UI_COLORS.error, ('+%d more'):fmt(#conflicts - 4));
                break;
            end
            imgui.TextColored(UI_COLORS.error, message);
        end
    end

    if (state.keybind_message ~= nil) then
        imgui.TextColored(state.keybind_message_color or UI_COLORS.config_header, state.keybind_message);
    end
end

function SHARED.normalize_name(value)
    local name = trim_one_line(value, SHARED.NAME_MAX);
    name = name:gsub('%s+', ' ');
    if (name == '') then
        return nil;
    end

    return name;
end

function SHARED.ensure_overrides()
    if (type(state.macro_overrides) ~= 'table') then
        state.macro_overrides = { profiles = {}, shared = {} };
    end
    if (type(state.macro_overrides.profiles) ~= 'table') then
        state.macro_overrides.profiles = {};
    end
    if (type(state.macro_overrides.shared) ~= 'table') then
        state.macro_overrides.shared = {};
    end

    return state.macro_overrides;
end

function SHARED.definitions()
    local overrides = SHARED.ensure_overrides();
    return overrides.shared;
end

function SHARED.definition(name)
    name = SHARED.normalize_name(name);
    if (name == nil) then
        return nil, nil;
    end

    local shared = SHARED.definitions();
    local slot = shared[name];
    if (type(slot) ~= 'table') then
        return nil, name;
    end

    return slot, name;
end

function SHARED.slot_parts(slot)
    local parts = {};
    if (type(slot) ~= 'table') then
        return parts;
    end

    if (slot.shared ~= nil) then
        table.insert(parts, ('shared = %s'):fmt(lua_string_literal(slot.shared)));
        return parts;
    end
    if (slot.label ~= nil) then
        table.insert(parts, ('label = %s'):fmt(lua_string_literal(slot.label)));
    end
    if (slot.use_action_name_label ~= nil) then
        table.insert(parts, ('use_action_name_label = %s'):fmt(slot.use_action_name_label ~= false and 'true' or 'false'));
    end
    if (slot.icon ~= nil and trim_one_line(slot.icon, LIMITS.macro_icon_max) ~= '') then
        table.insert(parts, ('icon = %s'):fmt(lua_string_literal(slot.icon)));
    end
    if (slot.weaponskill_effect ~= nil) then
        table.insert(parts, ('weaponskill_effect = %s'):fmt(lua_string_literal(slot.weaponskill_effect)));
    end
    if (slot.weaponskill_effect_intensity ~= nil) then
        table.insert(parts, ('weaponskill_effect_intensity = %d'):fmt(slot.weaponskill_effect_intensity));
    end
    if (slot.weaponskill_effect_opacity ~= nil) then
        table.insert(parts, ('weaponskill_effect_opacity = %d'):fmt(slot.weaponskill_effect_opacity));
    end
    if (slot.weaponskill_effect_frequency ~= nil) then
        table.insert(parts, ('weaponskill_effect_frequency = %d'):fmt(slot.weaponskill_effect_frequency));
    end
    if (slot.config_key ~= nil) then
        table.insert(parts, ('config_key = %d'):fmt(slot.config_key));
    end
    if (slot.config_value_a ~= nil) then
        table.insert(parts, ('config_value_a = %d'):fmt(slot.config_value_a));
    end
    if (slot.config_value_b ~= nil) then
        table.insert(parts, ('config_value_b = %d'):fmt(slot.config_value_b));
    end
    if (slot.command ~= nil) then
        table.insert(parts, ('command = %s'):fmt(lua_string_literal(slot.command)));
    end
    if (slot.macro_mode == 'multi') then
        table.insert(parts, "macro_mode = 'multi'");
        if (slot.script == true) then
            table.insert(parts, 'script = true');
        end
    end
    if (type(slot.commands) == 'table' and #slot.commands > 0) then
        local command_literals = {};
        for _, command in ipairs(slot.commands) do
            table.insert(command_literals, lua_string_literal(command));
        end
        table.insert(parts, ('commands = { %s }'):fmt(table.concat(command_literals, ', ')));
    end

    return parts;
end

local function button_overrides_dir()
    local install_path = safe_read(function ()
        return AshitaCore:GetInstallPath();
    end, nil);

    if (type(install_path) ~= 'string' or install_path == '') then
        return nil;
    end

    if (not install_path:match('[\\/]$')) then
        install_path = install_path .. '\\';
    end

    return install_path .. 'config\\addons\\' .. addon.name .. '\\';
end

local function button_overrides_file_path()
    local dir = button_overrides_dir();
    if (dir == nil) then
        return nil;
    end

    return dir .. 'button_overrides.lua';
end

local function visual_settings_file_path()
    local dir = button_overrides_dir();
    if (dir == nil) then
        return nil;
    end

    return dir .. 'visual_settings.lua';
end

local function ensure_button_overrides_dir()
    local install_path = safe_read(function ()
        return AshitaCore:GetInstallPath();
    end, nil);

    if (type(install_path) ~= 'string' or install_path == '') then
        return false, 'Ashita install path is unavailable.';
    end

    if (not install_path:match('[\\/]$')) then
        install_path = install_path .. '\\';
    end

    local addons_config_dir = install_path .. 'config\\addons\\';
    local dir = addons_config_dir .. addon.name .. '\\';

    if (ashita == nil or ashita.fs == nil) then
        return false, 'Ashita filesystem helpers are unavailable.';
    end

    if (not ashita.fs.exists(addons_config_dir)) then
        ashita.fs.create_dir(addons_config_dir);
    end
    if (not ashita.fs.exists(dir)) then
        ashita.fs.create_dir(dir);
    end

    return true, dir;
end

local function current_runtime_visual_settings()
    local settings = state.config.settings or {};
    local window_x, window_y = bar_window_position(settings);
    local main_profile_scope = BAR.profile_scope('main');
    local main_bar = {
        visible = main_bar_visible(),
        display_mode = display_mode(),
        profile_scope = main_profile_scope,
        button_count = BAR.button_count('main'),
        buttons_per_row = BAR.buttons_per_row('main'),
        keybinds = KEYBIND.effective_bar_keybinds('main'),
        slot_size = slot_size('main'),
        button_gap = button_gap('main'),
        slot_glow_size = slot_glow_size('main'),
        slot_glow_opacity = slot_glow_opacity('main'),
        label_vertical_position = label_vertical_position('main'),
        window_x = window_x,
        window_y = window_y,
    };
    local result = {
        main_bar = main_bar,
        visible = main_bar.visible,
        display_mode = main_bar.display_mode,
        slot_size = main_bar.slot_size,
        button_gap = main_bar.button_gap,
        slot_glow_size = main_bar.slot_glow_size,
        slot_glow_opacity = main_bar.slot_glow_opacity,
        label_vertical_position = main_bar.label_vertical_position,
        window_x = main_bar.window_x,
        window_y = main_bar.window_y,
        show_weaponskill_pulse = MACRO.weaponskill_pulse_enabled(settings),
        bars_unlocked = bar_frame_visible(),
    };

    for _, bar_key in ipairs(BAR.EXTRA_KEYS) do
        local extra_window_x, extra_window_y = BAR.extra_bar_window_position(bar_key, settings);
        local profile_scope = BAR.profile_scope(bar_key);
        local values = {
            visible = BAR.extra_bar_visible(bar_key),
            profile_scope = profile_scope,
            button_count = BAR.button_count(bar_key),
            buttons_per_row = BAR.buttons_per_row(bar_key),
            keybinds = KEYBIND.effective_bar_keybinds(bar_key),
            slot_size = slot_size(bar_key),
            button_gap = button_gap(bar_key),
            slot_glow_size = slot_glow_size(bar_key),
            slot_glow_opacity = slot_glow_opacity(bar_key),
            label_vertical_position = label_vertical_position(bar_key),
            window_x = extra_window_x,
            window_y = extra_window_y,
        };
        result[BAR.SETTINGS_KEY[bar_key]] = values;
        if (bar_key == 'extra1') then
            result.show_click_bar = values.visible;
            result.click_bar_window_x = values.window_x;
            result.click_bar_window_y = values.window_y;
        end
    end

    return result;
end

function BAR.apply_visual_settings(target, settings, bar_key)
    if (type(settings) ~= 'table') then
        return;
    end

    local mode = normalize_display_mode(settings.display_mode);
    local size = normalize_slot_size(settings.slot_size);
    local gap = normalize_button_gap(settings.button_gap);
    local count = BAR.normalize_button_count(settings.button_count);
    local per_row = BAR.normalize_buttons_per_row(settings.buttons_per_row, count or target.button_count or BAR.default_setting(bar_key, 'button_count'));
    local glow_size = normalize_slot_glow_size(settings.slot_glow_size);
    local glow_opacity = normalize_slot_glow_opacity(settings.slot_glow_opacity);
    local label_position = normalize_label_vertical_position(settings.label_vertical_position);
    local profile_scope = BAR.normalize_profile_scope(settings.profile_scope);
    local window_x = tonumber(settings.window_x);
    local window_y = tonumber(settings.window_y);

    if (settings.visible ~= nil) then target.visible = settings.visible ~= false; end
    if (bar_key == 'main' and mode ~= nil) then target.display_mode = mode; end
    if (profile_scope ~= nil) then target.profile_scope = profile_scope; end
    if (count ~= nil) then target.button_count = count; end
    if (per_row ~= nil) then target.buttons_per_row = per_row; end
    KEYBIND.apply_to_target(target, settings, bar_key);
    if (size ~= nil) then target.slot_size = size; end
    if (gap ~= nil) then target.button_gap = gap; end
    if (glow_size ~= nil) then target.slot_glow_size = glow_size; end
    if (glow_opacity ~= nil) then target.slot_glow_opacity = glow_opacity; end
    if (label_position ~= nil) then target.label_vertical_position = label_position; end
    if (window_x ~= nil) then target.window_x = math.floor(window_x + 0.5); end
    if (window_y ~= nil) then target.window_y = math.floor(window_y + 0.5); end
end

local function apply_visual_settings(settings)
    if (type(settings) ~= 'table') then
        return;
    end

    if (type(state.config.settings) ~= 'table') then
        state.config.settings = {};
    end

    local target = state.config.settings;
    if (type(target.main_bar) ~= 'table') then
        target.main_bar = {};
    end
    for _, bar_key in ipairs(BAR.EXTRA_KEYS) do
        local settings_key = BAR.SETTINGS_KEY[bar_key];
        if (type(target[settings_key]) ~= 'table') then
            target[settings_key] = {};
        end
    end

    BAR.apply_visual_settings(target.main_bar, settings.main_bar, 'main');
    for _, bar_key in ipairs(BAR.EXTRA_KEYS) do
        local settings_key = BAR.SETTINGS_KEY[bar_key];
        BAR.apply_visual_settings(target[settings_key], settings[settings_key], bar_key);
    end

    local mode = normalize_display_mode(settings.display_mode);
    local size = normalize_slot_size(settings.slot_size);
    local gap = normalize_button_gap(settings.button_gap);
    local glow_size = normalize_slot_glow_size(settings.slot_glow_size);
    local glow_opacity = normalize_slot_glow_opacity(settings.slot_glow_opacity);
    local label_position = normalize_label_vertical_position(settings.label_vertical_position);
    local profile_scope = BAR.normalize_profile_scope(settings.profile_scope);
    local window_x = tonumber(settings.window_x);
    local window_y = tonumber(settings.window_y);
    local click_bar_window_x = tonumber(settings.click_bar_window_x);
    local click_bar_window_y = tonumber(settings.click_bar_window_y);

    if (settings.visible ~= nil) then target.main_bar.visible = settings.visible ~= false; end
    if (settings.show_weaponskill_pulse ~= nil) then
        target.show_weaponskill_pulse = settings.show_weaponskill_pulse ~= false;
    elseif (settings.show_weaponskill_flames ~= nil) then
        target.show_weaponskill_pulse = settings.show_weaponskill_flames ~= false;
    end
    if (settings.bars_unlocked ~= nil) then
        target.bars_unlocked = settings.bars_unlocked == true;
    end
    if (mode ~= nil) then target.main_bar.display_mode = mode; end
    if (profile_scope ~= nil) then
        if (settings.main_bar == nil or BAR.normalize_profile_scope(settings.main_bar.profile_scope) == nil) then
            target.main_bar.profile_scope = profile_scope;
        end
        if (settings.extra_bar_1 == nil or BAR.normalize_profile_scope(settings.extra_bar_1.profile_scope) == nil) then
            target.extra_bar_1.profile_scope = profile_scope;
        end
    end
    KEYBIND.apply_to_target(target.main_bar, settings, 'main');
    if (size ~= nil) then
        target.main_bar.slot_size = size;
        if (settings.extra_bar_1 == nil) then target.extra_bar_1.slot_size = size; end
    end
    if (gap ~= nil) then
        target.main_bar.button_gap = gap;
        if (settings.extra_bar_1 == nil) then target.extra_bar_1.button_gap = gap; end
    end
    if (glow_size ~= nil) then
        target.main_bar.slot_glow_size = glow_size;
        if (settings.extra_bar_1 == nil) then target.extra_bar_1.slot_glow_size = glow_size; end
    end
    if (glow_opacity ~= nil) then
        target.main_bar.slot_glow_opacity = glow_opacity;
        if (settings.extra_bar_1 == nil) then target.extra_bar_1.slot_glow_opacity = glow_opacity; end
    end
    if (label_position ~= nil) then
        target.main_bar.label_vertical_position = label_position;
        if (settings.extra_bar_1 == nil) then target.extra_bar_1.label_vertical_position = label_position; end
    end
    if (window_x ~= nil) then target.main_bar.window_x = math.floor(window_x + 0.5); end
    if (window_y ~= nil) then target.main_bar.window_y = math.floor(window_y + 0.5); end
    if (settings.show_click_bar ~= nil) then target.extra_bar_1.visible = settings.show_click_bar ~= false; end
    if (click_bar_window_x ~= nil) then target.extra_bar_1.window_x = math.floor(click_bar_window_x + 0.5); end
    if (click_bar_window_y ~= nil) then target.extra_bar_1.window_y = math.floor(click_bar_window_y + 0.5); end

    target.visible = target.main_bar.visible ~= false;
    target.display_mode = target.main_bar.display_mode or target.display_mode;
    target.profile_scope = target.main_bar.profile_scope or target.profile_scope;
    target.slot_size = target.main_bar.slot_size or target.slot_size;
    target.button_gap = target.main_bar.button_gap or target.button_gap;
    target.slot_glow_size = target.main_bar.slot_glow_size or target.slot_glow_size;
    target.slot_glow_opacity = target.main_bar.slot_glow_opacity or target.slot_glow_opacity;
    target.label_vertical_position = target.main_bar.label_vertical_position or target.label_vertical_position;
    target.window_x = target.main_bar.window_x or target.window_x;
    target.window_y = target.main_bar.window_y or target.window_y;
    target.show_click_bar = target.extra_bar_1.visible ~= false;
    target.click_bar_window_x = target.extra_bar_1.window_x or target.click_bar_window_x;
    target.click_bar_window_y = target.extra_bar_1.window_y or target.click_bar_window_y;
end

local function serialize_visual_settings(settings)
    local main = settings.main_bar or {};
    local lines = {
        '-- Generated by AshitaBars. Runtime visual settings are stored here.',
        '-- This file lives outside the addon folder so installs do not reset placement, sizing, or keybinds.',
        'return {',
        '    settings = {',
    };

    local function append_bar(settings_key, bar_key, values, include_display_mode)
        values = type(values) == 'table' and values or {};
        table.insert(lines, ('        %s = {'):fmt(settings_key));
        table.insert(lines, ('            visible = %s,'):fmt(tostring(values.visible ~= false)));
        if (include_display_mode) then
            table.insert(lines, ('            display_mode = %s,'):fmt(lua_string_literal(values.display_mode or settings.display_mode)));
        end
        table.insert(lines, ('            profile_scope = %s,'):fmt(lua_string_literal(values.profile_scope or settings.profile_scope or 'job')));
        table.insert(lines, ('            button_count = %d,'):fmt(values.button_count or 10));
        table.insert(lines, ('            buttons_per_row = %d,'):fmt(values.buttons_per_row or values.button_count or 10));
        for _, line in ipairs(KEYBIND.serialize_lines(values.keybinds, '            ', bar_key)) do
            table.insert(lines, line);
        end
        table.insert(lines, ('            slot_size = %d,'):fmt(values.slot_size or settings.slot_size));
        table.insert(lines, ('            button_gap = %d,'):fmt(values.button_gap or settings.button_gap));
        table.insert(lines, ('            slot_glow_size = %d,'):fmt(values.slot_glow_size or settings.slot_glow_size));
        table.insert(lines, ('            slot_glow_opacity = %d,'):fmt(values.slot_glow_opacity or settings.slot_glow_opacity));
        table.insert(lines, ('            label_vertical_position = %d,'):fmt(values.label_vertical_position or settings.label_vertical_position));
        table.insert(lines, ('            window_x = %d,'):fmt(values.window_x or settings.window_x or settings.click_bar_window_x));
        table.insert(lines, ('            window_y = %d,'):fmt(values.window_y or settings.window_y or settings.click_bar_window_y));
        table.insert(lines, '        },');
    end

    append_bar('main_bar', 'main', main, true);
    for _, bar_key in ipairs(BAR.EXTRA_KEYS) do
        append_bar(BAR.SETTINGS_KEY[bar_key], bar_key, settings[BAR.SETTINGS_KEY[bar_key]], false);
    end

    local extra = settings.extra_bar_1 or {};
    for _, line in ipairs({
        ('        display_mode = %s,'):fmt(lua_string_literal(settings.display_mode)),
        ('        profile_scope = %s,'):fmt(lua_string_literal(settings.profile_scope or main.profile_scope or 'job')),
        ('        show_weaponskill_pulse = %s,'):fmt(tostring(settings.show_weaponskill_pulse ~= false)),
        ('        bars_unlocked = %s,'):fmt(tostring(settings.bars_unlocked == true)),
        ('        slot_size = %d,'):fmt(settings.slot_size),
        ('        button_gap = %d,'):fmt(settings.button_gap),
        ('        slot_glow_size = %d,'):fmt(settings.slot_glow_size),
        ('        slot_glow_opacity = %d,'):fmt(settings.slot_glow_opacity),
        ('        label_vertical_position = %d,'):fmt(settings.label_vertical_position),
        ('        window_x = %d,'):fmt(settings.window_x),
        ('        window_y = %d,'):fmt(settings.window_y),
        ('        show_click_bar = %s,'):fmt(tostring(extra.visible ~= false)),
        ('        click_bar_window_x = %d,'):fmt(extra.window_x or settings.click_bar_window_x),
        ('        click_bar_window_y = %d,'):fmt(extra.window_y or settings.click_bar_window_y),
        '    },',
        '}',
        '',
    }) do
        table.insert(lines, line);
    end

    return table.concat(lines, '\n');
end

DEFERRED.load_visual_settings = function ()
    local path = visual_settings_file_path();
    if (path == nil or ashita == nil or ashita.fs == nil or not ashita.fs.exists(path)) then
        return true;
    end

    local chunk, load_err = loadfile(path);
    if (chunk == nil) then
        log_warn(('Visual settings ignored: %s'):fmt(tostring(load_err)));
        return false;
    end

    local ok, visual_config = pcall(chunk);
    if (not ok or type(visual_config) ~= 'table') then
        log_warn(('Visual settings ignored: %s'):fmt(tostring(visual_config)));
        return false;
    end

    apply_visual_settings(visual_config.settings or visual_config);
    return true;
end

local function save_visual_settings()
    local ok, dir_or_err = ensure_button_overrides_dir();
    if (not ok) then
        return false, ('Save failed: %s'):fmt(tostring(dir_or_err));
    end

    local settings = current_runtime_visual_settings();
    local path = dir_or_err .. 'visual_settings.lua';
    local write_ok, write_err = write_text_file(path, serialize_visual_settings(settings));
    if (not write_ok) then
        return false, ('Save failed: could not write visual_settings.lua (%s).'):fmt(tostring(write_err));
    end

    apply_visual_settings(settings);
    state.display_mode_override = nil;
    state.slot_size_override = nil;
    state.button_gap_override = nil;
    state.slot_glow_size_override = nil;
    state.slot_glow_opacity_override = nil;
    state.label_vertical_position_override = nil;
    state.keybind_overrides = {};
    state.keybind_capture = nil;
    state.main_bar_profile_scope_override = nil;
    state.main_bar_visible_override = nil;
    state.main_bar_button_count_override = nil;
    state.main_bar_buttons_per_row_override = nil;
    state.click_bar_profile_scope_override = nil;
    state.click_bar_visible_override = nil;
    state.click_bar_button_count_override = nil;
    state.click_bar_buttons_per_row_override = nil;
    state.click_bar_slot_size_override = nil;
    state.click_bar_button_gap_override = nil;
    state.click_bar_slot_glow_size_override = nil;
    state.click_bar_slot_glow_opacity_override = nil;
    state.click_bar_label_vertical_position_override = nil;
    state.extra_bar_overrides = {};
    state.bar_window_x = settings.window_x;
    state.bar_window_y = settings.window_y;
    state.bar_anchor_x = settings.window_x;
    state.bar_anchor_y = settings.window_y;
    state.click_bar_window_x = settings.click_bar_window_x;
    state.click_bar_window_y = settings.click_bar_window_y;
    state.click_bar_anchor_x = settings.click_bar_window_x;
    state.click_bar_anchor_y = settings.click_bar_window_y;
    for _, bar_key in ipairs(BAR.EXTRA_KEYS) do
        local values = settings[BAR.SETTINGS_KEY[bar_key]];
        if (type(values) == 'table') then
            local runtime = BAR.extra_runtime(bar_key);
            runtime.window_x = values.window_x;
            runtime.window_y = values.window_y;
            runtime.anchor_x = values.window_x;
            runtime.anchor_y = values.window_y;
        end
    end
    state.profile = nil;

    return true, 'Saved visual settings to config/addons/ashitabars/visual_settings.lua.';
end

local function sanitize_slot_override(slot, allow_shared)
    if (type(slot) ~= 'table') then
        return nil;
    end

    local shared_name = (allow_shared ~= false) and SHARED.normalize_name(slot.shared) or nil;
    if (shared_name ~= nil) then
        return { shared = shared_name };
    end

    local sanitized = {};
    if (slot.label ~= nil) then
        sanitized.label = trim_one_line(slot.label, LIMITS.macro_label_max);
    end
    local use_action_name_label = slot.use_action_name_label;
    if (use_action_name_label == nil) then
        use_action_name_label = slot.use_item_name_label;
    end
    if (use_action_name_label ~= nil) then
        sanitized.use_action_name_label = use_action_name_label ~= false;
    end
    if (slot.command ~= nil) then
        sanitized.command = MACRO.sanitize_command_line(slot.command);
    end
    if (slot.commands ~= nil) then
        sanitized.commands = MACRO.commands_from_table(slot.commands);
        if (#sanitized.commands == 0) then
            sanitized.commands = nil;
        end
    end
    if (slot.macro_mode ~= nil or sanitized.commands ~= nil) then
        sanitized.macro_mode = MACRO.normalize_mode(slot.macro_mode);
        if (sanitized.commands ~= nil and slot.macro_mode == nil) then
            sanitized.macro_mode = 'multi';
        end
        if (sanitized.macro_mode == 'multi' and sanitized.commands == nil and sanitized.command ~= nil and sanitized.command ~= '') then
            sanitized.commands = { sanitized.command };
        end
        if (sanitized.macro_mode == 'multi' and sanitized.commands ~= nil and sanitized.command == nil) then
            sanitized.command = sanitized.commands[1] or '';
        end
        if (sanitized.macro_mode ~= 'multi') then
            sanitized.macro_mode = nil;
            sanitized.commands = nil;
            sanitized.script = nil;
        elseif (slot.script == true) then
            sanitized.script = true;
        end
    end
    if (slot.icon ~= nil) then
        local icon = trim_one_line(slot.icon, LIMITS.macro_icon_max);
        if (icon ~= '') then
            sanitized.icon = icon;
        end
    end
    local weaponskill_effect = MACRO.normalize_weaponskill_effect_style(slot.weaponskill_effect);
    if (slot.weaponskill_effect_enabled == false) then
        weaponskill_effect = 'off';
    end
    if (weaponskill_effect ~= nil) then
        sanitized.weaponskill_effect = weaponskill_effect;
    end
    local weaponskill_effect_intensity = MACRO.normalize_weaponskill_effect_intensity(slot.weaponskill_effect_intensity);
    if (weaponskill_effect_intensity ~= nil) then
        sanitized.weaponskill_effect_intensity = weaponskill_effect_intensity;
    end
    local weaponskill_effect_opacity = MACRO.normalize_weaponskill_effect_opacity(slot.weaponskill_effect_opacity);
    if (weaponskill_effect_opacity ~= nil) then
        sanitized.weaponskill_effect_opacity = weaponskill_effect_opacity;
    end
    local weaponskill_effect_frequency = MACRO.normalize_weaponskill_effect_frequency(slot.weaponskill_effect_frequency);
    if (weaponskill_effect_frequency ~= nil) then
        sanitized.weaponskill_effect_frequency = weaponskill_effect_frequency;
    end
    local config_key = COMMAND_MODE.normalize_config_id(slot.config_key);
    local config_value_a = COMMAND_MODE.normalize_config_value(slot.config_value_a);
    local config_value_b = COMMAND_MODE.normalize_config_value(slot.config_value_b);
    if (config_key ~= nil) then
        sanitized.config_key = config_key;
    end
    if (config_value_a ~= nil) then
        sanitized.config_value_a = config_value_a;
    end
    if (config_value_b ~= nil) then
        sanitized.config_value_b = config_value_b;
    end

    if (sanitized.label == nil and sanitized.command == nil and sanitized.commands == nil and sanitized.macro_mode == nil and sanitized.icon == nil and sanitized.use_action_name_label == nil and sanitized.weaponskill_effect == nil and sanitized.weaponskill_effect_intensity == nil and sanitized.weaponskill_effect_opacity == nil and sanitized.weaponskill_effect_frequency == nil and sanitized.config_key == nil and sanitized.config_value_a == nil and sanitized.config_value_b == nil) then
        return nil;
    end

    return sanitized;
end

local function sanitize_button_overrides(overrides)
    local sanitized = { profiles = {}, shared = {} };
    if (type(overrides) ~= 'table') then
        return sanitized;
    end

    local shared_source = (type(overrides.shared) == 'table') and overrides.shared or overrides.shared_buttons;
    if (type(shared_source) == 'table') then
        for name, slot in pairs(shared_source) do
            local shared_name = SHARED.normalize_name(name);
            local sanitized_slot = sanitize_slot_override(slot, false);
            if (shared_name ~= nil and sanitized_slot ~= nil) then
                sanitized.shared[shared_name] = sanitized_slot;
            end
        end
    end

    if (type(overrides.profiles) == 'table') then
        for profile_key, profile in pairs(overrides.profiles) do
            local normalized_profile_key = normalize_profile_key(tostring(profile_key));
            if (normalized_profile_key ~= nil and type(profile) == 'table') then
                local sanitized_profile = {};
                for _, row in ipairs(BUTTON_ROWS) do
                    local row_overrides = profile[row.id];
                    if (type(row_overrides) == 'table') then
                        local sanitized_row = {};
                        for index = 1, LIMITS.button_count_max do
                            local slot = sanitize_slot_override(row_overrides[index], true);
                            if (slot ~= nil) then
                                sanitized_row[index] = slot;
                            end
                        end
                        if (next(sanitized_row) ~= nil) then
                            sanitized_profile[row.id] = sanitized_row;
                        end
                    end
                end
                if (next(sanitized_profile) ~= nil) then
                    sanitized.profiles[normalized_profile_key] = sanitized_profile;
                end
            end
        end
    end

    return sanitized;
end

DEFERRED.load_button_overrides = function ()
    local path = button_overrides_file_path();
    if (path == nil or ashita == nil or ashita.fs == nil or not ashita.fs.exists(path)) then
        state.macro_overrides = { profiles = {}, shared = {} };
        return true;
    end

    local chunk, load_err = loadfile(path);
    if (chunk == nil) then
        state.macro_overrides = { profiles = {}, shared = {} };
        log_warn(('Button overrides ignored: %s'):fmt(tostring(load_err)));
        return false;
    end

    local ok, overrides = pcall(chunk);
    if (not ok or type(overrides) ~= 'table') then
        state.macro_overrides = { profiles = {}, shared = {} };
        log_warn(('Button overrides ignored: %s'):fmt(tostring(overrides)));
        return false;
    end

    state.macro_overrides = sanitize_button_overrides(overrides);
    return true;
end

local function serialize_button_overrides()
    local lines = {
        '-- Generated by AshitaBars. Runtime button edits are stored here.',
        '-- Each saved button executes only from an attended key press or click.',
        'return {',
        '    shared = {',
    };

    local shared = (state.macro_overrides and state.macro_overrides.shared) or {};
    for _, name in ipairs(sorted_keys(shared)) do
        local parts = SHARED.slot_parts(shared[name]);
        if (#parts > 0) then
            table.insert(lines, ('        [%s] = { %s },'):fmt(lua_string_literal(name), table.concat(parts, ', ')));
        end
    end

    table.insert(lines, '    },');
    table.insert(lines, '    profiles = {');

    local profiles = (state.macro_overrides and state.macro_overrides.profiles) or {};
    for _, profile_key in ipairs(sorted_keys(profiles)) do
        local profile = profiles[profile_key];
        if (type(profile) == 'table') then
            table.insert(lines, ('        [%s] = {'):fmt(lua_string_literal(profile_key)));
            for _, row in ipairs(BUTTON_ROWS) do
                local row_overrides = profile[row.id];
                if (type(row_overrides) == 'table' and next(row_overrides) ~= nil) then
                    table.insert(lines, ('            %s = {'):fmt(row.id));
                    for index = 1, LIMITS.button_count_max do
                        local slot = row_overrides[index];
                        if (type(slot) == 'table') then
                            local parts = SHARED.slot_parts(slot);
                            if (#parts > 0) then
                                table.insert(lines, ('                [%d] = { %s },'):fmt(index, table.concat(parts, ', ')));
                            end
                        end
                    end
                    table.insert(lines, '            },');
                end
            end
            table.insert(lines, '        },');
        end
    end

    table.insert(lines, '    },');
    table.insert(lines, '}');
    table.insert(lines, '');
    return table.concat(lines, '\n');
end

local function save_button_overrides()
    local ok, dir_or_err = ensure_button_overrides_dir();
    if (not ok) then
        return false, ('Save failed: %s'):fmt(tostring(dir_or_err));
    end

    local path = dir_or_err .. 'button_overrides.lua';
    local write_ok, write_err = write_text_file(path, serialize_button_overrides());
    if (not write_ok) then
        return false, ('Save failed: could not write button_overrides.lua (%s).'):fmt(tostring(write_err));
    end

    return true, 'Saved button edits to config/addons/ashitabars/button_overrides.lua.';
end

local function replace_setting(block, key, literal)
    local escaped_key = key:gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])', '%%%1');
    local pattern = '([\r\n][ \t]*)(' .. escaped_key .. '%s*=%s*)([^,\r\n]+)(,?)';
    local updated, count = block:gsub(pattern, function (prefix, assign, _, comma)
        return prefix .. assign .. literal .. ((comma ~= '') and comma or ',');
    end, 1);

    if (count > 0) then
        return updated;
    end

    local setting_indent = block:match('\n([ \t]*)[%w_]+%s*=') or '        ';
    local close_indent = block:match('\n([ \t]*)%}%s*$') or '    ';
    return block:gsub('%s*}$', ('\n%s%s = %s,\n%s}'):fmt(setting_indent, key, literal, close_indent), 1);
end

local function save_runtime_settings()
    return save_visual_settings();
end

local function copy_slot(slot)
    local copied = {};
    if (type(slot) == 'table') then
        for key, value in pairs(slot) do
            copied[key] = (type(value) == 'table') and copy_slot(value) or value;
        end
    end

    return copied;
end

local function get_profile_override(profile_key)
    local normalized = normalize_profile_key(profile_key);
    local overrides = state.macro_overrides or {};
    local profiles = overrides.profiles or {};
    if (normalized == nil or type(profiles) ~= 'table') then
        return nil;
    end

    return profiles[normalized];
end

local function get_slot_override(profile_key, group, index)
    if (not valid_row_id(group) or type(index) ~= 'number') then
        return nil;
    end

    local profile = get_profile_override(profile_key);
    local row = type(profile) == 'table' and profile[group] or nil;
    local slot = type(row) == 'table' and row[index] or nil;
    if (type(slot) ~= 'table') then
        return nil;
    end

    return slot;
end

local function editable_profile_key(profile)
    if (type(profile) ~= 'table') then
        profile = refresh_profile_context();
    end

    local key = normalize_profile_key(profile.edit_key or profile.key);
    if (key ~= nil and key ~= 'BARS') then
        return key;
    end

    return 'DEFAULT';
end

local function get_raw_config_slot(profile, group, index)
    if (type(profile) ~= 'table') then
        profile = refresh_profile_context();
    end

    local bars = profile.bars or {};
    local row = type(bars) == 'table' and bars[group] or nil;
    local slot = type(row) == 'table' and row[index] or nil;
    if (type(slot) ~= 'table') then
        return nil;
    end

    return slot;
end

local function apply_slot_override(base_slot, override)
    if (type(override) ~= 'table') then
        return base_slot;
    end

    local shared_name = SHARED.normalize_name(override.shared);
    if (shared_name ~= nil) then
        return { shared = shared_name };
    end

    local slot = copy_slot(base_slot);
    if (override.label ~= nil) then
        slot.label = override.label;
    end
    local use_action_name_label = override.use_action_name_label;
    if (use_action_name_label == nil) then
        use_action_name_label = override.use_item_name_label;
    end
    if (use_action_name_label ~= nil) then
        slot.use_action_name_label = use_action_name_label ~= false;
    end
    if (override.command ~= nil) then
        slot.command = override.command;
    end
    if (override.macro_mode ~= nil) then
        slot.macro_mode = override.macro_mode;
    end
    if (override.commands ~= nil) then
        slot.commands = MACRO.commands_from_table(override.commands);
    end
    if (override.script ~= nil) then
        slot.script = override.script == true;
    end
    if (override.icon ~= nil) then
        slot.icon = override.icon;
    end
    if (override.weaponskill_effect ~= nil) then
        slot.weaponskill_effect = override.weaponskill_effect;
    end
    if (override.weaponskill_effect_intensity ~= nil) then
        slot.weaponskill_effect_intensity = override.weaponskill_effect_intensity;
    end
    if (override.weaponskill_effect_opacity ~= nil) then
        slot.weaponskill_effect_opacity = override.weaponskill_effect_opacity;
    end
    if (override.weaponskill_effect_frequency ~= nil) then
        slot.weaponskill_effect_frequency = override.weaponskill_effect_frequency;
    end
    if (override.config_key ~= nil) then
        slot.config_key = override.config_key;
    end
    if (override.config_value_a ~= nil) then
        slot.config_value_a = override.config_value_a;
    end
    if (override.config_value_b ~= nil) then
        slot.config_value_b = override.config_value_b;
    end

    if (next(slot) == nil) then
        return nil;
    end

    return slot;
end

function SHARED.resolve_slot(slot)
    if (type(slot) ~= 'table') then
        return nil;
    end

    local shared_name = SHARED.normalize_name(slot.shared);
    if (shared_name == nil) then
        return slot;
    end

    local definition = SHARED.definition(shared_name);
    if (definition == nil) then
        return {
            shared = shared_name,
            label = shared_name,
            command = '',
            icon = 'command',
        };
    end

    local resolved = copy_slot(definition);
    resolved.shared = shared_name;
    return resolved;
end

function MACRO.normalize_slot_runtime(slot)
    if (type(slot) ~= 'table') then
        return nil;
    end

    local normalized = copy_slot(slot);
    local mode = MACRO.normalize_mode(normalized.macro_mode);
    local commands = MACRO.commands_from_table(normalized.commands);
    local command = MACRO.sanitize_command_line(normalized.command);

    if (mode == 'multi' or #commands > 0) then
        if (#commands == 0 and command ~= '') then
            commands = { command };
        end
        normalized.macro_mode = 'multi';
        normalized.commands = commands;
        normalized.command = commands[1] or command;
        normalized.script = normalized.script == true;
    else
        normalized.macro_mode = 'single';
        normalized.commands = nil;
        normalized.command = command;
        normalized.script = nil;
    end
    if (normalized.use_action_name_label == nil and normalized.use_item_name_label ~= nil) then
        normalized.use_action_name_label = normalized.use_item_name_label ~= false;
        normalized.use_item_name_label = nil;
    elseif (normalized.use_action_name_label ~= nil) then
        normalized.use_action_name_label = normalized.use_action_name_label ~= false;
    end
    normalized.weaponskill_effect = MACRO.weaponskill_effect_style(normalized);
    normalized.weaponskill_effect_intensity = MACRO.normalize_weaponskill_effect_intensity(normalized.weaponskill_effect_intensity) or 70;
    normalized.weaponskill_effect_opacity = MACRO.normalize_weaponskill_effect_opacity(normalized.weaponskill_effect_opacity) or 100;
    normalized.weaponskill_effect_frequency = MACRO.normalize_weaponskill_effect_frequency(normalized.weaponskill_effect_frequency) or 100;
    normalized.config_key = COMMAND_MODE.normalize_config_id(normalized.config_key);
    normalized.config_value_a = COMMAND_MODE.normalize_config_value(normalized.config_value_a);
    normalized.config_value_b = COMMAND_MODE.normalize_config_value(normalized.config_value_b);

    return normalized;
end

function MACRO.slot_mode(slot)
    if (type(slot) ~= 'table') then
        return 'single';
    end

    if (MACRO.normalize_mode(slot.macro_mode) == 'multi' or type(slot.commands) == 'table') then
        return 'multi';
    end

    return 'single';
end

function MACRO.slot_commands(slot)
    if (type(slot) ~= 'table') then
        return {};
    end

    if (MACRO.slot_mode(slot) == 'multi') then
        local commands = MACRO.commands_from_table(slot.commands);
        if (#commands == 0) then
            local fallback = MACRO.sanitize_command_line(slot.command);
            if (fallback ~= '') then
                commands = { fallback };
            end
        end
        return commands;
    end

    local command = MACRO.sanitize_command_line(slot.command);
    return (command ~= '') and { command } or {};
end

function MACRO.primary_command(slot)
    local commands = MACRO.slot_commands(slot);
    return commands[1] or '';
end

local function apply_editor_preview(slot, profile_key, group, index)
    local editor = state.macro_editor;
    if (editor == nil or not editor.visible[1]) then
        return slot;
    end

    if (normalize_profile_key(profile_key) ~= normalize_profile_key(editor.profile_key) or editor.group ~= group or editor.index ~= index) then
        return slot;
    end

    local preview_slot = copy_slot(slot);
    local mode = MACRO.normalize_mode(editor.macro_mode);
    if (mode == 'multi') then
        preview_slot.script = editor.run_as_script[1] == true;
    else
        preview_slot.script = nil;
    end
    if (mode ~= 'item') then
        preview_slot.icon = trim_one_line(editor.icon_buffer[1], LIMITS.macro_icon_max);
    end
    preview_slot.weaponskill_effect = editor.weaponskill_effect_enabled[1] == false and 'off' or (MACRO.normalize_weaponskill_effect_style(editor.weaponskill_effect) or 'pulse');
    preview_slot.weaponskill_effect_intensity = MACRO.normalize_weaponskill_effect_intensity(editor.weaponskill_effect_intensity[1]) or 70;
    preview_slot.weaponskill_effect_opacity = MACRO.normalize_weaponskill_effect_opacity(editor.weaponskill_effect_opacity[1]) or 100;
    preview_slot.weaponskill_effect_frequency = MACRO.normalize_weaponskill_effect_frequency(editor.weaponskill_effect_frequency[1]) or 100;
    return preview_slot;
end

local function get_slot(group, index)
    local bar_key = BAR.key_for_group(group);
    local profile = (type(state.profile) == 'table' and state.profile.bar_key == bar_key) and state.profile or refresh_profile_context(bar_key);
    local profile_key = editable_profile_key(profile);
    local slot = get_raw_config_slot(profile, group, index);
    local override = get_slot_override(profile_key, group, index);
    slot = apply_slot_override(slot, override);
    slot = SHARED.resolve_slot(slot);
    slot = apply_editor_preview(slot, profile_key, group, index);
    slot = MACRO.normalize_slot_runtime(slot);
    if (type(slot) ~= 'table') then
        return nil;
    end

    return slot;
end

function MACRO.get_slot_without_editor_preview(profile, profile_key, group, index)
    local slot = get_raw_config_slot(profile, group, index);
    local override = get_slot_override(profile_key, group, index);
    slot = apply_slot_override(slot, override);
    slot = SHARED.resolve_slot(slot);
    return MACRO.normalize_slot_runtime(slot);
end

function MACRO.slot_has_action(slot)
    if (type(slot) ~= 'table') then
        return false;
    end

    if (SHARED.normalize_name(slot.shared) ~= nil) then
        return true;
    end

    return #MACRO.slot_commands(slot) > 0;
end

function BAR.modifier_slot_enabled(group, index)
    if (BAR.group_modifier(group) == nil) then
        return true;
    end

    return MACRO.slot_has_action(get_slot(group, index));
end

function BAR.visual_row_for_index(parent_group, index)
    parent_group = parent_group or 'base';
    local active = active_group();
    local modifier_row_id = BAR.modifier_row_id(parent_group, active);
    if (modifier_row_id ~= nil and BAR.modifier_slot_enabled(modifier_row_id, index)) then
        return ROW_BY_ID[modifier_row_id] or ROW_BY_ID[parent_group] or ROW_BY_ID.base;
    end

    return ROW_BY_ID[parent_group] or ROW_BY_ID.base;
end

function KEYBIND.slot_enabled_for_binding(bar_key, row_id, index)
    if (tonumber(index) == nil or tonumber(index) > BAR.button_count(bar_key)) then
        return false;
    end
    if (BAR.group_modifier(row_id) ~= nil) then
        return BAR.modifier_slot_enabled(row_id, index);
    end

    return true;
end

COMMAND_MODE.ORDER = {
    'single',
    'multi',
    'spell',
    'item',
    'mount',
    'server',
    'configtoggle',
    'trusts',
    'weaponskill',
    'ability',
    'pet',
    'ranged',
    'target',
};

COMMAND_MODE.DEFS = {
    single      = { label = 'Freeform Command' },
    multi       = { label = 'Multi-Line Macro' },
    spell       = { label = 'Spell', action_label = 'Spell', empty_label = 'No usable learned spells found.' },
    item        = { label = 'Item', action_label = 'Item', empty_label = 'No inventory items found.' },
    mount       = { label = 'Mount', action_label = 'Mount', empty_label = 'No mount names found.' },
    server      = { label = 'Server Command', action_label = 'Server Command', empty_label = 'No server commands configured.' },
    configtoggle = { label = 'Config Toggle' },
    trusts      = { label = 'Trusts Addon', action_label = 'Trusts Action', empty_label = 'No FancyTrusts actions configured.' },
    weaponskill = { label = 'Weapon Skill', action_label = 'Weapon Skill', empty_label = 'No known weapon skills found.' },
    ability     = { label = 'Job Ability', action_label = 'Job Ability', empty_label = 'No known job abilities found.' },
    pet         = { label = 'Pet Command', action_label = 'Pet Command', empty_label = 'No usable pet commands found.' },
    ranged      = { label = 'Ranged Attack', action_label = 'Action' },
    target      = { label = 'Target / Assist', action_label = 'Action' },
};

COMMAND_MODE.TARGETS = {
    spell       = { '<t>', '<stpt>', '<stpc>', '<me>', '<bt>' },
    ability     = { '<t>', '<me>', '<bt>', '<stpc>', '<stpt>' },
    pet         = { '<t>', '<bt>', '<me>' },
    weaponskill = { '<t>', '<bt>' },
    ranged      = { '<t>', '<bt>' },
    target      = { '<bt>', '<t>', '<stpc>', '<stpt>', '<me>' },
};

COMMAND_MODE.TARGET_LABELS = {
    ['<t>']    = 'Current Target (<t>)',
    ['<bt>']   = 'Battle Target (<bt>)',
    ['<me>']   = 'Self (<me>)',
    ['<stpc>'] = 'Select PC (<stpc>)',
    ['<stpt>'] = 'Select Party (<stpt>)',
};

COMMAND_MODE.TARGET_ACTIONS = {
    { prefix = '/target', label = 'Target' },
    { prefix = '/assist', label = 'Assist' },
    { prefix = '/attack', label = 'Attack' },
    { prefix = '/check',  label = 'Check' },
};

COMMAND_MODE.SPELL_TYPE_OPTIONS = {
    { key = 'all',       label = 'All Types' },
    { key = 'white',     label = 'White Magic' },
    { key = 'black',     label = 'Black Magic' },
    { key = 'summoning', label = 'Summoning' },
    { key = 'ninjutsu',  label = 'Ninjutsu' },
    { key = 'song',      label = 'Songs' },
    { key = 'blue',      label = 'Blue Magic' },
    { key = 'geomancy',  label = 'Geomancy' },
    { key = 'trust',     label = 'Trusts' },
    { key = 'other',     label = 'Other' },
};

COMMAND_MODE.SPELL_ELEMENT_OPTIONS = {
    { key = 'all',       label = 'All Elements' },
    { key = 'fire',      label = 'Fire' },
    { key = 'ice',       label = 'Ice' },
    { key = 'wind',      label = 'Wind' },
    { key = 'earth',     label = 'Earth' },
    { key = 'lightning', label = 'Lightning' },
    { key = 'water',     label = 'Water' },
    { key = 'light',     label = 'Light' },
    { key = 'dark',      label = 'Dark' },
    { key = 'none',      label = 'Non-Elemental' },
};

COMMAND_MODE.ITEM_SOURCE_OPTIONS = {
    { key = 'all',       label = 'All Sources' },
    { key = 'inventory', label = 'Inventory' },
    { key = 'temporary', label = 'Temporary' },
};

COMMAND_MODE.ITEM_SOURCE_BY_CONTAINER = {
    [0] = { key = 'inventory', label = 'Inventory' },
    [3] = { key = 'temporary', label = 'Temporary' },
};

COMMAND_MODE.SERVER_COMMANDS = {
    {
        name = 'Signet',
        command = '!signet',
        buff = 'Signet',
        icon = 'signet',
        zone_dynamic = true,
    },
};

COMMAND_MODE.SIGNET_ZONE_COMMANDS = {
    old_world = { command = '!signet',   buff = 'Signet',   icon = 'signet',   zone_label = 'Old-world / normal leveling' },
    past      = { command = '!sigil',    buff = 'Sigil',    icon = 'sigil',    zone_label = 'Past [S] / Campaign' },
    aht_urhgan = { command = '!sanction', buff = 'Sanction', icon = 'sanction', zone_label = 'Aht Urhgan' },
    adoulin   = { command = '!ionis',    buff = 'Ionis',    icon = 'ionis',    zone_label = 'Adoulin' },
};

COMMAND_MODE.SIGNET_SERVER_COMMAND_KEYS = {
    ['!signet'] = true,
    ['!sigil'] = true,
    ['!sanction'] = true,
    ['!ionis'] = true,
};

COMMAND_MODE.TRUSTS_ACTIONS = {
    {
        name = 'Open Trusts Window',
        command = '/trusts',
        detail = 'FancyTrusts UI',
        icon = 'summon',
        search_keywords = 'fancytrusts trusts ui window open',
    },
    {
        name = 'Summon Preset 1',
        command = '/trusts p1',
        detail = 'FancyTrusts preset p1',
        icon = 'summon',
        search_keywords = 'fancytrusts trusts summon preset p1 1',
    },
    {
        name = 'Summon Preset 2',
        command = '/trusts p2',
        detail = 'FancyTrusts preset p2',
        icon = 'summon',
        search_keywords = 'fancytrusts trusts summon preset p2 2',
    },
    {
        name = 'Summon Preset 3',
        command = '/trusts p3',
        detail = 'FancyTrusts preset p3',
        icon = 'summon',
        search_keywords = 'fancytrusts trusts summon preset p3 3',
    },
    {
        name = 'Summon Preset 4',
        command = '/trusts p4',
        detail = 'FancyTrusts preset p4',
        icon = 'summon',
        search_keywords = 'fancytrusts trusts summon preset p4 4',
    },
    {
        name = 'Summon Preset 5',
        command = '/trusts p5',
        detail = 'FancyTrusts preset p5',
        icon = 'summon',
        search_keywords = 'fancytrusts trusts summon preset p5 5',
    },
};

COMMAND_MODE.SPELL_TYPE_BY_RESOURCE_TYPE = {
    [2] = 'white',
    [3] = 'black',
    [4] = 'summoning',
    [5] = 'ninjutsu',
    [6] = 'song',
    [7] = 'blue',
    [8] = 'geomancy',
    [9] = 'trust',
};

COMMAND_MODE.SPELL_TYPE_BY_SKILL = {
    [33] = 'white',
    [34] = 'white',
    [35] = 'white',
    [36] = 'white',
    [37] = 'black',
    [38] = 'black',
    [39] = 'summoning',
    [40] = 'ninjutsu',
    [41] = 'song',
    [44] = 'blue',
    [45] = 'geomancy',
};

COMMAND_MODE.SPELL_ELEMENT_BY_RESOURCE_ELEMENT = {
    [1] = 'fire',
    [2] = 'ice',
    [3] = 'wind',
    [4] = 'earth',
    [5] = 'lightning',
    [6] = 'water',
    [7] = 'light',
    [8] = 'dark',
    [16] = 'none',
};

function COMMAND_MODE.mode_label(mode)
    mode = MACRO.normalize_mode(mode);
    return (COMMAND_MODE.DEFS[mode] and COMMAND_MODE.DEFS[mode].label) or COMMAND_MODE.DEFS.single.label;
end

function COMMAND_MODE.mode_available(mode)
    mode = MACRO.normalize_mode(mode);
    if (mode == 'pet') then
        return #COMMAND_MODE.actions('pet') > 0;
    end

    return true;
end

function COMMAND_MODE.pet_command_default_target(name)
    local key = COMMAND_MODE.clean_name(name):lower():gsub('[%s%-]+', '');
    if (key == 'heel' or key == 'stay' or key == 'leave' or key == 'release' or key == 'retreat'
        or key == 'retrieve' or key == 'deactivate' or key == 'dismiss' or key == 'unsummon') then
        return '<me>';
    end

    return '<t>';
end

function COMMAND_MODE.clean_name(value)
    if (type(value) ~= 'string') then
        return '';
    end

    return trim_string(value:gsub('%z', ''));
end

function COMMAND_MODE.resource_name(resource)
    if (resource == nil) then
        return '';
    end

    local name = safe_read(function () return resource.Name[1]; end, nil)
        or safe_read(function () return resource.Name[2]; end, nil)
        or safe_read(function () return resource.Name[0]; end, nil);

    return COMMAND_MODE.clean_name(name);
end

function COMMAND_MODE.player_is_mounted()
    local player = safe_read(function ()
        return AshitaCore:GetMemoryManager():GetPlayer();
    end, nil);
    local resources = safe_read(function ()
        return AshitaCore:GetResourceManager();
    end, nil);
    local icons = player ~= nil and safe_read(function ()
        return player:GetStatusIcons();
    end, nil) or nil;

    if (icons == nil or resources == nil) then
        return false;
    end

    for slot = 0, 31, 1 do
        local icon = tonumber(safe_read(function ()
            return icons[slot + 1];
        end, nil));
        if (icon ~= nil and icon > 0 and icon ~= 255) then
            local name = COMMAND_MODE.clean_name(safe_read(function ()
                return resources:GetString('buffs.names', icon);
            end, '')):lower();
            if (name == 'mount' or name == 'mounted' or name == 'chocobo') then
                return true;
            end
        end
    end

    return false;
end

function COMMAND_MODE.current_status_lookup()
    if (state.command_mode_cache == nil) then
        state.command_mode_cache = {};
    end

    local now = os.clock();
    local cached = state.command_mode_cache.status_lookup;
    if (cached ~= nil and cached.lookup ~= nil and (now - cached.at) <= 0.25) then
        return cached.lookup;
    end

    local lookup = {};
    local player = safe_read(function ()
        return AshitaCore:GetMemoryManager():GetPlayer();
    end, nil);
    local resources = safe_read(function ()
        return AshitaCore:GetResourceManager();
    end, nil);
    local icons = player ~= nil and safe_read(function ()
        return player:GetStatusIcons();
    end, nil) or nil;

    if (icons ~= nil and resources ~= nil) then
        for slot = 0, 31, 1 do
            local icon = tonumber(safe_read(function ()
                return icons[slot + 1];
            end, nil));
            if (icon ~= nil and icon > 0 and icon ~= 255) then
                local name = COMMAND_MODE.clean_name(safe_read(function ()
                    return resources:GetString('buffs.names', icon);
                end, '')):lower();
                if (name ~= '') then
                    lookup[name] = true;
                end
            end
        end
    end

    state.command_mode_cache.status_lookup = { at = now, lookup = lookup };
    return lookup;
end

function COMMAND_MODE.player_has_status(status_name)
    status_name = COMMAND_MODE.clean_name(status_name):lower();
    if (status_name == '') then
        return false;
    end

    return COMMAND_MODE.current_status_lookup()[status_name] == true;
end

function COMMAND_MODE.current_zone_id()
    return tonumber(safe_read(function ()
        return AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0);
    end, nil));
end

function COMMAND_MODE.signet_zone_command_for_zone(zone_id)
    zone_id = tonumber(zone_id);
    if (zone_id == nil) then
        return COMMAND_MODE.SIGNET_ZONE_COMMANDS.old_world;
    end

    if (zone_id >= 48 and zone_id < 80) then
        return COMMAND_MODE.SIGNET_ZONE_COMMANDS.aht_urhgan;
    end
    if ((zone_id >= 256 and zone_id < 294) or zone_id == 299) then
        return COMMAND_MODE.SIGNET_ZONE_COMMANDS.adoulin;
    end
    if ((zone_id >= 80 and zone_id < 100)
        or (zone_id >= 136 and zone_id < 139)
        or zone_id == 155
        or zone_id == 156
        or zone_id == 164
        or zone_id == 171
        or zone_id == 175) then
        return COMMAND_MODE.SIGNET_ZONE_COMMANDS.past;
    end

    return COMMAND_MODE.SIGNET_ZONE_COMMANDS.old_world;
end

function COMMAND_MODE.current_signet_zone_command()
    return COMMAND_MODE.signet_zone_command_for_zone(COMMAND_MODE.current_zone_id());
end

function COMMAND_MODE.server_runtime_action(action)
    if (type(action) ~= 'table') then
        return nil;
    end
    if (action.zone_dynamic ~= true) then
        return action;
    end

    local zone_command = COMMAND_MODE.current_signet_zone_command();
    return {
        name = action.name,
        command = zone_command.command,
        buff = zone_command.buff,
        icon = zone_command.icon or action.icon,
        zone_label = zone_command.zone_label,
        zone_dynamic = true,
    };
end

function COMMAND_MODE.start_mount_recast_overlay()
    local total = 60;
    local now = os.time();
    local overlay = state.mount_recast_overlay;
    if (type(overlay) == 'table' and (tonumber(overlay.expires_at) or 0) > now) then
        return;
    end

    state.mount_recast_overlay = {
        started_at = now,
        total = total,
        expires_at = now + total,
    };
end

function COMMAND_MODE.mount_recast_overlay_info()
    local overlay = state.mount_recast_overlay;
    if (type(overlay) ~= 'table') then
        return nil;
    end

    local now = os.time();
    local remaining = (tonumber(overlay.expires_at) or 0) - now;
    if (remaining <= 0) then
        state.mount_recast_overlay = nil;
        return nil;
    end

    local total = math.max(1, tonumber(overlay.total) or 60);
    return {
        timer = remaining,
        total = total,
    };
end

function COMMAND_MODE.resource_id(resource)
    if (resource == nil) then
        return nil;
    end

    return tonumber(safe_read(function () return resource.Id; end, safe_read(function () return resource.Index; end, nil)));
end

function COMMAND_MODE.option_label(options, key, fallback)
    for _, option in ipairs(options or {}) do
        if (option.key == key) then
            return option.label;
        end
    end

    return fallback or tostring(key or '');
end

function COMMAND_MODE.add_action(list, lookup, name, id, detail, meta)
    name = COMMAND_MODE.clean_name(name);
    if (name == '') then
        return;
    end

    local key = name:lower();
    if (lookup[key] ~= nil) then
        if (detail ~= nil and detail ~= '' and lookup[key].detail == nil) then
            lookup[key].detail = detail;
        end
        if (type(meta) == 'table') then
            for meta_key, meta_value in pairs(meta) do
                if (lookup[key][meta_key] == nil) then
                    lookup[key][meta_key] = meta_value;
                end
            end
        end
        return;
    end

    local action = {
        name = name,
        id = id,
        detail = detail,
    };
    if (type(meta) == 'table') then
        for meta_key, meta_value in pairs(meta) do
            action[meta_key] = meta_value;
        end
    end
    lookup[key] = action;
    table.insert(list, action);
end

function COMMAND_MODE.sort_actions(list)
    table.sort(list, function (left, right)
        if (left.name == right.name) then
            return (tonumber(left.id) or 0) < (tonumber(right.id) or 0);
        end

        return left.name < right.name;
    end);
    return list;
end

function COMMAND_MODE.current_player_state()
    local player = safe_read(function ()
        return AshitaCore:GetMemoryManager():GetPlayer();
    end, nil);
    if (player == nil) then
        return nil;
    end

    local main_job = safe_read(function () return player:GetMainJob(); end, nil);
    local sub_job = safe_read(function () return player:GetSubJob(); end, nil);
    return {
        player = player,
        main_job = main_job,
        sub_job = sub_job,
        main_level = safe_read(function () return player:GetMainJobLevel(); end, nil),
        sub_level = safe_read(function () return player:GetSubJobLevel(); end, nil),
        has_spell_data = safe_read(function () return player:HasSpellData(); end, false),
        has_ability_data = safe_read(function () return player:HasAbilityData(); end, false),
    };
end

function COMMAND_MODE.spell_level_required(spell, job_id)
    if (spell == nil or spell.LevelRequired == nil or job_id == nil or job_id <= 0) then
        return nil;
    end

    local level = tonumber(safe_read(function ()
        return spell.LevelRequired[job_id + 1];
    end, nil));
    if (level == nil or level < 0 or level > 99) then
        return nil;
    end

    return level;
end

function COMMAND_MODE.spell_usable_for_current_job(spell, player_state)
    if (spell == nil or player_state == nil or spell.LevelRequired == nil) then
        return true;
    end

    local main_required = COMMAND_MODE.spell_level_required(spell, player_state.main_job);
    if (main_required ~= nil and player_state.main_level ~= nil and player_state.main_level >= main_required) then
        return true;
    end

    local sub_required = COMMAND_MODE.spell_level_required(spell, player_state.sub_job);
    if (sub_required ~= nil and player_state.sub_level ~= nil and player_state.sub_level >= sub_required) then
        return true;
    end

    return false;
end

function COMMAND_MODE.parse_command(command)
    if (type(command) ~= 'string') then
        return nil, nil, '', '';
    end

    local prefix, rest = command:match('^%s*(/%S+)%s*(.*)$');
    if (prefix == nil) then
        return nil, nil, '', '';
    end

    local name = nil;
    local remainder = '';
    rest = rest or '';
    name, remainder = rest:match('^"([^"]*)"%s*(.*)$');
    if (name == nil) then
        name, remainder = rest:match("^'([^']*)'%s*(.*)$");
    end
    if (name == nil) then
        name, remainder = rest:match('^(%S+)%s*(.*)$');
    end

    return prefix:lower(), COMMAND_MODE.clean_name(name), trim_string(remainder or ''), trim_string(rest);
end

function COMMAND_MODE.config_number(value)
    if (type(value) == 'number') then
        if (value ~= value) then
            return nil;
        end
        return math.floor(value);
    end
    if (type(value) ~= 'string') then
        return nil;
    end

    value = trim_string(value);
    if (value == '') then
        return nil;
    end
    if (value:match('^%-?%d+$') == nil and value:match('^0[xX]%x+$') == nil) then
        return nil;
    end

    local number = tonumber(value);
    if (number == nil or number ~= number) then
        return nil;
    end

    return math.floor(number);
end

function COMMAND_MODE.normalize_config_id(value)
    local id = COMMAND_MODE.config_number(value);
    if (id == nil or id < 1 or id > 207) then
        return nil;
    end

    return id;
end

function COMMAND_MODE.normalize_config_value(value)
    return COMMAND_MODE.config_number(value);
end

function COMMAND_MODE.parse_config_command(command)
    local prefix, action, remainder = COMMAND_MODE.parse_command(command);
    if (prefix ~= '/config') then
        return nil;
    end

    action = type(action) == 'string' and action:lower() or '';
    if (action == 'get') then
        local id_text = trim_string(remainder);
        local id = COMMAND_MODE.normalize_config_id(id_text);
        if (id == nil or id_text:find('%s') ~= nil) then
            return { action = action, error = 'Invalid config get syntax. Use /config get <id>.' };
        end
        return { action = action, id = id };
    end

    if (action == 'set') then
        local id_text, value_text = trim_string(remainder):match('^(%S+)%s+(%S+)$');
        local id = COMMAND_MODE.normalize_config_id(id_text);
        local value = COMMAND_MODE.normalize_config_value(value_text);
        if (id == nil or value == nil) then
            return { action = action, error = 'Invalid config set syntax. Use /config set <id> <value>.' };
        end
        return { action = action, id = id, value = value };
    end

    return { action = action, error = 'Only /config get and /config set are supported.' };
end

function COMMAND_MODE.config_value_getter()
    if (COMMAND_MODE.config_getter ~= nil) then
        return COMMAND_MODE.config_getter;
    end

    local ptr = safe_read(function ()
        return ashita.memory.find('FFXiMain.dll', 0, '8B0D????????85C974??8B44240450E8????????C383C8FFC3', 0, 0);
    end, nil);
    if (ptr == nil or ptr == 0) then
        return nil;
    end

    local ok, getter = pcall(function ()
        return ffi.cast('ashitabars_get_config_value_t', ptr);
    end);
    if (not ok or getter == nil) then
        return nil;
    end

    COMMAND_MODE.config_getter = getter;
    return getter;
end

function COMMAND_MODE.current_config_value(id)
    id = COMMAND_MODE.normalize_config_id(id);
    if (id == nil) then
        return nil, 'Invalid config id.';
    end

    local getter = COMMAND_MODE.config_value_getter();
    if (getter == nil) then
        return nil, 'Config reader unavailable.';
    end

    local ok, value = pcall(function ()
        return getter(id);
    end);
    if (not ok) then
        return nil, 'Config read failed.';
    end

    return tonumber(value), nil;
end

function COMMAND_MODE.config_toggle_values_from_editor(editor)
    if (editor == nil) then
        return nil, nil, nil;
    end

    return COMMAND_MODE.normalize_config_id(editor.config_key_buffer[1]),
        COMMAND_MODE.normalize_config_value(editor.config_value_a_buffer[1]),
        COMMAND_MODE.normalize_config_value(editor.config_value_b_buffer[1]);
end

function COMMAND_MODE.config_toggle_values_from_slot(slot)
    if (type(slot) ~= 'table') then
        return nil, nil, nil;
    end

    return COMMAND_MODE.normalize_config_id(slot.config_key),
        COMMAND_MODE.normalize_config_value(slot.config_value_a),
        COMMAND_MODE.normalize_config_value(slot.config_value_b);
end

function COMMAND_MODE.config_toggle_validation_error(id, value_a, value_b)
    if (id == nil) then
        return 'Enter a config key from 1 to 207.';
    end
    if (value_a == nil) then
        return 'Enter the first toggle value.';
    end
    if (value_b == nil) then
        return 'Enter the second toggle value.';
    end
    if (value_a == value_b) then
        return 'Toggle values must be different.';
    end

    return nil;
end

function COMMAND_MODE.config_toggle_next_command(id, value_a, value_b)
    local current, err = COMMAND_MODE.current_config_value(id);
    if (current == nil) then
        return nil, err;
    end

    local next_value = (current == value_a) and value_b or value_a;
    return ('/config set %d %d'):fmt(id, next_value), nil, current, next_value;
end

function COMMAND_MODE.server_command_key(command)
    if (type(command) ~= 'string') then
        return nil;
    end

    local text = trim_string(command):lower();
    local direct = text:match('^(![%w_%-]+)$');
    if (direct ~= nil) then
        return direct;
    end

    local prefix, _, _, raw_rest = COMMAND_MODE.parse_command(command);
    if (prefix ~= '/say' and prefix ~= '/s') then
        return nil;
    end

    return trim_string(raw_rest):lower():match('^(![%w_%-]+)$');
end

function COMMAND_MODE.server_action_by_key(command_key)
    if (type(command_key) ~= 'string' or command_key == '') then
        return nil;
    end

    command_key = command_key:lower();
    if (COMMAND_MODE.SIGNET_SERVER_COMMAND_KEYS[command_key] == true) then
        return COMMAND_MODE.SERVER_COMMANDS[1];
    end

    for _, action in ipairs(COMMAND_MODE.SERVER_COMMANDS) do
        if (type(action.command) == 'string' and action.command:lower() == command_key) then
            return action;
        end
    end

    return nil;
end

function COMMAND_MODE.server_action_by_name(name)
    name = COMMAND_MODE.clean_name(name);
    if (name == '') then
        return nil;
    end

    local key = name:lower();
    for _, action in ipairs(COMMAND_MODE.SERVER_COMMANDS) do
        if ((type(action.name) == 'string' and action.name:lower() == key)
            or (type(action.command) == 'string' and action.command:lower() == key)
            or COMMAND_MODE.SIGNET_SERVER_COMMAND_KEYS['!' .. key] == true) then
            return action;
        end
    end

    return nil;
end

function COMMAND_MODE.server_action_for_command(command)
    return COMMAND_MODE.server_action_by_key(COMMAND_MODE.server_command_key(command));
end

function COMMAND_MODE.trusts_command_key(command)
    if (type(command) ~= 'string') then
        return nil;
    end

    local prefix, _, _, raw_rest = COMMAND_MODE.parse_command(command);
    if (prefix ~= '/trusts') then
        return nil;
    end

    local rest = trim_string(raw_rest):lower();
    if (rest == '') then
        return '/trusts';
    end

    local preset = rest:match('^p([1-5])$');
    if (preset ~= nil) then
        return '/trusts p' .. preset;
    end

    return nil;
end

function COMMAND_MODE.trusts_action_by_key(command_key)
    if (type(command_key) ~= 'string' or command_key == '') then
        return nil;
    end

    command_key = command_key:lower();
    for _, action in ipairs(COMMAND_MODE.TRUSTS_ACTIONS) do
        if (type(action.command) == 'string' and action.command:lower() == command_key) then
            return action;
        end
    end

    return nil;
end

function COMMAND_MODE.trusts_action_by_name(name)
    name = COMMAND_MODE.clean_name(name);
    if (name == '') then
        return nil;
    end

    local key = name:lower();
    for _, action in ipairs(COMMAND_MODE.TRUSTS_ACTIONS) do
        if ((type(action.name) == 'string' and action.name:lower() == key)
            or (type(action.command) == 'string' and action.command:lower() == key)) then
            return action;
        end
    end

    return nil;
end

function COMMAND_MODE.trusts_action_for_command(command)
    return COMMAND_MODE.trusts_action_by_key(COMMAND_MODE.trusts_command_key(command));
end

function COMMAND_MODE.mode_from_command(command)
    if (COMMAND_MODE.server_action_for_command(command) ~= nil) then
        return 'server';
    end
    if (COMMAND_MODE.trusts_action_for_command(command) ~= nil) then
        return 'trusts';
    end

    local prefix = COMMAND_MODE.parse_command(command);
    if (prefix == '/ma' or prefix == '/magic') then
        return 'spell';
    end
    if (prefix == '/item') then
        return 'item';
    end
    if (prefix == '/mount') then
        return 'mount';
    end
    if (prefix == '/config') then
        local parsed = COMMAND_MODE.parse_config_command(command);
        if (parsed ~= nil and (parsed.action == 'get' or parsed.action == 'set') and parsed.error == nil) then
            return 'configtoggle';
        end
    end
    if (prefix == '/ws' or prefix == '/weaponskill') then
        return 'weaponskill';
    end
    if (prefix == '/ja' or prefix == '/jobability') then
        return 'ability';
    end
    if (prefix == '/pet') then
        return 'pet';
    end
    if (prefix == '/ra' or prefix == '/range' or prefix == '/shoot') then
        return 'ranged';
    end
    if (prefix == '/target' or prefix == '/targetnpc' or prefix == '/targetbnpc' or prefix == '/assist' or prefix == '/attack' or prefix == '/check') then
        return 'target';
    end

    return 'single';
end

function COMMAND_MODE.is_structured_mode(mode)
    mode = MACRO.normalize_mode(mode);
    return mode ~= 'single' and mode ~= 'multi';
end

function COMMAND_MODE.mode_for_slot(slot)
    if (MACRO.slot_mode(slot) == 'multi') then
        return 'multi';
    end

    local command_mode = COMMAND_MODE.mode_from_command(MACRO.primary_command(slot));
    if (command_mode ~= 'single') then
        return command_mode;
    end

    local configured_mode = MACRO.normalize_mode(type(slot) == 'table' and slot.macro_mode or nil);
    if (COMMAND_MODE.is_structured_mode(configured_mode)) then
        return configured_mode;
    end

    return 'single';
end

function COMMAND_MODE.command_action_for_mode(mode, command)
    local prefix, name, target, raw_rest = COMMAND_MODE.parse_command(command);
    mode = MACRO.normalize_mode(mode);
    if (mode == 'ranged') then
        return 'Ranged Attack', raw_rest ~= '' and raw_rest or COMMAND_MODE.default_target(mode);
    end
    if (mode == 'target') then
        return prefix or '/target', raw_rest ~= '' and raw_rest or COMMAND_MODE.default_target(mode);
    end
    if (mode == 'item') then
        return name or '', '<me>';
    end
    if (mode == 'mount') then
        return name or '', '';
    end
    if (mode == 'server') then
        local server_action = COMMAND_MODE.server_action_for_command(command);
        return server_action ~= nil and server_action.name or '', '';
    end
    if (mode == 'trusts') then
        local trusts_action = COMMAND_MODE.trusts_action_for_command(command);
        return trusts_action ~= nil and trusts_action.name or '', '';
    end
    if (mode == 'configtoggle') then
        local parsed = COMMAND_MODE.parse_config_command(command);
        return parsed ~= nil and parsed.id ~= nil and tostring(parsed.id) or '', '';
    end
    if (mode == 'pet') then
        return name or '', target ~= '' and target or COMMAND_MODE.pet_command_default_target(name);
    end
    if (mode == 'spell' or mode == 'weaponskill' or mode == 'ability') then
        return name or '', target ~= '' and target or COMMAND_MODE.default_target(mode);
    end

    return '', COMMAND_MODE.default_target(mode);
end

function COMMAND_MODE.default_target(mode)
    local targets = COMMAND_MODE.TARGETS[MACRO.normalize_mode(mode)] or {};
    return targets[1] or '<t>';
end

function COMMAND_MODE.load_editor_slot(editor, slot)
    if (editor == nil) then
        return;
    end

    local mode = COMMAND_MODE.mode_for_slot(slot);
    local action, target = COMMAND_MODE.command_action_for_mode(mode, MACRO.primary_command(slot));
    editor.macro_mode = mode;
    editor.command_action = action or '';
    editor.command_target = target or COMMAND_MODE.default_target(mode);
    editor.run_as_script[1] = mode == 'multi' and slot ~= nil and slot.script == true;
    editor.use_action_name_label[1] = COMMAND_MODE.is_structured_mode(mode) and (slot == nil or slot.use_action_name_label ~= false) or false;
    editor.spell_type_filter = 'all';
    editor.spell_element_filter = 'all';
    buffer_set(editor.spell_search_buffer, '');
    editor.item_source_filter = 'all';
    buffer_set(editor.item_search_buffer, '');
    buffer_set(editor.weaponskill_search_buffer, '');
    buffer_set(editor.ability_search_buffer, '');
    buffer_set(editor.pet_search_buffer, '');
    buffer_set(editor.mount_search_buffer, '');
    buffer_set(editor.server_search_buffer, '');
    buffer_set(editor.trusts_search_buffer, '');
    local config_key, config_value_a, config_value_b = COMMAND_MODE.config_toggle_values_from_slot(slot);
    if (mode == 'configtoggle') then
        buffer_set(editor.config_key_buffer, config_key ~= nil and tostring(config_key) or action or '');
        buffer_set(editor.config_value_a_buffer, config_value_a ~= nil and tostring(config_value_a) or '0');
        buffer_set(editor.config_value_b_buffer, config_value_b ~= nil and tostring(config_value_b) or '1');
    else
        buffer_set(editor.config_key_buffer, '');
        buffer_set(editor.config_value_a_buffer, '0');
        buffer_set(editor.config_value_b_buffer, '1');
    end
    if (mode == 'target') then
        editor.target_action = action or '/target';
    end
end

function COMMAND_MODE.quote_action_name(name)
    name = COMMAND_MODE.clean_name(name);
    if (name == '') then
        return '';
    end

    return name:gsub('"', '');
end

function COMMAND_MODE.editor_command(mode, editor)
    mode = MACRO.normalize_mode(mode);
    if (editor == nil) then
        return '';
    end

    local action = COMMAND_MODE.quote_action_name(editor.command_action);
    local target = trim_string(editor.command_target);
    if (target == '') then
        target = COMMAND_MODE.default_target(mode);
    end

    if (mode == 'spell') then
        return (action ~= '') and ('/ma "%s" %s'):fmt(action, target) or '';
    end
    if (mode == 'item') then
        return (action ~= '') and ('/item "%s" <me>'):fmt(action) or '';
    end
    if (mode == 'mount') then
        return (action ~= '') and ('/mount "%s"'):fmt(action) or '';
    end
    if (mode == 'server') then
        local server_action = COMMAND_MODE.server_action_by_name(action);
        return (server_action ~= nil) and ('/say %s'):fmt(server_action.command) or '';
    end
    if (mode == 'trusts') then
        local trusts_action = COMMAND_MODE.trusts_action_by_name(action);
        return (trusts_action ~= nil) and trusts_action.command or '';
    end
    if (mode == 'configtoggle') then
        local id = COMMAND_MODE.normalize_config_id(editor.config_key_buffer[1]);
        return (id ~= nil) and ('/config get %d'):fmt(id) or '';
    end
    if (mode == 'weaponskill') then
        return (action ~= '') and ('/ws "%s" %s'):fmt(action, target) or '';
    end
    if (mode == 'ability') then
        return (action ~= '') and ('/ja "%s" %s'):fmt(action, target) or '';
    end
    if (mode == 'pet') then
        return (action ~= '') and ('/pet "%s" %s'):fmt(action, target) or '';
    end
    if (mode == 'ranged') then
        return ('/ra %s'):fmt(target);
    end
    if (mode == 'target') then
        local prefix = editor.target_action or '/target';
        return ('%s %s'):fmt(prefix, target);
    end

    return '';
end

function COMMAND_MODE.configured_action_fallback(mode, list, lookup)
    for _, row in ipairs(BUTTON_ROWS) do
        for index = 1, LIMITS.button_count_max do
            local slot = get_slot(row.id, index);
            local commands = MACRO.slot_commands(slot);
            for _, command in ipairs(commands) do
                if (COMMAND_MODE.mode_from_command(command) == mode) then
                    local _, name = COMMAND_MODE.parse_command(command);
                    COMMAND_MODE.add_action(list, lookup, name, nil, 'configured');
                end
            end
        end
    end
end

function COMMAND_MODE.spell_type_key(spell, spell_name)
    spell_name = COMMAND_MODE.clean_name(spell_name);
    if (spell_name:lower():match('^trust:') ~= nil) then
        return 'trust';
    end

    local skill_id = tonumber(spell ~= nil and safe_read(function () return spell.Skill; end, nil));
    if (skill_id == 0) then
        return 'trust';
    end

    local type_id = tonumber(spell ~= nil and safe_read(function () return spell.Type; end, nil));
    local from_type = COMMAND_MODE.SPELL_TYPE_BY_RESOURCE_TYPE[type_id];
    if (from_type ~= nil) then
        return from_type;
    end

    return COMMAND_MODE.SPELL_TYPE_BY_SKILL[skill_id] or 'other';
end

function COMMAND_MODE.spell_element_key(spell)
    local element_id = tonumber(spell ~= nil and safe_read(function () return spell.Element; end, nil));
    return COMMAND_MODE.SPELL_ELEMENT_BY_RESOURCE_ELEMENT[element_id] or 'none';
end

function COMMAND_MODE.spell_action_meta(spell, name)
    local spell_type = COMMAND_MODE.spell_type_key(spell, name);
    local element = COMMAND_MODE.spell_element_key(spell);
    return {
        spell_type = spell_type,
        spell_type_label = COMMAND_MODE.option_label(COMMAND_MODE.SPELL_TYPE_OPTIONS, spell_type, 'Other'),
        spell_element = element,
        spell_element_label = COMMAND_MODE.option_label(COMMAND_MODE.SPELL_ELEMENT_OPTIONS, element, 'Non-Elemental'),
    };
end

function COMMAND_MODE.spell_actions()
    local list = {};
    local lookup = {};
    local state_info = COMMAND_MODE.current_player_state();
    local resources = safe_read(function () return AshitaCore:GetResourceManager(); end, nil);
    if (state_info ~= nil and resources ~= nil and state_info.has_spell_data) then
        for id = 0, 2048, 1 do
            if (safe_read(function () return state_info.player:HasSpell(id); end, false)) then
                local spell = safe_read(function () return resources:GetSpellById(id); end, nil);
                if (spell ~= nil and COMMAND_MODE.spell_usable_for_current_job(spell, state_info)) then
                    local mp = tonumber(safe_read(function () return spell.ManaCost; end, nil));
                    local name = COMMAND_MODE.resource_name(spell);
                    COMMAND_MODE.add_action(list, lookup, name, id, mp ~= nil and ('MP %d'):fmt(mp) or nil, COMMAND_MODE.spell_action_meta(spell, name));
                end
            end
        end
    end

    COMMAND_MODE.configured_action_fallback('spell', list, lookup);
    return COMMAND_MODE.sort_actions(list);
end

function COMMAND_MODE.item_actions()
    local list = {};
    local lookup = {};
    local inventory = safe_read(function () return AshitaCore:GetMemoryManager():GetInventory(); end, nil);
    local resources = safe_read(function () return AshitaCore:GetResourceManager(); end, nil);
    if (inventory ~= nil and resources ~= nil) then
        for _, container_id in ipairs(LIMITS.item_count_containers) do
            local max = tonumber(safe_read(function ()
                return inventory:GetContainerCountMax(container_id);
            end, 0)) or 0;

            for slot = 0, max, 1 do
                local item = safe_read(function ()
                    return inventory:GetContainerItem(container_id, slot);
                end, nil);
                local id = item ~= nil and tonumber(item.Id) or nil;
                if (id ~= nil and id > 0 and id ~= 65535) then
                    local resource = safe_read(function ()
                        return resources:GetItemById(id);
                    end, nil);
                    local name = COMMAND_MODE.resource_name(resource);
                    if (name ~= '') then
                        local count = DEFERRED.item_count(id);
                        local source = COMMAND_MODE.ITEM_SOURCE_BY_CONTAINER[container_id] or { key = 'other', label = 'Other' };
                        COMMAND_MODE.add_action(list, lookup, name, id, count ~= nil and ('x%d'):fmt(count) or nil, {
                            item_source = source.key,
                            item_source_label = source.label,
                        });
                    end
                end
            end
        end
    end

    COMMAND_MODE.configured_action_fallback('item', list, lookup);
    return COMMAND_MODE.sort_actions(list);
end

function COMMAND_MODE.action_by_name(mode, name)
    name = COMMAND_MODE.clean_name(name);
    if (name == '') then
        return nil;
    end

    for _, action in ipairs(COMMAND_MODE.actions(mode)) do
        if (action.name == name) then
            return action;
        end
    end

    return {
        name = name,
    };
end

function COMMAND_MODE.item_resource(item_id, item_name)
    local resources = safe_read(function ()
        return AshitaCore:GetResourceManager();
    end, nil);
    if (resources == nil) then
        return nil;
    end

    item_id = tonumber(item_id);
    if (item_id ~= nil and item_id > 0) then
        local by_id = safe_read(function ()
            return resources:GetItemById(item_id);
        end, nil);
        if (by_id ~= nil) then
            return by_id;
        end
    end

    item_name = COMMAND_MODE.clean_name(item_name);
    if (item_name ~= '') then
        return safe_read(function ()
            return resources:GetItemByName(item_name, 0);
        end, safe_read(function ()
            return resources:GetItemByName(item_name);
        end, nil));
    end

    return nil;
end

function COMMAND_MODE.selected_item_action(editor)
    if (editor == nil) then
        return nil, nil;
    end

    local action = COMMAND_MODE.action_by_name('item', editor.command_action);
    if (action == nil) then
        return nil, nil;
    end

    local resource = COMMAND_MODE.item_resource(action.id, action.name);
    if (action.id == nil and resource ~= nil) then
        action.id = COMMAND_MODE.resource_id(resource);
    end

    return action, resource;
end

function COMMAND_MODE.editor_item_label(editor)
    if (editor == nil) then
        return '';
    end

    local action, resource = COMMAND_MODE.selected_item_action(editor);
    local resource_name = COMMAND_MODE.resource_name(resource);
    if (resource_name ~= '') then
        return trim_one_line(resource_name, LIMITS.macro_label_max);
    end
    if (action ~= nil and COMMAND_MODE.clean_name(action.name) ~= '') then
        return trim_one_line(action.name, LIMITS.macro_label_max);
    end

    return trim_one_line(editor.command_action, LIMITS.macro_label_max);
end

function COMMAND_MODE.target_action_label(prefix)
    prefix = type(prefix) == 'string' and prefix:lower() or '/target';
    for _, action in ipairs(COMMAND_MODE.TARGET_ACTIONS) do
        if (action.prefix == prefix) then
            return action.label;
        end
    end

    return 'Target';
end

function COMMAND_MODE.editor_action_label(editor, mode)
    mode = MACRO.normalize_mode(mode or (editor ~= nil and editor.macro_mode) or 'single');
    if (mode == 'item') then
        return COMMAND_MODE.editor_item_label(editor);
    end
    if (mode == 'target') then
        return trim_one_line(COMMAND_MODE.target_action_label(editor ~= nil and editor.target_action or nil), LIMITS.macro_label_max);
    end
    if (mode == 'ranged') then
        return 'Ranged Attack';
    end
    if (mode == 'configtoggle') then
        local id = COMMAND_MODE.normalize_config_id(editor ~= nil and editor.config_key_buffer[1] or nil);
        return trim_one_line(id ~= nil and ('Config %d'):fmt(id) or 'Config Toggle', LIMITS.macro_label_max);
    end

    return trim_one_line(editor ~= nil and editor.command_action or '', LIMITS.macro_label_max);
end

function COMMAND_MODE.apply_editor_action_label(editor, mode)
    local label = COMMAND_MODE.editor_action_label(editor, mode);
    if (label ~= '') then
        buffer_set(editor.label_buffer, label);
    end

    return label;
end

function COMMAND_MODE.editor_selection_validation_error(mode, editor)
    mode = MACRO.normalize_mode(mode);
    if (mode == 'configtoggle') then
        local id, value_a, value_b = COMMAND_MODE.config_toggle_values_from_editor(editor);
        return COMMAND_MODE.config_toggle_validation_error(id, value_a, value_b);
    end
    if (COMMAND_MODE.clean_name(editor ~= nil and editor.command_action or '') == '') then
        if (mode == 'spell') then
            return 'Choose a spell.';
        end
        if (mode == 'item') then
            return 'Choose an item.';
        end
        if (mode == 'mount') then
            return 'Choose a mount.';
        end
        if (mode == 'server') then
            return 'Choose a server command.';
        end
        if (mode == 'trusts') then
            return 'Choose a trusts addon action.';
        end
        if (mode == 'weaponskill') then
            return 'Choose a weapon skill.';
        end
        if (mode == 'ability') then
            return 'Choose a job ability.';
        end
        if (mode == 'pet') then
            return 'Choose a pet command.';
        end
    end

    return nil;
end

function COMMAND_MODE.ensure_texture_state()
    if (state.item_texture_cache == nil) then
        state.item_texture_cache = {};
    end
    if (state.item_texture_handles == nil) then
        state.item_texture_handles = {};
    end

    if (COMMAND_MODE.d3d == nil) then
        local ok, d3d = pcall(require, 'd3d8');
        if (not ok or d3d == nil) then
            COMMAND_MODE.d3d = false;
            return false;
        end

        COMMAND_MODE.d3d = d3d;
        COMMAND_MODE.d3d_device = d3d.get_device();
    end

    return COMMAND_MODE.d3d ~= false and COMMAND_MODE.d3d_device ~= nil;
end

function COMMAND_MODE.item_icon_handle(item_id, resource)
    item_id = tonumber(item_id);
    if (item_id == nil or item_id <= 0) then
        return nil;
    end
    if (state.item_texture_handles ~= nil and state.item_texture_handles[item_id] ~= nil) then
        return state.item_texture_handles[item_id];
    end
    if (state.item_texture_cache ~= nil and state.item_texture_cache[item_id] == false) then
        return nil;
    end
    if (not COMMAND_MODE.ensure_texture_state()) then
        return nil;
    end

    resource = resource or COMMAND_MODE.item_resource(item_id, nil);
    local image_size = resource ~= nil and tonumber(safe_read(function () return resource.ImageSize; end, nil)) or nil;
    local bitmap = resource ~= nil and safe_read(function () return resource.Bitmap; end, nil) or nil;
    if (bitmap == nil or image_size == nil or image_size <= 0) then
        state.item_texture_cache[item_id] = false;
        return nil;
    end

    local ok, handle = pcall(function ()
        local texture_ptr = ffi.new('IDirect3DTexture8*[1]');
        local result = ffi.C.D3DXCreateTextureFromFileInMemoryEx(
            COMMAND_MODE.d3d_device,
            bitmap,
            image_size,
            0xFFFFFFFF,
            0xFFFFFFFF,
            1,
            0,
            ffi.C.D3DFMT_A8R8G8B8,
            ffi.C.D3DPOOL_MANAGED,
            ffi.C.D3DX_DEFAULT,
            ffi.C.D3DX_DEFAULT,
            0xFF000000,
            nil,
            nil,
            texture_ptr);

        if (result ~= ffi.C.S_OK) then
            return nil;
        end

        local texture = COMMAND_MODE.d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', texture_ptr[0]));
        state.item_texture_cache[item_id] = texture;
        state.item_texture_handles[item_id] = tonumber(ffi.cast('uint32_t', texture));
        return state.item_texture_handles[item_id];
    end);

    if (not ok or handle == nil) then
        state.item_texture_cache[item_id] = false;
        return nil;
    end

    return handle;
end

function ICON_ART_STYLE.addon_dir_path()
    local source = safe_read(function ()
        local info = debug.getinfo(1, 'S');
        return info and info.source or nil;
    end, nil);

    if (type(source) == 'string') then
        if (source:sub(1, 1) == '@') then
            source = source:sub(2);
        end

        local dir = source:match('^(.*[\\/])');
        if (dir ~= nil) then
            return dir;
        end
    end

    return nil;
end

function ICON_ART_STYLE.asset_path(file_name)
    if (type(file_name) ~= 'string' or not file_name:match('^[%w_%-]+%.png$')) then
        return nil;
    end

    local dir = ICON_ART_STYLE.addon_dir_path();
    if (dir == nil) then
        return nil;
    end

    return dir .. 'assets\\icons\\' .. file_name;
end

function ICON_ART_STYLE.asset_icon_handle(file_name)
    if (type(file_name) ~= 'string' or not file_name:match('^[%w_%-]+%.png$')) then
        return nil;
    end

    if (state.icon_asset_texture_handles ~= nil and state.icon_asset_texture_handles[file_name] ~= nil) then
        return state.icon_asset_texture_handles[file_name];
    end
    if (state.icon_asset_texture_cache ~= nil and state.icon_asset_texture_cache[file_name] == false) then
        return nil;
    end
    if (not COMMAND_MODE.ensure_texture_state()) then
        return nil;
    end

    if (state.icon_asset_texture_cache == nil) then
        state.icon_asset_texture_cache = {};
    end
    if (state.icon_asset_texture_handles == nil) then
        state.icon_asset_texture_handles = {};
    end

    local path = ICON_ART_STYLE.asset_path(file_name);
    local bytes = path ~= nil and read_text_file(path) or nil;
    if (type(bytes) ~= 'string' or #bytes == 0) then
        state.icon_asset_texture_cache[file_name] = false;
        return nil;
    end

    local ok, handle = pcall(function ()
        local texture_ptr = ffi.new('IDirect3DTexture8*[1]');
        local result = ffi.C.D3DXCreateTextureFromFileInMemoryEx(
            COMMAND_MODE.d3d_device,
            bytes,
            #bytes,
            0xFFFFFFFF,
            0xFFFFFFFF,
            1,
            0,
            ffi.C.D3DFMT_A8R8G8B8,
            ffi.C.D3DPOOL_MANAGED,
            ffi.C.D3DX_DEFAULT,
            ffi.C.D3DX_DEFAULT,
            0xFF000000,
            nil,
            nil,
            texture_ptr);

        if (result ~= ffi.C.S_OK) then
            return nil;
        end

        local texture = COMMAND_MODE.d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', texture_ptr[0]));
        state.icon_asset_texture_cache[file_name] = texture;
        state.icon_asset_texture_handles[file_name] = tonumber(ffi.cast('uint32_t', texture));
        return state.icon_asset_texture_handles[file_name];
    end);

    if (not ok or handle == nil) then
        state.icon_asset_texture_cache[file_name] = false;
        return nil;
    end

    return handle;
end

function ICON_ART_STYLE.icon_handle(icon_def)
    if (type(icon_def) ~= 'table') then
        return nil;
    end

    return ICON_ART_STYLE.asset_icon_handle(icon_def.asset);
end

function COMMAND_MODE.item_description_text(resource)
    local desc = resource ~= nil and safe_read(function ()
        return resource.Description[1];
    end, nil) or nil;
    if (type(desc) ~= 'string') then
        return '';
    end

    desc = desc:gsub('%z', ''):gsub('\r\n', '\n'):gsub('\r', '\n'):gsub('%%', '%%%%');
    return trim_string(desc);
end

function COMMAND_MODE.render_item_badges(resource)
    local flags = tonumber(resource ~= nil and safe_read(function () return resource.Flags; end, 0) or 0) or 0;
    local rare = bit.band(flags, 0x8000) ~= 0;
    local ex = bit.band(flags, 0x6040) ~= 0;
    if (rare) then
        imgui.TextColored({ 1.00, 0.86, 0.30, 1.00 }, 'Rare');
    end
    if (rare and ex) then
        imgui.SameLine(0, 6);
    end
    if (ex) then
        imgui.TextColored({ 0.48, 1.00, 0.48, 1.00 }, 'Ex');
    end
end

function COMMAND_MODE.render_item_resource_tooltip(action, resource)
    if (action == nil and resource == nil) then
        return;
    end

    local item_id = action ~= nil and tonumber(action.id) or COMMAND_MODE.resource_id(resource);
    local name = COMMAND_MODE.resource_name(resource);
    if (name == '' and action ~= nil) then
        name = action.name or '';
    end

    imgui.SetNextWindowSize({ 360, 0 }, ImGuiCond_Always);
    imgui.BeginTooltip();
    imgui.PushTextWrapPos(340);

    local handle = COMMAND_MODE.item_icon_handle(item_id, resource);
    if (handle ~= nil) then
        imgui.Image(handle, { 32, 32 });
        imgui.SameLine(0, 8);
    end

    imgui.TextColored(UI_COLORS.config_header, name ~= '' and name or 'Item');
    if (item_id ~= nil) then
        imgui.TextColored({ 0.72, 0.72, 0.76, 1.00 }, ('Item ID: %d'):fmt(item_id));
    end
    if (action ~= nil and action.detail ~= nil) then
        imgui.TextColored({ 0.72, 0.72, 0.76, 1.00 }, action.detail);
    end

    if (resource ~= nil) then
        COMMAND_MODE.render_item_badges(resource);
        local stack_size = tonumber(safe_read(function () return resource.StackSize; end, nil));
        if (stack_size ~= nil and stack_size > 1) then
            imgui.Text(('Stack: %d'):fmt(stack_size));
        end
        local level = tonumber(safe_read(function () return resource.Level; end, nil));
        if (level ~= nil and level > 0) then
            imgui.Text(('Level: %d'):fmt(level));
        end

        local desc = COMMAND_MODE.item_description_text(resource);
        if (desc ~= '') then
            imgui.Separator();
            imgui.TextWrapped(desc);
        end
    end

    imgui.PopTextWrapPos();
    imgui.EndTooltip();
end

function COMMAND_MODE.render_item_icon_preview(editor, size)
    size = size or 36;
    local action, resource = COMMAND_MODE.selected_item_action(editor);
    local handle = action ~= nil and COMMAND_MODE.item_icon_handle(action.id, resource) or nil;
    if (handle ~= nil) then
        imgui.Image(handle, { size, size });
    else
        imgui.Dummy({ size, size });
    end

    return imgui.IsItemHovered(), action, resource;
end

function COMMAND_MODE.weapon_skill_actions()
    local list = {};
    local lookup = {};
    local state_info = COMMAND_MODE.current_player_state();
    local resources = safe_read(function () return AshitaCore:GetResourceManager(); end, nil);
    if (state_info ~= nil and resources ~= nil) then
        for id = 1, 0x200, 1 do
            if (safe_read(function () return state_info.player:HasWeaponSkill(id); end, false)) then
                local ability = safe_read(function () return resources:GetAbilityById(id); end, nil);
                COMMAND_MODE.add_action(list, lookup, COMMAND_MODE.resource_name(ability), id, nil);
            end
        end
    end

    COMMAND_MODE.configured_action_fallback('weaponskill', list, lookup);
    return COMMAND_MODE.sort_actions(list);
end

function COMMAND_MODE.ability_actions()
    local list = {};
    local lookup = {};
    local state_info = COMMAND_MODE.current_player_state();
    local resources = safe_read(function () return AshitaCore:GetResourceManager(); end, nil);
    if (state_info ~= nil and resources ~= nil) then
        for id = 0x201, 0x600, 1 do
            if (safe_read(function () return state_info.player:HasAbility(id); end, false)) then
                local ability = safe_read(function () return resources:GetAbilityById(id); end, nil);
                local timer_id = ability ~= nil and tonumber(safe_read(function () return ability.RecastTimerId; end, nil)) or nil;
                COMMAND_MODE.add_action(list, lookup, COMMAND_MODE.resource_name(ability), id, timer_id ~= nil and ('timer %d'):fmt(timer_id) or nil);
            end
        end
    end

    COMMAND_MODE.configured_action_fallback('ability', list, lookup);
    return COMMAND_MODE.sort_actions(list);
end

function COMMAND_MODE.pet_command_actions()
    local list = {};
    local lookup = {};
    local state_info = COMMAND_MODE.current_player_state();
    local resources = safe_read(function () return AshitaCore:GetResourceManager(); end, nil);
    if (state_info ~= nil and resources ~= nil) then
        for id = 0x200, 0x800, 1 do
            if (safe_read(function () return state_info.player:HasPetCommand(id); end, false)) then
                local ability = safe_read(function () return resources:GetAbilityById(id); end, nil);
                local timer_id = ability ~= nil and tonumber(safe_read(function () return ability.RecastTimerId; end, nil)) or nil;
                COMMAND_MODE.add_action(list, lookup, COMMAND_MODE.resource_name(ability), id, timer_id ~= nil and ('timer %d'):fmt(timer_id) or nil);
            end
        end
    end

    return COMMAND_MODE.sort_actions(list);
end

function COMMAND_MODE.pet_command_available_now(name)
    name = COMMAND_MODE.clean_name(name);
    if (name == '') then
        return nil;
    end

    if (state.command_mode_cache == nil) then
        state.command_mode_cache = {};
    end

    local now = os.clock();
    local cached = state.command_mode_cache.pet_visual;
    if (cached ~= nil and cached.lookup ~= nil and (now - cached.at) <= 0.50) then
        return cached.lookup[name:lower()] == true;
    end

    local lookup = {};
    for _, action in ipairs(COMMAND_MODE.pet_command_actions()) do
        local key = COMMAND_MODE.clean_name(action.name):lower();
        if (key ~= '') then
            lookup[key] = true;
        end
    end

    state.command_mode_cache.pet_visual = { at = now, lookup = lookup };
    return lookup[name:lower()] == true;
end

function COMMAND_MODE.server_actions()
    local list = {};
    local lookup = {};
    for _, server_command in ipairs(COMMAND_MODE.SERVER_COMMANDS) do
        local runtime_command = COMMAND_MODE.server_runtime_action(server_command) or server_command;
        local command = type(runtime_command.command) == 'string' and runtime_command.command or '';
        local buff = type(runtime_command.buff) == 'string' and runtime_command.buff or '';
        local detail = 'current: ' .. command;
        if (buff ~= '') then
            detail = detail .. ', buff: ' .. buff;
        end
        if (runtime_command.zone_label ~= nil and runtime_command.zone_label ~= '') then
            detail = detail .. ', ' .. runtime_command.zone_label;
        end

        COMMAND_MODE.add_action(list, lookup, server_command.name, command, detail, {
            server_command = command,
            buff_name = buff,
            icon = runtime_command.icon or server_command.icon,
            search_keywords = '!signet !sigil !sanction !ionis',
        });
    end

    return COMMAND_MODE.sort_actions(list);
end

function COMMAND_MODE.trusts_actions()
    local list = {};
    local lookup = {};
    for _, trusts_action in ipairs(COMMAND_MODE.TRUSTS_ACTIONS) do
        COMMAND_MODE.add_action(list, lookup, trusts_action.name, trusts_action.command, trusts_action.detail, {
            trusts_command = trusts_action.command,
            icon = trusts_action.icon,
            search_keywords = trusts_action.search_keywords,
        });
    end

    return COMMAND_MODE.sort_actions(list);
end

function COMMAND_MODE.mount_actions()
    local list = {};
    local lookup = {};
    local resources = safe_read(function () return AshitaCore:GetResourceManager(); end, nil);
    if (resources ~= nil) then
        for id = 0, 255, 1 do
            local name = COMMAND_MODE.clean_name(safe_read(function ()
                return resources:GetString('mounts.names', id);
            end, ''));
            if (name ~= '' and name:lower() ~= 'none') then
                COMMAND_MODE.add_action(list, lookup, name, id, nil);
            end
        end
    end

    COMMAND_MODE.configured_action_fallback('mount', list, lookup);
    return COMMAND_MODE.sort_actions(list);
end

function COMMAND_MODE.actions(mode)
    mode = MACRO.normalize_mode(mode);
    if (state.command_mode_cache == nil) then
        state.command_mode_cache = {};
    end

    local now = os.clock();
    local cached = state.command_mode_cache[mode];
    if (cached ~= nil and cached.items ~= nil and (now - cached.at) <= LIMITS.command_list_cache_seconds) then
        return cached.items;
    end

    local items = {};
    if (mode == 'spell') then
        items = COMMAND_MODE.spell_actions();
    elseif (mode == 'item') then
        items = COMMAND_MODE.item_actions();
    elseif (mode == 'weaponskill') then
        items = COMMAND_MODE.weapon_skill_actions();
    elseif (mode == 'ability') then
        items = COMMAND_MODE.ability_actions();
    elseif (mode == 'pet') then
        items = COMMAND_MODE.pet_command_actions();
    elseif (mode == 'mount') then
        items = COMMAND_MODE.mount_actions();
    elseif (mode == 'server') then
        items = COMMAND_MODE.server_actions();
    elseif (mode == 'trusts') then
        items = COMMAND_MODE.trusts_actions();
    elseif (mode == 'ranged') then
        items = { { name = 'Ranged Attack' } };
    end

    state.command_mode_cache[mode] = { at = now, items = items };
    return items;
end

function COMMAND_MODE.invalidate_cache()
    state.command_mode_cache = {};
end

function COMMAND_MODE.set_default_label(editor, name)
    if (editor == nil or trim_string(editor.label_buffer[1]) ~= '') then
        return;
    end

    buffer_set(editor.label_buffer, trim_one_line(name, LIMITS.macro_label_max));
end

function COMMAND_MODE.ensure_structured_selection(editor, mode)
    if (editor == nil) then
        return;
    end

    mode = MACRO.normalize_mode(mode);
    if (mode == 'target') then
        editor.target_action = editor.target_action or '/target';
        editor.command_target = trim_string(editor.command_target) ~= '' and editor.command_target or COMMAND_MODE.default_target(mode);
        return;
    end
    if (mode == 'ranged') then
        editor.command_action = 'Ranged Attack';
        editor.command_target = trim_string(editor.command_target) ~= '' and editor.command_target or COMMAND_MODE.default_target(mode);
        return;
    end
    if (mode == 'item' or mode == 'mount') then
        editor.command_target = '<me>';
    elseif (mode == 'server' or mode == 'trusts' or mode == 'configtoggle') then
        editor.command_target = '';
    elseif (mode == 'pet') then
        editor.command_target = trim_string(editor.command_target) ~= '' and editor.command_target or COMMAND_MODE.pet_command_default_target(editor.command_action);
    else
        editor.command_target = trim_string(editor.command_target) ~= '' and editor.command_target or COMMAND_MODE.default_target(mode);
    end
    if (mode == 'spell' or mode == 'item' or mode == 'mount' or mode == 'server' or mode == 'trusts' or mode == 'configtoggle' or mode == 'weaponskill' or mode == 'ability' or mode == 'pet') then
        return;
    end

    if (COMMAND_MODE.clean_name(editor.command_action) ~= '') then
        return;
    end

    local actions = COMMAND_MODE.actions(mode);
    if (#actions > 0) then
        editor.command_action = actions[1].name;
        COMMAND_MODE.set_default_label(editor, editor.command_action);
    end
end

function COMMAND_MODE.change_editor_mode(editor, mode)
    if (editor == nil) then
        return;
    end

    local current_mode = MACRO.normalize_mode(editor.macro_mode);
    local _, current_command, current_commands = MACRO.editor_commands();
    mode = MACRO.normalize_mode(mode);
    if (mode == 'multi') then
        editor.macro_mode = 'multi';
        editor.run_as_script[1] = current_mode == 'multi' and editor.run_as_script[1] == true;
        if (trim_string(editor.commands_buffer[1]) == '') then
            buffer_set(editor.commands_buffer, MACRO.commands_to_text((#current_commands > 0) and current_commands or { current_command }));
        end
        return;
    end
    if (mode == 'single') then
        editor.macro_mode = 'single';
        editor.run_as_script[1] = false;
        if (current_command ~= '') then
            buffer_set(editor.command_buffer, current_command);
        end
        return;
    end

    editor.macro_mode = mode;
    editor.run_as_script[1] = false;
    if (COMMAND_MODE.is_structured_mode(mode)) then
        editor.use_action_name_label[1] = true;
    end
    if (mode == 'item') then
        buffer_set(editor.icon_buffer, '');
    end
    if (COMMAND_MODE.mode_from_command(current_command) ~= mode) then
        current_command = '';
    end
    local action, target = COMMAND_MODE.command_action_for_mode(mode, current_command);
    editor.command_action = action or '';
    editor.command_target = target or COMMAND_MODE.default_target(mode);
    if (mode == 'configtoggle') then
        local parsed = COMMAND_MODE.parse_config_command(current_command);
        buffer_set(editor.config_key_buffer, parsed ~= nil and parsed.id ~= nil and tostring(parsed.id) or '');
        buffer_set(editor.config_value_a_buffer, '0');
        buffer_set(editor.config_value_b_buffer, '1');
    end
    if (mode == 'target') then
        editor.target_action = action or '/target';
    end
    COMMAND_MODE.ensure_structured_selection(editor, mode);
    if (COMMAND_MODE.is_structured_mode(mode) and editor.use_action_name_label[1] ~= false) then
        COMMAND_MODE.apply_editor_action_label(editor, mode);
    end
    buffer_set(editor.command_buffer, COMMAND_MODE.editor_command(mode, editor));
end

function COMMAND_MODE.render_mode_selector(editor)
    local mode = MACRO.normalize_mode(editor.macro_mode);
    imgui.PushItemWidth(360);
    if (imgui.BeginCombo('Command Mode##ashitabars_button_mode_select', COMMAND_MODE.mode_label(mode), ImGuiComboFlags_None)) then
        for _, mode_id in ipairs(COMMAND_MODE.ORDER) do
            if (COMMAND_MODE.mode_available(mode_id) or mode == mode_id) then
                if (imgui.Selectable(COMMAND_MODE.mode_label(mode_id), mode == mode_id)) then
                    COMMAND_MODE.change_editor_mode(editor, mode_id);
                end
            end
        end
        imgui.EndCombo();
    end
    imgui.PopItemWidth();
end

function COMMAND_MODE.action_combo_label(editor, mode, actions)
    local current = COMMAND_MODE.clean_name(editor.command_action);
    if (current ~= '') then
        return current;
    end

    if (actions ~= nil and #actions > 0) then
        return 'Choose ' .. (COMMAND_MODE.DEFS[mode].action_label or 'Action');
    end

    return COMMAND_MODE.DEFS[mode].empty_label or 'No actions found.';
end

function COMMAND_MODE.spell_filter_key(value, options)
    if (type(value) ~= 'string' or value == '') then
        return 'all';
    end

    for _, option in ipairs(options or {}) do
        if (option.key == value) then
            return value;
        end
    end

    return 'all';
end

function COMMAND_MODE.spell_search_text(editor)
    if (editor == nil or editor.spell_search_buffer == nil) then
        return '';
    end

    return trim_string(editor.spell_search_buffer[1]):lower();
end

function COMMAND_MODE.action_search_buffer(editor, mode)
    if (editor == nil) then
        return nil;
    end

    mode = MACRO.normalize_mode(mode);
    if (mode == 'item') then
        return editor.item_search_buffer;
    end
    if (mode == 'weaponskill') then
        return editor.weaponskill_search_buffer;
    end
    if (mode == 'ability') then
        return editor.ability_search_buffer;
    end
    if (mode == 'pet') then
        return editor.pet_search_buffer;
    end
    if (mode == 'mount') then
        return editor.mount_search_buffer;
    end
    if (mode == 'server') then
        return editor.server_search_buffer;
    end
    if (mode == 'trusts') then
        return editor.trusts_search_buffer;
    end

    return nil;
end

function COMMAND_MODE.action_search_text(editor, mode)
    local buffer = COMMAND_MODE.action_search_buffer(editor, mode);
    if (buffer == nil) then
        return '';
    end

    return trim_string(buffer[1]):lower();
end

function COMMAND_MODE.action_search_haystack(action)
    if (type(action) ~= 'table') then
        return '';
    end

    return table.concat({
        action.name or '',
        action.detail or '',
        action.item_source_label or '',
        action.server_command or '',
        action.trusts_command or '',
        action.buff_name or '',
        action.search_keywords or '',
    }, ' '):lower();
end

function COMMAND_MODE.action_matches_search(action, search)
    if (type(action) ~= 'table') then
        return false;
    end

    search = type(search) == 'string' and search or '';
    if (search == '') then
        return true;
    end

    return COMMAND_MODE.action_search_haystack(action):find(search, 1, true) ~= nil;
end

function COMMAND_MODE.filtered_actions_by_search(actions, search)
    local filtered = {};
    for _, action in ipairs(actions or {}) do
        if (COMMAND_MODE.action_matches_search(action, search)) then
            table.insert(filtered, action);
        end
    end

    return filtered;
end

function COMMAND_MODE.item_action_matches_filter_values(action, source_filter, search)
    if (type(action) ~= 'table') then
        return false;
    end

    source_filter = COMMAND_MODE.spell_filter_key(source_filter, COMMAND_MODE.ITEM_SOURCE_OPTIONS);
    if (source_filter ~= 'all' and action.item_source ~= source_filter) then
        return false;
    end

    return COMMAND_MODE.action_matches_search(action, search);
end

function COMMAND_MODE.filtered_item_actions(editor, actions)
    local filtered = {};
    local source_filter = COMMAND_MODE.spell_filter_key(editor ~= nil and editor.item_source_filter or 'all', COMMAND_MODE.ITEM_SOURCE_OPTIONS);
    local search = COMMAND_MODE.action_search_text(editor, 'item');
    for _, action in ipairs(actions or {}) do
        if (COMMAND_MODE.item_action_matches_filter_values(action, source_filter, search)) then
            table.insert(filtered, action);
        end
    end

    return filtered;
end

function COMMAND_MODE.item_filter_options_for(actions, search)
    local available = {};
    for _, action in ipairs(actions or {}) do
        if (COMMAND_MODE.action_matches_search(action, search)) then
            local key = action.item_source;
            if (type(key) == 'string' and key ~= '') then
                available[key] = true;
            end
        end
    end

    local options = {};
    for _, option in ipairs(COMMAND_MODE.ITEM_SOURCE_OPTIONS) do
        if (option.key == 'all' or available[option.key] == true) then
            table.insert(options, option);
        end
    end

    return options;
end

function COMMAND_MODE.normalize_item_filter_options(editor, actions)
    local search = COMMAND_MODE.action_search_text(editor, 'item');
    local options = COMMAND_MODE.item_filter_options_for(actions, search);
    editor.item_source_filter = COMMAND_MODE.spell_filter_key(editor.item_source_filter, options);
    return options;
end

function COMMAND_MODE.spell_action_matches_filter_values(action, type_filter, element_filter, search)
    if (type(action) ~= 'table') then
        return false;
    end

    type_filter = COMMAND_MODE.spell_filter_key(type_filter, COMMAND_MODE.SPELL_TYPE_OPTIONS);
    if (type_filter ~= 'all' and action.spell_type ~= type_filter) then
        return false;
    end

    element_filter = COMMAND_MODE.spell_filter_key(element_filter, COMMAND_MODE.SPELL_ELEMENT_OPTIONS);
    if (element_filter ~= 'all' and action.spell_element ~= element_filter) then
        return false;
    end

    search = type(search) == 'string' and search or '';
    if (search ~= '') then
        local haystack = table.concat({
            action.name or '',
            action.detail or '',
            action.spell_type_label or '',
            action.spell_element_label or '',
        }, ' '):lower();
        if (haystack:find(search, 1, true) == nil) then
            return false;
        end
    end

    return true;
end

function COMMAND_MODE.spell_action_matches_filters(action, editor)
    return COMMAND_MODE.spell_action_matches_filter_values(
        action,
        editor ~= nil and editor.spell_type_filter or 'all',
        editor ~= nil and editor.spell_element_filter or 'all',
        COMMAND_MODE.spell_search_text(editor)
    );
end

function COMMAND_MODE.filtered_spell_actions(editor, actions)
    local filtered = {};
    for _, action in ipairs(actions or {}) do
        if (COMMAND_MODE.spell_action_matches_filters(action, editor)) then
            table.insert(filtered, action);
        end
    end

    return filtered;
end

function COMMAND_MODE.spell_filter_options_for(actions, base_options, action_key, type_filter, element_filter, search)
    local available = {};
    for _, action in ipairs(actions or {}) do
        if (COMMAND_MODE.spell_action_matches_filter_values(action, type_filter, element_filter, search)) then
            local key = action[action_key];
            if (type(key) == 'string' and key ~= '') then
                available[key] = true;
            end
        end
    end

    local options = {};
    for _, option in ipairs(base_options or {}) do
        if (option.key == 'all' or available[option.key] == true) then
            table.insert(options, option);
        end
    end

    return options;
end

function COMMAND_MODE.normalize_spell_filter_options(editor, actions)
    local search = COMMAND_MODE.spell_search_text(editor);
    local type_filter = COMMAND_MODE.spell_filter_key(editor.spell_type_filter, COMMAND_MODE.SPELL_TYPE_OPTIONS);
    local element_filter = COMMAND_MODE.spell_filter_key(editor.spell_element_filter, COMMAND_MODE.SPELL_ELEMENT_OPTIONS);
    local type_options = nil;
    local element_options = nil;

    for _ = 1, 2 do
        type_options = COMMAND_MODE.spell_filter_options_for(actions, COMMAND_MODE.SPELL_TYPE_OPTIONS, 'spell_type', 'all', element_filter, search);
        type_filter = COMMAND_MODE.spell_filter_key(type_filter, type_options);
        element_options = COMMAND_MODE.spell_filter_options_for(actions, COMMAND_MODE.SPELL_ELEMENT_OPTIONS, 'spell_element', type_filter, 'all', search);
        element_filter = COMMAND_MODE.spell_filter_key(element_filter, element_options);
    end

    editor.spell_type_filter = type_filter;
    editor.spell_element_filter = element_filter;
    return type_options or COMMAND_MODE.SPELL_TYPE_OPTIONS, element_options or COMMAND_MODE.SPELL_ELEMENT_OPTIONS;
end

function COMMAND_MODE.render_filter_combo(label, id, current_key, options, width)
    current_key = COMMAND_MODE.spell_filter_key(current_key, options);
    imgui.PushItemWidth(width or 170);
    if (imgui.BeginCombo(label .. '##' .. id, COMMAND_MODE.option_label(options, current_key, 'All'), ImGuiComboFlags_None)) then
        for _, option in ipairs(options or {}) do
            if (imgui.Selectable(option.label, option.key == current_key)) then
                current_key = option.key;
            end
        end
        imgui.EndCombo();
    end
    imgui.PopItemWidth();

    return current_key;
end

function COMMAND_MODE.render_spell_filters(editor, actions)
    if (editor == nil) then
        return actions or {};
    end

    local type_options, element_options = COMMAND_MODE.normalize_spell_filter_options(editor, actions);
    editor.spell_type_filter = COMMAND_MODE.render_filter_combo('Type', 'ashitabars_spell_type_filter', editor.spell_type_filter, type_options, 170);
    imgui.SameLine(0, 8);
    type_options, element_options = COMMAND_MODE.normalize_spell_filter_options(editor, actions);
    editor.spell_element_filter = COMMAND_MODE.render_filter_combo('Element', 'ashitabars_spell_element_filter', editor.spell_element_filter, element_options, 170);
    COMMAND_MODE.normalize_spell_filter_options(editor, actions);

    imgui.PushItemWidth(360);
    imgui.InputText('Search##ashitabars_spell_search_filter', editor.spell_search_buffer, 64);
    imgui.PopItemWidth();

    if (editor.spell_type_filter ~= 'all' or editor.spell_element_filter ~= 'all' or COMMAND_MODE.spell_search_text(editor) ~= '') then
        if (imgui.Button('Clear Filters##ashitabars_spell_clear_filters')) then
            editor.spell_type_filter = 'all';
            editor.spell_element_filter = 'all';
            buffer_set(editor.spell_search_buffer, '');
        end
    end

    local filtered = COMMAND_MODE.filtered_spell_actions(editor, actions);
    imgui.TextColored({ 0.72, 0.72, 0.76, 1.00 }, ('%d / %d spells'):fmt(#filtered, #(actions or {})));
    return filtered;
end

function COMMAND_MODE.render_item_filters(editor, actions)
    if (editor == nil) then
        return actions or {};
    end

    local source_options = COMMAND_MODE.normalize_item_filter_options(editor, actions);
    editor.item_source_filter = COMMAND_MODE.render_filter_combo('Source', 'ashitabars_item_source_filter', editor.item_source_filter, source_options, 170);
    COMMAND_MODE.normalize_item_filter_options(editor, actions);

    imgui.PushItemWidth(360);
    imgui.InputText('Search##ashitabars_item_search_filter', editor.item_search_buffer, 64);
    imgui.PopItemWidth();
    COMMAND_MODE.normalize_item_filter_options(editor, actions);

    if (editor.item_source_filter ~= 'all' or COMMAND_MODE.action_search_text(editor, 'item') ~= '') then
        if (imgui.Button('Clear Filters##ashitabars_item_clear_filters')) then
            editor.item_source_filter = 'all';
            buffer_set(editor.item_search_buffer, '');
        end
    end

    local filtered = COMMAND_MODE.filtered_item_actions(editor, actions);
    imgui.TextColored({ 0.72, 0.72, 0.76, 1.00 }, ('%d / %d items'):fmt(#filtered, #(actions or {})));
    return filtered;
end

function COMMAND_MODE.render_search_filter(editor, mode, actions)
    if (editor == nil) then
        return actions or {};
    end

    local buffer = COMMAND_MODE.action_search_buffer(editor, mode);
    if (buffer == nil) then
        return actions or {};
    end

    imgui.PushItemWidth(360);
    imgui.InputText('Search##ashitabars_' .. mode .. '_search_filter', buffer, 64);
    imgui.PopItemWidth();

    local search = COMMAND_MODE.action_search_text(editor, mode);
    if (search ~= '') then
        if (imgui.Button('Clear Filter##ashitabars_' .. mode .. '_clear_filter')) then
            buffer_set(buffer, '');
            search = '';
        end
    end

    local filtered = COMMAND_MODE.filtered_actions_by_search(actions, search);
    local count_label = 'actions';
    if (mode == 'weaponskill') then
        count_label = 'weapon skills';
    elseif (mode == 'ability') then
        count_label = 'job abilities';
    elseif (mode == 'pet') then
        count_label = 'pet commands';
    elseif (mode == 'mount') then
        count_label = 'mounts';
    elseif (mode == 'server') then
        count_label = 'server commands';
    elseif (mode == 'trusts') then
        count_label = 'trusts actions';
    end
    imgui.TextColored({ 0.72, 0.72, 0.76, 1.00 }, ('%d / %d %s'):fmt(#filtered, #(actions or {}), count_label));
    return filtered;
end

function COMMAND_MODE.spell_action_list_label(action)
    local label = action.name or '';
    local details = {};
    if (action.spell_type_label ~= nil and action.spell_type_label ~= '') then
        table.insert(details, action.spell_type_label);
    end
    if (action.spell_element_label ~= nil and action.spell_element_label ~= '' and action.spell_element ~= 'none') then
        table.insert(details, action.spell_element_label);
    end
    if (action.detail ~= nil and action.detail ~= '') then
        table.insert(details, action.detail);
    end
    if (#details > 0) then
        label = label .. '  (' .. table.concat(details, ', ') .. ')';
    end

    return label;
end

function COMMAND_MODE.select_editor_action(editor, mode, action)
    if (type(action) ~= 'table' or action.name == nil) then
        return;
    end

    editor.command_action = action.name;
    if (MACRO.normalize_mode(mode) == 'pet') then
        editor.command_target = COMMAND_MODE.pet_command_default_target(action.name);
    end
    if (COMMAND_MODE.is_structured_mode(mode) and editor.use_action_name_label[1] ~= false) then
        COMMAND_MODE.apply_editor_action_label(editor, mode);
    else
        COMMAND_MODE.set_default_label(editor, action.name);
    end
end

function COMMAND_MODE.action_list_label(mode, action)
    mode = MACRO.normalize_mode(mode);
    if (mode == 'spell') then
        return COMMAND_MODE.spell_action_list_label(action);
    end

    local label = action.name or '';
    local details = {};
    if (action.item_source_label ~= nil and action.item_source_label ~= '') then
        table.insert(details, action.item_source_label);
    end
    if (action.detail ~= nil and action.detail ~= '') then
        table.insert(details, action.detail);
    end
    if (#details > 0) then
        label = label .. '  (' .. table.concat(details, ', ') .. ')';
    end

    return label;
end

function COMMAND_MODE.clear_missing_filtered_selection(editor, actions)
    local current = COMMAND_MODE.clean_name(editor ~= nil and editor.command_action or '');
    if (current == '') then
        return;
    end

    local found = false;
    for _, action in ipairs(actions or {}) do
        if (action.name == current) then
            found = true;
            break;
        end
    end

    if (not found) then
        editor.command_action = '';
        if (editor.use_action_name_label[1] ~= false) then
            buffer_set(editor.label_buffer, '');
        end
    end
end

function COMMAND_MODE.render_action_result_list(editor, mode, actions, empty_label)
    mode = MACRO.normalize_mode(mode);
    actions = actions or {};
    imgui.TextColored(UI_COLORS.config_header, (COMMAND_MODE.DEFS[mode] and COMMAND_MODE.DEFS[mode].action_label) or 'Action');
    COMMAND_MODE.clear_missing_filtered_selection(editor, actions);
    if (#actions == 0) then
        imgui.Text(empty_label);
        return;
    end

    local child_open = false;
    local child_visible = true;
    if (type(imgui.BeginChild) == 'function' and type(imgui.EndChild) == 'function') then
        local ok, result = pcall(imgui.BeginChild, '##ashitabars_' .. mode .. '_result_list', { 360, 128 }, true);
        child_open = ok;
        child_visible = (not ok) or result ~= false;
    end

    if (child_visible) then
        for _, action in ipairs(actions) do
            local label = COMMAND_MODE.action_list_label(mode, action);
            local id = action.id or action.name or label;
            if (imgui.Selectable(label .. '##ashitabars_' .. mode .. '_result_' .. tostring(id), editor.command_action == action.name)) then
                COMMAND_MODE.select_editor_action(editor, mode, action);
            end
            if (mode == 'item' and imgui.IsItemHovered()) then
                COMMAND_MODE.render_item_resource_tooltip(action, COMMAND_MODE.item_resource(action.id, action.name));
            end
        end
    end

    if (child_open) then
        imgui.EndChild();
    end
end

function COMMAND_MODE.render_spell_action_list(editor, actions, empty_label)
    imgui.TextColored(UI_COLORS.config_header, 'Spell');
    actions = actions or {};
    COMMAND_MODE.clear_missing_filtered_selection(editor, actions);

    if (#actions == 0) then
        imgui.Text(empty_label);
        return;
    end

    local child_open = false;
    local child_visible = true;
    if (type(imgui.BeginChild) == 'function' and type(imgui.EndChild) == 'function') then
        local ok, result = pcall(imgui.BeginChild, '##ashitabars_spell_result_list', { 360, 128 }, true);
        child_open = ok;
        child_visible = (not ok) or result ~= false;
    end

    if (child_visible) then
        for _, action in ipairs(actions) do
            local label = COMMAND_MODE.spell_action_list_label(action);
            local id = action.id or action.name or label;
            if (imgui.Selectable(label .. '##ashitabars_spell_result_' .. tostring(id), editor.command_action == action.name)) then
                COMMAND_MODE.select_editor_action(editor, 'spell', action);
            end
        end
    end

    if (child_open) then
        imgui.EndChild();
    end
end

function COMMAND_MODE.render_action_selector(editor, mode)
    mode = MACRO.normalize_mode(mode);
    local def = COMMAND_MODE.DEFS[mode] or COMMAND_MODE.DEFS.single;
    imgui.TextColored(UI_COLORS.config_header, def.action_label or 'Action');
    imgui.SameLine(0, 8);
    if (imgui.Button('Refresh Lists##ashitabars_button_refresh_action_lists')) then
        COMMAND_MODE.invalidate_cache();
    end

    if (mode == 'target') then
        local current = editor.target_action or '/target';
        local label = 'Target';
        for _, action in ipairs(COMMAND_MODE.TARGET_ACTIONS) do
            if (action.prefix == current) then
                label = action.label;
                break;
            end
        end

        imgui.PushItemWidth(360);
        if (imgui.BeginCombo('Action##ashitabars_button_target_action', label, ImGuiComboFlags_None)) then
            for _, action in ipairs(COMMAND_MODE.TARGET_ACTIONS) do
                if (imgui.Selectable(action.label, action.prefix == current)) then
                    editor.target_action = action.prefix;
                    if (editor.use_action_name_label[1] ~= false) then
                        COMMAND_MODE.apply_editor_action_label(editor, mode);
                    else
                        COMMAND_MODE.set_default_label(editor, action.label);
                    end
                end
            end
            imgui.EndCombo();
        end
        imgui.PopItemWidth();
        return;
    end

    local actions = COMMAND_MODE.actions(mode);
    local empty_label = def.empty_label or 'No actions found.';
    if (mode == 'spell') then
        actions = COMMAND_MODE.render_spell_filters(editor, actions);
        empty_label = 'No spells match the current filters.';
        COMMAND_MODE.render_spell_action_list(editor, actions, empty_label);
        return;
    end

    if (mode == 'item') then
        local item_hovered, tooltip_action, tooltip_resource = COMMAND_MODE.render_item_icon_preview(editor, 36);
        imgui.SameLine(0, 8);
        actions = COMMAND_MODE.render_item_filters(editor, actions);
        empty_label = 'No items match the current filters.';
        COMMAND_MODE.render_action_result_list(editor, mode, actions, empty_label);
        if (item_hovered) then
            COMMAND_MODE.render_item_resource_tooltip(tooltip_action, tooltip_resource);
        end
        return;
    end

    if (mode == 'weaponskill' or mode == 'ability' or mode == 'pet' or mode == 'mount' or mode == 'server' or mode == 'trusts') then
        actions = COMMAND_MODE.render_search_filter(editor, mode, actions);
        if (mode == 'weaponskill') then
            empty_label = 'No weapon skills match the current filter.';
        elseif (mode == 'ability') then
            empty_label = 'No job abilities match the current filter.';
        elseif (mode == 'pet') then
            empty_label = 'No pet commands match the current filter.';
        elseif (mode == 'server') then
            empty_label = 'No server commands match the current filter.';
        elseif (mode == 'trusts') then
            empty_label = 'No trusts addon actions match the current filter.';
        else
            empty_label = 'No mounts match the current filter.';
        end
        COMMAND_MODE.render_action_result_list(editor, mode, actions, empty_label);
        return;
    end

    local item_hovered = false;
    local tooltip_action = nil;
    local tooltip_resource = nil;
    if (mode == 'item') then
        item_hovered, tooltip_action, tooltip_resource = COMMAND_MODE.render_item_icon_preview(editor, 36);
        imgui.SameLine(0, 8);
    end

    imgui.PushItemWidth(mode == 'item' and 316 or 360);
    if (imgui.BeginCombo((def.action_label or 'Action') .. '##ashitabars_button_action_select', COMMAND_MODE.action_combo_label(editor, mode, actions), ImGuiComboFlags_None)) then
        if (#actions == 0) then
            imgui.Text(empty_label);
        end
        for _, action in ipairs(actions) do
            local label = action.name;
            if (mode == 'spell') then
                local details = {};
                if (action.spell_type_label ~= nil and action.spell_type_label ~= '') then
                    table.insert(details, action.spell_type_label);
                end
                if (action.spell_element_label ~= nil and action.spell_element_label ~= '' and action.spell_element ~= 'none') then
                    table.insert(details, action.spell_element_label);
                end
                if (action.detail ~= nil and action.detail ~= '') then
                    table.insert(details, action.detail);
                end
                if (#details > 0) then
                    label = label .. '  (' .. table.concat(details, ', ') .. ')';
                end
            elseif (action.detail ~= nil and action.detail ~= '') then
                label = label .. '  (' .. action.detail .. ')';
            end
            if (imgui.Selectable(label, editor.command_action == action.name)) then
                editor.command_action = action.name;
                if (COMMAND_MODE.is_structured_mode(mode) and editor.use_action_name_label[1] ~= false) then
                    COMMAND_MODE.apply_editor_action_label(editor, mode);
                else
                    COMMAND_MODE.set_default_label(editor, action.name);
                end
            end
            if (mode == 'item' and imgui.IsItemHovered()) then
                COMMAND_MODE.render_item_resource_tooltip(action, COMMAND_MODE.item_resource(action.id, action.name));
            end
        end
        imgui.EndCombo();
    end
    local combo_hovered = imgui.IsItemHovered();
    imgui.PopItemWidth();

    if (mode == 'item' and (item_hovered or combo_hovered)) then
        COMMAND_MODE.render_item_resource_tooltip(tooltip_action, tooltip_resource);
    end
end

function COMMAND_MODE.render_target_selector(editor, mode)
    mode = MACRO.normalize_mode(mode);
    local targets = COMMAND_MODE.TARGETS[mode];
    if (type(targets) ~= 'table' or #targets == 0) then
        return;
    end

    local current = trim_string(editor.command_target);
    if (current == '') then
        current = COMMAND_MODE.default_target(mode);
        editor.command_target = current;
    end

    local label = COMMAND_MODE.TARGET_LABELS[current] or current;
    imgui.TextColored(UI_COLORS.config_header, 'Target');
    imgui.PushItemWidth(360);
    if (imgui.BeginCombo('Target##ashitabars_button_target_select', label, ImGuiComboFlags_None)) then
        for _, target in ipairs(targets) do
            if (imgui.Selectable(COMMAND_MODE.TARGET_LABELS[target] or target, current == target)) then
                editor.command_target = target;
            end
        end
        imgui.EndCombo();
    end
    imgui.PopItemWidth();
end

function COMMAND_MODE.render_config_toggle_editor(editor)
    imgui.TextColored(UI_COLORS.config_header, 'Config Toggle');

    imgui.PushItemWidth(110);
    local changed = imgui.InputText('Key##ashitabars_config_toggle_key', editor.config_key_buffer, 16);
    imgui.PopItemWidth();

    imgui.PushItemWidth(110);
    local changed_a = imgui.InputText('Value A##ashitabars_config_toggle_value_a', editor.config_value_a_buffer, 16);
    imgui.SameLine(0, 8);
    local changed_b = imgui.InputText('Value B##ashitabars_config_toggle_value_b', editor.config_value_b_buffer, 16);
    imgui.PopItemWidth();

    local id, value_a, value_b = COMMAND_MODE.config_toggle_values_from_editor(editor);
    editor.command_action = id ~= nil and tostring(id) or trim_string(editor.config_key_buffer[1]);
    if ((changed or changed_a or changed_b) and editor.use_action_name_label[1] ~= false) then
        COMMAND_MODE.apply_editor_action_label(editor, 'configtoggle');
    end

    local validation_error = COMMAND_MODE.config_toggle_validation_error(id, value_a, value_b);
    if (validation_error ~= nil) then
        return;
    end

    local set_command, read_error, current, next_value = COMMAND_MODE.config_toggle_next_command(id, value_a, value_b);
    if (set_command ~= nil) then
        imgui.Text(('Current Value: %d'):fmt(current));
        imgui.Text(('Next Press: %s'):fmt(set_command));
    elseif (read_error ~= nil) then
        imgui.TextColored({ 0.72, 0.72, 0.76, 1.00 }, read_error);
    end
end

function COMMAND_MODE.render_structured_editor(editor, mode)
    COMMAND_MODE.ensure_structured_selection(editor, mode);
    if (mode == 'configtoggle') then
        COMMAND_MODE.render_config_toggle_editor(editor);
    else
        COMMAND_MODE.render_action_selector(editor, mode);
    end
    if (mode ~= 'item' and mode ~= 'mount' and mode ~= 'server' and mode ~= 'trusts' and mode ~= 'configtoggle') then
        COMMAND_MODE.render_target_selector(editor, mode);
    end

    local command = COMMAND_MODE.editor_command(mode, editor);
    buffer_set(editor.command_buffer, command);
    imgui.TextColored(UI_COLORS.config_header, 'Generated Command');
    imgui.Text(command ~= '' and command or '(choose an action)');
end

local function allowed_command(command)
    if (type(command) ~= 'string') then return false; end
    if (COMMAND_MODE.server_action_for_command(command) ~= nil) then
        return true;
    end
    local prefix = command:lower():match('^%s*(/%S+)');
    return prefix ~= nil and ALLOWED_PREFIXES[prefix] == true;
end

local function command_validation_error(command)
    if (type(command) ~= 'string' or command == '') then
        return nil;
    end

    if (not command:match('^%s*/') and not command:match('^%s*!')) then
        return 'Command must start with an allowed slash command or supported server command.';
    end

    if (not allowed_command(command)) then
        if (command:match('^%s*!')) then
            return 'Unsupported server command.';
        end
        return 'Unsupported command prefix.';
    end

    local prefix = command:lower():match('^%s*(/%S+)');
    if (prefix == '/config') then
        local parsed = COMMAND_MODE.parse_config_command(command);
        if (parsed == nil or parsed.error ~= nil) then
            return parsed ~= nil and parsed.error or 'Invalid config command.';
        end
    end
    if (prefix == '/trusts' and COMMAND_MODE.trusts_action_for_command(command) == nil) then
        return 'Invalid trusts addon command. Use /trusts or /trusts p1 through /trusts p5.';
    end

    return nil;
end

function MACRO.commands_validation_error(commands)
    if (type(commands) ~= 'table' or #commands == 0) then
        return nil;
    end

    for index, command in ipairs(commands) do
        local error = command_validation_error(command);
        if (error ~= nil) then
            return ('Line %d: %s'):fmt(index, error);
        end
    end

    return nil;
end

function MACRO.editor_commands()
    local editor = state.macro_editor;
    if (editor == nil) then
        return 'single', '', {}, false;
    end

    local mode = MACRO.normalize_mode(editor.macro_mode);
    if (mode == 'multi') then
        local commands = MACRO.commands_from_text(editor.commands_buffer[1]);
        return mode, commands[1] or '', commands, false;
    end
    if (COMMAND_MODE.is_structured_mode(mode)) then
        local command = MACRO.sanitize_command_line(COMMAND_MODE.editor_command(mode, editor));
        return mode, command, (command ~= '') and { command } or {}, false;
    end

    local command = MACRO.sanitize_command_line(editor.command_buffer[1]);
    return mode, command, (command ~= '') and { command } or {}, false;
end

function MACRO.editor_validation_error()
    local mode, command, commands = MACRO.editor_commands();

    local selection_error = COMMAND_MODE.editor_selection_validation_error(mode, state.macro_editor);
    if (selection_error ~= nil) then
        return selection_error;
    end

    if (mode == 'multi') then
        return MACRO.commands_validation_error(commands);
    end

    return command_validation_error(command);
end

function MACRO.run_editor_commands()
    local editor = state.macro_editor;
    if (editor == nil or editor.profile_key == nil or editor.group == nil or editor.index == nil) then
        return false, 'No button selected.';
    end

    local mode, _, commands = MACRO.editor_commands();

    local selection_error = COMMAND_MODE.editor_selection_validation_error(mode, editor);
    if (selection_error ~= nil) then
        return false, selection_error;
    end

    if (#commands == 0) then
        return false, 'Nothing to run.';
    end

    local validation_error = MACRO.commands_validation_error(commands);
    if (validation_error ~= nil) then
        return false, validation_error;
    end

    local context = {
        profile_key = editor.profile_key,
        group = editor.group,
        index = editor.index,
        script = mode == 'multi' and editor.run_as_script[1] == true,
    };
    if (mode == 'configtoggle') then
        local config_key, config_value_a, config_value_b = COMMAND_MODE.config_toggle_values_from_editor(editor);
        context.config_toggle = {
            key = config_key,
            value_a = config_value_a,
            value_b = config_value_b,
        };
    end
    local commands_to_queue = COMMAND_MODE.commands_for_execution(commands, context);
    local queue_ok, queue_message = MACRO.queue_commands(commands_to_queue, context);
    if (not queue_ok) then
        return false, queue_message;
    end
    COMMAND_MODE.track_command_execution(commands_to_queue);

    if (mode == 'multi') then
        if (editor.run_as_script[1] == true) then
            return true, ('Validated and ran script (%d commands).'):fmt(#commands);
        end
        return true, ('Validated and ran %d commands.'):fmt(#commands);
    end

    return true, 'Validated and ran command.';
end

local function execute_slot(group, index, source)
    local bar_key = BAR.key_for_group(group);
    refresh_profile_context(bar_key);

    local slot = get_slot(group, index);
    local commands = MACRO.slot_commands(slot);
    if (#commands == 0) then
        return false;
    end

    local validation_error = MACRO.commands_validation_error(commands);
    if (validation_error ~= nil) then
        log_warn(('Rejected %s slot %s command from %s: %s'):fmt(group, BAR.slot_index_label(index), source, validation_error));
        return false;
    end

    local profile = (type(state.profile) == 'table' and state.profile.bar_key == bar_key) and state.profile or refresh_profile_context(bar_key);
    local context = {
        profile_key = editable_profile_key(profile),
        group = group,
        index = index,
        script = MACRO.script_enabled(slot),
        slot = slot,
    };
    local commands_to_queue = COMMAND_MODE.commands_for_execution(commands, context);
    local queue_ok, queue_message = MACRO.queue_commands(commands_to_queue, context);
    if (not queue_ok) then
        log_warn(('Rejected %s slot %s command from %s: %s'):fmt(group, BAR.slot_index_label(index), source, queue_message));
        return false;
    end
    COMMAND_MODE.track_command_execution(commands_to_queue);

    return true;
end

local function prune_button_overrides()
    local overrides = state.macro_overrides or {};
    local profiles = overrides.profiles or {};
    for profile_key, profile in pairs(profiles) do
        if (type(profile) ~= 'table') then
            profiles[profile_key] = nil;
        else
            for _, row in ipairs(BUTTON_ROWS) do
                local row_overrides = profile[row.id];
                if (type(row_overrides) ~= 'table' or next(row_overrides) == nil) then
                    profile[row.id] = nil;
                end
            end
            if (next(profile) == nil) then
                profiles[profile_key] = nil;
            end
        end
    end
end

local function set_slot_override(profile_key, group, index, label, command, icon, macro_mode, commands, shared_ref, use_action_name_label, script, weaponskill_effect, weaponskill_effect_intensity, weaponskill_effect_opacity, weaponskill_effect_frequency, config_key, config_value_a, config_value_b)
    profile_key = normalize_profile_key(profile_key) or 'DEFAULT';
    if (not valid_row_id(group) or type(index) ~= 'number' or index < 1 or index > LIMITS.button_count_max) then
        return false, 'Invalid button selection.';
    end

    local overrides = SHARED.ensure_overrides();
    local profiles = overrides.profiles;
    profiles[profile_key] = profiles[profile_key] or {};
    profiles[profile_key][group] = profiles[profile_key][group] or {};

    local shared_name = SHARED.normalize_name(shared_ref);
    local slot = nil;
    if (shared_name ~= nil) then
        if (SHARED.definition(shared_name) == nil) then
            return false, ('Shared button not found: %s'):fmt(shared_name);
        end
        slot = { shared = shared_name };
    else
        slot = {
            label = trim_one_line(label, LIMITS.macro_label_max),
            command = MACRO.sanitize_command_line(command),
        };
        local slot_icon = trim_one_line(icon, LIMITS.macro_icon_max);
        if (slot_icon ~= '') then
            slot.icon = slot_icon;
        end
        local effect_style = MACRO.normalize_weaponskill_effect_style(weaponskill_effect);
        if (effect_style ~= nil) then
            slot.weaponskill_effect = effect_style;
        end
        local effect_intensity = MACRO.normalize_weaponskill_effect_intensity(weaponskill_effect_intensity);
        if (effect_intensity ~= nil) then
            slot.weaponskill_effect_intensity = effect_intensity;
        end
        local effect_opacity = MACRO.normalize_weaponskill_effect_opacity(weaponskill_effect_opacity);
        if (effect_opacity ~= nil) then
            slot.weaponskill_effect_opacity = effect_opacity;
        end
        local effect_frequency = MACRO.normalize_weaponskill_effect_frequency(weaponskill_effect_frequency);
        if (effect_frequency ~= nil) then
            slot.weaponskill_effect_frequency = effect_frequency;
        end
        slot.macro_mode = MACRO.normalize_mode(macro_mode);
        if (COMMAND_MODE.is_structured_mode(slot.macro_mode)) then
            slot.use_action_name_label = use_action_name_label ~= false;
        end
        if (slot.macro_mode == 'configtoggle') then
            local ok, err = MACRO.apply_config_toggle_to_slot(slot, config_key, config_value_a, config_value_b);
            if (not ok) then
                return false, err;
            end
        end
        if (slot.macro_mode == 'multi') then
            slot.commands = MACRO.commands_from_table(commands);
            if (#slot.commands == 0 and slot.command ~= '') then
                slot.commands = { slot.command };
            end
            slot.command = slot.commands[1] or '';
            if (script == true) then
                slot.script = true;
            end
        else
            slot.macro_mode = 'single';
            slot.commands = nil;
            slot.script = nil;
        end
    end

    profiles[profile_key][group][index] = slot;
    prune_button_overrides();
    return true;
end

function SHARED.editor_slot(require_command)
    local editor = state.macro_editor;
    if (editor == nil) then
        return nil, 'No button selected.';
    end

    local mode, command, commands = MACRO.editor_commands();

    local selection_error = COMMAND_MODE.editor_selection_validation_error(mode, editor);
    if (selection_error ~= nil) then
        return nil, selection_error;
    end

    if (require_command and #commands == 0) then
        return nil, 'Shared button needs at least one command.';
    end

    local validation_error = MACRO.commands_validation_error(commands);
    if (validation_error ~= nil) then
        return nil, validation_error;
    end

    local use_action_name_label = COMMAND_MODE.is_structured_mode(mode) and editor.use_action_name_label[1] ~= false;
    local slot_icon = (mode == 'item') and '' or trim_one_line(editor.icon_buffer[1], LIMITS.macro_icon_max);
    local label = use_action_name_label and COMMAND_MODE.editor_action_label(editor, mode) or trim_one_line(editor.label_buffer[1], LIMITS.macro_label_max);
    local slot = {
        label = label,
        command = command,
        macro_mode = mode,
    };
    if (COMMAND_MODE.is_structured_mode(mode)) then
        slot.use_action_name_label = use_action_name_label;
    end
    if (slot_icon ~= '') then
        slot.icon = slot_icon;
    end
    if (mode == 'multi') then
        slot.commands = MACRO.commands_from_table(commands);
        slot.command = slot.commands[1] or '';
        if (editor.run_as_script[1] == true) then
            slot.script = true;
        end
    end
    if (mode == 'configtoggle') then
        local ok, err = MACRO.apply_config_toggle_to_slot(slot, COMMAND_MODE.config_toggle_values_from_editor(editor));
        if (not ok) then
            return nil, err;
        end
    end
    MACRO.apply_weaponskill_effect_to_slot(slot, MACRO.editor_weaponskill_effect_values(editor));

    return slot, nil, mode, command, commands;
end

function SHARED.load_into_editor(name)
    local editor = state.macro_editor;
    local definition, shared_name = SHARED.definition(name);
    if (editor == nil or definition == nil) then
        return false, ('Shared button not found: %s'):fmt(tostring(name));
    end

    local slot = MACRO.normalize_slot_runtime(definition) or {};
    editor.shared_ref = shared_name;
    editor.source = 'shared: ' .. shared_name;
    buffer_set(editor.shared_name_buffer, shared_name);
    buffer_set(editor.label_buffer, slot.label or '');
    buffer_set(editor.command_buffer, MACRO.primary_command(slot));
    buffer_set(editor.commands_buffer, MACRO.commands_to_text(MACRO.slot_commands(slot)));
    buffer_set(editor.icon_buffer, slot.icon or '');
    COMMAND_MODE.load_editor_slot(editor, slot);
    MACRO.load_editor_weaponskill_effect(editor, slot);
    return true;
end

function SHARED.save_editor_shared()
    local editor = state.macro_editor;
    if (editor == nil or editor.profile_key == nil or editor.group == nil or editor.index == nil) then
        return false, 'No button selected.';
    end

    local shared_name = SHARED.normalize_name(editor.shared_name_buffer[1] or editor.shared_ref);
    if (shared_name == nil) then
        return false, 'Enter a shared button name.';
    end

    local slot, slot_error = SHARED.editor_slot(true);
    if (slot == nil) then
        return false, slot_error;
    end

    SHARED.definitions()[shared_name] = slot;
    local set_ok, set_err = set_slot_override(editor.profile_key, editor.group, editor.index, nil, nil, nil, nil, nil, shared_name);
    if (not set_ok) then
        return false, set_err;
    end

    local save_ok, save_message = save_button_overrides();
    if (not save_ok) then
        return false, save_message;
    end

    editor.shared_ref = shared_name;
    editor.source = 'shared: ' .. shared_name;
    buffer_set(editor.shared_name_buffer, shared_name);
    log_info(save_message);
    return true, ('Saved shared button: %s'):fmt(shared_name);
end

function SHARED.assign_editor_shared()
    local editor = state.macro_editor;
    if (editor == nil or editor.profile_key == nil or editor.group == nil or editor.index == nil) then
        return false, 'No button selected.';
    end

    local shared_name = SHARED.normalize_name(editor.shared_ref or editor.shared_name_buffer[1]);
    if (shared_name == nil) then
        return false, 'Choose a shared button first.';
    end
    if (SHARED.definition(shared_name) == nil) then
        return false, ('Shared button not found: %s'):fmt(shared_name);
    end

    local set_ok, set_err = set_slot_override(editor.profile_key, editor.group, editor.index, nil, nil, nil, nil, nil, shared_name);
    if (not set_ok) then
        return false, set_err;
    end

    local save_ok, save_message = save_button_overrides();
    if (not save_ok) then
        return false, save_message;
    end

    SHARED.load_into_editor(shared_name);
    log_info(save_message);
    return true, ('Assigned shared button: %s'):fmt(shared_name);
end

function SHARED.detach_editor_shared()
    local editor = state.macro_editor;
    if (editor == nil) then
        return;
    end

    editor.shared_ref = nil;
    editor.source = 'local edit';
end

local function remove_slot_override(profile_key, group, index)
    profile_key = normalize_profile_key(profile_key) or 'DEFAULT';
    local profiles = (state.macro_overrides and state.macro_overrides.profiles) or {};
    local profile = profiles[profile_key];
    local row = type(profile) == 'table' and profile[group] or nil;
    if (type(row) == 'table') then
        row[index] = nil;
    end

    prune_button_overrides();
end

function MACRO.set_empty_slot_override(profile_key, group, index)
    return set_slot_override(profile_key, group, index, '', '', '', 'single', {}, nil, false, false);
end

local function command_prefix_and_name(command)
    if (type(command) ~= 'string') then
        return nil, nil;
    end

    local prefix, rest = command:match('^%s*(/%S+)%s*(.*)$');
    if (prefix == nil) then
        return nil, nil;
    end

    local name = rest:match('^"([^"]+)"') or rest:match("^'([^']+)'") or rest:match('^(%S+)');
    return prefix:lower(), name;
end

function MACRO.command_is_weaponskill(command)
    local prefix = command_prefix_and_name(command);
    return prefix == '/ws' or prefix == '/weaponskill';
end

function MACRO.editor_is_weaponskill(editor)
    editor = editor or state.macro_editor;
    if (type(editor) ~= 'table') then
        return false;
    end

    local mode = MACRO.normalize_mode(editor.macro_mode);
    if (mode == 'weaponskill') then
        return true;
    end

    local _, command = MACRO.editor_commands();
    return MACRO.command_is_weaponskill(command);
end

function MACRO.editor_weaponskill_effect_values(editor)
    editor = editor or state.macro_editor;
    if (type(editor) ~= 'table' or not MACRO.editor_is_weaponskill(editor)) then
        return nil, nil, nil;
    end

    local style = editor.weaponskill_effect_enabled[1] == false and 'off' or (MACRO.normalize_weaponskill_effect_style(editor.weaponskill_effect) or 'pulse');
    local intensity = MACRO.normalize_weaponskill_effect_intensity(editor.weaponskill_effect_intensity[1]) or 70;
    local opacity = MACRO.normalize_weaponskill_effect_opacity(editor.weaponskill_effect_opacity[1]) or 100;
    local frequency = MACRO.normalize_weaponskill_effect_frequency(editor.weaponskill_effect_frequency[1]) or 100;
    return style, intensity, opacity, frequency;
end

function MACRO.apply_weaponskill_effect_to_slot(slot, style, intensity, opacity, frequency)
    if (type(slot) ~= 'table') then
        return;
    end

    style = MACRO.normalize_weaponskill_effect_style(style);
    if (style ~= nil) then
        slot.weaponskill_effect = style;
    end
    intensity = MACRO.normalize_weaponskill_effect_intensity(intensity);
    if (intensity ~= nil) then
        slot.weaponskill_effect_intensity = intensity;
    end
    opacity = MACRO.normalize_weaponskill_effect_opacity(opacity);
    if (opacity ~= nil) then
        slot.weaponskill_effect_opacity = opacity;
    end
    frequency = MACRO.normalize_weaponskill_effect_frequency(frequency);
    if (frequency ~= nil) then
        slot.weaponskill_effect_frequency = frequency;
    end
end

function MACRO.apply_config_toggle_to_slot(slot, id, value_a, value_b)
    if (type(slot) ~= 'table') then
        return false, 'No button selected.';
    end

    id = COMMAND_MODE.normalize_config_id(id);
    value_a = COMMAND_MODE.normalize_config_value(value_a);
    value_b = COMMAND_MODE.normalize_config_value(value_b);
    local validation_error = COMMAND_MODE.config_toggle_validation_error(id, value_a, value_b);
    if (validation_error ~= nil) then
        return false, validation_error;
    end

    slot.config_key = id;
    slot.config_value_a = value_a;
    slot.config_value_b = value_b;
    return true, nil;
end

function MACRO.load_editor_weaponskill_effect(editor, slot)
    if (type(editor) ~= 'table') then
        return;
    end

    slot = type(slot) == 'table' and slot or {};
    local style = MACRO.weaponskill_effect_style(slot);
    editor.weaponskill_effect_enabled[1] = style ~= 'off';
    editor.weaponskill_effect = (style == 'off') and 'pulse' or style;
    editor.weaponskill_effect_intensity[1] = MACRO.normalize_weaponskill_effect_intensity(slot.weaponskill_effect_intensity) or 70;
    editor.weaponskill_effect_opacity[1] = MACRO.normalize_weaponskill_effect_opacity(slot.weaponskill_effect_opacity) or 100;
    editor.weaponskill_effect_frequency[1] = MACRO.normalize_weaponskill_effect_frequency(slot.weaponskill_effect_frequency) or 100;
end

function MACRO.editor_page_label(editor)
    editor = editor or state.macro_editor;
    if (type(editor) ~= 'table') then
        return 'Button';
    end

    local function row_label_for(group)
        local row = ROW_BY_ID[group or 'base'];
        return row ~= nil and row.label or tostring(group or 'Button');
    end

    local row_label = row_label_for(editor.group);
    if (MACRO.editor_is_main_parent(editor)) then
        if (editor.group == editor.parent_group) then
            row_label = editor.bar_key == 'main' and 'Button' or BAR.extra_label(editor.bar_key);
        else
            row_label = ('%s %s'):fmt(editor.bar_key == 'main' and 'Button' or BAR.extra_label(editor.bar_key), row_label_for(editor.group));
        end
    end
    return ('%s %s %s'):fmt(editor.profile_key or 'DEFAULT', row_label, BAR.slot_index_label(editor.index or 1));
end

function MACRO.editor_snapshot_slot(editor)
    editor = editor or state.macro_editor;
    if (type(editor) ~= 'table' or editor.profile_key == nil or editor.group == nil or editor.index == nil) then
        return nil, 'No button selected.';
    end

    local mode, command, commands = MACRO.editor_commands();
    local use_action_name_label = COMMAND_MODE.is_structured_mode(mode) and editor.use_action_name_label[1] ~= false;
    local label = use_action_name_label and COMMAND_MODE.editor_action_label(editor, mode) or trim_one_line(editor.label_buffer[1], LIMITS.macro_label_max);
    local icon = (mode == 'item') and '' or trim_one_line(editor.icon_buffer[1], LIMITS.macro_icon_max);
    local slot = {
        label = label,
        command = command,
        macro_mode = mode,
    };

    if (COMMAND_MODE.is_structured_mode(mode)) then
        slot.use_action_name_label = use_action_name_label;
    end
    if (icon ~= '') then
        slot.icon = icon;
    end
    if (mode == 'multi') then
        slot.commands = MACRO.commands_from_table(commands);
        slot.command = slot.commands[1] or '';
        if (editor.run_as_script[1] == true) then
            slot.script = true;
        end
    end
    if (mode == 'configtoggle') then
        local ok, err = MACRO.apply_config_toggle_to_slot(slot, COMMAND_MODE.config_toggle_values_from_editor(editor));
        if (not ok) then
            return nil, err;
        end
    end
    MACRO.apply_weaponskill_effect_to_slot(slot, MACRO.editor_weaponskill_effect_values(editor));

    return slot, nil;
end

function MACRO.load_slot_into_editor(editor, slot, source)
    editor = editor or state.macro_editor;
    if (type(editor) ~= 'table') then
        return false, 'No button selected.';
    end

    slot = type(slot) == 'table' and copy_slot(slot) or {};
    local shared_ref = SHARED.normalize_name(slot.shared);
    local display_slot = (shared_ref ~= nil and SHARED.resolve_slot({ shared = shared_ref })) or slot;
    display_slot = type(display_slot) == 'table' and display_slot or {};

    editor.shared_ref = shared_ref;
    editor.source = source or ((shared_ref ~= nil) and ('shared: ' .. shared_ref) or 'local edit');
    buffer_set(editor.shared_name_buffer, shared_ref or '');
    buffer_set(editor.label_buffer, display_slot.label or '');
    buffer_set(editor.command_buffer, MACRO.primary_command(display_slot));
    buffer_set(editor.commands_buffer, MACRO.commands_to_text(MACRO.slot_commands(display_slot)));
    buffer_set(editor.icon_buffer, display_slot.icon or '');
    COMMAND_MODE.load_editor_slot(editor, display_slot);
    MACRO.load_editor_weaponskill_effect(editor, display_slot);
    if (editor.icon_picker_visible ~= nil) then
        editor.icon_picker_visible[1] = false;
    end

    return true;
end

function MACRO.copy_editor_page()
    local editor = state.macro_editor;
    local slot, err = MACRO.editor_snapshot_slot(editor);
    if (slot == nil) then
        return false, err;
    end

    state.macro_clipboard = {
        slot = copy_slot(slot),
        label = MACRO.editor_page_label(editor),
    };
    return true, ('Copied %s.'):fmt(state.macro_clipboard.label);
end

function MACRO.paste_editor_page()
    local editor = state.macro_editor;
    if (type(editor) ~= 'table' or editor.profile_key == nil or editor.group == nil or editor.index == nil) then
        return false, 'No button selected.';
    end
    if (type(state.macro_clipboard) ~= 'table' or type(state.macro_clipboard.slot) ~= 'table') then
        return false, 'Nothing copied yet.';
    end

    local source_label = state.macro_clipboard.label or 'copied page';
    local ok, err = MACRO.load_slot_into_editor(editor, state.macro_clipboard.slot, 'pasted from ' .. source_label);
    if (not ok) then
        return false, err;
    end

    return true, ('Pasted into %s. Save to keep it.'):fmt(MACRO.editor_page_label(editor));
end

function MACRO.apply_editor_modifier_toggles()
    local editor = state.macro_editor;
    if (type(editor) ~= 'table' or not MACRO.editor_is_main_parent(editor) or editor.group ~= editor.parent_group) then
        return true;
    end

    if (editor.modifier_ctrl_enabled[1] == false) then
        local ok, err = MACRO.set_empty_slot_override(editor.profile_key, BAR.modifier_row_id(editor.parent_group, 'ctrl'), editor.index);
        if (not ok) then return false, err; end
    end
    if (editor.modifier_alt_enabled[1] == false) then
        local ok, err = MACRO.set_empty_slot_override(editor.profile_key, BAR.modifier_row_id(editor.parent_group, 'alt'), editor.index);
        if (not ok) then return false, err; end
    end
    if (editor.modifier_shift_enabled[1] == false) then
        local ok, err = MACRO.set_empty_slot_override(editor.profile_key, BAR.modifier_row_id(editor.parent_group, 'shift'), editor.index);
        if (not ok) then return false, err; end
    end

    return true;
end

local function editor_row_label(group)
    local row = ROW_BY_ID[group];
    if (row == nil) then
        return group or 'base';
    end

    return row.label;
end

function MACRO.editor_parent_group(group)
    return BAR.parent_group(group);
end

function MACRO.editor_is_main_parent(editor)
    return type(editor) == 'table' and BAR.row_supports_modifiers(editor.parent_group);
end

function MACRO.initialize_editor_modifier_state(editor, profile, profile_key, index, preserve)
    if (not MACRO.editor_is_main_parent(editor)) then
        editor.modifier_ctrl_enabled[1] = false;
        editor.modifier_alt_enabled[1] = false;
        editor.modifier_shift_enabled[1] = false;
        return;
    end

    if (preserve == true) then
        return;
    end

    editor.modifier_ctrl_enabled[1] = MACRO.slot_has_action(MACRO.get_slot_without_editor_preview(profile, profile_key, BAR.modifier_row_id(editor.parent_group, 'ctrl'), index));
    editor.modifier_alt_enabled[1] = MACRO.slot_has_action(MACRO.get_slot_without_editor_preview(profile, profile_key, BAR.modifier_row_id(editor.parent_group, 'alt'), index));
    editor.modifier_shift_enabled[1] = MACRO.slot_has_action(MACRO.get_slot_without_editor_preview(profile, profile_key, BAR.modifier_row_id(editor.parent_group, 'shift'), index));
end

local function open_macro_editor(row, index, preserve_modifier_state)
    local group = (row ~= nil and row.id) or 'base';
    local parent_group = MACRO.editor_parent_group(group);
    local bar_key = BAR.key_for_group(parent_group);
    local profile = refresh_profile_context(bar_key);
    local profile_key = editable_profile_key(profile);
    local slot = get_slot(group, index) or {};
    local override = get_slot_override(profile_key, group, index);
    local shared_ref = SHARED.normalize_name(slot.shared);
    local source = (shared_ref ~= nil) and ('shared: ' .. shared_ref) or ((override ~= nil) and 'saved edit' or profile.source);
    local editor = state.macro_editor;

    editor.visible[1] = true;
    if (editor.icon_picker_visible ~= nil) then
        editor.icon_picker_visible[1] = false;
    end
    editor.bar_key = bar_key;
    editor.parent_group = parent_group;
    editor.profile_key = profile_key;
    editor.group = group;
    editor.index = index;
    MACRO.initialize_editor_modifier_state(editor, profile, profile_key, index, preserve_modifier_state == true);
    MACRO.load_slot_into_editor(editor, slot, source);
    editor.message = nil;
end

local function save_macro_editor(clear_slot)
    local editor = state.macro_editor;
    if (editor.profile_key == nil or editor.group == nil or editor.index == nil) then
        editor.message = 'No button selected.';
        editor.message_color = UI_COLORS.error;
        return false;
    end

    local shared_ref = (not clear_slot) and SHARED.normalize_name(editor.shared_ref) or nil;
    if (shared_ref ~= nil) then
        local slot, slot_error = SHARED.editor_slot(true);
        if (slot == nil) then
            editor.message = slot_error;
            editor.message_color = UI_COLORS.error;
            return false;
        end

        SHARED.definitions()[shared_ref] = slot;
        local set_ok, set_err = set_slot_override(editor.profile_key, editor.group, editor.index, nil, nil, nil, nil, nil, shared_ref);
        if (not set_ok) then
            editor.message = set_err;
            editor.message_color = UI_COLORS.error;
            return false;
        end

        local modifier_ok, modifier_err = MACRO.apply_editor_modifier_toggles();
        if (not modifier_ok) then
            editor.message = modifier_err;
            editor.message_color = UI_COLORS.error;
            return false;
        end

        local save_ok, save_message = save_button_overrides();
        if (not save_ok) then
            editor.message = save_message;
            editor.message_color = UI_COLORS.error;
            log_warn(save_message);
            return false;
        end

        editor.source = 'shared: ' .. shared_ref;
        buffer_set(editor.shared_name_buffer, shared_ref);
        editor.message = ('Saved shared: %s'):fmt(shared_ref);
        editor.message_color = UI_COLORS.success;
        log_info(save_message);
        return true;
    end

    local mode, command, commands = MACRO.editor_commands();
    local use_action_name_label = COMMAND_MODE.is_structured_mode(mode) and editor.use_action_name_label[1] ~= false;
    local label = clear_slot and '' or (use_action_name_label and COMMAND_MODE.editor_action_label(editor, mode) or trim_one_line(editor.label_buffer[1], LIMITS.macro_label_max));
    command = clear_slot and '' or command;
    commands = clear_slot and {} or commands;
    local icon = clear_slot and '' or trim_one_line(editor.icon_buffer[1], LIMITS.macro_icon_max);
    if (mode == 'item') then
        icon = '';
    end
    local validation_error = ((not clear_slot) and COMMAND_MODE.editor_selection_validation_error(mode, editor))
        or MACRO.commands_validation_error(commands);
    if (validation_error ~= nil) then
        editor.message = validation_error;
        editor.message_color = UI_COLORS.error;
        return false;
    end

    local weaponskill_effect, weaponskill_effect_intensity, weaponskill_effect_opacity, weaponskill_effect_frequency = MACRO.editor_weaponskill_effect_values(editor);
    local config_key, config_value_a, config_value_b = nil, nil, nil;
    if (mode == 'configtoggle' and not clear_slot) then
        config_key, config_value_a, config_value_b = COMMAND_MODE.config_toggle_values_from_editor(editor);
    end
    local set_ok, set_err = set_slot_override(editor.profile_key, editor.group, editor.index, label, command, icon, mode, commands, nil, use_action_name_label, mode == 'multi' and editor.run_as_script[1] == true, weaponskill_effect, weaponskill_effect_intensity, weaponskill_effect_opacity, weaponskill_effect_frequency, config_key, config_value_a, config_value_b);
    if (not set_ok) then
        editor.message = set_err;
        editor.message_color = UI_COLORS.error;
        return false;
    end

    local modifier_ok, modifier_err = MACRO.apply_editor_modifier_toggles();
    if (not modifier_ok) then
        editor.message = modifier_err;
        editor.message_color = UI_COLORS.error;
        return false;
    end

    local save_ok, save_message = save_button_overrides();
    if (not save_ok) then
        editor.message = save_message;
        editor.message_color = UI_COLORS.error;
        log_warn(save_message);
        return false;
    end

    buffer_set(editor.label_buffer, label);
    buffer_set(editor.command_buffer, command);
    buffer_set(editor.commands_buffer, MACRO.commands_to_text(commands));
    editor.macro_mode = mode;
    editor.run_as_script[1] = mode == 'multi' and editor.run_as_script[1] == true;
    editor.shared_ref = nil;
    buffer_set(editor.icon_buffer, icon);
    editor.source = 'saved edit';
    editor.message = clear_slot and 'Cleared.' or 'Saved.';
    editor.message_color = UI_COLORS.success;
    log_info(save_message);
    return true;
end

local function reset_macro_editor()
    local editor = state.macro_editor;
    if (editor.profile_key == nil or editor.group == nil or editor.index == nil) then
        return false;
    end

    remove_slot_override(editor.profile_key, editor.group, editor.index);
    local save_ok, save_message = save_button_overrides();
    if (not save_ok) then
        editor.message = save_message;
        editor.message_color = UI_COLORS.error;
        log_warn(save_message);
        return false;
    end

    local profile = refresh_profile_context(editor.bar_key or BAR.key_for_group(editor.group));
    local slot = SHARED.resolve_slot(get_raw_config_slot(profile, editor.group, editor.index));
    slot = MACRO.normalize_slot_runtime(slot) or {};
    editor.shared_ref = SHARED.normalize_name(slot.shared);
    buffer_set(editor.shared_name_buffer, editor.shared_ref or '');
    buffer_set(editor.label_buffer, slot.label or '');
    buffer_set(editor.command_buffer, MACRO.primary_command(slot));
    buffer_set(editor.commands_buffer, MACRO.commands_to_text(MACRO.slot_commands(slot)));
    buffer_set(editor.icon_buffer, slot.icon or '');
    COMMAND_MODE.load_editor_slot(editor, slot);
    MACRO.load_editor_weaponskill_effect(editor, slot);
    editor.source = (editor.shared_ref ~= nil) and ('shared: ' .. editor.shared_ref) or profile.source;
    editor.message = 'Reset to config.';
    editor.message_color = UI_COLORS.success;
    log_info(save_message);
    return true;
end

local function icon_selector_label(token)
    token = trim_one_line(token, LIMITS.macro_icon_max);
    if (token == '') then
        return 'Auto (infer from command)';
    end

    local normalized = DEFERRED.normalize_icon_token(token);
    if (normalized ~= nil) then
        local base = normalized;
        local sigil_base = normalized:match('^sigil_(.+)$');
        if (sigil_base ~= nil) then
            base = sigil_base;
        end

        if (ICON_DEFS[base] ~= nil) then
            if (ICON_DEFS[base].asset ~= nil) then
                return base:gsub('^asset_', 'image: ');
            end
            if (sigil_base ~= nil) then
                return ('%s (sigil)'):fmt(base);
            end

            return base;
        end
    end

    return 'Custom: ' .. token;
end

function SHARED.render_selector(editor)
    local shared = SHARED.definitions();
    local selected = SHARED.normalize_name(editor.shared_ref);
    local selected_label = selected or 'None (local button)';

    imgui.PushItemWidth(360);
    if (imgui.BeginCombo('Shared Button##ashitabars_button_shared_select', selected_label, ImGuiComboFlags_None)) then
        if (imgui.Selectable('None (local button)', selected == nil)) then
            editor.shared_ref = nil;
            editor.source = 'local edit';
        end

        for _, name in ipairs(sorted_keys(shared)) do
            if (imgui.Selectable(name, selected == name)) then
                local ok, message = SHARED.load_into_editor(name);
                if (not ok) then
                    editor.message = message;
                    editor.message_color = UI_COLORS.error;
                end
            end
        end

        imgui.EndCombo();
    end
    imgui.PopItemWidth();
end

local function setting_enabled(name, fallback)
    local settings = state.config.settings or {};
    if (settings[name] == nil) then
        return fallback;
    end

    return settings[name] ~= false;
end

local function setting_number(name, fallback)
    local settings = state.config.settings or {};
    local value = tonumber(settings[name]);
    if (value == nil) then
        return fallback;
    end

    return value;
end

function MACRO.normalize_weaponskill_effect_style(value)
    if (type(value) ~= 'string') then
        return nil;
    end

    local style = value:lower():gsub('%s+', ''):gsub('%-', '_');
    if (style == 'pulse' or style == 'native' or style == 'nativepulse') then
        return 'pulse';
    end
    if (style == 'off' or style == 'none' or style == 'disabled') then
        return 'off';
    end

    return nil;
end

function MACRO.weaponskill_pulse_enabled(settings)
    settings = settings or state.config.settings or {};
    if (settings.show_weaponskill_pulse ~= nil) then
        return settings.show_weaponskill_pulse ~= false;
    end
    if (settings.show_weaponskill_flames ~= nil) then
        return settings.show_weaponskill_flames ~= false;
    end

    return DEFAULT_CONFIG.settings.show_weaponskill_pulse ~= false;
end

function MACRO.weaponskill_effect_style(slot)
    local style = MACRO.normalize_weaponskill_effect_style(slot ~= nil and slot.weaponskill_effect or nil);
    if (slot ~= nil and (slot.weaponskill_effect_enabled == false or style == 'off')) then
        return 'off';
    end
    return style or 'pulse';
end

function MACRO.normalize_weaponskill_effect_intensity(value)
    return normalize_percent(value, LIMITS.weaponskill_effect_intensity_min, LIMITS.weaponskill_effect_intensity_max);
end

function MACRO.normalize_weaponskill_effect_opacity(value)
    return normalize_percent(value, LIMITS.weaponskill_effect_opacity_min, LIMITS.weaponskill_effect_opacity_max);
end

function MACRO.normalize_weaponskill_effect_frequency(value)
    return normalize_percent(value, LIMITS.weaponskill_effect_frequency_min, LIMITS.weaponskill_effect_frequency_max);
end

function COMMAND_MODE.commands_for_execution(commands, options)
    if (type(commands) ~= 'table' or #commands ~= 1 or (type(options) == 'table' and options.script == true)) then
        return commands;
    end

    local config_toggle = type(options) == 'table' and options.config_toggle or nil;
    local slot = type(options) == 'table' and options.slot or nil;
    if (config_toggle ~= nil or (type(slot) == 'table' and slot.config_key ~= nil)) then
        local id = config_toggle ~= nil and config_toggle.key or slot.config_key;
        local value_a = config_toggle ~= nil and config_toggle.value_a or slot.config_value_a;
        local value_b = config_toggle ~= nil and config_toggle.value_b or slot.config_value_b;
        local validation_error = COMMAND_MODE.config_toggle_validation_error(
            COMMAND_MODE.normalize_config_id(id),
            COMMAND_MODE.normalize_config_value(value_a),
            COMMAND_MODE.normalize_config_value(value_b));
        if (validation_error ~= nil) then
            log_warn(('Config toggle rejected: %s'):fmt(validation_error));
            return {};
        end

        local command, read_error = COMMAND_MODE.config_toggle_next_command(id, value_a, value_b);
        if (command == nil) then
            log_warn(('Config toggle rejected: %s'):fmt(read_error or 'Unable to read current config value.'));
            return {};
        end

        return { command };
    end

    local server_action = COMMAND_MODE.server_action_for_command(commands[1]);
    if (server_action ~= nil) then
        local runtime_action = COMMAND_MODE.server_runtime_action(server_action);
        return { ('/say %s'):fmt(runtime_action.command) };
    end

    local prefix = command_prefix_and_name(commands[1]);
    if (prefix == '/mount' and COMMAND_MODE.player_is_mounted()) then
        return { '/dismount' };
    end

    return commands;
end

function COMMAND_MODE.track_command_execution(commands)
    if (type(commands) ~= 'table' or #commands ~= 1) then
        return;
    end

    local prefix = command_prefix_and_name(commands[1]);
    if (prefix == '/mount') then
        COMMAND_MODE.start_mount_recast_overlay();
    end
end

local function command_recast_action(command)
    local prefix, name = command_prefix_and_name(command);
    if (prefix == nil) then
        return nil, nil;
    end

    local kind = nil;
    if (prefix == '/ma' or prefix == '/magic') then
        kind = 'spell';
    elseif (prefix == '/ja' or prefix == '/jobability' or prefix == '/pet') then
        kind = 'ability';
    elseif (prefix == '/mount') then
        kind = 'mount';
    else
        return nil, nil;
    end

    if (type(name) ~= 'string' or name == '') then
        return nil, nil;
    end

    return kind, name;
end

local function spell_recast_source(resources, name)
    local spell = safe_read(function ()
        return resources:GetSpellByName(name, 0);
    end, nil);
    if (spell == nil) then
        return nil;
    end

    local spell_id = safe_read(function ()
        return spell.Index;
    end, safe_read(function ()
        return spell.Id;
    end, nil));
    spell_id = tonumber(spell_id);
    if (spell_id == nil) then
        return nil;
    end

    local recast_delay = tonumber(safe_read(function ()
        return spell.RecastDelay;
    end, nil));
    local total = nil;
    if (recast_delay ~= nil and recast_delay > 0) then
        total = recast_delay * 15;
    end

    local mp_cost = tonumber(safe_read(function ()
        return spell.ManaCost;
    end, safe_read(function ()
        return spell.MpCost;
    end, nil)));

    return {
        kind = 'spell',
        key = ('spell:%d'):fmt(math.floor(spell_id)),
        id = math.floor(spell_id),
        name = name,
        total = total,
        mp_cost = mp_cost,
    };
end

local function ability_recast_source(resources, name)
    local ability = safe_read(function ()
        return resources:GetAbilityByName(name, 0);
    end, nil);
    if (ability == nil) then
        return nil;
    end

    local timer_id = tonumber(safe_read(function ()
        return ability.RecastTimerId;
    end, nil));
    if (timer_id == nil or timer_id <= 0) then
        return nil;
    end

    local recast_time = tonumber(safe_read(function ()
        return ability.RecastTime;
    end, nil));
    local total = nil;
    if (recast_time ~= nil and recast_time > 0) then
        total = recast_time * 60;
    end

    return {
        kind = 'ability',
        key = ('ability:%d'):fmt(math.floor(timer_id)),
        timer_id = math.floor(timer_id),
        name = name,
        total = total,
    };
end

local function recast_source_for_command(command)
    if (type(command) ~= 'string' or command == '') then
        return nil;
    end

    local cached = state.recast_cache[command];
    if (cached ~= nil) then
        if (cached == false) then
            return nil;
        end
        return cached;
    end

    local kind, name = command_recast_action(command);
    if (kind == nil or name == nil) then
        state.recast_cache[command] = false;
        return nil;
    end

    if (kind == 'mount') then
        name = COMMAND_MODE.clean_name(name);
        state.recast_cache[command] = {
            kind = 'mount',
            key = 'mount',
            name = name ~= '' and name or 'Mount',
            total = 60,
            timer_units = 'seconds',
        };
        return state.recast_cache[command];
    end

    local resources = safe_read(function ()
        return AshitaCore:GetResourceManager();
    end, nil);
    if (resources == nil) then
        state.recast_cache[command] = false;
        return nil;
    end

    local source = nil;
    if (kind == 'spell') then
        source = spell_recast_source(resources, name);
    elseif (kind == 'ability') then
        source = ability_recast_source(resources, name);
    end

    state.recast_cache[command] = source or false;
    return source;
end

local function seconds_from_recast_timer(timer)
    timer = tonumber(timer);
    if (timer == nil or timer <= 0) then
        return 0;
    end

    return math.max(1, math.ceil(timer / 60));
end

local function format_recast_seconds(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0));
    if (seconds >= 3600) then
        local hours = math.floor(seconds / 3600);
        local minutes = math.floor((seconds % 3600) / 60);
        return ('%d:%02d'):fmt(hours, minutes);
    end

    if (seconds >= 60) then
        local minutes = math.floor(seconds / 60);
        local remaining = seconds % 60;
        return ('%d:%02d'):fmt(minutes, remaining);
    end

    return tostring(seconds);
end

local function spell_recast_timer(spell_id)
    local recast = safe_read(function ()
        return AshitaCore:GetMemoryManager():GetRecast();
    end, nil);
    if (recast == nil) then
        return 0;
    end

    return tonumber(safe_read(function ()
        return recast:GetSpellTimer(spell_id);
    end, 0)) or 0;
end

local function ability_recast_timer(timer_id)
    local recast = safe_read(function ()
        return AshitaCore:GetMemoryManager():GetRecast();
    end, nil);
    if (recast == nil) then
        return 0;
    end

    for slot = 0, 31, 1 do
        local active_timer_id = tonumber(safe_read(function ()
            return recast:GetAbilityTimerId(slot);
        end, nil));
        if (active_timer_id == timer_id) then
            return tonumber(safe_read(function ()
                return recast:GetAbilityTimer(slot);
            end, 0)) or 0;
        end
    end

    return 0;
end

local function slot_recast(slot)
    if (slot == nil or slot.recast == false or not setting_enabled('show_recasts', true)) then
        return nil;
    end

    local source = recast_source_for_command(slot.command);
    if (source == nil) then
        return nil;
    end

    local timer = 0;
    if (source.kind == 'spell') then
        timer = spell_recast_timer(source.id);
    elseif (source.kind == 'ability') then
        timer = ability_recast_timer(source.timer_id);
    elseif (source.kind == 'mount') then
        local mount_overlay = COMMAND_MODE.mount_recast_overlay_info();
        if (mount_overlay == nil) then
            return nil;
        end
        timer = mount_overlay.timer;
        source.total = mount_overlay.total;
    end

    if (timer <= 0) then
        return nil;
    end

    local total = tonumber(state.recast_totals[source.key]) or tonumber(source.total) or timer;
    if (source.total ~= nil and source.total > total) then
        total = source.total;
    end
    if (timer > total) then
        total = timer;
    end
    state.recast_totals[source.key] = total;

    local fraction = 1.0;
    if (total > 0) then
        fraction = timer / total;
    end
    if (fraction < 0) then
        fraction = 0;
    elseif (fraction > 1) then
        fraction = 1;
    end

    local seconds = (source.timer_units == 'seconds') and math.max(1, math.ceil(timer)) or seconds_from_recast_timer(timer);
    return {
        kind = source.kind,
        name = source.name,
        timer = timer,
        total = total,
        fraction = fraction,
        seconds = seconds,
        label = format_recast_seconds(seconds),
    };
end

function MACRO.run_overlay_info(context)
    local key = MACRO.run_key(context);
    if (key == nil or type(state.macro_runs) ~= 'table') then
        return nil;
    end

    local run = state.macro_runs[key];
    if (type(run) ~= 'table') then
        return nil;
    end

    local total = tonumber(run.total) or 0;
    local expires_at = tonumber(run.expires_at) or 0;
    local remaining = math.max(0, math.ceil(expires_at - os.time()));
    if (total <= 0 or remaining <= 0) then
        state.macro_runs[key] = nil;
        return nil;
    end

    return {
        kind = 'macro',
        total = total,
        seconds = remaining,
        fraction = math.min(1.0, math.max(0.0, remaining / total)),
        label = format_recast_seconds(remaining),
    };
end

local function item_source_for_command(command)
    if (type(command) ~= 'string' or command == '') then
        return nil;
    end

    local cached = state.item_source_cache[command];
    if (cached ~= nil) then
        if (cached == false) then
            return nil;
        end
        return cached;
    end

    local prefix, name = command_prefix_and_name(command);
    if (prefix ~= '/item' or type(name) ~= 'string' or name == '') then
        state.item_source_cache[command] = false;
        return nil;
    end

    local resources = safe_read(function ()
        return AshitaCore:GetResourceManager();
    end, nil);
    if (resources == nil) then
        state.item_source_cache[command] = false;
        return nil;
    end

    local item = safe_read(function ()
        return resources:GetItemByName(name, 0);
    end, nil) or safe_read(function ()
        return resources:GetItemByName(name);
    end, nil);
    if (item == nil) then
        state.item_source_cache[command] = false;
        return nil;
    end

    local item_id = tonumber(safe_read(function ()
        return item.Id;
    end, safe_read(function ()
        return item.Index;
    end, nil)));
    if (item_id == nil or item_id <= 0) then
        state.item_source_cache[command] = false;
        return nil;
    end

    local source = {
        kind = 'item',
        key = ('item:%d'):fmt(math.floor(item_id)),
        id = math.floor(item_id),
        name = name,
    };
    state.item_source_cache[command] = source;
    return source;
end

DEFERRED.item_count = function (item_id)
    item_id = tonumber(item_id);
    if (item_id == nil or item_id <= 0) then
        return nil;
    end

    local now = os.clock();
    local cached = state.item_count_cache[item_id];
    if (cached ~= nil and (now - cached.at) <= LIMITS.item_count_cache_seconds) then
        return cached.count;
    end

    local inventory = safe_read(function ()
        return AshitaCore:GetMemoryManager():GetInventory();
    end, nil);
    if (inventory == nil) then
        return nil;
    end

    local total = 0;
    for _, container_id in ipairs(LIMITS.item_count_containers) do
        local max = tonumber(safe_read(function ()
            return inventory:GetContainerCountMax(container_id);
        end, 0)) or 0;

        for slot = 0, max, 1 do
            local item = safe_read(function ()
                return inventory:GetContainerItem(container_id, slot);
            end, nil);
            local id = item ~= nil and tonumber(item.Id) or nil;
            if (id == item_id) then
                local count = tonumber(item.Count) or 1;
                total = total + math.max(1, count);
            end
        end
    end

    state.item_count_cache[item_id] = {
        at = now,
        count = total,
    };
    return total;
end

local function current_mp()
    return tonumber(safe_read(function ()
        return AshitaCore:GetMemoryManager():GetParty():GetMemberMP(0);
    end, nil));
end

local function current_tp()
    return tonumber(safe_read(function ()
        return AshitaCore:GetMemoryManager():GetParty():GetMemberTP(0);
    end, nil));
end

local function slot_weaponskill_pulse_info(slot)
    if (slot == nil or type(slot.command) ~= 'string' or slot.command == '' or not MACRO.weaponskill_pulse_enabled()) then
        return nil;
    end

    local prefix = command_prefix_and_name(slot.command);
    if (prefix ~= '/ws' and prefix ~= '/weaponskill') then
        return nil;
    end
    local style = MACRO.weaponskill_effect_style(slot);
    if (style == 'off') then
        return nil;
    end

    local tp = current_tp();
    local threshold = tonumber(slot.tp_threshold) or setting_number('weaponskill_tp_threshold', 1000);
    if (tp == nil or threshold == nil or threshold <= 0) then
        return nil;
    end

    local max_tp = math.max(3000, threshold);
    local ready = tp >= threshold;
    local pre_ready = math.min(1.0, math.max(0.0, tp / threshold));
    local post_ready = 0.0;
    if (max_tp > threshold) then
        post_ready = math.min(1.0, math.max(0.0, (tp - threshold) / (max_tp - threshold)));
    end

    local intensity = ready and (0.62 + (0.38 * post_ready)) or (0.12 + (0.43 * pre_ready));
    local effect_intensity = (MACRO.normalize_weaponskill_effect_intensity(slot.weaponskill_effect_intensity) or 70) / 100.0;
    local effect_opacity = (MACRO.normalize_weaponskill_effect_opacity(slot.weaponskill_effect_opacity) or 100) / 100.0;
    local effect_frequency = MACRO.normalize_weaponskill_effect_frequency(slot.weaponskill_effect_frequency) or 100;
    return {
        style = style,
        tp = tp,
        threshold = threshold,
        ready = ready,
        intensity = math.min(1.0, math.max(0.0, intensity * effect_intensity)),
        opacity = math.min(1.0, math.max(0.0, effect_opacity)),
        frequency = effect_frequency,
    };
end

local function slot_server_buff_pulse_info(slot)
    if (slot == nil or type(slot.command) ~= 'string' or slot.command == '') then
        return nil;
    end

    local server_action = COMMAND_MODE.server_action_for_command(slot.command);
    local runtime_action = COMMAND_MODE.server_runtime_action(server_action);
    if (runtime_action == nil or type(runtime_action.buff) ~= 'string' or runtime_action.buff == '') then
        return nil;
    end
    if (COMMAND_MODE.player_has_status(runtime_action.buff)) then
        return nil;
    end

    return {
        style = 'pulse',
        ready = true,
        intensity = 0.74,
        opacity = 0.82,
        frequency = 82,
        warm_color = { 0.36, 0.78, 0.42 },
        border_color = { 0.70, 1.00, 0.56 },
        inner_color = { 1.00, 0.94, 0.48 },
        call_color = { 0.52, 1.00, 0.44 },
        core_color = { 0.24, 0.86, 0.36 },
    };
end

local function format_count(value)
    value = math.max(0, math.floor(tonumber(value) or 0));
    if (value >= 1000000) then
        return ('%dm'):fmt(math.floor(value / 1000000));
    end
    if (value >= 10000) then
        return ('%dk'):fmt(math.floor(value / 1000));
    end
    if (value >= 1000) then
        local compact = ('%.1fk'):fmt(value / 1000);
        return compact:gsub('%.0k$', 'k');
    end

    return tostring(value);
end

local function slot_visual_state(slot)
    if (slot == nil or type(slot.command) ~= 'string' or slot.command == '') then
        return nil;
    end

    local show_counts = setting_enabled('show_counts', true) and slot.count ~= false;
    local show_availability = setting_enabled('show_availability', true) and slot.availability ~= false;
    if (not show_counts and not show_availability) then
        return nil;
    end

    local prefix, action_name = command_prefix_and_name(slot.command);
    local state_info = {
        available = true,
    };

    if (prefix == '/item') then
        local source = item_source_for_command(slot.command);
        if (source ~= nil) then
            local count = DEFERRED.item_count(source.id);
            if (count ~= nil) then
                state_info.kind = 'item';
                state_info.count = count;
                state_info.count_label = show_counts and format_count(count) or nil;
                if (show_availability and count <= 0) then
                    state_info.available = false;
                    state_info.reason = 'item count is 0';
                    state_info.reason_label = '0';
                end
            end
        end
    elseif (prefix == '/ma' or prefix == '/magic') then
        local source = recast_source_for_command(slot.command);
        local cost = source ~= nil and tonumber(source.mp_cost) or nil;
        local mp = current_mp();
        if (show_availability and cost ~= nil and cost > 0 and mp ~= nil and mp < cost) then
            state_info.kind = 'spell';
            state_info.available = false;
            state_info.reason = ('MP %d/%d'):fmt(mp, cost);
            state_info.reason_label = 'MP';
        end
    elseif (prefix == '/ws' or prefix == '/weaponskill') then
        local threshold = tonumber(slot.tp_threshold) or setting_number('weaponskill_tp_threshold', 1000);
        local tp = current_tp();
        if (show_availability and threshold ~= nil and threshold > 0 and tp ~= nil and tp < threshold) then
            state_info.kind = 'weaponskill';
            state_info.available = false;
            state_info.reason = ('TP %d/%d'):fmt(tp, threshold);
            state_info.reason_label = 'TP';
        end
    elseif (prefix == '/pet') then
        local available = COMMAND_MODE.pet_command_available_now(action_name);
        if (show_availability and available == false) then
            state_info.kind = 'pet';
            state_info.available = false;
            state_info.reason = ('%s unavailable'):fmt(action_name or 'Pet command');
            state_info.reason_label = 'PET';
        end
    end

    if (state_info.kind == nil and state_info.count_label == nil and state_info.available == true) then
        return nil;
    end

    return state_info;
end

local function icon_style()
    local settings = state.config.settings or {};
    local style = settings.icon_style;
    if (type(style) == 'string') then
        style = style:lower():gsub('%s+', '');
        if (style == 'auto' or style == 'configured' or style == 'none') then
            return style;
        end
    end

    return DEFAULT_CONFIG.settings.icon_style;
end

local function normalize_theme_key(value)
    if (type(value) ~= 'string') then
        return nil;
    end

    local key = value:lower():gsub('[%s%-]+', '_'):gsub('[^%w_]+', ''):gsub('_+', '_'):gsub('^_', ''):gsub('_$', '');
    if (key == '') then
        return nil;
    end

    return THEME_ALIASES[key] or key;
end

local function current_theme()
    local settings = state.config.settings or {};
    local key = normalize_theme_key(settings.theme);
    if (key ~= nil and THEMES[key] ~= nil) then
        return THEMES[key], key;
    end

    local default_key = normalize_theme_key(DEFAULT_CONFIG.settings.theme) or 'ffxi';
    return THEMES[default_key] or THEMES.ffxi, default_key;
end

DEFERRED.normalize_icon_token = function (value)
    if (type(value) ~= 'string') then
        return nil;
    end

    local token = value:lower():gsub('[%s%-]+', '_'):gsub('[^%w_]+', ''):gsub('_+', '_'):gsub('^_', ''):gsub('_$', '');
    if (token == '') then
        return nil;
    end

    local sigil_base = token:match('^sigil_(.+)$');
    if (sigil_base ~= nil) then
        return 'sigil_' .. (ICON_ALIASES[sigil_base] or sigil_base);
    end

    return ICON_ALIASES[token] or token;
end

local function color_with_alpha(color, alpha)
    return { color[1], color[2], color[3], alpha };
end

local function color_u32(color)
    return imgui.GetColorU32(color);
end

local function command_family(slot)
    if (slot == nil or type(slot.command) ~= 'string' or slot.command == '') then
        return 'empty';
    end

    local command = slot.command:lower();
    local prefix = command:match('^%s*(/%S+)') or '';

    if (COMMAND_MODE.server_action_for_command(slot.command) ~= nil) then
        return 'server';
    end

    if (prefix == '/ma' or prefix == '/magic') then
        for _, hint in ipairs(WHITE_MAGIC_HINTS) do
            if (command:find(hint, 1, true) ~= nil) then
                return 'white_magic';
            end
        end
        return 'black_magic';
    end

    if (prefix == '/ja' or prefix == '/jobability' or prefix == '/pet') then
        return 'ability';
    end
    if (prefix == '/ws' or prefix == '/weaponskill' or prefix == '/ra' or prefix == '/range' or prefix == '/shoot') then
        return 'weapon';
    end
    if (prefix == '/item' or prefix == '/heal') then
        return 'item';
    end
    if (prefix == '/mount') then
        return 'mount';
    end
    if (prefix == '/trusts') then
        return 'ability';
    end
    if (prefix == '/target' or prefix == '/assist' or prefix == '/attack' or prefix == '/check') then
        return 'target';
    end
    if (prefix == '/echo' or prefix == '/p' or prefix == '/party' or prefix == '/l' or prefix == '/linkshell' or prefix == '/say' or prefix == '/tell') then
        return 'chat';
    end

    return 'command';
end

local function command_has_any(command, hints)
    for _, hint in ipairs(hints) do
        if (command:find(hint, 1, true) ~= nil) then
            return true;
        end
    end

    return false;
end

local function infer_icon_token(slot, family)
    if (slot == nil or type(slot.command) ~= 'string') then
        return family;
    end

    local command = slot.command:lower();
    local prefix = command:match('^%s*(/%S+)') or '';
    local server_action = COMMAND_MODE.server_action_for_command(slot.command);

    if (server_action ~= nil) then
        local runtime_action = COMMAND_MODE.server_runtime_action(server_action);
        return (runtime_action ~= nil and runtime_action.icon) or server_action.icon or 'buff';
    end

    if (prefix == '/heal') then return 'rest'; end
    if (prefix == '/target' or prefix == '/targetnpc' or prefix == '/targetbnpc' or prefix == '/attack') then return 'target'; end
    if (prefix == '/assist') then return 'assist'; end
    if (prefix == '/check') then return 'check'; end
    if (prefix == '/map') then return 'map'; end
    if (prefix == '/item') then return 'item'; end
    if (prefix == '/mount') then return 'mount'; end
    if (prefix == '/trusts') then return 'summon'; end
    if (prefix == '/ja' or prefix == '/jobability' or prefix == '/pet') then return 'ability'; end
    if (prefix == '/ra' or prefix == '/range' or prefix == '/shoot') then return 'ranged'; end
    if (prefix == '/ws' or prefix == '/weaponskill') then return 'weapon'; end
    if (prefix == '/echo' or prefix == '/p' or prefix == '/party' or prefix == '/l' or prefix == '/linkshell' or prefix == '/say' or prefix == '/tell') then return 'chat'; end

    if (prefix == '/ma' or prefix == '/magic') then
        if (command_has_any(command, { 'cure', 'curaga' })) then
            return 'cure';
        end
        if (command_has_any(command, { 'dia', 'banish', 'holy' })) then
            return 'holy';
        end
        if (command_has_any(command, { 'protect', 'shell', 'bar', 'regen', 'haste', 'aquaveil', 'stoneskin' })) then
            return 'buff';
        end
        if (command_has_any(command, { 'raise', 'reraise' })) then
            return 'raise';
        end
        if (command_has_any(command, { 'sneak', 'invisible', 'deodorize' })) then
            return 'stealth';
        end
        if (command_has_any(command, { 'erase', 'poisona', 'paralyna', 'silena', 'blindna', 'stona', 'viruna', 'cursna' })) then
            return 'status';
        end
        if (command_has_any(command, { 'fire', 'flare' })) then return 'fire'; end
        if (command_has_any(command, { 'blizzard', 'freeze', 'ice' })) then return 'ice'; end
        if (command_has_any(command, { 'aero', 'tornado', 'wind' })) then return 'wind'; end
        if (command_has_any(command, { 'stone', 'quake', 'earth' })) then return 'earth'; end
        if (command_has_any(command, { 'thunder', 'burst', 'lightning' })) then return 'lightning'; end
        if (command_has_any(command, { 'water', 'flood' })) then return 'water'; end
        if (command_has_any(command, { 'drain', 'aspir', 'bio', 'dark' })) then return 'dark'; end
        if (command_has_any(command, { 'paralyze', 'slow', 'blind', 'silence', 'sleep', 'poison', 'bind', 'gravity', 'dispel' })) then return 'debuff'; end
        if (command_has_any(command, { 'minuet', 'madrigal', 'march', 'ballad', 'requiem', 'lullaby', 'threnody', 'elegy', 'paeon', 'carol' })) then return 'song'; end
        if (command_has_any(command, { 'carbuncle', 'ifrit', 'shiva', 'garuda', 'titan', 'ramuh', 'leviathan', 'fenrir', 'diabolos', 'avatar' })) then return 'summon'; end
    end

    return family;
end

local function icon_def_for_token(token, family)
    local normalized = DEFERRED.normalize_icon_token(token);
    if (normalized == nil) then
        return nil, nil;
    end

    local base_token = normalized;
    local art_style = nil;
    local sigil_base = normalized:match('^sigil_(.+)$');
    if (sigil_base ~= nil) then
        base_token = sigil_base;
        art_style = 'sigil';
    end

    local known = ICON_DEFS[base_token];
    if (known ~= nil) then
        if (art_style == nil) then
            return known, normalized;
        end

        local icon_def = {};
        for key, value in pairs(known) do
            icon_def[key] = value;
        end
        icon_def.art_style = art_style;
        return icon_def, normalized;
    end

    local text = base_token:sub(1, 2):upper();
    if (art_style ~= nil and text == '') then
        text = '?';
    end

    return {
        family = family,
        mark = 'text',
        text = text,
        accent = COMMAND_THEME[family] or COMMAND_THEME.command,
        art_style = art_style,
    }, normalized;
end

local function slot_icon(slot, family)
    if (slot == nil or type(slot.command) ~= 'string' or slot.command == '') then
        return nil, nil;
    end

    local style = icon_style();
    if (style == 'none') then
        return nil, nil;
    end

    local explicit = DEFERRED.normalize_icon_token(slot.icon);
    if (explicit ~= nil) then
        return icon_def_for_token(explicit, family);
    end

    if (style == 'configured') then
        return nil, nil;
    end

    return icon_def_for_token(infer_icon_token(slot, family), family);
end

local function fit_text(text, max_width)
    if (type(text) ~= 'string' or text == '' or max_width <= 0) then
        return '';
    end

    local width = imgui.CalcTextSize(text);
    if (width <= max_width) then
        return text;
    end

    local trimmed = text;
    while (#trimmed > 1) do
        trimmed = trimmed:sub(1, #trimmed - 1);
        local candidate = trimmed .. '.';
        width = imgui.CalcTextSize(candidate);
        if (width <= max_width) then
            return candidate;
        end
    end

    return '';
end

local function draw_text_shadow(draw_list, x, y, color, text)
    if (text == nil or text == '') then
        return;
    end

    local theme = current_theme();
    local shadow = color_u32(theme.text_shadow or { 0.00, 0.00, 0.00, 0.90 });
    draw_list:AddText({ x + 1, y + 1 }, shadow, text);
    draw_list:AddText({ x - 1, y }, shadow, text);
    draw_list:AddText({ x + 1, y }, shadow, text);
    draw_list:AddText({ x, y - 1 }, shadow, text);
    draw_list:AddText({ x, y }, color_u32(color), text);
end

local function draw_crystal_mark(draw_list, x, y, size, color, alpha)
    local col = color_u32(color_with_alpha(color, alpha));
    local dim = color_u32(color_with_alpha(color, alpha * 0.55));

    draw_list:AddLine({ x, y - size }, { x + size, y }, col, 1.35);
    draw_list:AddLine({ x + size, y }, { x, y + size }, col, 1.35);
    draw_list:AddLine({ x, y + size }, { x - size, y }, dim, 1.35);
    draw_list:AddLine({ x - size, y }, { x, y - size }, dim, 1.35);
    draw_list:AddLine({ x - size * 0.55, y }, { x + size * 0.55, y }, dim, 1.00);
    draw_list:AddLine({ x, y - size * 0.55 }, { x, y + size * 0.55 }, dim, 1.00);
end

local function draw_centered_text(draw_list, cx, cy, color, text)
    if (text == nil or text == '') then
        return;
    end

    local tw, th = imgui.CalcTextSize(text);
    tw = tonumber(tw) or 0;
    th = tonumber(th) or 0;
    draw_text_shadow(draw_list, cx - (tw * 0.5), cy - (th * 0.5), color, text);
end

function ICON_ART_STYLE.draw_sigil_mark(draw_list, icon_def, x, y, size, fallback_color)
    if (icon_def == nil) then
        return false;
    end

    local color = icon_def.accent or fallback_color or COMMAND_THEME.command;
    local col = color_u32(color_with_alpha(color, 0.94));
    local dim = color_u32(color_with_alpha(color, 0.45));
    local mark = icon_def.mark or 'diamond';
    local thick = math.max(1.1, size * 0.13);
    local fine = math.max(1.0, size * 0.08);

    local function point(px, py)
        return { x + (px * size), y + (py * size) };
    end

    local function line(x1, y1, x2, y2, color_value, width)
        draw_list:AddLine(point(x1, y1), point(x2, y2), color_value or col, width or fine);
    end

    local function diamond(scale, color_value, width)
        line(0, -scale, scale, 0, color_value, width);
        line(scale, 0, 0, scale, color_value, width);
        line(0, scale, -scale, 0, color_value, width);
        line(-scale, 0, 0, -scale, color_value, width);
    end

    local function box(x1, y1, x2, y2, color_value, width)
        draw_list:AddRect(point(x1, y1), point(x2, y2), color_value or col, 1.0, ImDrawCornerFlags_All, width or fine);
    end

    if (mark == 'text') then
        draw_centered_text(draw_list, x, y, color, icon_def.text or '?');
        return true;
    end

    if (mark == 'plus') then
        diamond(0.86, dim, fine);
        line(0, -0.72, 0, 0.72, col, thick);
        line(-0.72, 0, 0.72, 0, col, thick);
        return true;
    end

    if (mark == 'spark' or mark == 'ray') then
        diamond(0.62, dim, fine);
        line(0, -1.0, 0, 1.0, col, thick);
        line(-1.0, 0, 1.0, 0, col, thick);
        line(-0.70, -0.70, 0.70, 0.70, dim, fine);
        line(0.70, -0.70, -0.70, 0.70, dim, fine);
        return true;
    end

    if (mark == 'burst') then
        diamond(0.84, col, fine);
        diamond(0.36, dim, fine);
        line(0, -1.0, 0, -0.52, col, thick);
        line(0, 0.52, 0, 1.0, col, thick);
        line(-1.0, 0, -0.52, 0, col, thick);
        line(0.52, 0, 1.0, 0, col, thick);
        return true;
    end

    if (mark == 'flame') then
        line(0, -1.0, 0.52, -0.10, col, thick);
        line(0.52, -0.10, 0.18, 0.84, col, thick);
        line(0.18, 0.84, -0.56, 0.34, dim, thick);
        line(-0.56, 0.34, -0.18, -0.18, dim, fine);
        line(-0.18, -0.18, 0, -1.0, col, fine);
        return true;
    end

    if (mark == 'snow') then
        line(0, -1.0, 0, 1.0, col, fine);
        line(-1.0, 0, 1.0, 0, col, fine);
        line(-0.72, -0.72, 0.72, 0.72, dim, fine);
        line(0.72, -0.72, -0.72, 0.72, dim, fine);
        diamond(0.24, col, fine);
        return true;
    end

    if (mark == 'wind') then
        line(-0.96, -0.46, 0.68, -0.46, col, fine);
        line(0.68, -0.46, 0.36, -0.16, dim, fine);
        line(-0.78, 0.00, 0.94, 0.00, col, fine);
        line(0.94, 0.00, 0.62, 0.28, dim, fine);
        line(-0.48, 0.46, 0.54, 0.46, col, fine);
        return true;
    end

    if (mark == 'stone') then
        line(0, -0.92, 0.78, -0.22, col, thick);
        line(0.78, -0.22, 0.42, 0.74, col, thick);
        line(0.42, 0.74, -0.58, 0.60, dim, thick);
        line(-0.58, 0.60, -0.78, -0.22, dim, thick);
        line(-0.78, -0.22, 0, -0.92, col, thick);
        return true;
    end

    if (mark == 'bolt') then
        line(0.26, -1.0, -0.28, -0.08, col, thick);
        line(-0.28, -0.08, 0.18, -0.08, col, thick);
        line(0.18, -0.08, -0.34, 1.0, col, thick);
        line(-0.02, 0.02, 0.54, 0.02, dim, fine);
        return true;
    end

    if (mark == 'wave') then
        line(-0.96, -0.30, -0.44, -0.52, col, fine);
        line(-0.44, -0.52, 0.10, -0.30, col, fine);
        line(0.10, -0.30, 0.64, -0.52, col, fine);
        line(-0.82, 0.18, -0.28, -0.04, dim, fine);
        line(-0.28, -0.04, 0.28, 0.18, dim, fine);
        line(0.28, 0.18, 0.82, -0.04, dim, fine);
        return true;
    end

    if (mark == 'moon') then
        line(0.38, -1.0, -0.32, -0.52, col, thick);
        line(-0.32, -0.52, -0.52, 0.16, col, thick);
        line(-0.52, 0.16, -0.06, 0.78, dim, thick);
        line(0.02, -0.46, 0.40, 0.46, col, fine);
        return true;
    end

    if (mark == 'snare') then
        diamond(0.72, dim, fine);
        line(-0.70, -0.70, 0.70, 0.70, col, thick);
        line(0.70, -0.70, -0.70, 0.70, col, thick);
        return true;
    end

    if (mark == 'shield') then
        line(0, -1.0, 0.76, -0.46, col, thick);
        line(0.76, -0.46, 0.50, 0.50, col, thick);
        line(0.50, 0.50, 0, 1.0, dim, thick);
        line(0, 1.0, -0.50, 0.50, dim, thick);
        line(-0.50, 0.50, -0.76, -0.46, dim, thick);
        line(-0.76, -0.46, 0, -1.0, col, thick);
        return true;
    end

    if (mark == 'blade') then
        line(-0.56, 0.72, 0.72, -0.72, col, thick);
        line(0.20, -0.16, 0.72, -0.72, dim, fine);
        line(-0.64, 0.18, -0.18, 0.64, col, fine);
        return true;
    end

    if (mark == 'ranged') then
        line(-0.80, -0.74, -0.80, 0.74, col, thick);
        line(-0.80, -0.74, -0.32, 0, dim, fine);
        line(-0.80, 0.74, -0.32, 0, dim, fine);
        line(-0.54, 0, 0.88, 0, col, thick);
        line(0.88, 0, 0.48, -0.30, col, fine);
        line(0.88, 0, 0.48, 0.30, col, fine);
        return true;
    end

    if (mark == 'bag' or mark == 'gift') then
        box(-0.70, -0.12, 0.70, 0.80, col, fine);
        line(-0.34, -0.12, -0.12, -0.62, dim, fine);
        line(-0.12, -0.62, 0.12, -0.62, dim, fine);
        line(0.12, -0.62, 0.34, -0.12, dim, fine);
        if (mark == 'gift') then
            line(0, -0.12, 0, 0.80, dim, fine);
            line(-0.70, 0.30, 0.70, 0.30, dim, fine);
        end
        return true;
    end

    if (mark == 'reticle') then
        diamond(0.88, dim, fine);
        line(0, -1.0, 0, -0.38, col, fine);
        line(0, 0.38, 0, 1.0, col, fine);
        line(-1.0, 0, -0.38, 0, col, fine);
        line(0.38, 0, 1.0, 0, col, fine);
        return true;
    end

    if (mark == 'arrow') then
        line(-0.82, 0, 0.68, 0, col, thick);
        line(0.68, 0, 0.22, -0.44, col, thick);
        line(0.68, 0, 0.22, 0.44, col, thick);
        return true;
    end

    if (mark == 'chat') then
        box(-0.78, -0.52, 0.78, 0.42, col, fine);
        line(-0.24, 0.42, -0.48, 0.76, dim, fine);
        line(-0.48, 0.76, 0.08, 0.42, dim, fine);
        line(-0.44, -0.16, 0.44, -0.16, dim, fine);
        line(-0.44, 0.10, 0.24, 0.10, dim, fine);
        return true;
    end

    if (mark == 'note') then
        line(0.24, -0.86, 0.24, 0.50, col, thick);
        line(0.24, -0.86, 0.72, -0.62, dim, fine);
        line(0.72, -0.62, 0.72, -0.18, dim, fine);
        line(-0.48, 0.46, 0.24, 0.28, col, thick);
        return true;
    end

    if (mark == 'avatar') then
        diamond(0.76, col, fine);
        diamond(0.42, dim, fine);
        line(-1.0, 0, -0.46, -0.30, dim, fine);
        line(0.46, 0.30, 1.0, 0, dim, fine);
        return true;
    end

    if (mark == 'paw') then
        diamond(0.34, col, thick);
        box(-0.74, -0.58, -0.46, -0.28, dim, fine);
        box(-0.20, -0.78, 0.08, -0.46, dim, fine);
        box(0.38, -0.58, 0.66, -0.28, dim, fine);
        return true;
    end

    if (mark == 'claw') then
        line(-0.56, -0.86, -0.22, 0.72, col, thick);
        line(0, -0.96, 0.08, 0.78, col, thick);
        line(0.56, -0.86, 0.34, 0.72, col, thick);
        return true;
    end

    if (mark == 'heart') then
        line(0, 0.84, -0.68, 0.08, col, thick);
        line(-0.68, 0.08, -0.32, -0.58, col, thick);
        line(-0.32, -0.58, 0, -0.22, dim, fine);
        line(0, -0.22, 0.32, -0.58, dim, fine);
        line(0.32, -0.58, 0.68, 0.08, col, thick);
        line(0.68, 0.08, 0, 0.84, col, thick);
        return true;
    end

    diamond(0.86, col, fine);
    diamond(0.42, dim, fine);
    return true;
end

local function draw_icon_mark(draw_list, icon_def, x, y, size, fallback_color)
    if (icon_def == nil) then
        return;
    end

    local color = icon_def.accent or fallback_color or COMMAND_THEME.command;
    local col = color_u32(color_with_alpha(color, 0.92));
    local dim = color_u32(color_with_alpha(color, 0.48));
    local mark = icon_def.mark or 'diamond';
    local thick = math.max(2, math.floor(size * 0.18));

    if (icon_def.art_style == 'sigil' and ICON_ART_STYLE.draw_sigil_mark(draw_list, icon_def, x, y, size, fallback_color)) then
        return;
    end

    if (mark == 'plus') then
        draw_list:AddRectFilled({ x - thick, y - size }, { x + thick, y + size }, col, 1.0);
        draw_list:AddRectFilled({ x - size, y - thick }, { x + size, y + thick }, col, 1.0);
        draw_list:AddRect({ x - size, y - size }, { x + size, y + size }, dim, 1.0, ImDrawCornerFlags_All, 1.0);
        return;
    end

    if (mark == 'spark') then
        draw_list:AddLine({ x, y - size }, { x, y + size }, col, 1.7);
        draw_list:AddLine({ x - size, y }, { x + size, y }, col, 1.7);
        draw_list:AddLine({ x - size * 0.66, y - size * 0.66 }, { x + size * 0.66, y + size * 0.66 }, dim, 1.2);
        draw_list:AddLine({ x + size * 0.66, y - size * 0.66 }, { x - size * 0.66, y + size * 0.66 }, dim, 1.2);
        draw_list:AddRectFilled({ x - thick * 0.5, y - thick * 0.5 }, { x + thick * 0.5, y + thick * 0.5 }, col, 1.0);
        return;
    end

    if (mark == 'burst') then
        draw_list:AddLine({ x, y - size }, { x, y - size * 0.16 }, col, 1.6);
        draw_list:AddLine({ x, y + size * 0.16 }, { x, y + size }, col, 1.6);
        draw_list:AddLine({ x - size, y }, { x - size * 0.16, y }, col, 1.6);
        draw_list:AddLine({ x + size * 0.16, y }, { x + size, y }, col, 1.6);
        draw_list:AddLine({ x - size * 0.72, y - size * 0.72 }, { x - size * 0.18, y - size * 0.18 }, dim, 1.4);
        draw_list:AddLine({ x + size * 0.18, y + size * 0.18 }, { x + size * 0.72, y + size * 0.72 }, dim, 1.4);
        draw_list:AddLine({ x + size * 0.72, y - size * 0.72 }, { x + size * 0.18, y - size * 0.18 }, dim, 1.4);
        draw_list:AddLine({ x - size * 0.18, y + size * 0.18 }, { x - size * 0.72, y + size * 0.72 }, dim, 1.4);
        draw_crystal_mark(draw_list, x, y, size * 0.28, color, 0.74);
        return;
    end

    if (mark == 'flame') then
        draw_list:AddLine({ x, y - size }, { x + size * 0.55, y - size * 0.16 }, col, 1.8);
        draw_list:AddLine({ x + size * 0.55, y - size * 0.16 }, { x + size * 0.30, y + size * 0.70 }, col, 1.8);
        draw_list:AddLine({ x + size * 0.30, y + size * 0.70 }, { x - size * 0.38, y + size * 0.72 }, dim, 1.8);
        draw_list:AddLine({ x - size * 0.38, y + size * 0.72 }, { x - size * 0.60, y - size * 0.04 }, dim, 1.8);
        draw_list:AddLine({ x - size * 0.60, y - size * 0.04 }, { x, y - size }, col, 1.8);
        draw_list:AddLine({ x - size * 0.10, y + size * 0.48 }, { x + size * 0.18, y - size * 0.18 }, col, 1.1);
        return;
    end

    if (mark == 'snow') then
        draw_list:AddLine({ x, y - size }, { x, y + size }, col, 1.4);
        draw_list:AddLine({ x - size, y }, { x + size, y }, col, 1.4);
        draw_list:AddLine({ x - size * 0.70, y - size * 0.70 }, { x + size * 0.70, y + size * 0.70 }, dim, 1.2);
        draw_list:AddLine({ x + size * 0.70, y - size * 0.70 }, { x - size * 0.70, y + size * 0.70 }, dim, 1.2);
        draw_list:AddRectFilled({ x - thick * 0.35, y - thick * 0.35 }, { x + thick * 0.35, y + thick * 0.35 }, col, 1.0);
        return;
    end

    if (mark == 'wind') then
        draw_list:AddLine({ x - size, y - size * 0.42 }, { x + size * 0.66, y - size * 0.42 }, col, 1.5);
        draw_list:AddLine({ x + size * 0.66, y - size * 0.42 }, { x + size * 0.36, y - size * 0.12 }, dim, 1.2);
        draw_list:AddLine({ x - size * 0.74, y }, { x + size, y }, col, 1.5);
        draw_list:AddLine({ x + size, y }, { x + size * 0.68, y + size * 0.28 }, dim, 1.2);
        draw_list:AddLine({ x - size * 0.46, y + size * 0.42 }, { x + size * 0.62, y + size * 0.42 }, col, 1.5);
        return;
    end

    if (mark == 'stone') then
        draw_list:AddLine({ x, y - size }, { x + size * 0.78, y - size * 0.18 }, col, 1.7);
        draw_list:AddLine({ x + size * 0.78, y - size * 0.18 }, { x + size * 0.42, y + size * 0.72 }, col, 1.7);
        draw_list:AddLine({ x + size * 0.42, y + size * 0.72 }, { x - size * 0.58, y + size * 0.62 }, dim, 1.7);
        draw_list:AddLine({ x - size * 0.58, y + size * 0.62 }, { x - size * 0.78, y - size * 0.22 }, dim, 1.7);
        draw_list:AddLine({ x - size * 0.78, y - size * 0.22 }, { x, y - size }, col, 1.7);
        draw_list:AddLine({ x - size * 0.44, y - size * 0.10 }, { x + size * 0.42, y - size * 0.18 }, dim, 1.0);
        return;
    end

    if (mark == 'bolt') then
        draw_list:AddLine({ x + size * 0.26, y - size }, { x - size * 0.26, y - size * 0.10 }, col, 2.0);
        draw_list:AddLine({ x - size * 0.26, y - size * 0.10 }, { x + size * 0.18, y - size * 0.10 }, col, 2.0);
        draw_list:AddLine({ x + size * 0.18, y - size * 0.10 }, { x - size * 0.30, y + size }, col, 2.0);
        draw_list:AddLine({ x - size * 0.05, y - size * 0.02 }, { x + size * 0.52, y - size * 0.02 }, dim, 1.0);
        return;
    end

    if (mark == 'wave') then
        draw_list:AddLine({ x - size, y - size * 0.30 }, { x - size * 0.44, y - size * 0.52 }, col, 1.5);
        draw_list:AddLine({ x - size * 0.44, y - size * 0.52 }, { x + size * 0.10, y - size * 0.30 }, col, 1.5);
        draw_list:AddLine({ x + size * 0.10, y - size * 0.30 }, { x + size * 0.64, y - size * 0.52 }, col, 1.5);
        draw_list:AddLine({ x - size * 0.82, y + size * 0.12 }, { x - size * 0.28, y - size * 0.10 }, dim, 1.5);
        draw_list:AddLine({ x - size * 0.28, y - size * 0.10 }, { x + size * 0.28, y + size * 0.12 }, dim, 1.5);
        draw_list:AddLine({ x + size * 0.28, y + size * 0.12 }, { x + size * 0.82, y - size * 0.10 }, dim, 1.5);
        draw_list:AddLine({ x - size * 0.64, y + size * 0.54 }, { x + size * 0.66, y + size * 0.54 }, col, 1.1);
        return;
    end

    if (mark == 'ray') then
        draw_list:AddLine({ x, y - size }, { x, y + size }, col, 1.6);
        draw_list:AddLine({ x - size, y }, { x + size, y }, col, 1.6);
        draw_list:AddLine({ x - size * 0.62, y - size * 0.62 }, { x + size * 0.62, y + size * 0.62 }, dim, 1.2);
        draw_list:AddLine({ x + size * 0.62, y - size * 0.62 }, { x - size * 0.62, y + size * 0.62 }, dim, 1.2);
        draw_crystal_mark(draw_list, x, y, size * 0.32, color, 0.82);
        return;
    end

    if (mark == 'moon') then
        draw_list:AddLine({ x + size * 0.38, y - size }, { x - size * 0.30, y - size * 0.56 }, col, 1.8);
        draw_list:AddLine({ x - size * 0.30, y - size * 0.56 }, { x - size * 0.52, y + size * 0.12 }, col, 1.8);
        draw_list:AddLine({ x - size * 0.52, y + size * 0.12 }, { x - size * 0.08, y + size * 0.78 }, dim, 1.8);
        draw_list:AddLine({ x - size * 0.08, y + size * 0.78 }, { x + size * 0.42, y + size * 0.94 }, dim, 1.8);
        draw_list:AddLine({ x + size * 0.04, y - size * 0.48 }, { x + size * 0.40, y + size * 0.48 }, col, 1.1);
        return;
    end

    if (mark == 'snare') then
        draw_list:AddLine({ x - size * 0.70, y - size * 0.70 }, { x + size * 0.70, y + size * 0.70 }, col, 1.7);
        draw_list:AddLine({ x + size * 0.70, y - size * 0.70 }, { x - size * 0.70, y + size * 0.70 }, col, 1.7);
        draw_list:AddLine({ x - size, y }, { x - size * 0.34, y }, dim, 1.2);
        draw_list:AddLine({ x + size * 0.34, y }, { x + size, y }, dim, 1.2);
        draw_list:AddLine({ x, y - size }, { x, y - size * 0.34 }, dim, 1.2);
        draw_list:AddLine({ x, y + size * 0.34 }, { x, y + size }, dim, 1.2);
        return;
    end

    if (mark == 'shield') then
        draw_list:AddLine({ x, y - size }, { x + size * 0.75, y - size * 0.48 }, col, 1.8);
        draw_list:AddLine({ x + size * 0.75, y - size * 0.48 }, { x + size * 0.56, y + size * 0.50 }, col, 1.8);
        draw_list:AddLine({ x + size * 0.56, y + size * 0.50 }, { x, y + size }, dim, 1.8);
        draw_list:AddLine({ x, y + size }, { x - size * 0.56, y + size * 0.50 }, dim, 1.8);
        draw_list:AddLine({ x - size * 0.56, y + size * 0.50 }, { x - size * 0.75, y - size * 0.48 }, dim, 1.8);
        draw_list:AddLine({ x - size * 0.75, y - size * 0.48 }, { x, y - size }, col, 1.8);
        draw_list:AddLine({ x, y - size * 0.52 }, { x, y + size * 0.55 }, dim, 1.0);
        return;
    end

    if (mark == 'blade') then
        draw_list:AddLine({ x - size * 0.52, y + size * 0.70 }, { x + size * 0.70, y - size * 0.70 }, col, 2.1);
        draw_list:AddLine({ x + size * 0.18, y - size * 0.18 }, { x + size * 0.70, y - size * 0.70 }, dim, 1.1);
        draw_list:AddLine({ x - size * 0.62, y + size * 0.20 }, { x - size * 0.18, y + size * 0.62 }, col, 1.7);
        draw_list:AddLine({ x - size * 0.40, y + size * 0.38 }, { x - size * 0.72, y + size * 0.74 }, dim, 1.6);
        return;
    end

    if (mark == 'ranged') then
        draw_list:AddLine({ x - size * 0.80, y - size * 0.72 }, { x - size * 0.80, y + size * 0.72 }, col, 1.8);
        draw_list:AddLine({ x - size * 0.80, y - size * 0.72 }, { x - size * 0.34, y }, dim, 1.3);
        draw_list:AddLine({ x - size * 0.80, y + size * 0.72 }, { x - size * 0.34, y }, dim, 1.3);
        draw_list:AddLine({ x - size * 0.54, y }, { x + size * 0.86, y }, col, 1.8);
        draw_list:AddLine({ x + size * 0.86, y }, { x + size * 0.50, y - size * 0.30 }, col, 1.5);
        draw_list:AddLine({ x + size * 0.86, y }, { x + size * 0.50, y + size * 0.30 }, col, 1.5);
        return;
    end

    if (mark == 'bag') then
        draw_list:AddRect({ x - size * 0.70, y - size * 0.18 }, { x + size * 0.70, y + size * 0.82 }, col, 2.0, ImDrawCornerFlags_All, 1.8);
        draw_list:AddLine({ x - size * 0.36, y - size * 0.18 }, { x - size * 0.16, y - size * 0.62 }, dim, 1.4);
        draw_list:AddLine({ x - size * 0.16, y - size * 0.62 }, { x + size * 0.16, y - size * 0.62 }, dim, 1.4);
        draw_list:AddLine({ x + size * 0.16, y - size * 0.62 }, { x + size * 0.36, y - size * 0.18 }, dim, 1.4);
        draw_list:AddLine({ x - size * 0.42, y + size * 0.22 }, { x + size * 0.42, y + size * 0.22 }, dim, 1.0);
        return;
    end

    if (mark == 'reticle') then
        draw_list:AddRect({ x - size * 0.72, y - size * 0.72 }, { x + size * 0.72, y + size * 0.72 }, dim, 1.0, ImDrawCornerFlags_All, 1.1);
        draw_list:AddLine({ x, y - size }, { x, y - size * 0.36 }, col, 1.5);
        draw_list:AddLine({ x, y + size * 0.36 }, { x, y + size }, col, 1.5);
        draw_list:AddLine({ x - size, y }, { x - size * 0.36, y }, col, 1.5);
        draw_list:AddLine({ x + size * 0.36, y }, { x + size, y }, col, 1.5);
        draw_list:AddRectFilled({ x - 1, y - 1 }, { x + 1, y + 1 }, col, 1.0);
        return;
    end

    if (mark == 'arrow') then
        draw_list:AddLine({ x - size * 0.82, y }, { x + size * 0.64, y }, col, 2.0);
        draw_list:AddLine({ x + size * 0.64, y }, { x + size * 0.20, y - size * 0.44 }, col, 2.0);
        draw_list:AddLine({ x + size * 0.64, y }, { x + size * 0.20, y + size * 0.44 }, col, 2.0);
        draw_list:AddLine({ x - size * 0.32, y - size * 0.34 }, { x - size * 0.74, y }, dim, 1.3);
        draw_list:AddLine({ x - size * 0.32, y + size * 0.34 }, { x - size * 0.74, y }, dim, 1.3);
        return;
    end

    if (mark == 'chat') then
        draw_list:AddRect({ x - size * 0.78, y - size * 0.55 }, { x + size * 0.78, y + size * 0.42 }, col, 2.0, ImDrawCornerFlags_All, 1.5);
        draw_list:AddLine({ x - size * 0.22, y + size * 0.42 }, { x - size * 0.48, y + size * 0.78 }, dim, 1.5);
        draw_list:AddLine({ x - size * 0.48, y + size * 0.78 }, { x + size * 0.08, y + size * 0.42 }, dim, 1.5);
        draw_list:AddLine({ x - size * 0.46, y - size * 0.18 }, { x + size * 0.46, y - size * 0.18 }, dim, 1.0);
        draw_list:AddLine({ x - size * 0.46, y + size * 0.08 }, { x + size * 0.26, y + size * 0.08 }, dim, 1.0);
        return;
    end

    if (mark == 'note') then
        draw_list:AddLine({ x + size * 0.24, y - size * 0.86 }, { x + size * 0.24, y + size * 0.48 }, col, 1.8);
        draw_list:AddLine({ x + size * 0.24, y - size * 0.86 }, { x + size * 0.72, y - size * 0.62 }, dim, 1.4);
        draw_list:AddLine({ x + size * 0.72, y - size * 0.62 }, { x + size * 0.72, y - size * 0.20 }, dim, 1.4);
        draw_list:AddLine({ x - size * 0.48, y + size * 0.46 }, { x + size * 0.24, y + size * 0.28 }, col, 1.8);
        draw_list:AddLine({ x - size * 0.48, y + size * 0.46 }, { x - size * 0.16, y + size * 0.78 }, col, 1.8);
        return;
    end

    if (mark == 'avatar') then
        draw_crystal_mark(draw_list, x, y, size * 0.58, color, 0.82);
        draw_list:AddLine({ x - size, y }, { x - size * 0.38, y - size * 0.34 }, dim, 1.2);
        draw_list:AddLine({ x - size * 0.38, y - size * 0.34 }, { x + size * 0.56, y - size * 0.12 }, dim, 1.2);
        draw_list:AddLine({ x + size * 0.56, y - size * 0.12 }, { x + size, y + size * 0.24 }, dim, 1.2);
        draw_list:AddLine({ x - size * 0.70, y + size * 0.54 }, { x + size * 0.54, y + size * 0.70 }, col, 1.1);
        return;
    end

    if (mark == 'paw') then
        draw_crystal_mark(draw_list, x, y + size * 0.22, size * 0.34, color, 0.82);
        draw_list:AddRectFilled({ x - size * 0.72, y - size * 0.58 }, { x - size * 0.44, y - size * 0.28 }, dim, 1.0);
        draw_list:AddRectFilled({ x - size * 0.14, y - size * 0.82 }, { x + size * 0.14, y - size * 0.50 }, col, 1.0);
        draw_list:AddRectFilled({ x + size * 0.44, y - size * 0.58 }, { x + size * 0.72, y - size * 0.28 }, dim, 1.0);
        return;
    end

    if (mark == 'claw') then
        draw_list:AddLine({ x - size * 0.56, y - size * 0.86 }, { x - size * 0.22, y + size * 0.72 }, col, 2.0);
        draw_list:AddLine({ x, y - size * 0.96 }, { x + size * 0.08, y + size * 0.78 }, col, 2.0);
        draw_list:AddLine({ x + size * 0.56, y - size * 0.86 }, { x + size * 0.34, y + size * 0.72 }, dim, 2.0);
        return;
    end

    if (mark == 'heart') then
        draw_list:AddLine({ x, y + size * 0.86 }, { x - size * 0.68, y + size * 0.08 }, col, 1.8);
        draw_list:AddLine({ x - size * 0.68, y + size * 0.08 }, { x - size * 0.32, y - size * 0.58 }, col, 1.8);
        draw_list:AddLine({ x - size * 0.32, y - size * 0.58 }, { x, y - size * 0.22 }, dim, 1.2);
        draw_list:AddLine({ x, y - size * 0.22 }, { x + size * 0.32, y - size * 0.58 }, dim, 1.2);
        draw_list:AddLine({ x + size * 0.32, y - size * 0.58 }, { x + size * 0.68, y + size * 0.08 }, col, 1.8);
        draw_list:AddLine({ x + size * 0.68, y + size * 0.08 }, { x, y + size * 0.86 }, col, 1.8);
        return;
    end

    if (mark == 'gift') then
        draw_list:AddRect({ x - size * 0.70, y - size * 0.12 }, { x + size * 0.70, y + size * 0.80 }, col, 2.0, ImDrawCornerFlags_All, 1.4);
        draw_list:AddLine({ x, y - size * 0.12 }, { x, y + size * 0.80 }, dim, 1.1);
        draw_list:AddLine({ x - size * 0.70, y + size * 0.30 }, { x + size * 0.70, y + size * 0.30 }, dim, 1.1);
        draw_list:AddLine({ x - size * 0.26, y - size * 0.12 }, { x - size * 0.46, y - size * 0.52 }, col, 1.2);
        draw_list:AddLine({ x + size * 0.26, y - size * 0.12 }, { x + size * 0.46, y - size * 0.52 }, col, 1.2);
        return;
    end

    if (mark == 'text') then
        draw_centered_text(draw_list, x, y, color, icon_def.text or '?');
        return;
    end

    draw_crystal_mark(draw_list, x, y, size, color, 0.88);
end

local function draw_hotkey_badge(draw_list, x, y, slot_size, hotkey, color, dimmed)
    if (hotkey == nil or hotkey == '') then
        return;
    end

    local label = fit_text(hotkey, slot_size - 8);
    if (label == '') then
        return;
    end

    local theme = current_theme();
    local tw, th = imgui.CalcTextSize(label);
    tw = tonumber(tw) or 0;
    th = tonumber(th) or 0;

    local pad_x = 3;
    local bx1 = x + 4;
    local by1 = y + 3;
    local bx2 = math.min(x + slot_size - 4, bx1 + tw + (pad_x * 2));
    local by2 = by1 + th + 3;
    local bg = theme.hotkey_bg or { 0.00, 0.00, 0.00, 1.00 };
    local text_color = dimmed and (theme.hotkey_dim_text or { 0.62, 0.62, 0.66, 0.88 }) or color_with_alpha(color, 1.00);

    draw_list:AddRectFilled({ bx1, by1 }, { bx2, by2 }, color_u32(color_with_alpha(bg, dimmed and 0.54 or 0.74)), 1.5);
    draw_list:AddRect({ bx1, by1 }, { bx2, by2 }, color_u32(color_with_alpha(color, dimmed and 0.24 or 0.55)), 1.5, ImDrawCornerFlags_All, 1.0);
    draw_text_shadow(draw_list, bx1 + pad_x, by1 + 1, text_color, label);
end

local function draw_label_overlay(draw_list, x, y, slot_size, label, color)
    local theme = current_theme();
    local fitted = fit_text(label, slot_size - 8);
    if (fitted == '') then
        return;
    end

    local tw, th = imgui.CalcTextSize(fitted);
    tw = tonumber(tw) or 0;
    th = tonumber(th) or 0;

    local margin = 5;
    local top_y = y + margin;
    local bottom_y = y + slot_size - th - margin;
    local position = label_vertical_position() / 100.0;
    local text_x = x + math.floor((slot_size - tw) * 0.5);
    local text_y = top_y + ((bottom_y - top_y) * position);

    draw_text_shadow(draw_list, text_x, math.floor(text_y + 0.5), theme.label_text or { 0.96, 0.93, 0.84, 1.00 }, fitted);
end

local function draw_empty_slot_overlay(draw_list, x, y, slot_size)
    local theme = current_theme();
    local inset = math.max(8, math.floor(slot_size * 0.18));
    local x1 = x + inset;
    local y1 = y + inset;
    local x2 = x + slot_size - inset;
    local y2 = y + slot_size - inset;
    local line = color_u32(theme.empty_line or { 0.36, 0.36, 0.40, 0.40 });
    local dim = color_u32(theme.empty_dim or { 0.22, 0.22, 0.25, 0.44 });

    draw_list:AddRect({ x1, y1 }, { x2, y2 }, dim, 2.0, ImDrawCornerFlags_All, 1.0);
    draw_list:AddLine({ x1 + 4, y1 + 4 }, { x2 - 4, y2 - 4 }, line, 1.0);
    draw_list:AddLine({ x2 - 4, y1 + 4 }, { x1 + 4, y2 - 4 }, line, 1.0);
    draw_crystal_mark(draw_list, x + slot_size * 0.50, y + slot_size * 0.48, slot_size * 0.10, theme.empty_crystal or { 0.50, 0.48, 0.42, 1.00 }, 0.28);
end

local function draw_recast_overlay(draw_list, x1, y1, x2, y2, recast_info)
    if (recast_info == nil or recast_info.fraction == nil or recast_info.fraction <= 0) then
        return;
    end

    local theme = current_theme();
    local width = x2 - x1;
    local height = y2 - y1;
    if (width <= 0 or height <= 0) then
        return;
    end

    local fraction = math.min(1.0, math.max(0.0, recast_info.fraction));
    local wipe_height = math.ceil(height * fraction);
    local wipe_y = math.min(y2, y1 + wipe_height);
    local overlay = color_u32(theme.recast_overlay or { 0.00, 0.00, 0.00, 0.68 });
    local line = color_u32(theme.recast_line or { 1.00, 0.86, 0.54, 0.70 });

    draw_list:AddRectFilled({ x1, y1 }, { x2, wipe_y }, overlay, 2.0);
    if (wipe_y > y1 + 1 and wipe_y < y2 - 1) then
        draw_list:AddLine({ x1 + 2, wipe_y }, { x2 - 2, wipe_y }, line, 1.0);
    end

    draw_centered_text(draw_list, x1 + (width * 0.5), y1 + (height * 0.48), theme.recast_text or { 1.00, 0.96, 0.78, 1.00 }, recast_info.label);
end

local function draw_availability_overlay(draw_list, x1, y1, x2, y2, visual_state, show_reason)
    if (visual_state == nil or visual_state.available ~= false) then
        return;
    end

    local theme = current_theme();
    draw_list:AddRectFilled({ x1, y1 }, { x2, y2 }, color_u32(theme.unavailable_overlay or { 0.00, 0.00, 0.00, 0.58 }), 2.0);
    draw_list:AddLine({ x1 + 3, y2 - 3 }, { x2 - 3, y1 + 3 }, color_u32(theme.unavailable_line or { 1.00, 0.28, 0.18, 0.66 }), 2.0);

    if (show_reason and visual_state.reason_label ~= nil) then
        draw_centered_text(draw_list, x1 + ((x2 - x1) * 0.5), y1 + ((y2 - y1) * 0.48), theme.unavailable_text or { 1.00, 0.42, 0.32, 1.00 }, visual_state.reason_label);
    end
end

local function draw_weaponskill_pulse_overlay(draw_list, x, y, slot_size, pulse_info)
    if (pulse_info == nil or pulse_info.intensity == nil) then
        return;
    end

    local power = math.min(1.0, math.max(0.0, tonumber(pulse_info.intensity) or 0.0));
    if (power <= 0) then
        return;
    end
    local opacity = math.min(1.0, math.max(0.0, tonumber(pulse_info.opacity) or 1.0));
    if (opacity <= 0) then
        return;
    end

    local now = os.clock();
    local speed = math.max(0.25, math.min(2.0, (tonumber(pulse_info.frequency) or 100) / 100.0));
    local pulse = 0.5 + (0.5 * math.sin((now * 2.1 * speed) + (x * 0.017) + (y * 0.011)));
    local ready = pulse_info.ready == true;
    local warm_color = pulse_info.warm_color or { 1.00, 0.36, 0.06 };
    local border_color = pulse_info.border_color or { 1.00, 0.56, 0.10 };
    local inner_color = pulse_info.inner_color or { 1.00, 0.78, 0.28 };
    local call_color = pulse_info.call_color or { 1.00, 0.24, 0.02 };
    local core_color = pulse_info.core_color or { 1.00, 0.40, 0.08 };
    local rr = 4.0;
    local x1 = x + 1;
    local y1 = y + 1;
    local x2 = x + slot_size - 1;
    local y2 = y + slot_size - 1;

    local warm_alpha = ready and (0.05 + (power * 0.13) + (pulse * power * 0.07)) or (0.02 + (power * 0.08) + (pulse * power * 0.04));
    local border_alpha = ready and (0.22 + (power * 0.34) + (pulse * 0.22)) or (0.08 + (power * 0.28) + (pulse * power * 0.12));
    local inner_alpha = ready and (0.10 + (power * 0.22) + (pulse * 0.16)) or (0.03 + (power * 0.12) + (pulse * power * 0.06));
    local expand = math.floor(1 + (pulse * power * 4.0));
    local inset = math.max(3, math.floor(slot_size * 0.08));
    local core_inset = math.max(8, math.floor(slot_size * 0.18));

    draw_list:AddRectFilled({ x1, y1 }, { x2, y2 }, color_u32({ warm_color[1], warm_color[2], warm_color[3], math.min(0.22, warm_alpha) * opacity }), rr);
    draw_list:AddRect({ x1 + expand, y1 + expand }, { x2 - expand, y2 - expand }, color_u32({ border_color[1], border_color[2], border_color[3], math.min(0.78, border_alpha) * opacity }), rr, ImDrawCornerFlags_All, 1.2 + (power * 2.0));
    draw_list:AddRect({ x1 + inset, y1 + inset }, { x2 - inset, y2 - inset }, color_u32({ inner_color[1], inner_color[2], inner_color[3], math.min(0.48, inner_alpha) * opacity }), rr - 1, ImDrawCornerFlags_All, 1.0 + (power * 1.2));
    draw_list:AddRectFilled({ x + core_inset, y + core_inset }, { x + slot_size - core_inset, y + slot_size - core_inset }, color_u32({ core_color[1], core_color[2], core_color[3], math.min(0.16, inner_alpha * 0.56) * opacity }), 2.0);

    if (ready) then
        local call_alpha = math.min(0.76, 0.18 + (power * 0.28) + (pulse * 0.24));
        draw_list:AddRect({ x1, y1 }, { x2, y2 }, color_u32({ call_color[1], call_color[2], call_color[3], call_alpha * opacity }), rr + 1.0, ImDrawCornerFlags_All, 2.0 + (power * 1.5));
        draw_list:AddLine({ x1 + 4, y1 + 3 }, { x2 - 4, y1 + 3 }, color_u32({ inner_color[1], inner_color[2], inner_color[3], call_alpha * 0.72 * opacity }), 1.0 + (power * 1.0));
        draw_list:AddLine({ x1 + 4, y2 - 3 }, { x2 - 4, y2 - 3 }, color_u32({ warm_color[1], warm_color[2], warm_color[3], call_alpha * 0.80 * opacity }), 1.2 + (power * 1.3));
        draw_list:AddLine({ x1 + 3, y1 + 5 }, { x1 + 3, y2 - 5 }, color_u32({ border_color[1], border_color[2], border_color[3], call_alpha * 0.54 * opacity }), 1.0 + (power * 0.8));
        draw_list:AddLine({ x2 - 3, y1 + 5 }, { x2 - 3, y2 - 5 }, color_u32({ border_color[1], border_color[2], border_color[3], call_alpha * 0.54 * opacity }), 1.0 + (power * 0.8));
    end
end

local function draw_count_badge(draw_list, x, y, slot_size, label)
    if (label == nil or label == '') then
        return;
    end

    local theme = current_theme();
    local tw, th = imgui.CalcTextSize(label);
    tw = tonumber(tw) or 0;
    th = tonumber(th) or 0;

    local pad_x = 3;
    local by2 = y + slot_size - 18;
    local by1 = by2 - th - 3;
    local bx2 = x + slot_size - 5;
    local bx1 = math.max(x + 5, bx2 - tw - (pad_x * 2));

    draw_list:AddRectFilled({ bx1, by1 }, { bx2, by2 }, color_u32(theme.count_bg or { 0.00, 0.00, 0.00, 0.78 }), 1.5);
    draw_list:AddRect({ bx1, by1 }, { bx2, by2 }, color_u32(color_with_alpha(theme.icon_border or { 1.00, 0.86, 0.54, 1.00 }, 0.34)), 1.5, ImDrawCornerFlags_All, 1.0);
    draw_text_shadow(draw_list, bx1 + pad_x, by1 + 1, theme.count_text or { 1.00, 0.97, 0.84, 1.00 }, label);
end

local function draw_unsupported_overlay(draw_list, x, y, slot_size)
    local theme = current_theme();
    local warn = theme.unsupported or { 1.00, 0.24, 0.18, 1.00 };
    local col = color_u32(color_with_alpha(warn, 0.88));
    local dim = color_u32(color_with_alpha(warn, 0.34));
    local cx = x + slot_size - 9;
    local cy = y + 9;

    draw_list:AddLine({ x + slot_size - 17, y + 4 }, { x + slot_size - 4, y + 4 }, col, 1.5);
    draw_list:AddLine({ x + slot_size - 4, y + 4 }, { x + slot_size - 4, y + 17 }, col, 1.5);
    draw_list:AddRectFilled({ cx - 1, cy - 5 }, { cx + 1, cy + 3 }, col, 0.5);
    draw_list:AddRectFilled({ cx - 1, cy + 5 }, { cx + 1, cy + 7 }, dim, 0.5);
end

local function edit_handle_size(slot_size)
    return math.max(12, math.min(18, math.floor(slot_size * 0.24)));
end

local function point_in_rect(px, py, x1, y1, x2, y2)
    return px >= x1 and px <= x2 and py >= y1 and py <= y2;
end

local function edit_handle_hovered(x, y, slot_size)
    local mx, my = imgui.GetMousePos();
    local size = edit_handle_size(slot_size);
    return point_in_rect(mx, my, x, y, x + size, y + size);
end

local function draw_edit_handle(draw_list, x, y, slot_size, hovered)
    local size = edit_handle_size(slot_size);
    local color = hovered and UI_COLORS.edit_handle_hover or UI_COLORS.edit_handle;
    local bg = color_u32(color_with_alpha({ 0.00, 0.00, 0.00, 1.00 }, hovered and 0.82 or 0.68));
    local fg = color_u32(color);
    local dim = color_u32(color_with_alpha(color, hovered and 0.48 or 0.30));
    local x2 = x + size;
    local y2 = y + size;

    draw_list:AddTriangleFilled({ x, y }, { x2, y }, { x, y2 }, bg);
    draw_list:AddTriangle({ x, y }, { x2, y }, { x, y2 }, fg, 1.2);
    draw_list:AddLine({ x + 4, y + size - 5 }, { x + size - 5, y + 4 }, fg, 1.3);
    draw_list:AddLine({ x + 5, y + size - 3 }, { x + size - 3, y + 5 }, dim, 1.0);
end

local function draw_icon_preview_tile(draw_list, x, y, size, slot)
    local theme = current_theme();
    local family = command_family(slot);
    local icon_def = slot_icon(slot, family);
    local icon_family = (icon_def and icon_def.family) or family;
    local icon_color = (icon_def and icon_def.accent) or COMMAND_THEME[icon_family] or COMMAND_THEME.command;
    local inset = math.max(1, math.floor(size * 0.06));
    local ix1 = x + inset;
    local iy1 = y + inset;
    local ix2 = x + size - inset;
    local iy2 = y + size - inset;
    local asset_handle = ICON_ART_STYLE.icon_handle(icon_def);

    draw_list:AddRectFilled({ ix1, iy1 }, { ix2, iy2 }, color_u32({ icon_color[1] * 0.20, icon_color[2] * 0.20, icon_color[3] * 0.20, 0.96 }), 2.5);
    if (asset_handle ~= nil) then
        draw_list:AddImage(asset_handle, { ix1, iy1 }, { ix2, iy2 }, { 0, 0 }, { 1, 1 }, color_u32({ 1.00, 1.00, 1.00, 1.00 }));
    else
        draw_list:AddRectFilled({ ix1 + 1, iy1 + 1 }, { ix2 - 1, iy1 + ((iy2 - iy1) * 0.45) }, color_u32(color_with_alpha(theme.icon_highlight or { 1.00, 1.00, 1.00, 1.00 }, 0.05)), 2.0);
        draw_icon_mark(draw_list, icon_def, x + size * 0.50, y + size * 0.48, size * 0.22, icon_color);
    end
    draw_list:AddRect({ x, y }, { x + size, y + size }, color_u32(color_with_alpha(theme.hover_border or { 1.00, 0.96, 0.72, 0.52 }, 0.45)), 4.0, ImDrawCornerFlags_All, 1.0);
end

local function editor_icon_preview_slot(editor, icon)
    local _, command = MACRO.editor_commands();
    local slot = {
        command = command,
        icon = icon,
    };

    if (slot.command == '') then
        slot.command = '/echo AshitaBars icon preview';
    end

    return slot;
end

local function render_icon_picker_tile(editor, token, selected, tile_size)
    local theme = current_theme();
    local x, y = imgui.GetCursorScreenPos();
    local id_token = (token == '') and 'auto' or token;
    local clicked = imgui.InvisibleButton(('##ashitabars_icon_picker_%s'):fmt(id_token), { tile_size, tile_size });
    local hovered = imgui.IsItemHovered();
    local draw_list = imgui.GetWindowDrawList();
    local border_color = selected and (theme.active_border or { 1.00, 0.84, 0.34, 0.95 }) or (theme.window_border or { 0.58, 0.44, 0.20, 0.62 });
    local bg_alpha = hovered and 0.34 or 0.18;

    if (hovered) then
        border_color = theme.hover_border or { 1.00, 0.96, 0.72, 0.80 };
    end

    local padding = math.max(4, math.floor(tile_size * 0.08));
    draw_list:AddRectFilled({ x, y }, { x + tile_size, y + tile_size }, color_u32(color_with_alpha(theme.button_bg or { 0.04, 0.04, 0.05, 1.00 }, bg_alpha)), 5.0);
    draw_icon_preview_tile(draw_list, x + padding, y + padding, tile_size - (padding * 2), editor_icon_preview_slot(editor, token));
    draw_list:AddRect({ x, y }, { x + tile_size, y + tile_size }, color_u32(border_color), 5.0, ImDrawCornerFlags_All, selected and 2.4 or 1.2);

    if (hovered) then
        imgui.BeginTooltip();
        imgui.Text(icon_selector_label(token));
        imgui.EndTooltip();
    end

    return clicked;
end

function MACRO.icon_picker_category_label(value)
    if (value == 'all' or value == nil or value == '') then
        return 'All Categories';
    end

    for _, category in ipairs(ICON_SELECTOR_CATEGORIES) do
        if (category.label == value) then
            return category.label;
        end
    end

    return 'All Categories';
end

function MACRO.icon_picker_family_label(value)
    if (value == 'all' or value == nil or value == '') then
        return 'All Types';
    end

    for _, option in ipairs(MACRO.ICON_PICKER_FAMILY_FILTERS) do
        if (option.key == value) then
            return option.label;
        end
    end

    return 'All Types';
end

function MACRO.icon_picker_token_family(token, category)
    local known = ICON_DEFS[token];
    return (known ~= nil and known.family) or (category ~= nil and category.family) or 'command';
end

function MACRO.icon_picker_token_selected(normalized_current, token)
    if (normalized_current == token) then
        return true;
    end

    local current_def = normalized_current ~= nil and ICON_DEFS[normalized_current] or nil;
    local token_def = ICON_DEFS[token];
    return current_def ~= nil and token_def ~= nil and current_def.asset ~= nil and current_def.asset == token_def.asset;
end

function MACRO.icon_picker_token_matches(editor, token, category)
    if (type(editor) ~= 'table' or type(token) ~= 'string' or token == '') then
        return false;
    end

    local category_filter = editor.icon_picker_category_filter or 'all';
    if (category_filter ~= 'all' and (category == nil or category.label ~= category_filter)) then
        return false;
    end

    local family = MACRO.icon_picker_token_family(token, category);
    local family_filter = editor.icon_picker_family_filter or 'all';
    if (family_filter ~= 'all' and family ~= family_filter) then
        return false;
    end

    local search = trim_one_line(editor.icon_picker_search_buffer ~= nil and editor.icon_picker_search_buffer[1] or '', 64):lower();
    if (search == '') then
        return true;
    end

    local search_as_token = search:gsub('%s+', '_');
    local label = icon_selector_label(token):lower();
    local token_text = token:lower();
    local readable_token = token_text:gsub('_', ' ');
    local category_label = category ~= nil and category.label:lower() or '';
    local family_label = MACRO.icon_picker_family_label(family):lower();

    return token_text:find(search, 1, true) ~= nil
        or token_text:find(search_as_token, 1, true) ~= nil
        or readable_token:find(search, 1, true) ~= nil
        or label:find(search, 1, true) ~= nil
        or label:gsub('_', ' '):find(search, 1, true) ~= nil
        or category_label:find(search, 1, true) ~= nil
        or family_label:find(search, 1, true) ~= nil;
end

function MACRO.render_icon_picker_category_filter(editor)
    local current = editor.icon_picker_category_filter or 'all';
    imgui.PushItemWidth(210);
    if (imgui.BeginCombo('Category##ashitabars_icon_picker_category_filter', MACRO.icon_picker_category_label(current), ImGuiComboFlags_None)) then
        if (imgui.Selectable('All Categories', current == 'all')) then
            editor.icon_picker_category_filter = 'all';
        end
        for _, category in ipairs(ICON_SELECTOR_CATEGORIES) do
            if (imgui.Selectable(category.label, current == category.label)) then
                editor.icon_picker_category_filter = category.label;
            end
        end
        imgui.EndCombo();
    end
    imgui.PopItemWidth();
end

function MACRO.render_icon_picker_family_filter(editor)
    local current = editor.icon_picker_family_filter or 'all';
    imgui.PushItemWidth(190);
    if (imgui.BeginCombo('Type##ashitabars_icon_picker_family_filter', MACRO.icon_picker_family_label(current), ImGuiComboFlags_None)) then
        for _, option in ipairs(MACRO.ICON_PICKER_FAMILY_FILTERS) do
            if (imgui.Selectable(option.label, current == option.key)) then
                editor.icon_picker_family_filter = option.key;
            end
        end
        imgui.EndCombo();
    end
    imgui.PopItemWidth();
end

function MACRO.render_icon_selector(editor, width)
    local current_icon = trim_one_line(editor.icon_buffer[1], LIMITS.macro_icon_max);
    local normalized_current = DEFERRED.normalize_icon_token(current_icon);
    local changed = false;
    local picker_width = width or 430;
    local tile_size = 80;
    local gap = 5;
    local columns = math.max(1, math.floor((picker_width + gap) / (tile_size + gap)));
    local picker_height = 420;
    local child_open = false;
    local child_visible = true;
    local index = 0;
    local rendered_count = 0;

    if (type(imgui.BeginChild) == 'function' and type(imgui.EndChild) == 'function') then
        local ok, result = pcall(imgui.BeginChild, '##ashitabars_icon_picker_grid', { picker_width, picker_height }, true);
        child_open = ok;
        child_visible = (not ok) or result ~= false;
    end

    local function render_option(token, selected)
        index = index + 1;
        if (index > 1 and ((index - 1) % columns) ~= 0) then
            imgui.SameLine(0, gap);
        end

        if (render_icon_picker_tile(editor, token, selected, tile_size)) then
            buffer_set(editor.icon_buffer, token);
            editor.message = nil;
            changed = true;
        end
    end

    if (child_visible) then
        render_option('', current_icon == '');
        for _, category in ipairs(ICON_SELECTOR_CATEGORIES) do
            local tokens = {};
            for _, token in ipairs(category.tokens) do
                if (MACRO.icon_picker_token_matches(editor, token, category)) then
                    table.insert(tokens, token);
                end
            end

            if (#tokens > 0) then
                imgui.TextColored(UI_COLORS.config_header, category.label);
                index = 0;
                for _, token in ipairs(tokens) do
                    render_option(token, MACRO.icon_picker_token_selected(normalized_current, token));
                    rendered_count = rendered_count + 1;
                end
            end
        end

        if (rendered_count == 0) then
            imgui.TextColored(UI_COLORS.error, 'No icons match the current filters.');
        end
    end

    if (child_open) then
        imgui.EndChild();
    end

    return changed;
end

function MACRO.render_icon_picker_preview_button(editor, size)
    size = size or 72;
    local current_icon = trim_one_line(editor.icon_buffer[1], LIMITS.macro_icon_max);
    local x, y = imgui.GetCursorScreenPos();
    local clicked = imgui.InvisibleButton('##ashitabars_icon_picker_preview_button', { size, size });
    local hovered = imgui.IsItemHovered();
    local draw_list = imgui.GetWindowDrawList();
    local theme = current_theme();

    draw_icon_preview_tile(draw_list, x, y, size, editor_icon_preview_slot(editor, current_icon));
    if (editor.icon_picker_visible ~= nil and editor.icon_picker_visible[1] == true) then
        draw_list:AddRect({ x - 2, y - 2 }, { x + size + 2, y + size + 2 }, color_u32(theme.active_border or { 1.00, 0.84, 0.34, 0.95 }), 5.0, ImDrawCornerFlags_All, 2.0);
    end

    if (clicked) then
        editor.icon_picker_visible[1] = not editor.icon_picker_visible[1];
    end

    if (hovered) then
        imgui.BeginTooltip();
        imgui.Text('Click to choose icon');
        imgui.Text(icon_selector_label(current_icon));
        imgui.EndTooltip();
    end
end

function MACRO.render_icon_picker_window(editor)
    if (type(editor) ~= 'table' or editor.visible[1] ~= true or editor.icon_picker_visible == nil or editor.icon_picker_visible[1] ~= true) then
        return;
    end
    if (MACRO.normalize_mode(editor.macro_mode) == 'item') then
        editor.icon_picker_visible[1] = false;
        return;
    end

    local window_x = tonumber(editor.icon_picker_anchor_x) or 900;
    local window_y = tonumber(editor.icon_picker_anchor_y) or 280;
    local picker_width = 430;
    imgui.SetNextWindowPos({ window_x, window_y }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ picker_width + 28, 0 }, ImGuiCond_FirstUseEver);

    if (imgui.Begin('AshitaBars Icon Picker###AshitaBarsIconPicker', editor.icon_picker_visible, ImGuiWindowFlags_AlwaysAutoResize)) then
        imgui.PushItemWidth(picker_width);
        imgui.InputText('Search##ashitabars_icon_picker_search', editor.icon_picker_search_buffer, 64);
        imgui.PopItemWidth();

        MACRO.render_icon_picker_category_filter(editor);
        imgui.SameLine(0, 8);
        MACRO.render_icon_picker_family_filter(editor);

        local filters_active = trim_one_line(editor.icon_picker_search_buffer[1], 64) ~= ''
            or (editor.icon_picker_category_filter ~= nil and editor.icon_picker_category_filter ~= 'all')
            or (editor.icon_picker_family_filter ~= nil and editor.icon_picker_family_filter ~= 'all');
        if (filters_active) then
            if (imgui.Button('Clear Filters##ashitabars_icon_picker_clear_filters')) then
                buffer_set(editor.icon_picker_search_buffer, '');
                editor.icon_picker_category_filter = 'all';
                editor.icon_picker_family_filter = 'all';
            end
        end

        MACRO.render_icon_selector(editor, picker_width);
    end
    imgui.End();
end

function COMMAND_MODE.item_icon_handle_for_slot(slot)
    if (slot == nil or type(slot.command) ~= 'string' or slot.command == '') then
        return nil;
    end

    local prefix = command_prefix_and_name(slot.command);
    if (prefix ~= '/item') then
        return nil;
    end

    local source = item_source_for_command(slot.command);
    if (source == nil) then
        return nil;
    end

    local resource = COMMAND_MODE.item_resource(source.id, source.name);
    return COMMAND_MODE.item_icon_handle(source.id, resource);
end

function COMMAND_MODE.action_name_label_enabled(slot)
    if (slot == nil or type(slot.command) ~= 'string' or slot.command == '') then
        return false;
    end

    local mode = COMMAND_MODE.mode_from_command(slot.command);
    return COMMAND_MODE.is_structured_mode(mode) and slot.use_action_name_label ~= false;
end

function COMMAND_MODE.item_action_name_for_slot(slot)
    local source = item_source_for_command(slot.command);
    if (source == nil) then
        return nil;
    end

    local resource = COMMAND_MODE.item_resource(source.id, source.name);
    local name = COMMAND_MODE.resource_name(resource);
    if (name == '') then
        name = COMMAND_MODE.clean_name(source.name);
    end

    return name ~= '' and trim_one_line(name, LIMITS.macro_label_max) or nil;
end

function COMMAND_MODE.action_name_for_slot(slot)
    if (not COMMAND_MODE.action_name_label_enabled(slot)) then
        return nil;
    end

    local mode = COMMAND_MODE.mode_from_command(slot.command);
    if (mode == 'item') then
        return COMMAND_MODE.item_action_name_for_slot(slot);
    end
    if (mode == 'server') then
        local server_action = COMMAND_MODE.server_action_for_command(slot.command);
        return server_action ~= nil and trim_one_line(server_action.name, LIMITS.macro_label_max) or nil;
    end
    if (mode == 'trusts') then
        local trusts_action = COMMAND_MODE.trusts_action_for_command(slot.command);
        return trusts_action ~= nil and trim_one_line(trusts_action.name, LIMITS.macro_label_max) or nil;
    end
    if (mode == 'configtoggle') then
        local id = COMMAND_MODE.normalize_config_id(slot.config_key);
        if (id == nil) then
            local parsed = COMMAND_MODE.parse_config_command(slot.command);
            id = parsed ~= nil and parsed.id or nil;
        end
        return id ~= nil and trim_one_line(('Config %d'):fmt(id), LIMITS.macro_label_max) or nil;
    end

    local prefix, name = COMMAND_MODE.parse_command(slot.command);
    if (mode == 'target') then
        return trim_one_line(COMMAND_MODE.target_action_label(prefix), LIMITS.macro_label_max);
    end
    if (mode == 'ranged') then
        return 'Ranged Attack';
    end

    name = COMMAND_MODE.clean_name(name);
    return name ~= '' and trim_one_line(name, LIMITS.macro_label_max) or nil;
end

function COMMAND_MODE.slot_label(slot)
    if (COMMAND_MODE.action_name_label_enabled(slot)) then
        return COMMAND_MODE.action_name_for_slot(slot) or slot.label;
    end

    return slot ~= nil and slot.label or nil;
end

function MACRO.render_multiline_input(label, buffer, max_length, size)
    if (type(imgui.InputTextMultiline) == 'function') then
        local ok, changed = pcall(imgui.InputTextMultiline, label, buffer, max_length, size);
        if (ok) then
            return changed;
        end
    end

    local flags = rawget(_G, 'ImGuiInputTextFlags_Multiline') or ImGuiInputTextFlags_None;
    local ok, changed = pcall(imgui.InputText, label, buffer, max_length, flags);
    if (ok) then
        return changed;
    end

    return imgui.InputText(label, buffer, max_length);
end

local function render_slot_button(row, index, slot_size, active, transition_alpha, capture_anchor, show_frame)
    local slot = get_slot(row.id, index);
    local commands = MACRO.slot_commands(slot);
    local has_command = #commands > 0;
    local command_supported = has_command and MACRO.commands_validation_error(commands) == nil;
    local clicked = imgui.InvisibleButton(('##ashitabars_%s_%d'):fmt(row.id, index), { slot_size, slot_size });
    local hovered = imgui.IsItemHovered();
    local pressed = imgui.IsItemActive();
    local x, y = imgui.GetItemRectMin();
    local draw_list = imgui.GetWindowDrawList();
    local edit_hovered = show_frame and hovered and edit_handle_hovered(x, y, slot_size);
    local edit_clicked = clicked and edit_hovered;
    if (capture_anchor) then
        local window_x, window_y = imgui.GetWindowPos();
        local extra_anchor_key = capture_anchor == 'click' and 'extra1' or capture_anchor;
        if (BAR.is_extra_bar(extra_anchor_key)) then
            local runtime = BAR.extra_runtime(extra_anchor_key);
            if (show_frame) then
                runtime.frame_offset_x = x - window_x;
                runtime.frame_offset_y = y - window_y;
            else
                runtime.hidden_offset_x = x - window_x;
                runtime.hidden_offset_y = y - window_y;
            end
            runtime.measured_anchor_x = x;
            runtime.measured_anchor_y = y;
        else
            if (show_frame) then
                state.bar_frame_offset_x = x - window_x;
                state.bar_frame_offset_y = y - window_y;
            else
                state.bar_hidden_offset_x = x - window_x;
                state.bar_hidden_offset_y = y - window_y;
            end
            state.bar_measured_anchor_x = x;
            state.bar_measured_anchor_y = y;
        end
    end

    local theme = current_theme();
    local row_color = ROW_THEME[row.id] or ROW_THEME.base;
    local family = command_family(slot);
    local icon_def = slot_icon(slot, family);
    local icon_family = (icon_def and icon_def.family) or family;
    local icon_color = (icon_def and icon_def.accent) or COMMAND_THEME[icon_family] or COMMAND_THEME.command;
    local recast_info = slot_recast(slot);
    local visual_state = slot_visual_state(slot);
    local macro_run_info = has_command and command_supported and MACRO.run_overlay_info({
        profile_key = editable_profile_key(refresh_profile_context(BAR.key_for_group(row.id))),
        group = row.id,
        index = index,
    }) or nil;
    local weaponskill_pulse_info = has_command and command_supported and slot_weaponskill_pulse_info(slot) or nil;
    local server_buff_pulse_info = has_command and command_supported and slot_server_buff_pulse_info(slot) or nil;
    local available = visual_state == nil or visual_state.available ~= false;
    local draw_icon_color = available and icon_color or { icon_color[1] * 0.52, icon_color[2] * 0.52, icon_color[3] * 0.52, icon_color[4] or 1.00 };
    local nudge = pressed and 1 or 0;
    local rx = x + nudge;
    local ry = y + nudge;
    local rr = 4.0;
    local glow_scale = slot_glow_scale();
    local glow_alpha_scale = slot_glow_alpha_scale();
    local inset = math.max(1, math.floor(slot_size * 0.04));
    local ix1 = rx + inset;
    local iy1 = ry + inset;
    local ix2 = rx + slot_size - inset;
    local iy2 = ry + slot_size - inset;

    if ((active or hovered) and glow_scale > 0 and glow_alpha_scale > 0) then
        local glow_alpha = (active and 0.82 or 0.42) * glow_alpha_scale;
        local glow_extent = 2.0 * glow_scale;
        local glow_thickness = (active and 2.0 or 1.4) * glow_scale;
        draw_list:AddRect({ rx - glow_extent, ry - glow_extent }, { rx + slot_size + glow_extent, ry + slot_size + glow_extent }, color_u32(color_with_alpha(row_color, glow_alpha)), rr + (glow_extent * 0.5), ImDrawCornerFlags_All, glow_thickness);
    end

    local flash = tonumber(transition_alpha) or 0;
    if (flash > 0 and glow_scale > 0 and glow_alpha_scale > 0) then
        local flash_alpha = flash * glow_alpha_scale;
        local flash_extent = 3.0 * glow_scale;
        local inner_inset = math.max(1.0, 4.0 * glow_scale);
        draw_list:AddRectFilled({ rx + 2, ry + 2 }, { rx + slot_size - 2, ry + slot_size - 2 }, color_u32(color_with_alpha(row_color, flash_alpha * 0.11)), rr - 1);
        draw_list:AddRect({ rx - flash_extent, ry - flash_extent }, { rx + slot_size + flash_extent, ry + slot_size + flash_extent }, color_u32(color_with_alpha(row_color, flash_alpha * 0.76)), rr + flash_extent - 1, ImDrawCornerFlags_All, 2.2 * glow_scale);
        draw_list:AddRect({ rx + inner_inset, ry + inner_inset }, { rx + slot_size - inner_inset, ry + slot_size - inner_inset }, color_u32(color_with_alpha(row_color, flash_alpha * 0.32)), 2.0, ImDrawCornerFlags_All, 1.0 * glow_scale);
    end

    if (has_command) then
        local icon_alpha = command_supported and (available and 0.96 or 0.56) or 0.64;
        draw_list:AddRectFilled({ ix1, iy1 }, { ix2, iy2 }, color_u32({ draw_icon_color[1] * 0.20, draw_icon_color[2] * 0.20, draw_icon_color[3] * 0.20, icon_alpha }), 2.5);
        local highlight = theme.icon_highlight or { 1.00, 1.00, 1.00, 1.00 };
        draw_list:AddRectFilled({ ix1 + 1, iy1 + 1 }, { ix2 - 1, iy1 + ((iy2 - iy1) * 0.45) }, color_u32(color_with_alpha(highlight, command_supported and 0.05 or 0.02)), 2.0);
        local drew_image_icon = false;
        local asset_handle = ICON_ART_STYLE.icon_handle(icon_def);
        if (asset_handle ~= nil) then
            local tint = available and { 1.00, 1.00, 1.00, icon_alpha } or { 0.58, 0.58, 0.58, icon_alpha };
            drew_image_icon = pcall(function ()
                draw_list:AddImage(asset_handle, { ix1, iy1 }, { ix2, iy2 }, { 0, 0 }, { 1, 1 }, color_u32(tint));
            end);
        end
        if (not drew_image_icon) then
            local item_handle = COMMAND_MODE.item_icon_handle_for_slot(slot);
            if (item_handle ~= nil) then
                local image_inset = math.max(2, math.floor(slot_size * 0.08));
                local tint = available and { 1.00, 1.00, 1.00, icon_alpha } or { 0.58, 0.58, 0.58, icon_alpha };
                drew_image_icon = pcall(function ()
                    draw_list:AddImage(item_handle, { ix1 + image_inset, iy1 + image_inset }, { ix2 - image_inset, iy2 - image_inset }, { 0, 0 }, { 1, 1 }, color_u32(tint));
                end);
            end
        end
        if (not drew_image_icon) then
            draw_icon_mark(draw_list, icon_def, rx + slot_size * 0.50, ry + slot_size * 0.48, slot_size * 0.21, draw_icon_color);
        end
    else
        draw_list:AddRectFilled({ ix1, iy1 }, { ix2, iy2 }, color_u32(theme.empty_bg or { 0.03, 0.03, 0.04, 0.82 }), 2.5);
        draw_empty_slot_overlay(draw_list, rx, ry, slot_size);
    end

    if (has_command and command_supported and weaponskill_pulse_info ~= nil) then
        draw_weaponskill_pulse_overlay(draw_list, rx, ry, slot_size, weaponskill_pulse_info);
    end

    if (has_command and command_supported and server_buff_pulse_info ~= nil) then
        draw_weaponskill_pulse_overlay(draw_list, rx, ry, slot_size, server_buff_pulse_info);
    end

    if (has_command and command_supported and visual_state ~= nil and visual_state.available == false) then
        draw_availability_overlay(draw_list, ix1, iy1, ix2, iy2, visual_state, recast_info == nil);
    end

    if (has_command and command_supported and recast_info ~= nil) then
        draw_recast_overlay(draw_list, ix1, iy1, ix2, iy2, recast_info);
    end

    if (has_command and command_supported and macro_run_info ~= nil) then
        draw_recast_overlay(draw_list, ix1, iy1, ix2, iy2, macro_run_info);
    end

    if (setting_enabled('show_hotkeys', true)) then
        local hotkey = KEYBIND.slot_display_label(BAR.current_key(), row.id, index);
        local key_color = command_supported and row_color or (has_command and { 1.00, 0.30, 0.24, 1.00 } or { 0.54, 0.54, 0.58, 1.00 });
        if (hotkey ~= nil and (row.showHotkeys ~= false or hotkey ~= '')) then
            draw_hotkey_badge(draw_list, rx, ry, slot_size, hotkey, key_color, not has_command);
        end
    end

    local label = COMMAND_MODE.slot_label(slot);
    if (setting_enabled('show_labels', true) and has_command and label ~= nil and label ~= '') then
        draw_label_overlay(draw_list, rx, ry, slot_size, label, command_supported and draw_icon_color or { 1.00, 0.30, 0.24, 1.00 });
    end

    if (has_command and command_supported and visual_state ~= nil and visual_state.count_label ~= nil) then
        draw_count_badge(draw_list, rx, ry, slot_size, visual_state.count_label);
    end

    if (has_command and not command_supported) then
        draw_unsupported_overlay(draw_list, rx, ry, slot_size);
    end

    if (show_frame) then
        draw_edit_handle(draw_list, rx, ry, slot_size, edit_hovered);
    end

    if (hovered and glow_scale > 0 and glow_alpha_scale > 0) then
        local hover_color = theme.hover_border or { 1.00, 0.96, 0.72, 0.52 };
        local hover_alpha = (hover_color[4] or 1.00) * glow_alpha_scale;
        draw_list:AddRect({ rx + 1, ry + 1 }, { rx + slot_size - 1, ry + slot_size - 1 }, color_u32(color_with_alpha(hover_color, hover_alpha)), rr, ImDrawCornerFlags_All, 1.3 * glow_scale);
    end

    if (edit_clicked) then
        local editor_row = BAR.group_modifier(row.id) ~= nil and (ROW_BY_ID[BAR.parent_group(row.id)] or row) or row;
        open_macro_editor(editor_row, index);
        return false;
    end

    return clicked;
end

local function render_tooltip(row, index)
    if (not imgui.IsItemHovered()) then
        return;
    end

    local slot = get_slot(row.id, index);
    local family = command_family(slot);
    local _, icon_token = slot_icon(slot, family);
    local prefix = slot ~= nil and command_prefix_and_name(slot.command) or nil;
    imgui.BeginTooltip();
    imgui.Text(row.label .. ' ' .. BAR.slot_index_label(index));
    local label = COMMAND_MODE.slot_label(slot);
    if (label ~= nil and label ~= '') then
        imgui.Text(label);
    end
    if (prefix ~= '/item' and icon_token ~= nil) then
        imgui.Text('icon: ' .. icon_token);
    end
    if (slot and slot.command) then
        local commands = MACRO.slot_commands(slot);
        local recast_info = slot_recast(slot);
        local visual_state = slot_visual_state(slot);
        if (MACRO.slot_mode(slot) == 'multi' and #commands > 1) then
            imgui.Text(('macro: %d commands'):fmt(#commands));
            for line_index, command in ipairs(commands) do
                imgui.Text(('%d. %s'):fmt(line_index, command));
            end
        else
            imgui.Text(slot.command);
        end
        if (visual_state ~= nil and visual_state.count ~= nil) then
            imgui.Text(('count: %d'):fmt(visual_state.count));
        end
        if (visual_state ~= nil and visual_state.available == false and visual_state.reason ~= nil) then
            imgui.Text('availability: ' .. visual_state.reason);
        end
        if (recast_info ~= nil) then
            imgui.Text(('recast: %s'):fmt(recast_info.label));
        end
        local macro_run_info = MACRO.run_overlay_info({
            profile_key = editable_profile_key(refresh_profile_context(BAR.key_for_group(row.id))),
            group = row.id,
            index = index,
        });
        if (macro_run_info ~= nil) then
            imgui.Text(('macro running: %s'):fmt(macro_run_info.label));
        end
        local validation_error = MACRO.commands_validation_error(commands);
        if (validation_error ~= nil) then
            imgui.Text(validation_error);
        end
    else
        imgui.Text('(empty)');
    end
    imgui.EndTooltip();
end

local function render_row(row, active, transition_alpha, show_row_label, capture_anchor, show_frame, start_index, end_index, label_text)
    local current_slot_size = slot_size();
    local gap = button_gap();
    start_index = tonumber(start_index) or 1;
    end_index = tonumber(end_index) or BAR.button_count();

    if (show_row_label) then
        imgui.Text(label_text or row.label);
        imgui.SameLine(52, gap);
    end

    for index = start_index, end_index do
        if (index > start_index) then
            imgui.SameLine(0, gap);
        end

        local should_capture_anchor = (index == 1) and capture_anchor or false;
        local effective_row = row;
        local effective_active = active;
        local effective_transition_alpha = transition_alpha;
        if (BAR.row_supports_modifiers(row.id)) then
            effective_row = BAR.visual_row_for_index(row.id, index);
            local effective_modifier = BAR.group_modifier(effective_row.id);
            effective_active = effective_modifier ~= nil and active_group() == effective_modifier or active;
            effective_transition_alpha = 0;
        end

        if (render_slot_button(effective_row, index, current_slot_size, effective_active, effective_transition_alpha, should_capture_anchor, show_frame)) then
            execute_slot(effective_row.id, index, 'click');
        end
        render_tooltip(effective_row, index);
    end
end

function BAR.render_button_layout(row, active, transition_alpha, show_row_label, capture_anchor, show_frame, bar_key)
    local visible_count = BAR.button_count(bar_key);
    local columns = BAR.buttons_per_row(bar_key);
    local settings = state.config.settings or {};
    local row_gap = tonumber(settings.row_gap) or DEFAULT_CONFIG.settings.row_gap;
    local row_count = math.max(1, math.ceil(visible_count / columns));

    for layout_row = 1, row_count do
        if (layout_row > 1 and row_gap > 0) then
            imgui.Dummy({ 1, row_gap });
        end

        local start_index = ((layout_row - 1) * columns) + 1;
        local end_index = math.min(visible_count, start_index + columns - 1);
        local label_text = layout_row == 1 and row.label or '';
        render_row(row, active, transition_alpha, show_row_label, capture_anchor, show_frame, start_index, end_index, label_text);
    end
end

local function render_bars()
    if (not main_bar_visible()) then
        return;
    end

    local previous_bar_key = state.render_bar_key;
    state.render_bar_key = 'main';
    local profile = refresh_profile_context('main');
    local settings = state.config.settings or {};
    local current_slot_size = slot_size();
    local gap = button_gap();
    local row_gap = tonumber(settings.row_gap) or DEFAULT_CONFIG.settings.row_gap;
    local theme = current_theme();
    local show_frame = bar_frame_visible();
    local visible_count = BAR.button_count('main');
    local columns = BAR.buttons_per_row('main');
    local row_count = math.max(1, math.ceil(visible_count / columns));
    local label_width = show_frame and 58 or 0;
    local content_width = label_width + (current_slot_size * columns) + (gap * math.max(0, columns - 1));
    local content_height = (current_slot_size * row_count) + (row_gap * (row_count - 1));
    local hidden_pad = show_frame and 0 or frameless_window_padding();
    local width = content_width + (show_frame and 20 or (hidden_pad * 2));
    local height = content_height + (show_frame and 48 or (hidden_pad * 2));
    local active = active_group();
    local anchor_x, anchor_y = bar_window_position(settings);
    local offset_x, offset_y = bar_window_offset(show_frame);
    local window_x = anchor_x - offset_x;
    local window_y = anchor_y - offset_y;
    local window_flags = bit.bor(ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoSavedSettings);
    local style_var_count = 0;
    local anchor_locked = state.bar_anchor_lock_x ~= nil and state.bar_anchor_lock_y ~= nil;

    state.bar_measured_anchor_x = nil;
    state.bar_measured_anchor_y = nil;

    if (show_frame) then
        imgui.SetNextWindowPos({ window_x, window_y }, anchor_locked and ImGuiCond_Always or ImGuiCond_FirstUseEver);
    else
        imgui.SetNextWindowPos({ window_x, window_y }, ImGuiCond_Always);
        window_flags = bit.bor(window_flags, ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoBringToFrontOnFocus);
        imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { hidden_pad, hidden_pad });
        imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0.0);
        style_var_count = 2;
    end

    imgui.SetNextWindowSize({ width, height }, ImGuiCond_Always);
    imgui.PushStyleColor(ImGuiCol_WindowBg, theme.window_bg or { 0.025, 0.022, 0.018, 0.72 });
    imgui.PushStyleColor(ImGuiCol_Border,   theme.window_border or { 0.58, 0.44, 0.20, 0.88 });

    local window_title = ('AshitaBars [%s]###AshitaBars'):fmt(profile.key or 'DEFAULT');
    if (imgui.Begin(window_title, state.visible, window_flags)) then
        state.bar_window_x, state.bar_window_y = imgui.GetWindowPos();

        if (state.config_error ~= nil) then
            imgui.Text('Config load failed. Using defaults.');
        end

        BAR.render_button_layout(ROW_BY_ID.base, active == 'base', 0, show_frame, true, show_frame, 'main');

        if (state.bar_measured_anchor_x ~= nil and state.bar_measured_anchor_y ~= nil) then
            if (state.bar_anchor_lock_x ~= nil and state.bar_anchor_lock_y ~= nil) then
                local dx = state.bar_anchor_lock_x - state.bar_measured_anchor_x;
                local dy = state.bar_anchor_lock_y - state.bar_measured_anchor_y;
                if (math.abs(dx) > 0.01 or math.abs(dy) > 0.01) then
                    local current_x, current_y = imgui.GetWindowPos();
                    imgui.SetWindowPos({ current_x + dx, current_y + dy });
                    state.bar_window_x = current_x + dx;
                    state.bar_window_y = current_y + dy;
                end
                state.bar_anchor_x = state.bar_anchor_lock_x;
                state.bar_anchor_y = state.bar_anchor_lock_y;
                state.bar_anchor_lock_x = nil;
                state.bar_anchor_lock_y = nil;
            else
                state.bar_anchor_x = state.bar_measured_anchor_x;
                state.bar_anchor_y = state.bar_measured_anchor_y;
            end
        end
    end
    imgui.End();
    imgui.PopStyleColor(2);
    if (style_var_count > 0) then
        imgui.PopStyleVar(style_var_count);
    end
    state.render_bar_key = previous_bar_key;
end

function BAR.render_extra_bar(bar_key)
    if (not BAR.extra_bar_visible(bar_key)) then
        return;
    end

    local previous_bar_key = state.render_bar_key;
    state.render_bar_key = bar_key;
    local profile = refresh_profile_context(bar_key);
    local settings = state.config.settings or {};
    local current_slot_size = slot_size();
    local gap = button_gap();
    local row_gap = tonumber(settings.row_gap) or DEFAULT_CONFIG.settings.row_gap;
    local theme = current_theme();
    local show_frame = bar_frame_visible();
    local visible_count = BAR.button_count(bar_key);
    local columns = BAR.buttons_per_row(bar_key);
    local row_count = math.max(1, math.ceil(visible_count / columns));
    local content_width = (current_slot_size * columns) + (gap * math.max(0, columns - 1));
    local content_height = (current_slot_size * row_count) + (row_gap * (row_count - 1));
    local hidden_pad = show_frame and 0 or frameless_window_padding();
    local width = content_width + (show_frame and 20 or (hidden_pad * 2));
    local height = content_height + (show_frame and 48 or (hidden_pad * 2));
    local anchor_x, anchor_y = BAR.extra_bar_window_position(bar_key, settings);
    local offset_x, offset_y = BAR.extra_bar_window_offset(bar_key, show_frame);
    local window_x = anchor_x - offset_x;
    local window_y = anchor_y - offset_y;
    local window_flags = bit.bor(ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoSavedSettings);
    local style_var_count = 0;
    local runtime = BAR.extra_runtime(bar_key);
    local anchor_locked = runtime.anchor_lock_x ~= nil and runtime.anchor_lock_y ~= nil;

    runtime.measured_anchor_x = nil;
    runtime.measured_anchor_y = nil;
    runtime.open[1] = true;

    if (show_frame) then
        imgui.SetNextWindowPos({ window_x, window_y }, anchor_locked and ImGuiCond_Always or ImGuiCond_FirstUseEver);
    else
        imgui.SetNextWindowPos({ window_x, window_y }, ImGuiCond_Always);
        window_flags = bit.bor(window_flags, ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoBringToFrontOnFocus);
        imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { hidden_pad, hidden_pad });
        imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0.0);
        style_var_count = 2;
    end

    imgui.SetNextWindowSize({ width, height }, ImGuiCond_Always);
    imgui.PushStyleColor(ImGuiCol_WindowBg, theme.window_bg or { 0.025, 0.022, 0.018, 0.72 });
    imgui.PushStyleColor(ImGuiCol_Border,   theme.window_border or { 0.58, 0.44, 0.20, 0.88 });

    local window_title = ('AshitaBars %s [%s]###AshitaBars%s'):fmt(BAR.extra_label(bar_key), profile.key or 'DEFAULT', bar_key);
    if (imgui.Begin(window_title, runtime.open, window_flags)) then
        runtime.window_x, runtime.window_y = imgui.GetWindowPos();
        BAR.render_button_layout(ROW_BY_ID[BAR.extra_row_id(bar_key)] or CLICK_ROW, false, 0, false, bar_key, show_frame, bar_key);

        if (runtime.measured_anchor_x ~= nil and runtime.measured_anchor_y ~= nil) then
            if (runtime.anchor_lock_x ~= nil and runtime.anchor_lock_y ~= nil) then
                local dx = runtime.anchor_lock_x - runtime.measured_anchor_x;
                local dy = runtime.anchor_lock_y - runtime.measured_anchor_y;
                if (math.abs(dx) > 0.01 or math.abs(dy) > 0.01) then
                    local current_x, current_y = imgui.GetWindowPos();
                    imgui.SetWindowPos({ current_x + dx, current_y + dy });
                    runtime.window_x = current_x + dx;
                    runtime.window_y = current_y + dy;
                end
                runtime.anchor_x = runtime.anchor_lock_x;
                runtime.anchor_y = runtime.anchor_lock_y;
                runtime.anchor_lock_x = nil;
                runtime.anchor_lock_y = nil;
            else
                runtime.anchor_x = runtime.measured_anchor_x;
                runtime.anchor_y = runtime.measured_anchor_y;
            end
        end
    end
    imgui.End();
    if (runtime.open[1] == false) then
        BAR.set_override(bar_key, 'visible', false);
        runtime.open[1] = true;
    end
    imgui.PopStyleColor(2);
    if (style_var_count > 0) then
        imgui.PopStyleVar(style_var_count);
    end
    state.render_bar_key = previous_bar_key;
end

local function render_click_bar()
    for _, bar_key in ipairs(BAR.EXTRA_KEYS) do
        BAR.render_extra_bar(bar_key);
    end
end

local function render_runtime_int_control(label, id, value, source, min_value, max_value, apply_value, unit)
    unit = unit or 'px';
    local text = (unit == '%') and ('%d%% (%s)'):fmt(value, source) or ('%d %s (%s)'):fmt(value, unit, source);
    local slider_format = (unit == '%') and '%d%%' or ('%d ' .. unit);

    imgui.TextColored(UI_COLORS.config_header, label);
    imgui.SameLine(160);
    imgui.Text(text);

    local buffer = { value };
    imgui.PushItemWidth(340);
    local changed = imgui.SliderInt(('##ashitabars_%s_slider'):fmt(id), buffer, min_value, max_value, slider_format, ImGuiSliderFlags_AlwaysClamp);
    imgui.PopItemWidth();
    if (changed) then
        apply_value(buffer[1]);
    end
end

function BAR.render_profile_scope_config(bar_key)
    local scope, source = BAR.profile_scope(bar_key);
    imgui.Separator();
    imgui.TextColored(UI_COLORS.config_header, 'Button Scope');
    if (imgui.RadioButton(('Global##ashitabars_config_%s_scope_global'):fmt(bar_key), scope == 'global')) then
        BAR.set_override(bar_key, 'profile_scope', 'global');
    end
    imgui.SameLine(0, 8);
    if (imgui.RadioButton(('Main Job##ashitabars_config_%s_scope_job'):fmt(bar_key), scope == 'job')) then
        BAR.set_override(bar_key, 'profile_scope', 'job');
    end
    imgui.SameLine(0, 8);
    if (imgui.RadioButton(('Main + Subjob##ashitabars_config_%s_scope_job_sub'):fmt(bar_key), scope == 'job_sub')) then
        BAR.set_override(bar_key, 'profile_scope', 'job_sub');
    end
    imgui.SameLine(0, 8);
    imgui.Text(('(%s)'):fmt(source));

    local profile = refresh_profile_context(bar_key);
    imgui.Text(('Edits: %s'):fmt(profile.key or 'DEFAULT'));
    imgui.SameLine(0, 8);
    imgui.Text(('Base: %s (%s)'):fmt(profile.base_key or 'DEFAULT', profile.source or 'default'));
end

function BAR.render_visibility_config()
    imgui.TextColored(UI_COLORS.config_header, 'Visible Bars');

    local bars = {
        { key = 'main', label = 'Main Bar' },
    };
    for _, bar_key in ipairs(BAR.EXTRA_KEYS) do
        bars[#bars + 1] = { key = bar_key, label = BAR.extra_label(bar_key) };
    end

    for _, bar in ipairs(bars) do
        local is_main = bar.key == 'main';
        local visible = is_main and main_bar_visible() or BAR.extra_bar_visible(bar.key);
        if (imgui.Checkbox(('%s##ashitabars_config_visible_%s'):fmt(bar.label, bar.key), { visible })) then
            local next_visible = not visible;
            BAR.set_override(bar.key, 'visible', next_visible);
            if (is_main) then
                state.visible[1] = next_visible;
            else
                BAR.extra_runtime(bar.key).open[1] = true;
            end
            state.config_save_message = nil;
        end
        imgui.SameLine(0, 8);
        imgui.Text(('(%s)'):fmt(is_main and main_bar_visible_source() or BAR.extra_bar_visible_source(bar.key)));
    end
end

function BAR.render_config_tab(bar_key)
    BAR.render_profile_scope_config(bar_key);

    imgui.Separator();
    imgui.TextColored(UI_COLORS.config_header, 'Button Layout');
    render_runtime_int_control('Button Count', ('%s_button_count'):fmt(bar_key), BAR.button_count(bar_key), BAR.button_count_source(bar_key), LIMITS.button_count_min, LIMITS.button_count_max, function (value)
        local count = BAR.normalize_button_count(value);
        BAR.set_override(bar_key, 'button_count', count);
        if (count ~= nil and BAR.buttons_per_row(bar_key) > count) then
            BAR.set_override(bar_key, 'buttons_per_row', count);
        end
    end, 'buttons');

    render_runtime_int_control('Buttons Per Row', ('%s_buttons_per_row'):fmt(bar_key), BAR.buttons_per_row(bar_key), BAR.buttons_per_row_source(bar_key), LIMITS.buttons_per_row_min, BAR.button_count(bar_key), function (value)
        BAR.set_override(bar_key, 'buttons_per_row', BAR.normalize_buttons_per_row(value, BAR.button_count(bar_key)));
    end, 'buttons');

    render_runtime_int_control('Button Size', ('%s_slot_size'):fmt(bar_key), slot_size(bar_key), slot_size_source(bar_key), LIMITS.slot_size_min, LIMITS.slot_size_max, function (value)
        BAR.set_override(bar_key, 'slot_size', normalize_slot_size(value));
    end);

    render_runtime_int_control('Button Gap', ('%s_button_gap'):fmt(bar_key), button_gap(bar_key), button_gap_source(bar_key), LIMITS.button_gap_min, LIMITS.button_gap_max, function (value)
        BAR.set_override(bar_key, 'button_gap', normalize_button_gap(value));
    end);

    imgui.Separator();
    imgui.TextColored(UI_COLORS.config_header, 'Button Text');
    render_runtime_int_control('Label Vertical', ('%s_label_vertical_position'):fmt(bar_key), label_vertical_position(bar_key), label_vertical_position_source(bar_key), LIMITS.label_vertical_position_min, LIMITS.label_vertical_position_max, function (value)
        BAR.set_override(bar_key, 'label_vertical_position', normalize_label_vertical_position(value));
    end, '%');

    imgui.Separator();
    imgui.TextColored(UI_COLORS.config_header, 'Button Glow');
    render_runtime_int_control('Glow Size', ('%s_slot_glow_size'):fmt(bar_key), slot_glow_size(bar_key), slot_glow_size_source(bar_key), LIMITS.slot_glow_size_min, LIMITS.slot_glow_size_max, function (value)
        BAR.set_override(bar_key, 'slot_glow_size', normalize_slot_glow_size(value));
    end, '%');

    render_runtime_int_control('Glow Opacity', ('%s_slot_glow_opacity'):fmt(bar_key), slot_glow_opacity(bar_key), slot_glow_opacity_source(bar_key), LIMITS.slot_glow_opacity_min, LIMITS.slot_glow_opacity_max, function (value)
        BAR.set_override(bar_key, 'slot_glow_opacity', normalize_slot_glow_opacity(value));
    end, '%');

    KEYBIND.render_config_section(bar_key);
end

local function render_config_window()
    if (not state.config_visible[1]) then
        return;
    end

    imgui.SetNextWindowSize({ 440, 0 }, ImGuiCond_FirstUseEver);
    if (imgui.Begin(('AshitaBars v%s Configuration###AshitaBarsConfig'):fmt(addon.version), state.config_visible, ImGuiWindowFlags_AlwaysAutoResize)) then
        if (imgui.BeginTabBar('##ashitabars_config_tabs', ImGuiTabBarFlags_NoCloseWithMiddleMouseButton)) then
            if (imgui.BeginTabItem('General##ashitabars_config_general', nil)) then
                imgui.TextColored(UI_COLORS.config_header, 'Global');
                imgui.Text(('Theme: %s'):fmt(select(2, current_theme())));
                imgui.Text(('Icon Style: %s'):fmt(icon_style()));
                imgui.Separator();
                imgui.TextColored(UI_COLORS.config_header, 'Bars');
                BAR.render_visibility_config();
                imgui.Separator();
                local bars_unlocked = bar_frame_visible();
                if (imgui.Checkbox('Unlock Bars##ashitabars_config_unlock_bars', { bars_unlocked })) then
                    lock_bar_anchor();
                    BAR.lock_all_extra_bar_anchors();
                    state.config.settings.bars_unlocked = not bars_unlocked;
                    state.config_save_message = nil;
                end
                imgui.Separator();
                imgui.TextColored(UI_COLORS.config_header, 'Weapon Skills');
                local ws_pulse = MACRO.weaponskill_pulse_enabled();
                if (imgui.Checkbox('Weapon Skill Pulse##ashitabars_config_ws_pulse', { ws_pulse })) then
                    state.config.settings.show_weaponskill_pulse = not ws_pulse;
                    state.config.settings.show_weaponskill_flames = nil;
                    state.config_save_message = nil;
                end
                imgui.EndTabItem();
            end
            if (main_bar_visible() and imgui.BeginTabItem('Main Bar##ashitabars_config_main_bar', nil)) then
                BAR.render_config_tab('main');
                imgui.EndTabItem();
            end
            for _, bar_key in ipairs(BAR.EXTRA_KEYS) do
                if (BAR.extra_bar_visible(bar_key) and imgui.BeginTabItem(('%s##ashitabars_config_%s'):fmt(BAR.extra_label(bar_key), bar_key), nil)) then
                    BAR.render_config_tab(bar_key);
                    imgui.EndTabItem();
                end
            end
            imgui.EndTabBar();
        end
        imgui.Separator();
        if (imgui.Button('Save##ashitabars_config_save')) then
            local ok, message = save_runtime_settings();
            state.config_save_message = ok and 'Saved.' or 'Save failed. See chat log.';
            state.config_save_message_color = ok and UI_COLORS.success or UI_COLORS.error;
            if (ok) then
                log_info(message);
            else
                log_warn(message);
            end
        end
        if (state.config_save_message ~= nil) then
            imgui.SameLine(0, 8);
            imgui.TextColored(state.config_save_message_color, state.config_save_message);
        end
    end
    imgui.End();
end

function MACRO.weaponskill_effect_label(style)
    if (style == 'off') then return 'Off'; end
    return 'Native Pulse';
end

function MACRO.render_weaponskill_effect_editor(editor)
    if (not MACRO.editor_is_weaponskill(editor)) then
        return;
    end

    imgui.Separator();
    imgui.TextColored(UI_COLORS.config_header, 'Weapon Skill Effect');
    imgui.Checkbox('Enable Effect##ashitabars_button_ws_effect_enabled', editor.weaponskill_effect_enabled);

    if (editor.weaponskill_effect_enabled[1] == false) then
        return;
    end

    editor.weaponskill_effect = 'pulse';
    imgui.PushItemWidth(250);
    local intensity = MACRO.normalize_weaponskill_effect_intensity(editor.weaponskill_effect_intensity[1]) or 70;
    editor.weaponskill_effect_intensity[1] = intensity;
    imgui.SliderInt('Intensity##ashitabars_button_ws_effect_intensity', editor.weaponskill_effect_intensity, LIMITS.weaponskill_effect_intensity_min, LIMITS.weaponskill_effect_intensity_max, '%d%%', ImGuiSliderFlags_AlwaysClamp);

    local opacity = MACRO.normalize_weaponskill_effect_opacity(editor.weaponskill_effect_opacity[1]) or 100;
    editor.weaponskill_effect_opacity[1] = opacity;
    imgui.SliderInt('Opacity##ashitabars_button_ws_effect_opacity', editor.weaponskill_effect_opacity, LIMITS.weaponskill_effect_opacity_min, LIMITS.weaponskill_effect_opacity_max, '%d%%', ImGuiSliderFlags_AlwaysClamp);

    local frequency = MACRO.normalize_weaponskill_effect_frequency(editor.weaponskill_effect_frequency[1]) or 100;
    editor.weaponskill_effect_frequency[1] = frequency;
    imgui.SliderInt('Frequency##ashitabars_button_ws_effect_frequency', editor.weaponskill_effect_frequency, LIMITS.weaponskill_effect_frequency_min, LIMITS.weaponskill_effect_frequency_max, '%d%%', ImGuiSliderFlags_AlwaysClamp);
    imgui.PopItemWidth();
end

function MACRO.render_editor_clipboard_controls(editor)
    imgui.Separator();
    imgui.TextColored(UI_COLORS.config_header, 'Page Clipboard');
    if (imgui.Button('Copy##ashitabars_button_copy_page')) then
        local ok, message = MACRO.copy_editor_page();
        editor.message = message;
        editor.message_color = ok and UI_COLORS.success or UI_COLORS.error;
        if (not ok) then
            log_warn(message);
        end
    end
    imgui.SameLine(0, 8);
    if (imgui.Button('Paste##ashitabars_button_paste_page')) then
        local ok, message = MACRO.paste_editor_page();
        editor.message = message;
        editor.message_color = ok and UI_COLORS.success or UI_COLORS.error;
        if (not ok) then
            log_warn(message);
        end
    end
    if (type(state.macro_clipboard) == 'table' and state.macro_clipboard.label ~= nil) then
        imgui.SameLine(0, 8);
        imgui.Text(('Copied: %s'):fmt(state.macro_clipboard.label));
    end
end

function MACRO.render_editor_active_form(editor)
    MACRO.render_editor_clipboard_controls(editor);

    imgui.Separator();
    imgui.TextColored(UI_COLORS.config_header, 'Shared Button');
    SHARED.render_selector(editor);
    imgui.PushItemWidth(360);
    imgui.InputText('Shared Name##ashitabars_button_shared_name', editor.shared_name_buffer, SHARED.NAME_MAX);
    imgui.PopItemWidth();
    if (imgui.Button('Save Shared##ashitabars_button_save_shared')) then
        local ok, message = SHARED.save_editor_shared();
        editor.message = message;
        editor.message_color = ok and UI_COLORS.success or UI_COLORS.error;
        if (not ok) then
            log_warn(message);
        end
    end
    imgui.SameLine(0, 8);
    if (imgui.Button('Assign Shared##ashitabars_button_assign_shared')) then
        local ok, message = SHARED.assign_editor_shared();
        editor.message = message;
        editor.message_color = ok and UI_COLORS.success or UI_COLORS.error;
        if (not ok) then
            log_warn(message);
        end
    end
    imgui.SameLine(0, 8);
    if (imgui.Button('Detach Local##ashitabars_button_detach_shared')) then
        local detached = editor.shared_ref;
        SHARED.detach_editor_shared();
        if (save_macro_editor(false)) then
            editor.message = detached ~= nil and ('Detached local copy from: ' .. detached) or 'Saved local copy.';
            editor.message_color = UI_COLORS.success;
        end
    end

    imgui.Separator();
    local mode = MACRO.normalize_mode(editor.macro_mode);
    imgui.TextColored(UI_COLORS.config_header, 'Command Mode');
    COMMAND_MODE.render_mode_selector(editor);

    mode = MACRO.normalize_mode(editor.macro_mode);

    imgui.PushItemWidth(360);
    if (COMMAND_MODE.is_structured_mode(mode)) then
        if (imgui.Checkbox('Use Action Name As Label##ashitabars_button_action_name_label', editor.use_action_name_label)) then
            if (editor.use_action_name_label[1] ~= false) then
                COMMAND_MODE.apply_editor_action_label(editor, mode);
            end
        end
    end
    if (not COMMAND_MODE.is_structured_mode(mode) or editor.use_action_name_label[1] == false) then
        imgui.InputText('Label##ashitabars_button_label', editor.label_buffer, LIMITS.macro_label_max);
    elseif (COMMAND_MODE.is_structured_mode(mode)) then
        COMMAND_MODE.apply_editor_action_label(editor, mode);
    end
    if (mode == 'multi') then
        MACRO.render_multiline_input('Commands##ashitabars_button_commands', editor.commands_buffer, MACRO.COMMANDS_TEXT_MAX, { 360, 122 });
        imgui.Checkbox('Run As Ashita Script##ashitabars_button_run_as_script', editor.run_as_script);
    elseif (mode == 'single') then
        imgui.InputText('Command##ashitabars_button_command', editor.command_buffer, LIMITS.macro_command_max);
    end
    imgui.PopItemWidth();
    if (mode ~= 'single' and mode ~= 'multi') then
        COMMAND_MODE.render_structured_editor(editor, mode);
    end
    if (mode ~= 'item') then
        imgui.TextColored(UI_COLORS.config_header, 'Icon');
        MACRO.render_icon_picker_preview_button(editor, 72);
    elseif (editor.icon_picker_visible ~= nil) then
        editor.icon_picker_visible[1] = false;
    end
    MACRO.render_weaponskill_effect_editor(editor);

    local validation_error = MACRO.editor_validation_error();
    if (validation_error ~= nil) then
        imgui.TextColored(UI_COLORS.error, validation_error);
    end

    imgui.Separator();
    if (validation_error == nil) then
        if (imgui.Button('Save##ashitabars_button_save')) then
            if (save_macro_editor(false)) then
                editor.visible[1] = false;
                if (editor.icon_picker_visible ~= nil) then
                    editor.icon_picker_visible[1] = false;
                end
            end
        end
        imgui.SameLine(0, 8);
        if (imgui.Button('Validate & Run##ashitabars_button_validate_run')) then
            local ok, message = MACRO.run_editor_commands();
            editor.message = message;
            editor.message_color = ok and UI_COLORS.success or UI_COLORS.error;
            if (not ok) then
                log_warn(message);
            end
        end
        imgui.SameLine(0, 8);
    end
    if (imgui.Button('Clear##ashitabars_button_clear')) then
        save_macro_editor(true);
    end
    imgui.SameLine(0, 8);
    if (imgui.Button('Reset##ashitabars_button_reset')) then
        reset_macro_editor();
    end
    imgui.SameLine(0, 8);
    if (imgui.Button('Close##ashitabars_button_close')) then
        editor.visible[1] = false;
    end

    if (editor.message ~= nil) then
        imgui.SameLine(0, 8);
        imgui.TextColored(editor.message_color or UI_COLORS.success, editor.message);
    end
end

function MACRO.render_editor_variant_tabs(editor)
    if (not MACRO.editor_is_main_parent(editor)) then
        return false;
    end

    local switched = false;
    if (imgui.BeginTabBar('##ashitabars_button_variant_tabs', ImGuiTabBarFlags_NoCloseWithMiddleMouseButton)) then
        local function variant_tab(label, group, enabled)
            if (not enabled) then
                return;
            end
            if (imgui.BeginTabItem(('%s##ashitabars_button_variant_%s'):fmt(label, group), nil)) then
                if (editor.group ~= group) then
                    open_macro_editor(ROW_BY_ID[group], editor.index, true);
                    switched = true;
                end
                imgui.EndTabItem();
            end
        end

        variant_tab('Main', editor.parent_group, true);
        variant_tab('Ctrl', BAR.modifier_row_id(editor.parent_group, 'ctrl'), editor.modifier_ctrl_enabled[1] == true);
        variant_tab('Alt', BAR.modifier_row_id(editor.parent_group, 'alt'), editor.modifier_alt_enabled[1] == true);
        variant_tab('Shift', BAR.modifier_row_id(editor.parent_group, 'shift'), editor.modifier_shift_enabled[1] == true);
        imgui.EndTabBar();
    end

    if (switched) then
        return true;
    end

    if (editor.group == editor.parent_group) then
        imgui.TextColored(UI_COLORS.config_header, 'Modifiers');
        imgui.Checkbox('Ctrl##ashitabars_button_enable_ctrl', editor.modifier_ctrl_enabled);
        imgui.SameLine(0, 12);
        imgui.Checkbox('Alt##ashitabars_button_enable_alt', editor.modifier_alt_enabled);
        imgui.SameLine(0, 12);
        imgui.Checkbox('Shift##ashitabars_button_enable_shift', editor.modifier_shift_enabled);
    end

    return false;
end

local function render_macro_editor_window()
    local editor = state.macro_editor;
    if (editor == nil or not editor.visible[1]) then
        if (editor ~= nil and editor.icon_picker_visible ~= nil) then
            editor.icon_picker_visible[1] = false;
        end
        return;
    end

    local row_label = MACRO.editor_is_main_parent(editor) and (editor.bar_key == 'main' and 'Button' or BAR.extra_label(editor.bar_key)) or editor_row_label(editor.group);
    local digit = BAR.slot_index_label(editor.index or 1);
    local title = ('AshitaBars Button Editor###AshitaBarsButtonEditor');
    imgui.SetNextWindowSize({ 560, 0 }, ImGuiCond_FirstUseEver);
    if (imgui.Begin(title, editor.visible, ImGuiWindowFlags_AlwaysAutoResize)) then
        local editor_x, editor_y = imgui.GetWindowPos();
        local editor_w = 560;
        if (type(imgui.GetWindowSize) == 'function') then
            local current_w = imgui.GetWindowSize();
            editor_w = tonumber(current_w) or editor_w;
        elseif (type(imgui.GetWindowWidth) == 'function') then
            editor_w = tonumber(imgui.GetWindowWidth()) or editor_w;
        end
        editor.icon_picker_anchor_x = editor_x + editor_w + 8;
        editor.icon_picker_anchor_y = editor_y;

        imgui.TextColored(UI_COLORS.config_header, ('%s %s %s'):fmt(editor.profile_key or 'DEFAULT', row_label, digit));
        if (MACRO.editor_is_main_parent(editor) and editor.group ~= editor.parent_group) then
            imgui.SameLine(0, 8);
            imgui.Text(('%s variant'):fmt(editor_row_label(editor.group)));
        end
        imgui.SameLine(0, 8);
        imgui.Text(('(%s)'):fmt(editor.source or 'config'));

        if (not MACRO.render_editor_variant_tabs(editor)) then
            MACRO.render_editor_active_form(editor);
        end
    end
    imgui.End();
    MACRO.render_icon_picker_window(editor);
end

local function print_help()
    log_info('/ashitabars toggle - Show or hide the bars.');
    log_info('/ashitabars show - Show the bars.');
    log_info('/ashitabars hide - Hide the bars.');
    log_info('/ashitabars config - Toggle the runtime configuration and keybind window.');
    log_info(('/ashitabars size %d-%d|config - Change button size until config reload.'):fmt(LIMITS.slot_size_min, LIMITS.slot_size_max));
    log_info(('/ashitabars gap %d-%d|config - Change button spacing until config reload.'):fmt(LIMITS.button_gap_min, LIMITS.button_gap_max));
    log_info('/ashitabars reload - Reload ashitabars_config.lua.');
    log_info('/ashitabars status - Print input status.');
end

ashita.events.register('load', 'load_cb', function ()
    load_config();
    log_info('Loaded. Uses configurable key events, not /bind. Keys pass through while chat/input is open.');
end);

ashita.events.register('unload', 'unload_cb', function ()
    log_info('Unloaded. No keybind cleanup required.');
end);

ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args();
    if (#args == 0) then return; end

    local cmd = args[1]:lower();
    if (cmd ~= '/ashitabars' and cmd ~= '/abars') then
        return;
    end

    local sub = (#args >= 2) and args[2]:lower() or 'help';
    if (sub == 'toggle') then
        local visible = not main_bar_visible();
        BAR.set_override('main', 'visible', visible);
        state.visible[1] = visible;
        log_info(visible and 'Shown.' or 'Hidden.');
    elseif (sub == 'show') then
        BAR.set_override('main', 'visible', true);
        state.visible[1] = true;
        log_info('Shown.');
    elseif (sub == 'hide') then
        BAR.set_override('main', 'visible', false);
        state.visible[1] = false;
        log_info('Hidden.');
    elseif (sub == 'config' or sub == 'settings') then
        state.config_visible[1] = not state.config_visible[1];
        log_info(state.config_visible[1] and 'Configuration shown.' or 'Configuration hidden.');
    elseif (sub == 'mode') then
        log_info('Stacked mode has been removed. AshitaBars now uses a single per-button modifier row.');
    elseif (sub == 'size') then
        local requested = (#args >= 3) and args[3]:lower() or nil;
        if (requested == nil) then
            log_info(('Button size is %d px (%s).'):fmt(slot_size(), slot_size_source()));
        elseif (requested == 'config' or requested == 'default') then
            state.slot_size_override = nil;
            log_info(('Button size override cleared. Using %d px (%s).'):fmt(slot_size(), slot_size_source()));
        else
            local size = normalize_slot_size(requested);
            if (size == nil) then
                log_warn(('/ashitabars size expects %d-%d or config.'):fmt(LIMITS.slot_size_min, LIMITS.slot_size_max));
            else
                state.slot_size_override = size;
                log_info(('Button size set to %d px (runtime).'):fmt(size));
            end
        end
    elseif (sub == 'gap') then
        local requested = (#args >= 3) and args[3]:lower() or nil;
        if (requested == nil) then
            log_info(('Button gap is %d px (%s).'):fmt(button_gap(), button_gap_source()));
        elseif (requested == 'config' or requested == 'default') then
            state.button_gap_override = nil;
            log_info(('Button gap override cleared. Using %d px (%s).'):fmt(button_gap(), button_gap_source()));
        else
            local gap = normalize_button_gap(requested);
            if (gap == nil) then
                log_warn(('/ashitabars gap expects %d-%d or config.'):fmt(LIMITS.button_gap_min, LIMITS.button_gap_max));
            else
                state.button_gap_override = gap;
                log_info(('Button gap set to %d px (runtime).'):fmt(gap));
            end
        end
    elseif (sub == 'reload') then
        load_config();
        log_info('Config reloaded.');
    elseif (sub == 'status') then
        local input_state = AshitaCore:GetChatManager():IsInputOpen();
        local settings = state.config.settings or {};
        local profile = refresh_profile_context('main');
        local extra_profile = refresh_profile_context('extra1');
        local active = active_group();
        local _, theme_key = current_theme();
        local window_x, window_y = bar_window_position(settings);
        local click_window_x, click_window_y = click_bar_window_position(settings);
        log_info(('mainVisible=%s mainVisibleSource=%s input=0x%02X activeModifier=%s displayMode=%s displayModeSource=%s mainButtons=%d mainButtonsSource=%s mainButtonsPerRow=%d mainButtonsPerRowSource=%s mainSize=%d mainSizeSource=%s mainGap=%d mainGapSource=%s mainLabelY=%d mainLabelYSource=%s mainGlowSize=%d mainGlowSizeSource=%s mainGlowOpacity=%d mainGlowOpacitySource=%s mainFrame=%s mainFrameSource=%s mainAnchor=%d,%d extra1Visible=%s extra1VisibleSource=%s extra1Buttons=%d extra1ButtonsSource=%s extra1ButtonsPerRow=%d extra1ButtonsPerRowSource=%s extra1Size=%d extra1SizeSource=%s extra1Gap=%d extra1GapSource=%s extra1LabelY=%d extra1LabelYSource=%s extra1GlowSize=%d extra1GlowSizeSource=%s extra1GlowOpacity=%d extra1GlowOpacitySource=%s extra1Frame=%s extra1FrameSource=%s extra1Anchor=%d,%d theme=%s iconStyle=%s showRecasts=%s showCounts=%s showAvailability=%s wsTp=%d job=%s subjob=%s mainScope=%s mainScopeSource=%s mainProfile=%s mainBaseProfile=%s mainProfileSource=%s extra1Scope=%s extra1ScopeSource=%s extra1Profile=%s extra1BaseProfile=%s extra1ProfileSource=%s blockModifiers=%s'):fmt(
            tostring(main_bar_visible()),
            main_bar_visible_source(),
            input_state,
            active or 'none',
            display_mode(),
            display_mode_source(),
            BAR.button_count('main'),
            BAR.button_count_source('main'),
            BAR.buttons_per_row('main'),
            BAR.buttons_per_row_source('main'),
            slot_size('main'),
            slot_size_source('main'),
            button_gap('main'),
            button_gap_source('main'),
            label_vertical_position('main'),
            label_vertical_position_source('main'),
            slot_glow_size('main'),
            slot_glow_size_source('main'),
            slot_glow_opacity('main'),
            slot_glow_opacity_source('main'),
            tostring(bar_frame_visible()),
            bar_frame_source(),
            window_x,
            window_y,
            tostring(click_bar_visible()),
            click_bar_visible_source(),
            BAR.button_count('extra1'),
            BAR.button_count_source('extra1'),
            BAR.buttons_per_row('extra1'),
            BAR.buttons_per_row_source('extra1'),
            slot_size('extra1'),
            slot_size_source('extra1'),
            button_gap('extra1'),
            button_gap_source('extra1'),
            label_vertical_position('extra1'),
            label_vertical_position_source('extra1'),
            slot_glow_size('extra1'),
            slot_glow_size_source('extra1'),
            slot_glow_opacity('extra1'),
            slot_glow_opacity_source('extra1'),
            tostring(click_bar_frame_visible()),
            click_bar_frame_source(),
            click_window_x,
            click_window_y,
            theme_key,
            icon_style(),
            tostring(setting_enabled('show_recasts', true)),
            tostring(setting_enabled('show_counts', true)),
            tostring(setting_enabled('show_availability', true)),
            setting_number('weaponskill_tp_threshold', 1000),
            profile.job_key or 'unknown',
            profile.subjob_key or 'none',
            BAR.profile_scope_label(profile.scope),
            tostring(profile.scope_source),
            tostring(profile.key),
            tostring(profile.base_key),
            tostring(profile.source),
            BAR.profile_scope_label(extra_profile.scope),
            tostring(extra_profile.scope_source),
            tostring(extra_profile.key),
            tostring(extra_profile.base_key),
            tostring(extra_profile.source),
            tostring(settings.block_native_macro_modifiers ~= false)));
        log_info(('visualEffects weaponskillPulse=%s'):fmt(tostring(MACRO.weaponskill_pulse_enabled())));
        for _, bar_key in ipairs(BAR.EXTRA_KEYS) do
            local extra_status_profile = refresh_profile_context(bar_key);
            local extra_window_x, extra_window_y = BAR.extra_bar_window_position(bar_key, settings);
            log_info(('%s visible=%s visibleSource=%s buttons=%d buttonsSource=%s buttonsPerRow=%d buttonsPerRowSource=%s size=%d sizeSource=%s gap=%d gapSource=%s labelY=%d labelYSource=%s glowSize=%d glowSizeSource=%s glowOpacity=%d glowOpacitySource=%s frame=%s frameSource=%s anchor=%d,%d scope=%s scopeSource=%s profile=%s baseProfile=%s profileSource=%s'):fmt(
                bar_key,
                tostring(BAR.extra_bar_visible(bar_key)),
                BAR.extra_bar_visible_source(bar_key),
                BAR.button_count(bar_key),
                BAR.button_count_source(bar_key),
                BAR.buttons_per_row(bar_key),
                BAR.buttons_per_row_source(bar_key),
                slot_size(bar_key),
                slot_size_source(bar_key),
                button_gap(bar_key),
                button_gap_source(bar_key),
                label_vertical_position(bar_key),
                label_vertical_position_source(bar_key),
                slot_glow_size(bar_key),
                slot_glow_size_source(bar_key),
                slot_glow_opacity(bar_key),
                slot_glow_opacity_source(bar_key),
                tostring(bar_frame_visible()),
                bar_frame_source(),
                extra_window_x,
                extra_window_y,
                BAR.profile_scope_label(extra_status_profile.scope),
                tostring(extra_status_profile.scope_source),
                tostring(extra_status_profile.key),
                tostring(extra_status_profile.base_key),
                tostring(extra_status_profile.source)));
        end
        local keybind_conflicts = KEYBIND.conflict_messages();
        local keybind_parts = {
            ('main=%s'):fmt(KEYBIND.summary('main')),
        };
        for _, bar_key in ipairs(BAR.EXTRA_KEYS) do
            keybind_parts[#keybind_parts + 1] = ('%s=%s'):fmt(bar_key, KEYBIND.summary(bar_key));
        end
        log_info(('keybinds %s conflicts=%d'):fmt(table.concat(keybind_parts, ' '), #keybind_conflicts));
        for _, message in ipairs(keybind_conflicts) do
            log_warn(('Keybind conflict: %s'):fmt(message));
        end
    else
        print_help();
    end

    e.blocked = true;
end);

ashita.events.register('key_state', 'key_state_cb', function (e)
    clear_directinput_modifier_state(e);
end);

ashita.events.register('key', 'key_cb', function (e)
    if (e.blocked) then
        return;
    end

    if (not is_initial_keydown(e)) then
        return;
    end

    if (type(state.keybind_capture) == 'table') then
        if (input_is_closed() and KEYBIND.handle_capture_event(e)) then
            e.blocked = true;
        end
        return;
    end

    if (imgui_wants_keyboard()) then
        return;
    end

    local combo = KEYBIND.combo_from_event(e);
    if (combo == nil) then
        return;
    end

    if (not input_is_closed()) then
        return;
    end

    local map = KEYBIND.binding_map();
    local binding = map[combo];
    if (binding == nil) then
        return;
    end

    if (execute_slot(binding.group, binding.index, 'key')) then
        e.blocked = true;
    end
end);

ashita.events.register('d3d_present', 'present_cb', function ()
    sync_bar_frame_visibility();
    render_bars();
    render_click_bar();
    render_config_window();
    render_macro_editor_window();
end);
