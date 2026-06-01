`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Nathan Cinco
// 
// Create Date: 05/31/2026 04:22:08 PM
// Module Name: vga_sync
// Project Name: FPGA Pong
// Target Devices: Nexys A7-100T
// Description: 
// Generates VESA-compliant VGA synchronization signals (HSYNC/VSYNC) for a 
// 640x480 @ 60Hz resolution. Includes custom front/back porch offsets manually 
// calibrated to perfectly center the active video area on the target LCD monitor.
//
//////////////////////////////////////////////////////////////////////////////////

module vga_sync(
    input pixel_clk,     // 25 MHz pixel clock from system clock divider
    output reg hsync,    // Active-low horizontal synchronization pulse
    output reg vsync,    // Active-low vertical synchronization pulse
    output reg [3:0] vga_r, // 4-bit Red video signal
    output reg [3:0] vga_g, // 4-bit Green video signal
    output reg [3:0] vga_b  // 4-bit Blue video signal
    );
    
    // -------------------------------------------------------------------------
    // VGA Timing Parameters (640x480 @ 60Hz)
    // -------------------------------------------------------------------------
    // The monitor scans a total invisible canvas of 800x525.
    parameter TOTAL_WIDTH = 800;
    parameter TOTAL_HEIGHT = 525;

    // The physical visible resolution
    parameter ACTIVE_WIDTH = 640;
    parameter ACTIVE_HEIGHT = 480;
    
    // Sync pulses trigger at the end of the front porch.
    // HSYNC triggers at pixel 704 (lasts 96 pixels). VSYNC triggers at line 523 (lasts 2 lines).
    parameter H_SYNC_COLUMN = 704;
    parameter V_SYNC_LINE = 523;
    
    // Internal counters to track the current beam/pixel location on the screen
    reg [11:0] pixel_pos_h;
    reg [11:0] pixel_pos_v;
    
    // -------------------------------------------------------------------------
    // Pixel & Line Counters
    // -------------------------------------------------------------------------
    // Scans left-to-right (0 to 799). Upon reaching the end of a line, 
    // resets X to 0 and increments the Y line counter. 
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
        
    // -------------------------------------------------------------------------
    // Synchronization Pulse Generation
    // -------------------------------------------------------------------------
    // VESA standard 640x480 requires Active-Low sync pulses.
    // Signals idle HIGH (1) during active video and porches, and drop LOW (0) to sync.
    
    // Horizontal sync: Drops low from pixel 704 to 799 (96 pixels wide)
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
 
    // Vertical sync: Drops low from line 523 to 524 (2 lines wide)
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
         
    // -------------------------------------------------------------------------
    // Active Video Area & Color Output
    // -------------------------------------------------------------------------
    // Acts as a spatial stencil. Color data is only driven to the physical pins 
    // if the current X/Y coordinates fall strictly within the visible boundaries.
    always @(posedge pixel_clk)
        begin
          // Note: Porch boundaries deviate slightly from VESA standard (48/33) 
          // to compensate for LCD scaler mismatch and center the image.
          // Horizontal visible range: 49 to 688 (exactly 640 pixels wide).
          // Vertical visible range: 15 to 494 (exactly 480 lines tall).
          if ((pixel_pos_h >= 49 & pixel_pos_h < 689) & (pixel_pos_v >= 15 & pixel_pos_v < 495))  
            begin
                vga_r = 4'b1111; // Drive full white
                vga_g = 4'b1111;
                vga_b = 4'b1111;
           end
          else
            begin
                // Output must be completely black during Front Porch, Sync, and Back Porch
                vga_r = 0;
                vga_g = 0;
                vga_b = 0;
            end  
        end
endmodule
