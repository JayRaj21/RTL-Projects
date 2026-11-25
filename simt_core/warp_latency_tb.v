`timescale 1ns/1ps

module warp_latency_tb;
    reg clk, reset;
    reg [7:0] data0, data1;
    wire [7:0] s_r0, s_r1, h_r0, h_r1;
    wire s_done, h_done;
    integer i, s_cyc, h_cyc;

    sequential_core seq(.clk(clk), .reset(reset), .data0(data0), .data1(data1),
                         .result0(s_r0), .result1(s_r1), .both_done(s_done));
    hiding_core hide(.clk(clk), .reset(reset), .data0(data0), .data1(data1),
                      .result0(h_r0), .result1(h_r1), .both_done(h_done));

    initial forever #5 clk = ~clk;

    initial begin
        $dumpfile("warp_latency_tb.vcd");
        $dumpvars(0, warp_latency_tb);

        clk = 0;
        reset = 1;
        data0 = 5;
        data1 = 9;
        s_cyc = 0;
        h_cyc = 0;
        repeat (2) @(posedge clk);
        reset <= 0; //non-blocking: avoids racing the dut's same-edge always blocks

        for (i = 1; i <= 20; i = i + 1) begin
            @(posedge clk); #1;
            if (s_cyc == 0 && s_done) s_cyc = i;
            if (h_cyc == 0 && h_done) h_cyc = i;
            $display("cyc %0d  seq w0=%0d w1=%0d  hide w0=%0d w1=%0d", i, seq.w0.state, seq.w1.state, hide.w0.state, hide.w1.state);
        end

        //5*2=10, 9*2=18
        $display("seq  r0=%0d r1=%0d (expect 10 18)", s_r0, s_r1);
        $display("hide r0=%0d r1=%0d (expect 10 18)", h_r0, h_r1);
        $display("seq=%0d cycles  hide=%0d cycles", s_cyc, h_cyc);

        if (s_r0 == 10 && s_r1 == 18 && h_r0 == 10 && h_r1 == 18 &&
            s_cyc != 0 && h_cyc != 0 && h_cyc <= s_cyc)
            $display("PASS");
        else
            $display("FAIL");

        $finish;
    end
endmodule
