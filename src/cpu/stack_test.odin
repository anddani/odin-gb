package cpu

import "core:testing"

@(test)
test_push16_layout_and_sp :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.sp = 0xFFFE
	push16(&c, 0x1234)
	testing.expect_value(t, c.sp, u16(0xFFFC)) // grew down by 2
	testing.expect_value(t, m.data[0xFFFC], u8(0x34)) // low byte at lower address
	testing.expect_value(t, m.data[0xFFFD], u8(0x12)) // high byte next
}

@(test)
test_push_pop_roundtrip :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.sp = 0xFFFE
	push16(&c, 0xBEEF)
	val := pop16(&c)
	testing.expect_value(t, val, u16(0xBEEF))
	testing.expect_value(t, c.sp, u16(0xFFFE)) // sp restored
}

// Nested pushes pop in LIFO order.
@(test)
test_stack_lifo :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.sp = 0xFFFE
	push16(&c, 0x1111)
	push16(&c, 0x2222)
	testing.expect_value(t, pop16(&c), u16(0x2222)) // last in, first out
	testing.expect_value(t, pop16(&c), u16(0x1111))
	testing.expect_value(t, c.sp, u16(0xFFFE))
}
