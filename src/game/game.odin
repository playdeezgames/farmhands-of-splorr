package game

// The rules: an 8 by 8 field, crops and farmers placed by the player, a barn, money and turns.
// Pure: no core:os, no core:fmt. The numbers come from the Anvil world through data.odin.

FIELD_W :: 8
FIELD_H :: 8

Cell_Kind :: enum u8 {
	Empty,
	Crop,
	Farmer,
	Scarecrow,
}

Cell :: struct {
	owned:    bool, // bought land; wild land must be bought before anything goes on it
	kind:     Cell_Kind,
	crop:     Crop, // when kind is Crop
	progress: u8, // growth so far in half turns; ripe at 2 * CROPS[crop].grow
	rot:      u8, // ripe crop: turns left in the field; rots at CROPS[crop].keep
	hunger:   u8, // farmer: hungry turns in a row
	fed:      bool, // farmer: ate this turn, so tends the neighbours
	moved:    bool, // farmer: set down this turn, so settles in and works from the next
	health:   u8, // scarecrow: the weather wears it down; at 0 it falls apart
}

// What the player has in hand: a farmer to hire or a crop to plant.
Tool :: enum u8 {
	Farmer,
	Carrot,
	Wheat,
	Cabbage,
	Corn,
	Pumpkin,
	Scarecrow,
	Manure,
}

tool_crop :: proc(t: Tool) -> (Crop, bool) {
	if t == .Farmer || t == .Scarecrow || t == .Manure {
		return .Carrot, false
	}
	return Crop(u8(t) - 1), true
}

// Commands from keys, gamepad and buttons. The page's C table must match this order.
Command :: enum u8 {
	North,
	South,
	West,
	East,
	Confirm, // act on the cursor cell: plant, hire or harvest
	Next_Tool,
	Prev_Tool,
	Sell, // one of the selected crop from the barn
	Sell_All,
	Seeds, // turn one of the selected crop back into seeds
	End_Turn,
	New_Farm,
	Tool_1,
	Tool_2,
	Tool_3,
	Tool_4,
	Tool_5,
	Tool_6,
	Expand_Barn,
	Buy_Cat,
	Dismiss, // let the farmhand or scarecrow under the cursor (or in hand) go
	Tool_7,
	Tool_8,
}

LOG_LINES :: 4
LOG_COLS :: 78

Log_Line :: struct {
	text:  [LOG_COLS]u8,
	len:   u8,
	color: u8,
}

// Things that happened during the last command, for the sound picker.
Event :: enum u8 {
	Moved,
	Bought,
	Planted,
	Hired,
	Harvested,
	Sold,
	Seeded,
	Turned,
	Hungry,
	Quit,
	Denied,
	Rats,
	Cat,
	Built,
	Wandered,
	Crows,
	Placed,
	Carried,
	Dismissed,
	Fell,
	Rotted,
	Manured,
}

Game :: struct {
	field:    [FIELD_W * FIELD_H]Cell,
	money:    int,
	barn:     [Crop]int, // harvested crops
	seeds:    [Crop]int, // seeds kept back
	pantry:   int, // meals left over from a crop already eaten
	turn:     int,
	cursor_x: int,
	cursor_y: int,
	tool:     Tool,
	confirm_new: bool, // New_Farm pressed once; a second press starts over
	log:      [LOG_LINES]Log_Line,
	events:   bit_set[Event],
	// Totals for the panel.
	harvested: int,
	earned:    int,
	quits:     int,
	land_bought: int, // squares bought so far; each costs more than the last
	barn_level:  int, // expansions bought; each holds BARN_STEP more and draws more rats
	cats:        int,
	rng:         Rng, // the rats, the cats and the crows
	// A farmhand or scarecrow picked up: what it was and where it came from.
	carrying:    Cell_Kind, // .Empty when nothing is in hand
	carry_x:     int,
	carry_y:     int,
	carry_cell:  Cell,
	// N, P and K on each square. Kept apart from the cells so it stays with the land when what
	// stands on it is planted, harvested, moved or let go.
	soil:        [FIELD_W * FIELD_H][Nutrient]u8,
}

Nutrient :: enum u8 {
	N,
	P,
	K,
}

NUTRIENT_NAME := [Nutrient]string{.N = "N", .P = "P", .K = "K"}

