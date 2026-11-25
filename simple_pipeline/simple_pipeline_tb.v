`timescale 1ns/1ps

module simple_pipeline_tb;
    reg clk;
    reg a, b, c, d;
    wire [2:0] y_comb, y_pipe;

    //golden combinational result, delayed 2 cycles to line up with the pipelined version
    reg [2:0] expect_d1, expect_d2;

    calculator_unpipelined dut_comb(.y(y_comb), .a(a), .b(b), .c(c), .d(d));
    calculator_pipelined   dut_pipe(.y(y_pipe), .clk(clk), .a(a), .b(b), .c(c), .d(d));

    initial forever #5 clk = ~clk;

    always @(posedge clk) begin
        expect_d1 <= y_comb;
        expect_d2 <= expect_d1;
    end

    integer i;
    reg [3:0] stim [0:5];

    initial begin
        $dumpfile("simple_pipeline_tb.vcd");
        $dumpvars(0, simple_pipeline_tb);

        stim[0] = 4'b0000; //a=0 b=0 c=0 d=0 -> 0*0=0
        stim[1] = 4'b1000; //a=1 b=0 c=0 d=0 -> 1*0=0
        stim[2] = 4'b1100; //a=1 b=1 c=0 d=0 -> 2*0=0
        stim[3] = 4'b1110; //a=1 b=1 c=1 d=0 -> 2*1=2
        stim[4] = 4'b1111; //a=1 b=1 c=1 d=1 -> 2*2=4
        stim[5] = 4'b0110; //a=0 b=1 c=1 d=0 -> 1*1=1

        clk = 0;
        {a, b, c, d} = 4'b0000;

        for (i = 0; i < 6; i = i + 1) begin
            @(negedge clk);
            {a, b, c, d} = stim[i];
            @(posedge clk);
            $display("cycle=%0d a=%0d b=%0d c=%0d d=%0d  comb=%0d pipe=%0d (expect %0d)",
                      i, a, b, c, d, y_comb, y_pipe, expect_d2);
        end

        // let the last inputs finish draining through the pipeline
        repeat (3) begin
            @(posedge clk);
            $display("drain               comb=%0d pipe=%0d (expect %0d)", y_comb, y_pipe, expect_d2);
        end

        $finish;
    end
endmodule
