package cart

import "core:os"
import "core:slice"

MIN_ROM_SIZE :: 0x8000

Cart :: struct {
	rom:        []byte,
	ram:        []byte,
	// mbc:        Mbc,
	battery:    bool,
	rom_bank:   int,
	ram_bank:   int,
	ram_enable: bool,
	mode:       byte,
}

Cart_Error :: enum {
	None,
	File_Unreadable,
	Too_Small,
}

cart_from_bytes :: proc(data: []byte) -> (Cart, Cart_Error) {
	if len(data) < MIN_ROM_SIZE {
		return {}, Cart_Error.Too_Small
	}

	return Cart{rom = slice.clone(data)}, Cart_Error.None
}

cart_from_file :: proc(path: string) -> (Cart, Cart_Error) {
	data, err := os.read_entire_file_from_path(path, context.allocator)
	if err != nil {
		return {}, Cart_Error.File_Unreadable
	}
	defer delete(data)

	return cart_from_bytes(data)
}

cart_read :: proc(cart: ^Cart, addr: u16) -> byte {
	if (addr < MIN_ROM_SIZE) {
		return cart.rom[addr]
	} else {
		return 0 // TODO: external RAM
	}
}

cart_write :: proc(cart: ^Cart, addr: u16, value: byte) {
	if (addr < MIN_ROM_SIZE) {
		// Ignore writes to ROM
		return
	}
	// TODO: external RAM
}

cart_destroy :: proc(c: ^Cart) {
	delete(c.rom)
}
