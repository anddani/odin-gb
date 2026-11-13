package cpu

import "core:testing"

// A flat 64 KB memory used as the Bus backing for tests. The read/write procs
// recover it from the opaque ctx, exactly as the real harness/MMU will.
Test_Mem :: struct {
	data: [0x10000]u8,
}

test_read :: proc(ctx: rawptr, addr: u16) -> u8 {
	return (cast(^Test_Mem)ctx).data[addr]
}

test_write :: proc(ctx: rawptr, addr: u16, value: u8) {
	(cast(^Test_Mem)ctx).data[addr] = value
}

make_test_cpu :: proc(m: ^Test_Mem) -> Cpu {
	return Cpu{bus = Bus{ctx = m, read = test_read, write = test_write}}
}

// --- 16-bit pair accessors ----------------------------------------------------

@(test)
test_bc_roundtrip :: proc(t: ^testing.T) {
	c: Cpu
	set_bc(&c, 0x1234)
	testing.expect_value(t, c.regs[.B], u8(0x12)) // high byte
	testing.expect_value(t, c.regs[.C], u8(0x34)) // low byte (not nibble-masked)
	testing.expect_value(t, get_bc(&c), u16(0x1234))
}

@(test)
test_de_roundtrip :: proc(t: ^testing.T) {
	c: Cpu
	set_de(&c, 0xBEEF)
	testing.expect_value(t, c.regs[.D], u8(0xBE))
	testing.expect_value(t, c.regs[.E], u8(0xEF))
	testing.expect_value(t, get_de(&c), u16(0xBEEF))
}

@(test)
test_hl_roundtrip :: proc(t: ^testing.T) {
	c: Cpu
	set_hl(&c, 0xC0DE)
	testing.expect_value(t, c.regs[.H], u8(0xC0))
	testing.expect_value(t, c.regs[.L], u8(0xDE))
	testing.expect_value(t, get_hl(&c), u16(0xC0DE))
}

// Setting one pair must not disturb the registers of another pair.
@(test)
test_pairs_are_independent :: proc(t: ^testing.T) {
	c: Cpu
	set_bc(&c, 0xAABB)
	set_de(&c, 0xCCDD)
	testing.expect_value(t, get_bc(&c), u16(0xAABB))
	testing.expect_value(t, get_de(&c), u16(0xCCDD))
}

// --- AF / flags ---------------------------------------------------------------

// POP AF behavior: the low nibble of F is always forced to 0.
@(test)
test_af_masks_low_nibble :: proc(t: ^testing.T) {
	c: Cpu
	set_af(&c, 0xAB5F) // F low nibble (0x0F) must be dropped
	testing.expect_value(t, c.regs[.A], u8(0xAB))
	testing.expect_value(t, get_af(&c), u16(0xAB50))
}

// Each flag bit lands in the right position (Z=7, N=6, H=5, C=4).
@(test)
test_af_flag_bit_positions :: proc(t: ^testing.T) {
	c: Cpu

	set_af(&c, 0x00F0) // all four flags set
	testing.expect(t, c.flags.z && c.flags.n && c.flags.h && c.flags.c, "all flags set")
	testing.expect_value(t, get_af(&c), u16(0x00F0))

	set_af(&c, 0x0080) // only Z (bit 7)
	testing.expect(t, c.flags.z, "Z set")
	testing.expect(t, !c.flags.n && !c.flags.h && !c.flags.c, "only Z set")

	set_af(&c, 0x0010) // only C (bit 4)
	testing.expect(t, c.flags.c, "C set")
	testing.expect(t, !c.flags.z && !c.flags.n && !c.flags.h, "only C set")
}

// --- bus helpers --------------------------------------------------------------

@(test)
test_read8_write8 :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	write8(&c.bus, 0xC000, 0x42)
	testing.expect_value(t, m.data[0xC000], u8(0x42))
	testing.expect_value(t, read8(&c.bus, 0xC000), u8(0x42))
}

@(test)
test_read16_is_little_endian :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	m.data[0xC000] = 0x34 // low byte at the lower address
	m.data[0xC001] = 0x12 // high byte next
	testing.expect_value(t, read16(&c.bus, 0xC000), u16(0x1234))
}

@(test)
test_write16_is_little_endian :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	write16(&c.bus, 0xC000, 0x1234)
	testing.expect_value(t, m.data[0xC000], u8(0x34)) // low at lower address
	testing.expect_value(t, m.data[0xC001], u8(0x12)) // high next
}

@(test)
test_read16_write16_roundtrip :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	write16(&c.bus, 0xD000, 0xBEEF)
	testing.expect_value(t, read16(&c.bus, 0xD000), u16(0xBEEF))
}

// --- fetch8 -------------------------------------------------------------------

@(test)
test_fetch8_reads_and_advances_pc :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.pc = 0x0100
	m.data[0x0100] = 0xAA
	m.data[0x0101] = 0xBB

	testing.expect_value(t, fetch8(&c), u8(0xAA))
	testing.expect_value(t, c.pc, u16(0x0101))
	testing.expect_value(t, fetch8(&c), u8(0xBB))
	testing.expect_value(t, c.pc, u16(0x0102))
}

// HALT bug: HALT with IME=0 and an interrupt pending does NOT halt, and the
// byte after HALT is read twice (PC fails to increment once).
@(test)
test_halt_bug_double_fetch :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.ime = false
	c.pc = 0x0100
	m.data[0xFFFF] = 0x01 // IE: VBlank enabled
	m.data[0xFF0F] = 0x01 // IF: VBlank pending -> condition for the bug
	m.data[0x0100] = 0x76 // HALT
	m.data[0x0101] = 0x3C // INC A

	step(&c) // executes HALT -> sets halt_bug, PC now 0x0101
	testing.expect(t, !c.halt, "HALT bug: does not actually halt")
	testing.expect(t, c.halt_bug, "halt_bug armed")

	c.regs[.A] = 0
	step(&c) // INC A, but PC must NOT advance past 0x0101
	testing.expect_value(t, c.regs[.A], u8(1))
	testing.expect_value(t, c.pc, u16(0x0101)) // stuck -> byte re-read

	step(&c) // INC A again (the double-read), now PC advances
	testing.expect_value(t, c.regs[.A], u8(2))
	testing.expect_value(t, c.pc, u16(0x0102))
}

// Without the bug condition (IME on, or nothing pending), HALT halts normally.
@(test)
test_halt_normal :: proc(t: ^testing.T) {
	m: Test_Mem
	c := make_test_cpu(&m)
	c.ime = true
	c.pc = 0x0100
	m.data[0x0100] = 0x76 // HALT
	step(&c)
	testing.expect(t, c.halt, "normal HALT halts")
	testing.expect(t, !c.halt_bug, "no halt bug when IME set")
}
