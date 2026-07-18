# AshitaBars

Experimental Ashita v4 action bar addon for CatsEyeXI.

AshitaBars is intended to replace the visible feel of the native FFXI macro
palette while the addon is loaded. It does not use `/bind`; it handles
configurable key events directly so keys can pass through normally while chat
or another text input is open.

## Current Scope

- Shows configurable action-bar visuals:
  - The main bar is one visible row of ten parent buttons.
  - Ctrl, Alt, and Shift are optional per-button variants edited from the parent
    button, not separate visible rows.
- Defaults to `1-0`, `Ctrl+1-0`, `Alt+1-0`, and `Shift+1-0`, with per-button
  keybinds configurable in game.
- Captures configured keys only while FFXI chat/input is closed.
- Passes keys through while chat/input is open.
- Clears native DirectInput `Ctrl`/`Alt` macro-palette state only while an
  AshitaBars Ctrl/Alt digit hotkey is pressed, so FFXI should not also show or
  execute native macro rows for configured `Ctrl+1-0` / `Alt+1-0` style binds.
- Selects an action profile by current main job, falling back to `DEFAULT`.
- Clicks on visible slots also execute one configured command, structured
  generated command, or static multi-line macro.
- Draws image-first action-button slots with hotkey badges, configurable label
  placement, readable text outlines, empty-slot dimming, and unsupported-command
  markers.
- Draws display-only recast overlays for configured spell and job-ability slots
  when Ashita exposes a matching recast timer.
- Draws display-only item count badges and low-resource dimming for supported
  spell, item, and weapon-skill slots.
- Supports optional per-slot built-in icon tokens, with inferred icons in
  `auto` mode.
- When `/ashitabars config` is open, each button shows a small edit corner that
  opens an in-game editor for that button's label, command mode, command data,
  optional icon, and enabled Ctrl/Alt/Shift variants.
- Ships default test commands that only `/echo`.

## Safety Boundary

This addon can send real FFXI slash commands when configured to do so. Keep it
to one intentional keypress or click producing one configured action: either
one command line, one structured command that generates a normal slash command,
or one static multi-line macro. Static per-job profiles are fine; do not add
timers, loops, reactive combat-state action choice, packet injection,
unattended behavior, or detection-evasion behavior. The in-game button editor
follows the same boundary: each saved macro is a fixed list of allowed slash
command lines and only runs from the attended button press. `/wait` is allowed
inside saved multi-line macros, matching normal FFXI macro behavior. Common
attended macro helpers such as `/equip` and `/lac` are allowed so saved buttons
can wrap normal item-use and gear-state flows.

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

Visual and input settings are configured under `settings`:

```lua
settings = {
    theme = 'ffxi',
    show_hotkeys = true,
    show_labels = true,
    show_recasts = true,
    show_counts = true,
    show_availability = true,
    weaponskill_tp_threshold = 1000,
    icon_style = 'auto',
    main_bar = {
        visible = true,
        profile_scope = 'job', -- 'global', 'job', or 'job_sub'.
        keybinds = {
            base = { [1] = '1', [2] = '2', [3] = '3', [4] = '4', [5] = '5', [6] = '6', [7] = '7', [8] = '8', [9] = '9', [10] = '0' },
            ctrl = { [1] = 'Ctrl+1', [2] = 'Ctrl+2', [3] = 'Ctrl+3', [4] = 'Ctrl+4', [5] = 'Ctrl+5', [6] = 'Ctrl+6', [7] = 'Ctrl+7', [8] = 'Ctrl+8', [9] = 'Ctrl+9', [10] = 'Ctrl+0' },
            alt = { [1] = 'Alt+1', [2] = 'Alt+2', [3] = 'Alt+3', [4] = 'Alt+4', [5] = 'Alt+5', [6] = 'Alt+6', [7] = 'Alt+7', [8] = 'Alt+8', [9] = 'Alt+9', [10] = 'Alt+0' },
            shift = { [1] = 'Shift+1', [2] = 'Shift+2', [3] = 'Shift+3', [4] = 'Shift+4', [5] = 'Shift+5', [6] = 'Shift+6', [7] = 'Shift+7', [8] = 'Shift+8', [9] = 'Shift+9', [10] = 'Shift+0' },
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
        profile_scope = 'job', -- 'global', 'job', or 'job_sub'.
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
}
```

Stacked mode has been removed. Existing configs that still set
`main_bar.display_mode` or top-level `display_mode` are tolerated, but the main
bar now always renders as one row.

