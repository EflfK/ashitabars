local default_profile = {
    base = {
        [1]  = { label = 'One',   command = '/echo AshitaBars DEFAULT base 1' },
        [2]  = { label = 'Two',   command = '/echo AshitaBars DEFAULT base 2' },
        [3]  = { label = 'Three', command = '/echo AshitaBars DEFAULT base 3' },
        [4]  = { label = 'Four',  command = '/echo AshitaBars DEFAULT base 4' },
        [5]  = { label = 'Five',  command = '/echo AshitaBars DEFAULT base 5' },
        [6]  = { label = 'Six',   command = '/echo AshitaBars DEFAULT base 6' },
        [7]  = { label = 'Seven', command = '/echo AshitaBars DEFAULT base 7' },
        [8]  = { label = 'Eight', command = '/echo AshitaBars DEFAULT base 8' },
        [9]  = { label = 'Nine',  command = '/echo AshitaBars DEFAULT base 9' },
        [10] = { label = 'Zero',  command = '/echo AshitaBars DEFAULT base 0' },
    },

    ctrl = {
        [1]  = { label = 'C1', command = '/echo AshitaBars DEFAULT ctrl 1' },
        [2]  = { label = 'C2', command = '/echo AshitaBars DEFAULT ctrl 2' },
        [3]  = { label = 'C3', command = '/echo AshitaBars DEFAULT ctrl 3' },
        [4]  = { label = 'C4', command = '/echo AshitaBars DEFAULT ctrl 4' },
        [5]  = { label = 'C5', command = '/echo AshitaBars DEFAULT ctrl 5' },
        [6]  = { label = 'C6', command = '/echo AshitaBars DEFAULT ctrl 6' },
        [7]  = { label = 'C7', command = '/echo AshitaBars DEFAULT ctrl 7' },
        [8]  = { label = 'C8', command = '/echo AshitaBars DEFAULT ctrl 8' },
        [9]  = { label = 'C9', command = '/echo AshitaBars DEFAULT ctrl 9' },
        [10] = { label = 'C0', command = '/echo AshitaBars DEFAULT ctrl 0' },
    },

    alt = {
        [1]  = { label = 'A1', command = '/echo AshitaBars DEFAULT alt 1' },
        [2]  = { label = 'A2', command = '/echo AshitaBars DEFAULT alt 2' },
        [3]  = { label = 'A3', command = '/echo AshitaBars DEFAULT alt 3' },
        [4]  = { label = 'A4', command = '/echo AshitaBars DEFAULT alt 4' },
        [5]  = { label = 'A5', command = '/echo AshitaBars DEFAULT alt 5' },
        [6]  = { label = 'A6', command = '/echo AshitaBars DEFAULT alt 6' },
        [7]  = { label = 'A7', command = '/echo AshitaBars DEFAULT alt 7' },
        [8]  = { label = 'A8', command = '/echo AshitaBars DEFAULT alt 8' },
        [9]  = { label = 'A9', command = '/echo AshitaBars DEFAULT alt 9' },
        [10] = { label = 'A0', command = '/echo AshitaBars DEFAULT alt 0' },
    },

    click = {},
};

local whm_profile = {
    base = {
        [1]  = { label = 'Cure',    icon = 'cure',   command = '/ma "Cure" <stpt>' },
        [2]  = { label = 'CureMe',  icon = 'cure',   command = '/ma "Cure" <me>' },
        [3]  = { label = 'Dia',     icon = 'holy',   command = '/ma "Dia" <t>' },
        [4]  = { label = 'Banish',  icon = 'holy',   command = '/ma "Banish" <t>' },
        [5]  = { label = 'Poisona', icon = 'status', command = '/ma "Poisona" <stpc>' },
        [6]  = { label = 'Paralyn', icon = 'status', command = '/ma "Paralyna" <stpc>' },
        [7]  = { label = 'Protect', icon = 'buff',   command = '/ma "Protect" <me>' },
        [8]  = { label = 'Shell',   icon = 'buff',   command = '/ma "Shell" <me>' },
        [9]  = { label = 'Heal',    icon = 'rest',   command = '/heal' },
        [10] = { label = 'WHM0',    icon = 'test',   command = '/echo AshitaBars WHM base 0' },
    },

    ctrl = {
        [1]  = { label = 'CureII',  icon = 'cure',    command = '/ma "Cure II" <stpt>' },
        [2]  = { label = 'Curaga',  icon = 'cure',    command = '/ma "Curaga" <stpt>' },
        [3]  = { label = 'Regen',   icon = 'buff',    command = '/ma "Regen" <stpt>' },
        [4]  = { label = 'Raise',   icon = 'raise',   command = '/ma "Raise" <stpc>' },
        [5]  = { label = 'Sneak',   icon = 'stealth', command = '/ma "Sneak" <stpc>' },
        [6]  = { label = 'Invis',   icon = 'stealth', command = '/ma "Invisible" <stpc>' },
        [7]  = { label = 'Deodor',  icon = 'stealth', command = '/ma "Deodorize" <stpc>' },
        [8]  = { label = 'Barfire', icon = 'buff',    command = '/ma "Barfire" <me>' },
        [9]  = { label = 'Barwatr', icon = 'buff',    command = '/ma "Barwater" <me>' },
        [10] = { label = 'Barslp',  icon = 'buff',    command = '/ma "Barsleep" <me>' },
    },

    alt = {
        [1]  = { label = 'TargBT',  icon = 'target',  command = '/target <bt>' },
        [2]  = { label = 'Assist',  icon = 'assist',  command = '/assist <t>' },
        [3]  = { label = 'Check',   icon = 'check',   command = '/check <t>' },
        [4]  = { label = 'Echo',    icon = 'test',    command = '/echo AshitaBars WHM alt 4' },
        [5]  = { label = 'CureT',   icon = 'cure',    command = '/ma "Cure" <t>' },
        [6]  = { label = 'CurePC',  icon = 'cure',    command = '/ma "Cure" <stpc>' },
        [7]  = { label = 'Silena',  icon = 'status',  command = '/ma "Silena" <stpc>' },
        [8]  = { label = 'Erase',   icon = 'status',  command = '/ma "Erase" <stpc>' },
        [9]  = { label = 'Reraise', icon = 'raise',   command = '/ma "Reraise" <me>' },
        [10] = { label = 'DivSeal', icon = 'ability', command = '/ja "Divine Seal" <me>' },
    },

    click = {},
};

