package timer

Timer :: struct {
	div:          u8,
	tima:         u8,
	tma:          u8,
	tac:          u8,
	div_counter:  int,
	tima_counter: int,
}

tima_periods := [4]int{1024, 16, 64, 256}

timer_step :: proc(timer: ^Timer, cycles: int) -> bool {
	overflow := false

	// DIV
	total := timer.div_counter + cycles
	timer.div += u8(total / 256)
	timer.div_counter = total % 256

	// TIMA
	if timer.tac & 0x04 != 0 {
		timer.tima_counter += cycles
		period := tima_periods[timer.tac & 3]
		for timer.tima_counter >= period {
			timer.tima_counter -= period
			if timer.tima == 0xFF {
				timer.tima = timer.tma
				overflow = true
			} else {
				timer.tima += 1
			}
		}
	}
	return overflow
}

timer_read :: proc(timer: ^Timer, addr: u16) -> u8 {
	result: u8 = 0xFF
	switch addr {
	case 0xFF04:
		result = timer.div
	case 0xFF05:
		result = timer.tima
	case 0xFF06:
		result = timer.tma
	case 0xFF07:
		result = timer.tac
	}
	return result
}

timer_write :: proc(timer: ^Timer, addr: u16, value: u8) {
	switch addr {
	case 0xFF04:
		timer.div = 0
		timer.div_counter = 0
	case 0xFF05:
		timer.tima = value
	case 0xFF06:
		timer.tma = value
	case 0xFF07:
		timer.tac = value
	}
}
