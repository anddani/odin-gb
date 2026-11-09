package timer

Timer :: struct {
	div_counter: int,
	div:         u8,
	tac:         u8,
}

timer_step :: proc(timer: ^Timer, cycles: int) {
	// DIV
	total := timer.div_counter + cycles
	timer.div += u8(total / 256)
	timer.div_counter = total % 256

}
