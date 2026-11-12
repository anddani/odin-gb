package gameboy

import "core:image"
import "core:image/png"
import "core:testing"

import "../cart"

// dmg-acid2 is the canonical DMG PPU acceptance test. We render it and assert a
// PIXEL-EXACT match against the official reference image -- so any PPU change
// that breaks BG / window / sprites / priority is caught immediately.
@(test)
test_dmg_acid2_pixel_perfect :: proc(t: ^testing.T) {
	gb := new(Gameboy)
	defer free(gb)
	if gb_init(gb, "assets/dmg-acid2.gb") != .None {
		testing.expect(t, false, "could not load dmg-acid2.gb")
		return
	}
	defer cart.cart_destroy(&gb.cart)

	for i in 0 ..< 120 {gb_run_frame(gb)} // let the test settle

	img, err := png.load_from_file("assets/dmg-acid2-reference.png")
	if err != nil {
		testing.expectf(t, false, "load reference png: %v", err)
		return
	}
	defer image.destroy(img)
	px := img.pixels.buf[:]

	diffs := 0
	for y in 0 ..< 144 {
		for x in 0 ..< 160 {
			ref := u8(3 - int(px[(y * 160 + x) * img.channels]) / 85)
			if gb.ppu.framebuffer[y][x] != ref {diffs += 1}
		}
	}
	testing.expectf(t, diffs == 0, "dmg-acid2 differs from reference in %d pixels", diffs)
}
