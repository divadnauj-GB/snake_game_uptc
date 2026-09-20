<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->
# Minimal Snake Game ASIC 

**Authors:** Valeria Molano and Luisa Fernanda Avendaño.

This is a simple snake game project selected as the best course project from the **Digital Asic Design** 2025-2 course at Universidad Pedagogica y Tecnologica de Colombia - Tunja. The course has been taught by professor [Juan David Guerrero Balaguera](https://github.com/divadnauj-GB).

## Architecture details 

This project consist of an minimal ASIC design of the classical Snake videogame using four 8X8 Led Matrices and four input push buttons for controlling the game. The ASIC is all full implemented using verilog following the architecture shown in the following figure. 

![snake architecture](./snake_arch.svg)

The game is controlled via 4 push buttons each indicates one movement direction (e.g., up, down, left or right). In addition the system uses a 10MHZ input clock and an active low reset. The outpus uses three ports SPI compatible (SCK, MOSI, and CS) to control four MAX7219 Led matrices controllers connected in a daisy chain architecture. 

The ASIC is composed by a debounce circuitry that filters the noise cased by mechanical bouncing circuitry on the push buttons. The clean push button signals go into a direction encoder that converts four indivisual signals into a two bits direction encoding as shown in this table:

|||
|-|-|
|DIR[1:0]|Meaning|
|00|down|
|01|up|
|10|left|
|11|right|

The direction code enters the Snake Logic component which also receives a trigger signal every 500ms. Every time the snake eats food, the game tick goes faster 10ms. At every game tick the four led matrices are updated with the current status of the game. When there is a game over condition, the matrices turn on completely. 

The MAX7219 controller comprises a basic SPI contoller able of sending the information to all MAX7219 chips connected in a daisy chain structure.

The ASIC uses the following pis as the TinyTapeout Pinout: The Disp1 and Disp0 outputs correspond to a two BCD digits where the score can be visualized. external BCD-to-7segments decoder can be connected to disp0/1.

|||||
|-|-|-|-|
|#|Input (ui)|Output (uo) |Bidirectional (uio)|
|0|left     | spi_dout  | disp1[0]  |
|1|right    | spi_clk   | disp1[0]  |
|2|down     | spi_cs    | disp1[0]  |
|3|up       | -         | disp1[0]  |
|4| -       | disp0[0]  | -         |
|5| -       | disp0[0]  | -         |
|6| -       | disp0[0]  | -         |
|7| -       | disp0[0]  | -         |

## How to test

Before using the example you must connect the external hardware as presented in the previous table. Once powered the board adn selected the snake game, the snake should appear on the screen and you should be ready to go by changing the direction of moving the snake by pressing the push buttons. You shoudl see that every time the food is found, the snake grows and the game starts to go faster. 

The gamover conditionsa are very simple:
- When head touches the snake body
- When head crashes the screen edges


## External hardware

In order to use this ASIC you need the folowing components.

- Four push buttons connected with a pull up resistor, such that they produce 0 when pressed and 1 when released.
- Four 8X8 led matrices using the MAX7219 driver, they must be connected as the diagram shown in the previous figure.
- Connect the Disp0 and Disp1 to BCD-to-7Seg (e.g., 7447 or 7448) decoder in case you want to see your score on 7 segment displays.
