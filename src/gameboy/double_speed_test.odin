#+build !js
package gameboy

import "core:testing"

import "../cart"

// End-to-end: a ROM that arms KEY1 then executes STOP must switch to double speed
// when run through gb_run_frame (CPU STOP -> gb commits the speed switch).
@(test)
test_double_speed_switch :: proc(t: ^testing.T) {
	rom := make([]byte, 0x8000)
	defer delete(rom)
	rom[0x0143] = 0x80 // CGB cart

	// Program at the 0x0100 entry point:
	//   LD A,0x01      ; 3E 01
	//   LDH (0x4D),A   ; E0 4D   -> arm KEY1
	//   STOP           ; 10 00   -> commit the speed switch
	//   JR -2          ; 18 FE   -> spin in place for the rest of the frame
	prog := []byte{0x3E, 0x01, 0xE0, 0x4D, 0x10, 0x00, 0x18, 0xFE}
	copy(rom[0x0100:], prog)

	gb := new(Gameboy)
	defer free(gb)
	if gb_init_from_bytes(gb, rom) != .None {
		testing.expect(t, false, "init from bytes")
		return
	}
	defer cart.cart_destroy(&gb.cart)

	testing.expect(t, !gb.mmu.double_speed, "starts in single speed")
	gb_run_frame(gb)
	testing.expect(t, gb.mmu.double_speed, "KEY1 arm + STOP -> double speed")
}
