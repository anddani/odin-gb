package mmu

import "../cart"

Mmu :: struct {
	cart: ^cart.Cart,
	vram: [1][0x2000]u8,
	wram: [2][0x1000]u8,
	oam:  [0xA0]u8,
	io:   [0x80]u8,
	hram: [0x7F]u8,
	ie:   u8,
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

	case:

	}
}
