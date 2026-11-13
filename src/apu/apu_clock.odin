package apu

clock_length :: proc(apu: ^Apu) {
	channel_length(&apu.ch1)
	channel_length(&apu.ch2)
	channel_length(&apu.ch3)
	channel_length(&apu.ch4)
}

clock_sweep :: proc(apu: ^Apu) {
	channel_sweep(&apu.ch1)
}

clock_envelope :: proc(apu: ^Apu) {
	channel_envelope(&apu.ch1)
	channel_envelope(&apu.ch2)
	channel_envelope(&apu.ch3)
}
