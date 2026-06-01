`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/31/2026 03:36:07 PM
// Design Name: 
// Module Name: clk_gen_25MHz
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


module clk_gen_25MHz(
    input clk_100MHz,
    input reset,
    output clk_25MHz
    );
    
    reg [1:0] counter;
    
    always @(posedge clk_100MHz or posedge reset)
    begin
        if (reset)
            counter <= 0;
        else
            counter <= counter + 1;
            
    end
    
    assign clk_25MHz = counter[1];

endmodule
