`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Nathan Cinco
//
// Module Name: sync_debouncer_tb
// Project Name: FPGA Pong
// Description:
//   Self-checking testbench for sync_debouncer. STABLE_COUNT is overridden to a
//   small value so bounce/hold timing completes quickly in simulation. Covers:
//     1. Reset behavior
//     2. Clean press accepted after STABLE_COUNT (+ 2-FF sync latency)
//     3. Press bounce during PRESS_WAIT aborts the transition
//     4. Clean release accepted
//     5. Release bounce during RELEASE_WAIT aborts the transition
//     6. Glitch shorter than STABLE_COUNT is rejected entirely
//   A safety timeout kills the sim if it ever hangs.
//////////////////////////////////////////////////////////////////////////////////
module sync_debouncer_tb;

    // Shrunk so a "stable" interval is ~10 clocks instead of 250000.
    localparam STABLE_COUNT = 10;
    localparam CLK_PERIOD   = 40;   // 25 MHz

    reg  clk;
    reg  reset;
    reg  btn_in;
    wire btn_out;

    integer errors = 0;

    // ---- DUT ----
    sync_debouncer #(.STABLE_COUNT(STABLE_COUNT)) dut (
        .clk     (clk),
        .reset   (reset),
        .btn_in  (btn_in),
        .btn_out (btn_out)
    );

    // ---- clock ----
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ---- helpers ----
    // Hold the input at `level` long enough to clear the 2-FF synchronizer and
    // the full STABLE_COUNT, plus margin, so the FSM definitely commits.
    task hold_stable(input level);
        begin
            btn_in = level;
            repeat (STABLE_COUNT + 5) @(posedge clk);
        end
    endtask

    task check(input exp, input [127:0] label);
        begin
            if (btn_out !== exp) begin
                $display("[FAIL] %0s : btn_out=%b expected=%b @%0t",
                         label, btn_out, exp, $time);
                errors = errors + 1;
            end else
                $display("[PASS] %0s : btn_out=%b @%0t", label, btn_out, $time);
        end
    endtask

    // ---- safety timeout ----
    initial begin
        #(CLK_PERIOD * (STABLE_COUNT + 10) * 40);
        $display("[FATAL] timeout -- sim hung");
        $finish;
    end

    // ---- stimulus ----
    initial begin
        btn_in = 1'b0;
        reset  = 1'b1;
        repeat (3) @(posedge clk);

        // Case 1: reset clears output
        check(1'b0, "case1_reset_low");
        reset = 1'b0;
        @(posedge clk);

        // Case 2: clean press
        hold_stable(1'b1);
        @(posedge clk);
        check(1'b1, "case2_clean_press");

        // Case 3: bounce during PRESS_WAIT must abort.
        // Release fully, then start a press but yank it low before STABLE_COUNT.
        hold_stable(1'b0);                 // back to IDLE, btn_out low
        btn_in = 1'b1;
        repeat (STABLE_COUNT - 3) @(posedge clk);  // not long enough
        btn_in = 1'b0;                     // bounce back -> abort to IDLE
        repeat (5) @(posedge clk);
        check(1'b0, "case3_press_bounce_rejected");

        // Case 4: clean release after a confirmed press
        hold_stable(1'b1);
        check(1'b1, "case4_setup_pressed");
        hold_stable(1'b0);
        @(posedge clk);
        check(1'b0, "case4_clean_release");

        // Case 5: bounce during RELEASE_WAIT must abort (stay pressed).
        hold_stable(1'b1);                 // confirmed PRESSED, btn_out high
        btn_in = 1'b0;
        repeat (STABLE_COUNT - 3) @(posedge clk);  // not long enough
        btn_in = 1'b1;                     // bounce back -> abort to PRESSED
        repeat (5) @(posedge clk);
        check(1'b1, "case5_release_bounce_rejected");

        // Case 6: short glitch from idle never asserts output
        hold_stable(1'b0);                 // ensure IDLE
        btn_in = 1'b1;
        repeat (3) @(posedge clk);         // far below STABLE_COUNT
        btn_in = 1'b0;
        repeat (5) @(posedge clk);
        check(1'b0, "case6_short_glitch_rejected");

        // ---- summary ----
        if (errors == 0)
            $display("==== ALL TESTS PASSED ====");
        else
            $display("==== %0d TEST(S) FAILED ====", errors);
        $finish;
    end

endmodule