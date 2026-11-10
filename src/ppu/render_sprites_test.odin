package ppu

import "core:testing"

// Helper: a PPU with sprites enabled (8x8), identity OBP0, VRAM+OAM backed.
@(private = "file")
setup :: proc(vram: ^VRam, oam: ^[0xA0]u8) -> Ppu {
	p: Ppu
	p.vram = vram
	p.oam = oam
	p.lcdc = 0x02 // sprites on, 8x8
	p.obp0 = 0xE4 // identity: idx n -> shade n
	p.obp1 = 0xE4
	return p
}

@(test)
test_sprite_basic :: proc(t: ^testing.T) {
	vram: VRam
	oam: [0xA0]u8
	p := setup(&vram, &oam)
	vram[0] = 0xFF // tile 0 row 0: all color index 1
	vram[1] = 0x00
	oam[0] = 16 // Y -> screen_y 0
	oam[1] = 8 // X -> screen_x 0
	oam[2] = 0 // tile 0
	oam[3] = 0 // attr
	render_sprites(&p, 0)
	for i in 0 ..< 8 {
		testing.expect_value(t, p.framebuffer[0][i], u8(1))
	}
}

// Color index 0 is transparent -- must not overwrite the background.
@(test)
test_sprite_transparency :: proc(t: ^testing.T) {
	vram: VRam
	oam: [0xA0]u8
	p := setup(&vram, &oam)
	p.framebuffer[0][0] = 3 // pretend BG drew shade 3 here
	vram[0] = 0x00 // tile all color index 0 (transparent)
	vram[1] = 0x00
	oam[0] = 16;oam[1] = 8;oam[2] = 0;oam[3] = 0
	render_sprites(&p, 0)
	testing.expect_value(t, p.framebuffer[0][0], u8(3)) // untouched
}

@(test)
test_sprite_x_flip :: proc(t: ^testing.T) {
	vram: VRam
	oam: [0xA0]u8
	p := setup(&vram, &oam)
	vram[0] = 0x80 // only leftmost pixel (bit 7) is color 1
	vram[1] = 0x00
	oam[0] = 16;oam[1] = 8;oam[2] = 0;oam[3] = 0x20 // X-flip
	render_sprites(&p, 0)
	testing.expect_value(t, p.framebuffer[0][0], u8(0)) // moved away from col 0
	testing.expect_value(t, p.framebuffer[0][7], u8(1)) // now at col 7
}

// BG-over-OBJ priority: sprite hidden where BG color index != 0.
@(test)
test_sprite_bg_priority :: proc(t: ^testing.T) {
	vram: VRam
	oam: [0xA0]u8
	p := setup(&vram, &oam)
	vram[0] = 0xFF // sprite color 1 across the row
	vram[1] = 0x00
	p.bg_idx[0] = 2 // BG non-zero at col 0
	p.bg_idx[1] = 0 // BG color 0 at col 1
	oam[0] = 16;oam[1] = 8;oam[2] = 0;oam[3] = 0x80 // BG priority bit
	render_sprites(&p, 0)
	testing.expect_value(t, p.framebuffer[0][0], u8(0)) // hidden behind BG
	testing.expect_value(t, p.framebuffer[0][1], u8(1)) // shows over BG color 0
}

// OBP1 selected by attribute bit 4.
@(test)
test_sprite_uses_obp1 :: proc(t: ^testing.T) {
	vram: VRam
	oam: [0xA0]u8
	p := setup(&vram, &oam)
	p.obp1 = 0x1B // idx 1 -> shade 2
	vram[0] = 0xFF // color index 1
	vram[1] = 0x00
	oam[0] = 16;oam[1] = 8;oam[2] = 0;oam[3] = 0x10 // OBP1
	render_sprites(&p, 0)
	testing.expect_value(t, p.framebuffer[0][0], u8(2)) // via OBP1
}