soil_at :: proc(g: ^Game, x, y: int) -> ^[Nutrient]u8 {
	return &g.soil[y * FIELD_W + x]
}

// The first nutrient the crop at (x, y) needs more of than the square has; a short crop grows at half speed.
short_of :: proc(g: ^Game, x, y: int) -> (Nutrient, bool) {
	c := cell_at(g, x, y)
	if c.kind != .Crop {
		return .N, false
	}
	soil := soil_at(g, x, y)
	for n in Nutrient {
		if int(soil[n]) < CROPS[c.crop].uses[int(n)] {
			return n, true
		}
	}
	return .N, false
}

// The soil pays for a crop that was harvested or rotted: its uses come out, its gives go back.
pay_soil :: proc(g: ^Game, x, y: int, crop: Crop) {
	soil := soil_at(g, x, y)
	for n in Nutrient {
		v := int(soil[n]) - CROPS[crop].uses[int(n)] + CROPS[crop].gives[int(n)]
		soil[n] = u8(clamp(v, 0, SOIL_MAX))
	}
}

add_soil :: proc(g: ^Game, x, y, amount: int) {
	soil := soil_at(g, x, y)
	for n in Nutrient {
		soil[n] = u8(min(int(soil[n]) + amount, SOIL_MAX))
	}
}

soil_full :: proc(g: ^Game, x, y: int) -> bool {
	for v in soil_at(g, x, y) {
		if int(v) < SOIL_MAX {
			return false
		}
	}
	return true
}

// Spreads manure on an owned square, empty or under a crop.
manure :: proc(g: ^Game, x, y: int) -> bool {
	c := cell_at(g, x, y)
	if !c.owned {
		return false
	}
	t: Text
	if soil_full(g, x, y) {
		say(g, "The soil is already rich.", COLOR_LIGHT)
		g.events += {.Denied}
		return false
	}
	if g.money < MANURE_COST {
		add(&t, "Manure costs $")
		add_int(&t, MANURE_COST)
		add(&t, ".")
		say(g, text_of(&t), COLOR_RED)
		g.events += {.Denied}
		return false
	}
	g.money -= MANURE_COST
	add_soil(g, x, y, MANURE_AMOUNT)
	add(&t, "Spread manure for $")
	add_int(&t, MANURE_COST)
	add(&t, ". The soil is richer.")
	say(g, text_of(&t), COLOR_LIME)
	g.events += {.Manured}
	return true
}

init_game :: proc(g: ^Game, seed: u64 = 1) {
	g^ = {}
	g.rng = {seed}
	g.money = START_MONEY
	g.turn = 1
	g.cursor_x = FIELD_W / 2 - 1
	g.cursor_y = FIELD_H / 2 - 1
	g.tool = .Carrot
	for t, i in FIELD_TERRAIN {
		g.field[i].owned = t == .Soil
		g.soil[i] = {.N = SOIL_MAX, .P = SOIL_MAX, .K = SOIL_MAX}
	}
	say(g, "Welcome to the farm. Plant crops, hire farmhands, feed them.", COLOR_YELLOW)
	say(g, "Farmhands make the crops around them grow twice as fast.", COLOR_LIGHT)
	say(g, "Crows eat crops: scarecrows! Rats raid the barn: cats! Buy land.", COLOR_LIGHT)
	say(g, "Crops tire the soil: rotate them, or spread manure. Ripe crops rot.", COLOR_LIGHT)
}

cell_at :: proc(g: ^Game, x, y: int) -> ^Cell {
	return &g.field[y * FIELD_W + x]
}

ripe :: proc(c: Cell) -> bool {
	return c.kind == .Crop && int(c.progress) >= 2 * CROPS[c.crop].grow
}

// --- The log: the newest line at the bottom.

say :: proc(g: ^Game, text: string, color: u8 = COLOR_WHITE) {
	for i in 0 ..< LOG_LINES - 1 {
		g.log[i] = g.log[i + 1]
	}
	line := &g.log[LOG_LINES - 1]
	line^ = {}
	n := min(len(text), LOG_COLS)
	for i in 0 ..< n {
		line.text[i] = text[i]
	}
	line.len = u8(n)
	line.color = color
}

log_text :: proc(l: ^Log_Line) -> string {
	return string(l.text[:l.len])
}

// --- Actions. Each returns false when refused; a refused action changes nothing.

