package timer

import "core:testing"

@(test)
test_div_increments_every_256 :: proc(t: ^testing.T) {
	tm: Timer
	timer_step(&tm, 255)
	testing.expect_value(t, tm.div, u8(0)) // not yet
	timer_step(&tm, 1)
	testing.expect_value(t, tm.div, u8(1)) // crossed 256
}

@(test)
test_div_wraps :: proc(t: ^testing.T) {
	tm: Timer
	tm.div = 0xFF
	timer_step(&tm, 256)
	testing.expect_value(t, tm.div, u8(0x00))
}

@(test)
test_tima_disabled_does_not_count :: proc(t: ^testing.T) {
	tm: Timer
	tm.tac = 0x00 // enable bit clear
	timer_step(&tm, 10000)
	testing.expect_value(t, tm.tima, u8(0))
}

@(test)
test_tima_period_and_multi_increment :: proc(t: ^testing.T) {
	tm: Timer
	tm.tac = 0x05 // enable + select 1 -> period 16
	timer_step(&tm, 16)
	testing.expect_value(t, tm.tima, u8(1))
	timer_step(&tm, 48) // three more periods in one step
	testing.expect_value(t, tm.tima, u8(4))
}

@(test)
test_tima_overflow_reloads_tma_and_signals :: proc(t: ^testing.T) {
	tm: Timer
	tm.tac = 0x04 // enable + select 0 -> period 1024
	tm.tima = 0xFF
	tm.tma = 0x30
	ov := timer_step(&tm, 1024)
	testing.expect(t, ov, "overflow returns true")
	testing.expect_value(t, tm.tima, u8(0x30)) // reloaded from TMA, not 0
}

@(test)
test_tima_no_overflow_returns_false :: proc(t: ^testing.T) {
	tm: Timer
	tm.tac = 0x04
	ov := timer_step(&tm, 1024)
	testing.expect(t, !ov, "no overflow")
	testing.expect_value(t, tm.tima, u8(1))
}
