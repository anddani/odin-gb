package timer

import "core:testing"

// DIV is the upper 8 bits of the internal counter.
@(test)
test_div_increments_every_256 :: proc(t: ^testing.T) {
	tm: Timer
	timer_step(&tm, 255)
	testing.expect_value(t, timer_read(&tm, 0xFF04), u8(0)) // not yet
	timer_step(&tm, 1)
	testing.expect_value(t, timer_read(&tm, 0xFF04), u8(1)) // crossed 256
}

// Writing DIV resets the whole internal counter (DIV and TIMA phase).
@(test)
test_div_write_resets_counter :: proc(t: ^testing.T) {
	tm: Timer
	timer_step(&tm, 1000)
	timer_write(&tm, 0xFF04, 0xAB) // value ignored; counter -> 0
	testing.expect_value(t, timer_read(&tm, 0xFF04), u8(0))
}

@(test)
test_tima_disabled_does_not_count :: proc(t: ^testing.T) {
	tm: Timer
	tm.tac = 0x00
	timer_step(&tm, 10000)
	testing.expect_value(t, tm.tima, u8(0))
}

@(test)
test_tima_period_and_multi_increment :: proc(t: ^testing.T) {
	tm: Timer
	tm.tac = 0x05 // enable + select 1 -> period 16
	timer_step(&tm, 16)
	testing.expect_value(t, tm.tima, u8(1))
	timer_step(&tm, 48) // three more periods
	testing.expect_value(t, tm.tima, u8(4))
}

@(test)
test_tima_overflow_reloads_tma_and_signals :: proc(t: ^testing.T) {
	tm: Timer
	tm.tac = 0x04 // enable, period 1024
	tm.tima = 0xFF
	tm.tma = 0x30
	ov := timer_step(&tm, 1024)
	testing.expect(t, ov, "overflow returns true")
	testing.expect_value(t, tm.tima, u8(0x30)) // reloaded from TMA
}

@(test)
test_tima_no_overflow_returns_false :: proc(t: ^testing.T) {
	tm: Timer
	tm.tac = 0x04
	ov := timer_step(&tm, 1024)
	testing.expect(t, !ov, "no overflow")
	testing.expect_value(t, tm.tima, u8(1))
}

// TIMA must not lose a tick when the internal counter wraps past 0xFFFF.
@(test)
test_tima_counter_wrap :: proc(t: ^testing.T) {
	tm: Timer
	tm.tac = 0x06 // enable, period 64
	// advance near the wrap boundary without crossing a tick we care about
	tm.counter = 0xFFF0
	before := tm.tima
	timer_step(&tm, 0x20) // 0xFFF0 + 0x20 = 0x10010, wraps; crosses a 64-boundary
	testing.expect(t, tm.tima == before + 1, "tick not lost across u16 wrap")
}
