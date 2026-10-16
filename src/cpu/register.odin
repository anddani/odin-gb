package cpu

get_af :: proc(c: ^Cpu) -> u16 {
	return u16(c.regs[.A]) << 8 | u16(c.flags)
}

set_af :: proc(c: ^Cpu, value: u16) {
	c.regs[.A] = u8(value >> 8)
	c.flags = transmute(Flags)u8(value & 0xF0)
}

get_bc :: proc(c: ^Cpu) -> u16 {
	return u16(c.regs[.B]) << 8 | u16(c.regs[.C])
}

set_bc :: proc(c: ^Cpu, value: u16) {
	c.regs[.B] = u8(value >> 8)
	c.regs[.C] = u8(value & 0xFF)
}

get_de :: proc(c: ^Cpu) -> u16 {
	return u16(c.regs[.D]) << 8 | u16(c.regs[.E])
}

set_de :: proc(c: ^Cpu, value: u16) {
	c.regs[.D] = u8(value >> 8)
	c.regs[.E] = u8(value & 0xFF)
}

get_hl :: proc(c: ^Cpu) -> u16 {
	return u16(c.regs[.H]) << 8 | u16(c.regs[.L])
}

set_hl :: proc(c: ^Cpu, value: u16) {
	c.regs[.H] = u8(value >> 8)
	c.regs[.L] = u8(value & 0xFF)
}
