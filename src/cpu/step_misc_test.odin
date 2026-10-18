package cpu

import "core:testing"

// Opcodes: INC B = 0x04, INC (HL) = 0x34; DEC B = 0x05, DEC (HL) = 0x35.
// Reuses Test_Mem / make_test_cpu from cpu_test.odin (same package).

@(test)
test_inc_half_carry :: proc(t: ^testing.T) {
	c: Cpu
	c.regs[.B] = 0x0F
	cycles := misc(&c, 0x04)
	testing.expect_value(t, c.regs[.B], u8(0x10))
	testing.expect(t, c.flags.h && !c.flags.z && !c.flags.n, "INC 0x0F: H set, Z/N clear")
	testing.expect_value(t, cycles, 4)
}

@(test)
test_inc_wrap_to_zero :: proc(t: ^testing.T) {
	c: Cpu
	c.regs[.B] = 0xFF
	misc(&c, 0x04)
	testing.expect_value(t, c.regs[.B], u8(0x00))
	testing.expect(t, c.flags.z && c.flags.h, "INC 0xFF: Z and H set")
}

@(test)
test_inc_preserves_carry :: proc(t: ^testing.T) {
	c: Cpu
	c.flags.c = true
	c.regs[.B] = 0x01
	misc(&c, 0x04)
	testing.expect_value(t, c.regs[.B], u8(0x02))
	testing.expect(t, c.flags.c, "INC must preserve C")
	testing.expect(t, !c.flags.h, "0x01 INC: no half carry")
}

@(test)
test_inc_hl_memory_and_cycles :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	set_hl(&c, 0xC000)
	m.data[0xC000] = 0x0F
	cycles := misc(&c, 0x34) // INC (HL)
	testing.expect_value(t, m.data[0xC000], u8(0x10))
	testing.expect(t, c.flags.h, "INC (HL) 0x0F: H set")
	testing.expect_value(t, cycles, 12)
}

@(test)
test_dec_half_borrow :: proc(t: ^testing.T) {
	c: Cpu
	c.regs[.B] = 0x10
	cycles := misc(&c, 0x05)
	testing.expect_value(t, c.regs[.B], u8(0x0F))
	testing.expect(t, c.flags.n && c.flags.h && !c.flags.z, "DEC 0x10: N,H set, not zero")
	testing.expect_value(t, cycles, 4)
}

@(test)
test_dec_to_zero :: proc(t: ^testing.T) {
	c: Cpu
	c.regs[.B] = 0x01
	misc(&c, 0x05)
	testing.expect_value(t, c.regs[.B], u8(0x00))
	testing.expect(t, c.flags.z && c.flags.n && !c.flags.h, "DEC to 0: Z,N set, H clear")
}

@(test)
test_dec_wrap :: proc(t: ^testing.T) {
	c: Cpu
	c.regs[.B] = 0x00
	misc(&c, 0x05)
	testing.expect_value(t, c.regs[.B], u8(0xFF))
	testing.expect(t, c.flags.h && !c.flags.z, "DEC 0x00: H set (borrow), not zero")
}

@(test)
test_dec_preserves_carry :: proc(t: ^testing.T) {
	c: Cpu
	c.flags.c = true
	c.regs[.B] = 0x05
	misc(&c, 0x05)
	testing.expect(t, c.flags.c, "DEC must preserve C")
}

@(test)
test_dec_hl_memory_and_cycles :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	set_hl(&c, 0xC000)
	m.data[0xC000] = 0x01
	cycles := misc(&c, 0x35) // DEC (HL)
	testing.expect_value(t, m.data[0xC000], u8(0x00))
	testing.expect(t, c.flags.z && c.flags.n, "DEC (HL) to 0: Z,N set")
	testing.expect_value(t, cycles, 12)
}

// ADD HL,rr -- opcodes 0x09/0x19/0x29/0x39 (BC/DE/HL/SP).

// Reads the correct pair (DE, not BC) -- guards the get_rp operand.
@(test)
test_add_hl_reads_correct_pair :: proc(t: ^testing.T) {
	c: Cpu
	set_hl(&c, 0x0001)
	set_de(&c, 0x0002)
	cycles := misc(&c, 0x19) // ADD HL,DE
	testing.expect_value(t, get_hl(&c), u16(0x0003))
	testing.expect_value(t, cycles, 8)
}

@(test)
test_add_hl_half_carry_bit11 :: proc(t: ^testing.T) {
	c: Cpu
	set_hl(&c, 0x0FFF)
	set_bc(&c, 0x0001)
	misc(&c, 0x09) // ADD HL,BC
	testing.expect_value(t, get_hl(&c), u16(0x1000))
	testing.expect(t, c.flags.h && !c.flags.c && !c.flags.n, "bit-11 carry sets H only")
}

