package game

// Layout of the 480 by 270 screen: the field on the left; on the right a tabbed panel (Farm, Barn,
// Stats, Help) over a row of buttons every tab shares and the status line; the log across the
// bottom. pointer() uses the same rectangles.

CELL :: 24 // a field cell: a 12 px tile drawn at 2x
FIELD_X :: 12
FIELD_Y :: 24
PANEL_X :: 220
PANEL_W :: 256
TAB_Y :: 22
TAB_H :: 12
HEAD_Y :: 37 // column labels
ROWS_Y :: 46 // first row of the Farm and Barn tabs
ROW_H :: 11
TAB_BUTTONS_Y :: 181 // the buttons of one tab
SHARED_Y :: 194 // the buttons every tab shares
STATUS_Y :: 212
LOG_Y :: 228
LOG_H :: 10

Rect :: struct {
	x, y, w, h: int,
}

inside :: proc(r: Rect, x, y: int) -> bool {
	return x >= r.x && y >= r.y && x < r.x + r.w && y < r.y + r.h
}

Button :: struct {
	rect:    Rect,
	label:   string,
	command: Command,
	panels:  bit_set[Panel], // the tabs it shows on
}

ALL_PANELS :: bit_set[Panel]{.Farm, .Barn, .Stats, .Help}

BUTTONS := [?]Button {
	{{PANEL_X, SHARED_Y, 64, 14}, "End turn T", .End_Turn, ALL_PANELS},
	{{PANEL_X + 66, SHARED_Y, 60, 14}, "Act Space", .Confirm, ALL_PANELS},
	{{PANEL_X + 128, SHARED_Y, 56, 14}, "Let go D", .Dismiss, ALL_PANELS},
	{{PANEL_X + 186, SHARED_Y, 70, 14}, "New farm N", .New_Farm, ALL_PANELS},
	{{PANEL_X, TAB_BUTTONS_Y, 40, 11}, "Sell X", .Sell, {.Barn}},
	{{PANEL_X + 42, TAB_BUTTONS_Y, 34, 11}, "All A", .Sell_All, {.Barn}},
	{{PANEL_X + 78, TAB_BUTTONS_Y, 40, 11}, "Seed Z", .Seeds, {.Barn}},
	{{PANEL_X + 120, TAB_BUTTONS_Y, 74, 11}, "", .Expand_Barn, {.Barn}}, // labels with prices are made in draw_buttons
	{{PANEL_X + 196, TAB_BUTTONS_Y, 60, 11}, "", .Buy_Cat, {.Barn}},
	{{PANEL_X, TAB_BUTTONS_Y, 44, 11}, "< PgUp", .Page_Prev, {.Stats, .Help}},
	{{PANEL_X + 212, TAB_BUTTONS_Y, 44, 11}, "PgDn >", .Page_Next, {.Stats, .Help}},
	{{PANEL_X + 70, TAB_BUTTONS_Y, 116, 11}, "", .Tutorial, {.Help}},
}

PANEL_NAME := [Panel]string{.Farm = "Farm", .Barn = "Barn", .Stats = "Stats", .Help = "Help"}

tab_rect :: proc(p: Panel) -> Rect {
	return {PANEL_X + int(p) * 64, TAB_Y, 62, TAB_H}
}

// A row of the Farm tab (one per tool) or of the Barn tab (one per crop).
row_rect :: proc(i: int) -> Rect {
	return {PANEL_X, ROWS_Y + i * ROW_H, PANEL_W, ROW_H}
}

tool_row :: proc(t: Tool) -> Rect {
	return row_rect(int(t))
}

// The Barn tab's little - and + buttons: seed target, then sell-above.
BARN_SEED_DOWN_X :: 124
BARN_SEED_UP_X :: 150
BARN_SELL_DOWN_X :: 176
BARN_SELL_UP_X :: 202
BARN_STEP_W :: 10

TOOL_GFX := [Tool]Gfx {
	.Farmer    = .Farmer,
	.Scarecrow = .Scarecrow,
	.Manure    = .Manure,
	.Carrot    = .Carrot,
	.Radish    = .Radish,
	.Peas      = .Peas,
	.Wheat     = .Wheat,
	.Onion     = .Onion,
	.Cabbage   = .Cabbage,
	.Potato    = .Potato,
	.Corn      = .Corn,
	.Tomato    = .Tomato,
	.Pumpkin   = .Pumpkin,
}