// Acts on the cursor cell with the tool in hand.
act :: proc(g: ^Game) -> bool {
	c := cell_at(g, g.cursor_x, g.cursor_y)
	if g.carrying != .Empty {
		return set_down(g, g.cursor_x, g.cursor_y)
	}
	if !c.owned {
		return buy_land(g, g.cursor_x, g.cursor_y)
	}
	if g.tool == .Manure && (c.kind == .Empty || c.kind == .Crop) {
		return manure(g, g.cursor_x, g.cursor_y)
	}
	switch c.kind {
	case .Crop:
		if ripe(c^) {
			return harvest(g, g.cursor_x, g.cursor_y)
		}
		info := CROPS[c.crop]
		t: Text
		add(&t, info.name)
		add(&t, ": ")
		add_halves(&t, int(c.progress))
		add(&t, " of ")
		add_int(&t, info.grow)
		add(&t, " grown.")
		say(g, text_of(&t), COLOR_LIGHT)
		g.events += {.Denied}
		return false
	case .Farmer, .Scarecrow:
		return pick_up(g, g.cursor_x, g.cursor_y)
	case .Empty:
	}
	if crop, ok := tool_crop(g.tool); ok {
		return plant(g, g.cursor_x, g.cursor_y, crop)
	}
	if g.tool == .Scarecrow {
		return place_scarecrow(g, g.cursor_x, g.cursor_y)
	}
	return hire(g, g.cursor_x, g.cursor_y)
}

// --- Moving and letting go: a farmhand or scarecrow is picked up, then set down on empty soil.

pick_up :: proc(g: ^Game, x, y: int) -> bool {
	c := cell_at(g, x, y)
	if g.carrying != .Empty || (c.kind != .Farmer && c.kind != .Scarecrow) {
		return false
	}
	g.carrying = c.kind
	g.carry_x, g.carry_y = x, y
	g.carry_cell = c^
	c^ = {owned = true}
	say(g, g.carrying == .Farmer ? "Picked up a farmhand. Press Space on empty soil to set them down." : "Picked up the scarecrow. Press Space on empty soil to set it down.", COLOR_CYAN)
	g.events += {.Carried}
	return true
}

// Sets down what is in hand. Back where it came from is not a move; a farmhand set down anywhere
// else settles in and works from the next turn.
set_down :: proc(g: ^Game, x, y: int) -> bool {
	if g.carrying == .Empty {
		return false
	}
	c := cell_at(g, x, y)
	if !c.owned || c.kind != .Empty {
		say(g, "Set it down on empty soil first.", COLOR_RED)
		g.events += {.Denied}
		return false
	}
	home := x == g.carry_x && y == g.carry_y
	c^ = g.carry_cell
	if g.carrying == .Farmer {
		if home {
			say(g, "Put the farmhand back.", COLOR_CYAN)
		} else {
			c.moved = true
			c.fed = false
			say(g, "Set the farmhand down. They settle in and work next turn.", COLOR_CYAN)
		}
	} else {
		say(g, "Set the scarecrow down.", COLOR_CYAN)
	}
	g.carrying = .Empty
	g.carry_cell = {}
	g.events += {.Carried}
	return true
}

// Whatever is in hand goes back where it came from (end of turn).
put_back :: proc(g: ^Game) {
	if g.carrying == .Empty {
		return
	}
	cell_at(g, g.carry_x, g.carry_y)^ = g.carry_cell
	say(g, g.carrying == .Farmer ? "Put the farmhand back." : "Put the scarecrow back.", COLOR_CYAN)
	g.carrying = .Empty
	g.carry_cell = {}
}

// Lets go of what is in hand, or of the farmhand or scarecrow under the cursor. No refund.
dismiss :: proc(g: ^Game) -> bool {
	kind := g.carrying
	if kind != .Empty {
		g.carrying = .Empty
		g.carry_cell = {}
	} else {
		c := cell_at(g, g.cursor_x, g.cursor_y)
		if c.kind != .Farmer && c.kind != .Scarecrow {
			say(g, "Nothing here to let go.", COLOR_RED)
			g.events += {.Denied}
			return false
		}
		kind = c.kind
		c^ = {owned = true}
	}
	say(g, kind == .Farmer ? "Let a farmhand go." : "Took down the scarecrow.", COLOR_ORANGE)
	g.events += {.Dismissed}
	return true
}

