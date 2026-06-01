`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/31/2026 03:44:42 PM
// Design Name: 
// Module Name: clk_25MHz_sim
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


module tb_clk_gen_25MHz(
    );
    
    reg clk_100MHz;
    reg reset;
    
    wire clk_25MHz;
    
    clk_gen_25MHz uut(
        .clk_100MHz(clk_100MHz),
        .reset(reset),
        .clk_25MHz(clk_25MHz)
    );
    
    always
    begin
        #5 clk_100MHz = ~clk_100MHz;
    end
    
    initial begin
        clk_100MHz = 0;
        reset = 1;
        
        #20;
        
        reset = 0;
        
        #100;
        
    end
    
endmodule
