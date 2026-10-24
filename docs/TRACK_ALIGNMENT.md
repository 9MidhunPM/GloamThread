# Track alignment and demonstration

Source: the user-supplied **Devin Hacks Kochi Tracks** PDF, read directly on 24 October 2026. This section interprets that document only; it does not invent event requirements or promise a judging outcome.

Event guidance follows the corrected **Devin Hack Kochi** template referenced in [RULES.md](../RULES.md). The track interpretation below adds no AI provider requirement; current organizer announcements remain authoritative for eligibility and submission.

## Primary track: Make Room for Play

The track says:

> Build something people would want to experience, not just get work done with. Create a new way to play, make music, tell stories or interact with other people.

Its examples include a game across phones and a story whose world responds to players. These are examples, not a requirement for phones, online networking, generative assets or a particular number of players. Two people playing on one computer is local multiplayer.

Gloamthread's concrete fit:

| Track intention | Implemented behaviour to demonstrate | Evidence needed |
| --- | --- | --- |
| Experience worth playing | Responsive movement, readable combat, a secret and a complete short adventure | Ordinary-input full playthrough and two-person playtest observations |
| A new way to play | Same world rendered as Ember ruins and Moss overgrowth on two screens | Side-by-side live views of the same bridge/enemy state |
| Interaction with other people | Distinct-player anchor restoration, partner rescue and optional Cross-stitch combat payoff | Two independent devices and two people completing the action |
| Responsive storytelling | Restoring the Lantern Loom visibly reconnects the village | State change, NPC response and ending in the actual build |

The two themes alone are a presentation hook. Cooperative restoration and rescue give the theme an actual player relationship. Avoid making one player stand still at switches for most of the game; both should move, fight and choose actions.

## Other tracks

- **Works Anyway:** optional secondary fit if offline local play is treated as an explicit connectivity constraint and demonstrated with networking disabled. Merely saying “offline” on a slide is insufficient. Do not dilute the primary pitch to chase this track.
- **Kill the Busywork:** the game does not directly complete an annoying real-world workflow; no claim needed.
- **Make the Invisible Visible:** different artwork is not enough to claim useful detection and action under this track; no claim needed.

The provided PDF does not state a mandatory Luna API integration. If a separate organizer brief imposes one, verify that text and adjust the task explicitly. Agent-authored development and runtime AI are different things; never claim an API is used by the shipped game if it is not.

## Fun hypotheses and revision triggers

These are targets to test, not statements already proven:

1. Within 30 seconds of joining, both players can move and jump with visible ownership of their character.
2. Within roughly 90 seconds of play, they encounter the first clear cooperative payoff.
3. Each room introduces, develops, tests, rewards or gives rest; the return shortcut materially reduces repeated travel.
4. Both can defeat normal enemies and make progress without the other acting as a permanent damage dealer or permanent helper.
5. A failed rescue or boss attempt has an understandable cause and a quick retry.
6. The theme contrast is noticeable but neither side has worse platform/hazard visibility.

Observe at least two fresh pairs before declaring the eight-room MVP's human-playtest gate passed. Early single-pair feedback is useful but does not complete that gate. Record confusion, inactive time, repeated unreadable damage and whether they voluntarily want another attempt. Ask each person which moment was enjoyable and which felt like waiting. Revise the problematic room or mechanic; do not treat a numerical satisfaction score as proof of universal fun.

## A three-minute live demonstration

| Time | Show | Say |
| --- | --- | --- |
| 0:00–0:20 | Two people join, each moves a different courier | “Two couriers carry opposite ends of one living thread.” |
| 0:20–0:50 | Same landmark in Ember and Moss, same moving enemy | “We see the kingdom differently, but every physical action is shared.” |
| 0:50–1:30 | Both reach separate anchors and restore one bridge | “The world changes when we cooperate.” |
| 1:30–2:10 | Brief combat and a partner rescue | “Both players fight; either can save the other.” |
| 2:10–2:45 | Short prepared route to restoration payoff | “The goal is to reconnect a village, not collect an endless checklist.” |
| 2:45–3:00 | Ending/replay card and a brief Phase 2 statement | “Next, your drawing will shape your courier and its visual theme.” |

Use a documented showcase save for a short presentation if needed, and identify it as such. Keep a fresh-save full playthrough as separate evidence. A generated portrait/mockup is not proof that the future generation pipeline is implemented.

## Submission language

**One sentence:** Gloamthread: Two Ends is a local split-screen adventure where two couriers see the same unraveling kingdom differently and restore it together through combat, rescue and living-thread bridges.

**What the first build proves:** fixed characters, original authored content, two independent inputs, two themed views, shared physical consequences and a complete short cooperative story.

**What remains later:** uploaded/drawn characters, generation of new character artwork and theme assets, independent cross-room travel, online play and the 96-room production world.
