`timescale 1ns/1ps

module alu_timing_tb;
    reg clk, reset;

    wire [2:0] unpipelined_wb_addr, pipelined_wb_addr;
    wire [7:0] unpipelined_wb_data, pipelined_wb_data;
    wire unpipelined_wb_write, pipelined_wb_write;

    unpipelined_alu unpipelined_dut(.clk(clk), .reset(reset),
        .wb_rd_addr(unpipelined_wb_addr), .wb_rd_data(unpipelined_wb_data), .wb_reg_write(unpipelined_wb_write));

    pipelined_alu pipelined_dut(.clk(clk), .reset(reset),
        .wb_rd_addr(pipelined_wb_addr), .wb_rd_data(pipelined_wb_data), .wb_reg_write(pipelined_wb_write));

    // Both DUTs run the SAME baked-in program (from imem) completely on
    // their own once reset is released - no per-cycle stimulus needed, so
    // each "phase" below is just: reset, let it run, check the result.
    //
    // unpipelined_alu's total single-cycle critical path is 8ns (see its
    // own comments). pipelined_alu's longest single stage is 4ns. The two
    // clock periods below are chosen the same way as timing_demo.v's demo:
    // one longer than both (so both work), one in between (so only the
    // unpipelined design breaks).
    localparam LOOSE_HALF_PERIOD = 5; //10ns period - exceeds both 8ns and 4ns
    localparam TIGHT_HALF_PERIOD = 3; //6ns period  - exceeds 4ns, but NOT 8ns

    task run_one_cycle(input integer half_period);
        begin
            #(half_period) clk = 1'b0;
            #(half_period - 1) clk = 1'b1; // 1ns short: the caller's #1 settle delay right after this call makes up the difference, landing exactly where the next cycle would've started anyway - keeping the true edge-to-edge period at 2*half_period instead of 2*half_period+1
        end
    endtask

    // completion tracking: cycle number (counted from reset release) on
    // which each design finishes writing the program's LAST real result
    // (x5). 0 means "never finished within the cycles we ran."
    integer unpipelined_done_cycle, pipelined_done_cycle;

    // Resets both DUTs (re-running the same program from the start), lets
    // them run for enough cycles to finish and drain, and records how many
    // cycles each one actually took to produce the final result (x5).
    task run_phase(input integer half_period);
        integer i;
        reg unpipelined_done, pipelined_done;
        begin
            reset = 1'b1;
            run_one_cycle(half_period);
            run_one_cycle(half_period);
            // non-blocking: a blocking `reset = 1'b0` here would execute in
            // the same timestep as the second edge above (this thread keeps
            // running until it hits a delay), so the DUTs' own posedge
            // blocks would already see reset == 0 on that second edge -
            // releasing reset one edge early. The non-blocking assignment
            // defers the release to the NBA region, after the DUTs have
            // sampled reset == 1 on this edge, so reset is properly held
            // for the full 2 edges intended.
            reset <= 1'b0;

            unpipelined_done = 1'b0;
            pipelined_done   = 1'b0;
            unpipelined_done_cycle = 0;
            pipelined_done_cycle   = 0;

            for (i = 0; i < 10; i = i + 1) begin
                run_one_cycle(half_period);
                #1; // let this edge's non-blocking updates settle before reading wb_* signals

                if (!unpipelined_done && unpipelined_wb_write && unpipelined_wb_addr == 3'd5) begin
                    unpipelined_done = 1'b1;
                    unpipelined_done_cycle = i + 1;
                end
                if (!pipelined_done && pipelined_wb_write && pipelined_wb_addr == 3'd5) begin
                    pipelined_done = 1'b1;
                    pipelined_done_cycle = i + 1;
                end
            end
        end
    endtask

    task report_completion(input integer half_period);
        begin
            $display("completion time: unpipelined=%0d cycles (%0dns)   pipelined=%0d cycles (%0dns)",
                      unpipelined_done_cycle, unpipelined_done_cycle * 2 * half_period,
                      pipelined_done_cycle,   pipelined_done_cycle * 2 * half_period);
        end
    endtask

    task report_register(input [2:0] reg_num, input [7:0] expected);
        reg [7:0] unpipelined_val, pipelined_val;
        begin
            unpipelined_val = unpipelined_dut.rf.registers[reg_num];
            pipelined_val   = pipelined_dut.rf.registers[reg_num];
            $display("x%0d  unpipelined=%0d %s   pipelined=%0d %s   (expect %0d)",
                      reg_num,
                      unpipelined_val, (unpipelined_val === expected ? "OK" : "WRONG"),
                      pipelined_val,   (pipelined_val   === expected ? "OK" : "WRONG"),
                      expected);
        end
    endtask

    initial begin
        $dumpfile("alu_timing_tb.vcd");
        $dumpvars(0, alu_timing_tb);

        clk = 0;

        $display("=== phase 1: 10ns period (both designs have enough margin) ===");
        run_phase(LOOSE_HALF_PERIOD);
        report_register(1, 5);
        report_register(2, 3);
        report_register(3, 8);
        report_register(4, 3);
        report_register(5, 6);
        report_completion(LOOSE_HALF_PERIOD);

        $display("=== phase 2: 6ns period (unpipelined's 8ns critical path no longer fits) ===");
        run_phase(TIGHT_HALF_PERIOD);
        report_register(1, 5);
        report_register(2, 3);
        report_register(3, 8);
        report_register(4, 3);
        report_register(5, 6);
        report_completion(TIGHT_HALF_PERIOD);

        $finish;
    end
endmodule
