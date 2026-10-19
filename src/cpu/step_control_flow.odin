package cpu

jumps :: proc(c: ^Cpu, op: u8) -> int {
	op_code := (op >> 4) & 0b11
	cycle_count := 0
	switch op_code {
	// RET
	case 0:
		c.pc = pop16(c)
		cycle_count = 16

	// RETI
	case 1:
		c.pc = pop16(c)
		c.ime = true
		cycle_count = 16

	// JP HL
	case 2:
		c.pc = get_hl(c)
		cycle_count = 4

	// LD SP,HL
	case 3:
		c.sp = get_hl(c)
		cycle_count = 8
	}
	return cycle_count
}

cond :: proc(c: ^Cpu, op: u8) -> bool {
	cc := (op >> 3) & 0b11
	switch cc {
	// NZ
	case 0:
		return !c.flags.z

	// Z
	case 1:
		return c.flags.z

	// NC
	case 2:
		return !c.flags.c

	// C
	case 3:
		return c.flags.c
	}
	return false
}

control_flow :: proc(c: ^Cpu, op: u8) -> int {
	z := op & 0b00000111
	cycle_count := 4
	bit_3 := op & 0b00001000

	switch z {
	// RET cc
	// LDH (a8),A
	// LDH A,(a8)
	// ADD SP,r8
	// LD HL,SP+r8
	case 0:

	// POP rr
	// RET
	// RETI
	// JP HL
	// LD SP,HL
	case 1:
		if bit_3 == 0 {
			set_rp2(c, op, pop16(c))
			cycle_count = 12
		} else {
			cycle_count = jumps(c, op)
		}

	// JP cc,a16
	// LDH (C),A
	// LDH A,(C)
	// LD (a16),A
	// LD A,(a16)
	case 2:
		if op & 0x20 == 0 {
			target := fetch16(c)
			if cond(c, op) {
				c.pc = target
				cycle_count = 16
			} else {
				cycle_count = 12
			}
		} else {

		}

	// JP a16
	// CB
	// DI
	// EI
	case 3:
		op_code := (op & 0b00111000) >> 3
		switch op_code {
		// JP a16
		case 0:
			c.pc = fetch16(c)
			cycle_count = 16

		// CB
		case 1:

		// DI
		case 6:

		// EI
		case 7:
		}

	// CALL cc,a16
	case 4:

	// PUSH RR
	// CALL a6
	case 5:
		if bit_3 == 0 {
			push16(c, get_rp2(c, op))
			cycle_count = 16
		} else {

		}

	// immediate ALU
	case 6:
		op_code := (op & 0b00111000) >> 3
		v := fetch8(c)
		alu_apply(c, op_code, v)
		cycle_count = 8

	// RST
	case 7:
	}
	return cycle_count
}
