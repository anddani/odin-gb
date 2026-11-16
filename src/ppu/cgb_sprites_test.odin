#+build !js
package ppu

import "core:testing"

@(private = "file")
set_cram :: proc(cram: []u8, palette, color_idx: int, c: u16) {
	base := palette * 8 + color_idx * 2
	cram[base] = u8(c & 0xFF)
	cram[base + 1] = u8(c >> 8)
}

// CGB sprite, 8x8, tile 0 -> color index 1 across the row (in bank 0).
@(private = "file")
setup :: proc(banks: ^[2]VRam, oam: ^[0xA0]u8) -> Ppu {
	p: Ppu
	p.cgb = true
	p.vram = banks
	p.oam = oam
	banks[0][0] = 0xFF // tile 0 row 0 -> color index 1
	banks[0][1] = 0x00
	return p
}

// CGB sprites resolve through obj_cram using the OAM palette number (attr bits 0-2).
@(test)
test_cgb_sprite_uses_obj_palette :: proc(t: ^testing.T) {
	banks: [2]VRam
	oam: [0xA0]u8
	p := setup(&banks, &oam)
	oam[0] = 16;oam[1] = 8;oam[2] = 0;oam[3] = 0x03 // Y16/X8/tile0/palette 3
	set_cram(p.obj_cram[:], 3, 1, 0x001F) // OBJ palette 3, color 1 = red

	render_sprites(&p, 0)

	for i in 0 ..< 8 {
		testing.expect_value(t, p.framebuffer[0][i], Color{255, 0, 0})
	}
}

// Attribute bit 3 selects the VRAM bank for the sprite's TILE DATA.
@(test)
test_cgb_sprite_tile_data_bank :: proc(t: ^testing.T) {
	banks: [2]VRam
	oam: [0xA0]u8
	p := setup(&banks, &oam)
	banks[0][0] = 0x00;banks[0][1] = 0x00 // bank 0 tile 0 -> transparent
	banks[1][0] = 0xFF;banks[1][1] = 0x00 // bank 1 tile 0 -> color index 1
	oam[0] = 16;oam[1] = 8;oam[2] = 0;oam[3] = 0x08 // data bank 1, palette 0
	set_cram(p.obj_cram[:], 0, 1, 0x03E0) // green

	render_sprites(&p, 0)

	testing.expect_value(t, p.framebuffer[0][0], Color{0, 255, 0})
}

// CGB priority is by OAM index, NOT by X. Lower index wins overlap even at higher X.
@(test)
test_cgb_sprite_oam_order_priority :: proc(t: ^testing.T) {
	banks: [2]VRam
	oam: [0xA0]u8
	p := setup(&banks, &oam)
	// A: OAM index 0, X=10 (screen x 2), palette 1 (red)
	oam[0] = 16;oam[1] = 10;oam[2] = 0;oam[3] = 0x01
	// B: OAM index 1, X=8 (screen x 0), palette 2 (green)
	oam[4] = 16;oam[5] = 8;oam[6] = 0;oam[7] = 0x02
	set_cram(p.obj_cram[:], 1, 1, 0x001F) // red
	set_cram(p.obj_cram[:], 2, 1, 0x03E0) // green

	render_sprites(&p, 0)

	// x0 covered only by B -> green. x2 is the overlap: A (lower index) wins -> red.
	// On DMG this would be green at x2 (lower X wins); OAM order makes it red.
	testing.expect_value(t, p.framebuffer[0][0], Color{0, 255, 0})
	testing.expect_value(t, p.framebuffer[0][2], Color{255, 0, 0})
}

// Priority: BG tile priority bit hides the sprite (master prio on, BG non-zero).
@(test)
test_cgb_sprite_hidden_by_bg_tile_priority :: proc(t: ^testing.T) {
	banks: [2]VRam
	oam: [0xA0]u8
	p := setup(&banks, &oam)
	oam[0] = 16;oam[1] = 8;oam[2] = 0;oam[3] = 0x00 // no OAM priority
	set_cram(p.obj_cram[:], 0, 1, 0x03E0)
	p.lcdc = 0x01 // master priority ON
	p.bg_idx[0] = 2 // BG non-zero
	p.bg_prio[0] = true // BG tile requested priority
	sentinel := Color{1, 2, 3}
	p.framebuffer[0][0] = sentinel

	render_sprites(&p, 0)

	testing.expect_value(t, p.framebuffer[0][0], sentinel) // sprite hidden behind BG
}

// Priority: OAM priority bit hides the sprite (master prio on, BG non-zero).
@(test)
test_cgb_sprite_hidden_by_oam_priority :: proc(t: ^testing.T) {
	banks: [2]VRam
	oam: [0xA0]u8
	p := setup(&banks, &oam)
	oam[0] = 16;oam[1] = 8;oam[2] = 0;oam[3] = 0x80 // OAM priority bit
	set_cram(p.obj_cram[:], 0, 1, 0x03E0)
	p.lcdc = 0x01
	p.bg_idx[0] = 2
	p.bg_prio[0] = false // BG tile did not request priority
	sentinel := Color{1, 2, 3}
	p.framebuffer[0][0] = sentinel

	render_sprites(&p, 0)

	testing.expect_value(t, p.framebuffer[0][0], sentinel) // sprite hidden
}

// Priority: LCDC.0 clear (master priority off) -> sprite always on top.
@(test)
test_cgb_sprite_master_priority_off :: proc(t: ^testing.T) {
	banks: [2]VRam
	oam: [0xA0]u8
	p := setup(&banks, &oam)
	oam[0] = 16;oam[1] = 8;oam[2] = 0;oam[3] = 0x80 // OAM priority bit set
	set_cram(p.obj_cram[:], 0, 1, 0x03E0)
	p.lcdc = 0x00 // master priority OFF
	p.bg_idx[0] = 2
	p.bg_prio[0] = true // both priority bits set, but master off overrides
	p.framebuffer[0][0] = Color{1, 2, 3}

	render_sprites(&p, 0)

	testing.expect_value(t, p.framebuffer[0][0], Color{0, 255, 0}) // sprite wins
}

// Priority: BG color index 0 never hides the sprite, even with priority bits set.
@(test)
test_cgb_sprite_over_bg_color0 :: proc(t: ^testing.T) {
	banks: [2]VRam
	oam: [0xA0]u8
	p := setup(&banks, &oam)
	oam[0] = 16;oam[1] = 8;oam[2] = 0;oam[3] = 0x80
	set_cram(p.obj_cram[:], 0, 1, 0x03E0)
	p.lcdc = 0x01 // master priority ON
	p.bg_idx[0] = 0 // BG color 0 -> always behind
	p.bg_prio[0] = true
	p.framebuffer[0][0] = Color{1, 2, 3}

	render_sprites(&p, 0)

	testing.expect_value(t, p.framebuffer[0][0], Color{0, 255, 0}) // sprite wins
}
