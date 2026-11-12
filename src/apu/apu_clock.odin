package apu

MAX_VOLUME :: 15

clock_length :: proc(apu: ^Apu) {
	if apu.ch2.length_enable && apu.ch2.length > 0 {
		apu.ch2.length -= 1
		if apu.ch2.length == 0 {
			apu.ch2.enabled = false
		}
	}
}

clock_sweep :: proc(apu: ^Apu) {

}

clock_envelope :: proc(apu: ^Apu) {
	if apu.ch2.env_period == 0 {
		return
	}
	apu.ch2.env_timer -= 1
	if apu.ch2.env_timer <= 0 {
		apu.ch2.env_timer = int(apu.ch2.env_period)
		if apu.ch2.env_add && apu.ch2.volume < MAX_VOLUME {
			apu.ch2.volume += 1
		}
		if !apu.ch2.env_add && apu.ch2.volume > 0 {
			apu.ch2.volume -= 1
		}
	}

}
