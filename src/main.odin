package main

import "core:fmt"
import "core:os"
import rl "vendor:raylib"

import "cart"

WIDTH :: 160
HEIGHT :: 144
SCALE :: 4
FPS :: 60

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

	c, err := cart.cart_from_file(rom_path)

	if err != cart.Cart_Error.None {
		fmt.printf("Error reading cart from path %s: %s\n", rom_path, err)
		os.exit(1)
	}

	fmt.println("Cart rom len:", len(c.rom))
	defer cart.cart_destroy(&c)


	rl.InitWindow(WIDTH * SCALE, HEIGHT * SCALE, "GameBoy Emulator")
	rl.SetTargetFPS(FPS)

	fb: Framebuffer

	for y in 0 ..< HEIGHT {
		for x in 0 ..< WIDTH {
			fb[y][x] = {u8(x), u8(y), 0, 0xff}
		}
	}

	img := make_image(&fb)
	texture := rl.LoadTextureFromImage(img)
	rl.UpdateTexture(texture, &fb)

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		rl.DrawTextureEx(texture, {0, 0}, 0, SCALE, rl.WHITE)

		rl.EndDrawing()
	}

	rl.UnloadTexture(texture)
	rl.CloseWindow()
}
