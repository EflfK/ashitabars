# AshitaBars

Experimental Ashita v4 action bar addon for CatsEyeXI.

AshitaBars is intended to replace the visible feel of the native FFXI macro
palette while the addon is loaded. It does not use `/bind`; it handles key
events directly so plain `1-0` can pass through normally while chat or another
text input is open.

## Current Scope

- Shows configurable action-bar visuals:
  - `stacked`: three rows for `1-0`, `Ctrl+1-0`, and `Alt+1-0`
  - `single`: one visible row that switches between base, Ctrl, and Alt while
    the modifier is held
- Captures those keys only while FFXI chat/input is closed.
- Passes keys through while chat/input is open.
- Clears native DirectInput `Ctrl`/`Alt` macro-palette state while chat/input is
  closed by default, so FFXI should not also show or execute native macro rows.
- Selects an action profile by current main job, falling back to `DEFAULT`.
- Clicks on visible slots also execute one configured command.
- Ships default test commands that only `/echo`.

## Safety Boundary

This addon can send real FFXI slash commands when configured to do so. Keep it
to one intentional keypress or click producing one command. Static per-job
profiles are fine; do not add timers, loops, reactive combat-state action
choice, packet injection, unattended behavior, or detection-evasion behavior.

Unlisted active-helper behavior should be reviewed under CatsEyeXI addon policy
before normal use.

## Install

From this repository:

```powershell
.\install.ps1
```

In game:

```txt
/addon load ashitabars
```

Commands:

```txt
/ashitabars
/ashitabars show
/ashitabars hide
/ashitabars toggle
/ashitabars status
/ashitabars reload
```

Short alias:

```txt
/abars
```

## Configure

Edit:

```txt
ashitabars/ashitabars_config.lua
```

Visual display mode is controlled in `settings`:

```lua
settings = {
    visible = true,
    display_mode = 'single', -- Use 'stacked' for the existing three-row view.
}
```

The setting changes only the visible UI. Key execution remains `1-0`,
`Ctrl+1-0`, and `Alt+1-0` in both modes. Existing configs without
`display_mode` keep the original stacked view.

Profiles are keyed by main-job abbreviation. `DEFAULT` is used when the current
job does not have a configured profile:

```lua
profiles = {
    DEFAULT = {
        base = {
            [1] = { label = 'Cure', command = '/ma "Cure" <stpt>' },
        },
        ctrl = {},
        alt = {},
    },

    WAR = {
        base = {
            [1] = { label = 'Provoke', command = '/ja "Provoke" <t>' },
        },
        ctrl = {},
        alt = {},
    },
}
```

Each slot has a label and command:

```lua
[1] = { label = 'Cure', command = '/ma "Cure" <stpt>' },
```

Existing configs that still use a top-level `bars = { ... }` table continue to
work as a legacy fallback.

The sample config includes a `WHM` test profile. It intentionally mixes common
WHM spells with `/heal`, `/target`, `/assist`, `/check`, `/echo`, and one
`/ja` slot so different command paths and target forms can be tested.

`/ashitabars status` prints the normalized display mode and current visual row
alongside input, profile, and modifier-blocking state.

If modifier blocking conflicts with another hotkey, disable it:

```lua
block_native_macro_modifiers = false,
```

Allowed command prefixes are intentionally narrow. Ashita control commands such
as `/addon`, `/bind`, `/unbind`, `/exec`, and `/alias` are not accepted as slot
commands.

## Notes

Single-row mode is visual only. It does not add timers, alternate command
selection, or unattended behavior.

