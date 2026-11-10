package gameboy

import "../cart"
import "../cpu"
import "../mmu"
import "../ppu"
import "../timer"

Gameboy :: struct {
	cpu:   cpu.Cpu,
	mmu:   mmu.Mmu,
	timer: timer.Timer,
	ppu:   ppu.Ppu,
	cart:  cart.Cart,
}

FRAME_IN_TICKS :: 70224

gb_read :: proc(ctx: rawptr, addr: u16) -> u8 {
	gb := cast(^Gameboy)ctx
	return mmu.mmu_read(&gb.mmu, addr)
}

gb_write :: proc(ctx: rawptr, addr: u16, value: u8) {
	gb := cast(^Gameboy)ctx
	mmu.mmu_write(&gb.mmu, addr, value)
}

gb_init :: proc(gb: ^Gameboy, rom_path: string) -> cart.Cart_Error {
	c, err := cart.cart_from_file(rom_path)

	if err == cart.Cart_Error.None {
		gb.cart = c
		gb.mmu.cart = &gb.cart
		gb.mmu.timer = &gb.timer
		gb.mmu.ppu = &gb.ppu
		gb.ppu.vram = &gb.mmu.vram[0]
		gb.cpu.bus = cpu.Bus {
			ctx   = gb,
			read  = gb_read,
			write = gb_write,
		}
		gb.cpu.pc = 0x0100
		gb.cpu.sp = 0xFFFE
		cpu.set_af(&gb.cpu, 0x01B0)
		cpu.set_bc(&gb.cpu, 0x0013)
		cpu.set_de(&gb.cpu, 0x00D8)
		cpu.set_hl(&gb.cpu, 0x014D)
	}

	return err
}

gb_run_frame :: proc(gb: ^Gameboy) {
	cycles := 0
	for cycles < FRAME_IN_TICKS {
		used := cpu.step(&gb.cpu)
		mmu.mmu_tick(&gb.mmu, used)
		mmu.ppu_tick(&gb.mmu, used)
		cycles += used
	}
}
