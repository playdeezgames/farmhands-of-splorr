#+build !js
package game

import "core:testing"

@(test)
starts_with_money_and_an_empty_field :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	testing.expect_value(t, g.money, START_MONEY)
	testing.expect_value(t, g.turn, 1)
	for c in g.field {
		testing.expect_value(t, c.kind, Cell_Kind.Empty)
	}
}

@(test)
planting_costs_money_or_a_seed :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	testing.expect(t, plant(&g, 0, 0, .Carrot))
	testing.expect_value(t, g.money, START_MONEY - CROPS[.Carrot].cost)
	g.seeds[.Carrot] = 1
	testing.expect(t, plant(&g, 1, 0, .Carrot))
	testing.expect_value(t, g.money, START_MONEY - CROPS[.Carrot].cost)
	testing.expect_value(t, g.seeds[.Carrot], 0)
	testing.expect(t, !plant(&g, 1, 0, .Wheat)) // occupied
	g.money = 0
	testing.expect(t, !plant(&g, 2, 0, .Pumpkin))
	testing.expect_value(t, cell_at(&g, 2, 0).kind, Cell_Kind.Empty)
}

@(test)
crops_ripen_after_their_turns_and_harvest_into_the_barn :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	plant(&g, 0, 0, .Wheat)
	for _ in 0 ..< CROPS[.Wheat].grow - 1 {
		end_turn(&g)
	}
	testing.expect(t, !ripe(cell_at(&g, 0, 0)^))
	testing.expect(t, !harvest(&g, 0, 0))
	end_turn(&g)
	testing.expect(t, ripe(cell_at(&g, 0, 0)^))
	testing.expect(t, harvest(&g, 0, 0))
	testing.expect_value(t, g.barn[.Wheat], 1)
	testing.expect_value(t, cell_at(&g, 0, 0).kind, Cell_Kind.Empty)
}

@(test)
a_fed_farmer_speeds_up_all_eight_neighbours :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	g.money = 1000
	g.barn[.Carrot] = 10
	hire(&g, 4, 4)
	for y in 3 ..= 5 {
		for x in 3 ..= 5 {
			if x != 4 || y != 4 {
				plant(&g, x, y, .Corn)
			}
		}
	}
	plant(&g, 0, 0, .Corn) // far away
	end_turn(&g)
	for y in 3 ..= 5 {
		for x in 3 ..= 5 {
			if x != 4 || y != 4 {
				testing.expect_value(t, int(cell_at(&g, x, y).progress), 1 + FARMER_BOOST)
			}
		}
	}
	testing.expect_value(t, int(cell_at(&g, 0, 0).progress), 1)
	testing.expect_value(t, g.barn[.Carrot], 10 - FARMER_APPETITE)
}

@(test)
two_farmers_stack :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	g.money = 1000
	g.barn[.Carrot] = 10
	hire(&g, 0, 0)
	hire(&g, 2, 0)
	plant(&g, 1, 0, .Pumpkin)
	end_turn(&g)
	testing.expect_value(t, int(cell_at(&g, 1, 0).progress), 1 + 2 * FARMER_BOOST)
}

@(test)
a_hungry_farmer_does_not_work_and_then_quits :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	g.money = 1000
	hire(&g, 0, 0)
	plant(&g, 1, 0, .Pumpkin)
	end_turn(&g)
	testing.expect_value(t, int(cell_at(&g, 1, 0).progress), 1)
	testing.expect_value(t, int(cell_at(&g, 0, 0).hunger), 1)
	testing.expect(t, .Hungry in g.events)
	for _ in 0 ..< FARMER_PATIENCE {
		end_turn(&g)
	}
	testing.expect_value(t, cell_at(&g, 0, 0).kind, Cell_Kind.Empty)
	testing.expect_value(t, g.quits, 1)
}

