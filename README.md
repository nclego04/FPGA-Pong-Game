# FPGA Pong: VGA Paddle Controller

This repository contains the VGA display controller, paddle logic, and ball physics for an FPGA-based Pong game, implemented in Verilog on the Digilent Nexys A7-100T development board.

The system generates a 640x480 @ 60Hz VGA signal and renders two player-controlled paddles (red on the left, blue on the right) and a bouncing ball (black) over a white background. Each paddle moves up/down once per frame in response to a pair of debounced pushbuttons. The ball bounces off the top/bottom walls and paddles, speeds up on each paddle hit, and re-serves from center after a miss; `new_game` resets the rally at any time.

## Demo Videos
* [Paddle controller demo](docs/videos/pong_paddles_demo.mp4) — both paddles moving in response to the four debounced pushbuttons.
* [Ball physics demo](docs/videos/pong_ball_demo.mp4) — the ball bouncing off walls and paddles, with a serve on miss.

## System Architecture

### RTL Hierarchy
* `pong_ball` (Top-Level)
  * `clk_gen_25MHz`: Divides the Nexys A7's 100 MHz onboard oscillator down to a 25 MHz pixel clock using a 2-bit counter.
  * `sync_debouncer` (x4): FSM-based debouncer for each pushbutton — a two-FF synchronizer followed by a press/release timing FSM that rejects mechanical bounce.
  * `vga_sync`: Manages the horizontal and vertical synchronization pulses, front/back porches, the 640x480 active visible area, and renders both paddles and the ball, including paddle-collision detection, wall bouncing, and serve-on-miss/`new_game` reset logic.

The schematic below shows the structural connections between the clock divider, the four debouncers, and `vga_sync`.

![Top-Level Schematic](docs/images/pong_ball_schematic.png)

*Note: The porch offset values in `vga_sync.v` have been manually calibrated to center the image and compensate for my specific monitor (Dell S2415H).*

The photo below confirms the calibrated porch timing centers the active video area on the physical monitor referenced above.

![White Screen Output On Physical Monitor](docs/images/vga_output_white_screen.png)

## Hardware & Software Requirements
* **Board:** Digilent Nexys A7-100T
* **Software:** Xilinx Vivado 2021.2
* **Output:** VGA Monitor
* **Inputs:**
  * `SW0` (Pin J15): global system reset. Flip DOWN for the clock and display to run.
  * `SW1` (Pin L16, `new_game`): resets the ball to a center serve, starting a new rally.
  * `BTNU` / `BTNL` (`top_btn` / `left_btn`): move the left paddle up / down.
  * `BTNR` / `BTND` (`right_btn` / `bottom_btn`): move the right paddle up / down.

## Simulation & Verification
Behavioral simulations were conducted in Vivado prior to synthesis to verify timing accuracy.

The image below demonstrates the testbench results for `clk_gen_25MHz.v`. The cursors verify a 40.000 ns period, confirming a clean 25 MHz pixel clock derived from the 100 MHz source.

![25 MHz Clock Simulation Waveform](docs/images/clk_25mhz_waveform.png)

`sync_debouncer.v` synchronizes each raw button input and only accepts a press or release once it has held stable for `STABLE_COUNT` clocks, rejecting mechanical bounce.

![Debounce FSM State Diagram](docs/images/debounce_fsm_state_diagram.png)

The waveform below is from `sim/sync_debouncer_tb.v`. With `STABLE_COUNT` = 10 and a 40 ns clock period, `btn_out` only toggles after `btn_in` has held its new level for 10 consecutive clocks, confirming the debouncer rejects shorter glitches.

![Sync Debouncer Testbench Waveform](docs/images/sync_debouncer_waveform.png)

The image below shows both paddles rendered on the VGA output, confirming `vga_sync.v` correctly draws the left (red) and right (blue) paddles over the white background.

![VGA Output With Paddles Rendered](docs/images/vga_output_paddles.png)
