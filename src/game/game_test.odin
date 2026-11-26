#+build !js
package game

import "core:testing"

// Most tests want the whole field to plant on.
own_all :: proc(g: ^Game) {
	for &c in g.field {
		c.owned = true
	}
}

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
	own_all(&g)
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
	own_all(&g)
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
	own_all(&g)
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
	own_all(&g)
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
	own_all(&g)
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
	own_all(&g)
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
	own_all(&g)
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
	own_all(&g)
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
	own_all(&g)
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
	own_all(&g)
	command(&g, .Tool_1)
	testing.expect_value(t, g.tool, Tool.Farmer)
	command(&g, .Prev_Tool)
	testing.expect_value(t, g.tool, Tool.Scarecrow)
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
	own_all(&g)
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
	own_all(&g)
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

@(test)
starts_with_only_the_middle_four_squares :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	owned := 0
	for c in g.field {
		if c.owned {
			owned += 1
		}
	}
	testing.expect_value(t, owned, 4)
	for y in 3 ..= 4 {
		for x in 3 ..= 4 {
			testing.expect(t, cell_at(&g, x, y).owned)
		}
	}
	testing.expect(t, !plant(&g, 0, 0, .Carrot))
	testing.expect(t, !hire(&g, 0, 0))
	testing.expect(t, plant(&g, 3, 3, .Carrot))
}

@(test)
land_is_bought_next_to_owned_land_and_gets_dearer :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	g.money = 1000
	testing.expect(t, !can_buy(&g, 0, 0))
	testing.expect(t, !can_buy(&g, 2, 2)) // diagonal only
	testing.expect(t, can_buy(&g, 2, 3))
	testing.expect(t, !buy_land(&g, 0, 0))
	testing.expect_value(t, g.money, 1000)
	prices: [dynamic]int
	defer delete(prices)
	x := 2
	for x >= 0 {
		p := land_price(&g)
		append(&prices, p)
		g.events = {}
		testing.expect(t, buy_land(&g, x, 3))
		testing.expect_value(t, g.events, bit_set[Event]{.Bought})
		x -= 1
	}
	testing.expect_value(t, prices[0], LAND_PRICE)
	for i in 1 ..< len(prices) {
		testing.expect(t, prices[i] > prices[i - 1])
		testing.expect(t, prices[i] - prices[i - 1] >= prices[i - 1] - (i >= 2 ? prices[i - 2] : prices[0]))
	}
	testing.expect_value(t, g.money, 1000 - (prices[0] + prices[1] + prices[2]))
	testing.expect(t, can_buy(&g, 0, 2))
	g.money = 0
	testing.expect(t, !buy_land(&g, 0, 2))
	testing.expect(t, !cell_at(&g, 0, 2).owned)
}

@(test)
acting_on_wild_land_buys_it :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	command(&g, .East) // to (4, 3)
	command(&g, .East) // (5, 3), wild
	command(&g, .Confirm)
	testing.expect(t, cell_at(&g, 5, 3).owned)
	testing.expect_value(t, g.money, START_MONEY - LAND_PRICE)
	testing.expect_value(t, sound_for(g.events), Sfx.Buy)
	command(&g, .Confirm) // now plants
	testing.expect_value(t, cell_at(&g, 5, 3).kind, Cell_Kind.Crop)
}

@(test)
harvest_and_quitting_keep_the_land :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	plant(&g, 3, 3, .Carrot)
	for _ in 0 ..< CROPS[.Carrot].grow {
		end_turn(&g)
	}
	testing.expect(t, harvest(&g, 3, 3))
	testing.expect(t, cell_at(&g, 3, 3).owned)
	g.barn = {} // nothing to eat
	g.money = FARMER_COST
	hire(&g, 4, 4)
	for _ in 0 ..= FARMER_PATIENCE {
		end_turn(&g)
	}
	testing.expect_value(t, cell_at(&g, 4, 4).kind, Cell_Kind.Empty)
	testing.expect(t, cell_at(&g, 4, 4).owned)
}

