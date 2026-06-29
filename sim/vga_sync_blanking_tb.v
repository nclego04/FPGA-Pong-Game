`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Nathan Cinco
//
// Module Name: vga_sync_blanking_tb
// Project Name: FPGA Pong
// Description:
//   Self-checking testbench for vga_sync covering blanking: vga_r/g/b must be
//   forced to black (0) at every sample point outside the active window
//   (back porch, front porch, and sync regions), per VESA, regardless of
//   ball/paddle state. Checked every pixel_clk cycle for a full frame via
//   hierarchical reference to the internal pixel_pos_h/pixel_pos_v counters,
//   since the color outputs are registered one cycle behind the counter
//   value that drives them.
//////////////////////////////////////////////////////////////////////////////////
module vga_sync_blanking_tb;

    localparam CLK_PERIOD = 40;   // 25 MHz pixel clock

    reg reset, new_game;
    reg pixel_clk;
    reg left_btn_up, left_btn_down, right_btn_up, right_btn_down;

    wire hsync, vsync;
    wire [3:0] vga_r, vga_g, vga_b;

    integer errors  = 0;
    integer samples = 0;

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

    // ---- blanking monitor ----
    // Samples just after each posedge (via negedge, once the DUT's
    // non-blocking updates have settled). vga_r/g/b at sample N were
    // computed from the pixel_pos_h/v value captured at sample N-1, so
    // ph_prev/pv_prev are checked against the CURRENT color outputs.
    reg [11:0] ph_prev, pv_prev;
    reg        have_prev;

    initial begin
        have_prev = 1'b0;
        forever begin
            @(negedge pixel_clk);
            if (have_prev) begin
                samples = samples + 1;
                if (!((ph_prev >= dut.H_BACK_PORCH) && (ph_prev < dut.H_ACTIVE_END) &&
                      (pv_prev >= dut.V_BACK_PORCH) && (pv_prev < dut.V_ACTIVE_END))) begin
                    if (vga_r !== 4'b0000 || vga_g !== 4'b0000 || vga_b !== 4'b0000) begin
                        $display("[FAIL] blanking violated: ph_prev=%0d pv_prev=%0d vga_rgb=%b%b%b @%0t",
                                  ph_prev, pv_prev, vga_r, vga_g, vga_b, $time);
                        errors = errors + 1;
                    end
                end
            end
            ph_prev   = dut.pixel_pos_h;
            pv_prev   = dut.pixel_pos_v;
            have_prev = 1'b1;
        end
    end

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

        // Run for a bit more than one full frame to exercise every porch
        // region at least once.
        repeat (dut.TOTAL_WIDTH * dut.TOTAL_HEIGHT + dut.TOTAL_WIDTH) @(posedge pixel_clk);

        if (errors == 0)
            $display("==== ALL TESTS PASSED (%0d samples checked) ====", samples);
        else
            $display("==== %0d TEST(S) FAILED (%0d samples checked) ====", errors, samples);
        $finish;
    end

    // ---- safety timeout ----
    initial begin
        #(CLK_PERIOD * 800 * 525 * 3);
        $display("[FATAL] timeout -- sim hung");
        $finish;
    end

endmodule
