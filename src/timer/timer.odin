package timer

Timer :: struct {
	counter: u16,
	tima:    u8,
	tma:     u8,
	tac:     u8,
}

tima_periods := [4]int{1024, 16, 64, 256}

timer_step :: proc(timer: ^Timer, cycles: int) -> bool {
	overflow := false

	old := int(timer.counter)
	sum := old + cycles

	if timer.tac & 0x04 != 0 {
		period := tima_periods[timer.tac & 3]
		ticks := sum / period - old / period
		for _ in 0 ..< ticks {
			if timer.tima == 0xFF {
				timer.tima = timer.tma
				overflow = true
			} else {
				timer.tima += 1
			}
		}
	}
	timer.counter = u16(sum)
	return overflow
}

timer_read :: proc(timer: ^Timer, addr: u16) -> u8 {
	result: u8 = 0xFF
	switch addr {
	case 0xFF04:
		result = u8(timer.counter >> 8)
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
		timer.counter = 0
	case 0xFF05:
		timer.tima = value
	case 0xFF06:
		timer.tma = value
	case 0xFF07:
		timer.tac = value
	}
}
