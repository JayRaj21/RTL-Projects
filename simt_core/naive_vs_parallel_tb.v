`timescale 1ns/1ps

module naive_vs_parallel_tb;
    reg clk, reset;
    reg [1:0] step;
    wire n_busy, n_done;
    integer i, n_cyc, p_cyc;

    naive_core nv(.clk(clk), .reset(reset), .busy(n_busy), .done(n_done));
    simt_core par(.clk(clk), .reset(reset), .step(step));

    initial forever #5 clk = ~clk;

    initial begin
        $dumpfile("naive_vs_parallel_tb.vcd");
        $dumpvars(0, naive_vs_parallel_tb);

        clk = 0;
        reset = 1;
        step = 0;
        n_cyc = 0;
        p_cyc = 0;
        repeat (2) @(posedge clk);
        reset <= 0;
        step  <= 1;

        for (i = 1; i <= 25; i = i + 1) begin
            @(posedge clk); #1;
            if (n_cyc == 0 && n_done) n_cyc = i;
            if (p_cyc == 0 && step == 2'd3) p_cyc = i;
            $display("cyc %0d  nv phase=%0d idx=%0d done=%0d  par step=%0d", i, nv.phase, nv.idx, n_done, step);
            step <= (step == 2'd1) ? 2'd2 : (step == 2'd2) ? 2'd3 : 2'd0;
        end

        //lane data: 3,7,2,9 -> pred: 3>5=0, 7>5=1, 2>5=0, 9>5=1
        //lane0 (false): else-path 3+1=4
        //lane1 (true):  then-path 7*2=14
        //lane2 (false): else-path 2+1=3
        //lane3 (true):  then-path 9*2=18
        $display("nv  r0=%0d r1=%0d r2=%0d r3=%0d (expect 4 14 3 18)", nv.result[0], nv.result[1], nv.result[2], nv.result[3]);
        $display("par r0=%0d r1=%0d r2=%0d r3=%0d (expect 4 14 3 18)",
                  par.lane[0].lane_inst.result, par.lane[1].lane_inst.result,
                  par.lane[2].lane_inst.result, par.lane[3].lane_inst.result);
        $display("naive=%0d cycles  simt=%0d cycles", n_cyc, p_cyc);

        if (nv.result[0] == 4 && nv.result[1] == 14 && nv.result[2] == 3 && nv.result[3] == 18 &&
            par.lane[0].lane_inst.result == 4  && par.lane[1].lane_inst.result == 14 &&
            par.lane[2].lane_inst.result == 3  && par.lane[3].lane_inst.result == 18 &&
            n_cyc != 0 && p_cyc != 0 && n_cyc == 4 * p_cyc)
            $display("PASS"); //4 lanes -> 4x fewer cycles
        else
            $display("FAIL");

        $finish;
    end
endmodule
