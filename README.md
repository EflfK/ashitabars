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
    the modifier is held, with a brief row-switch glow
- Captures those keys only while FFXI chat/input is closed.
- Passes keys through while chat/input is open.
- Clears native DirectInput `Ctrl`/`Alt` macro-palette state while chat/input is
  closed by default, so FFXI should not also show or execute native macro rows.
- Selects an action profile by current main job, falling back to `DEFAULT`.
- Clicks on visible slots also execute one configured command.
- Draws custom action-button slots with hotkey badges, label strips, readable
  text outlines, empty-slot dimming, and unsupported-command markers.
- Draws display-only recast overlays for configured spell and job-ability slots
  when Ashita exposes a matching recast timer.
- Draws display-only item count badges and low-resource dimming for supported
  spell, item, and weapon-skill slots.
- Supports optional per-slot built-in icon tokens, with inferred icons in
  `auto` mode.
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
/ashitabars mode single
/ashitabars mode stacked
/ashitabars mode config
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
    theme = 'ffxi',
    show_hotkeys = true,
    show_labels = true,
    show_recasts = true,
    show_counts = true,
    show_availability = true,
    weaponskill_tp_threshold = 1000,
    icon_style = 'auto',
}
```

The setting changes only the visible UI. Key execution remains `1-0`,
`Ctrl+1-0`, and `Alt+1-0` in both modes. Existing configs without
`display_mode` keep the original stacked view.

You can switch display modes at runtime without editing the config:

```txt
/ashitabars mode single
/ashitabars mode stacked
/ashitabars mode config
```

`mode config` clears the runtime override and returns to `settings.display_mode`.
`/ashitabars reload` also clears the runtime override.

Built-in themes are `ffxi`, `jeuno`, and `sandoria`. `ffxi` is the default and
preserves the current brass-and-crystal look; the other themes only change the
window, frame, and overlay palette.

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

Each slot has a label and command, and may also include an `icon` token:

```lua
[1] = { label = 'Cure', icon = 'cure', command = '/ma "Cure" <stpt>' },
```

`icon_style = 'auto'` uses the configured icon when present and otherwise
infers a built-in icon from the command. Use `icon_style = 'configured'` to
draw icons only for slots that explicitly set `icon`, or `icon_style = 'none'`
for label-only slots.

`show_recasts = true` draws a dark cooldown wipe and remaining time on slots
whose commands resolve to `/ma`, `/magic`, `/ja`, or `/jobability` recast data.
This is display-only; key and click execution still runs the configured command
exactly as before. Set `show_recasts = false` globally, or `recast = false` on
an individual slot, to hide the overlay.

`show_counts = true` draws a compact count badge for `/item` slots when the item
can be resolved in the local Ashita resource table. Counts are read from
Inventory and Temporary item containers.

`show_availability = true` dims slots when safe local state shows the configured
action is currently short on a basic resource:

- `/item` slots dim when the resolved item count is `0`.
- `/ma` and `/magic` slots dim when current MP is lower than the spell MP cost.
- `/ws` and `/weaponskill` slots dim when current TP is lower than
  `weaponskill_tp_threshold`, defaulting to `1000`.

This dimming is display-only. It does not block the keypress, pick alternate
actions, or change the configured command. Set `show_availability = false`
globally, or `availability = false` on an individual slot, to hide the dimming.
Set `count = false` on an individual slot to hide only its count badge.

Built-in icon tokens include `cure`, `holy`, `buff`, `status`, `debuff`,
`raise`, `stealth`, `white_magic`, `black_magic`, `fire`, `ice`, `wind`,
`earth`, `lightning`, `water`, `light`, `dark`, `ability`, `song`, `summon`,
`weapon`, `ranged`, `item`, `target`, `assist`, `check`, `chat`, `rest`,
`test`, and `command`. Unknown icon tokens fall back to a small two-letter text
glyph.

In `auto` mode, common FFXI spell names infer matching icons. For example,
`Fire`/`Blizzard`/`Aero` use elemental glyphs, `Drain`/`Aspir`/`Bio` use dark,
common enfeebles use `debuff`, songs use `song`, and avatar names use
`summon`.

Existing configs that still use a top-level `bars = { ... }` table continue to
work as a legacy fallback.

The sample config includes a `WHM` test profile. It intentionally mixes common
WHM spells with `/heal`, `/target`, `/assist`, `/check`, `/echo`, and one
`/ja` slot so different command paths, target forms, and built-in icon tokens
can be tested.

Planned visual and quality-of-life improvements are tracked in `ROADMAP.md`.

`/ashitabars status` prints the normalized display mode, current visual row,
display-mode source, theme, icon style, recast/count/availability settings, and
weapon-skill TP threshold alongside input, profile, and modifier-blocking state.

If modifier blocking conflicts with another hotkey, disable it:

```lua
block_native_macro_modifiers = false,
```

Allowed command prefixes are intentionally narrow. Ashita control commands such
as `/addon`, `/bind`, `/unbind`, `/exec`, and `/alias` are not accepted as slot
commands. Slots with unsupported prefixes draw a red warning corner and are
still rejected when clicked or pressed.

## Notes

Single-row mode is visual only. It does not add timers, alternate command
selection, or unattended behavior.

