#+build !js
package cart

import "core:os"

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
