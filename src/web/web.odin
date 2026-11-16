// Wasm entry point
package main

import "base:runtime"

import "../apu"
import "../cart"
import "../gameboy"
import "../ppu"

gb: gameboy.Gameboy
loaded: bool

rom_staging: []byte
rgba: [ppu.HEIGHT][ppu.WIDTH][4]u8
audio_out: [apu.SAMPLE_BUF_SIZE]i16

main :: proc() {}

@(export)
web_rom_alloc :: proc "c" (size: i32) -> rawptr {
	context = runtime.default_context()
	delete(rom_staging)
	rom_staging = make([]byte, int(size))
	return raw_data(rom_staging)
}

@(export)
web_load_rom :: proc "c" () -> i32 {
	context = runtime.default_context()
	if loaded {
		cart.cart_destroy(&gb.cart)
	}
	gb = {}
	err := gameboy.gb_init_from_bytes(&gb, rom_staging)
	delete(rom_staging)
	rom_staging = nil
	loaded = err == .None
	return i32(err)
}

@(export)
web_set_input :: proc "c" (dirs: u8, btns: u8) {
	gb.joypad.dirs = dirs
	gb.joypad.btns = btns
}

@(export)
web_run_frame :: proc "c" () {
	context = runtime.default_context()
	if !loaded {
		return
	}
	gameboy.gb_run_frame(&gb)

	for y in 0 ..< ppu.HEIGHT {
		for x in 0 ..< ppu.WIDTH {
			c := gb.ppu.framebuffer[y][x]
			rgba[y][x] = {c.r, c.g, c.b, 0xFF}
		}
	}
}

@(export)
web_framebuffer :: proc "c" () -> rawptr {
	return &rgba
}

// Drains pending APU samples into audio_out, returns the number of i16 values.
@(export)
web_audio_drain :: proc "c" () -> i32 {
	context = runtime.default_context()
	return i32(apu.apu_drain(&gb.apu, audio_out[:]))
}

@(export)
web_audio_buffer :: proc "c" () -> rawptr {
	return &audio_out
}

// Battery-backed cart RAM, so JS can persist saves in localStorage.
// Length is 0 when the cart has nothing worth saving.
@(export)
web_save_ram :: proc "c" () -> rawptr {
	return raw_data(gb.cart.ram)
}

@(export)
web_save_ram_len :: proc "c" () -> i32 {
	if !loaded || !gb.cart.battery {
		return 0
	}
	return i32(len(gb.cart.ram))
}
