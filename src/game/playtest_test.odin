#+build !js
package game

import "core:testing"

// The November 27, 2026 playtest: licenses, ten crops, seed and sell rules, stats, tabs, the tutorial
// and the manual.

ripen :: proc(g: ^Game, x, y: int) {
	c := cell_at(g, x, y)
	c.progress = u8(2 * CROPS[c.crop].grow)
}

@(test)
only_carrots_are_licensed_at_the_start :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	for crop in Crop {
		testing.expect_value(t, g.licensed[crop], crop == .Carrot)
	}
	testing.expect(t, !plant(&g, 3, 3, .Radish))
	testing.expect(t, .Denied in g.events)
	testing.expect_value(t, cell_at(&g, 3, 3).kind, Cell_Kind.Empty)
	testing.expect_value(t, g.money, START_MONEY)
	testing.expect(t, plant(&g, 3, 3, .Carrot))
}

@(test)
licenses_are_bought_in_any_order :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	g.money = 5
	g.tool = .Pumpkin
	command(&g, .License)
	testing.expect(t, !g.licensed[.Pumpkin])
	testing.expect(t, .Denied in g.events)
	g.money = 1000
	command(&g, .License) // the dearest first: no ladder
	testing.expect(t, g.licensed[.Pumpkin])
	testing.expect_value(t, g.money, 1000 - CROPS[.Pumpkin].license)
	testing.expect_value(t, sound_for(g.events), Sfx.License)
	command(&g, .License) // once is enough
	testing.expect(t, .Denied in g.events)
	testing.expect_value(t, g.stats.licenses, 1)
	testing.expect(t, plant(&g, 3, 3, .Pumpkin))
	// the more a crop earns, the more its license costs
	for crop in Crop {
		if crop > .Carrot {
			testing.expect(t, CROPS[crop].license > CROPS[Crop(u8(crop) - 1)].license)
		}
	}
}

@(test)
a_locked_rows_price_buys_its_license :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	r := tool_row(.Radish)
	pointer(&g, r.x + 30, r.y + 3) // the name selects
	testing.expect_value(t, g.tool, Tool.Radish)
	testing.expect(t, !g.licensed[.Radish])
	pointer(&g, r.x + 100, r.y + 3) // the price buys
	testing.expect(t, g.licensed[.Radish])
}

@(test)
the_seed_target_is_kept_topped_up_from_the_barn :: proc(t: ^testing.T) {
	g: Game
	init_test(&g)
	g.tool = .Wheat
	command(&g, .Seed_Target_Up)
	command(&g, .Seed_Target_Up)
	testing.expect_value(t, g.seed_target[.Wheat], 2)
	plant(&g, 3, 3, .Wheat)
	ripen(&g, 3, 3)
	testing.expect(t, harvest(&g, 3, 3))
	// one wheat gives 3 seeds: the target is met and the barn is empty
	testing.expect_value(t, g.seeds[.Wheat], CROPS[.Wheat].seeds)
	testing.expect_value(t, g.barn[.Wheat], 0)
	testing.expect_value(t, g.crop_stats[.Wheat].seeded, 1)
	// a second harvest stays in the barn
	plant(&g, 3, 4, .Wheat) // uses a seed: 2 left, still on target
	testing.expect_value(t, g.seeds[.Wheat], 2)
	ripen(&g, 3, 4)
	harvest(&g, 3, 4)
	testing.expect_value(t, g.barn[.Wheat], 1)
	// planting below the target tops up from the barn at once
	plant(&g, 4, 4, .Wheat)
	plant(&g, 4, 3, .Wheat)
	testing.expect_value(t, g.seeds[.Wheat], CROPS[.Wheat].seeds)
	testing.expect_value(t, g.barn[.Wheat], 0)
}

