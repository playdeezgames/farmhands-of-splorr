package game

// Layout of the 480 by 270 screen: the field on the left, the tools and the barn on the right,
// buttons under them, the log across the bottom. pointer() uses the same rectangles.

CELL :: 24 // a field cell: a 12 px tile drawn at 2x
FIELD_X :: 12
FIELD_Y :: 24
PANEL_X :: 220
ROWS_Y :: 38 // first tool row
ROW_H :: 16
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
	{{PANEL_X + 108, 177, 68, 14}, "Act Enter", .Confirm},
	{{PANEL_X + 180, 177, 74, 14}, "New farm N", .New_Farm},
	{{PANEL_X, 194, 138, 14}, "", .Expand_Barn}, // labels with prices are made in draw_buttons
	{{PANEL_X + 142, 194, 112, 14}, "", .Buy_Cat},
}

tool_row :: proc(t: Tool) -> Rect {
	return {PANEL_X, ROWS_Y + int(t) * ROW_H - 2, 256, ROW_H}
}

TOOL_GFX := [Tool]Gfx {
	.Farmer  = .Farmer,
	.Carrot  = .Carrot,
	.Wheat   = .Wheat,
	.Cabbage = .Cabbage,
	.Corn    = .Corn,
	.Pumpkin = .Pumpkin,
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
	return COLOR_WHITE
}

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
			command(g, Command(u8(Command.Tool_1) + u8(t)))
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
	// With a farmhand in hand, show the cells they would tend.
	if g.tool == .Farmer {
		x0 := max(g.cursor_x - 1, 0)
		y0 := max(g.cursor_y - 1, 0)
		x1 := min(g.cursor_x + 1, FIELD_W - 1)
		y1 := min(g.cursor_y + 1, FIELD_H - 1)
		frame_rect(f, FIELD_X + x0 * CELL, FIELD_Y + y0 * CELL, (x1 - x0 + 1) * CELL, (y1 - y0 + 1) * CELL, COLOR_CYAN)
	}
	cx := FIELD_X + g.cursor_x * CELL
	cy := FIELD_Y + g.cursor_y * CELL
	frame_rect(f, cx, cy, CELL, CELL, COLOR_WHITE)
	frame_rect(f, cx + 1, cy + 1, CELL - 2, CELL - 2, COLOR_WHITE)
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
	case .Farmer:
		draw_gfx_scaled(f, .Farmer, px, py, 2, c.hunger == 0 ? COLOR_WHITE : COLOR_ORANGE)
		if c.hunger > 0 {
			// one red pip per hungry turn
			for i in 0 ..< int(c.hunger) {
				fill_rect(f, px + 3 + i * 4, py + 3, 3, 3, COLOR_RED)
			}
		}
	case .Crop:
		grow := CROPS[c.crop].grow
		if ripe(c) {
			draw_gfx_scaled(f, TOOL_GFX[Tool(u8(c.crop) + 1)], px, py, 2, CROP_COLOR[c.crop])
		} else {
			stage: Gfx = int(c.progress) * 2 < grow ? .Seedling : .Sprouts
			draw_gfx_scaled(f, stage, px, py, 2, stage == .Seedling ? COLOR_GREEN : COLOR_LIME)
			// growth bar along the bottom
			w := (CELL - 4) * int(c.progress) / grow
			fill_rect(f, px + 2, py + CELL - 3, CELL - 4, 1, COLOR_SOIL)
			fill_rect(f, px + 2, py + CELL - 3, w, 1, COLOR_YELLOW)
		}
	}
}

draw_tools :: proc(f: ^Frame, g: ^Game) {
	print(f, "   In hand   Cost Grow Sells Seeds Barn", PANEL_X, 26, COLOR_MID)
	for t in Tool {
		r := tool_row(t)
		y := r.y + 2
		if t == g.tool {
			fill_rect(f, r.x, r.y, r.w, r.h, COLOR_DARK)
		}
		key: Text
		add_int(&key, int(t) + 1)
		print(f, text_of(&key), PANEL_X + 2, y + 2, COLOR_MID)
		draw_gfx(f, TOOL_GFX[t], PANEL_X + 10, y, tool_color(t))
		crop, ok := tool_crop(t)
		if !ok {
			print(f, "Farmhand", PANEL_X + 26, y + 2, COLOR_WHITE)
			cost: Text
			add(&cost, "$")
			add_int(&cost, FARMER_COST)
			print(f, text_of(&cost), PANEL_X + 80, y + 2, COLOR_YELLOW)
			print(f, "x2 growth, eats", PANEL_X + 110, y + 2, COLOR_LIGHT)
			continue
		}
		info := CROPS[crop]
		print(f, info.name, PANEL_X + 26, y + 2, COLOR_WHITE)
		col :: proc(f: ^Frame, prefix: string, v: int, x, y: int, color: u8) {
			t: Text
			add(&t, prefix)
			add_int(&t, v)
			print(f, text_of(&t), x, y, color)
		}
		col(f, "$", info.cost, PANEL_X + 80, y + 2, COLOR_YELLOW)
		col(f, "", info.grow, PANEL_X + 110, y + 2, COLOR_LIGHT)
		col(f, "$", info.price, PANEL_X + 140, y + 2, COLOR_YELLOW)
		col(f, "", g.seeds[crop], PANEL_X + 182, y + 2, g.seeds[crop] > 0 ? COLOR_LIME : COLOR_MID)
		col(f, "", g.barn[crop], PANEL_X + 218, y + 2, g.barn[crop] > 0 ? COLOR_WHITE : COLOR_MID)
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

// What is under the cursor.
draw_status :: proc(f: ^Frame, g: ^Game) {
	c := cell_at(g, g.cursor_x, g.cursor_y)^
	t: Text
	if !c.owned {
		if can_buy(g, g.cursor_x, g.cursor_y) {
			add(&t, "Wild land. Enter: buy it for $")
			add_int(&t, land_price(g))
		} else {
			add(&t, "Wild land. Buy the land next to it first.")
		}
		print(f, text_of(&t), PANEL_X, 213, COLOR_GREEN)
		t = {}
	} else {
	switch c.kind {
	case .Empty:
		add(&t, "Soil. Enter: ")
		if crop, ok := tool_crop(g.tool); ok {
			add(&t, "plant ")
			add(&t, CROPS[crop].name)
			if g.seeds[crop] > 0 {
				add(&t, " (seed)")
			} else {
				add(&t, " ($")
				add_int(&t, CROPS[crop].cost)
				add(&t, ")")
			}
		} else {
			add(&t, "hire a farmhand ($")
			add_int(&t, FARMER_COST)
			add(&t, ")")
		}
	case .Crop:
		add(&t, CROPS[c.crop].name)
		if ripe(c) {
			add(&t, ", ripe. Enter: harvest")
		} else {
			add(&t, ": ")
			add_int(&t, int(c.progress))
			add(&t, "/")
			add_int(&t, CROPS[c.crop].grow)
			add(&t, ", +")
			add_int(&t, growth_at(g, g.cursor_x, g.cursor_y))
			add(&t, " a turn")
		}
	case .Farmer:
		add(&t, c.hunger == 0 ? "Farmhand, fed and working" : "Farmhand, hungry")
	}
	print(f, text_of(&t), PANEL_X, 213, COLOR_WHITE)
	}
	fill_rect(f, 0, LOG_Y - 4, SCREEN_W, 1, COLOR_DARK)
}
