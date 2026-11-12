package apu

wave_pos :: proc()

wave_trigger :: proc(apu: ^Apu) {
	ch := &apu.ch3
	ch.enabled = ch.dac_on
	if ch.length == 0 {
		ch.length = 256
	}
	ch.freq_timer = (2048 - ch.freq) * 2
	ch.wave_pos = 0
}