CROP_COLOR := [Crop]u8 {
	.Carrot  = COLOR_ORANGE,
	.Radish  = COLOR_RED,
	.Peas    = COLOR_LIME,
	.Wheat   = COLOR_YELLOW,
	.Onion   = COLOR_LIME,
	.Cabbage = COLOR_LIME,
	.Potato  = COLOR_ORANGE,
	.Corn    = COLOR_YELLOW,
	.Tomato  = COLOR_RED,
	.Pumpkin = COLOR_ORANGE,
}

crop_gfx :: proc(c: Crop) -> Gfx {
	return TOOL_GFX[crop_tool(c)]
}

tool_color :: proc(t: Tool) -> u8 {
	if crop, ok := tool_crop(t); ok {
		return CROP_COLOR[crop]
	}
	#partial switch t {
	case .Scarecrow:
		return COLOR_ORANGE
	case .Manure:
		return COLOR_LIGHT
	}
	return COLOR_WHITE
}

// The colours of the soil bars: N, P, K. Text marks a letter for its colour with ^ (print_rich).
NUTRIENT_COLOR := [Nutrient]u8{.N = COLOR_LIME, .P = COLOR_SKY, .K = COLOR_YELLOW}

// A click or tap at framebuffer pixel (x, y).
pointer :: proc(g: ^Game, x, y: int) {
	g.events = {}
	field := Rect{FIELD_X, FIELD_Y, FIELD_W * CELL, FIELD_H * CELL}
	if inside(field, x, y) {
		g.confirm_new = false
		g.confirm_tutorial = false
		g.cursor_x = (x - FIELD_X) / CELL
		g.cursor_y = (y - FIELD_Y) / CELL
		act(g)
		tutorial_check(g)
		return
	}
	for p in Panel {
		if inside(tab_rect(p), x, y) {
			show_panel(g, p)
			return
		}
	}
	switch g.panel {
	case .Farm:
		for t in Tool {
			if !inside(tool_row(t), x, y) {
				continue
			}
			crop, is_crop := tool_crop(t)
			if is_crop && !g.licensed[crop] && x >= PANEL_X + 80 {
				// the "License $n" in the row buys it
				g.tool = t
				command(g, .License)
				return
			}
			g.tool = t
			g.events += {.Moved}
			return
		}
	case .Barn:
		for crop in Crop {
			r := row_rect(int(crop))
			if !inside(r, x, y) {
				continue
			}
			g.tool = crop_tool(crop)
			dx := x - PANEL_X
			switch {
			case dx >= BARN_SEED_DOWN_X && dx < BARN_SEED_DOWN_X + BARN_STEP_W:
				command(g, .Seed_Target_Down)
			case dx >= BARN_SEED_UP_X && dx < BARN_SEED_UP_X + BARN_STEP_W:
				command(g, .Seed_Target_Up)
			case dx >= BARN_SELL_DOWN_X && dx < BARN_SELL_DOWN_X + BARN_STEP_W:
				command(g, .Sell_Above_Down)
			case dx >= BARN_SELL_UP_X && dx < BARN_SELL_UP_X + BARN_STEP_W:
				command(g, .Sell_Above_Up)
			case:
				g.events += {.Moved}
			}
			return
		}
	case .Stats, .Help:
	}
	for b in BUTTONS {
		if g.panel in b.panels && inside(b.rect, x, y) {
			command(g, b.command)
			return
		}
	}
}

draw_game :: proc(f: ^Frame, g: ^Game) {
	cls(f, COLOR_BLACK)
	draw_header(f, g)
	draw_field(f, g)
	draw_tabs(f, g)
	switch g.panel {
	case .Farm:
		draw_farm_tab(f, g)
	case .Barn:
		draw_barn_tab(f, g)
	case .Stats:
		draw_stats_tab(f, g)
	case .Help:
		draw_help_tab(f, g)
	}
	draw_buttons(f, g)
	draw_status(f, g)
	draw_log(f, g)
}