@(test)
a_full_barn_sells_the_harvest :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	own_all(&g)
	g.barn[.Wheat] = BARN_CAPACITY
	plant(&g, 0, 0, .Carrot)
	g.money += SCARECROW_COST
	place_scarecrow(&g, 1, 1) // no crows
	g.rng = {} // rats or not, the barn is refilled below
	for _ in 0 ..< CROPS[.Carrot].grow {
		end_turn(&g)
	}
	g.barn = {}
	g.barn[.Wheat] = BARN_CAPACITY
	money := g.money
	g.events = {}
	testing.expect(t, harvest(&g, 0, 0))
	testing.expect_value(t, g.barn[.Carrot], 0)
	testing.expect_value(t, g.money, money + CROPS[.Carrot].price)
	testing.expect(t, .Sold in g.events)
	testing.expect_value(t, cell_at(&g, 0, 0).kind, Cell_Kind.Empty)
}

@(test)
the_barn_grows_and_gets_dearer_and_draws_rats :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	g.money = 1000
	testing.expect_value(t, barn_capacity(&g), BARN_CAPACITY)
	testing.expect_value(t, rat_chance(&g), RAT_BASE_PERCENT)
	p0 := barn_price(&g)
	testing.expect_value(t, p0, BARN_PRICE)
	testing.expect(t, expand_barn(&g))
	testing.expect_value(t, barn_capacity(&g), BARN_CAPACITY + BARN_STEP)
	testing.expect_value(t, rat_chance(&g), RAT_BASE_PERCENT + RAT_STEP_PERCENT)
	testing.expect(t, barn_price(&g) > p0)
	testing.expect_value(t, g.money, 1000 - p0)
	testing.expect_value(t, sound_for(g.events), Sfx.Build)
	g.money = 0
	testing.expect(t, !expand_barn(&g))
}

@(test)
cats_lower_the_rat_chance_to_zero_at_most :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	g.money = 1000
	before := rat_chance(&g)
	testing.expect(t, buy_cat(&g))
	testing.expect_value(t, g.cats, 1)
	testing.expect_value(t, g.money, 1000 - CAT_COST)
	testing.expect_value(t, rat_chance(&g), max(before - CAT_DETER_PERCENT, 0))
	for _ in 0 ..< 50 {
		buy_cat(&g)
	}
	testing.expect_value(t, rat_chance(&g), 0)
	g.money = 0
	testing.expect(t, !buy_cat(&g))
}

@(test)
rats_eat_half_the_barn :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	g.barn[.Carrot] = 5
	g.barn[.Corn] = 4
	g.pantry = 3
	testing.expect_value(t, rats_feast(&g), 3 + 2)
	testing.expect_value(t, g.barn[.Carrot], 2)
	testing.expect_value(t, g.barn[.Corn], 2)
	testing.expect_value(t, g.pantry, 1)
}

@(test)
rats_come_about_as_often_as_the_chance_says :: proc(t: ^testing.T) {
	g: Game
	init_game(&g, 12345)
	g.barn_level = 3 // 20%
	chance := rat_chance(&g)
	visits := 0
	TURNS :: 2000
	for _ in 0 ..< TURNS {
		g.barn[.Pumpkin] = 2
		end_turn(&g)
		if .Rats in g.events {
			visits += 1
		}
		g.events = {}
	}
	expected := TURNS * chance / 100
	testing.expectf(t, abs(visits - expected) < expected / 4, "%d visits, expected about %d", visits, expected)
	// With enough cats, never.
	for _ in 0 ..< 200 {
		g.cats = 100 // some wander off every turn
		g.barn[.Pumpkin] = 2
		end_turn(&g)
		testing.expect(t, .Rats not_in g.events)
		g.events = {}
	}
}

@(test)
barn_and_cat_commands :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	g.money = 1000
	command(&g, .Expand_Barn)
	testing.expect_value(t, g.barn_level, 1)
	command(&g, .Buy_Cat)
	testing.expect_value(t, g.cats, 1)
	testing.expect_value(t, sound_for(g.events), Sfx.Cat)
	for b in BUTTONS {
		if b.command == .Buy_Cat {
			pointer(&g, b.rect.x + 2, b.rect.y + 2)
		}
	}
	testing.expect_value(t, g.cats, 2)
}

// --- Cats wander, crows, scarecrows, moving and letting go (November 26, 2026).

@(test)
cats_wander_about_as_often_as_the_chance_says :: proc(t: ^testing.T) {
	g: Game
	init_game(&g, 777)
	left := 0
	TURNS :: 400
	for _ in 0 ..< TURNS {
		g.cats = 50
		end_turn(&g)
		left += 50 - g.cats
		if g.cats < 50 {
			testing.expect(t, .Wandered in g.events)
		}
		g.events = {}
	}
	expected := TURNS * 50 * CAT_WANDER_PERCENT / 100
	testing.expectf(t, abs(left - expected) < expected / 5, "%d wandered, expected about %d", left, expected)
	g.cats = 0
	end_turn(&g)
	testing.expect_value(t, g.cats, 0)
	testing.expect(t, .Wandered not_in g.events)
}

