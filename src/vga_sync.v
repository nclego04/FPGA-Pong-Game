`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/31/2026 04:22:08 PM
// Design Name: 
// Module Name: vga_sync
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


module vga_sync(
    input pixel_clk,
    output reg hsync,
    output reg vsync,
    output reg [3:0] vga_r,
    output reg [3:0] vga_g,
    output reg [3:0] vga_b
    );
    
    parameter TOTAL_WIDTH = 800;
    parameter TOTAL_HEIGHT = 525;
    parameter ACTIVE_WIDTH = 640;
    parameter ACTIVE_HEIGHT = 480;
    parameter H_SYNC_COLUMN = 704;
    parameter V_SYNC_LINE = 523;
    
    reg [11:0] pixel_pos_h;
    reg [11:0] pixel_pos_v;
    
    //step pixel position throughout the screen
    always @(posedge pixel_clk)
        begin
          if (pixel_pos_h < TOTAL_WIDTH-1)
            begin
                pixel_pos_h <= pixel_pos_h + 1;
            end
          else
            begin
                pixel_pos_h <= 0;
                if (pixel_pos_v < TOTAL_HEIGHT-1)
                  begin
                    pixel_pos_v <= pixel_pos_v + 1;
                  end
                else
                  begin
                    pixel_pos_v <= 0;
                  end
 
            end 
        end
        
    //Horizontal sync
    always @(posedge pixel_clk)
        begin
          if (pixel_pos_h < H_SYNC_COLUMN)
            begin
                hsync = 1;
            end
          else
            begin
                hsync = 0;
            end  
        end
 
    //Vertical sync
    always @(posedge pixel_clk)
        begin
          if (pixel_pos_v < V_SYNC_LINE)
            begin
                vsync = 1;
            end
          else
            begin
                vsync = 0;
            end  
        end
         
    //Colour On/Off
    always @(posedge pixel_clk)
        begin
          if ((pixel_pos_h >= 49 & pixel_pos_h < 689) & (pixel_pos_v >= 15 & pixel_pos_v < 495))  
            begin
                vga_r = 4'b1111;
                vga_g = 4'b1111;
                vga_b = 4'b1111;
                
           end
          else
            begin
                vga_r = 0;
                vga_g = 0;
                vga_b = 0;
            end  
        end
endmodule