// The log; in the tutorial its top line is the current goal.
draw_log :: proc(f: ^Frame, g: ^Game) {
	first := 0
	if g.tutorial > 0 && g.tutorial <= len(TUTORIAL) {
		t: Text
		add(&t, "Goal ")
		add_int(&t, g.tutorial)
		add(&t, "/")
		add_int(&t, len(TUTORIAL))
		add(&t, ": ")
		fill_rect(f, 0, LOG_Y - 2, SCREEN_W, LOG_H, COLOR_DARK)
		w := print(f, text_of(&t), 6, LOG_Y, COLOR_YELLOW)
		print(f, TUTORIAL[g.tutorial - 1].goal, 6 + w, LOG_Y, COLOR_WHITE)
		first = 1
	}
	for i in first ..< LOG_LINES {
		l := &g.log[i]
		print(f, log_text(l), 6, LOG_Y + i * LOG_H, l.color)
	}
}

draw_header :: proc(f: ^Frame, g: ^Game) {
	draw_gfx(f, .Scarecrow, 8, 5, COLOR_ORANGE)
	print(f, "FARMHANDS of SPLORR!!", 24, 7, COLOR_YELLOW)
	t: Text
	add(&t, "Turn ")
	add_int(&t, g.turn)
	print(f, text_of(&t), PANEL_X, 7, COLOR_LIGHT)
	land: Text
	add(&land, "Land $")
	add_int(&land, land_price(g))
	print(f, text_of(&land), PANEL_X + 66, 7, COLOR_GREEN)
	draw_gfx(f, .Coin, 400, 5, COLOR_YELLOW)
	m: Text
	add(&m, "$")
	add_int(&m, g.money)
	print(f, text_of(&m), 416, 7, COLOR_YELLOW)
	fill_rect(f, 0, 19, SCREEN_W, 1, COLOR_DARK)
}

draw_tabs :: proc(f: ^Frame, g: ^Game) {
	for p in Panel {
		r := tab_rect(p)
		on := p == g.panel
		fill_rect(f, r.x, r.y, r.w, r.h, on ? COLOR_MID : COLOR_DARK)
		name := PANEL_NAME[p]
		print(f, name, r.x + (r.w - text_width(name)) / 2, r.y + 2, on ? COLOR_WHITE : COLOR_LIGHT)
	}
	fill_rect(f, PANEL_X, TAB_Y + TAB_H, PANEL_W, 1, COLOR_MID)
}

draw_field :: proc(f: ^Frame, g: ^Game) {
	frame_rect(f, FIELD_X - 2, FIELD_Y - 2, FIELD_W * CELL + 4, FIELD_H * CELL + 4, COLOR_SOIL)
	for y in 0 ..< FIELD_H {
		for x in 0 ..< FIELD_W {
			draw_cell(f, g, x, y)
		}
	}
	// Show the cells a farmhand would tend, or a scarecrow would guard, from the cursor.
	under := cell_at(g, g.cursor_x, g.cursor_y).kind
	if g.carrying == .Farmer || (g.carrying == .Empty && (g.tool == .Farmer || under == .Farmer)) {
		frame_area(f, g.cursor_x, g.cursor_y, 1, COLOR_CYAN)
	} else if g.carrying == .Scarecrow || (g.carrying == .Empty && (g.tool == .Scarecrow || under == .Scarecrow)) {
		frame_area(f, g.cursor_x, g.cursor_y, SCARECROW_RADIUS, COLOR_ORANGE)
	}
	cx := FIELD_X + g.cursor_x * CELL
	cy := FIELD_Y + g.cursor_y * CELL
	color: u8 = g.carrying == .Empty ? COLOR_WHITE : COLOR_CYAN
	frame_rect(f, cx, cy, CELL, CELL, color)
	frame_rect(f, cx + 1, cy + 1, CELL - 2, CELL - 2, color)
	// What is in hand rides in the cursor's corner.
	if g.carrying != .Empty {
		fill_rect(f, cx + 2, cy + 2, 12, 12, COLOR_BLACK)
		draw_gfx(f, g.carrying == .Farmer ? .Farmer : .Scarecrow, cx + 2, cy + 2, g.carrying == .Farmer ? COLOR_CYAN : COLOR_ORANGE)
	}
}

// A frame around the cells within r of (x, y), clipped to the field.
frame_area :: proc(f: ^Frame, x, y, r: int, color: u8) {
	x0 := max(x - r, 0)
	y0 := max(y - r, 0)
	x1 := min(x + r, FIELD_W - 1)
	y1 := min(y + r, FIELD_H - 1)
	frame_rect(f, FIELD_X + x0 * CELL, FIELD_Y + y0 * CELL, (x1 - x0 + 1) * CELL, (y1 - y0 + 1) * CELL, color)
}

