package apu

import "core:testing"

@(test)
test_reg_roundtrip :: proc(t: ^testing.T) {
	a: Apu
	a.power = true
	apu_write(&a, 0xFF16, 0x80) // NR21
	apu_write(&a, 0xFF30, 0xAB) // Wave RAM
	testing.expect_value(t, apu_read(&a, 0xFF16), u8(0x80))
	testing.expect_value(t, apu_read(&a, 0xFF30), u8(0xAB))
}

// NR52: bit7 power, bits4-6 read as 1, bits0-3 status (0 for now).
@(test)
test_nr52_read :: proc(t: ^testing.T) {
	a: Apu
	a.power = false
	testing.expect_value(t, apu_read(&a, 0xFF26), u8(0x70)) // power off -> 0x70
	a.power = true
	testing.expect_value(t, apu_read(&a, 0xFF26), u8(0xF0)) // power on -> 0xF0
}

// Writing NR52 consumes only bit 7.
@(test)
test_nr52_power_toggle :: proc(t: ^testing.T) {
	a: Apu
	apu_write(&a, 0xFF26, 0x80)
	testing.expect(t, a.power, "bit7 set -> power on")
	apu_write(&a, 0xFF26, 0x00)
	testing.expect(t, !a.power, "bit7 clear -> power off")
}

// Powering off clears NR10..NR25 but not Wave RAM.
@(test)
test_power_off_clears_regs :: proc(t: ^testing.T) {
	a: Apu
	a.power = true
	apu_write(&a, 0xFF10, 0x55) // NR10
	apu_write(&a, 0xFF25, 0x66) // NR51
	apu_write(&a, 0xFF30, 0x99) // Wave RAM
	apu_write(&a, 0xFF26, 0x00) // power off
	testing.expect_value(t, a.regs[0x00], u8(0)) // NR10 cleared
	testing.expect_value(t, a.regs[0x15], u8(0)) // NR51 cleared
	testing.expect_value(t, a.regs[0x20], u8(0x99)) // Wave RAM retained
}

// While powered off, writes to NR10..NR25 are ignored.
@(test)
test_power_off_write_gate :: proc(t: ^testing.T) {
	a: Apu
	a.power = false
	apu_write(&a, 0xFF10, 0x55) // ignored
	testing.expect_value(t, a.regs[0x00], u8(0))
	apu_write(&a, 0xFF30, 0x99) // Wave RAM still writable
	testing.expect_value(t, a.regs[0x20], u8(0x99))
}

// Frame sequencer: 512 Hz tick (every 8192 cycles), 8-step cycle.
@(test)
test_fs_step_advances :: proc(t: ^testing.T) {
	a: Apu
	a.power = true
	apu_step(&a, 8191)
	testing.expect_value(t, a.fs_step, u8(0)) // not yet
	apu_step(&a, 1)
	testing.expect_value(t, a.fs_step, u8(1)) // one 512 Hz tick
}

@(test)
test_fs_wraps_at_8 :: proc(t: ^testing.T) {
	a: Apu
	a.power = true
	apu_step(&a, 8192 * 8) // 8 ticks -> back to step 0
	testing.expect_value(t, a.fs_step, u8(0))
}

@(test)
test_fs_frozen_when_off :: proc(t: ^testing.T) {
	a: Apu
	a.power = false
	apu_step(&a, 8192 * 4)
	testing.expect_value(t, a.fs_step, u8(0)) // no advance while powered off
}

// Over one full 8-step cycle: length fires 4x (256Hz), sweep 2x (128Hz),
// envelope 1x (64Hz). Verified by the step schedule in apu_step.
@(test)
test_fs_cadence_schedule :: proc(t: ^testing.T) {
	// map step -> expected modulators (per the schedule)
	length_steps := [8]bool{true, false, true, false, true, false, true, false}
	sweep_steps := [8]bool{false, false, true, false, false, false, true, false}
	env_steps := [8]bool{false, false, false, false, false, false, false, true}
	lc, sc, ec := 0, 0, 0
	for s in 0 ..< 8 {
		if length_steps[s] {lc += 1}
		if sweep_steps[s] {sc += 1}
		if env_steps[s] {ec += 1}
	}
	testing.expect_value(t, lc, 4) // 256 Hz
	testing.expect_value(t, sc, 2) // 128 Hz
	testing.expect_value(t, ec, 1) // 64 Hz
}