`main_bar.keybinds` controls the default parent and modifier key combinations.
Ctrl/Alt/Shift keybinds only run when that specific button's modifier variant
is enabled in the button editor. Modifier combinations such as `Ctrl+Shift+1`
are not separate button layers. `extra_bar_1.keybinds` is optional; leave
`click = {}` empty to keep the extra bar click-only. Configured duplicate
keybinds are allowed but warned about in the config window and `/ashitabars
status`; the first matching enabled button runs.

Each bar has its own `profile_scope`:

- `global`: use `profiles.DEFAULT` and save runtime edits under `DEFAULT`.
- `job`: use the current main job key, such as `BST`, falling back to
  `DEFAULT` for configured slots.
- `job_sub`: use the current main+subjob key, such as `BST_WHM`, falling back
  to the main job and then `DEFAULT` for configured slots.

`extra_bar_1` configures the second 10-button single-row bar.
`extra_bar_1.window_x` / `extra_bar_1.window_y` store its independent position.

`/ashitabars config` opens a configuration window with `General`, `Main Bar`,
and `Extra Bar 1` tabs. The bar tabs expose independent visibility, profile
scope, sizing, spacing, text placement, glow, keybinds, and position settings. Numeric
controls use sliders. Click a keybind button, then press the new key; Backspace
or Delete clears the bind and Escape cancels. Changes apply immediately as
runtime overrides; click `Save` in the window to persist button scope, button
size, button gap, button glow, label placement, keybinds, and bar
positions to:

```txt
Ashita/config/addons/ashitabars/visual_settings.lua
```

That file lives outside the addon folder, so running `install.ps1` for a new
test build does not reset placement, size, spacing, glow, or keybind settings.

Button labels are drawn as shadowed text without a background strip.
Each bar's `label_vertical_position` controls their vertical placement from `0`
top, to `50` center, to `100` bottom.

Button glow is controlled by each bar's `slot_glow_size` and
`slot_glow_opacity`. `slot_glow_size = 100` is the original glow size,
`0` disables the glow, and `200` doubles the original glow size.
`slot_glow_opacity` is a `0` to `100` percent alpha multiplier.

Bar frames are hidden while the configuration window is closed. Opening
`/ashitabars config` temporarily shows all visible bar frames so bars can be
dragged and buttons can be edited; click `Save` to persist any new positions.

Button size is controlled by each bar's `slot_size`, clamped from `40` to `96`
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
setting when present, otherwise `main_bar.slot_size`. `/ashitabars reload` also
clears the runtime size override.

Button spacing is controlled by each bar's `button_gap`, clamped from `0` to `24`
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
setting when present, otherwise `main_bar.button_gap`. `/ashitabars reload` also
clears the runtime gap override.

Built-in themes are `ffxi`, `jeuno`, and `sandoria`. `ffxi` is the default and
preserves the current brass-and-crystal look; the other themes only change the
window chrome and overlay palette.

Profiles are keyed by the current bar's configured `profile_scope`. `DEFAULT`
is used for global bars and as the configured-slot fallback when a specific
profile does not exist:

```lua
profiles = {
    DEFAULT = {
        base = {
            [1] = { label = 'Cure', command = '/ma "Cure" <stpt>' },
        },
        ctrl = {},
        alt = {},
        shift = {},
        click = {}, -- Optional click-only row.
    },

    WAR = {
        base = {
            [1] = { label = 'Provoke', command = '/ja "Provoke" <t>' },
        },
        ctrl = {},
        alt = {},
        shift = {},
        click = {},
    },

    -- Optional exact main+subjob profile used by `profile_scope = 'job_sub'`.
    WAR_NIN = {
        base = {
            [1] = { label = 'Provoke', command = '/ja "Provoke" <t>' },
        },
        ctrl = {},
        alt = {},
        shift = {},
        click = {},
    },
}
```

Each slot has a label and command, and may also include an `icon` token:

```lua
[1] = { label = 'Cure', icon = 'cure', command = '/ma "Cure" <stpt>' },
```

Slots can also store a static multi-line macro. Each line is validated against
the same allowed prefix list and is queued only from the attended key press or
click. By default, each line is queued directly. Set `script = true` to run the
macro through Ashita's native `/exec` script runner, which lets `/wait`
pause between commands:

```lua
[2] = {
    label = 'Buffs',
    icon = 'buff',
    macro_mode = 'multi',
    script = true,
    commands = {
        '/ma "Protect" <me>',
        '/wait 2',
        '/ma "Shell" <me>',
    },
},
```

Runtime button edits can also define shared buttons once and reference them
from any job/profile slot:

