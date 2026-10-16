package cpu

Bus :: struct {
	ctx:   rawptr,
	read:  proc(ctx: rawptr, addr: u16) -> u8,
	write: proc(ctx: rawptr, addr: u16, value: u8),
}

Cpu :: struct {
	bus: Bus,
}

step :: proc(_: ^Cpu) -> int {
	return 0
}
