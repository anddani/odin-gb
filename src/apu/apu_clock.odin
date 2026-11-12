package apu

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

}
