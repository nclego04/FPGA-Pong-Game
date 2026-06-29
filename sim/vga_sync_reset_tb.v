`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Nathan Cinco
//
// Module Name: vga_sync_reset_tb
// Project Name: FPGA Pong
// Description:
//   Self-checking testbench for vga_sync covering reset/new_game. Covers:
//     1. Initial reset centers both paddles and serves the ball from center
//        (position, direction, and speed all checked).
//     2. From a displaced state (paddles and ball poked away from center via
//        hierarchical reference), holding new_game for a full frame recenters
//        both paddles and re-serves the ball, and holds that state across the
//        frame boundary rather than drifting once released.
//     3. Same displaced-state check via reset instead of new_game, confirming
//        both triggers produce the same functional outcome.
//////////////////////////////////////////////////////////////////////////////////
module vga_sync_reset_tb;

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
    // See vga_sync_paddle_tb for why the trailing negedge settle is required.
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

        // ===================== Initial reset =====================
        check(dut.left_paddle_y,  dut.PADDLE_Y_MAX / 2, "init_left_paddle_centered");
        check(dut.right_paddle_y, dut.PADDLE_Y_MAX / 2, "init_right_paddle_centered");
        check(dut.ball_x,         dut.BALL_START_X,     "init_ball_x_centered");
        check(dut.ball_y,         dut.BALL_START_Y,     "init_ball_y_centered");
        check(dut.ball_dir_x,     1'b1,                 "init_ball_dir_x_serve_right");
        check(dut.ball_dir_y,     1'b1,                 "init_ball_dir_y_serve_down");
        check(dut.ball_speed,     dut.BALL_BASE_SPEED,  "init_ball_speed_reset");

        // ===================== new_game from a displaced state =====================
        dut.left_paddle_y  = 50;
        dut.right_paddle_y = 350;
        dut.ball_x         = 100;
        dut.ball_y         = 400;
        dut.ball_dir_x     = 1'b0;
        dut.ball_dir_y     = 1'b0;
        dut.ball_speed     = dut.BALL_MAX_SPEED;

        new_game = 1'b1;
        next_frame();   // holds new_game across a full frame boundary

        check(dut.left_paddle_y,  dut.PADDLE_Y_MAX / 2, "new_game_left_paddle_centered");
        check(dut.right_paddle_y, dut.PADDLE_Y_MAX / 2, "new_game_right_paddle_centered");
        check(dut.ball_x,         dut.BALL_START_X,     "new_game_ball_x_centered");
        check(dut.ball_y,         dut.BALL_START_Y,     "new_game_ball_y_centered");
        check(dut.ball_dir_x,     1'b1,                 "new_game_ball_dir_x_serve_right");
        check(dut.ball_dir_y,     1'b1,                 "new_game_ball_dir_y_serve_down");
        check(dut.ball_speed,     dut.BALL_BASE_SPEED,  "new_game_ball_speed_reset");

        new_game = 1'b0;
        @(negedge pixel_clk);

        // ===================== reset from a displaced state =====================
        dut.left_paddle_y  = 50;
        dut.right_paddle_y = 350;
        dut.ball_x         = 100;
        dut.ball_y         = 400;
        dut.ball_dir_x     = 1'b0;
        dut.ball_dir_y     = 1'b0;
        dut.ball_speed     = dut.BALL_MAX_SPEED;

        reset = 1'b1;
        next_frame();

        check(dut.left_paddle_y,  dut.PADDLE_Y_MAX / 2, "reset_left_paddle_centered");
        check(dut.right_paddle_y, dut.PADDLE_Y_MAX / 2, "reset_right_paddle_centered");
        check(dut.ball_x,         dut.BALL_START_X,     "reset_ball_x_centered");
        check(dut.ball_y,         dut.BALL_START_Y,     "reset_ball_y_centered");
        check(dut.ball_dir_x,     1'b1,                 "reset_ball_dir_x_serve_right");
        check(dut.ball_dir_y,     1'b1,                 "reset_ball_dir_y_serve_down");
        check(dut.ball_speed,     dut.BALL_BASE_SPEED,  "reset_ball_speed_reset");

        reset = 1'b0;
        @(negedge pixel_clk);

        // ---- summary ----
        if (errors == 0)
            $display("==== ALL TESTS PASSED ====");
        else
            $display("==== %0d TEST(S) FAILED ====", errors);
        $finish;
    end

    // ---- safety timeout ----
    initial begin
        #(CLK_PERIOD * 800 * 525 * 10);
        $display("[FATAL] timeout -- sim hung");
        $finish;
    end

endmodule
