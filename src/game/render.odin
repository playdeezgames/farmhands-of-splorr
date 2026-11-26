package game

// Layout of the 480 by 270 screen: the field on the left, the tools and the barn on the right,
// buttons under them, the log across the bottom. pointer() uses the same rectangles.

CELL :: 24 // a field cell: a 12 px tile drawn at 2x
FIELD_X :: 12
FIELD_Y :: 24
PANEL_X :: 220
ROWS_Y :: 38 // first tool row
ROW_H :: 12
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
}

BUTTONS := [?]Button {
	{{PANEL_X, 160, 62, 14}, "Sell 1 X", .Sell},
	{{PANEL_X + 66, 160, 86, 14}, "Sell all A", .Sell_All},
	{{PANEL_X + 156, 160, 98, 14}, "Keep seed Z", .Seeds},
	{{PANEL_X, 177, 104, 14}, "End turn T", .End_Turn},
	{{PANEL_X + 108, 177, 68, 14}, "Act Space", .Confirm},
	{{PANEL_X + 180, 177, 74, 14}, "New farm N", .New_Farm},
	{{PANEL_X, 194, 104, 14}, "", .Expand_Barn}, // labels with prices are made in draw_buttons
	{{PANEL_X + 108, 194, 70, 14}, "", .Buy_Cat},
	{{PANEL_X + 182, 194, 72, 14}, "Let go D", .Dismiss},
}

tool_row :: proc(t: Tool) -> Rect {
	return {PANEL_X, ROWS_Y - 2 + int(t) * ROW_H, 256, ROW_H}
}

TOOL_GFX := [Tool]Gfx {
	.Farmer  = .Farmer,
	.Carrot  = .Carrot,
	.Wheat   = .Wheat,
	.Cabbage = .Cabbage,
	.Corn    = .Corn,
	.Pumpkin = .Pumpkin,
	.Scarecrow = .Scarecrow,
	.Manure = .Manure,
}

CROP_COLOR := [Crop]u8 {
	.Carrot  = COLOR_ORANGE,
	.Wheat   = COLOR_YELLOW,
	.Cabbage = COLOR_LIME,
	.Corn    = COLOR_YELLOW,
	.Pumpkin = COLOR_ORANGE,
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

tool_command :: proc(t: Tool) -> Command {
	#partial switch t {
	case .Scarecrow:
		return .Tool_7
	case .Manure:
		return .Tool_8
	}
	return Command(u8(Command.Tool_1) + u8(t))
}

// The colours of the soil bars: N, P, K.
NUTRIENT_COLOR := [Nutrient]u8{.N = COLOR_LIME, .P = COLOR_SKY, .K = COLOR_YELLOW}

// A click or tap at framebuffer pixel (x, y).
pointer :: proc(g: ^Game, x, y: int) {
	g.events = {}
	field := Rect{FIELD_X, FIELD_Y, FIELD_W * CELL, FIELD_H * CELL}
	if inside(field, x, y) {
		g.confirm_new = false
		g.cursor_x = (x - FIELD_X) / CELL
		g.cursor_y = (y - FIELD_Y) / CELL
		act(g)
		return
	}
	for t in Tool {
		if inside(tool_row(t), x, y) {
			command(g, tool_command(t))
			return
		}
	}
	for b in BUTTONS {
		if inside(b.rect, x, y) {
			command(g, b.command)
			return
		}
	}
}

