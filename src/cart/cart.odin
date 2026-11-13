package cart

import "core:os"
import "core:slice"

MIN_ROM_SIZE :: 0x8000

Cart :: struct {
	rom:        []byte,
	ram:        []byte,
	mbc:        Mbc,
	battery:    bool,
	rom_bank:   int,
	ram_bank:   int,
	ram_enable: bool,
	mode:       byte,
	save_path:  string,
	cgb:        bool,
}

Mbc :: enum {
	None,
	MBC1,
	MBC3,
	MBC5,
}

Cart_Error :: enum {
	None,
	File_Unreadable,
	Too_Small,
}

parse_cart_type :: proc(b: byte) -> (mbc: Mbc, battery: bool) {
	switch b {
	case 0x00:
		return .None, false
	case 0x01:
		return .MBC1, false
	case 0x02:
		return .MBC1, false
	case 0x03:
		return .MBC1, true
	case 0x0F, 0x10, 0x13:
		return .MBC3, true
	case 0x11, 0x12:
		return .MBC3, false
	case 0x1B, 0x1E:
		return .MBC5, true
	case 0x19, 0x1A, 0x1C, 0x1D:
		return .MBC5, false
	}
	return .None, false
}

ram_size_from :: proc(b: byte) -> int {
	switch b {
	case 0x02:
		return 8 * 1024
	case 0x03:
		return 32 * 1024
	case 0x04:
		return 128 * 1024
	case 0x05:
		return 64 * 1024
	}
	return 0
}

cart_from_bytes :: proc(data: []byte) -> (Cart, Cart_Error) {
	if len(data) < MIN_ROM_SIZE {
		return {}, Cart_Error.Too_Small
	}

	c := Cart {
		rom = slice.clone(data),
	}
	c.cgb = data[0x0143] & 0x80 != 0
	c.mbc, c.battery = parse_cart_type(data[0x147])
	ram_bytes := ram_size_from(data[0x0149])
	if ram_bytes > 0 {
		c.ram = make([]byte, ram_bytes)
	}
	c.rom_bank = 1

	return c, Cart_Error.None
}

cart_from_file :: proc(path: string) -> (Cart, Cart_Error) {
	file_data, file_err := os.read_entire_file_from_path(path, context.allocator)
	if file_err != nil {
		return {}, Cart_Error.File_Unreadable
	}
	defer delete(file_data)

	cart, cart_err := cart_from_bytes(file_data)

	if cart_err != .None {
		return cart, cart_err
	}

	cart_set_save_path(&cart, path)
	cart_load_ram(&cart)

	return cart, cart_err
}

cart_destroy :: proc(c: ^Cart) {
	delete(c.save_path)
	delete(c.rom)
	delete(c.ram)
}