// Small corner marks on a square a scarecrow guards: two pixels each way at every corner.
draw_guard_marks :: proc(f: ^Frame, px, py: int) {
	a := px + 1
	b := px + CELL - 2
	top := py + 1
	bot := py + CELL - 2
	for p in ([4][2]int{{a, top}, {b, top}, {a, bot}, {b, bot}}) {
		dx := p.x == a ? 1 : -1
		dy := p.y == top ? 1 : -1
		set_px(f, p.x, p.y, COLOR_ORANGE)
		set_px(f, p.x + dx, p.y, COLOR_ORANGE)
		set_px(f, p.x, p.y + dy, COLOR_ORANGE)
	}
}

draw_cell :: proc(f: ^Frame, g: ^Game, x, y: int) {
	px := FIELD_X + x * CELL
	py := FIELD_Y + y * CELL
	c := cell_at(g, x, y)^
	if !c.owned {
		// Wild land: grass on the dark background; the squares that can be bought get an edge.
		fill_rect(f, px + 1, py + 1, CELL - 2, CELL - 2, COLOR_BLACK)
		draw_gfx_scaled(f, .Wild, px, py, 2, can_buy(g, x, y) ? COLOR_GREEN : COLOR_DARK)
		if can_buy(g, x, y) {
			frame_rect(f, px + 1, py + 1, CELL - 2, CELL - 2, COLOR_DARK)
		}
		return
	}
	fill_rect(f, px + 1, py + 1, CELL - 2, CELL - 2, COLOR_SOIL_DARK)
	switch c.kind {
	case .Empty:
		draw_gfx_scaled(f, .Soil, px, py, 2, COLOR_SOIL)
		// N, P and K as three small bars in the corner
		soil := soil_at(g, x, y)
		for n, i in Nutrient {
			h := 2 * int(soil[n])
			bx := px + CELL - 11 + int(i) * 3
			fill_rect(f, bx, py + CELL - 3 - 2 * SOIL_MAX, 2, 2 * SOIL_MAX, COLOR_BLACK)
			fill_rect(f, bx, py + CELL - 3 - h, 2, h, NUTRIENT_COLOR[n])
		}
	case .Scarecrow:
		draw_gfx_scaled(f, .Scarecrow, px, py, 2, COLOR_ORANGE)
		// health bar along the bottom; red when nearly gone
		w := (CELL - 4) * int(c.health) / SCARECROW_HEALTH
		fill_rect(f, px + 2, py + CELL - 3, CELL - 4, 1, COLOR_SOIL)
		fill_rect(f, px + 2, py + CELL - 3, w, 1, c.health <= 3 ? COLOR_RED : COLOR_ORANGE)
	case .Farmer:
		// white when working, cyan while settling in after a move, orange when hungry
		draw_gfx_scaled(f, .Farmer, px, py, 2, c.hunger > 0 ? COLOR_ORANGE : c.moved ? COLOR_CYAN : COLOR_WHITE)
		if c.hunger > 0 {
			// one red pip per hungry turn
			for i in 0 ..< int(c.hunger) {
				fill_rect(f, px + 3 + i * 4, py + 3, 3, 3, COLOR_RED)
			}
		}
	case .Crop:
		grow := CROPS[c.crop].grow
		if ripe(c) {
			// ripe: a bar for the turns left before it rots; dull on its last turn
			keep := CROPS[c.crop].keep
			left := keep - int(c.rot)
			draw_gfx_scaled(f, crop_gfx(c.crop), px, py, 2, left <= 1 ? COLOR_MID : CROP_COLOR[c.crop])
			fill_rect(f, px + 2, py + CELL - 3, CELL - 4, 1, COLOR_SOIL)
			fill_rect(f, px + 2, py + CELL - 3, (CELL - 4) * left / keep, 1, left <= 1 ? COLOR_RED : COLOR_ORANGE)
		} else {
			stage: Gfx = int(c.progress) < grow ? .Seedling : .Sprouts
			draw_gfx_scaled(f, stage, px, py, 2, stage == .Seedling ? COLOR_GREEN : COLOR_LIME)
			// growth bar along the bottom; red when the soil is short
			_, short := short_of(g, x, y)
			w := (CELL - 4) * int(c.progress) / (2 * grow)
			fill_rect(f, px + 2, py + CELL - 3, CELL - 4, 1, COLOR_SOIL)
			fill_rect(f, px + 2, py + CELL - 3, max(w, 1), 1, short ? COLOR_RED : COLOR_YELLOW)
		}
	}
	if c.kind != .Scarecrow && guarded(g, x, y) {
		draw_guard_marks(f, px, py)
	}
}

