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

// --- Channel 2 trigger ---

@(test)
test_ch2_trigger_enables :: proc(t: ^testing.T) {
	a: Apu
	a.power = true
	apu_write(&a, 0xFF17, 0xF0) // NR22: volume 15, no envelope
	apu_write(&a, 0xFF18, 0x00) // NR23: freq low
	apu_write(&a, 0xFF19, 0x87) // NR24: trigger + freq high 7
	testing.expect(t, a.ch2.enabled, "trigger enables channel")
	testing.expect_value(t, a.ch2.volume, u8(15))
	// freq = 0x700 = 1792 -> timer = (2048-1792)*4 = 1024
	testing.expect_value(t, a.ch2.freq_timer, 1024)
}

@(test)
test_ch2_length_inverted_load :: proc(t: ^testing.T) {
	a: Apu
	a.power = true
	apu_write(&a, 0xFF16, 0x30) // NR21: duty=0, length data=0x30
	testing.expect_value(t, a.ch2.length, 64 - 0x30)
	testing.expect_value(t, a.ch2.duty, u8(0))
}

@(test)
test_ch2_dac_off_prevents_enable :: proc(t: ^testing.T) {
	a: Apu
	a.power = true
	apu_write(&a, 0xFF17, 0x00) // NR22: volume 0, no direction -> DAC off
	apu_write(&a, 0xFF19, 0x80) // trigger
	testing.expect(t, !a.ch2.enabled, "DAC off -> trigger cannot enable")
}

@(test)
test_ch2_trigger_reloads_length_if_zero :: proc(t: ^testing.T) {
	a: Apu
	a.power = true
	a.ch2.length = 0
	apu_write(&a, 0xFF17, 0xF0) // keep DAC on
	apu_write(&a, 0xFF19, 0x80) // trigger
	testing.expect_value(t, a.ch2.length, 64) // reloaded
}

// --- Channel 2 length / envelope clocking ---

@(test)
test_ch2_length_disables :: proc(t: ^testing.T) {
	a: Apu
	a.ch2.enabled = true
	a.ch2.length_enable = true
	a.ch2.length = 2
	clock_length(&a)
	testing.expect(t, a.ch2.enabled, "still on at length 1")
	clock_length(&a)
	testing.expect(t, !a.ch2.enabled, "disabled when length hits 0")
}

@(test)
test_ch2_length_frozen_when_disabled :: proc(t: ^testing.T) {
	a: Apu
	a.ch2.enabled = true
	a.ch2.length_enable = false // length not counting
	a.ch2.length = 3
	clock_length(&a)
	testing.expect_value(t, a.ch2.length, 3) // unchanged
	testing.expect(t, a.ch2.enabled, "stays on")
}

// --- Channel 2 envelope ---

@(test)
test_ch2_envelope_up_clamps :: proc(t: ^testing.T) {
	a: Apu
	a.ch2.env_period = 1
	a.ch2.env_add = true
	a.ch2.env_timer = 1
	a.ch2.volume = 14
	clock_envelope(&a)
	testing.expect_value(t, a.ch2.volume, u8(15))
	a.ch2.env_timer = 1
	clock_envelope(&a)
	testing.expect_value(t, a.ch2.volume, u8(15)) // clamped at 15
}

@(test)
test_ch2_envelope_down_clamps :: proc(t: ^testing.T) {
	a: Apu
	a.ch2.env_period = 1
	a.ch2.env_add = false
	a.ch2.env_timer = 1
	a.ch2.volume = 1
	clock_envelope(&a)
	testing.expect_value(t, a.ch2.volume, u8(0))
	a.ch2.env_timer = 1
	clock_envelope(&a)
	testing.expect_value(t, a.ch2.volume, u8(0)) // clamped at 0
}

@(test)
test_ch2_envelope_period_zero_off :: proc(t: ^testing.T) {
	a: Apu
	a.ch2.env_period = 0
	a.ch2.env_add = true
	a.ch2.volume = 5
	clock_envelope(&a)
	testing.expect_value(t, a.ch2.volume, u8(5)) // disabled -> no change
}

@(test)
test_ch2_envelope_waits_period :: proc(t: ^testing.T) {
	a: Apu
	a.ch2.env_period = 3
	a.ch2.env_add = true
	a.ch2.env_timer = 3
	a.ch2.volume = 0
	clock_envelope(&a) // timer 3->2
	clock_envelope(&a) // 2->1
	testing.expect_value(t, a.ch2.volume, u8(0)) // not yet
	clock_envelope(&a) // 1->0 -> step
	testing.expect_value(t, a.ch2.volume, u8(1))
}

// --- Channel 2 waveform output ---