@(test)
cats_guard_the_barn_on_the_turn_they_leave :: proc(t: ^testing.T) {
	// Rats roll first, against this turn's cats: with enough cats they never get in, even when every
	// turn some cats wander off afterwards.
	g: Game
	init_game(&g, 99)
	g.barn_level = 3
	for _ in 0 ..< 300 {
		g.cats = (RAT_BASE_PERCENT + RAT_STEP_PERCENT * 3) / CAT_DETER_PERCENT + 1
		g.barn[.Carrot] = 4
		end_turn(&g)
		testing.expect(t, .Rats not_in g.events)
		g.events = {}
	}
}

@(test)
crows_eat_unguarded_crops :: proc(t: ^testing.T) {
	g: Game
	init_game(&g, 4242)
	own_all(&g)
	eaten := 0
	TURNS :: 300
	for _ in 0 ..< TURNS {
		for y in 0 ..< FIELD_H {
			for x in 0 ..< FIELD_W {
				cell_at(&g, x, y)^ = {owned = true, kind = .Crop, crop = .Pumpkin}
			}
		}
		end_turn(&g)
		this_turn := 0
		for c in g.field {
			if c.kind == .Empty {
				this_turn += 1
			}
		}
		testing.expect_value(t, .Crows in g.events, this_turn > 0)
		eaten += this_turn
		g.events = {}
	}
	expected := TURNS * FIELD_W * FIELD_H * CROW_PERCENT / 100
	testing.expectf(t, abs(eaten - expected) < expected / 5, "%d eaten, expected about %d", eaten, expected)
}

@(test)
a_scarecrow_guards_five_by_five :: proc(t: ^testing.T) {
	g: Game
	init_game(&g, 31337)
	own_all(&g)
	g.money = 1000
	testing.expect(t, place_scarecrow(&g, 2, 2))
	testing.expect_value(t, g.money, 1000 - SCARECROW_COST)
	testing.expect(t, guarded(&g, 0, 0))
	testing.expect(t, guarded(&g, 4, 4))
	testing.expect(t, !guarded(&g, 5, 2))
	testing.expect(t, !guarded(&g, 2, 5))
	outside_eaten := 0
	for _ in 0 ..< 500 {
		for y in 0 ..< FIELD_H {
			for x in 0 ..< FIELD_W {
				c := cell_at(&g, x, y)
				if c.kind != .Scarecrow {
					c^ = {owned = true, kind = .Crop, crop = .Corn}
				} else {
					c.health = SCARECROW_HEALTH // keep it standing
				}
			}
		}
		end_turn(&g)
		for y in 0 ..< FIELD_H {
			for x in 0 ..< FIELD_W {
				if cell_at(&g, x, y).kind == .Empty {
					testing.expectf(t, !guarded(&g, x, y), "guarded crop at %d,%d eaten", x, y)
					outside_eaten += 1
				}
			}
		}
	}
	testing.expect(t, outside_eaten > 0)
}

@(test)
placing_a_scarecrow :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	command(&g, .Tool_7)
	testing.expect_value(t, g.tool, Tool.Scarecrow)
	// wild land is bought, not built on
	testing.expect(t, !place_scarecrow(&g, 0, 0))
	plant(&g, 3, 3, .Carrot)
	testing.expect(t, !place_scarecrow(&g, 3, 3))
	g.money = SCARECROW_COST - 1
	testing.expect(t, !place_scarecrow(&g, 4, 4))
	testing.expect(t, .Denied in g.events)
	g.money = SCARECROW_COST
	g.cursor_x, g.cursor_y = 4, 4
	testing.expect(t, act(&g))
	testing.expect_value(t, cell_at(&g, 4, 4).kind, Cell_Kind.Scarecrow)
	testing.expect_value(t, g.money, 0)
	testing.expect_value(t, sound_for(g.events), Sfx.Build)
}

