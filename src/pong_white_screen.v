`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/30/2026 10:21:45 PM
// Design Name: 
// Module Name: pong_white_screen
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module pong_white_screen(
    input clock_100MHz,
    input reset,
    output hsync,
    output vsync,
    output [3:0] vga_r,
    output [3:0] vga_g,
    output [3:0] vga_b
    );
    
    wire pixel_clk;
    
    clk_gen_25MHz pixel_clock(
        .clk_100MHz(clock_100MHz),
        .reset(reset),
        .clk_25MHz(pixel_clk)
    );
    
    vga_sync sync_generator(
        .pixel_clk(pixel_clk),
        .hsync(hsync),
        .vsync(vsync),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b)
    );
endmodule
