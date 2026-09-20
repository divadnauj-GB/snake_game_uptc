## How it works

See the General System Description and Internal Module Description sections below for the full technical breakdown of `snake_top`, `debounce`, `game_core`, and `spi_driver`.breakdown of `snake_top`, `debounce`, `game_core`, and `spi_driver`.

## How to test

1. Connect the 4-module MAX7219 LED panel and the 4 direction push-buttons (see the **Pin Specification** table below).
2. Release reset (`SW[0]` active-low).
3. Use the direction buttons to guide the snake toward the food. The game ends on collision with a wall or with the snake's own body.

## External hardware

- 4× individual 8×8 MAX7219 LED matrix modules (2×2 grid, `DIN`/`DOUT` daisy-chained, `CLK`/`CS` in parallel).
- 4× momentary push-buttons (active-low) for direction control.

**TECHNICAL SPECIFICATION OF THE SNAKE GAME**

**Microchip Snake Game (snake_game_uptc)**
Author: Juan David Guerrero Balaguera, Valeria Molano, Luisa Avendaño

**ASIC Flow:** LibreLane / OpenLane
**Top Module:** snake_top
**Project:** Tiny Tapeout
**License:** Apache-2.0

## 1. General System Description

Below you can see the description and hardware implementation (Verilog RTL) of the Snake game. The design is intended to control 4 coupled 8×8 LED matrices, forming a 16×16 pixel game area. The circuit integrates clean reading of mechanical buttons, the complete game logic through a state machine, snake and food position control, a BCD scoring system, and SPI communication to drive the external displays via the MAX7219 driver.

![Figure 1: Hardware architecture and data flow in snake_top.](architecture_diagram.jpg)

*Figure 1: Hardware architecture and data flow in snake_top.*

## 2. Internal Module Description

### 2.1 snake_top (Main Module)

- **Clock Management:** Takes the 50 MHz base clock (CLOCK_50) and generates a 5 MHz signal (slow_clk) exclusively for SPI transmission.
- **Game Speed:** The game_tick signal controls every step of the snake. It starts with a long wait cycle and, every time an apple is eaten, the set_timer signal reduces that wait time by 16,384 cycles. This progressively accelerates the game.

### 2.2 debounce (Debounce Filter)

Cleans the mechanical noise from the buttons. Each button (KEY [3:0]) enters a shift register. The signal only changes its internal logical state if it remains stable (high or low) for 8 consecutive clock cycles.

### 2.3 game_core (Game Logic)

- **FSM (11 States):** Controls the entire flow: initializes the screen, updates the snake's coordinates, checks for collisions, and sends commands to draw the matrix row by row.
- **FIFO Memory:** A 32-position circular register that stores the X, Y coordinates of the snake's body. It uses pointers to add the new head and delete the last part of the tail with each movement.
- **LFSR Generator:** Creates pseudo-random numbers based on a linear-feedback shift register. It is used to calculate random coordinates for the appearance of food.
- **BCD Score:** A binary-coded decimal counter. Its outputs go directly to 8 pins (4 for tens, 4 for units), allowing simple LEDs to be connected to display the score in binary without needing additional decoders.

### 2.4 spi_driver (Display Controller)

Receives 16-bit parallel commands from the game_core and serializes them. Generates the necessary clock, data, and chip select (CS) pulses to communicate in a standard way with the MAX7219 ICs of the LED matrices.

## 3. Pin Specification (Pinout)

**Table 1: Input and output signals map.**

| Signal | Type | Width | Origin / Destination | Description |
|---|---|---|---|---|
| CLOCK_50 | Input | 1 bit | System | Base board clock (50 MHz). |
| SW [0] | Input | 1 bit | Switch | Asynchronous reset (Active low 0). |
| KEY [0] | Input | 1 bit | Button | Moves Up. |
| KEY [1] | Input | 1 bit | Button | Moves Down. |
| KEY [2] | Input | 1 bit | Button | Moves Right. |
| KEY [3] | Input | 1 bit | Button | Moves Left. |
| MAX_DIN | Output | 1 bit | SPI Driver | Serial data output to MAX7219. |
| MAX_CLK | Output | 1 bit | SPI Driver | Clock for SPI transmission. |
| MAX_CS | Output | 1 bit | SPI Driver | Chip Select (CS) signal for the matrix. |
| HEX0 [3:0] | Output | 4 bits | Score LEDs | Counter units (for 4 LEDs). |
| HEX1 [3:0] | Output | 4 bits | Score LEDs | Counter tens (for 4 LEDs). |

## 4. Errata and Known Behaviors

Supplementary material in the repository:

1. **YouTube Demo Video:** Demonstration of physical operation on FPGA. Link: [https://youtu.be/Ej_GrQa6S1c](https://youtu.be/Ej_GrQa6S1c)
2. **Confirmation Images:** Visual evidence of the states and rendering of the game.

![Figure 2: Implementation with FPGA](1.jpeg)

*Figure 2: Implementation with FPGA*

![Figure 3: Working operation evidence](2.jpg)

*Figure 3: Working operation evidence*

**Table 2: Operational details to consider for hardware integration.**

| Code | Behavior | Recommended Solution |
|---|---|---|
| **ERRATA-01** — KEY Inversion | The direction pins on the main module are logically inverted (e.g., when receiving "Up", "Down" is processed). | Physically cross the button connections on the motherboard during assembly. |
| **ERRATA-02** — Self-collision | If the direction opposite to the current movement is pressed (e.g., moving right and pressing left), the game applies the 180° turn before advancing, detecting a collision with its own body. | The player must make "U" turns in two steps (e.g., press "Up" and immediately "Left"). |
| **ERRATA-03** — Delay on Loss | When a Game Over occurs, the matrix does not automatically update to show the collision screen, since the FSM blocks the refresh if the game_over flag is active. | The user must press any movement button one more time to force the screen update via SPI. |
| **ERRATA-04** — Initial Score | Upon reset, the initial position of the snake (2,7) immediately matches the first generated coordinate for the apple (3,7). | The game will always start by showing 1 point (0001) on the LEDs upon startup. |
