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
	// a:     u8,
	// bc:    u16,
	// de:    u16,
	// hl:    u16,
	sp:    u16,
	pc:    u16,
}

step :: proc(_: ^Cpu) -> int {
	return 0
}

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

read8 :: proc(b: ^Bus, addr: u16) -> u8 {
	return b.read(b.ctx, addr)
}

write8 :: proc(b: ^Bus, addr: u16, value: u8) {
	b.write(b.ctx, addr, value)
}

read16 :: proc(b: ^Bus, addr: u16) -> u16 {
	lo := u16(b.read(b.ctx, addr))
	hi := u16(b.read(b.ctx, addr + 1))
	return (hi << 8) | lo
}

write16 :: proc(b: ^Bus, addr: u16, value: u16) {
	lo := u8(value & 0xFF)
	hi := u8(value >> 8)
	b.write(b.ctx, addr, lo)
	b.write(b.ctx, addr + 1, hi)
}

fetch8 :: proc(c: ^Cpu) -> u8 {
	value := c.bus.read(c.bus.ctx, c.pc)
	c.pc += 1
	return value
}

fetch16 :: proc(c: ^Cpu) -> u16 {
	lo := u16(fetch8(c))
	hi := u16(fetch8(c))
	return (hi << 8) | lo
}
