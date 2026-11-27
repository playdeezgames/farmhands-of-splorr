package game

import "core:mem"

// A save is the whole Game (plain data, no pointers) behind a short header. The page keeps it in
// localStorage. A save from another build (another size or version) is refused, and so is one
// whose values are out of range.

SAVE_MAGIC :: u32(0x46484E31) // "FHN1"
SAVE_VERSION :: u32(7) // 7: ten crops, licenses, seed and sell rules, stats, tabs, tutorial (November 27, 2026); 2: land to buy; 3: barn capacity, rats and cats (November 25, 2026); 4: crows, scarecrows, carrying; 5: scarecrow health; 6: soil, half-step growth, rot (November 26, 2026)
SAVE_HEADER :: 8
SAVE_SIZE :: SAVE_HEADER + size_of(Game)

write_save :: proc(g: ^Game, out: []u8) -> int {
	if len(out) < SAVE_SIZE {
		return 0
	}
	put_u32(out[0:], SAVE_MAGIC)
	put_u32(out[4:], SAVE_VERSION)
	mem.copy(&out[SAVE_HEADER], g, size_of(Game))
	return SAVE_SIZE
}

read_save :: proc(g: ^Game, data: []u8) -> bool {
	if len(data) != SAVE_SIZE || get_u32(data[0:]) != SAVE_MAGIC || get_u32(data[4:]) != SAVE_VERSION {
		return false
	}
	scratch: Game
	mem.copy(&scratch, &data[SAVE_HEADER], size_of(Game))
	if !save_valid(&scratch) {
		return false
	}
	g^ = scratch
	g.events = {}
	return true
}

save_valid :: proc(g: ^Game) -> bool {
	if g.cursor_x < 0 || g.cursor_x >= FIELD_W || g.cursor_y < 0 || g.cursor_y >= FIELD_H {
		return false
	}
	if u8(g.tool) >= len(Tool) || g.turn < 1 || g.pantry < 0 || g.land_bought < 0 || g.barn_level < 0 || g.cats < 0 {
		return false
	}
	if u8(g.carrying) > u8(max(Cell_Kind)) || g.carrying == .Crop {
		return false
	}
	if g.carrying != .Empty {
		if g.carry_x < 0 || g.carry_x >= FIELD_W || g.carry_y < 0 || g.carry_y >= FIELD_H {
			return false
		}
		home := g.field[g.carry_y * FIELD_W + g.carry_x]
		if !home.owned || home.kind != .Empty || g.carry_cell.kind != g.carrying {
			return false
		}
		if g.carrying == .Scarecrow && (g.carry_cell.health < 1 || int(g.carry_cell.health) > SCARECROW_HEALTH) {
			return false
		}
	}
	for c in g.field {
		if u8(c.kind) > u8(max(Cell_Kind)) || u8(c.crop) > u8(max(Crop)) {
			return false
		}
		if c.kind != .Empty && !c.owned {
			return false
		}
		if c.kind == .Scarecrow && (c.health < 1 || int(c.health) > SCARECROW_HEALTH) {
			return false
		}
		if c.kind == .Crop && (int(c.progress) > 2 * CROPS[c.crop].grow || int(c.rot) >= CROPS[c.crop].keep) {
			return false
		}
	}
	for soil in g.soil {
		for v in soil {
			if int(v) > SOIL_MAX {
				return false
			}
		}
	}
	if u8(g.tool) > u8(max(Tool)) {
		return false
	}
	for crop in Crop {
		if g.barn[crop] < 0 || g.seeds[crop] < 0 {
			return false
		}
		if g.seed_target[crop] < 0 || g.seed_target[crop] > SEED_TARGET_MAX {
			return false
		}
		if g.sell_above[crop] < SELL_ABOVE_OFF || g.sell_above[crop] > SELL_ABOVE_MAX {
			return false
		}
	}
	if u8(g.panel) > u8(max(Panel)) || g.page < 0 || g.page >= page_count(g.panel) {
		return false
	}
	if g.tutorial < 0 || g.tutorial > len(TUTORIAL) {
		return false
	}
	for l in g.log {
		if int(l.len) > LOG_COLS || l.color > 15 {
			return false
		}
	}
	return true
}

put_u32 :: proc(b: []u8, v: u32) {
	b[0] = u8(v)
	b[1] = u8(v >> 8)
	b[2] = u8(v >> 16)
	b[3] = u8(v >> 24)
}

get_u32 :: proc(b: []u8) -> u32 {
	return u32(b[0]) | u32(b[1]) << 8 | u32(b[2]) << 16 | u32(b[3]) << 24
}
