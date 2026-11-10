package gameboy

import "core:testing"

import "../cart"

// End-to-end smoke test: the whole machine (CPU+MMU+timer+PPU) runs real ROM
// frames without crashing. Run from the repo root for the asset path.
@(test)
test_gameboy_runs_frames :: proc(t: ^testing.T) {
	gb := new(Gameboy)
	defer free(gb)

	err := gb_init(gb, "assets/06-ld r,r.gb")
	if err != .None {
		testing.expectf(t, false, "init failed: %v", err)
		return
	}
	defer cart.cart_destroy(&gb.cart)

	for i in 0 ..< 10 {
		gb_run_frame(gb)
	}

	testing.expect(t, gb.cart.rom != nil, "cart ROM loaded")
	testing.expect(t, gb.cpu.pc != 0x0100, "CPU advanced past the entry point")
}
