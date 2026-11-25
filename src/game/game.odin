package game

// The rules: an 8 by 8 field, crops and farmers placed by the player, a barn, money and turns.
// Pure: no core:os, no core:fmt. The numbers come from the Anvil world through data.odin.

FIELD_W :: 8
FIELD_H :: 8

Cell_Kind :: enum u8 {
	Empty,
	Crop,
	Farmer,
}

Cell :: struct {
	owned:    bool, // bought land; wild land must be bought before anything goes on it
	kind:     Cell_Kind,
	crop:     Crop, // when kind is Crop
	progress: u8, // growth so far; ripe at CROPS[crop].grow
	hunger:   u8, // farmer: hungry turns in a row
	fed:      bool, // farmer: ate this turn, so tends the neighbours
}

// What the player has in hand: a farmer to hire or a crop to plant.
Tool :: enum u8 {
	Farmer,
	Carrot,
	Wheat,
	Cabbage,
	Corn,
	Pumpkin,
}

tool_crop :: proc(t: Tool) -> (Crop, bool) {
	if t == .Farmer {
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
}

init_game :: proc(g: ^Game) {
	g^ = {}
	g.money = START_MONEY
	g.turn = 1
	g.cursor_x = FIELD_W / 2 - 1
	g.cursor_y = FIELD_H / 2 - 1
	g.tool = .Carrot
	for t, i in FIELD_TERRAIN {
		g.field[i].owned = t == .Soil
	}
	say(g, "Welcome to the farm. Plant crops, hire farmhands, feed them.", COLOR_YELLOW)
	say(g, "Farmhands make the crops around them grow twice as fast.", COLOR_LIGHT)
	say(g, "Buy wild land next to yers to grow the farm; each costs more.", COLOR_LIGHT)
}

cell_at :: proc(g: ^Game, x, y: int) -> ^Cell {
	return &g.field[y * FIELD_W + x]
}

ripe :: proc(c: Cell) -> bool {
	return c.kind == .Crop && int(c.progress) >= CROPS[c.crop].grow
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
	if !c.owned {
		return buy_land(g, g.cursor_x, g.cursor_y)
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
		add_int(&t, int(c.progress))
		add(&t, " of ")
		add_int(&t, info.grow)
		add(&t, " grown.")
		say(g, text_of(&t), COLOR_LIGHT)
		g.events += {.Denied}
		return false
	case .Farmer:
		t: Text
		add(&t, "A farmhand. ")
		if c.hunger == 0 {
			add(&t, "Fed and working.")
		} else {
			add(&t, "Hungry for ")
			add_int(&t, int(c.hunger))
			add(&t, c.hunger == 1 ? " turn" : " turns")
			add(&t, "; not working.")
		}
		say(g, text_of(&t), COLOR_LIGHT)
		g.events += {.Denied}
		return false
	case .Empty:
	}
	if crop, ok := tool_crop(g.tool); ok {
		return plant(g, g.cursor_x, g.cursor_y, crop)
	}
	return hire(g, g.cursor_x, g.cursor_y)
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
	g.barn[c.crop] += 1
	g.harvested += 1
	t: Text
	add(&t, "Harvested ")
	add(&t, CROPS[c.crop].name)
	add(&t, " into the barn.")
	say(g, text_of(&t), COLOR_YELLOW)
	c^ = {owned = true}
	g.events += {.Harvested}
	return true
}

// --- Land.

// The price of the next square: LAND_PRICE, each one after LAND_GROWTH_PERCENT more (rounded up).
land_price :: proc(g: ^Game) -> int {
	p := LAND_PRICE
	for _ in 0 ..< g.land_bought {
		p += (p * LAND_GROWTH_PERCENT + 99) / 100
		if p > 1_000_000_000 {
			return 1_000_000_000
		}
	}
	return p
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
			c.fed = true
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
	}
	ripened := 0
	for y in 0 ..< FIELD_H {
		for x in 0 ..< FIELD_W {
			c := cell_at(g, x, y)
			if c.kind != .Crop || ripe(c^) {
				continue
			}
			p := min(int(c.progress) + growth_at(g, x, y), CROPS[c.crop].grow)
			c.progress = u8(p)
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
			init_game(g)
			g.events += {.Turned}
		} else {
			g.confirm_new = true
			say(g, "Start a new farm? Press New again to confirm.", COLOR_ORANGE)
			g.events += {.Moved}
		}
	case .Tool_1, .Tool_2, .Tool_3, .Tool_4, .Tool_5, .Tool_6:
		g.tool = Tool(u8(c) - u8(Command.Tool_1))
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