```lua
return {
    shared = {
        ['Cure STPT'] = { label = 'Cure', icon = 'cure', command = '/ma "Cure" <stpt>' },
    },
    profiles = {
        WHM = {
            base = {
                [1] = { shared = 'Cure STPT' },
                [2] = { shared = 'Cure STPT' },
            },
        },
    },
}
```

You can edit visible buttons in game while `/ashitabars config` is open. Bar
frames are shown automatically while the configuration window is open; click the
small top-left corner of a button to edit it. The editor can save a label,
command mode, command data, and an optional icon chosen from a built-in visual
picker grouped by category. Each picker option stores its own button art token,
so individual buttons can mix the default crystal art and alternate sigil art.
Main-bar buttons open on a `Main` tab. That tab has Ctrl, Alt, and Shift
checkboxes; checking one exposes a matching modifier tab for that button. Each
modifier tab has its own command mode, command data, label, shared-button
reference, and icon, but does not define further modifiers. Unchecked modifier
variants do not run or block their keybinds.
Item mode does not show the manual icon selector because item buttons use the
selected item's in-game icon automatically. These runtime edits are stored
outside the addon folder in:

```txt
Ashita/config/addons/ashitabars/button_overrides.lua
```

Saved button edits are overlaid on top of the current bar's resolved profile
scope and persist across addon reloads and game sessions. `Clear` saves an
empty button for that slot, while `Reset` removes the saved edit and returns to
the configured profile slot. `Validate & Run` validates the current editor
command or macro lines and queues them immediately without saving the button.

Command mode options are:

- `Freeform Command`: hand-enter one allowed slash command.
- `Multi-Line Macro`: hand-enter allowed slash command lines, including
  `/wait`; the editor no longer applies a command-count cap. Check
  `Run As Ashita Script` when the macro should use Ashita's `/exec` runner
  so `/wait` pauses between lines. AshitaBars writes generated script files to
  `Ashita/scripts/` using `ashitabars_` filename prefixes. Script-backed
  macros show a display-only countdown on the button based on the sum of their
  `/wait` lines after they are pressed.
- `Spell`: filter usable learned spells by magic type, element, and search text,
  then choose from the filtered spell list and select a target; generates `/ma`.
  The type and element dropdowns only show values that still have matching
  spells under the other active filters. Trust spells are grouped under
  `Trusts`, even when their resource type data overlaps other magic categories.
  If the filters hide the selected spell, the editor clears the selection and
  requires choosing another spell before saving or running.
- `Item`: choose an item from Inventory or Temporary items; generates `/item`
  with `<me>` and intentionally does not show a target selector. Filter by item
  source and search text, then choose from the filtered item list. The editor
  previews the selected item's in-game icon and shows the item resource tooltip
  when hovering the preview or item rows. Saved item buttons do not need an
  `icon` token; the action bar renders the item icon from the game resource.
- `Mount`: search Ashita's `mounts.names` resource list, choose a mount, and
  generate `/mount`. Mount buttons do not show a target selector or icon token
  selector; the action bar uses the automatic mount icon. The selector lists
  mount resource names and does not claim whether the current character has
  unlocked each mount. When a single-command mount button is pressed while the
  player is already mounted, AshitaBars sends `/dismount` instead.
- `Weapon Skill`: search known weapon skills, choose one, and select a target;
  generates `/ws`.
- `Job Ability`: search known job abilities, choose one, and select a target;
  generates `/ja`.
- `Pet Command`: available only when Ashita reports usable pet commands for
  the current main/sub job. Search the live pet command list, choose a command,
  and select a target; generates `/pet`. Control-style commands such as Heel,
  Stay, Leave, Release, Retreat, Retrieve, and Deactivate default to `<me>`;
  action-style commands default to `<t>`.
- `Ranged Attack`: choose the ranged attack action and target; generates `/ra`.
- `Target / Assist`: choose target, assist, attack, or check plus a target.

Structured modes still save normal slash command text in
`button_overrides.lua`, so key execution, validation, icon inference, recast
display, item counts, and availability dimming use the same path as hand-written
commands. Existing command buttons are parsed back into the matching structured
mode when possible; unsupported or unusual commands open as `Freeform Command`.
All structured modes default to using the selected action name as the bar label.
Uncheck `Use Action Name As Label` to show the normal label field and save a
custom label instead. If a filter hides the selected action, the editor clears
the selection and hides `Save` / `Validate & Run` until a visible action is
selected again.

