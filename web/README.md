# Gloamthread website

The website is a static enhancement around the existing Godot browser export.
It uses original project artwork, a deterministic Three.js diorama, and a player
guide generated from `docs/PLAYER_GUIDE.md`. The gameplay canvas and website
renderer have separate lifecycles.

## Build

Use Node.js 22 or later (the release Docker exporter pins Node 24.22.1):

```sh
npm --prefix web ci
npm --prefix web run build
```

The build produces `build/web-site/`. The complete playable release is assembled
by the Python exporter; serve that output rather than this partial directory:

```sh
python3 tools/package_web.py
python3 -m http.server 8085 --directory build/web
```

Use `--allow-dirty` on the Python exporter only for explicitly labelled local QA.
The public release requires a clean committed checkout. `web/.gdignore` keeps
website dependencies and assets out of Godot's resource import; the export
template remains an explicitly read HTML file.

## Build interface

`build.mjs` bundles JavaScript, CSS, lazy 3D chunks and imported assets into flat
content-hashed `site-*` filenames. No runtime dependency CDN is used. It renders
the guide with shared website styles, copies its explicitly referenced original
public screenshots, rewrites technical links to repository documents, and
generates `help.html` with heading anchors and a contents navigation.

The private build manifest `site-manifest.json` contains `schema_version: 1`, an
exact `files` inventory, a SHA-256 `hashes` entry for each file, and the shell
replacement map `@@SITE_SCRIPT@@`, `@@SITE_STYLE@@`, `@@SITE_POSTER@@` and
`@@SITE_FAVICON@@`. The Python exporter validates and copies only those files;
the intermediate manifest itself is not served. Failed builds preserve the
previous website directory. Unexpected files or symlinks in that directory
stop replacement.

The guide preserves Markdown-generated anchors and additionally exposes
`#start-playing`, `#modes`, `#controls`, `#create-a-fighter`, `#saves`,
`#accessibility` and `#troubleshooting` for website navigation. `#arena-story`
and `#saves-backups` are compatibility aliases. The build rejects broken internal
anchors, duplicate IDs and unresolved template placeholders.

## Original media and font

`assets/favicon.svg` is an original angular thread mark authored for this site.
The diorama geometry and animation are authored in this project; its fighter
textures come from the public built-in character library. `assets/poster.webp`
is the static fallback; release preparation captures it from the actual 3D
renderer, rather than presenting a concept illustration as rendered output.

`assets/display.woff2` is derived from the project's original 5×7 bitmap glyphs
in `assets/source/art/glyphs.json`. Rebuild it deliberately with the optional
authoring dependencies below; ordinary builds use the committed font:

```sh
python3 -m venv /tmp/gloam-web-font
/tmp/gloam-web-font/bin/pip install fonttools==4.67.0 brotli==1.2.0
/tmp/gloam-web-font/bin/python tools/web_font.py
```

The font compiler fixes TrueType timestamps for reproducible output. Website
artwork and the font retain the project's MIT license; Three.js retains its MIT
license and attribution in the public notices. No private drawings, creation
jobs, invitations, credentials or external art packs belong in this build.
