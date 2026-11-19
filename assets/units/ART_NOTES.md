# Troop presentation assets

Generated using the built-in `image_gen.imagegen` tool with transparent RGBA
output. Each existing card illustration was the visual reference. The original
card files are preserved. Exact prompts are saved in
[generation_prompts.json](generation_prompts.json).

| Sheet | Reference | Identity |
| --- | --- | --- |
| `fighter_sheet.png` | `assets/ui/cards/fighter.webp` | Blue-haired swordsman, steel armor, blue cape |
| `ranger_sheet.png` | `assets/ui/cards/ranger.webp` | Hooded archer, recurve bow, quiver |
| `tank_sheet.png` | `assets/ui/cards/tank.webp` | Basalt golem, blue crystal fists and shoulders |

Each sheet has four columns and four rows. Rows 0/1 walk north/south; rows 2/3
attack north/south. Attack columns show anticipation, windup, strike/release,
and recovery. Runtime cropping uses rounded quarter boundaries because the
generated sheet dimensions vary slightly. Original PNGs are retained intact.

`scripts/ui/troop_art.gd` stores the atlas boundaries, intended display sizes,
and per-frame foot heights measured from the image alpha. `TroopVisual` aligns
each frame's feet to its ground position and draws a small contact shadow;
there is no vertical walking bob. Card portraits use front-facing frames from
these same sheets. The team-palette shader recolors blue equipment for Red.

Sword, arrow, impact, tower, spell, and spawn effects are simple code-drawn
presentation elements. They read published combat events and never calculate
damage or change game state. Cosmetic variation uses deterministic trigonometry,
so rendering does not consume the game's random-number stream.