Shared buttons are linked by name, not copied. If multiple slots use the same
shared button, editing and saving any attached slot updates the shared
definition and every other slot using that shared button changes with it. In
the editor, `Save Shared` creates or updates the named shared button and
attaches the current slot to it, `Assign Shared` points the current slot at the
selected shared button without changing the definition, and `Detach Local`
saves the current fields as a local per-slot copy.

`icon_style = 'auto'` uses the configured icon when present and otherwise
infers a built-in icon from the command. Use `icon_style = 'configured'` to
draw icons only for slots that explicitly set `icon`, or `icon_style = 'none'`
for label-only slots.

For structured command slots, `use_action_name_label` defaults to `true`, so the
displayed label is resolved from the saved command. Set
`use_action_name_label = false` on a slot when you want its configured `label`
to display instead.

`show_recasts = true` draws a dark cooldown wipe and remaining time on slots
whose commands resolve to `/ma`, `/magic`, `/ja`, `/jobability`, or `/mount`
recast data.
For multi-line macros, recast display is based on the first command. This is
display-only; key and click execution still runs the configured command or
macro exactly as saved. Set `show_recasts = false` globally, or `recast = false` on
an individual slot, to hide the overlay.
Mount buttons use a local 60-second display countdown after AshitaBars queues a
single `/mount` command; the game server still decides whether mounting is
actually allowed.

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
Pet command buttons are also struck out when Ashita no longer reports that
specific pet command as currently usable.

Built-in icon tokens include `cure`, `holy`, `buff`, `status`, `debuff`,
`raise`, `stealth`, `white_magic`, `black_magic`, `fire`, `ice`, `wind`,
`earth`, `lightning`, `water`, `light`, `dark`, `ability`, `song`, `summon`,
`pet`, `fight`, `charm`, `reward`, `weapon`, `ranged`, `item`, `target`,
`assist`, `check`, `chat`, `rest`, `test`, and `command`. Unknown icon tokens
fall back to a small two-letter text glyph. Prefix any built-in icon token with
`sigil_` to use that alternate line-art variant on a single button, for example
`sigil_cure` or `sigil_weapon`.

Image-backed icon tokens are also available in the icon picker. They use PNG
assets under `ashitabars/assets/icons/` and are stored by token name, such as
`asset_fire_flame`, `asset_ice_crystal`, `asset_weapon_swords`,
`asset_item_bag`, `asset_mount_chocobo`, and `asset_target_mark`.
Item buttons use the resolved in-game item icon automatically, while mount
buttons can use any selected built-in, sigil, or image-backed icon token.

In `auto` mode, common FFXI spell names infer matching icons. For example,
`Fire`/`Blizzard`/`Aero` use elemental glyphs, `Drain`/`Aspir`/`Bio` use dark,
common enfeebles use `debuff`, songs use `song`, and avatar names use
`summon`.

Existing configs that still use a top-level `bars = { ... }` table continue to
work as a legacy fallback.

The sample config includes a `WHM` test profile and a `BST` leveling profile.
The WHM profile intentionally mixes common WHM spells with `/heal`, `/target`,
`/assist`, `/check`, `/echo`, and one `/ja` slot so different command paths,
target forms, and built-in icon tokens can be tested. The BST profile is tuned
for early `BST/WHM` play with base combat/beast actions, Ctrl targeting, and
Alt support.

Planned visual and quality-of-life improvements are tracked in `ROADMAP.md`.

`/ashitabars status` prints the fixed display mode, active keyboard modifier,
button size/source, button gap/source, theme, icon style, click-bar
visibility/position, recast/count/availability settings, keybind
summary/conflict count, and weapon-skill TP threshold alongside input, job,
subjob, per-bar profile scope/resolution, and modifier-blocking state.

Modifier blocking is scoped to AshitaBars configured Ctrl/Alt digit hotkeys so
native shortcuts such as `Ctrl+E` and `Ctrl+I` can continue to work unless you
explicitly bind them. If modifier blocking still conflicts with another hotkey,
disable it:

```lua
block_native_macro_modifiers = false,
```

Allowed command prefixes are intentionally narrow. Player action commands such
as `/ma`, `/ja`, `/pet`, `/ws`, `/item`, `/attack`, and `/target` are accepted.
Ashita control commands such as `/addon`, `/bind`, `/unbind`, `/exec`, and
`/alias` are not accepted as slot commands or macro lines. Slots with
unsupported prefixes draw a red warning corner and are still rejected when
clicked or pressed.

## Notes

Modifier variants are still static button definitions. They do not add timers,
reactive command selection, or unattended behavior.