draw_game :: proc(f: ^Frame, g: ^Game) {
	cls(f, COLOR_BLACK)
	draw_header(f, g)
	draw_field(f, g)
	draw_tools(f, g)
	draw_buttons(f, g)
	draw_status(f, g)
	for i in 0 ..< LOG_LINES {
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
			draw_gfx_scaled(f, TOOL_GFX[Tool(u8(c.crop) + 1)], px, py, 2, left <= 1 ? COLOR_MID : CROP_COLOR[c.crop])
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
}

draw_tools :: proc(f: ^Frame, g: ^Game) {
	for h in ([?]struct {
			label: string,
			x:     int,
		}{{"In hand", 26}, {"Buy", 86}, {"Grow", 108}, {"Sell", 136}, {"Soil", 164}, {"Seed", 196}, {"Barn", 224}}) {
		print(f, h.label, PANEL_X + h.x, 26, COLOR_MID)
	}
	for t in Tool {
		r := tool_row(t)
		y := r.y
		if t == g.tool {
			fill_rect(f, r.x, r.y, r.w, r.h, COLOR_DARK)
		}
		key: Text
		add_int(&key, int(t) + 1)
		print(f, text_of(&key), PANEL_X + 2, y + 2, COLOR_MID)
		draw_gfx(f, TOOL_GFX[t], PANEL_X + 10, y, tool_color(t))
		col :: proc(f: ^Frame, prefix: string, v: int, x, y: int, color: u8) {
			t: Text
			add(&t, prefix)
			add_int(&t, v)
			print(f, text_of(&t), x, y, color)
		}
		crop, is_crop := tool_crop(t)
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
			print(f, name, PANEL_X + 26, y + 2, COLOR_WHITE)
			col(f, "$", price, PANEL_X + 86, y + 2, COLOR_YELLOW)
			print(f, note, PANEL_X + 114, y + 2, COLOR_LIGHT)
			continue
		}
		info := CROPS[crop]
		print(f, info.name, PANEL_X + 26, y + 2, COLOR_WHITE)
		col(f, "$", info.cost, PANEL_X + 86, y + 2, COLOR_YELLOW)
		col(f, "", info.grow, PANEL_X + 114, y + 2, COLOR_LIGHT)
		col(f, "$", info.price, PANEL_X + 136, y + 2, COLOR_YELLOW)
		// what it takes from the soil and puts back, e.g. "-N2+K" (an amount of 1 is left out)
		soil: Text
		for sign in ([?]string{"-", "+"}) {
			for n in Nutrient {
				v := sign == "-" ? info.uses[int(n)] : info.gives[int(n)]
				if v > 0 {
					add(&soil, sign)
					add(&soil, NUTRIENT_NAME[n])
					if v > 1 {
						add_int(&soil, v)
					}
				}
			}
		}
		print(f, text_of(&soil), PANEL_X + 162, y + 2, COLOR_LIGHT)
		col(f, "", g.seeds[crop], PANEL_X + 202, y + 2, g.seeds[crop] > 0 ? COLOR_LIME : COLOR_MID)
		col(f, "", g.barn[crop], PANEL_X + 228, y + 2, g.barn[crop] > 0 ? COLOR_WHITE : COLOR_MID)
	}
	draw_gfx(f, .Barn, PANEL_X, 136, COLOR_ORANGE)
	t: Text
	add(&t, "Barn ")
	add_int(&t, barn_count(g))
	add(&t, "/")
	add_int(&t, barn_capacity(g))
	add(&t, "  Meals ")
	add_int(&t, meals_in_barn(g))
	add(&t, "  Hands ")
	add_int(&t, farmer_count(g))
	print(f, text_of(&t), PANEL_X + 16, 138, barn_count(g) >= barn_capacity(g) ? COLOR_ORANGE : COLOR_LIGHT)
	draw_gfx(f, .Rat, PANEL_X, 146, COLOR_LIGHT)
	r: Text
	add(&r, "Rats ")
	add_int(&r, rat_chance(g))
	add(&r, "% a turn")
	print(f, text_of(&r), PANEL_X + 16, 148, rat_chance(g) > 0 ? COLOR_ORANGE : COLOR_MID)
	draw_gfx(f, .Cat, PANEL_X + 130, 146, COLOR_LIGHT)
	k: Text
	add(&k, "Cats ")
	add_int(&k, g.cats)
	add(&k, ", ")
	add_int(&k, CAT_WANDER_PERCENT)
	add(&k, "% roam")
	print(f, text_of(&k), PANEL_X + 146, 148, COLOR_LIGHT)
}

draw_buttons :: proc(f: ^Frame, g: ^Game) {
	for b in BUTTONS {
		color := COLOR_LIGHT
		if b.command == .New_Farm && g.confirm_new {
			color = COLOR_ORANGE
		}
		label := b.label
		t: Text
		#partial switch b.command {
		case .Expand_Barn:
			add(&t, "Barn +")
			add_int(&t, BARN_STEP)
			add(&t, " $")
			add_int(&t, barn_price(g))
			add(&t, " B")
			label = text_of(&t)
		case .Buy_Cat:
			add(&t, "Cat $")
			add_int(&t, CAT_COST)
			add(&t, " C")
			label = text_of(&t)
		}
		fill_rect(f, b.rect.x, b.rect.y, b.rect.w, b.rect.h, COLOR_DARK)
		frame_rect(f, b.rect.x, b.rect.y, b.rect.w, b.rect.h, COLOR_MID)
		print(f, label, b.rect.x + (b.rect.w - text_width(label)) / 2, b.rect.y + (b.rect.h - GLYPH_H) / 2, u8(color))
	}
}

// "N4 P2 K1" for the square at (x, y).
add_soil_text :: proc(t: ^Text, g: ^Game, x, y: int) {
	for n, i in Nutrient {
		if i > 0 {
			add(t, " ")
		}
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
			add(&t, ". Space: ")
			if g.tool == .Manure {
				add(&t, "manure ($")
				add_int(&t, MANURE_COST)
				add(&t, ")")
			} else if crop, ok := tool_crop(g.tool); ok {
				add(&t, "plant ")
				add(&t, CROPS[crop].name)
				if g.seeds[crop] > 0 {
					add(&t, " (seed)")
				} else {
					add(&t, " ($")
					add_int(&t, CROPS[crop].cost)
					add(&t, ")")
				}
			} else if g.tool == .Scarecrow {
				add(&t, "scarecrow ($")
				add_int(&t, SCARECROW_COST)
				add(&t, ")")
			} else {
				add(&t, "hire hand ($")
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
					add(&t, ", short of ")
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
	print(f, text_of(&t), PANEL_X, 213, color)
	fill_rect(f, 0, LOG_Y - 4, SCREEN_W, 1, COLOR_DARK)
}