@(test)
test_add_hl_carry_bit15 :: proc(t: ^testing.T) {
	c: Cpu
	set_hl(&c, 0xFFFF)
	set_bc(&c, 0x0001)
	misc(&c, 0x09)
	testing.expect_value(t, get_hl(&c), u16(0x0000)) // wraps
	testing.expect(t, c.flags.c && c.flags.h, "bit-15 overflow: C and H set")
}

// Z must be preserved: a result of 0x0000 must NOT set Z.
@(test)
test_add_hl_preserves_z :: proc(t: ^testing.T) {
	c: Cpu
	c.flags.z = false
	set_hl(&c, 0xFFFF)
	set_bc(&c, 0x0001) // result 0x0000
	misc(&c, 0x09)
	testing.expect(t, !c.flags.z, "ADD HL,rr must not touch Z even when result is 0")

	c.flags.z = true
	set_hl(&c, 0x0001)
	set_bc(&c, 0x0001)
	misc(&c, 0x09)
	testing.expect(t, c.flags.z, "ADD HL,rr must leave a set Z alone")
}

@(test)
test_add_hl_sp_and_self :: proc(t: ^testing.T) {
	c: Cpu
	set_hl(&c, 0x0010)
	c.sp = 0x0020
	misc(&c, 0x39) // ADD HL,SP
	testing.expect_value(t, get_hl(&c), u16(0x0030))

	set_hl(&c, 0x1234)
	misc(&c, 0x29) // ADD HL,HL (double)
	testing.expect_value(t, get_hl(&c), u16(0x2468))
}

// INC rr / DEC rr -- 0x03/0x13/0x23/0x33 (INC), 0x0B/0x1B/0x2B/0x3B (DEC).

@(test)
test_inc_rr_wraps_and_preserves_flags :: proc(t: ^testing.T) {
	c: Cpu
	c.flags = transmute(Flags)u8(0xF0) // all flags set
	set_hl(&c, 0xFFFF)
	cycles := misc(&c, 0x23) // INC HL
	testing.expect_value(t, get_hl(&c), u16(0x0000)) // wraps
	testing.expect(t, c.flags.z && c.flags.n && c.flags.h && c.flags.c, "INC rr must not touch flags")
	testing.expect_value(t, cycles, 8)
}

@(test)
test_dec_rr_wraps_and_selects_pair :: proc(t: ^testing.T) {
	c: Cpu
	set_bc(&c, 0x0000)
	misc(&c, 0x0B) // DEC BC
	testing.expect_value(t, get_bc(&c), u16(0xFFFF)) // wraps, correct pair

	set_de(&c, 0x0100)
	misc(&c, 0x1B) // DEC DE
	testing.expect_value(t, get_de(&c), u16(0x00FF))
}

// LD (rr),A / LD A,(rr) -- 0x02/12/22/32 (store), 0x0A/1A/2A/3A (load).

@(test)
test_ld_bc_store_and_de_load :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.regs[.A] = 0x7E
	set_bc(&c, 0xC000)
	cycles := misc(&c, 0x02) // LD (BC),A
	testing.expect_value(t, m.data[0xC000], u8(0x7E))
	testing.expect_value(t, cycles, 8)

	m.data[0xC050] = 0x3C
	set_de(&c, 0xC050)
	misc(&c, 0x1A) // LD A,(DE)
	testing.expect_value(t, c.regs[.A], u8(0x3C))
}

@(test)
test_ld_hli_store_increments_hl :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.regs[.A] = 0x11
	set_hl(&c, 0xC000)
	misc(&c, 0x22) // LD (HL+),A
	testing.expect_value(t, m.data[0xC000], u8(0x11)) // written at old HL
	testing.expect_value(t, get_hl(&c), u16(0xC001)) // HL incremented after
}

@(test)
test_ld_hld_load_decrements_hl :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	m.data[0xC005] = 0x99
	set_hl(&c, 0xC005)
	misc(&c, 0x3A) // LD A,(HL-)
	testing.expect_value(t, c.regs[.A], u8(0x99)) // read from old HL
	testing.expect_value(t, get_hl(&c), u16(0xC004)) // HL decremented after
}

// Accumulator rotates: RLCA=0x07, RRCA=0x0F, RLA=0x17, RRA=0x1F.
// All keep Z=N=H=0. RLCA/RRCA are circular; RLA/RRA go through carry.

