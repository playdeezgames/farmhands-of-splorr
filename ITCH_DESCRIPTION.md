# itch.io page copy: Farmhands of SPLORR!!

Page: https://thegrumpygamedev.itch.io/farmhands-of-splorr (**does not exist yet**; the slug is a guess until the page is made, by the user in the dashboard or through Chrome on request). First release booked in Coxswain for December 6, 2026 (#43); ship only on the user's "ship".
**Draft, written November 26, 2026 (updated the same day for crows, scarecrows and their weathering, wandering cats, moving and letting go, Space as the action key, and soil nutrients, rotation, manure and rotting); the user has not approved any of it.** Pasted in by hand; nothing here is published by the repo. Cover: `assets/cover.png` (630 by 500, the title over a farm in progress). Screenshots: `assets/screenshots/01-new-farm.png`, `02-farm.png`, `03-rats.png` (a bad turn: rats, crows and a cat gone; the screen at 2x, 960 by 540; `tools/make_shots.sh` remakes them).

## Short description (the one-line field)

Plant crops, hire farmhands, keep them fed. A small turn-based farm on an 8 by 8 field.

(87 characters; itch.io allows 120.)

## Page text

**Latest version:** https://playdeezgames.github.io/farmhands-of-splorr/

**Farmhands of SPLORR!!** is a small turn-based farm. Yer field is 8 by 8, but ye start with only the four squares in the middle.

- **Plant crops.** Carrots, wheat, cabbage, corn and pumpkins each cost a little, take a few turns to ripen and sell for more.
- **Hire farmhands.** A fed farmhand makes every crop in the eight squares around them grow twice as fast. Pick one up and set them down somewhere better (they take a turn to settle in), or let them go.
- **Feed them.** Farmhands eat from the barn every turn. One that goes hungry does no work, and one hungry for too long quits.
- **Sell or keep seed.** Harvests go to the barn. Sell them, or turn one back into seeds and plant for free. Don't leave ripe crops standing: they rot.
- **Mind the soil.** Every square holds N, P and K. Each crop takes one and puts a little of another back, so rotate them; a crop short of what it needs grows at half speed. Manure fills a tired square back up.
- **Buy land.** Each new square costs more than the last.
- **Mind the barn.** It holds only so much (the rest is sold at harvest), and the bigger ye build it, the more the rats like it. Cats help, but cats wander off.
- **Mind the crows.** They peck at any crop a scarecrow isn't watching. A scarecrow guards the 5 by 5 around it, until the weather wears it down and it falls apart.

This Metaphor is a demo. There is no goal but a bigger farm.

### How to play

Arrows move, Space acts (on a farmhand or scarecrow it picks them up), 1 to 8 (or Q and E) pick a farmhand, crop, scarecrow or manure, X sells one, A sells all, Z keeps seed, B builds the barn bigger, C buys a cat, D lets a farmhand or scarecrow go, T ends the turn, N starts a new farm, M turns the sound off. Mouse and touch: tap anything. A gamepad works too. The farm is saved in yer browser.

**AI disclosure:** made with Claude Code. Claude wrote the code and the text and made the sounds and the numbers in the Anvil of SPLORR!!, at the author's direction. The tiles and the fonts are by people (credits below).

### Credits

- Tiles: Urizen 1-bit tileset by vurmux (CC0)
- Font: DINOBYTE by mby (CC BY 4.0); cover title in Public Pixel by GGBotNet (CC0)
- Sounds: made in the Anvil of SPLORR!!
- Source: https://github.com/playdeezgames/farmhands-of-splorr
- TheGrumpyGameDev, with Claude Code (AI).

*This page was set up by Claude, an AI agent (Claude Code), on behalf of The Grumpy GameDev.* (Keep this line only if an agent pastes or edits the page.)

## Page settings (by hand, when the time comes)

- Kind of project: HTML. Tick "played in the browser". Uploads: only the `html` channel.
- Pricing: no payments (free demo).
- Embed: "Click to launch in fullscreen" (the user's rule for every game, November 13, 2026). Mobile friendly: yes, landscape orientation.
- External link: `Latest version (GitHub Pages)` to https://playdeezgames.github.io/farmhands-of-splorr/
- Classification: Games. Release status: In development. Genre: Simulation. Custom noun: **Metaphor**.
- Tags: farming, turn-based, management, pixel-art, 1-bit, casual, retro, crows.
- AI disclosure field: Yes (Code, Sounds, Text).
- Feedback: the footer's "Send feedback" link and the F key stay hidden until a LootLocker game exists (the user's call). If one is made, put its domain and key in `web/index.html` (`LL_DOMAIN`, `LL_KEY`), add `https://playdeezgames.github.io` and `https://html-classic.itch.zone` to its CORS Allowlist and give it feedback categories.
