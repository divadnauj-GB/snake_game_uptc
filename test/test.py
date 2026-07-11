# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from max7219.max7219 import MAX72xxModel, MAX7219_composed, Signal
from max7219.push_button import button_sim

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 100, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    dut.cs.value = 1


    dout = Signal(0)
    model = MAX7219_composed(
        dut.sck,
        dut.cs,
        dut.din,
        dout,
        file="matrix.txt"
    )
    
    await ClockCycles(dut.clk, 60)
    dut.rst_n.value = 1
    cocotb.start_soon(model.start())
    butt1=button_sim(dut.clk,dut.butt1)
    butt2=button_sim(dut.clk,dut.butt2)
    butt3=button_sim(dut.clk,dut.butt3)
    butt4=button_sim(dut.clk,dut.butt4)

    await ClockCycles(dut.clk, 7000000)
    model.print_framebuffer()
    await butt4.update(1)
    await ClockCycles(dut.clk, 5500000)
    """
    model.print_framebuffer()
    await ClockCycles(dut.clk, 50000)
    model.print_framebuffer()
    await ClockCycles(dut.clk, 50000)
    model.print_framebuffer()
    await ClockCycles(dut.clk, 50000)
    model.print_framebuffer()
    await ClockCycles(dut.clk, 50000)
    model.print_framebuffer()
    await ClockCycles(dut.clk, 50000)
    model.print_framebuffer()
    await ClockCycles(dut.clk, 50000)
    model.print_framebuffer()
    await ClockCycles(dut.clk, 50000)
    model.print_framebuffer()
    await ClockCycles(dut.clk, 50000)
    model.print_framebuffer()
    await ClockCycles(dut.clk, 50000)
    model.print_framebuffer()
    await ClockCycles(dut.clk, 50000)
    model.print_framebuffer()
    await ClockCycles(dut.clk, 50000)
    model.print_framebuffer()
    await ClockCycles(dut.clk, 50000)
    model.print_framebuffer()
    await ClockCycles(dut.clk, 50000)
    model.print_framebuffer()
    await ClockCycles(dut.clk, 50000)
    model.print_framebuffer()
    await ClockCycles(dut.clk, 50000)
    model.print_framebuffer()
    await ClockCycles(dut.clk, 50000)
    model.print_framebuffer()
    await ClockCycles(dut.clk, 50000)
    """
    model.print_framebuffer()

    with open("matrix_gold.txt","r") as Gfp:
        expected_output=Gfp.readlines()
#
    with open("matrix.txt","r") as Rfp:
        sim_output=Rfp.readlines()
#
    assert(expected_output==sim_output)

