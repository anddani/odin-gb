package cpu

import "core:testing"

// Immediate ALU: ADD A,d8=0xC6, SUB A,d8=0xD6, AND A,d8=0xE6, CP A,d8=0xFE.
// Flag math is covered by the alu_apply tests; here we check operand source
// (fetch8 from pc), pc advance, the flat 8 cycles, and op_code decoding.

@(test)
test_imm_alu_add_fetches_operand :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.regs[.A] = 0x14
	c.pc = 0x0100
	m.data[0x0100] = 0x22 // immediate operand
	cycles := control_flow(&c, 0xC6) // ADD A,d8
	testing.expect_value(t, c.regs[.A], u8(0x36))
	testing.expect_value(t, c.pc, u16(0x0101)) // immediate consumed
	testing.expect_value(t, cycles, 8)
}

@(test)
test_imm_alu_sub :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.regs[.A] = 0x20
	c.pc = 0x0200
	m.data[0x0200] = 0x01
	cycles := control_flow(&c, 0xD6) // SUB A,d8
	testing.expect_value(t, c.regs[.A], u8(0x1F))
	testing.expect(t, c.flags.n && c.flags.h, "SUB: N set, H borrow")
	testing.expect_value(t, cycles, 8)
}

// CP A,d8 sets flags but must not modify A.
@(test)
test_imm_alu_cp_does_not_store :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.regs[.A] = 0x42
	c.pc = 0x0100
	m.data[0x0100] = 0x42
	control_flow(&c, 0xFE) // CP A,d8
	testing.expect_value(t, c.regs[.A], u8(0x42)) // unchanged
	testing.expect(t, c.flags.z && c.flags.n, "CP equal: Z,N set")
}

// 0xE6 must decode to op_code 4 (AND) -- guards the (op>>3)&7 extraction for
// the high immediate opcodes.
@(test)
test_imm_alu_decodes_high_opcode :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.regs[.A] = 0xF0
	c.pc = 0x0100
	m.data[0x0100] = 0x0F
	control_flow(&c, 0xE6) // AND A,d8
	testing.expect_value(t, c.regs[.A], u8(0x00))
	testing.expect(t, c.flags.z && c.flags.h, "AND: Z set, H=1")
}

// PUSH/POP: PUSH BC=0xC5 (16cyc), POP DE=0xD1 (12cyc), POP AF=0xF1.

@(test)
test_push_bc :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	set_bc(&c, 0x1234)
	c.sp = 0xFFFE
	cycles := control_flow(&c, 0xC5) // PUSH BC
	testing.expect_value(t, c.sp, u16(0xFFFC))
	testing.expect_value(t, m.data[0xFFFC], u8(0x34)) // low byte
	testing.expect_value(t, m.data[0xFFFD], u8(0x12)) // high byte
	testing.expect_value(t, cycles, 16)
}

@(test)
test_pop_de :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	m.data[0xFFFC] = 0x34
	m.data[0xFFFD] = 0x12
	c.sp = 0xFFFC
	cycles := control_flow(&c, 0xD1) // POP DE
	testing.expect_value(t, get_de(&c), u16(0x1234))
	testing.expect_value(t, c.sp, u16(0xFFFE))
	testing.expect_value(t, cycles, 12)
}

// POP AF must mask F's low nibble to 0 (via set_af).
@(test)
test_pop_af_masks_low_nibble :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	m.data[0xFFFC] = 0x5F // F byte with low nibble set
	m.data[0xFFFD] = 0xAB // A
	c.sp = 0xFFFC
	control_flow(&c, 0xF1) // POP AF
	testing.expect_value(t, get_af(&c), u16(0xAB50)) // low nibble dropped
}

// RET=0xC9, RETI=0xD9, JP HL=0xE9, LD SP,HL=0xF9.

@(test)
test_ret :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	m.data[0xFFFC] = 0x34
	m.data[0xFFFD] = 0x12
	c.sp = 0xFFFC
	cycles := control_flow(&c, 0xC9) // RET
	testing.expect_value(t, c.pc, u16(0x1234))
	testing.expect_value(t, c.sp, u16(0xFFFE))
	testing.expect_value(t, cycles, 16)
}

@(test)
test_reti_enables_ime :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	m.data[0xFFFC] = 0x00
	m.data[0xFFFD] = 0x40
	c.sp = 0xFFFC
	c.ime = false
	cycles := control_flow(&c, 0xD9) // RETI
	testing.expect_value(t, c.pc, u16(0x4000))
	testing.expect(t, c.ime, "RETI enables IME")
	testing.expect_value(t, cycles, 16)
}

@(test)
test_jp_hl :: proc(t: ^testing.T) {
	c: Cpu
	set_hl(&c, 0x4000)
	cycles := control_flow(&c, 0xE9) // JP HL
	testing.expect_value(t, c.pc, u16(0x4000)) // address IN HL, not mem[HL]
	testing.expect_value(t, cycles, 4)
}

@(test)
test_ld_sp_hl :: proc(t: ^testing.T) {
	c: Cpu
	set_hl(&c, 0xC000)
	cycles := control_flow(&c, 0xF9) // LD SP,HL
	testing.expect_value(t, c.sp, u16(0xC000))
	testing.expect_value(t, cycles, 8)
}

// JP a16=0xC3, JP NZ=0xC2, JP Z=0xCA.

@(test)
test_jp_a16 :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.pc = 0x0100
	m.data[0x0100] = 0x00 // target 0x4000, little-endian
	m.data[0x0101] = 0x40
	cycles := control_flow(&c, 0xC3)
	testing.expect_value(t, c.pc, u16(0x4000))
	testing.expect_value(t, cycles, 16)
}

@(test)
test_jp_cc_taken :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.flags.z = true
	c.pc = 0x0100
	m.data[0x0100] = 0x00
	m.data[0x0101] = 0x40
	cycles := control_flow(&c, 0xCA) // JP Z, taken
	testing.expect_value(t, c.pc, u16(0x4000))
	testing.expect_value(t, cycles, 16)
}

// Not taken: the 16-bit operand is still consumed (pc advances by 2), no jump.
@(test)
test_jp_cc_not_taken_consumes_operand :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.flags.z = false
	c.pc = 0x0100
	m.data[0x0100] = 0x00
	m.data[0x0101] = 0x40
	cycles := control_flow(&c, 0xCA) // JP Z, Z clear -> not taken
	testing.expect_value(t, c.pc, u16(0x0102)) // operand consumed, no jump
	testing.expect_value(t, cycles, 12)
}

@(test)
test_jp_nz_taken :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.flags.z = false // NZ condition true
	c.pc = 0x0200
	m.data[0x0200] = 0x34
	m.data[0x0201] = 0x12
	cycles := control_flow(&c, 0xC2) // JP NZ, taken
	testing.expect_value(t, c.pc, u16(0x1234))
	testing.expect_value(t, cycles, 16)
}