@(test)
a_big_crop_feeds_several_meals :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	g.money = 1000
	g.barn[.Pumpkin] = 1
	hire(&g, 0, 0)
	for _ in 0 ..< CROPS[.Pumpkin].food {
		end_turn(&g)
		testing.expect_value(t, int(cell_at(&g, 0, 0).hunger), 0)
	}
	end_turn(&g)
	testing.expect_value(t, int(cell_at(&g, 0, 0).hunger), 1)
}

@(test)
farmers_eat_the_cheapest_meal_first :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	g.money = 1000
	g.barn[.Carrot] = 1
	g.barn[.Pumpkin] = 1
	hire(&g, 0, 0)
	end_turn(&g)
	// carrot: $3 a meal; pumpkin: $22 for 4 meals, $5.50 a meal
	testing.expect_value(t, g.barn[.Carrot], 0)
	testing.expect_value(t, g.barn[.Pumpkin], 1)
}

@(test)
selling_and_keeping_seed :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	g.barn[.Corn] = 3
	testing.expect(t, sell(&g, .Corn, 1))
	testing.expect_value(t, g.money, START_MONEY + CROPS[.Corn].price)
	testing.expect(t, make_seeds(&g, .Corn))
	testing.expect_value(t, g.seeds[.Corn], CROPS[.Corn].seeds)
	testing.expect(t, sell(&g, .Corn, 99))
	testing.expect_value(t, g.barn[.Corn], 0)
	testing.expect(t, !sell(&g, .Corn, 1))
	testing.expect(t, !make_seeds(&g, .Corn))
}

@(test)
hiring_needs_the_money :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	g.money = FARMER_COST - 1
	testing.expect(t, !hire(&g, 0, 0))
	g.money = FARMER_COST
	testing.expect(t, hire(&g, 0, 0))
	testing.expect_value(t, g.money, 0)
}

@(test)
commands_and_pointer_route :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	command(&g, .Tool_1)
	testing.expect_value(t, g.tool, Tool.Farmer)
	command(&g, .Prev_Tool)
	testing.expect_value(t, g.tool, Tool.Pumpkin)
	command(&g, .Sell) // nothing in the barn
	testing.expect(t, .Denied in g.events)
	command(&g, .Tool_2)
	pointer(&g, FIELD_X + 2 * CELL + 5, FIELD_Y + 3 * CELL + 5)
	testing.expect_value(t, g.cursor_x, 2)
	testing.expect_value(t, g.cursor_y, 3)
	testing.expect_value(t, cell_at(&g, 2, 3).kind, Cell_Kind.Crop)
	testing.expect_value(t, sound_for(g.events), Sfx.Plant)
	r := tool_row(.Corn)
	pointer(&g, r.x + 5, r.y + 5)
	testing.expect_value(t, g.tool, Tool.Corn)
	command(&g, .New_Farm)
	testing.expect(t, g.confirm_new)
	command(&g, .New_Farm)
	testing.expect_value(t, cell_at(&g, 2, 3).kind, Cell_Kind.Empty)
}

@(test)
saves_round_trip :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	plant(&g, 3, 3, .Cabbage)
	end_turn(&g)
	buf: [SAVE_SIZE]u8
	n := write_save(&g, buf[:])
	testing.expect_value(t, n, SAVE_SIZE)
	h: Game
	testing.expect(t, read_save(&h, buf[:n]))
	testing.expect_value(t, h.turn, g.turn)
	testing.expect_value(t, cell_at(&h, 3, 3).crop, Crop.Cabbage)
	buf[0] = 0
	testing.expect(t, !read_save(&h, buf[:n]))
}

@(test)
draws_without_crashing :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	g.money = 1000
	g.barn[.Carrot] = 1
	hire(&g, 1, 1)
	plant(&g, 0, 0, .Carrot)
	plant(&g, 2, 2, .Pumpkin)
	end_turn(&g)
	end_turn(&g)
	f := new(Frame)
	defer free(f)
	draw_game(f, &g)
	resolve(f)
	lit := 0
	for p in f.px {
		if p != COLOR_BLACK {
			lit += 1
		}
	}
	testing.expect(t, lit > 1000)
}
