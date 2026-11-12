package cart

cart_write_none :: proc(cart: ^Cart, addr: u16, value: byte) {
	if addr >= 0xA000 && addr < 0xC000 && len(cart.ram) > 0 {
		off := cart.ram_bank * 0x2000 + int(addr - 0xA000)
		cart.ram[off % len(cart.ram)] = value
	}
}

cart_write_mbc1 :: proc(cart: ^Cart, addr: u16, value: byte) {
	switch {
	case addr < 0x2000:
		cart.ram_enable = (value & 0x0F) == 0x0A

	case addr < 0x4000:
		lo := int(value & 0x1F)
		if lo == 0 {
			lo = 1
		}
		cart.rom_bank = (cart.rom_bank & 0x60) | lo

	case addr < 0x6000:
		two := int(value & 0x03)
		if cart.mode == 0 {
			cart.rom_bank = (cart.rom_bank & 0x1F) | (two << 5)
		} else {
			cart.ram_bank = two
		}

	case addr < 0x8000:
		cart.mode = value & 1

	case addr >= 0xA000 && addr < 0xC000:
		if cart.ram_enable && len(cart.ram) > 0 {
			off := cart.ram_bank * 0x2000 + int(addr - 0xA000)
			cart.ram[off % len(cart.ram)] = value
		}
	}
}

cart_write_mbc3 :: proc(cart: ^Cart, addr: u16, value: byte) {
	switch {
	case addr < 0x2000:
		cart.ram_enable = (value & 0x0F) == 0x0A

	case addr < 0x4000:
		rom_bank := int(value & 0x7F)
		if rom_bank == 0 {
			rom_bank = 1
		}
		cart.rom_bank = rom_bank

	case addr < 0x6000:
		cart.ram_bank = int(value & 0x0F)

	case addr < 0x8000:

	case addr >= 0xA000 && addr < 0xC000:
		if cart.ram_enable && cart.ram_bank <= 3 && len(cart.ram) > 0 {
			off := cart.ram_bank * 0x2000 + int(addr - 0xA000)
			cart.ram[off % len(cart.ram)] = value
		}
	}
}

cart_write :: proc(cart: ^Cart, addr: u16, value: byte) {
	switch cart.mbc {
	case .None:
		cart_write_none(cart, addr, value)
	case .MBC1:
		cart_write_mbc1(cart, addr, value)
	case .MBC3:
		cart_write_mbc3(cart, addr, value)
	case .MBC5:
	// TODO
	}
}