@(test)
crops_over_the_sell_above_number_are_sold :: proc(t: ^testing.T) {
	g: Game
	init_test(&g)
	g.tool = .Corn
	testing.expect_value(t, g.sell_above[.Corn], SELL_ABOVE_OFF)
	g.barn[.Corn] = 5
	command(&g, .Sell_Above_Up) // off to 0: sells the lot
	testing.expect_value(t, g.sell_above[.Corn], 0)
	testing.expect_value(t, g.barn[.Corn], 0)
	testing.expect_value(t, g.money, START_MONEY + 5 * CROPS[.Corn].price)
	testing.expect_value(t, g.crop_stats[.Corn].auto_sold, 5)
	command(&g, .Sell_Above_Up)
	command(&g, .Sell_Above_Up)
	g.barn[.Corn] = 2
	plant(&g, 3, 3, .Corn)
	ripen(&g, 3, 3)
	harvest(&g, 3, 3)
	testing.expect_value(t, g.barn[.Corn], 2)
	command(&g, .Sell_Above_Down)
	command(&g, .Sell_Above_Down)
	command(&g, .Sell_Above_Down) // back to off
	testing.expect_value(t, g.sell_above[.Corn], SELL_ABOVE_OFF)
	command(&g, .Sell_Above_Down) // stays off
	testing.expect_value(t, g.sell_above[.Corn], SELL_ABOVE_OFF)
	// seed first, then sell
	g.barn[.Corn] = 4
	g.seeds[.Corn] = 0
	g.seed_target[.Corn] = 5
	g.sell_above[.Corn] = 1
	auto_barn(&g, .Corn)
	testing.expect_value(t, g.seeds[.Corn], 6) // two corn kept back, 3 seeds each
	testing.expect_value(t, g.barn[.Corn], 1)
}

@(test)
a_full_barn_seeds_before_it_sells :: proc(t: ^testing.T) {
	g: Game
	init_test(&g)
	g.barn[.Wheat] = BARN_CAPACITY
	g.seed_target[.Carrot] = 1
	plant(&g, 3, 3, .Carrot)
	ripen(&g, 3, 3)
	harvest(&g, 3, 3)
	// the carrot went to seed, so nothing was sold
	testing.expect_value(t, g.seeds[.Carrot], CROPS[.Carrot].seeds)
	testing.expect_value(t, g.crop_stats[.Carrot].auto_sold, 0)
	plant(&g, 3, 4, .Carrot) // from seed
	plant(&g, 4, 4, .Carrot)
	ripen(&g, 3, 4)
	harvest(&g, 3, 4) // both plantings used seeds, so this one goes to seed too
	ripen(&g, 4, 4)
	money := g.money
	g.seed_target[.Carrot] = 0
	harvest(&g, 4, 4) // barn full: sold
	testing.expect_value(t, g.money, money + CROPS[.Carrot].price)
	testing.expect_value(t, g.crop_stats[.Carrot].auto_sold, 1)
	testing.expect_value(t, barn_count(&g), BARN_CAPACITY)
}

@(test)
stats_count_what_happens :: proc(t: ^testing.T) {
	g: Game
	init_test(&g)
	g.money = 1000
	plant(&g, 3, 3, .Carrot)
	plant(&g, 4, 3, .Carrot)
	testing.expect_value(t, g.crop_stats[.Carrot].planted, 2)
	ripen(&g, 3, 3)
	harvest(&g, 3, 3)
	testing.expect_value(t, g.crop_stats[.Carrot].harvested, 1)
	g.tool = .Carrot
	command(&g, .Seeds)
	testing.expect_value(t, g.crop_stats[.Carrot].seeded, 1)
	g.barn[.Carrot] = 2
	command(&g, .Sell)
	testing.expect_value(t, g.crop_stats[.Carrot].sold, 1)
	hire(&g, 3, 4)
	testing.expect_value(t, g.stats.hired, 1)
	command(&g, .Buy_Cat)
	command(&g, .Expand_Barn)
	testing.expect_value(t, g.stats.cats, 1)
	testing.expect_value(t, g.stats.expansions, 1)
	place_scarecrow(&g, 4, 4)
	testing.expect_value(t, g.stats.scarecrows, 1)
	g.cursor_x, g.cursor_y = 4, 4
	command(&g, .Dismiss)
	testing.expect_value(t, g.stats.scarecrows_down, 1)
	g.cursor_x, g.cursor_y = 3, 4
	command(&g, .Dismiss)
	testing.expect_value(t, g.stats.let_go, 1)
	buy_land(&g, 2, 3)
	testing.expect_value(t, g.stats.land, 1)
	soil_at(&g, 4, 4)^ = {}
	manure(&g, 4, 4)
	testing.expect_value(t, g.stats.manure, 1)
	g.barn[.Carrot] = 1
	end_turn(&g) // nobody to feed now, but the barn
	testing.expect(t, g.stats.spent > 0)
	testing.expect_value(t, g.stats.earned, CROPS[.Carrot].price)
	testing.expect_value(t, g.money, 1000 - g.stats.spent + g.stats.earned)
	// rats count what they eat
	g.barn[.Wheat] = 4
	rats_feast(&g)
	testing.expect_value(t, g.crop_stats[.Wheat].rats, 2)
	// farmhands count what they eat
	init_test(&g)
	hire_free :: proc(g: ^Game, x, y: int) {cell_at(g, x, y)^ = {owned = true, kind = .Farmer, fed = true}}
	hire_free(&g, 3, 3)
	g.barn[.Cabbage] = 1
	end_turn(&g)
	testing.expect_value(t, g.crop_stats[.Cabbage].fed, 1)
}

