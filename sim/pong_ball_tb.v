`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Nathan Cinco
//
// Module Name: pong_ball_tb
// Project Name: FPGA Pong
// Description:
//   Integration smoke test for the pong_ball top level. Drives the real
//   board-level inputs (100 MHz clock, reset, the four pushbuttons) through
//   the actual clk_gen -> sync_debouncer -> vga_sync chain and confirms each
//   physical button moves the CORRECT paddle in the CORRECT direction. This
//   targets the position->direction mapping at the four debouncer
//   instantiations in pong_ball.v, which is pure structural wiring with no
//   other test -- a swapped btn_out (wrong paddle or wrong direction) is
//   invisible to the per-module testbenches and would only show up here.
//
//   Expected mapping (see pong_ball.v):
//     top_btn    -> LEFT  paddle UP   (left_paddle_y  decreases)
//     left_btn   -> LEFT  paddle DOWN (left_paddle_y  increases)
//     right_btn  -> RIGHT paddle UP   (right_paddle_y decreases)
//     bottom_btn -> RIGHT paddle DOWN (right_paddle_y increases)
//
//   Notes:
//   - Each debouncer's STABLE_COUNT is shrunk via defparam so debounce
//     completes in a handful of clocks instead of ~250000. This test is about
//     WIRING, not debounce timing (which sync_debouncer_tb already covers), so
//     the real count would only make the sim slower without testing anything
//     new here. Frame geometry and all paddle parameters are left at their
//     real values, so the once-per-frame paddle step behaves exactly as on
//     hardware.
//   - Buttons are pressed one at a time; after each, the test waits a fixed,
//     wiring-independent interval (debounce + one structural end_of_frame
//     tick) and checks the resulting paddle deltas directly -- it does NOT
//     wait on the button's own debounced net, which would assume the very
//     wiring under test.
//////////////////////////////////////////////////////////////////////////////////
module pong_ball_tb;

    localparam CLK_PERIOD = 10;   // 100 MHz board clock
    localparam DBNC       = 10;   // shrunk debounce STABLE_COUNT (see header)

    reg clock_100MHz;
    reg reset;
    reg new_game;
    reg left_btn, top_btn, bottom_btn, right_btn;

    wire hsync, vsync;
    wire [3:0] vga_r, vga_g, vga_b;

    integer errors = 0;

    reg [11:0] lp0, rp0;   // paddle snapshots taken before each button press

    // ---- DUT ----
    pong_ball dut (
        .clock_100MHz (clock_100MHz),
        .reset        (reset),
        .left_btn     (left_btn),
        .top_btn      (top_btn),
        .bottom_btn   (bottom_btn),
        .right_btn    (right_btn),
        .new_game     (new_game),
        .hsync        (hsync),
        .vsync        (vsync),
        .vga_r        (vga_r),
        .vga_g        (vga_g),
        .vga_b        (vga_b)
    );

    // Shrink debounce on all four buttons (wiring test, not a timing test).
    defparam dut.left_btn_debouncer.STABLE_COUNT   = DBNC;
    defparam dut.top_btn_debouncer.STABLE_COUNT    = DBNC;
    defparam dut.bottom_btn_debouncer.STABLE_COUNT = DBNC;
    defparam dut.right_btn_debouncer.STABLE_COUNT  = DBNC;

    // ---- clock ----
    initial clock_100MHz = 1'b0;
    always #(CLK_PERIOD/2) clock_100MHz = ~clock_100MHz;

    // ---- helpers ----
    // Advance to the next once-per-frame paddle update and return after it has
    // committed. end_of_frame is a structural frame tick, independent of the
    // button wiring under test, so using it here is not circular. The paddle
    // move happens on the pixel_clk posedge AFTER end_of_frame asserts; the
    // trailing negedge settles past that edge's NBA region before we read.
    task step_frame_move;
        begin
            @(posedge dut.sync_generator.end_of_frame);
            @(posedge dut.pixel_clk);
            @(negedge dut.pixel_clk);
        end
    endtask

    task check_move(input [383:0] label, input dir_ok, input other_unchanged,
                    input [11:0] before, input [11:0] after);
        begin
            if (dir_ok && other_unchanged)
                $display("[PASS] %0s : %0d -> %0d", label, before, after);
            else begin
                $display("[FAIL] %0s : %0d -> %0d (dir_ok=%b other_paddle_unchanged=%b)",
                         label, before, after, dir_ok, other_unchanged);
                errors = errors + 1;
            end
        end
    endtask

    // Press one button, wait a wiring-independent interval (debounce + one
    // frame tick), check the paddle response, then release and let the
    // debouncer return to idle before the caller moves on.
    task apply_button(input integer sel);
        reg [11:0] lpn, rpn;
        begin
            lp0 = dut.sync_generator.left_paddle_y;
            rp0 = dut.sync_generator.right_paddle_y;

            case (sel)
                0: top_btn    = 1'b1;
                1: left_btn   = 1'b1;
                2: right_btn  = 1'b1;
                3: bottom_btn = 1'b1;
            endcase

            // Deterministic debounce settle (independent of which net it drives).
            repeat (2*DBNC + 10) @(posedge dut.pixel_clk);

            // One structural frame tick applies the paddle move.
            step_frame_move;

            lpn = dut.sync_generator.left_paddle_y;
            rpn = dut.sync_generator.right_paddle_y;

            case (sel)
                0: check_move("top_btn -> LEFT paddle UP",      lpn < lp0, rpn == rp0, lp0, lpn);
                1: check_move("left_btn -> LEFT paddle DOWN",   lpn > lp0, rpn == rp0, lp0, lpn);
                2: check_move("right_btn -> RIGHT paddle UP",   rpn < rp0, lpn == lp0, rp0, rpn);
                3: check_move("bottom_btn -> RIGHT paddle DOWN", rpn > rp0, lpn == lp0, rp0, rpn);
            endcase

            // Release and let the debouncer recognize it, so a still-high net
            // can't bleed into the next button's check.
            top_btn = 0; left_btn = 0; right_btn = 0; bottom_btn = 0;
            repeat (2*DBNC + 10) @(posedge dut.pixel_clk);
        end
    endtask

    // ---- stimulus ----
    initial begin
        clock_100MHz = 1'b0;
        reset        = 1'b1;
        new_game     = 1'b0;
        top_btn = 0; left_btn = 0; right_btn = 0; bottom_btn = 0;

        repeat (8) @(posedge clock_100MHz);
        reset = 1'b0;
        @(negedge dut.pixel_clk);   // let the clock divider start running

        // Sanity: reset centers both paddles.
        if (dut.sync_generator.left_paddle_y !== dut.sync_generator.PADDLE_Y_MAX/2 ||
            dut.sync_generator.right_paddle_y !== dut.sync_generator.PADDLE_Y_MAX/2) begin
            $display("[FAIL] reset_centers_paddles : L=%0d R=%0d expected=%0d",
                     dut.sync_generator.left_paddle_y, dut.sync_generator.right_paddle_y,
                     dut.sync_generator.PADDLE_Y_MAX/2);
            errors = errors + 1;
        end else
            $display("[PASS] reset_centers_paddles : both at %0d",
                     dut.sync_generator.PADDLE_Y_MAX/2);

        apply_button(0);   // top_btn    -> left  up
        apply_button(1);   // left_btn   -> left  down
        apply_button(2);   // right_btn  -> right up
        apply_button(3);   // bottom_btn -> right down

        if (errors == 0)
            $display("==== ALL TESTS PASSED ====");
        else
            $display("==== %0d TEST(S) FAILED ====", errors);
        $finish;
    end

    // ---- safety timeout ----
    // Generous: at most ~one real frame (800x525 pixel clocks) per button,
    // plus margin. A hang here means a button never produced any paddle move.
    initial begin
        #150000000;
        $display("[FATAL] timeout -- a button produced no paddle movement (mis-wired?)");
        $finish;
    end

endmodule
