package ppu

import "core:testing"

// --- CRAM register behavior (driven through the MMU-facing ppu_read/ppu_write) ---

// With auto-increment off (bit7 clear), every BGPD write hits the same index.
@(test)
test_bgpd_write_no_autoinc :: proc(t: ^testing.T) {
	p: Ppu
	ppu_write(&p, 0xFF68, 0x05) // index 5, auto-inc OFF
	ppu_write(&p, 0xFF69, 0xAA)
	ppu_write(&p, 0xFF69, 0xBB)
	testing.expect_value(t, p.bg_cram[5], u8(0xBB)) // second write overwrote the first
	testing.expect_value(t, p.bg_cram[6], u8(0x00)) // index did not advance
	testing.expect_value(t, ppu_read(&p, 0xFF68), u8(0x45)) // 0x05 | 0x40 (bit6 reads 1)
}

// With auto-increment on (bit7 set), successive BGPD writes fill consecutive bytes.
@(test)
test_bgpd_write_autoinc :: proc(t: ^testing.T) {
	p: Ppu
	ppu_write(&p, 0xFF68, 0x80) // index 0, auto-inc ON
	for i in 0 ..< 10 {
		ppu_write(&p, 0xFF69, u8(i + 1))
	}
	for i in 0 ..< 10 {
		testing.expect_value(t, p.bg_cram[i], u8(i + 1))
	}
	testing.expect_value(t, ppu_read(&p, 0xFF68), u8(0x80 | 0x40 | 10)) // index 10, bit6 reads 1
}

// Index wraps 0x3F -> 0x00 and keeps the auto-increment bit.
@(test)
test_bgpd_autoinc_wrap :: proc(t: ^testing.T) {
	p: Ppu
	ppu_write(&p, 0xFF68, 0x80 | 0x3F) // index 63, auto-inc ON
	ppu_write(&p, 0xFF69, 0x11)
	testing.expect_value(t, p.bg_cram[63], u8(0x11))
	testing.expect_value(t, ppu_read(&p, 0xFF68), u8(0x80 | 0x40)) // wrapped to index 0, bit7 kept, bit6 reads 1
}

// Reading BGPD must NOT auto-increment the index.
@(test)
test_bgpd_read_no_autoinc :: proc(t: ^testing.T) {
	p: Ppu
	p.bg_cram[3] = 0xCD
	ppu_write(&p, 0xFF68, 0x80 | 0x03) // index 3, auto-inc ON (must be ignored on read)
	testing.expect_value(t, ppu_read(&p, 0xFF69), u8(0xCD))
	testing.expect_value(t, ppu_read(&p, 0xFF69), u8(0xCD)) // still index 3
	testing.expect_value(t, ppu_read(&p, 0xFF68), u8(0x80 | 0x40 | 0x03)) // index unchanged, bit6 reads 1
}

// OBPI/OBPD mirror the BG pair (own index + own CRAM).
@(test)
test_obpd_write_autoinc :: proc(t: ^testing.T) {
	p: Ppu
	ppu_write(&p, 0xFF6A, 0x80) // OBPI index 0, auto-inc ON
	ppu_write(&p, 0xFF6B, 0x12)
	ppu_write(&p, 0xFF6B, 0x34)
	testing.expect_value(t, p.obj_cram[0], u8(0x12))
	testing.expect_value(t, p.obj_cram[1], u8(0x34))
	testing.expect_value(t, ppu_read(&p, 0xFF6A), u8(0x80 | 0x40 | 2)) // bit6 reads 1
	testing.expect_value(t, p.bg_cram[0], u8(0x00)) // BG CRAM untouched
}

// --- RGB555 -> RGB888 decode ---

// Pack a 5-bit RGB555 color little-endian into two CRAM bytes.
@(private = "file")
put_color :: proc(cram: []u8, palette, color_idx: int, c: u16) {
	base := palette * 8 + color_idx * 2
	cram[base] = u8(c & 0xFF)
	cram[base + 1] = u8(c >> 8)
}

@(test)
test_cram_color_decode :: proc(t: ^testing.T) {
	cram: [64]u8
	put_color(cram[:], 0, 0, 0x7FFF) // all 31s -> white
	put_color(cram[:], 0, 1, 0x001F) // red max
	put_color(cram[:], 0, 2, 0x03E0) // green max
	put_color(cram[:], 0, 3, 0x7C00) // blue max

	testing.expect_value(t, cram_color(cram[:], 0, 0), Color{255, 255, 255})
	testing.expect_value(t, cram_color(cram[:], 0, 1), Color{255, 0, 0})
	testing.expect_value(t, cram_color(cram[:], 0, 2), Color{0, 255, 0})
	testing.expect_value(t, cram_color(cram[:], 0, 3), Color{0, 0, 255})
}

// Base math addresses the right palette/color (palette 1, color 2 -> byte 12).
@(test)
test_cram_color_palette_offset :: proc(t: ^testing.T) {
	cram: [64]u8
	put_color(cram[:], 1, 2, 0x0000) // black at byte 12/13
	cram[12] = 0x1F // overwrite low byte -> red only
	testing.expect_value(t, cram_color(cram[:], 1, 2), Color{255, 0, 0})
}

// scale5 fills low bits so 31 -> 255 (not 248) and 0 -> 0.
@(test)
test_scale5_full_range :: proc(t: ^testing.T) {
	testing.expect_value(t, scale5(0), u8(0))
	testing.expect_value(t, scale5(31), u8(255))
	testing.expect_value(t, scale5(1), u8(8)) // (1<<3)|(1>>2) = 8
}
