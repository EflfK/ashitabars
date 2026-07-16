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
};

return {
    settings = {
        visible = true,
        slot_size = 48,
        slot_gap = 4,
        row_gap = 6,
        window_x = 820,
        window_y = 760,
        block_native_macro_modifiers = true,
    },

    profiles = {
        DEFAULT = default_profile,

        -- Add job-specific profiles by main-job abbreviation. For example:
        -- WAR = {
        --     base = {
        --         [1] = { label = 'Provoke', command = '/ja "Provoke" <t>' },
        --     },
        --     ctrl = {},
        --     alt = {},
        -- },
    },
}

