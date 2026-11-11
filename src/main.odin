package main

import "core:fmt"
import "core:os"
import rl "vendor:raylib"

import "cart"
import "gameboy"

WIDTH :: 160
HEIGHT :: 144
SCALE :: 4
FPS :: 60
SHADES := [4]rl.Color {
	{0xFF, 0xFF, 0xFF, 0xFF},
	{0xAA, 0xAA, 0xAA, 0xFF},
	{0x55, 0x55, 0x55, 0xFF},
	{0x00, 0x00, 0x00, 0xFF},
}

Framebuffer :: [HEIGHT][WIDTH]rl.Color

make_image :: proc(fb: ^Framebuffer) -> rl.Image {
	return rl.Image {
		data = fb,
		width = WIDTH,
		height = HEIGHT,
		mipmaps = 1,
		format = .UNCOMPRESSED_R8G8B8A8,
	}
}


main :: proc() {
	if len(os.args) < 2 {
		fmt.println("Provide path to rom")
		os.exit(1)
	}

	rom_path := os.args[1]


	gb := new(gameboy.Gameboy)
	if err := gameboy.gb_init(gb, os.args[1]); err != .None {
		fmt.eprintln("Reading cartridge failed:", err)
		os.exit(1)
	}

	fmt.println("Cart rom len:", len(gb.cart.rom))

	rl.InitWindow(WIDTH * SCALE, HEIGHT * SCALE, "odin-gb")
	rl.SetTargetFPS(FPS)

	fb: Framebuffer
	img := make_image(&fb)
	texture := rl.LoadTextureFromImage(img)

	for !rl.WindowShouldClose() {
		dirs: u8 = 0
		if rl.IsKeyDown(.DOWN) {dirs |= 0b1000}
		if rl.IsKeyDown(.UP) {dirs |= 0b0100}
		if rl.IsKeyDown(.LEFT) {dirs |= 0b0010}
		if rl.IsKeyDown(.RIGHT) {dirs |= 0b0001}
		gb.joypad.dirs = dirs

		btns: u8 = 0
		if rl.IsKeyDown(.ENTER) {btns |= 0b1000}
		if rl.IsKeyDown(.RIGHT_SHIFT) {btns |= 0b0100}
		if rl.IsKeyDown(.Z) {btns |= 0b0010}
		if rl.IsKeyDown(.X) {btns |= 0b0001}
		gb.joypad.btns = btns


		gameboy.gb_run_frame(gb)

		for y in 0 ..< HEIGHT {
			for x in 0 ..< WIDTH {
				fb[y][x] = SHADES[gb.ppu.framebuffer[y][x]]
			}
		}
		rl.UpdateTexture(texture, &fb)


		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		rl.DrawTextureEx(texture, {0, 0}, 0, SCALE, rl.WHITE)
		rl.EndDrawing()
	}
	cart.cart_save_ram(&gb.cart)

	rl.UnloadTexture(texture)
	rl.CloseWindow()
}
