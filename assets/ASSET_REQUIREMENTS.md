# Art and audio slots

The game includes original fantasy art created with built-in image generation
from the written brief. The supplied gameplay screenshot, title poster,
PowerPoint, and video were unavailable during this implementation.

| Asset | Shipped slot | Replacement guidance |
| --- | --- | --- |
| Title painting | `ui/backgrounds/citadel.webp` | 1920 × 1080 landscape, leave the left third clear for the logo and menu |
| Arena painting | `arena/fortress.webp` | 1920 × 1080 landscape, two vertical lanes and two bridges at the logical lanes, all live towers rendered separately |
| Blue and Red portraits | `ui/portraits/` | Square color portrait, 400 × 400 or larger |
| Five card illustrations and card back | `ui/cards/` | Center the main subject for square and portrait crops, 400 × 400 or larger |
| Cores, guards, and ruins | `arena/structures/` | Alpha-transparent PNG or WebP with the tower centered over its base, up to 400 px tall |
| Banners, braziers, and preview miniatures | `arena/decorations/`, `arena/preview/` | Alpha-transparent PNG or WebP, up to 240 px tall |
| Crowned frames and small symbols | `ui/frames/metal_trim.png`, `../scripts/ui/components/arena_icon.gd` | 64 × 64 nine-slice corner texture and scalable Godot symbols |

Optional music and click sound can be assigned to the `menu_music` and
`button_sound` exports on `TitleScreen`. Use an Ogg Vorbis loop for music and
a short WAV or Ogg for the click. The audio streams are currently empty.
