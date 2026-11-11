package testrom
import "core:fmt"
import "core:testing"
import "../cart"
import "../cpu"
import "../mmu"
@(test)
test_combined_cpu_instrs :: proc(t: ^testing.T) {
	c, err := cart.cart_from_file("assets/cpu_instrs.gb")
	if err != .None { return }
	defer cart.cart_destroy(&c)
	m := new(Machine); defer free(m)
	m.mmu.cart = &c; m.mmu.timer = &m.timer; m.mmu.ppu = &m.ppu; m.mmu.joypad = &m.joypad
	m.ppu.vram = &m.mmu.vram[0]; m.ppu.oam = &m.mmu.oam
	st: cpu.Cpu
	st.bus = cpu.Bus{ctx=m, read=machine_read, write=machine_write}
	st.pc=0x0100; st.sp=0xFFFE
	cpu.set_af(&st,0x01B0); cpu.set_bc(&st,0x0013); cpu.set_de(&st,0x00D8); cpu.set_hl(&st,0x014D)
	for i in 0..<400_000_000 {
		used := cpu.step(&st); mmu.mmu_tick(&m.mmu, used); mmu.ppu_tick(&m.mmu, used)
		if serial_status(&m.serial) != .Running { break }
	}
	fmt.printf("status=%v bank=%d text=%q\n", serial_status(&m.serial), c.rom_bank, serial_text(&m.serial))
}
