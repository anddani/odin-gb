package cpu

import "core:testing"

// ALU op-code selectors (bits 5-3 of an ALU opcode).
ALU_ADD :: 0
ALU_ADC :: 1
ALU_SUB :: 2
ALU_SBC :: 3
ALU_AND :: 4
ALU_XOR :: 5
ALU_OR :: 6
ALU_CP :: 7

// Build an ALU opcode (op_code in bits 5-3, src reg in bits 2-0) and run it.
@(private = "file")
run_alu :: proc(c: ^Cpu, code, src: u8) -> int {
	return alu(c, (code << 3) | src)
}

// Reuses Test_Mem / make_test_cpu from cpu_test.odin (same package).
// Most tests use src=0 (register B) so the operand is independent of A.

@(test)
test_alu_add_plain :: proc(t: ^testing.T) {
	c: Cpu
	c.regs[.A] = 0x3A
	c.regs[.B] = 0x05
	run_alu(&c, ALU_ADD, 0)
	testing.expect_value(t, c.regs[.A], u8(0x3F))
	testing.expect(t, !c.flags.z && !c.flags.n && !c.flags.h && !c.flags.c, "0x3A+0x05: no flags")
}

@(test)
test_alu_add_half_carry :: proc(t: ^testing.T) {
	c: Cpu
	c.regs[.A] = 0x0F
	c.regs[.B] = 0x01
	run_alu(&c, ALU_ADD, 0)
	testing.expect_value(t, c.regs[.A], u8(0x10))
	testing.expect(t, c.flags.h, "nibble 0xF+1 sets H")
	testing.expect(t, !c.flags.c, "no full carry")
}

@(test)
test_alu_add_full_carry_and_zero :: proc(t: ^testing.T) {
	c: Cpu
	c.regs[.A] = 0xFF
	c.regs[.B] = 0x01
	run_alu(&c, ALU_ADD, 0)
	testing.expect_value(t, c.regs[.A], u8(0x00)) // wraps
	testing.expect(t, c.flags.c && c.flags.h && c.flags.z, "0xFF+1: C, H, Z all set")
}

// The carry-in alone can produce a half-carry.
@(test)
test_alu_adc_carry_causes_half_carry :: proc(t: ^testing.T) {
	c: Cpu
	c.flags.c = true
	c.regs[.A] = 0x0F
	c.regs[.B] = 0x00
	run_alu(&c, ALU_ADC, 0)
	testing.expect_value(t, c.regs[.A], u8(0x10))
	testing.expect(t, c.flags.h, "0xF + 0 + carry sets H")
	testing.expect(t, !c.flags.c, "no full carry")
}

@(test)
test_alu_sub_half_borrow :: proc(t: ^testing.T) {
	c: Cpu
	c.regs[.A] = 0x10
	c.regs[.B] = 0x01
	run_alu(&c, ALU_SUB, 0)
	testing.expect_value(t, c.regs[.A], u8(0x0F))
	testing.expect(t, c.flags.n, "SUB sets N")
	testing.expect(t, c.flags.h, "nibble 0x0 < 0x1 borrows -> H")
	testing.expect(t, !c.flags.c, "no full borrow")
}

@(test)
test_alu_sub_underflow :: proc(t: ^testing.T) {
	c: Cpu
	c.regs[.A] = 0x00
	c.regs[.B] = 0x01
	run_alu(&c, ALU_SUB, 0)
	testing.expect_value(t, c.regs[.A], u8(0xFF)) // wraps
	testing.expect(t, c.flags.c && c.flags.h && c.flags.n, "0-1: C, H, N set")
}

// SBC where operand + carry would wrap a u8 -- the widening guard.
@(test)
test_alu_sbc_operand_plus_carry_wrap :: proc(t: ^testing.T) {
	c: Cpu
	c.flags.c = true
	c.regs[.A] = 0x00
	c.regs[.B] = 0xFF
	run_alu(&c, ALU_SBC, 0)
	testing.expect_value(t, c.regs[.A], u8(0x00)) // 0 - 0xFF - 1 = 0 (mod 256)
	testing.expect(t, c.flags.c, "0 < 0xFF+1 -> carry set (not lost to wrap)")
	testing.expect(t, c.flags.z, "result is zero")
}

@(test)
test_alu_and_sets_h :: proc(t: ^testing.T) {
	c: Cpu
	c.regs[.A] = 0xF0
	c.regs[.B] = 0x0F
	run_alu(&c, ALU_AND, 0)
	testing.expect_value(t, c.regs[.A], u8(0x00))
	testing.expect(t, c.flags.z && c.flags.h, "AND: Z and H set")
	testing.expect(t, !c.flags.n && !c.flags.c, "AND: N,C clear")
}

@(test)
test_alu_xor_clears_h :: proc(t: ^testing.T) {
	c: Cpu
	c.flags.h = true // must be cleared by XOR
	c.regs[.A] = 0xFF
	c.regs[.B] = 0x0F
	run_alu(&c, ALU_XOR, 0)
	testing.expect_value(t, c.regs[.A], u8(0xF0))
	testing.expect(t, !c.flags.h && !c.flags.n && !c.flags.c, "XOR clears H,N,C")
}

@(test)
test_alu_or_clears_h :: proc(t: ^testing.T) {
	c: Cpu
	c.flags.h = true // must be cleared by OR
	c.regs[.A] = 0xF0
	c.regs[.B] = 0x0F
	run_alu(&c, ALU_OR, 0)
	testing.expect_value(t, c.regs[.A], u8(0xFF))
	testing.expect(t, !c.flags.h && !c.flags.n && !c.flags.c, "OR clears H,N,C")
}

// CP sets flags like SUB but must NOT modify A.
@(test)
test_alu_cp_does_not_store :: proc(t: ^testing.T) {
	c: Cpu
	c.regs[.A] = 0x42
	c.regs[.B] = 0x42
	run_alu(&c, ALU_CP, 0)
	testing.expect_value(t, c.regs[.A], u8(0x42)) // unchanged
	testing.expect(t, c.flags.z && c.flags.n, "equal compare: Z and N set")

	c.regs[.A] = 0x42
	c.regs[.B] = 0x40
	run_alu(&c, ALU_CP, 0)
	testing.expect_value(t, c.regs[.A], u8(0x42)) // still unchanged
	testing.expect(t, !c.flags.z, "0x42 != 0x40: Z clear")
}

// Operand from (HL) via src=6: reads memory and costs 8 cycles.
@(test)
test_alu_hl_operand_and_cycles :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.regs[.A] = 0x20
	set_hl(&c, 0xC000)
	m.data[0xC000] = 0x22

	cycles := run_alu(&c, ALU_ADD, 6)
	testing.expect_value(t, c.regs[.A], u8(0x42))
	testing.expect_value(t, cycles, 8)
}

@(test)
test_alu_register_operand_cycles :: proc(t: ^testing.T) {
	c: Cpu
	cycles := run_alu(&c, ALU_ADD, 0)
	testing.expect_value(t, cycles, 4)
}
