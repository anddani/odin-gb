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
	bus:   Bus,
	flags: Flags,
	regs:  [Reg]u8,
	halt:  bool,
	// a:     u8,
	// bc:    u16,
	// de:    u16,
	// hl:    u16,
	sp:    u16,
	pc:    u16,
}


step :: proc(c: ^Cpu) -> int {
	op := fetch8(c)
	switch (op >> 6) {
	// Relative jumps, 16-bit LD/INC/DEC,
	// 8-bit INC/DEC, LD r,d8, rotates
	case 0:
		return 4

	// LD r,r'
	case 1:
		return ld(c, op)

	// ALU A,r
	case 2:
		return alu(c, op)

	// Conditional RET/JP/CALL, PUSH/POP, RST,
	// CB prefix, ALU A,d8, LDH
	case 3:
		return 4

	case:
		return 0
	}
}