@(test)
crows_and_rot_are_counted :: proc(t: ^testing.T) {
	g: Game
	init_test(&g, 99)
	own_all(&g)
	for i in 0 ..< FIELD_W * FIELD_H {
		g.field[i] = {owned = true, kind = .Crop, crop = .Onion}
	}
	for _ in 0 ..< 40 {
		end_turn(&g)
	}
	s := g.crop_stats[.Onion]
	testing.expect(t, s.crows > 0)
	testing.expect(t, s.rotted > 0)
}

@(test)
tutorial_goals_tick_off_in_order :: proc(t: ^testing.T) {
	g: Game
	init_tutorial(&g)
	testing.expect_value(t, g.tutorial, 1)
	command(&g, .End_Turn) // not the goal yet
	testing.expect_value(t, g.tutorial, 1)
	g.cursor_x, g.cursor_y = 3, 3
	command(&g, .Tool_4)
	command(&g, .Confirm)
	testing.expect_value(t, g.tutorial, 2)
	testing.expect_value(t, sound_for(g.events), Sfx.Goal)
	command(&g, .End_Turn)
	testing.expect_value(t, g.tutorial, 3)
	for !ripe(cell_at(&g, 3, 3)^) {
		command(&g, .End_Turn)
	}
	command(&g, .Confirm)
	testing.expect_value(t, g.tutorial, 4)
	command(&g, .Seeds)
	testing.expect_value(t, g.tutorial, 5)
	g.barn[.Carrot] = 1
	command(&g, .Sell)
	testing.expect_value(t, g.tutorial, 6)
	g.money = 1000
	g.cursor_x, g.cursor_y = 2, 3
	command(&g, .Confirm)
	testing.expect_value(t, g.tutorial, 7)
	command(&g, .Tool_1)
	g.cursor_x, g.cursor_y = 4, 4
	command(&g, .Confirm)
	testing.expect_value(t, g.tutorial, 8)
	command(&g, .Tool_2)
	g.cursor_x, g.cursor_y = 4, 3
	command(&g, .Confirm)
	testing.expect_value(t, g.tutorial, 9)
	command(&g, .Tool_5)
	command(&g, .License)
	testing.expect_value(t, g.tutorial, 10)
	command(&g, .Seed_Target_Up)
	testing.expect_value(t, g.tutorial, 0) // done
	// skip and restart from the Help tab's button
	command(&g, .Tutorial)
	testing.expect(t, g.confirm_tutorial)
	command(&g, .Tutorial)
	testing.expect_value(t, g.tutorial, 1)
	command(&g, .Tutorial)
	testing.expect_value(t, g.tutorial, 0)
}

