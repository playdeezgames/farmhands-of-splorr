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
tools/make_shots.sh            # assets/screenshots/ from the frame dump's scenes 1 to 3
odin test src/game -collection:tggd=src -define:DUMP_PLAY=/tmp/frame.ppm   # render a frame of a farm (scene 2)
python3 -I tools/make_cover.py /tmp/frame.ppm      # assets/cover.png from that frame
```

The browser pane's launch config `farmhands-web` (port 8770, in the vault's `.claude/launch.json`) serves `build/web`; run `tools/build.sh` first.

## Architecture

Odin compiled to `js_wasm32`, a 480 by 270 software framebuffer of palette indices drawn to a canvas (no WebGL). The layout follows Cluster Conquerors of SPLORR!!.

- **The Anvil holds the data and the sounds.** The Anvil world `farmhands.json` (copy in `assets/anvil/world.json`): item types `farmer` (cost, boost, appetite, patience) and the five crops (cost, grow, price, seeds, food), the item types `cat` (cost, deter_percent, wander_percent) and `scarecrow` (cost, radius), the params `start_money`, `land_price`, `land_growth_percent`, `barn_capacity`, `barn_step`, `barn_price`, `barn_growth_percent`, `rat_base_percent`, `rat_step_percent` and `crow_percent`, the 8 by 8 map `farm` (terrain set `field`: `soil` is owned at the start, the middle four squares; `wild` must be bought), and seventeen PLAY-text sounds exported to `assets/sfx/`. To change a number: change it in the Anvil, `world_export` to `assets/anvil/world.json`, run `tools/gen_assets.py`. Never hand-edit `data.odin`, `gfx.odin` or `font.odin`.
- **Art:** Urizen 1-bit tiles (CC0, vurmux) picked in `PICKS` in `tools/gen_assets.py`, kept as masks and painted in palette colours; field cells draw them at 2x. Font: DINOBYTE (CC BY 4.0, mby). The palette is Sweetie-16 with two soil browns in place of its teal and navy.
- `src/game/` (pure, no `core:os`/`core:fmt`): `game.odin` (the `Game` struct, `Command`, `act`/`plant`/`hire`/`harvest`/`sell`/`make_seeds`, `end_turn`: farmhands eat first (cheapest meal per dollar; a crop's extra meals go to the pantry), then each crop grows 1 plus `FARMER_BOOST` per fed neighbouring farmhand; land: each `Cell` is `owned` or wild, `can_buy` needs owned land on a side, `land_price` starts at `LAND_PRICE` and grows `LAND_GROWTH_PERCENT` per square bought, rounded up; acting on wild land buys it; the barn: `barn_capacity` crops, a harvest into a full barn is sold at once, `expand_barn` (price from `grown`, like land), `rat_chance` = base + step per expansion - deter per cat, clamped 0 to 100, rolled every turn after feeding from the game's `Rng` (seeded by the page), `rats_feast` eats half of each crop rounded up and half the pantry; `buy_cat`; after the rats, each cat wanders off at `CAT_WANDER_PERCENT`, then crows eat each crop no scarecrow guards at `CROW_PERCENT` (`guarded`: a `.Scarecrow` cell within `SCARECROW_RADIUS` across and down; `place_scarecrow` is the 7th tool); `pick_up`/`set_down`/`put_back` carry a farmhand or scarecrow (`carrying`, `carry_cell`; a farmhand set down elsewhere is `moved` and gives no boost until the next turn; `end_turn` puts back whatever is in hand), `dismiss` (D) lets one go with no refund), `render.odin` (layout, `pointer` hit-testing, drawing), `sounds.odin` (`Sfx`, picked from the `events` of the last input), `save.odin` (the whole `Game` behind a header), `screen.odin` (frame, palette, drawing). Tests are `*_test.odin` with `#+build !js`.
- `src/web/web.odin` is the thin browser layer; `web/index.html` maps keys, mouse/touch (everything is clickable on the canvas) and the gamepad, plays the WAVs and saves to localStorage (`fhos-save`). The `C` table and `SFX` list there must match `Command` and `Sfx`.

## Standing rules (full text in the vault's `Home.md`)

- **"Push" means `git push`; "ship" means itch.io.** Neither without the user saying that word. One ship a day through Coxswain.
- **GitHub Pages:** live since November 25, 2026 at https://playdeezgames.github.io/farmhands-of-splorr/ (public repo `playdeezgames/farmhands-of-splorr`, served from `main` `/docs`). To update: `tools/pages.sh`, commit `docs/`, push (each push needs the user's go-ahead). Public repo: no 1-Bit Kingdom art, ever.
- Release standard: `ITCH_DESCRIPTION.md`, `assets/cover.png`, `assets/screenshots/`, `devlog/YYYYMMDD/`, `tools/ship.sh` + `shippit.sh`. Footer back links and AI disclosure; the "Send feedback" link and F stay hidden until a LootLocker game exists (`LL_DOMAIN`/`LL_KEY` in `web/index.html`; the user's call).
- **itch.io:** first release booked in Coxswain for December 6, 2026 (#43). Page copy and devlog are drafts in `ITCH_DESCRIPTION.md` and `devlog/20261206/`; the itch page does not exist yet.
- In player-facing text the game is a **"Metaphor"** and the voice says **"yer"**.
- Do not describe or "fix" deliberate design as a problem once the user has decided it.
