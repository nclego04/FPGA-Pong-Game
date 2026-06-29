`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Nathan Cinco
//
// Module Name: vga_sync_ball_tb
// Project Name: FPGA Pong
// Description:
//   Self-checking testbench for vga_sync covering ball physics. Ball state
//   (ball_x/y, ball_dir_x/y, ball_speed) is poked directly via hierarchical
//   reference -- mostly using expressions relative to the DUT's own
//   parameters/registers (e.g. "ball_x = LEFT_PADDLE_X") rather than literal
//   numbers, so each scenario sets up exactly the boundary condition it's
//   testing regardless of the actual parameter values. Each scenario then
//   advances exactly one frame (settling at the following negedge, same
//   race-avoidance pattern as vga_sync_paddle_tb) and checks the result.
//   Covers:
//     - Top/bottom wall bounce.
//     - Normal horizontal/vertical steps away from any wall/paddle (sanity,
//       to confirm bounce/hit logic doesn't fire away from the edges).
//     - Paddle hit on either side: direction reverses, position snaps flush
//       to the paddle face, and speed increments.
//     - BALL_MAX_SPEED cap: a hit at max speed does not increment further.
//     - Hit takes priority over relaunch when both are geometrically true
//       (forced via an artificial speed, since real gameplay speed can't
//       reach this condition with BALL_MAX_SPEED this small).
//     - Serve-on-miss on either edge: recenters, resets speed, and serves
//       away from the edge that was reached.
//////////////////////////////////////////////////////////////////////////////////
module vga_sync_ball_tb;

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
    // See vga_sync_paddle_tb for why the trailing negedge settle is required:
    // it lets the DUT's own NBA write from the update edge land before we
    // poke/read state again, avoiding a same-time-step race.
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

        // ===================== Wall bounces =====================

        // Top wall: positioned exactly at the bounce threshold.
        dut.ball_speed = 2;
        dut.ball_dir_y = 1'b0;               // moving up
        dut.ball_y     = dut.ball_speed;
        next_frame();
        check(dut.ball_y,     12'd0, "ball_top_wall_bounce_y");
        check(dut.ball_dir_y, 1'b1,  "ball_top_wall_bounce_dir");

        // Bottom wall: positioned exactly at the bounce threshold.
        dut.ball_speed = 2;
        dut.ball_dir_y = 1'b1;               // moving down
        dut.ball_y     = dut.ACTIVE_HEIGHT - dut.BALL_SIZE - dut.ball_speed;
        next_frame();
        check(dut.ball_y,     dut.ACTIVE_HEIGHT - dut.BALL_SIZE, "ball_bottom_wall_bounce_y");
        check(dut.ball_dir_y, 1'b0,                              "ball_bottom_wall_bounce_dir");

        // ===================== Normal steps (sanity) =====================
        // Mid-screen, far from any wall/paddle: bounce/hit logic must not fire.

        dut.ball_speed = 2;
        dut.ball_dir_y = 1'b1;
        dut.ball_y     = 200;
        next_frame();
        check(dut.ball_y, 12'd202, "ball_normal_step_down");

        dut.ball_dir_y = 1'b0;
        dut.ball_y     = 200;
        next_frame();
        check(dut.ball_y, 12'd198, "ball_normal_step_up");

        dut.ball_dir_x = 1'b1;
        dut.ball_x     = 300;
        dut.ball_y     = 50;
        next_frame();
        check(dut.ball_x, 12'd302, "ball_normal_step_right");

        dut.ball_dir_x = 1'b0;
        dut.ball_x     = 300;
        next_frame();
        check(dut.ball_x, 12'd298, "ball_normal_step_left");

        // ===================== Paddle hits =====================

        // Left paddle: ball_x/y set relative to LEFT_PADDLE_X/left_paddle_y so
        // the hit condition holds regardless of the actual parameter values.
        dut.ball_dir_x = 1'b0;               // moving left
        dut.ball_speed = dut.BALL_BASE_SPEED + 1;   // not at the cap
        dut.ball_x     = dut.LEFT_PADDLE_X;
        dut.ball_y     = dut.left_paddle_y;         // guaranteed vertical overlap
        next_frame();
        check(dut.ball_dir_x, 1'b1, "ball_left_paddle_hit_dir");
        check(dut.ball_x, dut.LEFT_PADDLE_X + dut.PADDLE_WIDTH, "ball_left_paddle_hit_snap");
        check(dut.ball_speed, dut.BALL_BASE_SPEED + 2, "ball_left_paddle_hit_speedup");

        // Right paddle: mirrored.
        dut.ball_dir_x = 1'b1;               // moving right
        dut.ball_speed = dut.BALL_BASE_SPEED + 1;
        dut.ball_x     = dut.RIGHT_PADDLE_X;
        dut.ball_y     = dut.right_paddle_y;
        next_frame();
        check(dut.ball_dir_x, 1'b0, "ball_right_paddle_hit_dir");
        check(dut.ball_x, dut.RIGHT_PADDLE_X - dut.BALL_SIZE, "ball_right_paddle_hit_snap");
        check(dut.ball_speed, dut.BALL_BASE_SPEED + 2, "ball_right_paddle_hit_speedup");

        // ===================== BALL_MAX_SPEED cap =====================

        dut.ball_dir_x = 1'b0;
        dut.ball_speed = dut.BALL_MAX_SPEED;
        dut.ball_x     = dut.LEFT_PADDLE_X;
        dut.ball_y     = dut.left_paddle_y;
        next_frame();
        check(dut.ball_speed, dut.BALL_MAX_SPEED, "ball_speed_capped_at_max");

        // ===================== Hit priority over relaunch =====================
        // Force reach_left_edge and hit_left_paddle to BOTH be geometrically
        // true via an artificially large speed (unreachable with the real
        // BALL_MAX_SPEED). relaunch ANDs in !hit_left_paddle, so if the hit
        // correctly wins, the ball snaps to the paddle face (27) rather than
        // resetting to the center serve position (316) -- that's the one
        // signal that actually distinguishes the two outcomes here, since
        // both paths happen to agree on the resulting direction.
        dut.ball_dir_x = 1'b0;
        dut.ball_speed = dut.LEFT_PADDLE_X + dut.PADDLE_WIDTH;
        dut.ball_x     = dut.LEFT_PADDLE_X;
        dut.ball_y     = dut.left_paddle_y;
        next_frame();
        check(dut.ball_x, dut.LEFT_PADDLE_X + dut.PADDLE_WIDTH,
              "ball_hit_priority_over_relaunch");

        // ===================== Serve-on-miss =====================

        // Right edge missed: move the right paddle out of the way vertically
        // so hit_right_paddle is false, then reach the right edge.
        dut.right_paddle_y = 0;
        dut.ball_y         = dut.ACTIVE_HEIGHT - dut.BALL_SIZE;
        dut.ball_dir_x     = 1'b1;
        dut.ball_dir_y     = 1'b0;
        dut.ball_speed     = dut.BALL_BASE_SPEED + 1;
        dut.ball_x         = dut.ACTIVE_WIDTH - dut.BALL_SIZE - dut.ball_speed;
        next_frame();
        check(dut.ball_x,     dut.BALL_START_X,     "ball_serve_on_miss_right_x");
        check(dut.ball_y,     dut.BALL_START_Y,     "ball_serve_on_miss_right_y");
        check(dut.ball_dir_x, 1'b0,                 "ball_serve_on_miss_right_dir_away_from_edge");
        check(dut.ball_dir_y, 1'b1,                 "ball_serve_on_miss_right_dir_y");
        check(dut.ball_speed, dut.BALL_BASE_SPEED,  "ball_serve_on_miss_right_speed_reset");
        dut.right_paddle_y = dut.PADDLE_Y_MAX / 2;  // restore

        // Left edge missed: mirrored.
        dut.left_paddle_y = 0;
        dut.ball_y         = dut.ACTIVE_HEIGHT - dut.BALL_SIZE;
        dut.ball_dir_x     = 1'b0;
        dut.ball_dir_y     = 1'b0;
        dut.ball_speed     = dut.BALL_BASE_SPEED + 1;
        dut.ball_x         = dut.ball_speed;
        next_frame();
        check(dut.ball_x,     dut.BALL_START_X,     "ball_serve_on_miss_left_x");
        check(dut.ball_y,     dut.BALL_START_Y,     "ball_serve_on_miss_left_y");
        check(dut.ball_dir_x, 1'b1,                 "ball_serve_on_miss_left_dir_away_from_edge");
        check(dut.ball_dir_y, 1'b1,                 "ball_serve_on_miss_left_dir_y");
        check(dut.ball_speed, dut.BALL_BASE_SPEED,  "ball_serve_on_miss_left_speed_reset");
        dut.left_paddle_y = dut.PADDLE_Y_MAX / 2;   // restore

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
