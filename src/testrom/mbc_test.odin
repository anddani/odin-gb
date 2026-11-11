package testrom

import "core:testing"

// Combined cpu_instrs.gb is a 4-bank MBC1 ROM -- exercises banking end to end.
@(test)
test_combined_cpu_instrs :: proc(t: ^testing.T) {
	result, err := run_blargg_serial("assets/cpu_instrs.gb")
	if err != .None {
		testing.expectf(t, false, "load err %v", err)
		return
	}
	testing.expectf(t, result.status == .Passed, "combined cpu_instrs: got %v", result.status)
}
