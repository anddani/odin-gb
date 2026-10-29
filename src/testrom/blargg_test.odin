package testrom

import "core:testing"

import "../cart"

// Boots an individual Blargg cpu_instrs sub-ROM headless and asserts it prints
// "Passed" over serial. Run from the repo root so the asset path resolves.
run_sub_rom :: proc(t: ^testing.T, path: string) {
	result, err := run_blargg_serial(path)
	if err != .None {
		testing.expectf(t, false, "could not load %s (err=%v)", path, err)
		return
	}
	testing.expectf(
		t,
		result.status == .Passed,
		"%s: expected Passed, got %v after %d cycles",
		path,
		result.status,
		result.cycles,
	)
}

@(test)
test_blargg_06_ld :: proc(t: ^testing.T) {
	run_sub_rom(t, "assets/06-ld r,r.gb")
}