// Prints a number, with an optional prefix.
print_num :: proc(f: ^Frame, prefix: string, v: int, x, y: int, color: u8) {
	t: Text
	add(&t, prefix)
	add_int(&t, v)
	print(f, text_of(&t), x, y, color)
}

// What a crop takes from the soil and puts back, e.g. "-^N2+^K" (an amount of 1 is left out).
add_crop_soil :: proc(t: ^Text, crop: Crop) {
	info := CROPS[crop]
	for sign in ([?]string{"-", "+"}) {
		for n in Nutrient {
			v := sign == "-" ? info.uses[int(n)] : info.gives[int(n)]
			if v > 0 {
				add(t, sign)
				add(t, "^")
				add(t, NUTRIENT_NAME[n])
				if v > 1 {
					add_int(t, v)
				}
			}
		}
	}
}

draw_farm_tab :: proc(f: ^Frame, g: ^Game) {
	for h in ([?]struct {
			label: string,
			x:     int,
		}{{"Tool", 26}, {"Buy", 86}, {"Grow", 108}, {"Sell", 136}, {"Soil", 164}, {"Seed", 196}, {"Barn", 224}}) {
		print(f, h.label, PANEL_X + h.x, HEAD_Y, COLOR_MID)
	}
	for t in Tool {
		r := tool_row(t)
		y := r.y + 2
		if t == g.tool {
			fill_rect(f, r.x, r.y, r.w, r.h, COLOR_DARK)
		}
		if int(t) < 10 {
			print_num(f, "", (int(t) + 1) % 10, PANEL_X + 2, y, COLOR_MID)
		}
		crop, is_crop := tool_crop(t)
		locked := is_crop && !g.licensed[crop]
		draw_gfx(f, TOOL_GFX[t], PANEL_X + 10, r.y, locked ? COLOR_MID : tool_color(t))
		if !is_crop {
			name, note: string
			price := 0
			#partial switch t {
			case .Farmer:
				name, price, note = "Farmhand", FARMER_COST, "x2 growth, eats"
			case .Scarecrow:
				name, price, note = "Scarecrow", SCARECROW_COST, "guards 5x5, wears"
			case .Manure:
				name, price, note = "Manure", MANURE_COST, "refills the soil"
			}
			print(f, name, PANEL_X + 26, y, COLOR_WHITE)
			print_num(f, "$", price, PANEL_X + 86, y, COLOR_YELLOW)
			print(f, note, PANEL_X + 114, y, COLOR_LIGHT)
			continue
		}
		info := CROPS[crop]
		print(f, info.name, PANEL_X + 26, y, locked ? COLOR_MID : COLOR_WHITE)
		if locked {
			lt: Text
			add(&lt, "License $")
			add_int(&lt, info.license)
			add(&lt, " L")
			print(f, text_of(&lt), PANEL_X + 86, y, COLOR_ORANGE)
			continue
		}
		print_num(f, "$", info.cost, PANEL_X + 86, y, COLOR_YELLOW)
		print_num(f, "", info.grow, PANEL_X + 114, y, COLOR_LIGHT)
		print_num(f, "$", info.price, PANEL_X + 136, y, COLOR_YELLOW)
		soil: Text
		add_crop_soil(&soil, crop)
		print_rich(f, text_of(&soil), PANEL_X + 162, y, COLOR_LIGHT)
		print_num(f, "", g.seeds[crop], PANEL_X + 202, y, g.seeds[crop] > 0 ? COLOR_LIME : COLOR_MID)
		print_num(f, "", g.barn[crop], PANEL_X + 228, y, g.barn[crop] > 0 ? COLOR_WHITE : COLOR_MID)
	}
}

