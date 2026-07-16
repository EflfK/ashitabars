addon.name      = 'ashitabars';
addon.author    = 'Eflfk';
addon.version   = '0.19.0';
addon.desc      = 'Configurable attended action bars for Ashita.';

require('common');

local bit   = require('bit');
local chat  = require('chat');
local ffi   = require('ffi');
local imgui = require('imgui');

pcall(ffi.cdef, 'short __stdcall GetKeyState(int nVirtKey);');

local VK = {
    CONTROL = 0x11,
    ALT     = 0x12,
    SHIFT   = 0x10,
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

local KEY_UP_MASK       = bit.lshift(0x8000, 16);
local KEY_WAS_DOWN_MASK = bit.lshift(0x4000, 16);
local DIGIT_LABELS      = { '1', '2', '3', '4', '5', '6', '7', '8', '9', '0' };
local ROWS              = {
    { id = 'base', label = '1-0',  keyPrefix = ''  },
    { id = 'ctrl', label = 'Ctrl', keyPrefix = 'C' },
    { id = 'alt',  label = 'Alt',  keyPrefix = 'A' },
};
local ROW_BY_ID         = {};
for _, row in ipairs(ROWS) do
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
    ['/ws'] = true,
    ['/weaponskill'] = true,
    ['/ra'] = true,
    ['/range'] = true,
    ['/shoot'] = true,
    ['/item'] = true,
    ['/heal'] = true,
    ['/target'] = true,
    ['/assist'] = true,
    ['/attack'] = true,
    ['/check'] = true,
    ['/echo'] = true,
    ['/p'] = true,
    ['/party'] = true,
    ['/l'] = true,
    ['/linkshell'] = true,
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
};

local ROW_TRANSITION_SECONDS = 0.24;
local ITEM_COUNT_CONTAINER_IDS = { 0, 3 };
local ITEM_COUNT_CACHE_SECONDS = 0.40;
local SLOT_SIZE_MIN = 40;
local SLOT_SIZE_MAX = 96;
local BUTTON_GAP_MIN = 0;
local BUTTON_GAP_MAX = 24;
local SLOT_GLOW_SIZE_MIN = 0;
local SLOT_GLOW_SIZE_MAX = 200;
local SLOT_GLOW_OPACITY_MIN = 0;
local SLOT_GLOW_OPACITY_MAX = 100;
local LABEL_VERTICAL_POSITION_MIN = 0;
local LABEL_VERTICAL_POSITION_MAX = 100;
local MACRO_LABEL_MAX = 32;
local MACRO_COMMAND_MAX = 256;
local MACRO_ICON_MAX = 32;
local FRAMELESS_WINDOW_PADDING = 4;
local CONFIG_HEADER_COLOR = { 1.00, 0.70, 0.36, 1.00 };
local CONFIG_SUCCESS_COLOR = { 0.45, 1.00, 0.58, 1.00 };
local CONFIG_ERROR_COLOR = { 1.00, 0.36, 0.30, 1.00 };
local EDIT_HANDLE_COLOR = { 0.92, 0.72, 0.32, 0.92 };
local EDIT_HANDLE_HOVER_COLOR = { 1.00, 0.88, 0.48, 1.00 };

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
    avatar = 'summon',
    weapon = 'weapon',
    weaponskill = 'weapon',
    weapon_skill = 'weapon',
    ws = 'weapon',
    ranged = 'ranged',
    range = 'ranged',
    shoot = 'ranged',
    item = 'item',
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
    weapon      = { family = 'weapon',      mark = 'blade',   accent = { 1.00, 0.48, 0.36, 1.00 } },
    ranged      = { family = 'weapon',      mark = 'ranged',  accent = { 0.98, 0.64, 0.34, 1.00 } },
    item        = { family = 'item',        mark = 'bag',     accent = { 0.54, 0.94, 0.54, 1.00 } },
    target      = { family = 'target',      mark = 'reticle', accent = { 0.62, 0.86, 1.00, 1.00 } },
    assist      = { family = 'target',      mark = 'arrow',   accent = { 0.62, 0.86, 1.00, 1.00 } },
    check       = { family = 'target',      mark = 'text',    text = '?', accent = { 0.76, 0.90, 1.00, 1.00 } },
    chat        = { family = 'chat',        mark = 'chat',    accent = { 0.90, 0.90, 0.98, 1.00 } },
    test        = { family = 'chat',        mark = 'text',    text = 'T', accent = { 0.88, 0.84, 0.72, 1.00 } },
    command     = { family = 'command',     mark = 'diamond', accent = { 0.76, 0.70, 0.54, 1.00 } },
};

local ICON_SELECTOR_TOKENS = {
    'cure',
    'holy',
    'buff',
    'status',
    'raise',
    'stealth',
    'white_magic',
    'black_magic',
    'debuff',
    'fire',
    'ice',
    'wind',
    'earth',
    'lightning',
    'water',
    'light',
    'dark',
    'ability',
    'song',
    'summon',
    'weapon',
    'ranged',
    'item',
    'target',
    'assist',
    'check',
    'chat',
    'rest',
    'test',
    'command',
};

local DEFAULT_CONFIG = {
    settings = {
        visible = true,
        display_mode = 'stacked',
        theme = 'ffxi',
        show_hotkeys = true,
        show_labels = true,
        show_recasts = true,
        show_counts = true,
        show_availability = true,
        weaponskill_tp_threshold = 1000,
        icon_style = 'auto',
        slot_size = 64,
        button_gap = 6,
        slot_glow_size = 100,
        slot_glow_opacity = 100,
        label_vertical_position = 100,
        show_bar_frame = false,
        row_gap = 6,
        window_x = 820,
        window_y = 760,
        block_native_macro_modifiers = true,
    },
    profiles = {
        DEFAULT = {
            base = {},
            ctrl = {},
            alt = {},
        },
    },
    bars = {
        base = {},
        ctrl = {},
        alt = {},
    },
};

local state = {
    config = DEFAULT_CONFIG,
    macro_overrides = { profiles = {} },
    visible = T{ true },
    config_visible = T{ false },
    config_save_message = nil,
    config_save_message_color = CONFIG_SUCCESS_COLOR,
    config_error = nil,
    profile = nil,
    display_mode_override = nil,
    slot_size_override = nil,
    button_gap_override = nil,
    slot_glow_size_override = nil,
    slot_glow_opacity_override = nil,
    label_vertical_position_override = nil,
    bar_frame_override = nil,
    bar_window_x = nil,
    bar_window_y = nil,
    bar_anchor_x = nil,
    bar_anchor_y = nil,
    bar_anchor_lock_x = nil,
    bar_anchor_lock_y = nil,
    bar_frame_offset_x = nil,
    bar_frame_offset_y = nil,
    bar_hidden_offset_x = FRAMELESS_WINDOW_PADDING,
    bar_hidden_offset_y = FRAMELESS_WINDOW_PADDING,
    recast_cache = {},
    recast_totals = {},
    item_source_cache = {},
    item_count_cache = {},
    visual = {
        row = 'base',
        changed_at = 0,
    },
    macro_editor = {
        visible = T{ false },
        profile_key = nil,
        group = nil,
        index = nil,
        source = nil,
        label_buffer = T{ '' },
        command_buffer = T{ '' },
        icon_buffer = T{ '' },
        preview_icon = nil,
        message = nil,
        message_color = CONFIG_SUCCESS_COLOR,
    },
};

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

