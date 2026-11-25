`timescale 1ns/1ps

module timing_demo_tb;
    parameter WIDTH = 8;
    parameter NUM_CYCLES = 10;

    reg clk;
    integer half_period;
    reg [WIDTH-1:0] a, b, c;
    wire [2*WIDTH-1:0] out_unpipelined, out_pipelined;

    mac_unpipelined_timed #(.WIDTH(WIDTH)) unpipelined_mac(.out(out_unpipelined), .clk(clk), .a(a), .b(b), .c(c));
    mac_pipelined_timed   #(.WIDTH(WIDTH)) pipelined_mac(.out(out_pipelined), .clk(clk), .a(a), .b(b), .c(c));

    // expected values computed in plain testbench arithmetic (not a parallel
    // hardware shift register) so this check can't race against the DUTs'
    // own registers, which are updated by the exact same clock edge
    integer cycle;
    reg [2*WIDTH-1:0] expected_val [0:NUM_CYCLES];

    initial begin
        $dumpfile("timing_demo_tb.vcd");
        $dumpvars(0, timing_demo_tb);

        b = 5;
        c = 10;
        clk = 0;

        // expected_val[k] = result for the input applied on cycle k
        // (b, c held constant; a = k, so result = k*5 + 10)
        for (cycle = 1; cycle <= NUM_CYCLES; cycle = cycle + 1)
            expected_val[cycle] = cycle * 5 + 10;

        // -----------------------------------------------------------
        // Phase 1: loose clock period (10ns), comfortably longer than
        // both the unpipelined critical path (8ns) and each pipelined
        // stage (4ns). Both designs should track correctly.
        //
        // The two clock periods used by phases 1 and 2 are chosen
        // relative to timing_demo.v's CRIT_DELAY=8 and STAGE_DELAY=4:
        // phase 1's 10ns period is longer than both delays, so both
        // designs have time to settle every cycle. Phase 2's 6ns period
        // is shorter than CRIT_DELAY (8ns) but still longer than
        // STAGE_DELAY (4ns), so only the unpipelined design is pushed
        // past its settling time while the pipelined design keeps working.
        // -----------------------------------------------------------
        half_period = 5; //10ns period
        $display("--- phase 1: 10ns period ---");
        for (cycle = 1; cycle <= 5; cycle = cycle + 1) begin
            // apply the input right after an edge, so it gets the FULL
            // period to propagate before the next edge samples it (there
            // is no delay between the posedge and this assignment). If
            // inputs were instead applied at negedge (mid-cycle), as an
            // earlier version of this file did, they would only get a
            // HALF period to settle - e.g. 5ns at this loose 10ns period -
            // which is LESS than the unpipelined critical path (8ns) even
            // during this "loose" phase, so that earlier timing would have
            // accidentally been testing the wrong thing.
            a = cycle;
            drive_one_clock_cycle;
            check_outputs(cycle);
        end

        // -----------------------------------------------------------
        // Phase 2: tight clock period (6ns), shorter than the
        // unpipelined critical path (8ns), so it cannot settle in time.
        // Still longer than each pipelined stage (4ns), so that design
        // keeps working correctly. Cycle 6 still prints OK: it shows the
        // value latched at the last 10ns edge (phase 1's edge 5), not a
        // result produced under the new 6ns period. The unpipelined
        // failures only show up from cycle 7 onward.
        // -----------------------------------------------------------
        half_period = 3; //6ns period
        $display("--- phase 2: 6ns period ---");
        for (cycle = 6; cycle <= NUM_CYCLES; cycle = cycle + 1) begin
            // out_unpipelined freezes at 35 here instead of lagging through
            // 40, 45, etc. `assign #CRIT_DELAY result_comb = (a*b)+c;` uses
            // Verilog's default inertial delay: since `a` changes every 6ns
            // (this phase's clock period) and CRIT_DELAY is 8ns, each new
            // input change arrives before the previous scheduled update
            // completes, so the pending update gets cancelled and
            // result_comb never moves again.
            a = cycle;
            drive_one_clock_cycle;
            check_outputs(cycle);
        end

        $finish;
    end

    // -----------------------------------------------------------
    // Clock generation
    // -----------------------------------------------------------
    // Drives clk from this stimulus thread instead of a free-running
    // `always` block, so there is no race between a clock edge and the
    // testbench changing half_period: every cycle, including the one
    // where the period changes, is exactly 2*half_period ns long, start
    // to finish, with the period value read fresh each time it's called.
    task drive_one_clock_cycle;
        begin
            #(half_period) clk = 0;
            #(half_period) clk = 1;
        end
    endtask

    // -----------------------------------------------------------
    // Output checking
    // -----------------------------------------------------------
    // unpipelined has 1 register stage -> its output on cycle N reflects
    // cycle N-1's input. pipelined has 2 register stages -> cycle N-2.
    // This task runs in the active region right after drive_one_clock_cycle
    // raises clk, which is before the DUTs' non-blocking (<=) updates for
    // this same edge take effect, so it always reads the value latched at
    // the PREVIOUS edge - never a race against this edge's new result.
    task check_outputs(input integer n);
        reg u_ok, p_ok;
        begin
            u_ok = (n >= 2) ? (out_unpipelined === expected_val[n-1]) : 1'b1;
            p_ok = (n >= 3) ? (out_pipelined === expected_val[n-2]) : 1'b1;
            $display("cycle=%0d a=%0d  unpipelined=%0d %s  pipelined=%0d %s",
                      n, a, out_unpipelined, (u_ok ? "OK" : "WRONG"), out_pipelined, (p_ok ? "OK" : "WRONG"));
        end
    endtask
endmodule
