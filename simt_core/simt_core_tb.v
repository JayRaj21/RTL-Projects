`timescale 1ns/1ps

module simt_core_tb;
    reg clk, reset;
    reg [1:0] step;

    simt_core dut(.clk(clk), .reset(reset), .step(step));

    initial forever #5 clk = ~clk;

    initial begin
        $dumpfile("simt_core_tb.vcd");
        $dumpvars(0, simt_core_tb);

        clk = 0;
        reset = 1;
        step = 0;
        repeat (2) @(posedge clk);
        reset <= 0; //non-blocking: every lane's always block sees the old
                    //value on this same edge, not a stale/raced new one

        step <= 1; @(posedge clk); //compute predicate, all lanes
        step <= 2; @(posedge clk); //then-path (data*2), pred-true lanes only
        step <= 3; @(posedge clk); //else-path (data+1), pred-false lanes only
        step <= 0; @(posedge clk); //settle

        //lane data: 3,7,2,9 -> pred: 3>5=0, 7>5=1, 2>5=0, 9>5=1
        //lane0 (false): else-path 3+1=4
        //lane1 (true):  then-path 7*2=14
        //lane2 (false): else-path 2+1=3
        //lane3 (true):  then-path 9*2=18
        $display("lane0=%0d (expect 4)",  dut.lane[0].lane_inst.result);
        $display("lane1=%0d (expect 14)", dut.lane[1].lane_inst.result);
        $display("lane2=%0d (expect 3)",  dut.lane[2].lane_inst.result);
        $display("lane3=%0d (expect 18)", dut.lane[3].lane_inst.result);

        $finish;
    end
endmodule
