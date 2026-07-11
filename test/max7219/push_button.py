import cocotb
from cocotb.triggers import Timer, FallingEdge, RisingEdge, ClockCycles, Join
from cocotb.clock import Clock


class button_sim():
    """This class emulates the pulses generated externally by a push button"""
    def __init__(self, clk, pulse ):
        # inputs
        self.clk = clk
        self.pulse = pulse
        self.pulse.value=1

    async def update(self,num_pushes):
        for _ in range(num_pushes):
            self.pulse.value=0
            for _ in range(3):
                await FallingEdge(self.clk)
            self.pulse.value=1
            for _ in range(6):
                await FallingEdge(self.clk)
            self.pulse.value=0
            for _ in range(5):
                await FallingEdge(self.clk)
            self.pulse.value=1
            for _ in range(10):
                await FallingEdge(self.clk)
            self.pulse.value=0
            for _ in range(800-24):
                await FallingEdge(self.clk)
            self.pulse.value=1
            for _ in range(3):
                await FallingEdge(self.clk)
            self.pulse.value=0
            for _ in range(6):
                await FallingEdge(self.clk)
            self.pulse.value=1
            for _ in range(5):
                await FallingEdge(self.clk)
            self.pulse.value=0
            for _ in range(10):
                await FallingEdge(self.clk)
            self.pulse.value=1
            for _ in range(800-24):
                await FallingEdge(self.clk)
