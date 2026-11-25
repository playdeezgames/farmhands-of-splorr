# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

**Farmhands of SPLORR!!**, a demo started November 25, 2026 by TheGrumpyGameDev (built by Claude Code at the user's direction). A turn-based farm on an 8 by 8 grid: the player buys and places farmhands and crops; each crop takes a number of turns to ripen; a fed farmhand makes every crop in the eight cells around them grow faster; harvested crops go to the barn, where they are sold or turned back into seeds; farmhands eat from the barn every turn, and a farmhand hungry for too long quits.

The vault at `/home/yermom/git/bok-of-splorr/splorr/` is the shared body of knowledge for all SPLORR!! games and holds the standing rules. Read its `Home.md` first. This game's note is `Games/Farmhands of SPLORR!!.md`; when a fact about the game changes, update that note and its `Home.md` row too.

## Commands

```bash
tools/test.sh                  # native tests, wasm checks, then a real wasm build
tools/build.sh [--size]        # wasm build into build/web
tools/serve.sh                 # build and serve on http://localhost:${PORT:-8000}/
tools/pages.sh                 # tests, size build, copy into docs/ for GitHub Pages; never commits or pushes
./shippit.sh [--push]          # tests, size build, zip; butler push only with --push (only on the user's "ship")
python3 -I tools/gen_assets.py [--sheet out.png]  # regenerate src/game/data.odin, gfx.odin, font.odin
odin test src/game -collection:tggd=src -define:DUMP_PLAY=/tmp/frame.ppm   # render a frame of a farm
python3 -I tools/make_cover.py /tmp/frame.ppm      # assets/cover.png from that frame
```

The browser pane's launch config `farmhands-web` (port 8770, in the vault's `.claude/launch.json`) serves `build/web`; run `tools/build.sh` first.

## Architecture

Odin compiled to `js_wasm32`, a 480 by 270 software framebuffer of palette indices drawn to a canvas (no WebGL). The layout follows Cluster Conquerors of SPLORR!!.

- **The Anvil holds the data and the sounds.** The Anvil world `farmhands.json` (copy in `assets/anvil/world.json`): item types `farmer` (cost, boost, appetite, patience) and the five crops (cost, grow, price, seeds, food), the param `start_money`, the 8 by 8 map `farm` (terrain set `field`, all soil for now), and ten PLAY-text sounds exported to `assets/sfx/`. To change a number: change it in the Anvil, `world_export` to `assets/anvil/world.json`, run `tools/gen_assets.py`. Never hand-edit `data.odin`, `gfx.odin` or `font.odin`.
- **Art:** Urizen 1-bit tiles (CC0, vurmux) picked in `PICKS` in `tools/gen_assets.py`, kept as masks and painted in palette colours; field cells draw them at 2x. Font: DINOBYTE (CC BY 4.0, mby). The palette is Sweetie-16 with two soil browns in place of its teal and navy.
- `src/game/` (pure, no `core:os`/`core:fmt`): `game.odin` (the `Game` struct, `Command`, `act`/`plant`/`hire`/`harvest`/`sell`/`make_seeds`, `end_turn`: farmhands eat first (cheapest meal per dollar; a crop's extra meals go to the pantry), then each crop grows 1 plus `FARMER_BOOST` per fed neighbouring farmhand), `render.odin` (layout, `pointer` hit-testing, drawing), `sounds.odin` (`Sfx`, picked from the `events` of the last input), `save.odin` (the whole `Game` behind a header), `screen.odin` (frame, palette, drawing). Tests are `*_test.odin` with `#+build !js`.
- `src/web/web.odin` is the thin browser layer; `web/index.html` maps keys, mouse/touch (everything is clickable on the canvas) and the gamepad, plays the WAVs and saves to localStorage (`fhos-save`). The `C` table and `SFX` list there must match `Command` and `Sfx`.

## Standing rules (full text in the vault's `Home.md`)

- **"Push" means `git push`; "ship" means itch.io.** Neither without the user saying that word. One ship a day through Coxswain.
- **GitHub Pages first**; making the repo public and enabling Pages are the user's call. No 1-Bit Kingdom art here.
- Release standard: `ITCH_DESCRIPTION.md`, `assets/cover.png`, `assets/screenshots/`, `devlog/YYYYMMDD/`, `tools/ship.sh` + `shippit.sh`. Footer back links, AI disclosure and "Send feedback" (LootLocker game not set up yet).
- In player-facing text the game is a **"Metaphor"** and the voice says **"yer"**.
- Do not describe or "fix" deliberate design as a problem once the user has decided it.
