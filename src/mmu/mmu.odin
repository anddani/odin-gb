package mmu

import "../apu"
import "../cart"
import "../joypad"
import "../ppu"
import "../timer"

Mmu :: struct {
	cart:   ^cart.Cart,
	timer:  ^timer.Timer,
	ppu:    ^ppu.Ppu,
	joypad: ^joypad.Joypad,
	apu:    ^apu.Apu,
	vram:   [2][0x2000]u8,
	wram:   [8][0x1000]u8,
	vbk:    u8,
	svbk:   u8,
	oam:    [0xA0]u8,
	io:     [0x80]u8,
	hram:   [0x7F]u8,
	ie:     u8,
	cgb:    bool,
}

mmu_tick :: proc(mmu: ^Mmu, cycles: int) {
	if timer.timer_step(mmu.timer, cycles) {
		// Bit 2 requests timer interrupt
		mmu.io[0x0F] |= 0x04
	}
	apu.apu_step(mmu.apu, cycles)
}

ppu_tick :: proc(mmu: ^Mmu, cycles: int) {
	vblank, stat := ppu.ppu_step(mmu.ppu, cycles)
	if vblank {
		mmu.io[0x0F] |= 0x01
	}
	if stat {
		mmu.io[0x0F] |= 0x02
	}
}

mmu_read :: proc(mmu: ^Mmu, addr: u16) -> byte {
	value: byte = 0
	switch addr {
	case 0x0000 ..= 0x7FFF, 0xA000 ..= 0xBFFF:
		// ROM + External RAM
		value = cart.cart_read(mmu.cart, addr)

	case 0x8000 ..= 0x9FFF:
		// VRAM
		value = mmu.vram[0][addr - 0x8000]

	case 0xC000 ..= 0xCFFF:
		// WRAM bank 0
		value = mmu.wram[0][addr - 0xC000]

	case 0xD000 ..= 0xDFFF:
		// WRAM bank 1
		value = mmu.wram[1][addr - 0xD000]

	case 0xE000 ..= 0xFDFF:
		// Echo RAM
		value = mmu_read(mmu, addr - 0x2000)

	case 0xFE00 ..= 0xFE9F:
		// OAM
		value = mmu.oam[addr - 0xFE00]

	case 0xFEA0 ..= 0xFEFF:
		// No-op, default value 0xFF
		value = 0xFF

	case 0xFF00 ..= 0xFF7F:
		// I/O
		switch addr {
		case 0xFF00:
			value = joypad.joypad_read(mmu.joypad)
		case 0xFF04 ..= 0xFF07:
			value = timer.timer_read(mmu.timer, addr)
		case 0xFF10 ..= 0xFF3F:
			value = apu.apu_read(mmu.apu, addr)
		case 0xFF40 ..= 0xFF4B:
			value = ppu.ppu_read(mmu.ppu, addr)
		case:
			value = mmu.io[addr - 0xFF00]
		}

	case 0xFF80 ..= 0xFFFE:
		// HRAM
		value = mmu.hram[addr - 0xFF80]

	case 0xFFFF:
		// IE
		value = mmu.ie

	case:
	}
	return value
}

mmu_write :: proc(mmu: ^Mmu, addr: u16, value: byte) {
	switch addr {
	case 0x0000 ..= 0x7FFF, 0xA000 ..= 0xBFFF:
		// ROM + External RAM
		cart.cart_write(mmu.cart, addr, value)

	case 0x8000 ..= 0x9FFF:
		// VRAM
		mmu.vram[0][addr - 0x8000] = value

	case 0xC000 ..= 0xCFFF:
		// WRAM bank 0
		mmu.wram[0][addr - 0xC000] = value

	case 0xD000 ..= 0xDFFF:
		// WRAM bank 1
		mmu.wram[1][addr - 0xD000] = value

	case 0xE000 ..= 0xFDFF:
		// Echo RAM
		mmu_write(mmu, addr - 0x2000, value)

	case 0xFE00 ..= 0xFE9F:
		// OAM
		mmu.oam[addr - 0xFE00] = value

	// No-op
	case 0xFEA0 ..= 0xFEFF:

	case 0xFF00 ..= 0xFF7F:
		// I/O
		switch addr {
		case 0xFF00:
			joypad.joypad_write(mmu.joypad, value)
		case 0xFF04 ..= 0xFF07:
			timer.timer_write(mmu.timer, addr, value)
		case 0xFF10 ..= 0xFF3F:
			apu.apu_write(mmu.apu, addr, value)
		case 0xFF40 ..= 0xFF45, 0xFF47 ..= 0xFF4B:
			ppu.ppu_write(mmu.ppu, addr, value)
		case 0xFF46:
			base := u16(value) << 8
			for i in 0 ..< 0xA0 {
				mmu.oam[i] = mmu_read(mmu, base + u16(i))
			}
		case:
			mmu.io[addr - 0xFF00] = value
		}

	case 0xFF80 ..= 0xFFFE:
		// HRAM
		mmu.hram[addr - 0xFF80] = value

	case 0xFFFF:
		// IE
		mmu.ie = value

	case:

	}
}