draw_barn_tab :: proc(f: ^Frame, g: ^Game) {
	for h in ([?]struct {
			label: string,
			x:     int,
		}{{"Crop", 26}, {"Barn", 68}, {"Seed", 94}, {"Keep", BARN_SEED_DOWN_X + 10}, {"Sell over", BARN_SELL_DOWN_X}}) {
		print(f, h.label, PANEL_X + h.x, HEAD_Y, COLOR_MID)
	}
	step_button :: proc(f: ^Frame, x, y: int, label: string) {
		fill_rect(f, PANEL_X + x, y, BARN_STEP_W, ROW_H - 1, COLOR_DARK)
		print(f, label, PANEL_X + x + 2, y + 1, COLOR_LIGHT)
	}
	for crop in Crop {
		r := row_rect(int(crop))
		y := r.y + 2
		if c, ok := tool_crop(g.tool); ok && c == crop {
			fill_rect(f, r.x, r.y, r.w, r.h, COLOR_DARK)
		}
		locked := !g.licensed[crop]
		draw_gfx(f, crop_gfx(crop), PANEL_X + 10, r.y, locked ? COLOR_MID : CROP_COLOR[crop])
		print(f, CROPS[crop].name, PANEL_X + 26, y, locked ? COLOR_MID : COLOR_WHITE)
		print_num(f, "", g.barn[crop], PANEL_X + 76, y, g.barn[crop] > 0 ? COLOR_WHITE : COLOR_MID)
		print_num(f, "", g.seeds[crop], PANEL_X + 100, y, g.seeds[crop] > 0 ? COLOR_LIME : COLOR_MID)
		step_button(f, BARN_SEED_DOWN_X, r.y, "-")
		target := g.seed_target[crop]
		print_num(f, "", target, PANEL_X + BARN_SEED_DOWN_X + BARN_STEP_W + (target < 10 ? 6 : 2), y, target > 0 ? COLOR_LIME : COLOR_MID)
		step_button(f, BARN_SEED_UP_X, r.y, "+")
		step_button(f, BARN_SELL_DOWN_X, r.y, "-")
		above := g.sell_above[crop]
		if above == SELL_ABOVE_OFF {
			print(f, "-", PANEL_X + BARN_SELL_DOWN_X + BARN_STEP_W + 5, y, COLOR_MID)
		} else {
			print_num(f, "", above, PANEL_X + BARN_SELL_DOWN_X + BARN_STEP_W + (above < 10 ? 6 : 2), y, COLOR_YELLOW)
		}
		step_button(f, BARN_SELL_UP_X, r.y, "+")
	}
	info_y := ROWS_Y + len(Crop) * ROW_H + 2
	draw_gfx(f, .Barn, PANEL_X, info_y - 2, COLOR_ORANGE)
	t: Text
	add(&t, "Barn ")
	add_int(&t, barn_count(g))
	add(&t, "/")
	add_int(&t, barn_capacity(g))
	add(&t, "  Meals ")
	add_int(&t, meals_in_barn(g))
	add(&t, "  Hands ")
	add_int(&t, farmer_count(g))
	print(f, text_of(&t), PANEL_X + 16, info_y, barn_count(g) >= barn_capacity(g) ? COLOR_ORANGE : COLOR_LIGHT)
	draw_gfx(f, .Rat, PANEL_X, info_y + 8, COLOR_LIGHT)
	r: Text
	add(&r, "Rats ")
	add_int(&r, rat_chance(g))
	add(&r, "% a turn")
	print(f, text_of(&r), PANEL_X + 16, info_y + 10, rat_chance(g) > 0 ? COLOR_ORANGE : COLOR_MID)
	draw_gfx(f, .Cat, PANEL_X + 130, info_y + 8, COLOR_LIGHT)
	k: Text
	add(&k, "Cats ")
	add_int(&k, g.cats)
	add(&k, ", ")
	add_int(&k, CAT_WANDER_PERCENT)
	add(&k, "% roam")
	print(f, text_of(&k), PANEL_X + 146, info_y + 10, COLOR_LIGHT)
}

STATS_PAGES :: 3