local bst_profile = {
    base = {
        [1]  = { label = 'Call',    icon = 'summon',  command = '/ja "Call Beast" <me>' },
        [2]  = { label = 'Attack',  icon = 'target',  command = '/attack <t>' },
        [3]  = { label = 'Charm',   icon = 'ability', command = '/ja "Charm" <t>' },
        [4]  = { label = 'Familr',  icon = 'ability', command = '/ja "Familiar" <me>' },
        [5]  = { label = 'RageAxe', icon = 'weapon',  command = '/ws "Raging Axe" <t>' },
        [6]  = { label = 'CureMe',  icon = 'cure',    command = '/ma "Cure" <me>' },
        [7]  = { label = 'Cure',    icon = 'cure',    command = '/ma "Cure" <stpt>' },
        [8]  = { label = 'Dia',     icon = 'holy',    command = '/ma "Dia" <t>' },
        [9]  = { label = 'Slow',    icon = 'debuff',  command = '/ma "Slow" <t>' },
        [10] = { label = 'Heal',    icon = 'rest',    command = '/heal' },
    },

    ctrl = {
        [1]  = { label = 'TargBT',  icon = 'target', command = '/target <bt>' },
        [2]  = { label = 'Assist',  icon = 'assist', command = '/assist <t>' },
        [3]  = { label = 'Attack',  icon = 'target', command = '/attack <t>' },
        [4]  = { label = 'Check',   icon = 'check',  command = '/check <t>' },
        [5]  = { label = 'TargNPC', icon = 'target', command = '/target <stnpc>' },
        [6]  = { label = 'CureT',   icon = 'cure',   command = '/ma "Cure" <t>' },
        [7]  = { label = 'CurePC',  icon = 'cure',   command = '/ma "Cure" <stpc>' },
        [8]  = { label = 'DiaBT',   icon = 'holy',   command = '/ma "Dia" <bt>' },
        [9]  = { label = 'SlowBT',  icon = 'debuff', command = '/ma "Slow" <bt>' },
        [10] = { label = 'WSBT',    icon = 'weapon', command = '/ws "Raging Axe" <bt>' },
    },

    alt = {
        [1]  = { label = 'Protect', icon = 'buff',   command = '/ma "Protect" <me>' },
        [2]  = { label = 'Shell',   icon = 'buff',   command = '/ma "Shell" <me>' },
        [3]  = { label = 'Poisona', icon = 'status', command = '/ma "Poisona" <stpc>' },
        [4]  = { label = 'Cure',    icon = 'cure',   command = '/ma "Cure" <stpt>' },
        [5]  = { label = 'CureMe',  icon = 'cure',   command = '/ma "Cure" <me>' },
        [6]  = { label = 'Banish',  icon = 'holy',   command = '/ma "Banish" <t>' },
        [7]  = { label = 'Stone',   icon = 'earth',  command = '/ma "Stone" <t>' },
        [8]  = { label = 'Dia',     icon = 'holy',   command = '/ma "Dia" <t>' },
        [9]  = { label = 'Slow',    icon = 'debuff', command = '/ma "Slow" <t>' },
        [10] = { label = 'Heal',    icon = 'rest',   command = '/heal' },
    },

    click = {},
};

return {
    settings = {
        theme = 'ffxi', -- Other built-in options: 'jeuno', 'sandoria'.
        show_hotkeys = true,
        show_labels = true,
        show_recasts = true,
        show_counts = true,
        show_availability = true,
        weaponskill_tp_threshold = 1000,
        icon_style = 'auto',
        row_gap = 6,
        block_native_macro_modifiers = true,
        main_bar = {
            visible = true,
            display_mode = 'single', -- Use 'stacked' for the existing three-row view.
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
            slot_size = 64,
            button_gap = 6,
            slot_glow_size = 100,
            slot_glow_opacity = 100,
            label_vertical_position = 100,
            window_x = 820,
            window_y = 680,
        },
    },

    profiles = {
        DEFAULT = default_profile,
        BST = bst_profile,
        WHM = whm_profile,

        -- Add job-specific profiles by main-job abbreviation. For example:
        -- WAR = {
        --     base = {
        --         [1] = { label = 'Provoke', command = '/ja "Provoke" <t>' },
        --         [2] = { label = 'FastBlade', command = '/ws "Fast Blade" <t>' },
        --         -- Item buttons use the selected item's in-game icon automatically.
        --         -- Structured commands use the action name as the label unless use_action_name_label is false.
        --         [3] = { label = 'Potion', command = '/item "Potion" <me>' },
        --         [4] = {
        --             label = 'Buffs',
        --             icon = 'buff',
        --             macro_mode = 'multi',
        --             script = true, -- Use Ashita's /exec runner so /wait pauses between commands.
        --             commands = {
        --                 '/ma "Protect" <me>',
        --                 '/wait 2',
        --                 '/ma "Shell" <me>',
        --             },
        --         },
        --     },
        --     ctrl = {},
        --     alt = {},
        --     click = {}, -- Optional click-only row. Never bound to keys.
        -- },
    },
}

