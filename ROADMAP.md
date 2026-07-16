# AshitaBars Roadmap

This is a working list for later AshitaBars improvements. Keep changes within
the attended-action boundary: one intentional keypress or click produces at
most one configured command.

## Visual Polish

- Done: custom action-button renderer with a World of Warcraft-style square slot,
  bevel, inner border, hover state, pressed state, and active-row glow.
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
- Drag-to-reorder or config editing UI, guarded so it only changes static
  profile configuration.
