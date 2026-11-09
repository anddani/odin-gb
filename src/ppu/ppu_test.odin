package ppu

import "core:testing"

// LY is read-only to the CPU.
@(test)
test_ly_read_only :: proc(t: ^testing.T) {
	p: Ppu
	p.ly = 0x42
	ppu_write(&p, 0xFF44, 0x00) // attempt to clobber LY
	testing.expect_value(t, p.ly, u8(0x42)) // unchanged
	testing.expect_value(t, ppu_read(&p, 0xFF44), u8(0x42))
}

// STAT: only bits 3-6 are writable; the PPU-controlled low 3 bits survive.
@(test)
test_stat_low_bits_preserved :: proc(t: ^testing.T) {
	p: Ppu
	p.stat = 0x03 // PPU low bits (e.g. mode 3)
	ppu_write(&p, 0xFF41, 0x78) // set the writable enable bits
	testing.expect_value(t, p.stat, u8(0x7B)) // 0x78 | 0x03
}

@(test)
test_ppu_registers_roundtrip :: proc(t: ^testing.T) {
	p: Ppu
	ppu_write(&p, 0xFF40, 0x91) // LCDC
	ppu_write(&p, 0xFF43, 0x20) // SCX
	ppu_write(&p, 0xFF47, 0xE4) // BGP
	testing.expect_value(t, ppu_read(&p, 0xFF40), u8(0x91))
	testing.expect_value(t, ppu_read(&p, 0xFF43), u8(0x20))
	testing.expect_value(t, ppu_read(&p, 0xFF47), u8(0xE4))
}

// --- ppu_step state machine (LCD enabled via LCDC bit 7) ---

@(test)
test_ppu_ly_increments_per_line :: proc(t: ^testing.T) {
	p: Ppu
	p.lcdc = 0x80
	ppu_step(&p, 456)
	testing.expect_value(t, p.ly, u8(1))
}

@(test)
test_ppu_vblank_fires_at_144 :: proc(t: ^testing.T) {
	p: Ppu
	p.lcdc = 0x80
	saw_vblank := false
	for i in 0 ..< 144 {
		vb, _ := ppu_step(&p, 456)
		if vb {saw_vblank = true}
	}
	testing.expect_value(t, p.ly, u8(144))
	testing.expect(t, saw_vblank, "VBlank fires when LY reaches 144")
}

@(test)
test_ppu_mode_progression :: proc(t: ^testing.T) {
	p: Ppu
	p.lcdc = 0x80
	ppu_step(&p, 40) // dots 40  -> mode 2
	testing.expect_value(t, p.mode, u8(2))
	ppu_step(&p, 60) // dots 100 -> mode 3
	testing.expect_value(t, p.mode, u8(3))
	ppu_step(&p, 200) // dots 300 -> mode 0
	testing.expect_value(t, p.mode, u8(0))
}

@(test)
test_ppu_ly_wraps_at_154 :: proc(t: ^testing.T) {
	p: Ppu
	p.lcdc = 0x80
	for i in 0 ..< 154 {
		ppu_step(&p, 456)
	}
	testing.expect_value(t, p.ly, u8(0)) // 153 -> 0
}

@(test)
test_ppu_lcd_off_is_idle :: proc(t: ^testing.T) {
	p: Ppu
	p.lcdc = 0x00 // LCD disabled
	p.ly = 50
	vb, st := ppu_step(&p, 456)
	testing.expect_value(t, p.ly, u8(0)) // reset
	testing.expect_value(t, p.mode, u8(0))
	testing.expect(t, !vb && !st, "no interrupts while LCD off")
}

@(test)
test_ppu_lyc_stat_interrupt :: proc(t: ^testing.T) {
	p: Ppu
	p.lcdc = 0x80
	p.lyc = 1
	p.stat = 0x40 // LYC=LY interrupt enable
	_, st := ppu_step(&p, 456) // LY 0 -> 1 == LYC
	testing.expect(t, st, "STAT interrupt on LYC=LY when enabled")
	testing.expect(t, (p.stat & 0x04) != 0, "LYC=LY flag set")
}

