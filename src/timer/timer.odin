package timer

Timer :: struct {
	div_counter:  int,
	div:          u8,
	tima_counter: int,
	tima:         u8,
	tma:          u8,
	tac:          u8,
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
