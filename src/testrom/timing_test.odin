package testrom

import "core:testing"

// Blargg timing suites -- verify exact per-instruction and memory-access cycle
// counts. Both are MBC1 ROMs; they report pass/fail over serial.

@(test)
test_instr_timing :: proc(t: ^testing.T) {
	result, err := run_blargg_serial("assets/instr_timing.gb")
	if err != .None {
		testing.expectf(t, false, "load err %v", err)
		return
	}
	testing.expectf(t, result.status == .Passed, "instr_timing: got %v", result.status)
}

@(test)
test_mem_timing :: proc(t: ^testing.T) {
	result, err := run_blargg_serial("assets/mem_timing.gb")
	if err != .None {
		testing.expectf(t, false, "load err %v", err)
		return
	}
	testing.expectf(t, result.status == .Passed, "mem_timing: got %v", result.status)
}