@(test)
moving_a_farmhand :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	own_all(&g)
	g.money = 1000
	hire(&g, 1, 1)
	cell_at(&g, 1, 1).hunger = 1
	g.cursor_x, g.cursor_y = 1, 1
	testing.expect(t, act(&g)) // pick up
	testing.expect_value(t, g.carrying, Cell_Kind.Farmer)
	testing.expect_value(t, cell_at(&g, 1, 1).kind, Cell_Kind.Empty)
	// while carrying, nothing else happens
	plant(&g, 5, 5, .Carrot)
	hire(&g, 6, 6)
	before := g
	g.cursor_x, g.cursor_y = 5, 5
	testing.expect(t, !act(&g))
	g.cursor_x, g.cursor_y = 6, 6
	testing.expect(t, !act(&g))
	testing.expect_value(t, cell_at(&g, 5, 5)^, before.field[5 * FIELD_W + 5])
	testing.expect_value(t, g.money, before.money)
	// set down elsewhere: hunger kept, settles in
	g.cursor_x, g.cursor_y = 3, 3
	testing.expect(t, act(&g))
	c := cell_at(&g, 3, 3)
	testing.expect_value(t, c.kind, Cell_Kind.Farmer)
	testing.expect_value(t, c.hunger, 1)
	testing.expect(t, c.moved)
	testing.expect_value(t, g.carrying, Cell_Kind.Empty)
	// no boost on the move turn, a boost on the next
	plant(&g, 3, 4, .Pumpkin)
	g.barn[.Pumpkin] = 10
	place_scarecrow(&g, 4, 4)
	cell_at(&g, 6, 6)^ = {owned = true}
	end_turn(&g)
	testing.expect_value(t, int(cell_at(&g, 3, 4).progress), 1)
	testing.expect(t, !cell_at(&g, 3, 3).moved)
	end_turn(&g)
	testing.expect_value(t, int(cell_at(&g, 3, 4).progress), 1 + 1 + FARMER_BOOST)
}

@(test)
putting_a_farmhand_back_is_not_a_move :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	own_all(&g)
	g.money = 1000
	hire(&g, 3, 3)
	plant(&g, 3, 4, .Pumpkin)
	place_scarecrow(&g, 4, 4)
	g.barn[.Pumpkin] = 10
	g.cursor_x, g.cursor_y = 3, 3
	act(&g)
	act(&g) // back where they came from
	testing.expect(t, !cell_at(&g, 3, 3).moved)
	end_turn(&g)
	testing.expect_value(t, int(cell_at(&g, 3, 4).progress), 1 + FARMER_BOOST)
	// ending the turn with a farmhand in hand puts them back
	act(&g)
	g.cursor_x, g.cursor_y = 0, 0
	end_turn(&g)
	testing.expect_value(t, g.carrying, Cell_Kind.Empty)
	testing.expect_value(t, cell_at(&g, 3, 3).kind, Cell_Kind.Farmer)
	testing.expect(t, !cell_at(&g, 3, 3).moved)
}

@(test)
moving_a_scarecrow :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	own_all(&g)
	g.money = 1000
	place_scarecrow(&g, 0, 0)
	g.cursor_x, g.cursor_y = 0, 0
	testing.expect(t, act(&g))
	testing.expect_value(t, g.carrying, Cell_Kind.Scarecrow)
	testing.expect(t, !guarded(&g, 7, 7))
	g.cursor_x, g.cursor_y = 7, 7
	testing.expect(t, act(&g))
	testing.expect(t, guarded(&g, 7, 7))
	testing.expect(t, !guarded(&g, 0, 0))
}

@(test)
letting_go :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	own_all(&g)
	g.money = 1000
	hire(&g, 2, 2)
	place_scarecrow(&g, 5, 5)
	money := g.money
	g.cursor_x, g.cursor_y = 2, 2
	command(&g, .Dismiss)
	testing.expect(t, .Dismissed in g.events)
	testing.expect_value(t, cell_at(&g, 2, 2).kind, Cell_Kind.Empty)
	testing.expect_value(t, g.money, money)
	testing.expect_value(t, sound_for(g.events), Sfx.Dismiss)
	command(&g, .Dismiss) // soil now
	testing.expect(t, .Denied in g.events)
	g.cursor_x, g.cursor_y = 5, 5
	command(&g, .Confirm) // pick up the scarecrow
	g.cursor_x, g.cursor_y = 0, 0
	command(&g, .Dismiss)
	testing.expect_value(t, g.carrying, Cell_Kind.Empty)
	testing.expect_value(t, cell_at(&g, 5, 5).kind, Cell_Kind.Empty)
	testing.expect_value(t, cell_at(&g, 0, 0).kind, Cell_Kind.Empty)
}

