#+build !js
package game

import "core:os"
import "core:testing"

// Writes a frame of the game as a PPM, for screenshots and the cover:
// odin test src/game -collection:tggd=src -define:DUMP_PLAY=/path/frame.ppm [-define:DUMP_SCENE=n]
// Scenes: 2 (the default, also the cover) a farm in progress; 1 a new farm a couple of turns in;
// 3 the farm in progress on a bad turn: rats in the barn, crows in the field, a cat gone.
DUMP_PLAY :: #config(DUMP_PLAY, "")
DUMP_SCENE :: #config(DUMP_SCENE, 2)

@(private = "file")
write_file :: os.write_entire_file

@(test)
dump_play :: proc(t: ^testing.T) {
	when DUMP_PLAY != "" {
		g := new(Game)
		defer free(g)
		init_game(g)
		when DUMP_SCENE == 1 {
			plant(g, 3, 3, .Carrot)
			plant(g, 4, 3, .Wheat)
			plant(g, 4, 4, .Carrot)
			hire(g, 3, 4)
			end_turn(g)
			end_turn(g)
			g.cursor_x, g.cursor_y = 5, 3
			g.tool = .Carrot
		} else {
			dump_farm(g)
		}
		when DUMP_SCENE == 3 {
			g.barn[.Wheat] += 6
			g.barn[.Cabbage] += 4
			ate := rats_feast(g)
			line: Text
			add(&line, "Rats got into the barn and ate ")
			add_int(&line, ate)
			add(&line, " crops!")
			say(g, text_of(&line), COLOR_RED)
			say(g, "Crows ate a Corn!", COLOR_RED)
			say(g, "1 cat wandered off.", COLOR_ORANGE)
		}
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

// A farm some way along: about a third of the field bought and planted, two farmhands, a scarecrow,
// a bigger barn, two cats.
dump_farm :: proc(g: ^Game) {
	g.money = 240
	for y in 1 ..< 6 {
		for x in 2 ..< 6 {
			cell_at(g, x, y).owned = true
		}
	}
	cell_at(g, 1, 3).owned = true
	cell_at(g, 6, 3).owned = true
	g.land_bought = 18
	g.barn_level = 2
	g.cats = 2
	g.barn[.Carrot] = 20
	hire(g, 3, 2)
	hire(g, 4, 4)
	place_scarecrow(g, 2, 3)
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
	sell(g, .Carrot, 6)
	g.cursor_x, g.cursor_y = 6, 2
	g.tool = .Corn
}
