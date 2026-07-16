addon.name      = 'ashitabars';
addon.author    = 'Eflfk';
addon.version   = '0.4.0';
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

local DEFAULT_CONFIG = {
    settings = {
        visible = true,
        display_mode = 'stacked',
        show_hotkeys = true,
        show_labels = true,
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

local function display_mode()
    local settings = state.config.settings or {};
    local mode = settings.display_mode;
    if (type(mode) == 'string') then
        mode = mode:lower():gsub('%s+', '');
        if (mode == 'stacked' or mode == 'single') then
            return mode;
        end
    end

    return DEFAULT_CONFIG.settings.display_mode;
end

local function visual_group()
    return active_group() or 'base';
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

    draw_list:AddText({ x + 1, y + 1 }, color_u32({ 0.00, 0.00, 0.00, 0.88 }), text);
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

local function render_slot_button(row, index, slot_size, active)
    local slot = get_slot(row.id, index);
    local has_command = slot ~= nil and slot.command ~= nil and slot.command ~= '';
    local clicked = imgui.InvisibleButton(('##ashitabars_%s_%d'):fmt(row.id, index), { slot_size, slot_size });
    local hovered = imgui.IsItemHovered();
    local pressed = imgui.IsItemActive();
    local x, y = imgui.GetItemRectMin();
    local draw_list = imgui.GetWindowDrawList();
    local row_color = ROW_THEME[row.id] or ROW_THEME.base;
    local family = command_family(slot);
    local icon_color = COMMAND_THEME[family] or COMMAND_THEME.command;
    local nudge = pressed and 1 or 0;
    local rx = x + nudge;
    local ry = y + nudge;
    local rr = 4.0;
    local inset = math.max(5, math.floor(slot_size * 0.12));
    local ix1 = rx + inset;
    local iy1 = ry + inset;
    local ix2 = rx + slot_size - inset;
    local iy2 = ry + slot_size - inset;

    draw_list:AddRectFilled({ x + 2, y + 3 }, { x + slot_size + 2, y + slot_size + 3 }, color_u32({ 0.00, 0.00, 0.00, 0.58 }), rr);

    if (active or hovered) then
        local glow_alpha = active and 0.82 or 0.42;
        draw_list:AddRect({ rx - 2, ry - 2 }, { rx + slot_size + 2, ry + slot_size + 2 }, color_u32(color_with_alpha(row_color, glow_alpha)), rr + 1, ImDrawCornerFlags_All, active and 2.0 or 1.4);
    end

    draw_list:AddRectFilled({ rx, ry }, { rx + slot_size, ry + slot_size }, color_u32({ 0.035, 0.030, 0.028, 0.98 }), rr);
    draw_list:AddRect({ rx, ry }, { rx + slot_size, ry + slot_size }, color_u32({ 0.02, 0.02, 0.02, 1.00 }), rr, ImDrawCornerFlags_All, 2.0);
    draw_list:AddLine({ rx + 2, ry + 2 }, { rx + slot_size - 3, ry + 2 }, color_u32({ 0.88, 0.78, 0.48, 0.46 }), 1.0);
    draw_list:AddLine({ rx + 2, ry + 2 }, { rx + 2, ry + slot_size - 3 }, color_u32({ 0.86, 0.76, 0.48, 0.34 }), 1.0);
    draw_list:AddLine({ rx + slot_size - 2, ry + 3 }, { rx + slot_size - 2, ry + slot_size - 2 }, color_u32({ 0.00, 0.00, 0.00, 0.72 }), 1.0);
    draw_list:AddLine({ rx + 3, ry + slot_size - 2 }, { rx + slot_size - 2, ry + slot_size - 2 }, color_u32({ 0.00, 0.00, 0.00, 0.72 }), 1.0);

    if (has_command) then
        draw_list:AddRectFilled({ ix1, iy1 }, { ix2, iy2 }, color_u32({ icon_color[1] * 0.20, icon_color[2] * 0.20, icon_color[3] * 0.20, 0.96 }), 2.5);
        draw_list:AddRectFilled({ ix1 + 1, iy1 + 1 }, { ix2 - 1, iy1 + ((iy2 - iy1) * 0.45) }, color_u32({ 1.00, 1.00, 1.00, 0.05 }), 2.0);
        draw_crystal_mark(draw_list, rx + slot_size * 0.50, ry + slot_size * 0.48, slot_size * 0.21, icon_color, 0.86);
    else
        draw_list:AddRectFilled({ ix1, iy1 }, { ix2, iy2 }, color_u32({ 0.03, 0.03, 0.04, 0.82 }), 2.5);
        draw_list:AddLine({ ix1 + 5, iy1 + 5 }, { ix2 - 5, iy2 - 5 }, color_u32({ 0.32, 0.32, 0.36, 0.38 }), 1.0);
        draw_list:AddLine({ ix2 - 5, iy1 + 5 }, { ix1 + 5, iy2 - 5 }, color_u32({ 0.32, 0.32, 0.36, 0.30 }), 1.0);
    end

    draw_list:AddRect({ ix1, iy1 }, { ix2, iy2 }, color_u32({ 1.00, 0.86, 0.54, has_command and 0.35 or 0.18 }), 2.5, ImDrawCornerFlags_All, 1.0);

    if (setting_enabled('show_hotkeys', true)) then
        local hotkey = row.keyPrefix .. DIGIT_LABELS[index];
        local key_color = has_command and color_with_alpha(row_color, 0.96) or { 0.54, 0.54, 0.58, 0.80 };
        draw_text_shadow(draw_list, rx + 5, ry + 3, key_color, hotkey);
    end

    if (setting_enabled('show_labels', true) and has_command and slot.label ~= nil) then
        local label = fit_text(slot.label, slot_size - 8);
        if (label ~= '') then
            local tw, th = imgui.CalcTextSize(label);
            local label_y = ry + slot_size - th - 4;
            draw_list:AddRectFilled({ rx + 3, label_y - 1 }, { rx + slot_size - 3, ry + slot_size - 3 }, color_u32({ 0.00, 0.00, 0.00, 0.58 }), 1.5);
            draw_text_shadow(draw_list, rx + math.floor((slot_size - tw) * 0.5), label_y, { 0.96, 0.93, 0.84, 1.00 }, label);
        end
    end

    if (hovered) then
        draw_list:AddRect({ rx + 1, ry + 1 }, { rx + slot_size - 1, ry + slot_size - 1 }, color_u32({ 1.00, 0.96, 0.72, 0.52 }), rr, ImDrawCornerFlags_All, 1.3);
    end

    return clicked;
end

local function render_tooltip(row, index)
    if (not imgui.IsItemHovered()) then
        return;
    end

    local slot = get_slot(row.id, index);
    imgui.BeginTooltip();
    imgui.Text(row.label .. ' ' .. DIGIT_LABELS[index]);
    if (slot and slot.label) then
        imgui.Text(slot.label);
    end
    if (slot and slot.command) then
        imgui.Text(slot.command);
    else
        imgui.Text('(empty)');
    end
    imgui.EndTooltip();
end

local function render_row(row, active)
    local settings = state.config.settings or {};
    local slot_size = tonumber(settings.slot_size) or DEFAULT_CONFIG.settings.slot_size;
    local gap = tonumber(settings.slot_gap) or DEFAULT_CONFIG.settings.slot_gap;

    imgui.Text(row.label);
    imgui.SameLine(52, gap);

    for index = 1, 10 do
        if (index > 1) then
            imgui.SameLine(0, gap);
        end

        if (render_slot_button(row, index, slot_size, active)) then
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
    local row_count = (mode == 'single') and 1 or #ROWS;
    local width = 58 + (slot_size * 10) + (gap * 9) + 20;
    local height = (slot_size * row_count) + (row_gap * (row_count - 1)) + 48;
    local active = active_group();
    local visual = visual_group();

    imgui.SetNextWindowPos({ tonumber(settings.window_x) or 820, tonumber(settings.window_y) or 760 }, ImGuiCond_FirstUseEver);
    imgui.SetNextWindowSize({ width, height }, ImGuiCond_Always);
    imgui.PushStyleColor(ImGuiCol_WindowBg, { 0.025, 0.022, 0.018, 0.72 });
    imgui.PushStyleColor(ImGuiCol_Border,   { 0.58, 0.44, 0.20, 0.88 });

    local window_title = ('AshitaBars [%s %s]###AshitaBars'):fmt(profile.key or 'DEFAULT', mode);
    if (imgui.Begin(window_title, state.visible, bit.bor(ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoCollapse))) then
        if (state.config_error ~= nil) then
            imgui.Text('Config load failed. Using defaults.');
        end

        if (mode == 'single') then
            local row = ROW_BY_ID[visual] or ROW_BY_ID.base;
            render_row(row, active == row.id);
        else
            for i, row in ipairs(ROWS) do
                render_row(row, active == row.id);
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
    elseif (sub == 'reload') then
        load_config();
        log_info('Config reloaded.');
    elseif (sub == 'status') then
        local input_state = AshitaCore:GetChatManager():IsInputOpen();
        local settings = state.config.settings or {};
        local profile = refresh_profile_context();
        local active = active_group();
        log_info(('visible=%s input=0x%02X active=%s displayMode=%s visualRow=%s job=%s profile=%s source=%s blockModifiers=%s'):fmt(
            tostring(state.visible[1]),
            input_state,
            active or 'none',
            display_mode(),
            visual_group(),
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
