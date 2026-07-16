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
- Clicks on visible slots also execute one configured command or static
  multi-line macro.
- Draws image-first action-button slots with hotkey badges, configurable label
  placement, readable text outlines, empty-slot dimming, and unsupported-command
  markers.
- Draws display-only recast overlays for configured spell and job-ability slots
  when Ashita exposes a matching recast timer.
- Draws display-only item count badges and low-resource dimming for supported
  spell, item, and weapon-skill slots.
- Supports optional per-slot built-in icon tokens, with inferred icons in
  `auto` mode.
- When the bar frame is visible, each button shows a small edit corner that
  opens an in-game editor for that button's label, command mode, command text,
  and optional icon.
- Ships default test commands that only `/echo`.

## Safety Boundary

This addon can send real FFXI slash commands when configured to do so. Keep it
to one intentional keypress or click producing one configured action: either
one command line or one static multi-line macro. Static per-job profiles are
fine; do not add timers, waits, loops, reactive combat-state action choice,
packet injection, unattended behavior, or detection-evasion behavior. The
in-game button editor follows the same boundary: each saved macro is a fixed
list of allowed slash command lines and only runs from the attended button
press.

Unlisted active-helper behavior should be reviewed under CatsEyeXI addon policy
before normal use.

## Install

From this repository:

```powershell
.\install.ps1
```

The installer does not overwrite saved runtime visuals or button edits under
`Ashita/config/addons/ashitabars/`. On first install after older versions, it
also migrates known visual settings from the currently installed
`ashitabars_config.lua` into `visual_settings.lua` before replacing the addon
folder.

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
/ashitabars config
/ashitabars mode single
/ashitabars mode stacked
/ashitabars mode config
/ashitabars size 72
/ashitabars size config
/ashitabars gap 8
/ashitabars gap config
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
    slot_size = 64,
    button_gap = 6,
    slot_glow_size = 100,
    slot_glow_opacity = 100,
    label_vertical_position = 100,
    show_bar_frame = false,
    window_x = 820,
    window_y = 760,
}
```

The setting changes only the visible UI. Key execution remains `1-0`,
`Ctrl+1-0`, and `Alt+1-0` in both modes. Existing configs without
`display_mode` keep the original stacked view.

You can switch display modes at runtime without editing the config:

```txt
/ashitabars config
/ashitabars mode single
/ashitabars mode stacked
/ashitabars mode config
```

`mode config` clears the runtime override and returns to the saved visual
setting when present, otherwise `settings.display_mode`. `/ashitabars reload`
also clears runtime overrides and reapplies saved visual settings.

`/ashitabars config` opens a configuration window with a General tab for the
same controls exposed by `/ashitabars mode`, `/ashitabars size`, and
`/ashitabars gap`. Numeric controls use sliders. Changes apply immediately as
runtime overrides; click `Save` in the window to persist display mode, button
size, button gap, button glow, label placement, bar frame visibility, and bar
position to:

```txt
Ashita/config/addons/ashitabars/visual_settings.lua
```

That file lives outside the addon folder, so running `install.ps1` for a new
test build does not reset placement, size, spacing, or glow settings.

Button labels are drawn as shadowed text without a background strip.
`settings.label_vertical_position` controls their vertical placement from `0`
top, to `50` center, to `100` bottom.

Button glow is controlled by `settings.slot_glow_size` and
`settings.slot_glow_opacity`. `slot_glow_size = 100` is the original glow size,
`0` disables the glow, and `200` doubles the original glow size.
`slot_glow_opacity` is a `0` to `100` percent alpha multiplier.

`show_bar_frame = true` keeps the normal ImGui title bar and background visible
so the bar can be dragged. `show_bar_frame = false` hides the title bar and
window background, hides the left row labels, and locks the first action button
at the saved `window_x` / `window_y` position. To move the frameless bar, open
`/ashitabars config`, enable `Show Bar Frame`, drag the bar, then click `Save`
after setting the frame visibility you want.

Button size is controlled by `settings.slot_size`, clamped from `40` to `96`
pixels. The sample config defaults to `64` so count badges, recast text, and
labels have room to breathe.

You can tune button size at runtime without editing the config:

```txt
/ashitabars size
/ashitabars size 56
/ashitabars size 64
/ashitabars size 72
/ashitabars size config
```

`size config` clears the runtime override and returns to the saved visual
setting when present, otherwise `settings.slot_size`. `/ashitabars reload` also
clears the runtime size override.

Button spacing is controlled by `settings.button_gap`, clamped from `0` to `24`
pixels. Existing configs that still use `slot_gap` continue to work as a legacy
fallback.

You can tune button spacing at runtime without editing the config:

```txt
/ashitabars gap
/ashitabars gap 4
/ashitabars gap 8
/ashitabars gap 12
/ashitabars gap config
```

`gap config` clears the runtime override and returns to the saved visual
setting when present, otherwise `settings.button_gap`. `/ashitabars reload` also
clears the runtime gap override.

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

Slots can also store a static multi-line macro. Each line is validated against
the same allowed prefix list and is queued only from the attended key press or
click:

```lua
[2] = {
    label = 'Buffs',
    icon = 'buff',
    macro_mode = 'multi',
    commands = {
        '/ma "Protect" <me>',
        '/ma "Shell" <me>',
    },
},
```

You can edit visible buttons in game while the bar frame is shown. Open
`/ashitabars config`, enable `Show Bar Frame`, then click the small top-left
corner of a button. The editor can save a label, a single-command or
multi-line macro mode, and an optional icon chosen from a built-in selector.
The edited button previews the selected icon in the editor preview tile, and
previews hovered icon presets while the selector is open. These runtime edits
are stored outside the addon folder in:

```txt
Ashita/config/addons/ashitabars/button_overrides.lua
```

Saved button edits are overlaid on top of the current job-aware profile and
persist across addon reloads and game sessions. `Clear` saves an empty button
for that slot, while `Reset` removes the saved edit and returns to the
configured profile slot. `Validate & Run` validates the current editor command
or macro lines and queues them immediately without saving the button.

`icon_style = 'auto'` uses the configured icon when present and otherwise
infers a built-in icon from the command. Use `icon_style = 'configured'` to
draw icons only for slots that explicitly set `icon`, or `icon_style = 'none'`
for label-only slots.

`show_recasts = true` draws a dark cooldown wipe and remaining time on slots
whose commands resolve to `/ma`, `/magic`, `/ja`, or `/jobability` recast data.
For multi-line macros, recast display is based on the first command. This is
display-only; key and click execution still runs the configured command or
macro exactly as saved. Set `show_recasts = false` globally, or `recast = false` on
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
display-mode source, button size/source, button gap/source, theme, icon style,
recast/count/availability settings, and weapon-skill TP threshold alongside
input, profile, and modifier-blocking state.

If modifier blocking conflicts with another hotkey, disable it:

```lua
block_native_macro_modifiers = false,
```

Allowed command prefixes are intentionally narrow. Ashita control commands such
as `/addon`, `/bind`, `/unbind`, `/exec`, and `/alias` are not accepted as slot
commands or macro lines. Slots with unsupported prefixes draw a red warning
corner and are still rejected when clicked or pressed.

## Notes

Single-row mode is visual only. It does not add timers, alternate command
selection, or unattended behavior.