place_scarecrow :: proc(g: ^Game, x, y: int) -> bool {
	c := cell_at(g, x, y)
	if c.kind != .Empty || !c.owned {
		return false
	}
	t: Text
	if g.money < SCARECROW_COST {
		add(&t, "A scarecrow costs $")
		add_int(&t, SCARECROW_COST)
		add(&t, ".")
		say(g, text_of(&t), COLOR_RED)
		g.events += {.Denied}
		return false
	}
	g.money -= SCARECROW_COST
	c^ = {owned = true, kind = .Scarecrow, health = SCARECROW_HEALTH}
	add(&t, "Put up a scarecrow for $")
	add_int(&t, SCARECROW_COST)
	add(&t, ". It guards the ")
	add_int(&t, SCARECROW_RADIUS * 2 + 1)
	add(&t, "x")
	add_int(&t, SCARECROW_RADIUS * 2 + 1)
	add(&t, " around it.")
	say(g, text_of(&t), COLOR_CYAN)
	g.events += {.Placed}
	return true
}

// True when a scarecrow stands within SCARECROW_RADIUS of (x, y) across and down.
guarded :: proc(g: ^Game, x, y: int) -> bool {
	for sy in max(0, y - SCARECROW_RADIUS) ..= min(FIELD_H - 1, y + SCARECROW_RADIUS) {
		for sx in max(0, x - SCARECROW_RADIUS) ..= min(FIELD_W - 1, x + SCARECROW_RADIUS) {
			if cell_at(g, sx, sy).kind == .Scarecrow {
				return true
			}
		}
	}
	return false
}

// Plants a crop on an empty cell, using a seed from the barn if there is one, or paying for it.
plant :: proc(g: ^Game, x, y: int, crop: Crop) -> bool {
	c := cell_at(g, x, y)
	if c.kind != .Empty || !c.owned {
		return false
	}
	info := CROPS[crop]
	t: Text
	if g.seeds[crop] > 0 {
		g.seeds[crop] -= 1
		add(&t, "Planted ")
		add(&t, info.name)
		add(&t, " from yer own seed.")
	} else if g.money >= info.cost {
		g.money -= info.cost
		add(&t, "Bought and planted ")
		add(&t, info.name)
		add(&t, " for $")
		add_int(&t, info.cost)
		add(&t, ".")
	} else {
		add(&t, "Not enough money for ")
		add(&t, info.name)
		add(&t, " seed ($")
		add_int(&t, info.cost)
		add(&t, ").")
		say(g, text_of(&t), COLOR_RED)
		g.events += {.Denied}
		return false
	}
	c^ = {owned = true, kind = .Crop, crop = crop}
	say(g, text_of(&t), COLOR_LIME)
	g.events += {.Planted}
	return true
}

hire :: proc(g: ^Game, x, y: int) -> bool {
	c := cell_at(g, x, y)
	if c.kind != .Empty || !c.owned {
		return false
	}
	if g.money < FARMER_COST {
		t: Text
		add(&t, "A farmhand costs $")
		add_int(&t, FARMER_COST)
		add(&t, ".")
		say(g, text_of(&t), COLOR_RED)
		g.events += {.Denied}
		return false
	}
	g.money -= FARMER_COST
	c^ = {owned = true, kind = .Farmer, fed = true}
	t: Text
	add(&t, "Hired a farmhand for $")
	add_int(&t, FARMER_COST)
	add(&t, ". They eat every turn.")
	say(g, text_of(&t), COLOR_CYAN)
	g.events += {.Hired}
	return true
}

harvest :: proc(g: ^Game, x, y: int) -> bool {
	c := cell_at(g, x, y)
	if !ripe(c^) {
		return false
	}
	g.harvested += 1
	info := CROPS[c.crop]
	t: Text
	if barn_count(g) >= barn_capacity(g) {
		g.money += info.price
		g.earned += info.price
		add(&t, "Barn full: sold the ")
		add(&t, info.name)
		add(&t, " for $")
		add_int(&t, info.price)
		add(&t, ".")
		g.events += {.Sold}
	} else {
		g.barn[c.crop] += 1
		add(&t, "Harvested ")
		add(&t, info.name)
		add(&t, " into the barn.")
	}
	say(g, text_of(&t), COLOR_YELLOW)
	pay_soil(g, x, y, c.crop)
	c^ = {owned = true}
	g.events += {.Harvested}
	return true
}

// --- Land.

