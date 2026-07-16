addon.name      = 'ashitabars';
addon.author    = 'Eflfk';
addon.version   = '0.1.0';
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

local KEY_UP_MASK       = bit.lshift(0x8000, 16);
local KEY_WAS_DOWN_MASK = bit.lshift(0x4000, 16);
local DIGIT_LABELS      = { '1', '2', '3', '4', '5', '6', '7', '8', '9', '0' };
local ROWS              = {
    { id = 'base', label = '1-0',  keyPrefix = ''  },
    { id = 'ctrl', label = 'Ctrl', keyPrefix = 'C' },
    { id = 'alt',  label = 'Alt',  keyPrefix = 'A' },
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

local DEFAULT_CONFIG = {
    settings = {
        visible = true,
        slot_size = 48,
        slot_gap = 4,
        row_gap = 6,
        window_x = 820,
        window_y = 760,
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
};

local function log_info(message)
    print(chat.header(addon.name):append(chat.message(message)));
end

local function log_warn(message)
    print(chat.header(addon.name):append(chat.warning(message)));
end

local function load_config()
    package.loaded.ashitabars_config = nil;

    local ok, config = pcall(require, 'ashitabars_config');
    if (not ok or type(config) ~= 'table') then
        state.config_error = tostring(config);
        state.config = DEFAULT_CONFIG;
        state.visible[1] = true;
        return;
    end

    state.config_error = nil;
    state.config = config;
    if (type(state.config.settings) ~= 'table') then
        state.config.settings = DEFAULT_CONFIG.settings;
    end
    if (type(state.config.bars) ~= 'table') then
        state.config.bars = DEFAULT_CONFIG.bars;
    end

    state.visible[1] = (state.config.settings.visible ~= false);
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

local function active_group()
    local ctrl = key_down(VK.CONTROL);
    local alt = key_down(VK.ALT);

    if (ctrl and not alt) then return 'ctrl'; end
    if (alt and not ctrl) then return 'alt'; end
    if (not ctrl and not alt) then return 'base'; end
    return nil;
end

local function get_slot(group, index)
    local bars = state.config.bars or {};
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

local function short_label(text, fallback)
    if (type(text) ~= 'string' or text == '') then
        return fallback;
    end

    if (#text <= 8) then
        return text;
    end

    return text:sub(1, 7) .. '.';
end

local function slot_button_label(row, index)
    local key = row.keyPrefix .. DIGIT_LABELS[index];
    local slot = get_slot(row.id, index);
    local label = slot and short_label(slot.label, '') or '';

    if (label == '') then
        return key;
    end

    return key .. '\n' .. label;
end

local function push_slot_colors(row_id, has_command, is_active)
    if (is_active) then
        imgui.PushStyleColor(ImGuiCol_Button,        { 0.22, 0.42, 0.58, 0.95 });
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.30, 0.54, 0.74, 1.00 });
        imgui.PushStyleColor(ImGuiCol_ButtonActive,  { 0.36, 0.62, 0.82, 1.00 });
    elseif (has_command) then
        imgui.PushStyleColor(ImGuiCol_Button,        { 0.10, 0.10, 0.12, 0.92 });
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.18, 0.20, 0.24, 0.96 });
        imgui.PushStyleColor(ImGuiCol_ButtonActive,  { 0.22, 0.26, 0.32, 1.00 });
    else
        imgui.PushStyleColor(ImGuiCol_Button,        { 0.05, 0.05, 0.06, 0.74 });
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.08, 0.08, 0.10, 0.78 });
        imgui.PushStyleColor(ImGuiCol_ButtonActive,  { 0.10, 0.10, 0.12, 0.84 });
    end

    if (row_id == 'ctrl') then
        imgui.PushStyleColor(ImGuiCol_Text, { 0.78, 0.93, 1.00, 1.00 });
    elseif (row_id == 'alt') then
        imgui.PushStyleColor(ImGuiCol_Text, { 1.00, 0.88, 0.66, 1.00 });
    else
        imgui.PushStyleColor(ImGuiCol_Text, { 0.94, 0.94, 0.96, 1.00 });
    end
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

        local slot = get_slot(row.id, index);
        local has_command = slot ~= nil and slot.command ~= nil and slot.command ~= '';
        push_slot_colors(row.id, has_command, active);
        local label = slot_button_label(row, index) .. ('##ashitabars_%s_%d'):fmt(row.id, index);
        if (imgui.Button(label, { slot_size, slot_size })) then
            execute_slot(row.id, index, 'click');
        end
        imgui.PopStyleColor(4);
        render_tooltip(row, index);
    end
end

local function render_bars()
    if (not state.visible[1]) then
        return;
    end

    local settings = state.config.settings or {};
    local slot_size = tonumber(settings.slot_size) or DEFAULT_CONFIG.settings.slot_size;
    local gap = tonumber(settings.slot_gap) or DEFAULT_CONFIG.settings.slot_gap;
    local row_gap = tonumber(settings.row_gap) or DEFAULT_CONFIG.settings.row_gap;
    local width = 58 + (slot_size * 10) + (gap * 9) + 20;
    local height = (slot_size * 3) + (row_gap * 2) + 48;
    local active = active_group();

    imgui.SetNextWindowPos({ tonumber(settings.window_x) or 820, tonumber(settings.window_y) or 760 }, ImGuiCond_FirstUseEver);
    imgui.SetNextWindowSize({ width, height }, ImGuiCond_FirstUseEver);
    imgui.PushStyleColor(ImGuiCol_WindowBg, { 0.03, 0.03, 0.04, 0.78 });
    imgui.PushStyleColor(ImGuiCol_Border,   { 0.38, 0.38, 0.42, 0.90 });

    if (imgui.Begin('AshitaBars', state.visible, bit.bor(ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoCollapse))) then
        if (state.config_error ~= nil) then
            imgui.Text('Config load failed. Using defaults.');
        end

        for i, row in ipairs(ROWS) do
            render_row(row, active == row.id);
            if (i < #ROWS) then
                imgui.Dummy({ 1, row_gap });
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
        log_info(('visible=%s input=0x%02X active=%s'):fmt(tostring(state.visible[1]), input_state, tostring(active_group())));
    else
        print_help();
    end

    e.blocked = true;
end);

ashita.events.register('key', 'key_cb', function (e)
    if (e.blocked or not is_initial_keydown(e)) then
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