@(test)
tabs_and_pages :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	testing.expect_value(t, g.panel, Panel.Farm)
	command(&g, .Next_Tab)
	testing.expect_value(t, g.panel, Panel.Barn)
	command(&g, .Prev_Tab)
	command(&g, .Prev_Tab)
	testing.expect_value(t, g.panel, Panel.Help)
	command(&g, .Page_Prev)
	testing.expect_value(t, g.page, len(HELP) - 1)
	command(&g, .Page_Next)
	testing.expect_value(t, g.page, 0)
	for p in Panel {
		r := tab_rect(p)
		pointer(&g, r.x + 3, r.y + 3)
		testing.expect_value(t, g.panel, p)
		testing.expect_value(t, g.page, 0)
	}
	// every button on every tab answers a click there
	for p in Panel {
		for b in BUTTONS {
			if p not_in b.panels {
				continue
			}
			init_game(&g)
			show_panel(&g, p)
			pointer(&g, b.rect.x + 2, b.rect.y + 2)
			testing.expect(t, g.events != {}, "a button did nothing")
		}
	}
	// the Barn tab's steppers
	init_game(&g)
	show_panel(&g, .Barn)
	r := row_rect(int(Crop.Peas))
	pointer(&g, PANEL_X + BARN_SEED_UP_X + 2, r.y + 3)
	testing.expect_value(t, g.tool, Tool.Peas)
	testing.expect_value(t, g.seed_target[.Peas], 1)
	pointer(&g, PANEL_X + BARN_SELL_UP_X + 2, r.y + 3)
	testing.expect_value(t, g.sell_above[.Peas], 0)
	pointer(&g, PANEL_X + BARN_SELL_DOWN_X + 2, r.y + 3)
	testing.expect_value(t, g.sell_above[.Peas], SELL_ABOVE_OFF)
	pointer(&g, PANEL_X + BARN_SEED_DOWN_X + 2, r.y + 3)
	testing.expect_value(t, g.seed_target[.Peas], 0)
}

@(test)
the_layout_fits :: proc(t: ^testing.T) {
	testing.expect(t, tool_row(max(Tool)).y + ROW_H <= SHARED_Y)
	testing.expect(t, row_rect(len(Crop)).y + 22 <= TAB_BUTTONS_Y)
	for b in BUTTONS {
		testing.expect(t, b.rect.x >= PANEL_X && b.rect.x + b.rect.w <= PANEL_X + PANEL_W)
		testing.expect(t, b.rect.y + b.rect.h <= STATUS_Y)
	}
	for page in HELP {
		testing.expect(t, len(page.lines) <= HELP_LINES, page.title)
		for line in page.lines {
			testing.expect(t, rich_width(line) <= HELP_COLS * GLYPH_W, line)
		}
	}
	for step in TUTORIAL {
		testing.expect(t, len(step.goal) + len("Goal 10/10: ") <= LOG_COLS, step.goal)
	}
}

@(test)
saves_keep_the_new_things :: proc(t: ^testing.T) {
	g: Game
	init_tutorial(&g)
	g.licensed[.Tomato] = true
	g.seed_target[.Tomato] = 4
	g.sell_above[.Tomato] = 7
	g.crop_stats[.Tomato].rotted = 3
	g.stats.spent = 99
	g.panel = .Help
	g.page = 4
	buf: [SAVE_SIZE]u8
	n := write_save(&g, buf[:])
	h: Game
	testing.expect(t, read_save(&h, buf[:n]))
	testing.expect(t, h.licensed[.Tomato])
	testing.expect_value(t, h.seed_target[.Tomato], 4)
	testing.expect_value(t, h.sell_above[.Tomato], 7)
	testing.expect_value(t, h.crop_stats[.Tomato].rotted, 3)
	testing.expect_value(t, h.stats.spent, 99)
	testing.expect_value(t, h.panel, Panel.Help)
	testing.expect_value(t, h.page, 4)
	testing.expect_value(t, h.tutorial, 1)
	// out of range is refused
	g.page = 99
	write_save(&g, buf[:])
	testing.expect(t, !read_save(&h, buf[:n]))
	// a version 6 save starts a new farm
	g.page = 0
	write_save(&g, buf[:])
	put_u32(buf[4:], 6)
	testing.expect(t, !read_save(&h, buf[:n]))
}

@(test)
every_screen_draws :: proc(t: ^testing.T) {
	g := new(Game)
	defer free(g)
	f := new(Frame)
	defer free(f)
	init_tutorial(g)
	dump_farm(g)
	for p in Panel {
		for page in 0 ..< page_count(p) {
			g.panel = p
			g.page = page
			draw_game(f, g)
		}
	}
	testing.expect(t, true)
}