// The price of the next square: LAND_PRICE, each one after LAND_GROWTH_PERCENT more (rounded up).
land_price :: proc(g: ^Game) -> int {
	return grown(LAND_PRICE, LAND_GROWTH_PERCENT, g.land_bought)
}

// A price after n rises of percent each, rounded up, capped so it fits in 32 bits.
grown :: proc(base, percent, n: int) -> int {
	p := base
	for _ in 0 ..< n {
		p += (p * percent + 99) / 100
		if p > 1_000_000_000 {
			return 1_000_000_000
		}
	}
	return p
}

// --- The barn, its rats and the cats.

barn_capacity :: proc(g: ^Game) -> int {
	return BARN_CAPACITY + BARN_STEP * g.barn_level
}

barn_count :: proc(g: ^Game) -> int {
	n := 0
	for crop in Crop {
		n += g.barn[crop]
	}
	return n
}

barn_price :: proc(g: ^Game) -> int {
	return grown(BARN_PRICE, BARN_GROWTH_PERCENT, g.barn_level)
}

// The chance, in percent, that rats get into the barn this turn.
rat_chance :: proc(g: ^Game) -> int {
	return clamp(RAT_BASE_PERCENT + RAT_STEP_PERCENT * g.barn_level - CAT_DETER_PERCENT * g.cats, 0, 100)
}

expand_barn :: proc(g: ^Game) -> bool {
	price := barn_price(g)
	t: Text
	if g.money < price {
		add(&t, "A bigger barn costs $")
		add_int(&t, price)
		add(&t, ".")
		say(g, text_of(&t), COLOR_RED)
		g.events += {.Denied}
		return false
	}
	g.money -= price
	g.barn_level += 1
	add(&t, "Built the barn bigger for $")
	add_int(&t, price)
	add(&t, ": holds ")
	add_int(&t, barn_capacity(g))
	add(&t, ". Rats ")
	add_int(&t, rat_chance(g))
	add(&t, "%.")
	say(g, text_of(&t), COLOR_CYAN)
	g.events += {.Built}
	return true
}

buy_cat :: proc(g: ^Game) -> bool {
	t: Text
	if g.money < CAT_COST {
		add(&t, "A cat costs $")
		add_int(&t, CAT_COST)
		add(&t, ".")
		say(g, text_of(&t), COLOR_RED)
		g.events += {.Denied}
		return false
	}
	g.money -= CAT_COST
	g.cats += 1
	add(&t, "Got a cat for $")
	add_int(&t, CAT_COST)
	add(&t, ". Rats ")
	add_int(&t, rat_chance(g))
	add(&t, "%.")
	say(g, text_of(&t), COLOR_CYAN)
	g.events += {.Cat}
	return true
}

// Rats eat half of every crop in the barn (rounded up) and half the pantry. Returns the crops eaten.
rats_feast :: proc(g: ^Game) -> int {
	eaten := 0
	for crop in Crop {
		n := (g.barn[crop] + 1) / 2
		g.barn[crop] -= n
		eaten += n
	}
	g.pantry /= 2
	return eaten
}

