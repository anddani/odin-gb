package cpu

import "core:testing"

// Reuses Test_Mem / make_test_cpu from cpu_test.odin (same package).

@(test)
test_read_reg_plain_register :: proc(t: ^testing.T) {
	c: Cpu
	c.regs[.B] = 0x5A
	testing.expect_value(t, read_reg(&c, 0), u8(0x5A)) // code 0 = B
	c.regs[.A] = 0x3C
	testing.expect_value(t, read_reg(&c, 7), u8(0x3C)) // code 7 = A
}

@(test)
test_write_reg_plain_register :: proc(t: ^testing.T) {
	c: Cpu
	write_reg(&c, 2, 0x7C) // code 2 = D
	testing.expect_value(t, c.regs[.D], u8(0x7C))
}

// Code 6 must read the byte at (HL) from the bus, not the register array.
@(test)
test_read_reg_code6_reads_memory :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	set_hl(&c, 0xC123)
	m.data[0xC123] = 0x99
	testing.expect_value(t, read_reg(&c, 6), u8(0x99))
}

// Code 6 must write memory at (HL) and NOT touch the dead _HL slot -- this is
// the fall-through bug guard.
@(test)
test_write_reg_code6_writes_memory_only :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	set_hl(&c, 0xC123)
	c.regs[._HL] = 0x11 // sentinel in the placeholder slot

	write_reg(&c, 6, 0x42)

	testing.expect_value(t, m.data[0xC123], u8(0x42)) // memory updated
	testing.expect_value(t, c.regs[._HL], u8(0x11)) // dead slot untouched
}