draw_stats_tab :: proc(f: ^Frame, g: ^Game) {
	title := [STATS_PAGES]string{"Farm totals", "Crops: in and out", "Crops: losses"}
	t: Text
	add(&t, title[g.page])
	add(&t, "  ")
	add_int(&t, g.page + 1)
	add(&t, "/")
	add_int(&t, STATS_PAGES)
	print(f, text_of(&t), PANEL_X + 2, HEAD_Y, COLOR_YELLOW)
	switch g.page {
	case 0:
		s := g.stats
		Line :: struct {
			label: string,
			v:     int,
		}
		lines := [?]Line {
			{"Turns", g.turn - 1},
			{"Earned $", s.earned},
			{"Spent $", s.spent},
			{"Land bought", s.land},
			{"Barn built", s.expansions},
			{"Licenses", s.licenses},
			{"Manure", s.manure},
			{"Hands hired", s.hired},
			{"Hands quit", s.quit},
			{"Hands let go", s.let_go},
			{"Cats got", s.cats},
			{"Cats roamed", s.cats_wandered},
			{"Scarecrows", s.scarecrows},
			{"Fell apart", s.scarecrows_fell},
			{"Taken down", s.scarecrows_down},
		}
		for l, i in lines {
			x := PANEL_X + 2 + (i / 8) * 128
			y := ROWS_Y + 2 + (i % 8) * 16
			print(f, l.label, x, y, COLOR_LIGHT)
			v: Text
			add_int(&v, l.v)
			print(f, text_of(&v), x + 120 - text_width(text_of(&v)), y, COLOR_WHITE)
		}
	case 1, 2:
		heads := g.page == 1 ? [5]string{"Plant", "Harv", "Sold", "Auto", "Seed"} : [5]string{"Fed", "Rats", "Crows", "Rot", ""}
		for h, i in heads {
			print(f, h, PANEL_X + 76 + i * 36 + 30 - text_width(h), HEAD_Y + 10, COLOR_MID)
		}
		for crop in Crop {
			s := g.crop_stats[crop]
			y := ROWS_Y + 9 + int(crop) * ROW_H
			draw_gfx(f, crop_gfx(crop), PANEL_X + 2, y - 2, CROP_COLOR[crop])
			print(f, CROPS[crop].name, PANEL_X + 18, y, COLOR_WHITE)
			vals := g.page == 1 ? [5]int{s.planted, s.harvested, s.sold, s.auto_sold, s.seeded} : [5]int{s.fed, s.rats, s.crows, s.rotted, -1}
			for v, i in vals {
				if v < 0 {
					continue
				}
				n: Text
				add_int(&n, v)
				print(f, text_of(&n), PANEL_X + 76 + i * 36 + 30 - text_width(text_of(&n)), y, v > 0 ? COLOR_WHITE : COLOR_MID)
			}
		}
	}
}

draw_help_tab :: proc(f: ^Frame, g: ^Game) {
	page := HELP[g.page]
	t: Text
	add(&t, page.title)
	print(f, text_of(&t), PANEL_X + 2, HEAD_Y, COLOR_YELLOW)
	n: Text
	add_int(&n, g.page + 1)
	add(&n, "/")
	add_int(&n, len(HELP))
	print(f, text_of(&n), PANEL_X + PANEL_W - 2 - text_width(text_of(&n)), HEAD_Y, COLOR_MID)
	for line, i in page.lines {
		print_rich(f, line, PANEL_X + 2, ROWS_Y + 2 + i * 10, COLOR_LIGHT)
	}
}

draw_buttons :: proc(f: ^Frame, g: ^Game) {
	for b in BUTTONS {
		if g.panel not_in b.panels {
			continue
		}
		color := COLOR_LIGHT
		if (b.command == .New_Farm && g.confirm_new) || (b.command == .Tutorial && g.confirm_tutorial) {
			color = COLOR_ORANGE
		}
		label := b.label
		t: Text
		#partial switch b.command {
		case .Expand_Barn:
			add(&t, "Barn $")
			add_int(&t, barn_price(g))
			add(&t, " B")
			label = text_of(&t)
		case .Buy_Cat:
			add(&t, "Cat $")
			add_int(&t, CAT_COST)
			add(&t, " C")
			label = text_of(&t)
		case .Tutorial:
			label = g.tutorial > 0 ? "Skip tutorial" : "Start tutorial"
		}
		fill_rect(f, b.rect.x, b.rect.y, b.rect.w, b.rect.h, COLOR_DARK)
		frame_rect(f, b.rect.x, b.rect.y, b.rect.w, b.rect.h, COLOR_MID)
		print(f, label, b.rect.x + (b.rect.w - text_width(label)) / 2, b.rect.y + (b.rect.h - GLYPH_H + 1) / 2, u8(color))
	}
}

