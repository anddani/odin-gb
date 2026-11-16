#+build !js
package gameboy

import "../cart"

gb_init :: proc(gb: ^Gameboy, rom_path: string) -> cart.Cart_Error {
	c, err := cart.cart_from_file(rom_path)

	if err == cart.Cart_Error.None {
		gb_init_cart(gb, c)
	}

	return err
}
