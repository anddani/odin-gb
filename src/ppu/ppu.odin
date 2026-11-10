package ppu

WIDTH :: 160
HEIGHT :: 144
VRam :: [0x2000]u8

Ppu :: struct {
	lcdc:        u8, // FF40
	stat:        u8, // FF41
	scy:         u8, // FF42
	scx:         u8, // FF43
	ly:          u8, // FF44
	lyc:         u8, // FF45
	bgp:         u8, // FF47
	obp0:        u8, // FF48
	obp1:        u8, // FF49
	wy:          u8, // FF4A
	wx:          u8, // FF4B
	vram:        ^VRam, // TODO: Refactor to move ownership of VRAM to PPU instead of MMU
	framebuffer: [HEIGHT][WIDTH]u8,
	dots:        int,
	mode:        u8,
}


sync_mode_to_stat :: proc(ppu: ^Ppu) {
	ppu.stat = (ppu.stat & 0xFC) | ppu.mode
}

set_stat_flag :: proc(ppu: ^Ppu, mask: u8, on: bool) {
	ppu.stat = on ? (ppu.stat | mask) : (ppu.stat &~ mask)
}

render_scanline :: proc(ppu: ^Ppu, ly: u8) {
	if ppu.lcdc & 0b1 == 0 {
		// BG enable, set shade 0 for whole row
		ppu.framebuffer[ly] = 0
		return
	}

	bgY := (ly + ppu.scy) & 0xFF // BG pixel row
	tileRow := bgY / 8 // tile row (0-31)
	rowInTile := bgY % 8 // pixel row within tile (0-7)

	// Which 32x32 tile map
	map_base := ppu.lcdc & 0b1000 != 0 ? 0x9C00 : 0x9800

	for x in 0 ..< WIDTH {
		bgX := (u8(x) + ppu.scx) & 0xFF
		tileCol := bgX / 8
		colInTile := bgX % 8

		tile_index := ppu.vram[map_base + int(tileRow) * 32 + int(tileCol) - 0x8000]

		tile_addr: u16
		if ppu.lcdc & 0b10000 != 0 {
			tile_addr = 0x8000 + u16(tile_index) * 16
		} else {
			tile_addr = u16(0x9000 + int(i8(tile_index)) * 16)
		}

		pixel_row_idx := tile_addr + u16(rowInTile) * 2 - 0x8000
		lo := ppu.vram[pixel_row_idx]
		hi := ppu.vram[pixel_row_idx + 1]

		bit := 7 - colInTile
		color_idx := ((hi >> bit) & 1) << 1 | ((lo >> bit) & 1)

		shade := (ppu.bgp >> (color_idx * 2)) & 0x3
		ppu.framebuffer[ly][x] = shade
	}
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
		if lyc_equal && ppu.stat & 0x40 != 0 {
			stat = true
		}

		// Entering VBlank
		if ppu.ly == 144 {
			vblank = true
		}
	}

	new_mode: u8
	if ppu.ly >= 144 {
		// VBlank
		new_mode = 1
	} else if ppu.dots < 80 {
		// OAM scan
		new_mode = 2
	} else if ppu.dots < 252 {
		// Drawing
		new_mode = 3
	} else {
		// HBlank
		new_mode = 0
	}

	if new_mode != ppu.mode {
		ppu.mode = new_mode
		sync_mode_to_stat(ppu)
		if new_mode == 0 {
			render_scanline(ppu, ppu.ly)
		}
		if new_mode == 0 && ppu.stat & 0x08 != 0 ||
		   new_mode == 2 && ppu.stat & 0x20 != 0 ||
		   new_mode == 1 && ppu.stat & 0x10 != 0 {
			stat = true
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
	case 0xFF48:
		result = ppu.obp0
	case 0xFF49:
		result = ppu.obp1
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
	case 0xFF48:
		ppu.obp0 = value
	case 0xFF49:
		ppu.obp1 = value
	case 0xFF4A:
		ppu.wy = value
	case 0xFF4B:
		ppu.wx = value
	}
}
