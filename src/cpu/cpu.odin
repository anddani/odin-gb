package cpu

Bus :: struct {
	ctx:   rawptr,
	read:  proc(ctx: rawptr, addr: u16) -> u8,
	write: proc(ctx: rawptr, addr: u16, value: u8),
}

Flags :: bit_field u8 {
	_: u8   | 4,
	c: bool | 1,
	h: bool | 1,
	n: bool | 1,
	z: bool | 1,
}

Reg :: enum {
	B,
	C,
	D,
	E,
	H,
	L,
	_HL,
	A,
}

Cpu :: struct {
	bus:         Bus,
	flags:       Flags,
	regs:        [Reg]u8,
	halt:        bool,
	sp:          u16,
	pc:          u16,
	ime:         bool,
	ime_pending: bool,
}

service_interrupt :: proc(c: ^Cpu, iff: u8, pending: u8) -> int {
	c.halt = false
	for bit in 0 ..< 5 {
		shifted_bit: u8 = 1 << u8(bit)
		if pending & shifted_bit != 0 {
			c.ime = false
			write8(&c.bus, 0xFF0F, iff & ~shifted_bit)
			push16(c, c.pc)
			c.pc = 0x40 + u16(bit) * 8
			return 20
		}
	}
	return 0
}

quadrant_dispatch :: proc(c: ^Cpu) -> int {
	op := fetch8(c)
	switch (op >> 6) {
	// Relative jumps, 16-bit LD/INC/DEC,
	// 8-bit INC/DEC, LD r,d8, rotates
	case 0:
		return misc(c, op)

	// LD r,r'
	case 1:
		return ld(c, op)

	// ALU A,r
	case 2:
		return alu(c, op)

	// Conditional RET/JP/CALL, PUSH/POP, RST,
	// CB prefix, ALU A,d8, LDH
	case 3:
		return control_flow(c, op)

	case:
		return 0
	}
}

step :: proc(c: ^Cpu) -> int {
	ie := read8(&c.bus, 0xFFFF)
	iff := read8(&c.bus, 0xFF0F)
	pending := ie & iff & 0x1F
	if c.ime && pending != 0 {
		return service_interrupt(c, iff, pending)
	}

	if c.halt {
		if pending != 0 {
			c.halt = false
		} else {
			return 4
		}
	}

	will_enable := c.ime_pending

	cycles := quadrant_dispatch(c)

	if will_enable {
		c.ime = true
		c.ime_pending = false
	}

	return cycles
}
