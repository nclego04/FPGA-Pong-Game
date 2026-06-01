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

module tb_clk_gen_25MHz(); // Testbenches have no physical inputs or outputs

    // -------------------------------------------------------------------------
    // Testbench Signals
    // -------------------------------------------------------------------------
    // Registers (reg) are used to generate stimulus (inputs to the UUT).
    reg clk_100MHz;
    reg reset;
    
    // Wires (wire) are used to observe the outputs from the UUT.
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
    // Apply test vectors sequentially to verify module behavior.
    initial begin
        // 1. Initialize signals
        clk_100MHz = 0;
        reset = 1; // Assert asynchronous reset immediately
        
        // 2. Hold reset high for two full 100 MHz clock cycles (20ns) to 
        // ensure the internal counter zeroes out correctly.
        #20;
        
        // 3. De-assert reset and allow the counter to run freely
        reset = 0;
        
        // 4. Run the simulation for 100ns (10 input clock cycles) to observe
        // several full periods of the divided 25 MHz output clock.
        #100;        
    end
    
endmodule
