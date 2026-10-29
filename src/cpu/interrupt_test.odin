package cpu

import "core:testing"

// Reuses Test_Mem / make_test_cpu from cpu_test.odin.

// With IME on and a source enabled+requested, step services it: push PC, jump
// to the vector, clear IME and the IF bit, 20 cycles, no instruction executed.
@(test)
test_interrupt_serviced :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.ime = true
	c.pc = 0x0150
	c.sp = 0xFFFE
	m.data[0xFFFF] = 0x04 // IE: Timer (bit 2)
	m.data[0xFF0F] = 0x04 // IF: Timer requested

	cycles := step(&c)

	testing.expect_value(t, c.pc, u16(0x0050)) // Timer vector
	testing.expect_value(t, cycles, 20)
	testing.expect(t, !c.ime, "IME cleared on service")
	testing.expect_value(t, m.data[0xFF0F], u8(0x00)) // IF bit cleared
	testing.expect_value(t, c.sp, u16(0xFFFC))
	testing.expect_value(t, m.data[0xFFFC], u8(0x50)) // return addr low
	testing.expect_value(t, m.data[0xFFFD], u8(0x01)) // return addr high
}

// Lowest bit wins: VBlank (bit 0) serviced before Timer (bit 2).
@(test)
test_interrupt_priority :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.ime = true
	c.pc = 0x0150
	c.sp = 0xFFFE
	m.data[0xFFFF] = 0x1F // all enabled
	m.data[0xFF0F] = 0x05 // VBlank + Timer requested

	step(&c)

	testing.expect_value(t, c.pc, u16(0x0040)) // VBlank vector
	testing.expect_value(t, m.data[0xFF0F], u8(0x04)) // only VBlank cleared; Timer still pending
}

// IME off: no service, the instruction runs normally.
@(test)
test_interrupt_ignored_when_ime_off :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.ime = false
	c.pc = 0x0150
	m.data[0xFFFF] = 0x04
	m.data[0xFF0F] = 0x04
	m.data[0x0150] = 0x00 // NOP

	cycles := step(&c)

	testing.expect_value(t, c.pc, u16(0x0151)) // NOP executed, no service
	testing.expect_value(t, cycles, 4)
}

// EI enables IME only after the following instruction.
@(test)
test_ei_delay :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.pc = 0x0150
	c.ime = false
	m.data[0x0150] = 0xFB // EI
	m.data[0x0151] = 0x00 // NOP

	step(&c) // EI
	testing.expect(t, !c.ime && c.ime_pending, "EI schedules but does not enable yet")

	step(&c) // NOP
	testing.expect(t, c.ime, "IME enabled after the instruction following EI")
}

// HALT stays halted with nothing pending, wakes when a source becomes pending.
@(test)
test_halt_wake :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.halt = true
	c.ime = false
	c.pc = 0x0150

	cycles := step(&c)
	testing.expect(t, c.halt, "stays halted with no pending interrupt")
	testing.expect_value(t, cycles, 4)

	m.data[0xFFFF] = 0x04
	m.data[0xFF0F] = 0x04
	step(&c)
	testing.expect(t, !c.halt, "wakes when an interrupt is pending")
}
