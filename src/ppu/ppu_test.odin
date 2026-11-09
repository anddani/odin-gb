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
