addon.name      = 'ashitabars';
addon.author    = 'Eflfk';
addon.version   = '0.10.0';
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

local THEMES = {
    ffxi = {
        window_bg = { 0.025, 0.022, 0.018, 0.72 },
        window_border = { 0.58, 0.44, 0.20, 0.88 },
        slot_shadow = { 0.00, 0.00, 0.00, 0.58 },
        slot_bg = { 0.035, 0.030, 0.028, 0.98 },
        slot_border = { 0.02, 0.02, 0.02, 1.00 },
        bevel_light = { 0.88, 0.78, 0.48, 0.46 },
        bevel_mid = { 0.86, 0.76, 0.48, 0.34 },
        bevel_shadow = { 0.00, 0.00, 0.00, 0.72 },
        icon_border = { 1.00, 0.86, 0.54, 1.00 },
        icon_highlight = { 1.00, 1.00, 1.00, 1.00 },
        empty_bg = { 0.03, 0.03, 0.04, 0.82 },
        empty_line = { 0.36, 0.36, 0.40, 0.40 },
        empty_dim = { 0.22, 0.22, 0.25, 0.44 },
        empty_crystal = { 0.50, 0.48, 0.42, 1.00 },
        hotkey_bg = { 0.00, 0.00, 0.00, 1.00 },
        hotkey_dim_text = { 0.62, 0.62, 0.66, 0.88 },
        label_bg = { 0.00, 0.00, 0.00, 0.70 },
        label_text = { 0.96, 0.93, 0.84, 1.00 },
        text_shadow = { 0.00, 0.00, 0.00, 0.90 },
        unsupported = { 1.00, 0.24, 0.18, 1.00 },
        hover_border = { 1.00, 0.96, 0.72, 0.52 },
    },
    jeuno = {
        window_bg = { 0.020, 0.026, 0.034, 0.74 },
        window_border = { 0.45, 0.62, 0.76, 0.86 },
        slot_shadow = { 0.00, 0.00, 0.00, 0.60 },
        slot_bg = { 0.030, 0.036, 0.046, 0.98 },
        slot_border = { 0.01, 0.02, 0.03, 1.00 },
        bevel_light = { 0.58, 0.74, 0.88, 0.42 },
        bevel_mid = { 0.40, 0.56, 0.70, 0.34 },
        bevel_shadow = { 0.00, 0.00, 0.00, 0.74 },
        icon_border = { 0.70, 0.86, 1.00, 1.00 },
        icon_highlight = { 1.00, 1.00, 1.00, 1.00 },
        empty_bg = { 0.025, 0.030, 0.040, 0.84 },
        empty_line = { 0.34, 0.42, 0.50, 0.40 },
        empty_dim = { 0.18, 0.24, 0.30, 0.46 },
        empty_crystal = { 0.38, 0.48, 0.56, 1.00 },
        hotkey_bg = { 0.00, 0.00, 0.00, 1.00 },
        hotkey_dim_text = { 0.60, 0.66, 0.72, 0.88 },
        label_bg = { 0.00, 0.00, 0.00, 0.70 },
        label_text = { 0.88, 0.94, 1.00, 1.00 },
        text_shadow = { 0.00, 0.00, 0.00, 0.90 },
        unsupported = { 1.00, 0.24, 0.18, 1.00 },
        hover_border = { 0.80, 0.94, 1.00, 0.54 },
    },
    sandoria = {
        window_bg = { 0.034, 0.018, 0.018, 0.74 },
        window_border = { 0.72, 0.42, 0.30, 0.88 },
        slot_shadow = { 0.00, 0.00, 0.00, 0.60 },
        slot_bg = { 0.040, 0.026, 0.022, 0.98 },
        slot_border = { 0.02, 0.01, 0.01, 1.00 },
        bevel_light = { 0.92, 0.62, 0.42, 0.44 },
        bevel_mid = { 0.74, 0.42, 0.32, 0.34 },
        bevel_shadow = { 0.00, 0.00, 0.00, 0.74 },
        icon_border = { 1.00, 0.68, 0.48, 1.00 },
        icon_highlight = { 1.00, 1.00, 1.00, 1.00 },
        empty_bg = { 0.04, 0.025, 0.026, 0.84 },
        empty_line = { 0.48, 0.34, 0.34, 0.40 },
        empty_dim = { 0.28, 0.18, 0.18, 0.46 },
        empty_crystal = { 0.58, 0.42, 0.36, 1.00 },
        hotkey_bg = { 0.00, 0.00, 0.00, 1.00 },
        hotkey_dim_text = { 0.70, 0.60, 0.58, 0.88 },
        label_bg = { 0.00, 0.00, 0.00, 0.70 },
        label_text = { 1.00, 0.90, 0.82, 1.00 },
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

local DEFAULT_CONFIG = {
    settings = {
        visible = true,
        display_mode = 'stacked',
        theme = 'ffxi',
        show_hotkeys = true,
        show_labels = true,
        icon_style = 'auto',
        slot_size = 48,
        slot_gap = 4,
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
    visible = T{ true },
    config_error = nil,
    profile = nil,
    display_mode_override = nil,
    visual = {
        row = 'base',
        changed_at = 0,
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
        state.visible[1] = true;
        state.profile = nil;
        state.display_mode_override = nil;
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

    state.visible[1] = (state.config.settings.visible ~= false);
    state.profile = nil;
    state.display_mode_override = nil;
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
    local bars = profile.bars or {};
    local row = bars[group] or {};
    local slot = row[index];
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

local function setting_enabled(name, fallback)
    local settings = state.config.settings or {};
    if (settings[name] == nil) then
        return fallback;
    end

    return settings[name] ~= false;
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

local function normalize_icon_token(value)
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

    local strip_h = math.max(14, th + 5);
    local y1 = y + slot_size - strip_h - 3;
    local y2 = y + slot_size - 3;

    draw_list:AddRectFilled({ x + 3, y1 }, { x + slot_size - 3, y2 }, color_u32(theme.label_bg or { 0.00, 0.00, 0.00, 0.70 }), 1.5);
    draw_list:AddLine({ x + 5, y1 + 1 }, { x + slot_size - 5, y1 + 1 }, color_u32(color_with_alpha(color, 0.36)), 1.0);
    draw_text_shadow(draw_list, x + math.floor((slot_size - tw) * 0.5), y1 + math.floor((strip_h - th) * 0.5), theme.label_text or { 0.96, 0.93, 0.84, 1.00 }, fitted);
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

local function render_slot_button(row, index, slot_size, active, transition_alpha)
    local slot = get_slot(row.id, index);
    local has_command = slot ~= nil and slot.command ~= nil and slot.command ~= '';
    local command_supported = has_command and allowed_command(slot.command);
    local clicked = imgui.InvisibleButton(('##ashitabars_%s_%d'):fmt(row.id, index), { slot_size, slot_size });
    local hovered = imgui.IsItemHovered();
    local pressed = imgui.IsItemActive();
    local x, y = imgui.GetItemRectMin();
    local draw_list = imgui.GetWindowDrawList();
    local theme = current_theme();
    local row_color = ROW_THEME[row.id] or ROW_THEME.base;
    local family = command_family(slot);
    local icon_def = slot_icon(slot, family);
    local icon_family = (icon_def and icon_def.family) or family;
    local icon_color = (icon_def and icon_def.accent) or COMMAND_THEME[icon_family] or COMMAND_THEME.command;
    local nudge = pressed and 1 or 0;
    local rx = x + nudge;
    local ry = y + nudge;
    local rr = 4.0;
    local inset = math.max(5, math.floor(slot_size * 0.12));
    local ix1 = rx + inset;
    local iy1 = ry + inset;
    local ix2 = rx + slot_size - inset;
    local iy2 = ry + slot_size - inset;

    draw_list:AddRectFilled({ x + 2, y + 3 }, { x + slot_size + 2, y + slot_size + 3 }, color_u32(theme.slot_shadow or { 0.00, 0.00, 0.00, 0.58 }), rr);

    if (active or hovered) then
        local glow_alpha = active and 0.82 or 0.42;
        draw_list:AddRect({ rx - 2, ry - 2 }, { rx + slot_size + 2, ry + slot_size + 2 }, color_u32(color_with_alpha(row_color, glow_alpha)), rr + 1, ImDrawCornerFlags_All, active and 2.0 or 1.4);
    end

    draw_list:AddRectFilled({ rx, ry }, { rx + slot_size, ry + slot_size }, color_u32(theme.slot_bg or { 0.035, 0.030, 0.028, 0.98 }), rr);
    draw_list:AddRect({ rx, ry }, { rx + slot_size, ry + slot_size }, color_u32(theme.slot_border or { 0.02, 0.02, 0.02, 1.00 }), rr, ImDrawCornerFlags_All, 2.0);

    local flash = tonumber(transition_alpha) or 0;
    if (flash > 0) then
        draw_list:AddRectFilled({ rx + 2, ry + 2 }, { rx + slot_size - 2, ry + slot_size - 2 }, color_u32(color_with_alpha(row_color, flash * 0.11)), rr - 1);
        draw_list:AddRect({ rx - 3, ry - 3 }, { rx + slot_size + 3, ry + slot_size + 3 }, color_u32(color_with_alpha(row_color, flash * 0.76)), rr + 2, ImDrawCornerFlags_All, 2.2);
        draw_list:AddRect({ rx + 4, ry + 4 }, { rx + slot_size - 4, ry + slot_size - 4 }, color_u32(color_with_alpha(row_color, flash * 0.32)), 2.0, ImDrawCornerFlags_All, 1.0);
    end

    draw_list:AddLine({ rx + 2, ry + 2 }, { rx + slot_size - 3, ry + 2 }, color_u32(theme.bevel_light or { 0.88, 0.78, 0.48, 0.46 }), 1.0);
    draw_list:AddLine({ rx + 2, ry + 2 }, { rx + 2, ry + slot_size - 3 }, color_u32(theme.bevel_mid or { 0.86, 0.76, 0.48, 0.34 }), 1.0);
    draw_list:AddLine({ rx + slot_size - 2, ry + 3 }, { rx + slot_size - 2, ry + slot_size - 2 }, color_u32(theme.bevel_shadow or { 0.00, 0.00, 0.00, 0.72 }), 1.0);
    draw_list:AddLine({ rx + 3, ry + slot_size - 2 }, { rx + slot_size - 2, ry + slot_size - 2 }, color_u32(theme.bevel_shadow or { 0.00, 0.00, 0.00, 0.72 }), 1.0);

    if (has_command) then
        local icon_alpha = command_supported and 0.96 or 0.64;
        draw_list:AddRectFilled({ ix1, iy1 }, { ix2, iy2 }, color_u32({ icon_color[1] * 0.20, icon_color[2] * 0.20, icon_color[3] * 0.20, icon_alpha }), 2.5);
        local highlight = theme.icon_highlight or { 1.00, 1.00, 1.00, 1.00 };
        draw_list:AddRectFilled({ ix1 + 1, iy1 + 1 }, { ix2 - 1, iy1 + ((iy2 - iy1) * 0.45) }, color_u32(color_with_alpha(highlight, command_supported and 0.05 or 0.02)), 2.0);
        draw_icon_mark(draw_list, icon_def, rx + slot_size * 0.50, ry + slot_size * 0.48, slot_size * 0.21, icon_color);
    else
        draw_list:AddRectFilled({ ix1, iy1 }, { ix2, iy2 }, color_u32(theme.empty_bg or { 0.03, 0.03, 0.04, 0.82 }), 2.5);
        draw_empty_slot_overlay(draw_list, rx, ry, slot_size);
    end

    draw_list:AddRect({ ix1, iy1 }, { ix2, iy2 }, color_u32(color_with_alpha(theme.icon_border or { 1.00, 0.86, 0.54, 1.00 }, has_command and 0.35 or 0.18)), 2.5, ImDrawCornerFlags_All, 1.0);

    if (setting_enabled('show_hotkeys', true)) then
        local hotkey = row.keyPrefix .. DIGIT_LABELS[index];
        local key_color = command_supported and row_color or (has_command and { 1.00, 0.30, 0.24, 1.00 } or { 0.54, 0.54, 0.58, 1.00 });
        draw_hotkey_badge(draw_list, rx, ry, slot_size, hotkey, key_color, not has_command);
    end

    if (setting_enabled('show_labels', true) and has_command and slot.label ~= nil) then
        draw_label_overlay(draw_list, rx, ry, slot_size, slot.label, command_supported and icon_color or { 1.00, 0.30, 0.24, 1.00 });
    end

    if (has_command and not command_supported) then
        draw_unsupported_overlay(draw_list, rx, ry, slot_size);
    end

    if (hovered) then
        draw_list:AddRect({ rx + 1, ry + 1 }, { rx + slot_size - 1, ry + slot_size - 1 }, color_u32(theme.hover_border or { 1.00, 0.96, 0.72, 0.52 }), rr, ImDrawCornerFlags_All, 1.3);
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
        imgui.Text(slot.command);
        if (not allowed_command(slot.command)) then
            imgui.Text('unsupported command prefix');
        end
    else
        imgui.Text('(empty)');
    end
    imgui.EndTooltip();
end

local function render_row(row, active, transition_alpha)
    local settings = state.config.settings or {};
    local slot_size = tonumber(settings.slot_size) or DEFAULT_CONFIG.settings.slot_size;
    local gap = tonumber(settings.slot_gap) or DEFAULT_CONFIG.settings.slot_gap;

    imgui.Text(row.label);
    imgui.SameLine(52, gap);

    for index = 1, 10 do
        if (index > 1) then
            imgui.SameLine(0, gap);
        end

        if (render_slot_button(row, index, slot_size, active, transition_alpha)) then
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
    local slot_size = tonumber(settings.slot_size) or DEFAULT_CONFIG.settings.slot_size;
    local gap = tonumber(settings.slot_gap) or DEFAULT_CONFIG.settings.slot_gap;
    local row_gap = tonumber(settings.row_gap) or DEFAULT_CONFIG.settings.row_gap;
    local mode = display_mode();
    local theme = current_theme();
    local row_count = (mode == 'single') and 1 or #ROWS;
    local width = 58 + (slot_size * 10) + (gap * 9) + 20;
    local height = (slot_size * row_count) + (row_gap * (row_count - 1)) + 48;
    local active = active_group();
    local visual = visual_group();

    imgui.SetNextWindowPos({ tonumber(settings.window_x) or 820, tonumber(settings.window_y) or 760 }, ImGuiCond_FirstUseEver);
    imgui.SetNextWindowSize({ width, height }, ImGuiCond_Always);
    imgui.PushStyleColor(ImGuiCol_WindowBg, theme.window_bg or { 0.025, 0.022, 0.018, 0.72 });
    imgui.PushStyleColor(ImGuiCol_Border,   theme.window_border or { 0.58, 0.44, 0.20, 0.88 });

    local window_title = ('AshitaBars [%s %s]###AshitaBars'):fmt(profile.key or 'DEFAULT', mode);
    if (imgui.Begin(window_title, state.visible, bit.bor(ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoCollapse))) then
        if (state.config_error ~= nil) then
            imgui.Text('Config load failed. Using defaults.');
        end

        if (mode == 'single') then
            local row = ROW_BY_ID[visual] or ROW_BY_ID.base;
            local transition_alpha = row_transition_alpha(row.id, mode);
            render_row(row, active == row.id, transition_alpha);
        else
            row_transition_alpha(visual, mode);
            for i, row in ipairs(ROWS) do
                render_row(row, active == row.id, 0);
                if (i < #ROWS) then
                    imgui.Dummy({ 1, row_gap });
                end
            end
        end
    end
    imgui.End();
    imgui.PopStyleColor(2);
end

local function print_help()
    log_info('/ashitabars toggle - Show or hide the bars.');
    log_info('/ashitabars show - Show the bars.');
    log_info('/ashitabars hide - Hide the bars.');
    log_info('/ashitabars mode single|stacked|config - Change the display mode until config reload.');
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
    elseif (sub == 'reload') then
        load_config();
        log_info('Config reloaded.');
    elseif (sub == 'status') then
        local input_state = AshitaCore:GetChatManager():IsInputOpen();
        local settings = state.config.settings or {};
        local profile = refresh_profile_context();
        local active = active_group();
        local _, theme_key = current_theme();
        log_info(('visible=%s input=0x%02X active=%s displayMode=%s displayModeSource=%s visualRow=%s theme=%s iconStyle=%s job=%s profile=%s source=%s blockModifiers=%s'):fmt(
            tostring(state.visible[1]),
            input_state,
            active or 'none',
            display_mode(),
            display_mode_source(),
            visual_group(),
            theme_key,
            icon_style(),
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
end);
