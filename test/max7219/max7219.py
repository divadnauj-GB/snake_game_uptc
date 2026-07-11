import cocotb
from cocotb.triggers import FallingEdge, RisingEdge
from cocotb.types import LogicArray, Logic, Bit
from cocotb.handle import LogicObject
from cocotb.triggers import Timer
import copy

class Signal:
    def __init__(self, value=0):
        self.value = value


"""
This is a simulation model of an MAX72XX driver of a 8X8 Led Matrix
"""
class MAX72xxModel:
    def __init__(self, clk, cs, din, dout, id=0):
        self.clk = clk
        self.cs = cs
        self.din = din
        self.dout = dout
        self.id = id
        self.framebuffer = [[0]*8 for _ in range(8)]
        self.registers = {}
        self.shift_reg = [0]*16
        self.decode_mode = 0
        self.intensity = 0
        self.scan_limit = 7  # Default to all digits
    
    async def start(self):
        """Asynchronous coroutine to monitor SPI bus and decode commands."""
        cocotb.start_soon(self.shift_spi_reg())
        cocotb.start_soon(self.capture_spi_command())
        while True:
            self.dout.value = self.shift_reg[15]
            await RisingEdge(self.clk)

    async def shift_spi_reg(self):
        """Listen for SPI commands continuously."""
        while True:
            await FallingEdge(self.cs)
            while self.cs.value == 0:
                await RisingEdge(self.clk)
                for i in range(15, 0, -1):
                    self.shift_reg[i] = self.shift_reg[i - 1]
                self.shift_reg[0] = int(self.din.value)
                await Timer(1, unit="ns")
                self.dout.value = self.shift_reg[15]


    async def capture_spi_command(self):
        """Capture a single SPI command when CS goes low."""
        while True:
            await RisingEdge(self.cs)
            address = 0
            data = 0
            #print(f"Shift Register State: {self.id} {self.din.value} {self.shift_reg}",self.dout.value)
            for i in range(8):
                address = address + int(self.shift_reg[i+8])*(2**i) 
                data = data + int(self.shift_reg[i])*(2**i)
            self._process_command(address, data)

    def _process_command(self, address, data):
        """Decode MAX7219 registers and grid data."""
        # Handle shutdown, decode mode, intensity, etc.
        print(f"Processing command: Address=0x{address:02X}, Data=0x{data:02X}")
        self.registers[address] = data
        match address:
            case 0x0C:  # Shutdown register
                if data == 0x00:
                    self._shutdown()
                elif data == 0x01:
                    self._power_on()
            case 0x09:  # Decode mode register
                self.decode_mode = data
                print(f"decode mode established: {data}")
            case 0x0A:  # Intensity register
                self.intensity = data
                print(f"intensity established: {data}")
            case 0x0B:  # Scan limit register
                self.scan_limit = data
                print(f"scan limit established: {data}")
            case x if x in range(0x01, 0x09):  # Digit registers
                self._update_framebuffer(x, data)

    def _shutdown(self):
        """Handle shutdown command."""  
        print("MAX7219 is shutting down.")
        self.framebuffer = [[0]*8 for _ in range(8)]
    
    def _power_on(self):
        """Handle power on command."""
        print("MAX7219 is powering on.")
        self.framebuffer = [[0]*8 for _ in range(8)]

    def _update_framebuffer(self, row_idx, data):
        """Update the framebuffer for a specific row based on the data byte."""
        for col_idx in range(8):
            self.framebuffer[row_idx - 1][col_idx] = (data >> col_idx) & 0x01

    def get_framebuffer(self):
        """Return the current state of the 8x8 framebuffer."""
        return self.framebuffer
    

"""
This is an 2D array of 2X2 MAX7219 matrices organized as follows 
M00 M01
M10 M11
This generates a 16X16 matrix
The matrices are connected as follow din->M00->M01->M10->M11->dout
"""
class MAX7219_composed:
    def __init__(self, clk, cs, din, dout, file=None):
        self.clk = clk
        self.cs = cs
        self.din = din
        self.dout = dout
        self.dout1 = Signal(0)
        self.dout2 = Signal(0)
        self.dout3 = Signal(0)
        self.max7219_0_0 = MAX72xxModel(self.clk, self.cs, self.din,  self.dout1, id=0)
        self.max7219_0_1 = MAX72xxModel(self.clk, self.cs, self.dout1, self.dout2, id=1)
        self.max7219_1_0 = MAX72xxModel(self.clk, self.cs, self.dout2, self.dout3, id=2)
        self.max7219_1_1 = MAX72xxModel(self.clk, self.cs, self.dout3, self.dout, id=3)
        self.framebuffer = [[0]*16 for _ in range(16)]  # 4 devices, each with 8 rows
        self.file = file
        if isinstance(self.file, str):
            with open(self.file,'w') as fp:
                fp.write(f"MAX72XX Content....\n")

    async def start(self):
        """Start the composed model."""
        cocotb.start_soon(self.max7219_0_0.start())
        cocotb.start_soon(self.max7219_0_1.start())
        cocotb.start_soon(self.max7219_1_0.start())
        cocotb.start_soon(self.max7219_1_1.start())
        while True:
            await RisingEdge(self.clk)
            

    def get_framebuffer(self):
        """Combine the framebuffers of all four devices into a single 16x16 framebuffer."""
        fb0 = self.max7219_0_0.get_framebuffer()
        fb1 = self.max7219_0_1.get_framebuffer()
        fb2 = self.max7219_1_0.get_framebuffer()
        fb3 = self.max7219_1_1.get_framebuffer()

        for row in range(8):
            self.framebuffer[row][:8] = fb0[row]
            self.framebuffer[row][8:] = fb1[row]
            self.framebuffer[row + 8][:8] = fb2[row]
            self.framebuffer[row + 8][8:] = fb3[row]
        return self.framebuffer

    def print_framebuffer(self):
        """Print the current state of the 16x16 framebuffer."""
        self.get_framebuffer()
        data=[]
        for row in self.framebuffer:
            pixel_frame = ''.join(str(pixel) for pixel in row)
            pixel_frame = pixel_frame.replace('0', ' ').replace('1', '█')
            data.append(pixel_frame)
            print(pixel_frame)
        #dumps the content of the buffer into a txtfile
        if isinstance(self.file, str):
            with open(self.file,'a') as fp:
                fp.write(f"\n\n")
                for line in data:
                    fp.write(f"{line}\n")