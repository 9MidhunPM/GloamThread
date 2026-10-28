# Website design and motion

The website presents the existing pixel game through a living 3D diorama. The
user approved these built-in Image Gen concepts on 2026-10-28 before
implementation: [homepage](media/web-home-concept.png) and
[player guide](media/web-guide-concept.png). They are design references, not
captures of gameplay or the implemented website. The original public fighters
replace the illustrative characters in the concept.

## Visual contract

- Midnight navy `#101a24`, forest teal `#203f43`, warm amber `#f1bc68`, ivory
  `#eee9d9`, and restrained cyan `#85d9e7`.
- Original pixel display headings and wordmark, legible system-font body text,
  rectangular actions, thin rules, generous spacing, and one strong scene.
- The homepage reads **A small world. A wild fight.**, with **Play Gloamthread**
  and **Read the guide**, Arena/Story scene previews, mode descriptions, and
  direct controls/save/creation help links.
- The help page uses the same header and typography, a readable document column,
  section navigation, an on-page outline, and a compact mobile contents control.
- The scene is a website illustration. It does not represent a new 3D gameplay
  mode. Real gameplay screenshots in the guide retain their own captions.

## Interaction contract

Before play, pointer/drag movement explores the diorama, and Arena/Story tabs
change its presentation. Motion includes a restrained entrance, lantern light,
particles and a glowing thread. Native page scrolling remains available.
Reduced-motion preferences and the visible motion control select a still view.
Hidden/offscreen rendering is suspended.

Play owns one game startup. The website renderer releases its resources before
Godot starts. Home retains the paused game and uses the still poster, and Resume
returns to the same run. Loading, errors, retry, fullscreen and persistence
messages remain explicit and accessible. Reading help while a game exists must
not unload the run.

## Reproduction and review

Scene geometry is authored in the repository, with deterministic placement and
owned public sprite textures. The fallback poster is captured from that scene;
the concept image is never substituted for a runtime capture. Website build and
hosting instructions are in [the Web release guide](WEB_RELEASE.md).

Review the implementation against both concepts at their 1536×1024 reference
size, a 1366×768 laptop size, and a narrow mobile viewport. Compare composition,
copy, typography, palette, asset framing, controls, and responsive behavior.
Record material deviations and exact browser/display limitations alongside the
release evidence. A passing export alone does not establish visual fidelity.
