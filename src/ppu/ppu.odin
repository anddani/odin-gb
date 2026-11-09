package ppu

Ppu :: struct {
	lcdc: u8, // FF40
	stat: u8, // FF41
	scy:  u8, // FF42
	scx:  u8, // FF43
	ly:   u8, // FF44
	lyc:  u8, // FF45
	bgp:  u8, // FF47
	wy:   u8, // FF4A
	wx:   u8, // FF4B
	dots: int,
	mode: u8,
}

sync_mode_to_stat :: proc(ppu: ^Ppu) {
	ppu.stat = (ppu.stat & 0xFC) | ppu.mode
}

set_stat_flag :: proc(ppu: ^Ppu, mask: u8, on: bool) {
	ppu.stat = on ? (ppu.stat | mask) : (ppu.stat &~ mask)
}

ppu_step :: proc(ppu: ^Ppu, cycles: int) -> (bool, bool) {
	vblank, stat := false, false

	// LCD disabled
	if ppu.lcdc & 0x80 == 0 {
		ppu.dots = 0
		ppu.ly = 0
		ppu.mode = 0
		sync_mode_to_stat(ppu)
		return false, false
	}

	ppu.dots += cycles

	// End of scanline
	if ppu.dots >= 456 {
		ppu.dots -= 456
		ppu.ly = (ppu.ly + 1) % 154
		lyc_equal := ppu.ly == ppu.lyc
		set_stat_flag(ppu, 0x04, lyc_equal)
		if lyc_equal && ppu.stat & 0x40 == 0 {
			stat = true
		}

		// Entering VBlank
		if ppu.ly == 144 {
			vblank = true
		}
	}

	return vblank, stat
}

ppu_read :: proc(ppu: ^Ppu, addr: u16) -> u8 {
	result: u8 = 0xFF
	switch addr {
	case 0xFF40:
		result = ppu.lcdc
	case 0xFF41:
		result = ppu.stat
	case 0xFF42:
		result = ppu.scy
	case 0xFF43:
		result = ppu.scx
	case 0xFF44:
		result = ppu.ly
	case 0xFF45:
		result = ppu.lyc
	case 0xFF47:
		result = ppu.bgp
	case 0xFF4A:
		result = ppu.wy
	case 0xFF4B:
		result = ppu.wx
	}
	return result
}

ppu_write :: proc(ppu: ^Ppu, addr: u16, value: u8) {
	switch addr {
	case 0xFF40:
		ppu.lcdc = value
	case 0xFF41:
		ppu.stat = (value & 0xF8) | (ppu.stat & 0x07)
	case 0xFF42:
		ppu.scy = value
	case 0xFF43:
		ppu.scx = value
	case 0xFF45:
		ppu.lyc = value
	case 0xFF47:
		ppu.bgp = value
	case 0xFF4A:
		ppu.wy = value
	case 0xFF4B:
		ppu.wx = value
	}
}
