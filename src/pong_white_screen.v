`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Nathan Cinco
// 
// Create Date: 05/30/2026 10:21:45 PM
// Module Name: pong_white_screen
// Project Name: FPGA Pong
// Target Devices: Nexys A7-100T
// Description: 
// Top-level structural wrapper for the VGA display controller. 
// Integrates the clock divider and VGA synchronization modules to 
// drive a solid white test screen to the physical VGA port.
//
//////////////////////////////////////////////////////////////////////////////////

module pong_white_screen(
    // Board Inputs
    input clock_100MHz,  // 100 MHz oscillator from the Nexys A7 board
    input reset,         // Asynchronous system reset (mapped to SW0)
    
    // VGA Physical Outputs (12-bit color total)
    output hsync,        // Horizontal synchronization pulse
    output vsync,        // Vertical synchronization pulse
    output [3:0] vga_r,  // 4-bit Red channel
    output [3:0] vga_g,  // 4-bit Green channel
    output [3:0] vga_b   // 4-bit Blue channel    
);
    
// Internal routing signals
    wire pixel_clk;      // 25 MHz clock domain bridge between modules
    
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
    // VGA Synchronization and Color Output
    // -------------------------------------------------------------------------
    // Driven by the 25 MHz pixel clock. Handles all porch timings, sync pulses, 
    // and outputs full-brightness (white) RGB values during the active area.
    vga_sync sync_generator(
        .pixel_clk(pixel_clk),
        .hsync(hsync),
        .vsync(vsync),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b)    
    );
endmodule