@(test)
test_rlca_circular :: proc(t: ^testing.T) {
	c: Cpu
	c.regs[.A] = 0x85 // 1000_0101
	misc(&c, 0x07)
	testing.expect_value(t, c.regs[.A], u8(0x0B)) // 0000_1011, bit7 wraps to bit0
	testing.expect(t, c.flags.c, "RLCA: C = old bit 7")
	testing.expect(t, !c.flags.z && !c.flags.n && !c.flags.h, "RLCA: Z/N/H clear")
}

@(test)
test_rrca_circular :: proc(t: ^testing.T) {
	c: Cpu
	c.regs[.A] = 0x01
	misc(&c, 0x0F)
	testing.expect_value(t, c.regs[.A], u8(0x80)) // bit0 wraps to bit7
	testing.expect(t, c.flags.c, "RRCA: C = old bit 0")
}

@(test)
test_rla_through_carry :: proc(t: ^testing.T) {
	c: Cpu
	// old bit 7 goes to carry, must NOT wrap into bit 0
	c.regs[.A] = 0x80
	c.flags.c = false
	misc(&c, 0x17)
	testing.expect_value(t, c.regs[.A], u8(0x00)) // not 0x01
	testing.expect(t, c.flags.c, "RLA: new C = old bit 7")
	testing.expect(t, !c.flags.z, "RLA: Z stays 0 even when result is 0")

	c.regs[.A] = 0x01
	c.flags.c = true
	misc(&c, 0x17)
	testing.expect_value(t, c.regs[.A], u8(0x03)) // old carry fills bit 0
	testing.expect(t, !c.flags.c, "RLA: new C = old bit 7 (0)")
}

@(test)
test_rra_through_carry :: proc(t: ^testing.T) {
	c: Cpu
	c.regs[.A] = 0x80
	c.flags.c = true
	misc(&c, 0x1F)
	testing.expect_value(t, c.regs[.A], u8(0xC0)) // old carry fills bit 7
	testing.expect(t, !c.flags.c, "RRA: new C = old bit 0 (0)")

	c.regs[.A] = 0x01
	c.flags.c = false
	misc(&c, 0x1F)
	testing.expect_value(t, c.regs[.A], u8(0x00))
	testing.expect(t, c.flags.c, "RRA: new C = old bit 0 (1)")
}

// DAA = 0x27. Corrects A to packed BCD using N/H/C from the previous op.

@(test)
test_daa_add_low_nibble :: proc(t: ^testing.T) {
	c: Cpu
	c.regs[.A] = 0x0A // low nibble > 9
	misc(&c, 0x27)
	testing.expect_value(t, c.regs[.A], u8(0x10))
	testing.expect(t, !c.flags.c && !c.flags.h, "no carry, H cleared")
}

@(test)
test_daa_add_half_carry :: proc(t: ^testing.T) {
	c: Cpu
	c.regs[.A] = 0x10 // BCD 9+7 = binary 0x10 with H
	c.flags.h = true
	misc(&c, 0x27)
	testing.expect_value(t, c.regs[.A], u8(0x16)) // BCD "16"
}

@(test)
test_daa_add_high_nibble_sets_carry :: proc(t: ^testing.T) {
	c: Cpu
	c.regs[.A] = 0x10 // BCD 90+80 = 0x110 -> 0x10 with C
	c.flags.c = true
	misc(&c, 0x27)
	testing.expect_value(t, c.regs[.A], u8(0x70)) // BCD "70" + carry
	testing.expect(t, c.flags.c, "decimal carry out")
}

@(test)
test_daa_add_over_99_is_zero :: proc(t: ^testing.T) {
	c: Cpu
	c.regs[.A] = 0xA0 // high nibble > 9
	misc(&c, 0x27)
	testing.expect_value(t, c.regs[.A], u8(0x00))
	testing.expect(t, c.flags.c && c.flags.z, "carry set, zero result")
}

@(test)
test_daa_sub_half_borrow :: proc(t: ^testing.T) {
	c: Cpu
	c.regs[.A] = 0x0F // BCD 10-01 = binary 0x0F with N,H
	c.flags.n = true
	c.flags.h = true
	misc(&c, 0x27)
	testing.expect_value(t, c.regs[.A], u8(0x09)) // BCD "09"
	testing.expect(t, c.flags.n && !c.flags.c, "N preserved, C unchanged")
}

@(test)
test_daa_sub_with_borrow :: proc(t: ^testing.T) {
	c: Cpu
	c.regs[.A] = 0xFF // BCD 00-01 = binary 0xFF with N,H,C
	c.flags.n = true
	c.flags.h = true
	c.flags.c = true
	misc(&c, 0x27)
	testing.expect_value(t, c.regs[.A], u8(0x99)) // BCD "99" (borrow)
	testing.expect(t, c.flags.c, "C stays set in sub path")
}
