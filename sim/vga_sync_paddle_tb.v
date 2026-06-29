`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Nathan Cinco
//
// Module Name: vga_sync_paddle_tb
// Project Name: FPGA Pong
// Description:
//   Self-checking testbench for vga_sync covering paddle clamping. Paddle
//   position registers are poked directly via hierarchical reference to set
//   up edge-case starting positions without waiting through dozens of real
//   frames; each scenario then advances exactly one frame (confirmed by
//   vga_sync_timing_tb to be exactly TOTAL_WIDTH*TOTAL_HEIGHT pixel_clk
//   periods) and checks the resulting position. Covers, for both paddles:
//     - Holding up/down clamps flush to 0 / PADDLE_Y_MAX without underflow
//       or overshoot, and the clamp holds on a subsequent frame.
//     - A normal (non-boundary) step still moves by MOVE_STEP, so the clamp
//       doesn't fire away from the edges.
//     - Simultaneous up+down: the design's if/else-if structure gives "up"
//       priority over "down" -- verified here as the intended behavior.
//////////////////////////////////////////////////////////////////////////////////
module vga_sync_paddle_tb;

    localparam CLK_PERIOD = 40;   // 25 MHz pixel clock

    reg reset, new_game;
    reg pixel_clk;
    reg left_btn_up, left_btn_down, right_btn_up, right_btn_down;

    wire hsync, vsync;
    wire [3:0] vga_r, vga_g, vga_b;

    integer errors = 0;

    // ---- DUT ----
    vga_sync dut (
        .reset          (reset),
        .new_game       (new_game),
        .pixel_clk      (pixel_clk),
        .left_btn_up    (left_btn_up),
        .left_btn_down  (left_btn_down),
        .right_btn_up   (right_btn_up),
        .right_btn_down (right_btn_down),
        .hsync          (hsync),
        .vsync          (vsync),
        .vga_r          (vga_r),
        .vga_g          (vga_g),
        .vga_b          (vga_b)
    );

    // ---- clock ----
    initial pixel_clk = 1'b0;
    always #(CLK_PERIOD/2) pixel_clk = ~pixel_clk;

    // ---- helpers ----
    // One frame == TOTAL_WIDTH*TOTAL_HEIGHT pixel_clk periods. Paddle
    // position only updates on the last cycle of a frame, so waiting this
    // many edges lands exactly on the next update. The trailing negedge wait
    // is essential, not cosmetic: it lets the DUT's own non-blocking write
    // from that edge land in the NBA region before we read/poke the
    // register again, otherwise our poke in the active region of the same
    // time step would be silently clobbered by it.
    task next_frame;
        begin
            repeat (dut.TOTAL_WIDTH * dut.TOTAL_HEIGHT) @(posedge pixel_clk);
            @(negedge pixel_clk);
        end
    endtask

    task check(input [11:0] actual, input [11:0] expected, input [383:0] label);
        begin
            if (actual !== expected) begin
                $display("[FAIL] %0s : actual=%0d expected=%0d @%0t",
                         label, actual, expected, $time);
                errors = errors + 1;
            end else
                $display("[PASS] %0s : %0d @%0t", label, actual, $time);
        end
    endtask

    // ---- stimulus ----
    initial begin
        reset          = 1'b1;
        new_game       = 1'b0;
        left_btn_up    = 1'b0;
        left_btn_down  = 1'b0;
        right_btn_up   = 1'b0;
        right_btn_down = 1'b0;

        repeat (3) @(posedge pixel_clk);
        reset = 1'b0;
        @(negedge pixel_clk);   // settle past that edge's NBA region

        check(dut.left_paddle_y,  dut.PADDLE_Y_MAX / 2, "reset_left_centered");
        check(dut.right_paddle_y, dut.PADDLE_Y_MAX / 2, "reset_right_centered");

        // ===================== LEFT PADDLE =====================

        // Top clamp: starts just below MOVE_STEP, must snap to 0, not underflow.
        dut.left_paddle_y = 2;
        left_btn_up = 1'b1; left_btn_down = 1'b0;
        next_frame();
        check(dut.left_paddle_y, 12'd0, "left_top_clamp_no_underflow");

        // Clamp holds on a further frame of the same input.
        next_frame();
        check(dut.left_paddle_y, 12'd0, "left_top_clamp_holds");

        // Bottom clamp: starts just above PADDLE_Y_MAX-MOVE_STEP, must snap
        // to PADDLE_Y_MAX, not overshoot off-screen.
        dut.left_paddle_y = dut.PADDLE_Y_MAX - 2;
        left_btn_up = 1'b0; left_btn_down = 1'b1;
        next_frame();
        check(dut.left_paddle_y, dut.PADDLE_Y_MAX, "left_bottom_clamp_no_overshoot");

        next_frame();
        check(dut.left_paddle_y, dut.PADDLE_Y_MAX, "left_bottom_clamp_holds");

        // Normal step away from either edge: clamp must not fire early.
        dut.left_paddle_y = 200;
        left_btn_up = 1'b1; left_btn_down = 1'b0;
        next_frame();
        check(dut.left_paddle_y, 12'd196, "left_normal_step_up");

        dut.left_paddle_y = 200;
        left_btn_up = 1'b0; left_btn_down = 1'b1;
        next_frame();
        check(dut.left_paddle_y, 12'd204, "left_normal_step_down");

        // Simultaneous up+down: design priority is up wins (if/else-if).
        dut.left_paddle_y = 200;
        left_btn_up = 1'b1; left_btn_down = 1'b1;
        next_frame();
        check(dut.left_paddle_y, 12'd196, "left_simultaneous_up_wins");
        left_btn_up = 1'b0; left_btn_down = 1'b0;

        // ===================== RIGHT PADDLE =====================

        dut.right_paddle_y = 2;
        right_btn_up = 1'b1; right_btn_down = 1'b0;
        next_frame();
        check(dut.right_paddle_y, 12'd0, "right_top_clamp_no_underflow");

        next_frame();
        check(dut.right_paddle_y, 12'd0, "right_top_clamp_holds");

        dut.right_paddle_y = dut.PADDLE_Y_MAX - 2;
        right_btn_up = 1'b0; right_btn_down = 1'b1;
        next_frame();
        check(dut.right_paddle_y, dut.PADDLE_Y_MAX, "right_bottom_clamp_no_overshoot");

        next_frame();
        check(dut.right_paddle_y, dut.PADDLE_Y_MAX, "right_bottom_clamp_holds");

        dut.right_paddle_y = 200;
        right_btn_up = 1'b1; right_btn_down = 1'b0;
        next_frame();
        check(dut.right_paddle_y, 12'd196, "right_normal_step_up");

        dut.right_paddle_y = 200;
        right_btn_up = 1'b0; right_btn_down = 1'b1;
        next_frame();
        check(dut.right_paddle_y, 12'd204, "right_normal_step_down");

        dut.right_paddle_y = 200;
        right_btn_up = 1'b1; right_btn_down = 1'b1;
        next_frame();
        check(dut.right_paddle_y, 12'd196, "right_simultaneous_up_wins");
        right_btn_up = 1'b0; right_btn_down = 1'b0;

        // ---- summary ----
        if (errors == 0)
            $display("==== ALL TESTS PASSED ====");
        else
            $display("==== %0d TEST(S) FAILED ====", errors);
        $finish;
    end

    // ---- safety timeout ----
    initial begin
        #(CLK_PERIOD * 800 * 525 * 25);
        $display("[FATAL] timeout -- sim hung");
        $finish;
    end

endmodule
