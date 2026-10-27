# Zen Mahjong Journey — Visual Asset Pack

This is a named, directly usable set of PNG assets and visual reference screens.

## Directly usable
- `backgrounds/`: original full-screen vertical environment PNGs.
- `tiles/faces/`: **individual** uniformly sized transparent PNGs (192x240); configure the tile logic independently from appearance.
- `tiles/backs/`: tile backs.
- `ui/buttons/`: independent, empty scalable-style button visuals; place editable Godot text labels on top.
- `ui/icons/`: separate transparent UI icons; use the names for your Godot controls.
- `ui/panels/`: blank dialog/hud panels; put Godot labels and widgets on top.
- `progression/`: stage markers.
- `effects/`: optional cherry-petal particles.
- `branding/app_icon_preview_512.png`: app icon preview, verify Play Store artwork requirements.

## Concept art only — do NOT use as interactive screen
The PNGs in `screens/reference_only/` show styling and desired screen layouts; they contain flattened text and buttons and are **not** individual UI elements. Reconstruct every screen in Godot controls using the separate transparent button icons, labels and panels. Do not place invisible buttons over full-screen concept screenshots.

## Rendering guidance
Use 1080x1920 portrait reference, expand/stretch to phone safe area, background set to COVER. Texture filtering linear, alpha blending enabled. The generated background artwork is detailed, so add subtle dark or cream translucent contrast overlays behind gameplay board/HUD when needed.

## Mahjong symbols
The `tiles/faces/` directory contains 42 face IDs across bamboo, dots, characters, winds, dragons, flowers, and seasons. These graphics are consistent procedural artwork, suitable for playable prototyping. Some CJK glyph rendering may depend on the installed font; have a visual review before production publishing. The ornamental flower/season icons can be upgraded with hand-drawn art later.

## Business / QA
This asset pack does not contain Godot scenes, animations, sound, fonts or AdMob code. Claude must build those separately. Preview art is a visual target, not proof that UI/gameplay works.
