package cart

rom_read :: proc(cart: ^Cart, addr: u16) -> byte {
	switch {
	case addr < 0x4000:
		return cart.rom[addr]

	case addr < 0x8000:
		bank := cart.rom_bank % (len(cart.rom) / 0x4000)
		return cart.rom[bank * 0x4000 + int(addr - 0x4000)]
	}
	return 0xFF
}

ram_read :: proc(cart: ^Cart, addr: u16) -> byte {
	if !cart.ram_enable || len(cart.ram) == 0 {
		return 0xFF
	}
	off := cart.ram_bank * 0x2000 + int(addr - 0xA000)
	return cart.ram[off % len(cart.ram)]
}

cart_read_none :: proc(cart: ^Cart, addr: u16) -> byte {
	if addr < 0x8000 {
		return cart.rom[addr]
	}
	if addr >= 0xA000 && addr < 0xC000 && len(cart.ram) > 0 {
		return cart.ram[int(addr - 0xA000)]
	}
	return 0xFF
}

cart_read_mbc1 :: proc(cart: ^Cart, addr: u16) -> byte {
	switch {
	case addr < 0x8000:
		return rom_read(cart, addr)

	case addr >= 0xA000 && addr < 0xC000:
		return ram_read(cart, addr)
	}
	return 0xFF
}

cart_read_mbc3 :: proc(cart: ^Cart, addr: u16) -> byte {
	switch {
	case addr < 0x8000:
		return rom_read(cart, addr)

	case addr >= 0xA000 && addr < 0xC000:
		if !cart.ram_enable || len(cart.ram) == 0 {
			return 0xFF
		}
		if cart.ram_bank <= 3 {
			off := cart.ram_bank * 0x2000 + int(addr - 0xA000)
			return cart.ram[off % len(cart.ram)]
		} else {
			return 0x00 // FIXME: stub
		}
	}
	return 0xFF
}

cart_read_mbc5 :: proc(cart: ^Cart, addr: u16) -> byte {
	switch {
	case addr < 0x8000:
		return rom_read(cart, addr)

	case addr >= 0xA000 && addr < 0xC000:
		return ram_read(cart, addr)
	}
	return 0xFF
}

cart_read :: proc(cart: ^Cart, addr: u16) -> byte {
	switch cart.mbc {
	case .None:
		return cart_read_none(cart, addr)
	case .MBC1:
		return cart_read_mbc1(cart, addr)
	case .MBC3:
		return cart_read_mbc3(cart, addr)
	case .MBC5:
		return cart_read_mbc5(cart, addr)
	}
	return 0xFF
}
