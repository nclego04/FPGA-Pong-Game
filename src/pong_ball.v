`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Nathan Cinco
//
// Create Date: 05/30/2026 10:21:45 PM
// Module Name: pong_ball
// Project Name: FPGA Pong
// Target Devices: Nexys A7-100T
// Description:
// Top-level structural wrapper for the FPGA Pong hardware. Integrates the
// clock divider, four debounced pushbuttons, and the VGA synchronization
// module that renders both paddles and the ball to the physical VGA port.
//
//////////////////////////////////////////////////////////////////////////////////

module pong_ball(
    // Board Inputs
    input clock_100MHz,  // 100 MHz oscillator from the Nexys A7 board
    input reset,         // Asynchronous system reset (mapped to SW0)
    input left_btn,
    input top_btn,
    input bottom_btn,
    input right_btn,
    input new_game,

    // VGA Physical Outputs (12-bit color total)
    output hsync,        // Horizontal synchronization pulse
    output vsync,        // Vertical synchronization pulse
    output [3:0] vga_r,  // 4-bit Red channel
    output [3:0] vga_g,  // 4-bit Green channel
    output [3:0] vga_b   // 4-bit Blue channel
);

    // Internal routing signals
    wire pixel_clk;      // 25 MHz clock domain bridge between modules
    
    wire left_paddle_down, left_paddle_up, right_paddle_down, right_paddle_up;

    // -------------------------------------------------------------------------
    // System Clock Generation
    // -------------------------------------------------------------------------
    // Steps down the 100 MHz board clock to the 25 MHz pixel clock required
    // for standard 640x480 @ 60Hz VGA timing.
    clk_gen_25MHz pixel_clock(
        .clk_100MHz(clock_100MHz),
        .reset(reset),
        .clk_25MHz(pixel_clk)
    );

    // -------------------------------------------------------------------------
    // Button Debouncing
    // -------------------------------------------------------------------------
    // The Nexys A7's onboard buttons are a generic directional pad
    // (up/down/left/right), not paddle-specific controls, so the ports above
    // are named for physical position to match the board's silkscreen/schematic.
    // Each one is repurposed here as an up/down control for whichever paddle it
    // is wired to: {top_btn, left_btn} drive the left paddle, {right_btn,
    // bottom_btn} drive the right paddle. The mapping from physical position to
    // paddle direction happens entirely at these four instantiations.
     sync_debouncer left_btn_debouncer(
        .clk(pixel_clk),
        .reset(reset),
        .btn_in(left_btn),

        .btn_out(left_paddle_down)   // left_btn -> left paddle moves down
    );

    sync_debouncer top_btn_debouncer(
        .clk(pixel_clk),
        .reset(reset),
        .btn_in(top_btn),

        .btn_out(left_paddle_up)     // top_btn -> left paddle moves up
    );

    sync_debouncer bottom_btn_debouncer(
        .clk(pixel_clk),
        .reset(reset),
        .btn_in(bottom_btn),

        .btn_out(right_paddle_down)  // bottom_btn -> right paddle moves down
    );

    sync_debouncer right_btn_debouncer(
        .clk(pixel_clk),
        .reset(reset),
        .btn_in(right_btn),

        .btn_out(right_paddle_up)    // right_btn -> right paddle moves up
    );
    
    // -------------------------------------------------------------------------
    // VGA Synchronization and Color Output
    // -------------------------------------------------------------------------
    // Driven by the 25 MHz pixel clock. Handles all porch/sync timing and
    // renders both paddles and the ball over a white background during the
    // active area.
    vga_sync sync_generator(
        .reset(reset),
        .new_game(new_game),
        .pixel_clk(pixel_clk),
        .left_btn_up(left_paddle_up),
        .left_btn_down(left_paddle_down),
        .right_btn_up(right_paddle_up),
        .right_btn_down(right_paddle_down),

        .hsync(hsync),
        .vsync(vsync),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b)
    );
endmodule