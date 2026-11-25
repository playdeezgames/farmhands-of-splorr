#+build !js
package game

import "core:os"
import "core:testing"

// Writes a frame of a farm in progress as a PPM, for screenshots and the cover:
// odin test src/game -collection:tggd=src -define:DUMP_PLAY=/path/frame.ppm
DUMP_PLAY :: #config(DUMP_PLAY, "")

@(private = "file")
write_file :: os.write_entire_file

@(test)
dump_play :: proc(t: ^testing.T) {
	when DUMP_PLAY != "" {
		g := new(Game)
		defer free(g)
		init_game(g)
		g.money = 400
		for y in 1 ..< 7 {
			for x in 1 ..< 7 {
				cell_at(g, x, y).owned = true
			}
		}
		for x in 2 ..< 6 {
			cell_at(g, x, 0).owned = true
		}
		g.land_bought = 36
		g.barn[.Carrot] = 30
		hire(g, 2, 2)
		hire(g, 5, 5)
		crops := [?]Crop{.Carrot, .Wheat, .Cabbage, .Corn, .Pumpkin}
		i := 0
		for y in 0 ..< FIELD_H {
			for x in 0 ..< FIELD_W {
				if cell_at(g, x, y).owned && cell_at(g, x, y).kind == .Empty && (x + y) % 5 != 0 {
					plant(g, x, y, crops[i % len(crops)])
					i += 1
				}
			}
			if y == 3 {
				end_turn(g)
				end_turn(g)
			}
		}
		end_turn(g)
		end_turn(g)
		for y in 0 ..< FIELD_H {
			for x in 0 ..< FIELD_W {
				if ripe(cell_at(g, x, y)^) && x < 2 {
					harvest(g, x, y)
				}
			}
		}
		make_seeds(g, .Carrot)
		sell(g, .Wheat, 9)
		g.cursor_x, g.cursor_y = 7, 3
		g.tool = .Corn
		f := new(Frame)
		defer free(f)
		draw_game(f, g)
		resolve(f)
		out := make([dynamic]u8, context.temp_allocator)
		header := "P6\n480 270\n255\n"
		append(&out, ..transmute([]u8)header)
		for p in f.rgba {
			append(&out, u8(p), u8(p >> 8), u8(p >> 16))
		}
		testing.expect(t, write_file(DUMP_PLAY, out[:]) == nil)
	}
}
