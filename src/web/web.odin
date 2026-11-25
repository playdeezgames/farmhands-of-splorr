#+build js
package main

// Thin browser layer. odin.js drives `step` from its own requestAnimationFrame loop; the page copies
// the frame when platform_frame_ready says it changed, and forwards input as small integers.

import "base:runtime"
import "tggd:game"

state: struct {
	rules:  game.Game,
	screen: game.Frame,
	dirty:  bool,
	ready:  bool,
	sfx:    game.Sfx,
}

main :: proc() {
}

@(export)
platform_start :: proc "c" () {
	context = runtime.default_context()
	game.init_game(&state.rules)
	state.dirty = true
}

save_buf: [game.SAVE_SIZE]u8

@(export)
platform_save_ptr :: proc "c" () -> rawptr {
	return &save_buf
}

@(export)
platform_save_size :: proc "c" () -> i32 {
	return i32(game.SAVE_SIZE)
}

@(export)
platform_save :: proc "c" () -> i32 {
	context = runtime.default_context()
	return i32(game.write_save(&state.rules, save_buf[:]))
}

@(export)
platform_load :: proc "c" (n: i32) -> i32 {
	context = runtime.default_context()
	if n < 0 || int(n) > len(save_buf) || !game.read_save(&state.rules, save_buf[:n]) {
		return 0
	}
	state.dirty = true
	return 1
}

@(export)
step :: proc(dt: f64, c: runtime.Context) -> bool {
	context = c
	if state.dirty {
		state.dirty = false
		game.draw_game(&state.screen, &state.rules)
		game.resolve(&state.screen)
		state.ready = true
	}
	return true
}

// A game.Command from a key or a gamepad button.
@(export)
platform_command :: proc "c" (command: i32) {
	context = runtime.default_context()
	if command < 0 || command > i32(max(game.Command)) {
		return
	}
	game.command(&state.rules, game.Command(command))
	state.sfx = game.sound_for(state.rules.events)
	state.dirty = true
}

// A click or tap at framebuffer pixel (x, y).
@(export)
platform_pointer :: proc "c" (x, y: i32) {
	context = runtime.default_context()
	game.pointer(&state.rules, int(x), int(y))
	state.sfx = game.sound_for(state.rules.events)
	state.dirty = true
}

@(export)
platform_frame_ready :: proc "c" () -> i32 {
	if !state.ready {
		return 0
	}
	state.ready = false
	return 1
}

@(export)
platform_frame_ptr :: proc "c" () -> rawptr {
	return &state.screen.rgba
}

@(export)
platform_screen_w :: proc "c" () -> i32 {
	return game.SCREEN_W
}

@(export)
platform_screen_h :: proc "c" () -> i32 {
	return game.SCREEN_H
}

// The sound to play since the last call (a game.Sfx, 0 for none), and forgets it.
@(export)
platform_sfx :: proc "c" () -> i32 {
	s := state.sfx
	state.sfx = .None
	return i32(s)
}
