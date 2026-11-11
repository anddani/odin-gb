package cart

import "core:os"
import "core:path/filepath"
import "core:strings"

set_save_path :: proc(cart: ^Cart, path: string) {
	// Get the save path by replacing the rom extension with ".sav"
	ext := filepath.ext(path)
	stem := path[:len(path) - len(ext)]
	cart.save_path = strings.concatenate({stem, ".sav"})
}

copy_save_to_ram :: proc(cart: ^Cart) {
	if cart.battery && len(cart.ram) > 0 {
		sav, sav_err := os.read_entire_file(cart.save_path, context.allocator)
		if sav_err == nil {
			defer delete(sav)
			n := min(len(sav), len(cart.ram))
			copy(cart.ram[:n], sav[:n])
		}
	}
}