// "^N4 ^P2 ^K1" for the square at (x, y).
add_soil_text :: proc(t: ^Text, g: ^Game, x, y: int) {
	for n, i in Nutrient {
		if i > 0 {
			add(t, " ")
		}
		add(t, "^")
		add(t, NUTRIENT_NAME[n])
		add_int(t, int(soil_at(g, x, y)[n]))
	}
}

// What is under the cursor, or what is in hand.
draw_status :: proc(f: ^Frame, g: ^Game) {
	c := cell_at(g, g.cursor_x, g.cursor_y)^
	t: Text
	color: u8 = COLOR_WHITE
	if g.carrying != .Empty {
		add(&t, g.carrying == .Farmer ? "In hand: farmhand. " : "In hand: scarecrow. ")
		add(&t, c.owned && c.kind == .Empty ? "Space: set down" : "Find empty soil")
		color = COLOR_CYAN
	} else if !c.owned {
		if can_buy(g, g.cursor_x, g.cursor_y) {
			add(&t, "Wild land. Space: buy it for $")
			add_int(&t, land_price(g))
		} else {
			add(&t, "Wild land. Buy the land next to it first.")
		}
		color = COLOR_GREEN
	} else {
		switch c.kind {
		case .Empty:
			add(&t, "Soil ")
			add_soil_text(&t, g, g.cursor_x, g.cursor_y)
			add(&t, ". ")
			if g.tool == .Manure {
				add(&t, "Space: manure ($")
				add_int(&t, MANURE_COST)
				add(&t, ")")
			} else if crop, ok := tool_crop(g.tool); ok {
				if !g.licensed[crop] {
					add(&t, CROPS[crop].name)
					add(&t, " license $")
					add_int(&t, CROPS[crop].license)
					add(&t, ": L")
				} else {
					add(&t, "Space: plant ")
					add(&t, CROPS[crop].name)
					if g.seeds[crop] > 0 {
						add(&t, " (seed)")
					} else {
						add(&t, " ($")
						add_int(&t, CROPS[crop].cost)
						add(&t, ")")
					}
				}
			} else if g.tool == .Scarecrow {
				add(&t, "Space: scarecrow ($")
				add_int(&t, SCARECROW_COST)
				add(&t, ")")
			} else {
				add(&t, "Space: hire hand ($")
				add_int(&t, FARMER_COST)
				add(&t, ")")
			}
		case .Crop:
			add(&t, CROPS[c.crop].name)
			if g.tool == .Manure {
				add(&t, " ")
				add_soil_text(&t, g, g.cursor_x, g.cursor_y)
				add(&t, ". Space: manure ($")
				add_int(&t, MANURE_COST)
				add(&t, ")")
			} else if ripe(c) {
				add(&t, ", ripe, rots in ")
				add_int(&t, CROPS[c.crop].keep - int(c.rot))
				add(&t, ". Space: harvest")
			} else {
				add(&t, " ")
				add_halves(&t, int(c.progress))
				add(&t, "/")
				add_int(&t, CROPS[c.crop].grow)
				add(&t, " +")
				step := growth_at(g, g.cursor_x, g.cursor_y)
				n, short := short_of(g, g.cursor_x, g.cursor_y)
				add_halves(&t, short ? step : 2 * step)
				if short {
					add(&t, ", short of ^")
					add(&t, NUTRIENT_NAME[n])
				}
				if guarded(g, g.cursor_x, g.cursor_y) {
					add(&t, ", guarded")
				} else {
					add(&t, ", crows ")
					add_int(&t, CROW_PERCENT)
					add(&t, "%")
				}
			}
		case .Farmer:
			if c.hunger > 0 {
				add(&t, "Farmhand, hungry. Space: move, D: let go")
			} else if c.moved {
				add(&t, "Farmhand, settling in. Space: move")
			} else {
				add(&t, "Farmhand, working. Space: move, D: let go")
			}
		case .Scarecrow:
			add(&t, "Scarecrow ")
			add_int(&t, int(c.health))
			add(&t, "/")
			add_int(&t, SCARECROW_HEALTH)
			add(&t, ". Space: move, D: take down")
		}
	}
	print_rich(f, text_of(&t), PANEL_X, STATUS_Y, color)
	fill_rect(f, 0, LOG_Y - 4, SCREEN_W, 1, COLOR_DARK)
}
