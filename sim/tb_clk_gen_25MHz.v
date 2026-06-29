`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Nathan Cinco
// 
// Create Date: 05/31/2026
// Module Name: tb_clk_gen_25MHz
// Project Name: FPGA Pong
// Target Devices: Simulation Only (Vivado Simulator)
// Description: 
// Behavioral testbench to verify the functionality of the 25 MHz clock divider.
// Generates a simulated 100 MHz input clock and toggles the reset signal to 
// observe the 25 MHz divided output.
//
//////////////////////////////////////////////////////////////////////////////////

module tb_clk_gen_25MHz();

    // -------------------------------------------------------------------------
    // Testbench Signals
    // -------------------------------------------------------------------------
    reg clk_100MHz;
    reg reset;

    wire clk_25MHz;
    
    // -------------------------------------------------------------------------
    // Unit Under Test (UUT) Instantiation
    // -------------------------------------------------------------------------
    clk_gen_25MHz uut (
        .clk_100MHz(clk_100MHz),
        .reset(reset),
        .clk_25MHz(clk_25MHz)
    );
    
    // -------------------------------------------------------------------------
    // Clock Generation
    // -------------------------------------------------------------------------
    // Create a 100 MHz clock signal.
    // 100 MHz = 10ns period. Toggle the signal every 5ns to create a 50% duty cycle.
    always begin
        #5 clk_100MHz = ~clk_100MHz; 
    end
    
    // -------------------------------------------------------------------------
    // Stimulus Block
    // -------------------------------------------------------------------------
    initial begin
        clk_100MHz = 0;
        reset = 1;

        // Hold reset high for two full 100 MHz clock cycles (20ns) to
        // ensure the internal counter zeroes out correctly.
        #20;

        reset = 0;

        // Run for 100ns (10 input clock cycles) to observe several full
        // periods of the divided 25 MHz output clock.
        #100;
    end
    
endmodule
