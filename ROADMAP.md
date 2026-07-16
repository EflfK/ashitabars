# AshitaBars Roadmap

This is a working list for later AshitaBars improvements. Keep changes within
the attended-action boundary: one intentional keypress or click produces at
most one configured action or static macro.

## Visual Polish

- Done: custom action-button renderer with image-first square slots, hover
  state, pressed state, and active-row glow.
- Done: per-slot built-in icon support through config, with inferred icons in
  `auto` mode and a text-only fallback when icons are disabled or absent.
- Done: Final Fantasy-inspired icon set for common action types such as white magic,
  black magic, job abilities, weapon skills, items, targeting, assist, healing,
  and test actions.
- Done: slot overlays for hotkey text, action label text, empty-slot dimming, and
  readable text shadowing.
- Done: single-row modifier transition polish, such as a quick glow or color shift
  when the visible row changes between base, Ctrl, and Alt.
- Done: theme settings for visual preferences, such as `theme`, `show_hotkeys`,
  `show_labels`, and `icon_style`.
- Done: configurable button sizing through `settings.slot_size` and runtime
  `/ashitabars size`, with a larger sample default for denser slot overlays.
- Done: configurable button spacing through `settings.button_gap` and runtime
  `/ashitabars gap`, with legacy `slot_gap` fallback.
- Done: runtime configuration window for display mode, button size, and button
  gap, with slider controls and a Save button for persistence.
- Done: optional draggable bar frame, allowing the ImGui title/background to be
  shown for positioning and hidden for locked frameless action bars.
- Done: configurable button glow size and opacity, with runtime sliders and
  saved config values.
- Done: configurable button label vertical placement, with label text drawn
  directly over the icon instead of on a filled strip.
- Done: in-game button editor, opened from a small frame-mode edit corner and
  persisted as per-profile button overrides, with a built-in icon selector and
  live icon preview.
- Done: single-command and multi-line macro modes in the button editor, with
  per-line command-prefix validation, a Validate & Run editor button, and
  attended execution only.

## Later Feature Ideas

- Done: `/ashitabars mode single|stacked` to switch display mode in game without
  editing `ashitabars_config.lua` and reloading.
- Done: display-only cooldown or recast overlays for spell and job-ability slots
  when the local Ashita recast timer can be resolved safely.
- Done: display-only item count badges and basic low-resource dimming for item,
  spell, and weapon-skill slots where safe local state is available.
- Display-only charge/count text for abilities where safe charge state is
  available and semantics are clear.
- Display-only range or usability dimming if it can be implemented without
  automated action choice.
- Drag-to-reorder UI, guarded so it only changes static profile configuration.
