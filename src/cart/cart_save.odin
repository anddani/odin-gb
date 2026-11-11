package cart

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

cart_set_save_path :: proc(cart: ^Cart, path: string) {
	// Get the save path by replacing the rom extension with ".sav"
	ext := filepath.ext(path)
	stem := path[:len(path) - len(ext)]
	cart.save_path = strings.concatenate({stem, ".sav"})
}

cart_load_ram :: proc(cart: ^Cart) {
	if cart.battery && len(cart.ram) > 0 {
		sav, sav_err := os.read_entire_file(cart.save_path, context.allocator)
		if sav_err == nil {
			defer delete(sav)
			n := min(len(sav), len(cart.ram))
			copy(cart.ram[:n], sav[:n])
		}
	}
}

cart_save_ram :: proc(cart: ^Cart) {
	if cart.battery && len(cart.ram) > 0 {
		err := os.write_entire_file(cart.save_path, cart.ram)
		if err != nil {
			fmt.eprintln("Save failed:", err)
		}
	}
}
