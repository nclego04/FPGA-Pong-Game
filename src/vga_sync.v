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
// 640x480 @ 60Hz resolution, plus two player-controlled paddles. Includes custom
// front/back porch offsets manually calibrated to center the active video area
// on the target LCD monitor.
//
// NOTE: Button inputs are expected to be ALREADY synchronized and debounced
// upstream (see sync_debouncer in the top level). This module uses them directly.
//
//////////////////////////////////////////////////////////////////////////////////

module vga_sync(
    input reset,
    input pixel_clk,     // 25 MHz pixel clock from system clock divider
    input left_btn_up,   // pre-synchronized, debounced button levels
    input left_btn_down,
    input right_btn_up,
    input right_btn_down,

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
    parameter TOTAL_WIDTH  = 800;
    parameter TOTAL_HEIGHT = 525;

    // The physical visible resolution
    parameter ACTIVE_WIDTH  = 640;
    parameter ACTIVE_HEIGHT = 480;

    // Porch widths
    parameter H_BACK_PORCH  = 49;   // pixels before active area begins
    parameter H_FRONT_PORCH = 15;   // pixels after active area ends

    parameter V_BACK_PORCH  = 15;   // lines before active area begins
    parameter V_FRONT_PORCH = 28;   // lines after active area ends

    // Sync pulses trigger at the end of the front porch.
    // HSYNC triggers at pixel 704 (lasts 96 pixels). VSYNC triggers at line 523 (lasts 2 lines).
    parameter H_ACTIVE_END  = H_BACK_PORCH + ACTIVE_WIDTH;   // 689
    parameter H_SYNC_COLUMN = H_ACTIVE_END + H_FRONT_PORCH;  // 704

    parameter V_ACTIVE_END  = V_BACK_PORCH + ACTIVE_HEIGHT;  // 495
    parameter V_SYNC_LINE   = V_ACTIVE_END + V_FRONT_PORCH;  // 523

    // -------------------------------------------------------------------------
    // Paddle geometry
    // -------------------------------------------------------------------------
    parameter PADDLE_WIDTH   = 7;    // paddle thickness in pixels
    parameter PADDLE_HEIGHT  = 80;   // paddle length
    parameter LEFT_PADDLE_X  = 20;   // left paddle distance from left edge
    parameter RIGHT_PADDLE_X = ACTIVE_WIDTH - 20 - PADDLE_WIDTH;  // mirrored
    parameter MOVE_STEP      = 4;    // pixels moved per frame while held

    // Lowest valid top-edge position for a paddle (keeps it on screen)
    parameter PADDLE_Y_MAX = ACTIVE_HEIGHT - PADDLE_HEIGHT;

    // -------------------------------------------------------------------------
    // Internal counters to track the current beam/pixel location on the screen
    // -------------------------------------------------------------------------
    reg [11:0] pixel_pos_h;
    reg [11:0] pixel_pos_v;

    // -------------------------------------------------------------------------
    // Pixel & Line Counters
    // Scans left-to-right (0 to TOTAL_WIDTH-1). On reaching the end of a line,
    // resets X to 0 and increments the Y line counter.
    // -------------------------------------------------------------------------
    always @(posedge pixel_clk) begin
        if (reset) begin
            pixel_pos_h <= 12'b0;
            pixel_pos_v <= 12'b0;
        end else if (pixel_pos_h < TOTAL_WIDTH - 1) begin
            pixel_pos_h <= pixel_pos_h + 1;
        end else begin
            pixel_pos_h <= 0;
            if (pixel_pos_v < TOTAL_HEIGHT - 1)
                pixel_pos_v <= pixel_pos_v + 1;
            else
                pixel_pos_v <= 0;
        end
    end

    // Active-area coordinates (valid ONLY inside the active window; they
    // underflow to large values during porches/sync, so always gate their use
    // with the active-region test below).
    wire [11:0] active_x = pixel_pos_h - H_BACK_PORCH;  // 0..ACTIVE_WIDTH-1
    wire [11:0] active_y = pixel_pos_v - V_BACK_PORCH;  // 0..ACTIVE_HEIGHT-1

    // -------------------------------------------------------------------------
    // Paddle position registers (top edge, movable)
    // -------------------------------------------------------------------------
    reg [11:0] left_paddle_y;
    reg [11:0] right_paddle_y;

    wire left_on  = (active_x >= LEFT_PADDLE_X)  & (active_x < LEFT_PADDLE_X + PADDLE_WIDTH) &
                    (active_y >= left_paddle_y)  & (active_y < left_paddle_y + PADDLE_HEIGHT);

    wire right_on = (active_x >= RIGHT_PADDLE_X) & (active_x < RIGHT_PADDLE_X + PADDLE_WIDTH) &
                    (active_y >= right_paddle_y) & (active_y < right_paddle_y + PADDLE_HEIGHT);

    // -------------------------------------------------------------------------
    // Synchronization Pulse Generation (active-low; idle HIGH, drop LOW to sync)
    // VESA timing defines hsync/vsync as active-low: the line must stay high
    // through back porch + active video + front porch, and only pulses low
    // for the dedicated sync width (H_SYNC_COLUMN..TOTAL_WIDTH-1 /
    // V_SYNC_LINE..TOTAL_HEIGHT-1) for the monitor to lock onto the timing.
    // -------------------------------------------------------------------------
    always @(posedge pixel_clk) begin
        if (reset)
            hsync <= 1'b1;
        else if (pixel_pos_h < H_SYNC_COLUMN)
            hsync <= 1'b1;
        else
            hsync <= 1'b0;
    end

    always @(posedge pixel_clk) begin
        if (reset)
            vsync <= 1'b1;
        else if (pixel_pos_v < V_SYNC_LINE)
            vsync <= 1'b1;
        else
            vsync <= 1'b0;
    end

    // -------------------------------------------------------------------------
    // Paddle movement: update once per frame at end_of_frame, not every pixel
    // clock, so paddle speed is a fixed number of pixels per visible frame
    // (~60 Hz) regardless of pixel clock rate, instead of moving at an
    // imperceptibly fast, clock-rate-dependent speed.
    // Boundaries clamp the paddle flush to top (0) and bottom (PADDLE_Y_MAX)
    // without underflowing. Buttons arrive already synchronized/debounced.
    // -------------------------------------------------------------------------
    wire end_of_frame = (pixel_pos_h == TOTAL_WIDTH - 1) & (pixel_pos_v == TOTAL_HEIGHT - 1);

    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            left_paddle_y  <= PADDLE_Y_MAX / 2;   // center
            right_paddle_y <= PADDLE_Y_MAX / 2;
        end else if (end_of_frame) begin
            // ----- Left paddle -----
            if (left_btn_up) begin
                if (left_paddle_y >= MOVE_STEP)
                    left_paddle_y <= left_paddle_y - MOVE_STEP;
                else
                    left_paddle_y <= 0;                 // snap to top
            end else if (left_btn_down) begin
                if (left_paddle_y <= PADDLE_Y_MAX - MOVE_STEP)
                    left_paddle_y <= left_paddle_y + MOVE_STEP;
                else
                    left_paddle_y <= PADDLE_Y_MAX;      // snap to bottom
            end

            // ----- Right paddle -----
            if (right_btn_up) begin
                if (right_paddle_y >= MOVE_STEP)
                    right_paddle_y <= right_paddle_y - MOVE_STEP;
                else
                    right_paddle_y <= 0;
            end else if (right_btn_down) begin
                if (right_paddle_y <= PADDLE_Y_MAX - MOVE_STEP)
                    right_paddle_y <= right_paddle_y + MOVE_STEP;
                else
                    right_paddle_y <= PADDLE_Y_MAX;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Active Video Area & Color Output
    // Color is only driven inside the visible boundaries. Paddles are given
    // distinct, saturated colors (red/blue) so each player's paddle is
    // unambiguous on the monitor; blanking must output black (0) because
    // VESA prohibits driving active video levels during the porch/sync
    // intervals.
    // -------------------------------------------------------------------------
    always @(posedge pixel_clk) begin
        if (reset) begin
            vga_r <= 4'b0000;
            vga_g <= 4'b0000;
            vga_b <= 4'b0000;
        end else if ((pixel_pos_h >= H_BACK_PORCH) & (pixel_pos_h < H_ACTIVE_END) &
                     (pixel_pos_v >= V_BACK_PORCH) & (pixel_pos_v < V_ACTIVE_END)) begin
            if (left_on) begin
                vga_r <= 4'b1111;   // left paddle = red
                vga_g <= 4'b0000;
                vga_b <= 4'b0000;
            end else if (right_on) begin
                vga_r <= 4'b0000;   // right paddle = blue
                vga_g <= 4'b0000;
                vga_b <= 4'b1111;
            end else begin
                vga_r <= 4'b1111;   // background = white
                vga_g <= 4'b1111;
                vga_b <= 4'b1111;
            end
        end else begin
            vga_r <= 4'b0000;       // blanking (porch/sync) = black
            vga_g <= 4'b0000;
            vga_b <= 4'b0000;
        end
    end

endmodule
