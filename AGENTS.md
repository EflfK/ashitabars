# AshitaBars Repository Instructions

## Icon Imports

When the user asks to import, refresh, or pull icons for AshitaBars, use the
workspace-relative source folder `FinalFantasyXI/icons/`. Do not use a full
user-specific path.

Import icon PNGs into `ashitabars/assets/icons/`, preserving each source file
name because those names become the icon token IDs. Add newly imported icons to
the AshitaBars icon registry in `ashitabars/ashitabars.lua` so they appear in
the icon picker, grouped into the closest existing category/family. Update
documentation when the visible token list changes.
