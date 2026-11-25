`timescale 1ns/1ps

module mac_tb;
    parameter WIDTH = 8;

    reg clk;
    reg [WIDTH-1:0] a, b, c;
    wire [2*WIDTH-1:0] out_comb, out_pipe;

    //a small history of unpipelined results, so we can compare the
    //pipelined output (2 cycles late) against the matching inputs
    reg [2*WIDTH-1:0] expect_d1, expect_d2;

    mac_unpipelined #(.WIDTH(WIDTH)) dut_comb(.out(out_comb), .a(a), .b(b), .c(c));
    mac_pipelined   #(.WIDTH(WIDTH)) dut_pipe(.out(out_pipe), .clk(clk), .a(a), .b(b), .c(c));

    initial forever #5 clk = ~clk;

    always @(posedge clk) begin
        expect_d1 <= out_comb; //what the combinational unit says *this* cycle
        expect_d2 <= expect_d1; //same value, one more cycle later
    end

    integer i;

    initial begin
        $dumpfile("mac_tb.vcd");
        $dumpvars(0, mac_tb);

        clk = 0;
        a = 0; b = 0; c = 0;

        for (i = 0; i < 8; i = i + 1) begin
            @(negedge clk);
            a = i + 1;
            b = i + 2;
            c = i;
            @(posedge clk); //let this cycle's values settle before printing
            $display("cycle=%0d a=%0d b=%0d c=%0d  comb=%0d pipe=%0d (expect %0d)",
                      i, a, b, c, out_comb, out_pipe, expect_d2);
        end

        // a few extra cycles so the last inputs finish draining through the pipe
        repeat (3) begin
            @(posedge clk);
            $display("drain          comb=%0d pipe=%0d (expect %0d)", out_comb, out_pipe, expect_d2);
        end

        $finish;
    end
endmodule