@(test)
saving_while_carrying :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	own_all(&g)
	g.money = 1000
	hire(&g, 2, 2)
	g.cursor_x, g.cursor_y = 2, 2
	act(&g)
	buf: [SAVE_SIZE]u8
	testing.expect_value(t, write_save(&g, buf[:]), SAVE_SIZE)
	back: Game
	testing.expect(t, read_save(&back, buf[:]))
	testing.expect_value(t, back.carrying, Cell_Kind.Farmer)
	testing.expect_value(t, back.carry_x, 2)
	// a save whose carry origin is taken is refused
	g.field[2 * FIELD_W + 2] = {owned = true, kind = .Scarecrow}
	write_save(&g, buf[:])
	testing.expect(t, !read_save(&back, buf[:]))
}

// --- Scarecrows weather and fall apart (November 26, 2026).

@(test)
scarecrows_last_about_their_health_in_turns :: proc(t: ^testing.T) {
	g: Game
	init_game(&g, 2468)
	own_all(&g)
	total, shortest, longest := 0, 1000, 0
	RUNS :: 300
	for _ in 0 ..< RUNS {
		g.field[0] = {owned = true, kind = .Scarecrow, health = SCARECROW_HEALTH}
		turns := 0
		for g.field[0].kind == .Scarecrow {
			end_turn(&g)
			turns += 1
		}
		total += turns
		shortest = min(shortest, turns)
		longest = max(longest, turns)
	}
	expected := SCARECROW_HEALTH * 2 / SCARECROW_WEAR_MAX // wear averages SCARECROW_WEAR_MAX / 2 a turn
	average := total / RUNS
	testing.expectf(t, abs(average - expected) <= 2, "average %d turns, expected about %d", average, expected)
	testing.expect(t, shortest < longest)
}

@(test)
a_scarecrow_falls_apart :: proc(t: ^testing.T) {
	g: Game
	init_game(&g, 1)
	own_all(&g)
	g.money = 100
	testing.expect(t, place_scarecrow(&g, 3, 3))
	testing.expect_value(t, int(cell_at(&g, 3, 3).health), SCARECROW_HEALTH)
	// carrying keeps its health
	cell_at(&g, 3, 3).health = 5
	g.cursor_x, g.cursor_y = 3, 3
	act(&g)
	g.cursor_x, g.cursor_y = 4, 4
	act(&g)
	testing.expect_value(t, int(cell_at(&g, 4, 4).health), 5)
	cell_at(&g, 4, 4).health = 1
	for _ in 0 ..< 100 {
		g.events = {}
		end_turn(&g)
		if cell_at(&g, 4, 4).kind != .Scarecrow {
			break
		}
	}
	testing.expect_value(t, cell_at(&g, 4, 4)^, Cell{owned = true})
	testing.expect(t, .Fell in g.events)
	testing.expect_value(t, sound_for(g.events - {.Turned}), Sfx.Fall)
}

@(test)
a_scarecrow_guards_on_the_turn_it_falls :: proc(t: ^testing.T) {
	// The crows roll before the weather: crops inside the 5x5 are safe on the scarecrow's last turn.
	for seed in 1 ..= 200 {
		g: Game
		init_game(&g, u64(seed))
		own_all(&g)
		for &c in g.field {
			c = {owned = true, kind = .Crop, crop = .Pumpkin}
		}
		cell_at(&g, 3, 3)^ = {owned = true, kind = .Scarecrow, health = 1}
		end_turn(&g)
		for y in 1 ..= 5 {
			for x in 1 ..= 5 {
				if x == 3 && y == 3 {
					continue
				}
				testing.expectf(t, cell_at(&g, x, y).kind == .Crop, "seed %d: crop at %d,%d eaten", seed, x, y)
			}
		}
	}
}

@(test)
a_save_with_a_broken_scarecrow_is_refused :: proc(t: ^testing.T) {
	g: Game
	init_game(&g)
	g.field[27] = {owned = true, kind = .Scarecrow, health = 0}
	buf: [SAVE_SIZE]u8
	write_save(&g, buf[:])
	back: Game
	testing.expect(t, !read_save(&back, buf[:]))
	g.field[27].health = SCARECROW_HEALTH + 1
	write_save(&g, buf[:])
	testing.expect(t, !read_save(&back, buf[:]))
	g.field[27].health = SCARECROW_HEALTH
	write_save(&g, buf[:])
	testing.expect(t, read_save(&back, buf[:]))
}