local load_button_overrides = nil;
local load_visual_settings = nil;
local normalize_icon_token = nil;

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

local function refresh_profile_context()
    local config = state.config or DEFAULT_CONFIG;
    local profiles = config.profiles;
    local legacy_bars = config.bars;
    local job_id = current_main_job_id();
    local job_key = job_abbr(job_id);
    local bars = nil;
    local profile_key = nil;
    local source = 'built-in';

    bars, profile_key = get_profile_by_key(profiles, job_key);
    if (bars ~= nil) then
        source = 'job';
    end

    if (bars == nil) then
        bars, profile_key = get_profile_by_key(profiles, 'DEFAULT');
        if (bars ~= nil) then
            source = 'default';
        end
    end

    if (bars == nil and type(legacy_bars) == 'table') then
        bars = legacy_bars;
        profile_key = 'bars';
        source = 'legacy';
    end

    if (bars == nil) then
        bars = DEFAULT_CONFIG.profiles.DEFAULT;
        profile_key = 'DEFAULT';
    end

    state.profile = {
        bars = bars,
        key = profile_key or 'DEFAULT',
        job_id = job_id,
        job_key = job_key,
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
        if (load_visual_settings ~= nil) then
            load_visual_settings();
        end
        state.visible[1] = true;
        state.profile = nil;
        state.display_mode_override = nil;
        state.slot_size_override = nil;
        state.button_gap_override = nil;
        state.slot_glow_size_override = nil;
        state.slot_glow_opacity_override = nil;
        state.label_vertical_position_override = nil;
        state.bar_frame_override = nil;
        state.bar_window_x = tonumber(state.config.settings.window_x) or DEFAULT_CONFIG.settings.window_x;
        state.bar_window_y = tonumber(state.config.settings.window_y) or DEFAULT_CONFIG.settings.window_y;
        state.bar_anchor_x = DEFAULT_CONFIG.settings.window_x;
        state.bar_anchor_y = DEFAULT_CONFIG.settings.window_y;
        state.bar_anchor_lock_x = nil;
        state.bar_anchor_lock_y = nil;
        state.bar_frame_offset_x = nil;
        state.bar_frame_offset_y = nil;
        state.bar_hidden_offset_x = FRAMELESS_WINDOW_PADDING;
        state.bar_hidden_offset_y = FRAMELESS_WINDOW_PADDING;
        state.recast_cache = {};
        state.recast_totals = {};
        state.item_source_cache = {};
        state.item_count_cache = {};
        if (load_button_overrides ~= nil) then
            load_button_overrides();
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

    if (load_visual_settings ~= nil) then
        load_visual_settings();
    end

    state.visible[1] = (state.config.settings.visible ~= false);
    state.profile = nil;
    state.display_mode_override = nil;
    state.slot_size_override = nil;
    state.button_gap_override = nil;
    state.slot_glow_size_override = nil;
    state.slot_glow_opacity_override = nil;
    state.label_vertical_position_override = nil;
    state.bar_frame_override = nil;
    state.bar_window_x = tonumber(state.config.settings.window_x) or DEFAULT_CONFIG.settings.window_x;
    state.bar_window_y = tonumber(state.config.settings.window_y) or DEFAULT_CONFIG.settings.window_y;
    state.bar_anchor_x = state.bar_window_x;
    state.bar_anchor_y = state.bar_window_y;
    state.bar_anchor_lock_x = nil;
    state.bar_anchor_lock_y = nil;
    state.bar_frame_offset_x = nil;
    state.bar_frame_offset_y = nil;
    state.bar_hidden_offset_x = FRAMELESS_WINDOW_PADDING;
    state.bar_hidden_offset_y = FRAMELESS_WINDOW_PADDING;
    state.recast_cache = {};
    state.recast_totals = {};
    state.item_source_cache = {};
    state.item_count_cache = {};
    if (load_button_overrides ~= nil) then
        load_button_overrides();
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

local function should_block_native_modifier(e)
    local settings = state.config.settings or {};
    if (settings.block_native_macro_modifiers == false) then
        return false;
    end

    return input_is_closed() and (e.wparam == VK.CONTROL or e.wparam == VK.ALT);
end

local function clear_directinput_modifier_state(e)
    local settings = state.config.settings or {};
    if (settings.block_native_macro_modifiers == false or not input_is_closed() or e.data_raw == nil) then
        return;
    end

    local keyptr = ffi.cast('uint8_t*', e.data_raw);
    for _, scancode in ipairs(DIK_BLOCKED_MODIFIERS) do
        keyptr[scancode] = 0;
    end
end

local function active_group()
    local ctrl = key_down(VK.CONTROL);
    local alt = key_down(VK.ALT);

    if (ctrl and not alt) then return 'ctrl'; end
    if (alt and not ctrl) then return 'alt'; end
    if (not ctrl and not alt) then return 'base'; end
    return nil;
end

local function normalize_display_mode(value)
    if (type(value) ~= 'string') then
        return nil;
    end

    local mode = value:lower():gsub('%s+', '');
    if (mode == 'stacked' or mode == 'single') then
        return mode;
    end

    return nil;
end

local function configured_display_mode()
    local settings = state.config.settings or {};
    local mode = normalize_display_mode(settings.display_mode);
    if (mode ~= nil) then
        return mode, 'config';
    end

    return DEFAULT_CONFIG.settings.display_mode, 'default';
end

local function display_mode()
    if (state.display_mode_override ~= nil) then
        return state.display_mode_override;
    end

    return configured_display_mode();
end

local function display_mode_source()
    if (state.display_mode_override ~= nil) then
        return 'runtime';
    end

    local _, source = configured_display_mode();
    return source;
end

local function normalize_slot_size(value)
    local size = tonumber(value);
    if (size == nil) then
        return nil;
    end

    size = math.floor(size + 0.5);
    if (size < SLOT_SIZE_MIN) then
        return SLOT_SIZE_MIN;
    end
    if (size > SLOT_SIZE_MAX) then
        return SLOT_SIZE_MAX;
    end

    return size;
end

local function slot_size()
    if (state.slot_size_override ~= nil) then
        return state.slot_size_override;
    end

    local settings = state.config.settings or {};
    return normalize_slot_size(settings.slot_size) or DEFAULT_CONFIG.settings.slot_size;
end

local function slot_size_source()
    if (state.slot_size_override ~= nil) then
        return 'runtime';
    end

    local settings = state.config.settings or {};
    if (normalize_slot_size(settings.slot_size) ~= nil) then
        return 'config';
    end

    return 'default';
end

local function normalize_button_gap(value)
    local gap = tonumber(value);
    if (gap == nil) then
        return nil;
    end

    gap = math.floor(gap + 0.5);
    if (gap < BUTTON_GAP_MIN) then
        return BUTTON_GAP_MIN;
    end
    if (gap > BUTTON_GAP_MAX) then
        return BUTTON_GAP_MAX;
    end

    return gap;
end

local function configured_button_gap()
    local settings = state.config.settings or {};
    local gap = normalize_button_gap(settings.button_gap);
    if (gap ~= nil) then
        return gap, 'config';
    end

    gap = normalize_button_gap(settings.slot_gap);
    if (gap ~= nil) then
        return gap, 'legacy';
    end

    return DEFAULT_CONFIG.settings.button_gap, 'default';
end

local function button_gap()
    if (state.button_gap_override ~= nil) then
        return state.button_gap_override;
    end

    local gap = configured_button_gap();
    return gap;
end

local function button_gap_source()
    if (state.button_gap_override ~= nil) then
        return 'runtime';
    end

    local _, source = configured_button_gap();
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
    return normalize_percent(value, SLOT_GLOW_SIZE_MIN, SLOT_GLOW_SIZE_MAX);
end

local function normalize_slot_glow_opacity(value)
    return normalize_percent(value, SLOT_GLOW_OPACITY_MIN, SLOT_GLOW_OPACITY_MAX);
end

local function slot_glow_size()
    if (state.slot_glow_size_override ~= nil) then
        return state.slot_glow_size_override;
    end

    local settings = state.config.settings or {};
    return normalize_slot_glow_size(settings.slot_glow_size) or DEFAULT_CONFIG.settings.slot_glow_size;
end

local function slot_glow_size_source()
    if (state.slot_glow_size_override ~= nil) then
        return 'runtime';
    end

    local settings = state.config.settings or {};
    if (normalize_slot_glow_size(settings.slot_glow_size) ~= nil) then
        return 'config';
    end

    return 'default';
end

local function slot_glow_opacity()
    if (state.slot_glow_opacity_override ~= nil) then
        return state.slot_glow_opacity_override;
    end

    local settings = state.config.settings or {};
    return normalize_slot_glow_opacity(settings.slot_glow_opacity) or DEFAULT_CONFIG.settings.slot_glow_opacity;
end

local function slot_glow_opacity_source()
    if (state.slot_glow_opacity_override ~= nil) then
        return 'runtime';
    end

    local settings = state.config.settings or {};
    if (normalize_slot_glow_opacity(settings.slot_glow_opacity) ~= nil) then
        return 'config';
    end

    return 'default';
end

local function slot_glow_scale()
    return slot_glow_size() / 100.0;
end

local function slot_glow_alpha_scale()
    return slot_glow_opacity() / 100.0;
end

local function normalize_label_vertical_position(value)
    return normalize_percent(value, LABEL_VERTICAL_POSITION_MIN, LABEL_VERTICAL_POSITION_MAX);
end

local function label_vertical_position()
    if (state.label_vertical_position_override ~= nil) then
        return state.label_vertical_position_override;
    end

    local settings = state.config.settings or {};
    return normalize_label_vertical_position(settings.label_vertical_position) or DEFAULT_CONFIG.settings.label_vertical_position;
end

local function label_vertical_position_source()
    if (state.label_vertical_position_override ~= nil) then
        return 'runtime';
    end

    local settings = state.config.settings or {};
    if (normalize_label_vertical_position(settings.label_vertical_position) ~= nil) then
        return 'config';
    end

    return 'default';
end

local function configured_bar_frame_visible()
    local settings = state.config.settings or {};
    if (settings.show_bar_frame ~= nil) then
        return settings.show_bar_frame ~= false, 'config';
    end

    return DEFAULT_CONFIG.settings.show_bar_frame ~= false, 'default';
end

local function bar_frame_visible()
    if (state.bar_frame_override ~= nil) then
        return state.bar_frame_override == true;
    end

    local visible = configured_bar_frame_visible();
    return visible;
end

local function bar_frame_source()
    if (state.bar_frame_override ~= nil) then
        return 'runtime';
    end

    local _, source = configured_bar_frame_visible();
    return source;
end

local function bar_window_position(settings)
    local x = tonumber(state.bar_anchor_x) or tonumber(settings.window_x) or DEFAULT_CONFIG.settings.window_x;
    local y = tonumber(state.bar_anchor_y) or tonumber(settings.window_y) or DEFAULT_CONFIG.settings.window_y;
    return math.floor(x + 0.5), math.floor(y + 0.5);
end

local function estimated_frame_offset()
    local style = safe_read(function () return imgui.GetStyle(); end, nil);
    local pad_x = 8;
    local pad_y = 8;
    local title_h = 22;

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

    return pad_x + 52, pad_y + title_h;
end

local function frameless_window_padding()
    return math.max(FRAMELESS_WINDOW_PADDING, math.ceil((3 * slot_glow_scale()) + 1));
end

local function bar_window_offset(show_frame)
    if (show_frame) then
        local fallback_x, fallback_y = estimated_frame_offset();
        return tonumber(state.bar_frame_offset_x) or fallback_x, tonumber(state.bar_frame_offset_y) or fallback_y;
    end

    local pad = frameless_window_padding();
    return pad, pad;
end

local function lock_bar_anchor()
    local settings = state.config.settings or {};
    local anchor_x, anchor_y = bar_window_position(settings);
    state.bar_anchor_lock_x = anchor_x;
    state.bar_anchor_lock_y = anchor_y;
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
    local text = tostring(value):gsub('\\', '\\\\'):gsub("'", "\\'");
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
    return {
        display_mode = display_mode(),
        slot_size = slot_size(),
        button_gap = button_gap(),
        slot_glow_size = slot_glow_size(),
        slot_glow_opacity = slot_glow_opacity(),
        label_vertical_position = label_vertical_position(),
        show_bar_frame = bar_frame_visible(),
        window_x = window_x,
        window_y = window_y,
    };
end

local function apply_visual_settings(settings)
    if (type(settings) ~= 'table') then
        return;
    end

    if (type(state.config.settings) ~= 'table') then
        state.config.settings = {};
    end

    local target = state.config.settings;
    local mode = normalize_display_mode(settings.display_mode);
    local size = normalize_slot_size(settings.slot_size);
    local gap = normalize_button_gap(settings.button_gap);
    local glow_size = normalize_slot_glow_size(settings.slot_glow_size);
    local glow_opacity = normalize_slot_glow_opacity(settings.slot_glow_opacity);
    local label_position = normalize_label_vertical_position(settings.label_vertical_position);
    local window_x = tonumber(settings.window_x);
    local window_y = tonumber(settings.window_y);

    if (mode ~= nil) then target.display_mode = mode; end
    if (size ~= nil) then target.slot_size = size; end
    if (gap ~= nil) then target.button_gap = gap; end
    if (glow_size ~= nil) then target.slot_glow_size = glow_size; end
    if (glow_opacity ~= nil) then target.slot_glow_opacity = glow_opacity; end
    if (label_position ~= nil) then target.label_vertical_position = label_position; end
    if (settings.show_bar_frame ~= nil) then target.show_bar_frame = settings.show_bar_frame ~= false; end
    if (window_x ~= nil) then target.window_x = math.floor(window_x + 0.5); end
    if (window_y ~= nil) then target.window_y = math.floor(window_y + 0.5); end
end

local function serialize_visual_settings(settings)
    local lines = {
        '-- Generated by AshitaBars. Runtime visual settings are stored here.',
        '-- This file lives outside the addon folder so installs do not reset placement or sizing.',
        'return {',
        '    settings = {',
        ('        display_mode = %s,'):fmt(lua_string_literal(settings.display_mode)),
        ('        slot_size = %d,'):fmt(settings.slot_size),
        ('        button_gap = %d,'):fmt(settings.button_gap),
        ('        slot_glow_size = %d,'):fmt(settings.slot_glow_size),
        ('        slot_glow_opacity = %d,'):fmt(settings.slot_glow_opacity),
        ('        label_vertical_position = %d,'):fmt(settings.label_vertical_position),
        ('        show_bar_frame = %s,'):fmt(tostring(settings.show_bar_frame)),
        ('        window_x = %d,'):fmt(settings.window_x),
        ('        window_y = %d,'):fmt(settings.window_y),
        '    },',
        '}',
        '',
    };

    return table.concat(lines, '\n');
end

load_visual_settings = function ()
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
    state.bar_frame_override = nil;
    state.bar_window_x = settings.window_x;
    state.bar_window_y = settings.window_y;
    state.bar_anchor_x = settings.window_x;
    state.bar_anchor_y = settings.window_y;

    return true, 'Saved visual settings to config/addons/ashitabars/visual_settings.lua.';
end

local function sanitize_slot_override(slot)
    if (type(slot) ~= 'table') then
        return nil;
    end

    local sanitized = {};
    if (slot.label ~= nil) then
        sanitized.label = trim_one_line(slot.label, MACRO_LABEL_MAX);
    end
    if (slot.command ~= nil) then
        sanitized.command = trim_one_line(slot.command, MACRO_COMMAND_MAX);
    end
    if (slot.icon ~= nil) then
        sanitized.icon = trim_one_line(slot.icon, MACRO_ICON_MAX);
    end

    if (sanitized.label == nil and sanitized.command == nil and sanitized.icon == nil) then
        return nil;
    end

    return sanitized;
end

local function sanitize_button_overrides(overrides)
    local sanitized = { profiles = {} };
    if (type(overrides) ~= 'table' or type(overrides.profiles) ~= 'table') then
        return sanitized;
    end

    for profile_key, profile in pairs(overrides.profiles) do
        local normalized_profile_key = normalize_profile_key(tostring(profile_key));
        if (normalized_profile_key ~= nil and type(profile) == 'table') then
            local sanitized_profile = {};
            for _, row in ipairs(ROWS) do
                local row_overrides = profile[row.id];
                if (type(row_overrides) == 'table') then
                    local sanitized_row = {};
                    for index = 1, 10 do
                        local slot = sanitize_slot_override(row_overrides[index]);
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

    return sanitized;
end

load_button_overrides = function ()
    local path = button_overrides_file_path();
    if (path == nil or ashita == nil or ashita.fs == nil or not ashita.fs.exists(path)) then
        state.macro_overrides = { profiles = {} };
        return true;
    end

    local chunk, load_err = loadfile(path);
    if (chunk == nil) then
        state.macro_overrides = { profiles = {} };
        log_warn(('Button overrides ignored: %s'):fmt(tostring(load_err)));
        return false;
    end

    local ok, overrides = pcall(chunk);
    if (not ok or type(overrides) ~= 'table') then
        state.macro_overrides = { profiles = {} };
        log_warn(('Button overrides ignored: %s'):fmt(tostring(overrides)));
        return false;
    end

    state.macro_overrides = sanitize_button_overrides(overrides);
    return true;
end

local function serialize_button_overrides()
    local lines = {
        '-- Generated by AshitaBars. Runtime button edits are stored here.',
        '-- Each saved button still executes at most one allowed slash command.',
        'return {',
        '    profiles = {',
    };

    local profiles = (state.macro_overrides and state.macro_overrides.profiles) or {};
    for _, profile_key in ipairs(sorted_keys(profiles)) do
        local profile = profiles[profile_key];
        if (type(profile) == 'table') then
            table.insert(lines, ('        [%s] = {'):fmt(lua_string_literal(profile_key)));
            for _, row in ipairs(ROWS) do
                local row_overrides = profile[row.id];
                if (type(row_overrides) == 'table' and next(row_overrides) ~= nil) then
                    table.insert(lines, ('            %s = {'):fmt(row.id));
                    for index = 1, 10 do
                        local slot = row_overrides[index];
                        if (type(slot) == 'table') then
                            local parts = {};
                            if (slot.label ~= nil) then
                                table.insert(parts, ('label = %s'):fmt(lua_string_literal(slot.label)));
                            end
                            if (slot.icon ~= nil) then
                                table.insert(parts, ('icon = %s'):fmt(lua_string_literal(slot.icon)));
                            end
                            if (slot.command ~= nil) then
                                table.insert(parts, ('command = %s'):fmt(lua_string_literal(slot.command)));
                            end
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
            copied[key] = value;
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

    local key = normalize_profile_key(profile.key);
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

    local slot = copy_slot(base_slot);
    if (override.label ~= nil) then
        slot.label = override.label;
    end
    if (override.command ~= nil) then
        slot.command = override.command;
    end
    if (override.icon ~= nil) then
        slot.icon = override.icon;
    end

    if (next(slot) == nil) then
        return nil;
    end

    return slot;
end

local function apply_editor_preview(slot, profile_key, group, index)
    local editor = state.macro_editor;
    if (editor == nil or not editor.visible[1]) then
        return slot;
    end

    if (normalize_profile_key(profile_key) ~= normalize_profile_key(editor.profile_key) or editor.group ~= group or editor.index ~= index) then
        return slot;
    end

    local preview_icon = editor.preview_icon;
    if (preview_icon == nil) then
        preview_icon = trim_one_line(editor.icon_buffer[1], MACRO_ICON_MAX);
    end

    local preview_slot = copy_slot(slot);
    preview_slot.icon = preview_icon;
    return preview_slot;
end

local function visual_group()
    return active_group() or 'base';
end

local function row_transition_alpha(row_id, mode)
    if (state.visual == nil) then
        state.visual = { row = row_id, changed_at = os.clock() };
        return 0;
    end

    local now = os.clock();
    if (state.visual.row ~= row_id) then
        state.visual.row = row_id;
        state.visual.changed_at = now;
    end

    if (mode ~= 'single') then
        return 0;
    end

    local elapsed = now - (state.visual.changed_at or now);
    if (elapsed < 0 or elapsed >= ROW_TRANSITION_SECONDS) then
        return 0;
    end

    local progress = elapsed / ROW_TRANSITION_SECONDS;
    local remaining = 1.0 - progress;
    return remaining * remaining;
end

local function get_slot(group, index)
    local profile = state.profile or refresh_profile_context();
    local profile_key = editable_profile_key(profile);
    local slot = get_raw_config_slot(profile, group, index);
    local override = get_slot_override(profile_key, group, index);
    slot = apply_slot_override(slot, override);
    slot = apply_editor_preview(slot, profile_key, group, index);
    if (type(slot) ~= 'table') then
        return nil;
    end

    return slot;
end

local function allowed_command(command)
    if (type(command) ~= 'string') then return false; end
    local prefix = command:lower():match('^%s*(/%S+)');
    return prefix ~= nil and ALLOWED_PREFIXES[prefix] == true;
end

local function command_validation_error(command)
    if (type(command) ~= 'string' or command == '') then
        return nil;
    end

    if (not command:match('^%s*/')) then
        return 'Command must start with an allowed slash command.';
    end

    if (not allowed_command(command)) then
        return 'Unsupported command prefix.';
    end

    return nil;
end

local function execute_slot(group, index, source)
    refresh_profile_context();

    local slot = get_slot(group, index);
    if (slot == nil or slot.command == nil or slot.command == '') then
        return false;
    end

    if (not allowed_command(slot.command)) then
        log_warn(('Rejected %s slot %s command from %s: unsupported command prefix.'):fmt(group, DIGIT_LABELS[index], source));
        return false;
    end

    AshitaCore:GetChatManager():QueueCommand(1, slot.command);
    return true;
end

local function prune_button_overrides()
    local overrides = state.macro_overrides or {};
    local profiles = overrides.profiles or {};
    for profile_key, profile in pairs(profiles) do
        if (type(profile) ~= 'table') then
            profiles[profile_key] = nil;
        else
            for _, row in ipairs(ROWS) do
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

local function set_slot_override(profile_key, group, index, label, command, icon)
    profile_key = normalize_profile_key(profile_key) or 'DEFAULT';
    if (not valid_row_id(group) or type(index) ~= 'number' or index < 1 or index > 10) then
        return false, 'Invalid button selection.';
    end

    if (type(state.macro_overrides) ~= 'table') then
        state.macro_overrides = { profiles = {} };
    end
    if (type(state.macro_overrides.profiles) ~= 'table') then
        state.macro_overrides.profiles = {};
    end

    local profiles = state.macro_overrides.profiles;
    profiles[profile_key] = profiles[profile_key] or {};
    profiles[profile_key][group] = profiles[profile_key][group] or {};

    local slot = {
        label = trim_one_line(label, MACRO_LABEL_MAX),
        command = trim_one_line(command, MACRO_COMMAND_MAX),
    };
    slot.icon = trim_one_line(icon, MACRO_ICON_MAX);

    profiles[profile_key][group][index] = slot;
    prune_button_overrides();
    return true;
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

local function editor_row_label(group)
    local row = ROW_BY_ID[group];
    if (row == nil) then
        return group or 'base';
    end

    return row.label;
end

local function open_macro_editor(row, index)
    local profile = refresh_profile_context();
    local profile_key = editable_profile_key(profile);
    local slot = get_slot(row.id, index) or {};
    local override = get_slot_override(profile_key, row.id, index);
    local editor = state.macro_editor;

    editor.visible[1] = true;
    editor.profile_key = profile_key;
    editor.group = row.id;
    editor.index = index;
    editor.source = (override ~= nil) and 'saved edit' or profile.source;
    buffer_set(editor.label_buffer, slot.label or '');
    buffer_set(editor.command_buffer, slot.command or '');
    buffer_set(editor.icon_buffer, slot.icon or '');
    editor.message = nil;
end

local function save_macro_editor(clear_slot)
    local editor = state.macro_editor;
    if (editor.profile_key == nil or editor.group == nil or editor.index == nil) then
        editor.message = 'No button selected.';
        editor.message_color = CONFIG_ERROR_COLOR;
        return false;
    end

    local label = clear_slot and '' or trim_one_line(editor.label_buffer[1], MACRO_LABEL_MAX);
    local command = clear_slot and '' or trim_one_line(editor.command_buffer[1], MACRO_COMMAND_MAX);
    local icon = clear_slot and '' or trim_one_line(editor.icon_buffer[1], MACRO_ICON_MAX);
    local validation_error = command_validation_error(command);
    if (validation_error ~= nil) then
        editor.message = validation_error;
        editor.message_color = CONFIG_ERROR_COLOR;
        return false;
    end

    local set_ok, set_err = set_slot_override(editor.profile_key, editor.group, editor.index, label, command, icon);
    if (not set_ok) then
        editor.message = set_err;
        editor.message_color = CONFIG_ERROR_COLOR;
        return false;
    end

    local save_ok, save_message = save_button_overrides();
    if (not save_ok) then
        editor.message = save_message;
        editor.message_color = CONFIG_ERROR_COLOR;
        log_warn(save_message);
        return false;
    end

    buffer_set(editor.label_buffer, label);
    buffer_set(editor.command_buffer, command);
    buffer_set(editor.icon_buffer, icon);
    editor.source = 'saved edit';
    editor.message = clear_slot and 'Cleared.' or 'Saved.';
    editor.message_color = CONFIG_SUCCESS_COLOR;
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
        editor.message_color = CONFIG_ERROR_COLOR;
        log_warn(save_message);
        return false;
    end

    local profile = refresh_profile_context();
    local slot = get_raw_config_slot(profile, editor.group, editor.index) or {};
    buffer_set(editor.label_buffer, slot.label or '');
    buffer_set(editor.command_buffer, slot.command or '');
    buffer_set(editor.icon_buffer, slot.icon or '');
    editor.source = profile.source;
    editor.message = 'Reset to config.';
    editor.message_color = CONFIG_SUCCESS_COLOR;
    log_info(save_message);
    return true;
end

local function icon_selector_label(token)
    token = trim_one_line(token, MACRO_ICON_MAX);
    if (token == '') then
        return 'Auto (infer from command)';
    end

    local normalized = normalize_icon_token(token);
    if (normalized ~= nil and ICON_DEFS[normalized] ~= nil) then
        return normalized;
    end

    return 'Custom: ' .. token;
end

local function render_icon_selector(editor)
    local current_icon = trim_one_line(editor.icon_buffer[1], MACRO_ICON_MAX);
    local normalized_current = normalize_icon_token(current_icon);
    local selected_label = icon_selector_label(current_icon);

    editor.preview_icon = nil;
    imgui.PushItemWidth(360);
    if (imgui.BeginCombo('Icon Preset##ashitabars_button_icon_select', selected_label, ImGuiComboFlags_None)) then
        if (imgui.Selectable('Auto (infer from command)', current_icon == '')) then
            buffer_set(editor.icon_buffer, '');
        end
        if (imgui.IsItemHovered()) then
            editor.preview_icon = '';
        end

        for _, token in ipairs(ICON_SELECTOR_TOKENS) do
            local selected = normalized_current == token;
            if (imgui.Selectable(token, selected)) then
                buffer_set(editor.icon_buffer, token);
            end
            if (imgui.IsItemHovered()) then
                editor.preview_icon = token;
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

local function command_recast_action(command)
    local prefix, name = command_prefix_and_name(command);
    if (prefix == nil) then
        return nil, nil;
    end

    local kind = nil;
    if (prefix == '/ma' or prefix == '/magic') then
        kind = 'spell';
    elseif (prefix == '/ja' or prefix == '/jobability') then
        kind = 'ability';
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

    local seconds = seconds_from_recast_timer(timer);
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

local function item_count(item_id)
    item_id = tonumber(item_id);
    if (item_id == nil or item_id <= 0) then
        return nil;
    end

    local now = os.clock();
    local cached = state.item_count_cache[item_id];
    if (cached ~= nil and (now - cached.at) <= ITEM_COUNT_CACHE_SECONDS) then
        return cached.count;
    end

    local inventory = safe_read(function ()
        return AshitaCore:GetMemoryManager():GetInventory();
    end, nil);
    if (inventory == nil) then
        return nil;
    end

    local total = 0;
    for _, container_id in ipairs(ITEM_COUNT_CONTAINER_IDS) do
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

    local prefix = command_prefix_and_name(slot.command);
    local state_info = {
        available = true,
    };

    if (prefix == '/item') then
        local source = item_source_for_command(slot.command);
        if (source ~= nil) then
            local count = item_count(source.id);
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

normalize_icon_token = function (value)
    if (type(value) ~= 'string') then
        return nil;
    end

    local token = value:lower():gsub('[%s%-]+', '_'):gsub('[^%w_]+', ''):gsub('_+', '_'):gsub('^_', ''):gsub('_$', '');
    if (token == '') then
        return nil;
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

    if (prefix == '/ma' or prefix == '/magic') then
        for _, hint in ipairs(WHITE_MAGIC_HINTS) do
            if (command:find(hint, 1, true) ~= nil) then
                return 'white_magic';
            end
        end
        return 'black_magic';
    end

    if (prefix == '/ja' or prefix == '/jobability') then
        return 'ability';
    end
    if (prefix == '/ws' or prefix == '/weaponskill' or prefix == '/ra' or prefix == '/range' or prefix == '/shoot') then
        return 'weapon';
    end
    if (prefix == '/item' or prefix == '/heal') then
        return 'item';
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

    if (prefix == '/heal') then return 'rest'; end
    if (prefix == '/target' or prefix == '/attack') then return 'target'; end
    if (prefix == '/assist') then return 'assist'; end
    if (prefix == '/check') then return 'check'; end
    if (prefix == '/item') then return 'item'; end
    if (prefix == '/ja' or prefix == '/jobability') then return 'ability'; end
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
    local normalized = normalize_icon_token(token);
    if (normalized == nil) then
        return nil, nil;
    end

    local known = ICON_DEFS[normalized];
    if (known ~= nil) then
        return known, normalized;
    end

    return {
        family = family,
        mark = 'text',
        text = normalized:sub(1, 2):upper(),
        accent = COMMAND_THEME[family] or COMMAND_THEME.command,
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

    local explicit = normalize_icon_token(slot.icon);
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

local function draw_icon_mark(draw_list, icon_def, x, y, size, fallback_color)
    if (icon_def == nil) then
        return;
    end

    local color = icon_def.accent or fallback_color or COMMAND_THEME.command;
    local col = color_u32(color_with_alpha(color, 0.92));
    local dim = color_u32(color_with_alpha(color, 0.48));
    local mark = icon_def.mark or 'diamond';
    local thick = math.max(2, math.floor(size * 0.18));

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

    local theme = current_theme();
    local tw, th = imgui.CalcTextSize(hotkey);
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
    draw_text_shadow(draw_list, bx1 + pad_x, by1 + 1, text_color, hotkey);
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
    local color = hovered and EDIT_HANDLE_HOVER_COLOR or EDIT_HANDLE_COLOR;
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

    draw_list:AddRectFilled({ ix1, iy1 }, { ix2, iy2 }, color_u32({ icon_color[1] * 0.20, icon_color[2] * 0.20, icon_color[3] * 0.20, 0.96 }), 2.5);
    draw_list:AddRectFilled({ ix1 + 1, iy1 + 1 }, { ix2 - 1, iy1 + ((iy2 - iy1) * 0.45) }, color_u32(color_with_alpha(theme.icon_highlight or { 1.00, 1.00, 1.00, 1.00 }, 0.05)), 2.0);
    draw_icon_mark(draw_list, icon_def, x + size * 0.50, y + size * 0.48, size * 0.22, icon_color);
    draw_list:AddRect({ x, y }, { x + size, y + size }, color_u32(color_with_alpha(theme.hover_border or { 1.00, 0.96, 0.72, 0.52 }, 0.45)), 4.0, ImDrawCornerFlags_All, 1.0);
end

local function render_editor_icon_preview(editor)
    local preview_size = 54;
    local x, y = imgui.GetCursorScreenPos();
    local slot = {
        command = trim_one_line(editor.command_buffer[1], MACRO_COMMAND_MAX),
        icon = editor.preview_icon ~= nil and editor.preview_icon or trim_one_line(editor.icon_buffer[1], MACRO_ICON_MAX),
    };

    if (slot.command == '') then
        slot.command = '/echo AshitaBars icon preview';
    end

    imgui.InvisibleButton('##ashitabars_button_icon_preview', { preview_size, preview_size });
    draw_icon_preview_tile(imgui.GetWindowDrawList(), x, y, preview_size, slot);
end

local function render_slot_button(row, index, slot_size, active, transition_alpha, capture_anchor, show_frame)
    local slot = get_slot(row.id, index);
    local has_command = slot ~= nil and slot.command ~= nil and slot.command ~= '';
    local command_supported = has_command and allowed_command(slot.command);
    local clicked = imgui.InvisibleButton(('##ashitabars_%s_%d'):fmt(row.id, index), { slot_size, slot_size });
    local hovered = imgui.IsItemHovered();
    local pressed = imgui.IsItemActive();
    local x, y = imgui.GetItemRectMin();
    local draw_list = imgui.GetWindowDrawList();
    local edit_hovered = show_frame and hovered and edit_handle_hovered(x, y, slot_size);
    local edit_clicked = clicked and edit_hovered;
    if (capture_anchor) then
        local window_x, window_y = imgui.GetWindowPos();
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

    local theme = current_theme();
    local row_color = ROW_THEME[row.id] or ROW_THEME.base;
    local family = command_family(slot);
    local icon_def = slot_icon(slot, family);
    local icon_family = (icon_def and icon_def.family) or family;
    local icon_color = (icon_def and icon_def.accent) or COMMAND_THEME[icon_family] or COMMAND_THEME.command;
    local recast_info = slot_recast(slot);
    local visual_state = slot_visual_state(slot);
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
        draw_icon_mark(draw_list, icon_def, rx + slot_size * 0.50, ry + slot_size * 0.48, slot_size * 0.21, draw_icon_color);
    else
        draw_list:AddRectFilled({ ix1, iy1 }, { ix2, iy2 }, color_u32(theme.empty_bg or { 0.03, 0.03, 0.04, 0.82 }), 2.5);
        draw_empty_slot_overlay(draw_list, rx, ry, slot_size);
    end

    if (has_command and command_supported and visual_state ~= nil and visual_state.available == false) then
        draw_availability_overlay(draw_list, ix1, iy1, ix2, iy2, visual_state, recast_info == nil);
    end

    if (has_command and command_supported and recast_info ~= nil) then
        draw_recast_overlay(draw_list, ix1, iy1, ix2, iy2, recast_info);
    end

    if (setting_enabled('show_hotkeys', true)) then
        local hotkey = row.keyPrefix .. DIGIT_LABELS[index];
        local key_color = command_supported and row_color or (has_command and { 1.00, 0.30, 0.24, 1.00 } or { 0.54, 0.54, 0.58, 1.00 });
        draw_hotkey_badge(draw_list, rx, ry, slot_size, hotkey, key_color, not has_command);
    end

    if (setting_enabled('show_labels', true) and has_command and slot.label ~= nil) then
        draw_label_overlay(draw_list, rx, ry, slot_size, slot.label, command_supported and draw_icon_color or { 1.00, 0.30, 0.24, 1.00 });
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
        open_macro_editor(row, index);
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
    imgui.BeginTooltip();
    imgui.Text(row.label .. ' ' .. DIGIT_LABELS[index]);
    if (slot and slot.label) then
        imgui.Text(slot.label);
    end
    if (icon_token ~= nil) then
        imgui.Text('icon: ' .. icon_token);
    end
    if (slot and slot.command) then
        local recast_info = slot_recast(slot);
        local visual_state = slot_visual_state(slot);
        imgui.Text(slot.command);
        if (visual_state ~= nil and visual_state.count ~= nil) then
            imgui.Text(('count: %d'):fmt(visual_state.count));
        end
        if (visual_state ~= nil and visual_state.available == false and visual_state.reason ~= nil) then
            imgui.Text('availability: ' .. visual_state.reason);
        end
        if (recast_info ~= nil) then
            imgui.Text(('recast: %s'):fmt(recast_info.label));
        end
        if (not allowed_command(slot.command)) then
            imgui.Text('unsupported command prefix');
        end
    else
        imgui.Text('(empty)');
    end
    imgui.EndTooltip();
end

local function render_row(row, active, transition_alpha, show_row_label, capture_anchor, show_frame)
    local current_slot_size = slot_size();
    local gap = button_gap();

    if (show_row_label) then
        imgui.Text(row.label);
        imgui.SameLine(52, gap);
    end

    for index = 1, 10 do
        if (index > 1) then
            imgui.SameLine(0, gap);
        end

        local should_capture_anchor = capture_anchor and index == 1;
        if (render_slot_button(row, index, current_slot_size, active, transition_alpha, should_capture_anchor, show_frame)) then
            execute_slot(row.id, index, 'click');
        end
        render_tooltip(row, index);
    end
end

local function render_bars()
    if (not state.visible[1]) then
        return;
    end

    local profile = refresh_profile_context();
    local settings = state.config.settings or {};
    local current_slot_size = slot_size();
    local gap = button_gap();
    local row_gap = tonumber(settings.row_gap) or DEFAULT_CONFIG.settings.row_gap;
    local mode = display_mode();
    local theme = current_theme();
    local show_frame = bar_frame_visible();
    local row_count = (mode == 'single') and 1 or #ROWS;
    local label_width = show_frame and 58 or 0;
    local content_width = label_width + (current_slot_size * 10) + (gap * 9);
    local content_height = (current_slot_size * row_count) + (row_gap * (row_count - 1));
    local hidden_pad = show_frame and 0 or frameless_window_padding();
    local width = content_width + (show_frame and 20 or (hidden_pad * 2));
    local height = content_height + (show_frame and 48 or (hidden_pad * 2));
    local active = active_group();
    local visual = visual_group();
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

    local window_title = ('AshitaBars [%s %s]###AshitaBars'):fmt(profile.key or 'DEFAULT', mode);
    if (imgui.Begin(window_title, state.visible, window_flags)) then
        state.bar_window_x, state.bar_window_y = imgui.GetWindowPos();

        if (state.config_error ~= nil) then
            imgui.Text('Config load failed. Using defaults.');
        end

        if (mode == 'single') then
            local row = ROW_BY_ID[visual] or ROW_BY_ID.base;
            local transition_alpha = row_transition_alpha(row.id, mode);
            render_row(row, active == row.id, transition_alpha, show_frame, true, show_frame);
        else
            row_transition_alpha(visual, mode);
            for i, row in ipairs(ROWS) do
                render_row(row, active == row.id, 0, show_frame, i == 1, show_frame);
                if (i < #ROWS) then
                    imgui.Dummy({ 1, row_gap });
                end
            end
        end

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
end

local function render_runtime_int_control(label, id, value, source, min_value, max_value, apply_value, unit)
    unit = unit or 'px';
    local text = (unit == '%') and ('%d%% (%s)'):fmt(value, source) or ('%d %s (%s)'):fmt(value, unit, source);
    local slider_format = (unit == '%') and '%d%%' or ('%d ' .. unit);

    imgui.TextColored(CONFIG_HEADER_COLOR, label);
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

local function render_config_window()
    if (not state.config_visible[1]) then
        return;
    end

    imgui.SetNextWindowSize({ 440, 0 }, ImGuiCond_FirstUseEver);
    if (imgui.Begin(('AshitaBars v%s Configuration###AshitaBarsConfig'):fmt(addon.version), state.config_visible, ImGuiWindowFlags_AlwaysAutoResize)) then
        if (imgui.BeginTabBar('##ashitabars_config_tabs', ImGuiTabBarFlags_NoCloseWithMiddleMouseButton)) then
            if (imgui.BeginTabItem('General##ashitabars_config_general', nil)) then
                imgui.TextColored(CONFIG_HEADER_COLOR, 'Display Mode');
                local mode = display_mode();
                if (imgui.RadioButton('Single##ashitabars_config_mode_single', mode == 'single')) then
                    state.display_mode_override = 'single';
                end
                imgui.SameLine(0, 8);
                if (imgui.RadioButton('Stacked##ashitabars_config_mode_stacked', mode == 'stacked')) then
                    state.display_mode_override = 'stacked';
                end
                imgui.SameLine(0, 8);
                imgui.Text(('(%s)'):fmt(display_mode_source()));

                imgui.Separator();
                imgui.TextColored(CONFIG_HEADER_COLOR, 'Button Layout');
                render_runtime_int_control('Button Size', 'slot_size', slot_size(), slot_size_source(), SLOT_SIZE_MIN, SLOT_SIZE_MAX, function (value)
                    state.slot_size_override = normalize_slot_size(value);
                end);

                render_runtime_int_control('Button Gap', 'button_gap', button_gap(), button_gap_source(), BUTTON_GAP_MIN, BUTTON_GAP_MAX, function (value)
                    state.button_gap_override = normalize_button_gap(value);
                end);

                imgui.Separator();
                imgui.TextColored(CONFIG_HEADER_COLOR, 'Button Text');
                render_runtime_int_control('Label Vertical', 'label_vertical_position', label_vertical_position(), label_vertical_position_source(), LABEL_VERTICAL_POSITION_MIN, LABEL_VERTICAL_POSITION_MAX, function (value)
                    state.label_vertical_position_override = normalize_label_vertical_position(value);
                end, '%');

                imgui.Separator();
                imgui.TextColored(CONFIG_HEADER_COLOR, 'Button Glow');
                render_runtime_int_control('Glow Size', 'slot_glow_size', slot_glow_size(), slot_glow_size_source(), SLOT_GLOW_SIZE_MIN, SLOT_GLOW_SIZE_MAX, function (value)
                    state.slot_glow_size_override = normalize_slot_glow_size(value);
                end, '%');

                render_runtime_int_control('Glow Opacity', 'slot_glow_opacity', slot_glow_opacity(), slot_glow_opacity_source(), SLOT_GLOW_OPACITY_MIN, SLOT_GLOW_OPACITY_MAX, function (value)
                    state.slot_glow_opacity_override = normalize_slot_glow_opacity(value);
                end, '%');

                imgui.Separator();
                imgui.TextColored(CONFIG_HEADER_COLOR, 'Bar Window');
                local show_frame = bar_frame_visible();
                if (imgui.Checkbox('Show Bar Frame##ashitabars_config_show_bar_frame', { show_frame })) then
                    lock_bar_anchor();
                    state.bar_frame_override = not show_frame;
                end
                imgui.SameLine(0, 8);
                imgui.Text(('(%s)'):fmt(bar_frame_source()));

                imgui.Separator();
                if (imgui.Button('Save##ashitabars_config_save')) then
                    local ok, message = save_runtime_settings();
                    state.config_save_message = ok and 'Saved.' or 'Save failed. See chat log.';
                    state.config_save_message_color = ok and CONFIG_SUCCESS_COLOR or CONFIG_ERROR_COLOR;
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

                imgui.EndTabItem();
            end
            imgui.EndTabBar();
        end
    end
    imgui.End();
end

local function render_macro_editor_window()
    local editor = state.macro_editor;
    if (editor == nil or not editor.visible[1]) then
        return;
    end

    local row_label = editor_row_label(editor.group);
    local digit = DIGIT_LABELS[editor.index or 1] or '?';
    local title = ('AshitaBars Button Editor###AshitaBarsButtonEditor');
    imgui.SetNextWindowSize({ 520, 0 }, ImGuiCond_FirstUseEver);
    if (imgui.Begin(title, editor.visible, ImGuiWindowFlags_AlwaysAutoResize)) then
        imgui.TextColored(CONFIG_HEADER_COLOR, ('%s %s %s'):fmt(editor.profile_key or 'DEFAULT', row_label, digit));
        imgui.SameLine(0, 8);
        imgui.Text(('(%s)'):fmt(editor.source or 'config'));

        imgui.Separator();
        imgui.PushItemWidth(360);
        imgui.InputText('Label##ashitabars_button_label', editor.label_buffer, MACRO_LABEL_MAX);
        imgui.InputText('Command##ashitabars_button_command', editor.command_buffer, MACRO_COMMAND_MAX);
        imgui.PopItemWidth();
        render_icon_selector(editor);
        imgui.SameLine(0, 10);
        render_editor_icon_preview(editor);

        local command = trim_one_line(editor.command_buffer[1], MACRO_COMMAND_MAX);
        local validation_error = command_validation_error(command);
        if (validation_error ~= nil) then
            imgui.TextColored(CONFIG_ERROR_COLOR, validation_error);
        end

        imgui.Separator();
        if (imgui.Button('Save##ashitabars_button_save')) then
            save_macro_editor(false);
        end
        imgui.SameLine(0, 8);
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
            imgui.TextColored(editor.message_color or CONFIG_SUCCESS_COLOR, editor.message);
        end
    end
    imgui.End();
end

local function print_help()
    log_info('/ashitabars toggle - Show or hide the bars.');
    log_info('/ashitabars show - Show the bars.');
    log_info('/ashitabars hide - Hide the bars.');
    log_info('/ashitabars config - Toggle the runtime configuration window.');
    log_info('/ashitabars mode single|stacked|config - Change the display mode until config reload.');
    log_info(('/ashitabars size %d-%d|config - Change button size until config reload.'):fmt(SLOT_SIZE_MIN, SLOT_SIZE_MAX));
    log_info(('/ashitabars gap %d-%d|config - Change button spacing until config reload.'):fmt(BUTTON_GAP_MIN, BUTTON_GAP_MAX));
    log_info('/ashitabars reload - Reload ashitabars_config.lua.');
    log_info('/ashitabars status - Print input status.');
end

ashita.events.register('load', 'load_cb', function ()
    load_config();
    log_info('Loaded. Uses key events, not /bind. Number keys pass through while chat/input is open.');
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
        state.visible[1] = not state.visible[1];
        log_info(state.visible[1] and 'Shown.' or 'Hidden.');
    elseif (sub == 'show') then
        state.visible[1] = true;
        log_info('Shown.');
    elseif (sub == 'hide') then
        state.visible[1] = false;
        log_info('Hidden.');
    elseif (sub == 'config' or sub == 'settings') then
        state.config_visible[1] = not state.config_visible[1];
        log_info(state.config_visible[1] and 'Configuration shown.' or 'Configuration hidden.');
    elseif (sub == 'mode') then
        local requested = (#args >= 3) and args[3]:lower() or nil;
        if (requested == nil) then
            log_info(('Display mode is %s (%s).'):fmt(display_mode(), display_mode_source()));
        elseif (requested == 'config' or requested == 'default') then
            state.display_mode_override = nil;
            log_info(('Display mode override cleared. Using %s (%s).'):fmt(display_mode(), display_mode_source()));
        else
            local mode = normalize_display_mode(requested);
            if (mode == nil) then
                log_warn('Usage: /ashitabars mode single|stacked|config');
            else
                state.display_mode_override = mode;
                log_info(('Display mode set to %s (runtime).'):fmt(mode));
            end
        end
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
                log_warn(('/ashitabars size expects %d-%d or config.'):fmt(SLOT_SIZE_MIN, SLOT_SIZE_MAX));
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
                log_warn(('/ashitabars gap expects %d-%d or config.'):fmt(BUTTON_GAP_MIN, BUTTON_GAP_MAX));
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
        local profile = refresh_profile_context();
        local active = active_group();
        local _, theme_key = current_theme();
        local window_x, window_y = bar_window_position(settings);
        log_info(('visible=%s input=0x%02X active=%s displayMode=%s displayModeSource=%s visualRow=%s slotSize=%d slotSizeSource=%s buttonGap=%d buttonGapSource=%s labelY=%d labelYSource=%s glowSize=%d glowSizeSource=%s glowOpacity=%d glowOpacitySource=%s barFrame=%s barFrameSource=%s barAnchor=%d,%d theme=%s iconStyle=%s showRecasts=%s showCounts=%s showAvailability=%s wsTp=%d job=%s profile=%s source=%s blockModifiers=%s'):fmt(
            tostring(state.visible[1]),
            input_state,
            active or 'none',
            display_mode(),
            display_mode_source(),
            visual_group(),
            slot_size(),
            slot_size_source(),
            button_gap(),
            button_gap_source(),
            label_vertical_position(),
            label_vertical_position_source(),
            slot_glow_size(),
            slot_glow_size_source(),
            slot_glow_opacity(),
            slot_glow_opacity_source(),
            tostring(bar_frame_visible()),
            bar_frame_source(),
            window_x,
            window_y,
            theme_key,
            icon_style(),
            tostring(setting_enabled('show_recasts', true)),
            tostring(setting_enabled('show_counts', true)),
            tostring(setting_enabled('show_availability', true)),
            setting_number('weaponskill_tp_threshold', 1000),
            profile.job_key or 'unknown',
            tostring(profile.key),
            tostring(profile.source),
            tostring(settings.block_native_macro_modifiers ~= false)));
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

    if (should_block_native_modifier(e)) then
        e.blocked = true;
        return;
    end

    if (not is_initial_keydown(e)) then
        return;
    end

    if (imgui_wants_keyboard()) then
        return;
    end

    local index = VK.DIGITS[e.wparam];
    if (index == nil) then
        return;
    end

    if (not input_is_closed()) then
        return;
    end

    if (key_down(VK.SHIFT)) then
        return;
    end

    local group = active_group();
    if (group == nil) then
        return;
    end

    execute_slot(group, index, 'key');
    e.blocked = true;
end);

ashita.events.register('d3d_present', 'present_cb', function ()
    render_bars();
    render_config_window();
    render_macro_editor_window();
end);
