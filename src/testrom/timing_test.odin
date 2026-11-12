package testrom

import "core:testing"

// Blargg instr_timing / mem_timing verify SUB-INSTRUCTION timing: exactly when,
// within an instruction, the timer advances and memory accesses land. Our
// architecture is instruction-atomic (peripherals are ticked by the whole
// instruction's cycle count AFTER cpu.step returns), so these cannot pass
// without a cycle-accurate rewrite of the step loop. That is a deliberate
// scanline-first deferral (see PLAN M8). These tests document the current
// status: they are EXPECTED to fail until cycle accuracy is implemented.

@(test)
test_instr_timing_expected_fail :: proc(t: ^testing.T) {
	result, err := run_blargg_serial("assets/instr_timing.gb")
	if err != .None {return}
	// Flips to .Passed the day we go cycle-accurate -- then make this an assert.
	testing.expect(
		t,
		result.status != .Passed,
		"instr_timing unexpectedly PASSED -- cycle accuracy achieved; promote this test",
	)
}

@(test)
test_mem_timing_expected_fail :: proc(t: ^testing.T) {
	result, err := run_blargg_serial("assets/mem_timing.gb")
	if err != .None {return}
	testing.expect(
		t,
		result.status != .Passed,
		"mem_timing unexpectedly PASSED -- cycle accuracy achieved; promote this test",
	)
}
