package main

import rl "vendor:raylib"

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
