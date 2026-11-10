package ppu

import "core:slice"

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
	oam:         ^[0xA0]u8,
	framebuffer: [HEIGHT][WIDTH]u8,
	bg_idx:      [WIDTH]u8,
	dots:        int,
	mode:        u8,
}

Sprite_Ref :: struct {
	x:   u8,
	idx: int,
}

sync_mode_to_stat :: proc(ppu: ^Ppu) {
	ppu.stat = (ppu.stat & 0xFC) | ppu.mode
}

set_stat_flag :: proc(ppu: ^Ppu, mask: u8, on: bool) {
	ppu.stat = on ? (ppu.stat | mask) : (ppu.stat &~ mask)
}

bg_pixel :: proc(ppu: ^Ppu, map_base, tile_col, tile_row, row_in_tile, col_in_tile: int) -> u8 {
	tile_idx := ppu.vram[map_base + tile_row * 32 + tile_col - 0x8000]

	tile_addr: u16
	if ppu.lcdc & 0b10000 != 0 {
		tile_addr = 0x8000 + u16(tile_idx) * 16
	} else {
		tile_addr = u16(0x9000 + int(i8(tile_idx)) * 16)
	}

	pixel_row_idx := tile_addr + u16(row_in_tile) * 2 - 0x8000
	lo := ppu.vram[pixel_row_idx]
	hi := ppu.vram[pixel_row_idx + 1]

	bit := u8(7 - col_in_tile)
	return ((hi >> bit) & 1) << 1 | ((lo >> bit) & 1)
}

render_scanline :: proc(ppu: ^Ppu, ly: u8) {
	if ppu.lcdc & 0b1 == 0 {
		// BG enable, set shade 0 for whole row
		ppu.framebuffer[ly] = 0
		ppu.bg_idx = 0
		return
	}

	bg_y := (ly + ppu.scy) & 0xFF // BG pixel row
	tile_row := bg_y / 8 // tile row (0-31)
	row_in_tile := bg_y % 8 // pixel row within tile (0-7)

	// Which 32x32 tile map
	map_base := ppu.lcdc & 0b1000 != 0 ? 0x9C00 : 0x9800

	for x in 0 ..< WIDTH {
		window_active := ppu.lcdc & 0x20 != 0 && int(ly) >= int(ppu.wy) && x >= (int(ppu.wx) - 7)

		idx: u8
		if window_active {
			win_x := x - (int(ppu.wx) - 7)
			win_y := int(ly) - int(ppu.wy)
			map_base := ppu.lcdc & 0x40 != 0 ? 0x9C00 : 0x9800
			tile_col := win_x / 8
			tile_row := win_y / 8
			row_in_tile := win_y % 8
			col_in_tile := win_x % 8
			idx = bg_pixel(ppu, map_base, tile_col, tile_row, row_in_tile, col_in_tile)
		} else {
			bg_x := (u8(x) + ppu.scx) & 0xFF
			tile_col := int(bg_x / 8)
			tile_row := int(bg_y / 8)
			col_in_tile := int(bg_x % 8)
			row_in_tile := int(bg_y % 8)
			idx = bg_pixel(ppu, map_base, tile_col, tile_row, row_in_tile, col_in_tile)
		}
		shade := (ppu.bgp >> (idx * 2)) & 0x3
		ppu.bg_idx[x] = idx
		ppu.framebuffer[ly][x] = shade
	}
}

render_sprites :: proc(ppu: ^Ppu, ly: u8) {
	sprite_height: u8 = ppu.lcdc & 0b100 == 0 ? 8 : 16

	on_line: [10]Sprite_Ref
	count := 0
	for i := 0; i < 40 && count < 10; i += 1 {
		oam_y := ppu.oam[i * 4]
		screen_y := int(oam_y) - 16
		if int(ly) >= screen_y && int(ly) < screen_y + int(sprite_height) {
			on_line[count] = {ppu.oam[i * 4 + 1], i}
			count += 1
		}
	}

	slice.sort_by(on_line[:count], proc(a, b: Sprite_Ref) -> bool {
		if a.x != b.x {
			return a.x < b.x
		}
		return a.idx < b.idx
	})

	covered: [WIDTH]bool
	for s in 0 ..< count {
		idx := on_line[s].idx
		oam_y := ppu.oam[idx * 4]
		oam_x := ppu.oam[idx * 4 + 1]
		tile := ppu.oam[idx * 4 + 2]
		attr := ppu.oam[idx * 4 + 3]

		screen_y := int(oam_y) - 16
		screen_x := int(oam_x) - 8

		row := int(ly) - screen_y
		if attr & 0x40 != 0 {
			row = int(sprite_height) - 1 - row
		}

		if sprite_height == 16 {
			tile &= 0xFE
			if row >= 8 {
				tile |= 1
				row -= 8
			}
		}

		addr := 0x8000 + int(tile) * 16 + row * 2
		lo := ppu.vram[addr - 0x8000]
		hi := ppu.vram[addr - 0x8000 + 1]

		for col in 0 ..< 8 {
			bit := attr & 0x20 != 0 ? col : 7 - col
			color_idx := ((hi >> u8(bit)) & 1) << 1 | ((lo >> u8(bit)) & 1)

			if color_idx == 0 {
				continue
			}

			x := screen_x + col
			if x < 0 || x >= 160 {
				continue
			}
			if covered[x] {
				continue
			}

			covered[x] = true
			if attr & 0x80 != 0 && ppu.bg_idx[x] != 0 {
				continue
			}

			palette := attr & 0x10 != 0 ? ppu.obp1 : ppu.obp0
			shade := (palette >> (color_idx * 2)) & 0x3
			ppu.framebuffer[ly][x] = shade
		}
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
			if ppu.lcdc & 0b10 != 0 {
				render_sprites(ppu, ppu.ly)
			}
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
