#+build !js
package ppu

import "core:testing"

// Pack an RGB555 color (little-endian) into a palette slot of a CRAM array.
@(private = "file")
set_cram :: proc(cram: []u8, palette, color_idx: int, c: u16) {
	base := palette * 8 + color_idx * 2
	cram[base] = u8(c & 0xFF)
	cram[base + 1] = u8(c >> 8)
}

// CGB BG: the color index is resolved through the tile attribute's palette number.
@(test)
test_cgb_bg_uses_palette :: proc(t: ^testing.T) {
	banks: [2]VRam
	p: Ppu
	p.cgb = true
	p.vram = &banks
	p.lcdc = 0x11 // BG enable + tile data 0x8000
	banks[0][0] = 0xFF // tile 0 row 0 -> color index 1 across the row
	banks[0][1] = 0x00
	banks[0][0x1800] = 0 // map 0x9800[0] -> tile 0
	banks[1][0x1800] = 2 // attribute: BG palette 2
	set_cram(p.bg_cram[:], 2, 1, 0x001F) // palette 2, color 1 = red

	render_scanline(&p, 0)

	for i in 0 ..< 8 {
		testing.expect_value(t, p.framebuffer[0][i], Color{255, 0, 0})
	}
}

// Attribute bit 3 selects the VRAM bank the TILE DATA is read from.
@(test)
test_cgb_bg_tile_data_bank :: proc(t: ^testing.T) {
	banks: [2]VRam
	p: Ppu
	p.cgb = true
	p.vram = &banks
	p.lcdc = 0x11
	banks[0][0] = 0x00 // bank 0 tile 0 -> color index 0 (would be wrong)
	banks[0][1] = 0x00
	banks[1][0] = 0xFF // bank 1 tile 0 -> color index 1 (the correct source)
	banks[1][1] = 0x00
	banks[0][0x1800] = 0 // tile index 0 (always from bank 0)
	banks[1][0x1800] = 0x08 // attribute: data bank 1, palette 0
	set_cram(p.bg_cram[:], 0, 1, 0x03E0) // palette 0, color 1 = green

	render_scanline(&p, 0)

	testing.expect_value(t, p.framebuffer[0][0], Color{0, 255, 0}) // read bank-1 data
}

// Attribute bit 5 flips the tile horizontally.
@(test)
test_cgb_bg_x_flip :: proc(t: ^testing.T) {
	banks: [2]VRam
	p: Ppu
	p.cgb = true
	p.vram = &banks
	p.lcdc = 0x11
	banks[0][0] = 0x80 // only leftmost pixel (bit 7) is color index 1
	banks[0][1] = 0x00
	banks[0][0x1800] = 0
	banks[1][0x1800] = 0x20 // attribute: X flip, palette 0
	set_cram(p.bg_cram[:], 0, 0, 0x7C00) // color 0 = blue
	set_cram(p.bg_cram[:], 0, 1, 0x03E0) // color 1 = green

	render_scanline(&p, 0)

	testing.expect_value(t, p.framebuffer[0][0], Color{0, 0, 255}) // col 0 now color 0 (blue)
	testing.expect_value(t, p.framebuffer[0][7], Color{0, 255, 0}) // flipped to col 7 (green)
}

// Attribute bit 6 flips the tile vertically: ly=0 reads tile row 7.
@(test)
test_cgb_bg_y_flip :: proc(t: ^testing.T) {
	banks: [2]VRam
	p: Ppu
	p.cgb = true
	p.vram = &banks
	p.lcdc = 0x11
	banks[0][14] = 0xFF // tile row 7 (byte 14/15) -> color index 1
	banks[0][15] = 0x00
	banks[0][0] = 0x00 // tile row 0 -> color index 0
	banks[0][1] = 0x00
	banks[0][0x1800] = 0
	banks[1][0x1800] = 0x40 // attribute: Y flip, palette 0
	set_cram(p.bg_cram[:], 0, 1, 0x03E0) // color 1 = green

	render_scanline(&p, 0) // ly=0, Y-flipped -> reads row 7

	testing.expect_value(t, p.framebuffer[0][0], Color{0, 255, 0})
}
