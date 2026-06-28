`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Nathan Cinco
// 
// Create Date: 05/31/2026 03:36:07 PM
// Module Name: clk_gen_25MHz
// Project Name: FPGA Pong
// Target Devices: Nexys A7-100T
// Description: 
// Takes the 100 MHz onboard oscillator clock and divides it by 4 
// to generate a 25 MHz pixel clock required for 640x480 @ 60Hz VGA timing.
// 
//////////////////////////////////////////////////////////////////////////////////

module clk_gen_25MHz(
    input clk_100MHz,    // 100 MHz system clock from Nexys A7 onboard oscillator
    input reset,         // Asynchronous active-high reset
    output clk_25MHz     // 25 MHz pixel clock for VGA synchronization
    );

    reg [1:0] counter;

    always @(posedge clk_100MHz or posedge reset)
    begin
        if (reset)
            counter <= 0;
        else
            counter <= counter + 1;
            
    end

    // The MSB (bit 1) of a 2-bit counter toggles at exactly 1/4 the rate of the input clock.
    // 00 -> 01 -> 10 -> 11 -> 00... (Bit 1 is high 50% of the time, creating a symmetric square wave).
    assign clk_25MHz = counter[1];

endmodule
