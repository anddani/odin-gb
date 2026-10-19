package cpu

import "core:testing"

// cb() fetches the CB opcode byte from pc, so place it in memory at pc.
// CB opcodes used: RLC B=0x00, RL B=0x10, SRA B=0x28, SWAP A=0x37, SRL B=0x38,
// RLC (HL)=0x06.

@(private = "file")
run_cb :: proc(c: ^Cpu, m: ^Test_Mem, cb_op: u8) -> int {
	c.pc = 0x0100
	m.data[0x0100] = cb_op
	return cb(c)
}

@(test)
test_cb_rlc_circular :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.regs[.B] = 0x85 // 1000_0101
	cycles := run_cb(&c, &m, 0x00) // RLC B
	testing.expect_value(t, c.regs[.B], u8(0x0B)) // bit7 wraps to bit0
	testing.expect(t, c.flags.c && !c.flags.z, "C=old bit7, not zero")
	testing.expect_value(t, cycles, 8)
}

// Unlike RLCA, the CB rotates set Z from the result.
@(test)
test_cb_rlc_sets_z_from_result :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.regs[.B] = 0x00
	run_cb(&c, &m, 0x00) // RLC B
	testing.expect(t, c.flags.z, "CB RLC sets Z when result is 0")
}

@(test)
test_cb_rl_through_carry :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.regs[.B] = 0x80
	c.flags.c = false
	run_cb(&c, &m, 0x10) // RL B
	testing.expect_value(t, c.regs[.B], u8(0x00)) // bit7 out, old carry (0) in
	testing.expect(t, c.flags.c && c.flags.z, "C=old bit7, Z (result 0)")

	c.regs[.B] = 0x01
	c.flags.c = true
	run_cb(&c, &m, 0x10) // RL B
	testing.expect_value(t, c.regs[.B], u8(0x03)) // old carry fills bit0
	testing.expect(t, !c.flags.c, "C = old bit7 (0)")
}

@(test)
test_cb_sra_preserves_sign :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.regs[.B] = 0x81 // 1000_0001
	run_cb(&c, &m, 0x28) // SRA B
	testing.expect_value(t, c.regs[.B], u8(0xC0)) // bit7 preserved
	testing.expect(t, c.flags.c, "C = old bit0")
}

@(test)
test_cb_srl_zeroes_bit7 :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.regs[.B] = 0x81
	run_cb(&c, &m, 0x38) // SRL B
	testing.expect_value(t, c.regs[.B], u8(0x40)) // bit7 = 0 (no sign)
	testing.expect(t, c.flags.c, "C = old bit0")
}

@(test)
test_cb_swap :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.regs[.A] = 0xAB
	run_cb(&c, &m, 0x37) // SWAP A
	testing.expect_value(t, c.regs[.A], u8(0xBA)) // nibbles swapped
	testing.expect(t, !c.flags.c, "SWAP clears C")
}

// (HL) operand reads+writes memory and costs 16 cycles.
@(test)
test_cb_hl_operand_and_cycles :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	set_hl(&c, 0xC000)
	m.data[0xC000] = 0x85
	cycles := run_cb(&c, &m, 0x06) // RLC (HL)
	testing.expect_value(t, m.data[0xC000], u8(0x0B))
	testing.expect_value(t, cycles, 16)
}

// BIT 7,B=0x78; RES 0,B=0x80; SET 0,B=0xC0; BIT 0,(HL)=0x46.

@(test)
test_cb_bit_set_z_when_bit_clear :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.regs[.B] = 0x00 // bit 7 is 0
	c.flags.c = true // must be preserved
	run_cb(&c, &m, 0x78) // BIT 7,B
	testing.expect(t, c.flags.z, "Z set when tested bit is 0")
	testing.expect(t, !c.flags.n && c.flags.h, "N=0, H=1")
	testing.expect(t, c.flags.c, "BIT preserves C")
}

@(test)
test_cb_bit_clear_z_when_bit_set :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.regs[.B] = 0x80 // bit 7 is 1
	run_cb(&c, &m, 0x78) // BIT 7,B
	testing.expect(t, !c.flags.z, "Z clear when tested bit is 1")
	testing.expect_value(t, c.regs[.B], u8(0x80)) // BIT does not modify the register
}

@(test)
test_cb_res_clears_bit :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.regs[.B] = 0xFF
	run_cb(&c, &m, 0x80) // RES 0,B
	testing.expect_value(t, c.regs[.B], u8(0xFE))
}

@(test)
test_cb_set_sets_bit :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.regs[.B] = 0x00
	run_cb(&c, &m, 0xC0) // SET 0,B
	testing.expect_value(t, c.regs[.B], u8(0x01))
}

// BIT b,(HL) reads memory but does not write, and costs 12 cycles.
@(test)
test_cb_bit_hl_is_12_cycles :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	set_hl(&c, 0xC000)
	m.data[0xC000] = 0x01 // bit 0 set
	cycles := run_cb(&c, &m, 0x46) // BIT 0,(HL)
	testing.expect(t, !c.flags.z, "bit 0 is set -> Z clear")
	testing.expect_value(t, m.data[0xC000], u8(0x01)) // unchanged
	testing.expect_value(t, cycles, 12)
}
