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

// CALL a16=0xCD, CALL Z=0xCC.

@(test)
test_call_a16 :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.pc = 0x0100
	c.sp = 0xFFFE
	m.data[0x0100] = 0x00 // target 0x4000
	m.data[0x0101] = 0x40
	cycles := control_flow(&c, 0xCD)
	testing.expect_value(t, c.pc, u16(0x4000))
	testing.expect_value(t, c.sp, u16(0xFFFC))
	// return address pushed is 0x0102 -- past the 2-byte operand
	testing.expect_value(t, m.data[0xFFFC], u8(0x02))
	testing.expect_value(t, m.data[0xFFFD], u8(0x01))
	testing.expect_value(t, cycles, 24)
}

@(test)
test_call_cc_taken :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.flags.z = true
	c.pc = 0x0100
	c.sp = 0xFFFE
	m.data[0x0100] = 0x00
	m.data[0x0101] = 0x40
	cycles := control_flow(&c, 0xCC) // CALL Z, taken
	testing.expect_value(t, c.pc, u16(0x4000))
	testing.expect_value(t, c.sp, u16(0xFFFC))
	testing.expect_value(t, cycles, 24)
}

@(test)
test_call_cc_not_taken :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.flags.z = false
	c.pc = 0x0100
	c.sp = 0xFFFE
	m.data[0x0100] = 0x00
	m.data[0x0101] = 0x40
	cycles := control_flow(&c, 0xCC) // CALL Z, not taken
	testing.expect_value(t, c.pc, u16(0x0102)) // operand consumed, no jump
	testing.expect_value(t, c.sp, u16(0xFFFE)) // nothing pushed
	testing.expect_value(t, cycles, 12)
}

// CALL then RET must return to the instruction after the CALL.
@(test)
test_call_ret_roundtrip :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.pc = 0x0100
	c.sp = 0xFFFE
	m.data[0x0100] = 0x00
	m.data[0x0101] = 0x40
	control_flow(&c, 0xCD) // CALL 0x4000
	testing.expect_value(t, c.pc, u16(0x4000))
	control_flow(&c, 0xC9) // RET
	testing.expect_value(t, c.pc, u16(0x0102)) // back past the CALL operand
	testing.expect_value(t, c.sp, u16(0xFFFE)) // sp restored
}

// RST: 0xC7..0xFF, vector = op & 0x38.

@(test)
test_rst_pushes_and_jumps :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.pc = 0x0150
	c.sp = 0xFFFE
	cycles := control_flow(&c, 0xD7) // RST 0x10
	testing.expect_value(t, c.pc, u16(0x0010))
	testing.expect_value(t, c.sp, u16(0xFFFC))
	testing.expect_value(t, m.data[0xFFFC], u8(0x50)) // return addr low
	testing.expect_value(t, m.data[0xFFFD], u8(0x01)) // return addr high
	testing.expect_value(t, cycles, 16)
}

@(test)
test_rst_vectors :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.sp = 0xFFFE
	control_flow(&c, 0xC7) // RST 0x00
	testing.expect_value(t, c.pc, u16(0x0000))
	c.sp = 0xFFFE
	control_flow(&c, 0xFF) // RST 0x38
	testing.expect_value(t, c.pc, u16(0x0038))
}

// RET cc: RET NZ=0xC0, RET Z=0xC8.

@(test)
test_ret_cc_taken :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.flags.z = true
	c.sp = 0xFFFC
	m.data[0xFFFC] = 0x00
	m.data[0xFFFD] = 0x40
	cycles := control_flow(&c, 0xC8) // RET Z, taken
	testing.expect_value(t, c.pc, u16(0x4000))
	testing.expect_value(t, c.sp, u16(0xFFFE))
	testing.expect_value(t, cycles, 20)
}

@(test)
test_ret_cc_not_taken :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.flags.z = false
	c.pc = 0x0150
	c.sp = 0xFFFC
	m.data[0xFFFC] = 0x00
	m.data[0xFFFD] = 0x40
	cycles := control_flow(&c, 0xC8) // RET Z, Z clear -> not taken
	testing.expect_value(t, c.pc, u16(0x0150)) // no jump
	testing.expect_value(t, c.sp, u16(0xFFFC)) // nothing popped
	testing.expect_value(t, cycles, 8)
}

@(test)
test_ret_nz_taken :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.flags.z = false // NZ true
	c.sp = 0xFFFC
	m.data[0xFFFC] = 0x34
	m.data[0xFFFD] = 0x12
	cycles := control_flow(&c, 0xC0) // RET NZ, taken
	testing.expect_value(t, c.pc, u16(0x1234))
	testing.expect_value(t, cycles, 20)
}

// LDH (a8),A=0xE0, LDH A,(a8)=0xF0 -- address 0xFF00 + a8.

@(test)
test_ldh_a8_store :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.regs[.A] = 0x42
	c.pc = 0x0100
	m.data[0x0100] = 0x80 // offset -> 0xFF80
	cycles := control_flow(&c, 0xE0)
	testing.expect_value(t, m.data[0xFF80], u8(0x42))
	testing.expect_value(t, c.pc, u16(0x0101)) // immediate consumed
	testing.expect_value(t, cycles, 12)
}

