# Design comparison and intentional adaptations

References: approved [homepage concept](../../docs/media/web-home-concept.png)
and [guide concept](../../docs/media/web-guide-concept.png).
Actual public renders: [homepage](../../docs/media/web-portal-home-desktop.png),
[guide](../../docs/media/web-portal-guide-desktop.png),
[touch-sized homepage](../../docs/media/web-portal-home-mobile.png), and
[touch-sized guide](../../docs/media/web-portal-guide-mobile.png).

The references and actual renders were opened together with `view_image` during
the same QA pass. Reference-size checks use 1536×1024; gameplay smoke uses
1366×768; the mobile check uses 390×844 with touch/coarse-pointer emulation.
Browser/IAB is unsupported in this Linux session, so actual Playwright browser
captures and DOM checks supply the render evidence. No physical-display or
hardware-performance conclusion follows from software rendering.

| Comparison | Observation and action |
| --- | --- |
| First viewport | Retained left headline/actions and right miniature, followed by the mode strip, help links and footer. Bounded the scene height after the initial layout pushed the mode strip below the reference composition; it now begins at approximately y=782. |
| Copy | Preserved the headline, primary/guide actions, mode labels and core supporting copy. Added the real lazy-load status and a narrow-screen desktop-controls explanation; corrected missing whitespace around responsive line breaks. No fabricated metrics or proof badges. |
| Palette and framing | Retained navy `#101a24`, amber `#f1bc68`, ivory `#eee9d9`, restrained cyan links, thin teal rules and rectangular buttons. The transparent scene blends into the page; it is not a framed gameplay screenshot. |
| Typography | Derived a self-hosted font from the game's original 5×7 glyphs, with moderate stroke reinforcement and system-font body text. This intentionally uses reproducible project glyphs rather than attempting to copy an unspecified concept font. Increased heading/wordmark weight after the first render looked too slight. |
| Diorama | Implemented real deterministic geometry, branching tree, raised routes, bridge, lights, thread, particles and the existing Kiln Fox/Thistlepaw sprites. Its original voxel detail and characters are intentional adaptations from the concept illustration; it is not a pixel-identical rendering of that bitmap. Refined the initial plain trunk and regular paving, and reduced draw calls through instancing. |
| Guide | Matched the three-column desktop structure, compact seven-link sidebar, three-link outline, numbered quickstart and control table. Fixed alias highlighting and full-width desktop table rows. The complete generated guide continues below the viewport; its footer follows the whole document. |
| Responsive layout | Stacked the homepage and collapsed guide navigation into a contents disclosure. Verified no horizontal document overflow at 390px. Coarse pointers do not receive the unsupported drag hint. |
| Motion and interaction | Checked live scene/tab behavior, persisted motion-off, OS reduced motion and a usable still poster. Staggered entrances and hover cues support the design. Actual game input checks are separate from these visual checks. |

The above-the-fold copy review found the deliberate status/mobile guidance
additions described above. Remaining differences are the documented original
font/geometry and the complete long-form guide. The implementation was reviewed
for fidelity to the accepted visual direction, with these adaptations disclosed;
no claim of pixel-identical concept reproduction is made.

The still poster is an actual 1200×1000 transparent renderer capture, encoded
losslessly. Its source hash, authoring details and the font/favicon provenance
are recorded in `web/assets/provenance.json`. The two concept images were
generated with the built-in image tool for design review; no user-API Forge
request was made to implement or verify this website.