@(test)
test_ch2_square_wave :: proc(t: ^testing.T) {
	a: Apu
	a.power = true
	apu_write(&a, 0xFF16, 0x80) // NR21: duty 2 (50%), length 0
	apu_write(&a, 0xFF17, 0xA0) // NR22: volume 10, no envelope
	apu_write(&a, 0xFF18, 0x00) // NR23: freq low
	apu_write(&a, 0xFF19, 0x87) // NR24: trigger, freq high 7 -> freq 0x700=1792, period (2048-1792)*4=1024

	// duty 2 pattern is {1,0,0,0,0,1,1,1}; duty_pos starts 0 -> output volume*pattern[0]=10
	seen_high := false
	seen_low := false
	for i in 0 ..< 16 {
		out := square_output(&a.ch2)
		if out == 10 {seen_high = true}
		if out == 0 {seen_low = true}
		square_step(&a.ch2, 1024) // advance exactly one duty step
	}
	testing.expect(t, seen_high, "square wave reaches volume 10")
	testing.expect(t, seen_low, "square wave reaches 0")
}

@(test)
test_ch2_silent_when_disabled :: proc(t: ^testing.T) {
	a: Apu
	a.ch2.enabled = false
	a.ch2.volume = 15
	testing.expect_value(t, square_output(&a.ch2), u8(0))
}

@(test)
test_ch2_duty_pos_advances :: proc(t: ^testing.T) {
	a: Apu
	a.power = true
	apu_write(&a, 0xFF17, 0xF0) // NR22: DAC on so trigger enables
	apu_write(&a, 0xFF18, 0x00) // freq low 0
	apu_write(&a, 0xFF19, 0x80) // trigger, freq 0 -> period 8192, freq_timer loaded
	a.ch2.duty_pos = 0
	square_step(&a.ch2, 8192)
	testing.expect_value(t, a.ch2.duty_pos, u8(1))
	square_step(&a.ch2, 8192 * 3)
	testing.expect_value(t, a.ch2.duty_pos, u8(4))
}

// --- sample buffer / drain ---

@(test)
test_apu_produces_samples :: proc(t: ^testing.T) {
	a: Apu
	a.power = true
	apu_write(&a, 0xFF17, 0xF0) // NR22 volume 15
	apu_write(&a, 0xFF16, 0x80) // duty 50%
	apu_write(&a, 0xFF19, 0x87) // trigger
	apu_step(&a, 4194304 / 60) // ~one frame of cycles
	out: [2048]i16
	n := apu_drain(&a, out[:])
	testing.expect(t, n > 700 && n < 900, "about 800 samples per frame") // 48000/60
}

@(test)
test_apu_drain_empties :: proc(t: ^testing.T) {
	a: Apu
	a.power = true
	apu_write(&a, 0xFF17, 0xF0)
	apu_write(&a, 0xFF19, 0x80)
	apu_step(&a, 87 * 10) // ~10 samples
	out: [64]i16
	n1 := apu_drain(&a, out[:])
	testing.expect(t, n1 >= 9 && n1 <= 11, "drained ~10")
	n2 := apu_drain(&a, out[:])
	testing.expect_value(t, n2, 0) // nothing left
}

// --- Channel 1 sweep ---

@(test)
test_sweep_slides_down :: proc(t: ^testing.T) {
	a: Apu
	a.power = true
	apu_write(&a, 0xFF10, 0x19) // NR10: period 1, down (bit3), shift 1
	apu_write(&a, 0xFF12, 0xF0) // NR12: DAC on
	apu_write(&a, 0xFF13, 0x00) // freq low
	apu_write(&a, 0xFF14, 0x84) // trigger, freq high -> freq 0x400 = 1024
	testing.expect_value(t, a.ch1.sweep_shadow, 1024)
	clock_sweep(&a) // timer 1->0, step: 1024 - (1024>>1) = 512
	testing.expect_value(t, a.ch1.freq, 512)
}

@(test)
test_sweep_up_overflow_disables :: proc(t: ^testing.T) {
	a: Apu
	a.power = true
	apu_write(&a, 0xFF10, 0x11) // period 1, UP, shift 1
	apu_write(&a, 0xFF12, 0xF0)
	apu_write(&a, 0xFF13, 0xFF) // freq low
	apu_write(&a, 0xFF14, 0x87) // trigger, freq high 7 -> freq 0x7FF = 2047
	// 2047 + (2047>>1)=3070 > 2047 -> overflow
	clock_sweep(&a)
	testing.expect(t, !a.ch1.enabled, "sweep overflow disables channel")
}

@(test)
test_sweep_immediate_overflow_on_trigger :: proc(t: ^testing.T) {
	a: Apu
	a.power = true
	apu_write(&a, 0xFF10, 0x01) // period 0, up, shift 1
	apu_write(&a, 0xFF12, 0xF0)
	apu_write(&a, 0xFF13, 0xFF)
	apu_write(&a, 0xFF14, 0x87) // trigger: shift>0 -> immediate calc, 2047+1023>2047 overflow
	testing.expect(t, !a.ch1.enabled, "trigger-time overflow disables immediately")
}

@(test)
test_sweep_disabled_no_slide :: proc(t: ^testing.T) {
	a: Apu
	a.power = true
	apu_write(&a, 0xFF10, 0x00) // period 0, shift 0 -> sweep inert
	apu_write(&a, 0xFF12, 0xF0)
	apu_write(&a, 0xFF13, 0x00)
	apu_write(&a, 0xFF14, 0x84) // trigger, freq 1024
	clock_sweep(&a)
	testing.expect_value(t, a.ch1.freq, 1024) // unchanged
}