// Wild land can be bought when it touches owned land on a side.
can_buy :: proc(g: ^Game, x, y: int) -> bool {
	if cell_at(g, x, y).owned {
		return false
	}
	SIDES :: [4][2]int{{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
	for d in SIDES {
		nx, ny := x + d.x, y + d.y
		if nx >= 0 && ny >= 0 && nx < FIELD_W && ny < FIELD_H && cell_at(g, nx, ny).owned {
			return true
		}
	}
	return false
}

buy_land :: proc(g: ^Game, x, y: int) -> bool {
	if !can_buy(g, x, y) {
		say(g, "Wild land. Buy the land next to it first.", COLOR_RED)
		g.events += {.Denied}
		return false
	}
	price := land_price(g)
	t: Text
	if g.money < price {
		add(&t, "This land costs $")
		add_int(&t, price)
		add(&t, ".")
		say(g, text_of(&t), COLOR_RED)
		g.events += {.Denied}
		return false
	}
	g.money -= price
	g.land_bought += 1
	cell_at(g, x, y)^ = {owned = true}
	add(&t, "Bought the land for $")
	add_int(&t, price)
	add(&t, ". The next costs $")
	add_int(&t, land_price(g))
	add(&t, ".")
	say(g, text_of(&t), COLOR_CYAN)
	g.events += {.Bought}
	return true
}

// Sells up to n of a crop from the barn.
sell :: proc(g: ^Game, crop: Crop, n: int) -> bool {
	count := min(n, g.barn[crop])
	info := CROPS[crop]
	if count <= 0 {
		t: Text
		add(&t, "No ")
		add(&t, info.name)
		add(&t, " in the barn to sell.")
		say(g, text_of(&t), COLOR_RED)
		g.events += {.Denied}
		return false
	}
	g.barn[crop] -= count
	g.money += count * info.price
	g.earned += count * info.price
	t: Text
	add(&t, "Sold ")
	add_int(&t, count)
	add(&t, " ")
	add(&t, info.name)
	add(&t, " for $")
	add_int(&t, count * info.price)
	add(&t, ".")
	say(g, text_of(&t), COLOR_YELLOW)
	g.events += {.Sold}
	return true
}

// Turns one crop from the barn back into seeds.
make_seeds :: proc(g: ^Game, crop: Crop) -> bool {
	info := CROPS[crop]
	if g.barn[crop] <= 0 {
		t: Text
		add(&t, "No ")
		add(&t, info.name)
		add(&t, " in the barn to keep for seed.")
		say(g, text_of(&t), COLOR_RED)
		g.events += {.Denied}
		return false
	}
	g.barn[crop] -= 1
	g.seeds[crop] += info.seeds
	t: Text
	add(&t, "Kept a ")
	add(&t, info.name)
	add(&t, " back: ")
	add_int(&t, info.seeds)
	add(&t, " seeds.")
	say(g, text_of(&t), COLOR_LIME)
	g.events += {.Seeded}
	return true
}

// Meals the barn could provide right now (the pantry plus every crop eaten).
meals_in_barn :: proc(g: ^Game) -> int {
	total := g.pantry
	for crop in Crop {
		total += g.barn[crop] * CROPS[crop].food
	}
	return total
}

// Takes one meal: from the pantry, or by opening the crop that sells for least per meal.
eat_meal :: proc(g: ^Game) -> bool {
	if g.pantry == 0 {
		best: Crop
		found := false
		for crop in Crop {
			if g.barn[crop] == 0 {
				continue
			}
			// cheapest per meal: price/food, compared without division
			if !found || CROPS[crop].price * CROPS[best].food < CROPS[best].price * CROPS[crop].food {
				best = crop
				found = true
			}
		}
		if !found {
			return false
		}
		g.barn[best] -= 1
		g.pantry += CROPS[best].food
	}
	g.pantry -= 1
	return true
}

farmer_count :: proc(g: ^Game) -> int {
	n := 0
	for c in g.field {
		if c.kind == .Farmer {
			n += 1
		}
	}
	return n
}

// The growth a crop at (x, y) gets this turn: one, plus a boost from each fed farmer next to it.
growth_at :: proc(g: ^Game, x, y: int) -> int {
	grow := 1
	for dy in -1 ..= 1 {
		for dx in -1 ..= 1 {
			if dx == 0 && dy == 0 {
				continue
			}
			nx, ny := x + dx, y + dy
			if nx < 0 || ny < 0 || nx >= FIELD_W || ny >= FIELD_H {
				continue
			}
			n := cell_at(g, nx, ny)
			if n.kind == .Farmer && n.fed {
				grow += FARMER_BOOST
			}
		}
	}
	return grow
}

// The end of a turn: farmers eat (or go hungry, or quit), then crops grow.
end_turn :: proc(g: ^Game) {
	put_back(g)
	fed, hungry, quit := 0, 0, 0
	for &c in g.field {
		if c.kind != .Farmer {
			continue
		}
		ate := true
		for _ in 0 ..< FARMER_APPETITE {
			if !eat_meal(g) {
				ate = false
				break
			}
		}
		if ate {
			c.hunger = 0
			c.fed = !c.moved // set down this turn: eats, but works from the next
			fed += 1
		} else {
			c.hunger += 1
			c.fed = false
			if int(c.hunger) > FARMER_PATIENCE {
				c = {owned = true}
				quit += 1
			} else {
				hungry += 1
			}
		}
		c.moved = false
	}
	// Roll every turn, so the rolls stay in step whatever is in the barn.
	rats := rng_int(&g.rng, 100) < rat_chance(g) && (barn_count(g) > 0 || g.pantry > 0)
	rats_ate := rats ? rats_feast(g) : 0
	// Then the cats roll to wander off (this turn's cats have already guarded the barn).
	wandered := 0
	for _ in 0 ..< g.cats {
		if rng_int(&g.rng, 100) < CAT_WANDER_PERCENT {
			wandered += 1
		}
	}
	g.cats -= wandered
	// Then the crows, at every crop no scarecrow guards.
	crowed, crowed_crop := 0, Crop.Carrot
	for y in 0 ..< FIELD_H {
		for x in 0 ..< FIELD_W {
			c := cell_at(g, x, y)
			if c.kind != .Crop || guarded(g, x, y) {
				continue
			}
			if rng_int(&g.rng, 100) < CROW_PERCENT {
				crowed += 1
				crowed_crop = c.crop
				c^ = {owned = true}
			}
		}
	}
	// Then the weather, after the crows, so a scarecrow still guards on the turn it falls.
	fell := 0
	for &c in g.field {
		if c.kind != .Scarecrow {
			continue
		}
		wear := rng_int(&g.rng, SCARECROW_WEAR_MAX + 1)
		if int(c.health) <= wear {
			c = {owned = true}
			fell += 1
		} else {
			c.health -= u8(wear)
		}
	}
	// Growth in half turns: half speed when the soil is short. A crop already ripe ages instead,
	// and one left too long rots, paying the soil and leaving compost.
	ripened, rotted, rotted_crop := 0, 0, Crop.Carrot
	for y in 0 ..< FIELD_H {
		for x in 0 ..< FIELD_W {
			c := cell_at(g, x, y)
			if c.kind != .Crop {
				continue
			}
			if ripe(c^) {
				c.rot += 1
				if int(c.rot) >= CROPS[c.crop].keep {
					rotted += 1
					rotted_crop = c.crop
					pay_soil(g, x, y, c.crop)
					add_soil(g, x, y, COMPOST)
					c^ = {owned = true}
				}
				continue
			}
			step := growth_at(g, x, y)
			if _, short := short_of(g, x, y); !short {
				step *= 2
			}
			c.progress = u8(min(int(c.progress) + step, 2 * CROPS[c.crop].grow))
			if ripe(c^) {
				ripened += 1
			}
		}
	}
	g.turn += 1
	g.quits += quit
	g.events += {.Turned}
	t: Text
	add(&t, "Turn ")
	add_int(&t, g.turn)
	add(&t, ".")
	if ripened > 0 {
		add(&t, " ")
		add_int(&t, ripened)
		add(&t, ripened == 1 ? " crop ripened." : " crops ripened.")
	}
	if fed > 0 {
		add(&t, " Fed ")
		add_int(&t, fed)
		add(&t, fed == 1 ? " farmhand." : " farmhands.")
	}
	say(g, text_of(&t), COLOR_WHITE)
	if rats {
		t4: Text
		add(&t4, "Rats got into the barn and ate ")
		add_int(&t4, rats_ate)
		add(&t4, rats_ate == 1 ? " crop!" : " crops!")
		say(g, text_of(&t4), COLOR_RED)
		g.events += {.Rats}
	}
	if crowed > 0 {
		t5: Text
		if crowed == 1 {
			add(&t5, "Crows ate a ")
			add(&t5, CROPS[crowed_crop].name)
			add(&t5, "!")
		} else {
			add(&t5, "Crows ate ")
			add_int(&t5, crowed)
			add(&t5, " crops!")
		}
		say(g, text_of(&t5), COLOR_RED)
		g.events += {.Crows}
	}
	if rotted > 0 {
		t8: Text
		if rotted == 1 {
			add(&t8, "A ")
			add(&t8, CROPS[rotted_crop].name)
			add(&t8, " rotted in the field.")
		} else {
			add_int(&t8, rotted)
			add(&t8, " crops rotted in the field.")
		}
		say(g, text_of(&t8), COLOR_ORANGE)
		g.events += {.Rotted}
	}
	if fell > 0 {
		t7: Text
		if fell == 1 {
			add(&t7, "A scarecrow fell apart in the weather.")
		} else {
			add_int(&t7, fell)
			add(&t7, " scarecrows fell apart in the weather.")
		}
		say(g, text_of(&t7), COLOR_ORANGE)
		g.events += {.Fell}
	}
	if wandered > 0 {
		t6: Text
		add_int(&t6, wandered)
		add(&t6, wandered == 1 ? " cat wandered off." : " cats wandered off.")
		say(g, text_of(&t6), COLOR_ORANGE)
		g.events += {.Wandered}
	}
	if hungry > 0 {
		t2: Text
		add_int(&t2, hungry)
		add(&t2, hungry == 1 ? " farmhand went hungry and did no work." : " farmhands went hungry and did no work.")
		say(g, text_of(&t2), COLOR_ORANGE)
		g.events += {.Hungry}
	}
	if quit > 0 {
		t3: Text
		add_int(&t3, quit)
		add(&t3, quit == 1 ? " farmhand quit from hunger." : " farmhands quit from hunger.")
		say(g, text_of(&t3), COLOR_RED)
		g.events += {.Quit}
	}
}

// --- Input.

command :: proc(g: ^Game, c: Command) {
	g.events = {}
	if c != .New_Farm {
		g.confirm_new = false
	}
	switch c {
	case .North:
		move_cursor(g, 0, -1)
	case .South:
		move_cursor(g, 0, 1)
	case .West:
		move_cursor(g, -1, 0)
	case .East:
		move_cursor(g, 1, 0)
	case .Confirm:
		act(g)
	case .Next_Tool:
		g.tool = Tool((int(g.tool) + 1) % len(Tool))
		g.events += {.Moved}
	case .Prev_Tool:
		g.tool = Tool((int(g.tool) + len(Tool) - 1) % len(Tool))
		g.events += {.Moved}
	case .Sell, .Sell_All, .Seeds:
		crop, ok := tool_crop(g.tool)
		if !ok {
			say(g, "Pick a crop first (2 to 6) to sell it or keep it for seed.", COLOR_RED)
			g.events += {.Denied}
			return
		}
		#partial switch c {
		case .Sell:
			sell(g, crop, 1)
		case .Sell_All:
			sell(g, crop, g.barn[crop])
		case .Seeds:
			make_seeds(g, crop)
		}
	case .End_Turn:
		end_turn(g)
	case .New_Farm:
		if g.confirm_new {
			init_game(g, rng_next(&g.rng))
			g.events += {.Turned}
		} else {
			g.confirm_new = true
			say(g, "Start a new farm? Press New again to confirm.", COLOR_ORANGE)
			g.events += {.Moved}
		}
	case .Tool_1, .Tool_2, .Tool_3, .Tool_4, .Tool_5, .Tool_6:
		g.tool = Tool(u8(c) - u8(Command.Tool_1))
		g.events += {.Moved}
	case .Expand_Barn:
		expand_barn(g)
	case .Buy_Cat:
		buy_cat(g)
	case .Dismiss:
		dismiss(g)
	case .Tool_7:
		g.tool = .Scarecrow
		g.events += {.Moved}
	case .Tool_8:
		g.tool = .Manure
		g.events += {.Moved}
	}
}

move_cursor :: proc(g: ^Game, dx, dy: int) {
	g.cursor_x = clamp(g.cursor_x + dx, 0, FIELD_W - 1)
	g.cursor_y = clamp(g.cursor_y + dy, 0, FIELD_H - 1)
	g.events += {.Moved}
}

// --- Strings without core:fmt: a fixed buffer on the stack.

Text :: struct {
	buf: [96]u8,
	n:   int,
}

add :: proc(t: ^Text, s: string) {
	for i in 0 ..< len(s) {
		if t.n < len(t.buf) {
			t.buf[t.n] = s[i]
			t.n += 1
		}
	}
}

// A count of half turns, as "3" or "3.5".
add_halves :: proc(t: ^Text, halves: int) {
	add_int(t, halves / 2)
	if halves % 2 == 1 {
		add(t, ".5")
	}
}

add_int :: proc(t: ^Text, v: int) {
	if v < 0 {
		add(t, "-")
		add_int(t, -v)
		return
	}
	digits: [20]u8
	n := 0
	x := v
	for {
		digits[n] = u8('0' + x % 10)
		n += 1
		x /= 10
		if x == 0 {
			break
		}
	}
	for i := n - 1; i >= 0; i -= 1 {
		if t.n < len(t.buf) {
			t.buf[t.n] = digits[i]
			t.n += 1
		}
	}
}

text_of :: proc(t: ^Text) -> string {
	return string(t.buf[:t.n])
}
