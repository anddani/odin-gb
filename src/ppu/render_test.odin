package ppu

import "core:testing"

// A tile row is two bytes: `lo` holds the low bit-plane, `hi` the high plane.
// lo=0x55 (01010101), hi=0x33 (00110011) -> per-pixel color index 0,1,2,3,0,1,2,3.

@(test)
test_render_bg_tile_row :: proc(t: ^testing.T) {
	vram: VRam
	p: Ppu
	p.vram = &vram
	p.lcdc = 0x11 // BG enable (bit0) + tile data 0x8000 (bit4)
	p.bgp = 0xE4 // identity: idx n -> shade n
	vram[0] = 0x55 // tile 0, row 0, low plane
	vram[1] = 0x33 // tile 0, row 0, high plane
	vram[0x1800] = 0 // tile map 0x9800[0] = tile 0

	render_scanline(&p, 0)

	expected := [8]u8{0, 1, 2, 3, 0, 1, 2, 3}
	for i in 0 ..< 8 {
		testing.expect_value(t, p.framebuffer[0][i], expected[i])
	}
}

// BGP remaps color indices to shades.
@(test)
test_render_bg_through_bgp :: proc(t: ^testing.T) {
	vram: VRam
	p: Ppu
	p.vram = &vram
	p.lcdc = 0x11
	p.bgp = 0x1B // idx 0->3, 1->2, 2->1, 3->0
	vram[0] = 0x55
	vram[1] = 0x33
	vram[0x1800] = 0

	render_scanline(&p, 0)

	testing.expect_value(t, p.framebuffer[0][0], u8(3)) // idx 0
	testing.expect_value(t, p.framebuffer[0][1], u8(2)) // idx 1
	testing.expect_value(t, p.framebuffer[0][2], u8(1)) // idx 2
	testing.expect_value(t, p.framebuffer[0][3], u8(0)) // idx 3
}

// ly=1 must read tile row 1 (byte offset 2/3), proving the *2 row stride.
@(test)
test_render_bg_correct_tile_row :: proc(t: ^testing.T) {
	vram: VRam
	p: Ppu
	p.vram = &vram
	p.lcdc = 0x11
	p.bgp = 0xE4
	vram[0x1800] = 0 // tile 0
	vram[2] = 0xFF // row 1 low plane (all low bits set)
	vram[3] = 0x00 // row 1 high plane -> color index 1 everywhere

	render_scanline(&p, 1) // ly=1 -> rowInTile 1

	for i in 0 ..< 8 {
		testing.expect_value(t, p.framebuffer[1][i], u8(1))
	}
}

@(test)
test_render_bg_disabled_blanks_row :: proc(t: ^testing.T) {
	vram: VRam
	p: Ppu
	p.vram = &vram
	p.lcdc = 0x00 // BG disabled

	render_scanline(&p, 5)

	for i in 0 ..< WIDTH {
		testing.expect_value(t, p.framebuffer[5][i], u8(0))
	}
}

// Window covers the whole row when WX=7 (screen x 0), WY=0.
@(test)
test_window_covers_row :: proc(t: ^testing.T) {
	vram: VRam
	p: Ppu
	p.vram = &vram
	p.lcdc = 0x31 // BG + window on, tile data 0x8000, both maps 0x9800
	p.bgp = 0xE4
	p.wy = 0
	p.wx = 7 // screen x 0
	vram[0] = 0xFF // tile 0 -> color index 1
	vram[1] = 0x00
	vram[0x1800] = 0 // window map 0x9800 -> tile 0

	render_scanline(&p, 0)

	for i in 0 ..< 8 {
		testing.expect_value(t, p.framebuffer[0][i], u8(1))
	}
}

// WX offset: window starts at screen x 8; left of it is background.
@(test)
test_window_wx_boundary :: proc(t: ^testing.T) {
	vram: VRam
	p: Ppu
	p.vram = &vram
	p.lcdc = 0x71 // BG map 0x9800, window map 0x9C00 (bit 6), tile data 0x8000
	p.bgp = 0xE4
	p.wy = 0
	p.wx = 15 // screen x 8

	vram[0] = 0xFF;vram[1] = 0x00 // tile 0 -> color 1
	vram[0x10] = 0x00;vram[0x11] = 0xFF // tile 1 -> color 2
	vram[0x1800] = 1 // BG map -> tile 1 (color 2)
	vram[0x1C00] = 0 // window map -> tile 0 (color 1)

	render_scanline(&p, 0)

	testing.expect_value(t, p.framebuffer[0][0], u8(2)) // BG (left of window)
	testing.expect_value(t, p.framebuffer[0][8], u8(1)) // window
}