// --- Channel 3 (wave) ---

@(test)
test_wave_output_nibbles :: proc(t: ^testing.T) {
	a: Apu
	a.ch3.enabled = true
	a.ch3.dac_on = true
	a.ch3.wave_shift = 1 // 100%
	a.regs[0x20] = 0xAB // Wave RAM FF30: high nibble 0xA (pos 0), low 0xB (pos 1)
	a.ch3.wave_pos = 0
	testing.expect_value(t, wave_output(&a), u8(0x0A)) // high nibble first
	a.ch3.wave_pos = 1
	testing.expect_value(t, wave_output(&a), u8(0x0B)) // low nibble
}

@(test)
test_wave_volume_shift :: proc(t: ^testing.T) {
	a: Apu
	a.ch3.enabled = true
	a.ch3.dac_on = true
	a.regs[0x20] = 0xC0 // pos 0 -> sample 0xC = 12
	a.ch3.wave_pos = 0
	a.ch3.wave_shift = 0;testing.expect_value(t, wave_output(&a), u8(0)) // mute
	a.ch3.wave_shift = 1;testing.expect_value(t, wave_output(&a), u8(12)) // 100%
	a.ch3.wave_shift = 2;testing.expect_value(t, wave_output(&a), u8(6)) // 50%
	a.ch3.wave_shift = 3;testing.expect_value(t, wave_output(&a), u8(3)) // 25%
}

@(test)
test_wave_silent_when_off :: proc(t: ^testing.T) {
	a: Apu
	a.ch3.dac_on = false
	a.ch3.enabled = true
	a.regs[0x20] = 0xFF
	a.ch3.wave_shift = 1
	testing.expect_value(t, wave_output(&a), u8(0))
}

@(test)
test_wave_step_x2_and_wrap :: proc(t: ^testing.T) {
	a: Apu
	a.ch3.freq = 0 // period = (2048-0)*2 = 4096
	a.ch3.freq_timer = 4096
	a.ch3.wave_pos = 30
	wave_step(&a.ch3, 4096)
	testing.expect_value(t, a.ch3.wave_pos, u8(31))
	wave_step(&a.ch3, 4096)
	testing.expect_value(t, a.ch3.wave_pos, u8(0)) // wraps 31->0
}

@(test)
test_wave_trigger :: proc(t: ^testing.T) {
	a: Apu
	a.power = true
	apu_write(&a, 0xFF1A, 0x80) // NR30 DAC on
	apu_write(&a, 0xFF1D, 0x00) // freq low
	apu_write(&a, 0xFF1E, 0x84) // trigger, freq high -> 0x400=1024
	testing.expect(t, a.ch3.enabled, "trigger enables with DAC on")
	testing.expect_value(t, a.ch3.freq_timer, (2048 - 1024) * 2) // x2
	testing.expect_value(t, a.ch3.wave_pos, u8(0))
}

// --- Channel 4 (noise) ---

@(test)
test_noise_output_inverted :: proc(t: ^testing.T) {
	a: Apu
	a.ch4.enabled = true
	a.ch4.volume = 10
	a.ch4.lfsr = 0xFFFE // low bit 0 -> inverted = 1 -> output volume
	testing.expect_value(t, noise_output(&a.ch4), u8(10))
	a.ch4.lfsr = 0xFFFF // low bit 1 -> inverted = 0 -> silent
	testing.expect_value(t, noise_output(&a.ch4), u8(0))
}

@(test)
test_noise_lfsr_feedback :: proc(t: ^testing.T) {
	a: Apu
	a.ch4.noise_divisor = 8
	a.ch4.noise_shift = 0
	a.ch4.lfsr = 0x7FFF // all ones
	a.ch4.freq_timer = 8
	noise_step(&a.ch4, 8) // one clock
	// bits0,1 both 1 -> xor 0 -> shift right, bit14 = 0 -> 0x3FFF
	testing.expect_value(t, a.ch4.lfsr, u16(0x3FFF))
}

@(test)
test_noise_step_divisor_zero_is_noop :: proc(t: ^testing.T) {
	a: Apu
	a.ch4.noise_divisor = 0 // unconfigured
	a.ch4.freq_timer = -100
	noise_step(&a.ch4, 100) // must NOT hang
	testing.expect(t, true, "divisor 0 -> no-op, no infinite loop")
}

@(test)
test_noise_trigger :: proc(t: ^testing.T) {
	a: Apu
	a.power = true
	apu_write(&a, 0xFF21, 0xF0) // NR42 DAC on, volume 15
	apu_write(&a, 0xFF22, 0x00) // NR43 divisor code 0 -> 8, shift 0
	apu_write(&a, 0xFF23, 0x80) // NR44 trigger
	testing.expect(t, a.ch4.enabled, "trigger enables")
	testing.expect_value(t, a.ch4.lfsr, u16(0x7FFF)) // reset to all ones
	testing.expect_value(t, a.ch4.volume, u8(15))
}