@(test)
test_ldh_a8_load :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.pc = 0x0100
	m.data[0x0100] = 0x80 // offset -> 0xFF80
	m.data[0xFF80] = 0x3C
	cycles := control_flow(&c, 0xF0)
	testing.expect_value(t, c.regs[.A], u8(0x3C))
	testing.expect_value(t, cycles, 12)
}

// LDH (C),A=0xE2, LDH A,(C)=0xF2, LD (a16),A=0xEA, LD A,(a16)=0xFA.

@(test)
test_ldh_c_store :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.regs[.A] = 0x42
	c.regs[.C] = 0x80 // -> 0xFF80
	cycles := control_flow(&c, 0xE2)
	testing.expect_value(t, m.data[0xFF80], u8(0x42))
	testing.expect_value(t, cycles, 8)
}

@(test)
test_ldh_c_load :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.regs[.C] = 0x80
	m.data[0xFF80] = 0x3C
	cycles := control_flow(&c, 0xF2)
	testing.expect_value(t, c.regs[.A], u8(0x3C))
	testing.expect_value(t, cycles, 8)
}

@(test)
test_ld_a16_store :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.regs[.A] = 0x99
	c.pc = 0x0100
	m.data[0x0100] = 0x00 // addr 0xC000, little-endian
	m.data[0x0101] = 0xC0
	cycles := control_flow(&c, 0xEA)
	testing.expect_value(t, m.data[0xC000], u8(0x99))
	testing.expect_value(t, c.pc, u16(0x0102)) // 16-bit operand consumed
	testing.expect_value(t, cycles, 16)
}

@(test)
test_ld_a16_load :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.pc = 0x0100
	m.data[0x0100] = 0x00 // addr 0xC000
	m.data[0x0101] = 0xC0
	m.data[0xC000] = 0x55
	cycles := control_flow(&c, 0xFA)
	testing.expect_value(t, c.regs[.A], u8(0x55))
	testing.expect_value(t, cycles, 16)
}

// ADD SP,r8 = 0xE8. Z=0, N=0; H/C from an unsigned 8-bit add of SP's low byte.

@(test)
test_add_sp_r8_positive :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.sp = 0x0005
	c.pc = 0x0100
	m.data[0x0100] = 0x03
	cycles := control_flow(&c, 0xE8)
	testing.expect_value(t, c.sp, u16(0x0008))
	testing.expect(t, !c.flags.z && !c.flags.n && !c.flags.h && !c.flags.c, "no flags")
	testing.expect_value(t, cycles, 16)
}

// Negative offset decreases SP, but H/C come from the unsigned byte add.
@(test)
test_add_sp_r8_negative :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.sp = 0x0005
	c.pc = 0x0100
	m.data[0x0100] = 0xFF // -1
	control_flow(&c, 0xE8)
	testing.expect_value(t, c.sp, u16(0x0004)) // SP decreases
	testing.expect(t, c.flags.h && c.flags.c, "H,C from 0x05 + 0xFF low-byte add")
}

@(test)
test_add_sp_r8_half_carry_only :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.sp = 0x000F
	c.pc = 0x0100
	m.data[0x0100] = 0x01
	control_flow(&c, 0xE8)
	testing.expect_value(t, c.sp, u16(0x0010))
	testing.expect(t, c.flags.h && !c.flags.c, "H set, no C")
}

// Result can be 0, but Z is never set.
@(test)
test_add_sp_r8_z_always_zero :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.sp = 0x0001
	c.pc = 0x0100
	m.data[0x0100] = 0xFF // -1 -> result 0x0000
	control_flow(&c, 0xE8)
	testing.expect_value(t, c.sp, u16(0x0000))
	testing.expect(t, !c.flags.z, "ADD SP,r8 never sets Z")
}

// LD HL,SP+r8 = 0xF8. Same math as ADD SP,r8 but result -> HL, SP unchanged.

@(test)
test_ld_hl_sp_r8 :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.sp = 0x0005
	c.pc = 0x0100
	m.data[0x0100] = 0x03
	cycles := control_flow(&c, 0xF8)
	testing.expect_value(t, get_hl(&c), u16(0x0008)) // result in HL
	testing.expect_value(t, c.sp, u16(0x0005)) // SP unchanged
	testing.expect_value(t, cycles, 12)
}

@(test)
test_ld_hl_sp_r8_negative :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.sp = 0x0005
	c.pc = 0x0100
	m.data[0x0100] = 0xFF // -1
	control_flow(&c, 0xF8)
	testing.expect_value(t, get_hl(&c), u16(0x0004))
	testing.expect_value(t, c.sp, u16(0x0005)) // SP still unchanged
	testing.expect(t, c.flags.h && c.flags.c, "H,C from unsigned low-byte add")
}

// DI=0xF3 (immediate), EI=0xFB (delayed via ime_pending).

@(test)
test_di_disables_ime :: proc(t: ^testing.T) {
	c: Cpu
	c.ime = true
	cycles := control_flow(&c, 0xF3) // DI
	testing.expect(t, !c.ime, "DI clears IME immediately")
	testing.expect_value(t, cycles, 4)
}

@(test)
test_ei_schedules_but_not_immediate :: proc(t: ^testing.T) {
	c: Cpu
	c.ime = false
	cycles := control_flow(&c, 0xFB) // EI
	testing.expect(t, !c.ime, "EI does NOT enable IME immediately")
	testing.expect(t, c.ime_pending, "EI schedules the IME enable")
	testing.expect_value(t, cycles, 4)
}
