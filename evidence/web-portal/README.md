# Living 3D website release

Public website: **[gloamthread.midhunpm.in](https://gloamthread.midhunpm.in)**.
Player help: **[help.html](https://gloamthread.midhunpm.in/help.html)**.
Implementation: [`37f5bff1f056c7811bb84a4260c1f95ee660d03d`](https://github.com/9MidhunPM/GloamThread/commit/37f5bff1f056c7811bb84a4260c1f95ee660d03d),
immutable tag **web-v0.6.1-resume**. Later evidence/documentation commits do not
change this deployed payload. [Build and operations](../../docs/WEB_RELEASE.md).

## Implemented behavior

The website has an original deterministic Three.js miniature, public fighter
sprites, lantern/thread/particle motion, bounded pointer interaction, Arena/Story
previews, staggered entrances and a motion control. A real renderer capture is
the still fallback; the design concept is never presented as a runtime capture.
The display font derives reproducibly from the game's owned bitmap glyphs.

Game assets download after Play. The website renderer is disposed before Godot
starts; Home retains the paused game with the still poster. The browser shell
keeps the existing six-method bridge, logical mode sizes, storage warnings and
explicit manual startup recovery. The guide is generated from Markdown with
validated aliases, seven concise navigation entries and mobile contents.

## Source and packaging checks

[Source-check record](source-checks.json) contains commands, engine/dependency
versions, durations and log hashes from the 2026-10-29 rerun at the original
portal revision `8390db8`. The subsequent shell-only focus/scroll correction
leaves all Godot scripts, scenes, game assets and project settings unchanged;
its real-click regression is recorded in [the resume report](resume-regression.json).
All source-baseline checks pass: **246 Python tests without skips**, **17 packaging
tests**, **23 Arena scenarios**, **178 native Forge assertions**, **50 browser
boundary assertions**, editor import, content/retained/world/scenery validation,
website build and dependency audit. No deterministic content rebuild or paid
provider request was made.

The final local export used:

```sh
npm --prefix web ci
python3 tools/package_web.py --output build/web-final
```

It recorded `dirty_qa_build=false`, exact source identity and 30 public file
hashes. Production uses official Godot 4.7.2 on ARM64; local checks use the Arch
4.7.2 build with the same engine revision. Website dependency versions are
locked in the source. [Deployment snapshot](deployment.json) records the
successful Dokploy rollout and retained services; no volumes were recreated.

## Public verification

The retained [BUILD](BUILD.json), [public integrity report](public-integrity.json),
[Chromium report](chromium.json), [Firefox report](firefox.json) and
[visual-check report](visual-checks.json) describe the actual deployed revision.

The integrity check compares all public sizes/SHA-256 values, records cache/MIME
headers, scans for known private credential/invite values without exposing them,
and checks web and Forge readiness. Rerun it with:

```sh
python3 evidence/web-portal/verify_public.py
```

The integrity verifier uses the host's `curl` HTTPS route because a direct Python
HTTPS route stalled on a CDN address in this environment. It compares actual
decompressed response bytes; it does not infer integrity from health or HEAD.

The browser scripts use isolated contexts and actual canvas mouse/keyboard
input. They cover deferred engine downloads, real title/Story return/solo
combat, pause, Home/Resume and guide retention. Renderer disposal is checked
separately from gameplay. Website checks cover the real scene, tabs, persisted
motion-off, OS reduced motion, guide alias highlighting and desktop table width,
plus a 390×844 touch viewport without overflow or a misleading drag hint.

Install Playwright separately under ignored build output if needed, then set
`PLAYWRIGHT_MODULE` to that installation's module path. Browser availability and
the actual software-rendering setup are recorded in the browser report. For
example, the standalone website check is:

```sh
PLAYWRIGHT_MODULE="$PWD/build/browser-qa/node_modules/playwright" node evidence/web-portal/visual-checks.cjs
```

Browser/IAB was unavailable in this Linux environment (the native CUA operation
is unsupported), so Playwright was used. Native-size design comparison and
intentional adaptations are recorded in [the visual review](visual-review.md).

## Evidence boundaries

These automated checks are separate from human play, audible listening,
physical controller/hotplug testing or a physical frame-rate claim. Mobile
website navigation is supported; mobile touch gameplay, Safari certification,
online multiplayer and cloud/offline-reload saves are outside this release.
A complete 20-wave browser route was not added in this milestone.

Earlier local precommit routes also exercised controlled loader/stall/storage/
fullscreen failures, Story checkpoint reload, co-op wave-one readiness and
six-file fighter ZIP integrity. Their temporary artifacts were lost during the
session interruption. They remain recorded in the implementation changelog;
the durable reports here are the fresh source/public checks, not reconstructed
reports of those earlier runs. An initial Firefox Home/Resume timeout
was reproduced during final verification. Pointer tracing showed smooth
scrolling moving Resume between press and release. Focus suppression alone was
insufficient; guide-only smooth scrolling resolved the isolated failure. The
regression report preserves the failed attempts and the controlled probe; current
patched-source/public results are reported separately.

The original 2026-10-27 [browser release evidence](../web-release/README.md)
retains the earlier hosted-generation, backup/restore and full native route
boundaries. No new generation or production restore was needed for the portal.

## Resume regression

The original portal (`8390db8`) and focus-only patch (`36a0f3e`) failed the same
Firefox pointer loop. A controlled CSS probe passed 35 cycles; the actual clean
`37f5bff` source then passed 50 cycles without injected styles. The deployed patch
passes ten rapid cycles in each browser. See [the retained regression history](resume-regression.json).
