`timescale 1ns/1ps

module bram_tb;
    parameter ADDR_WIDTH = 4;
    parameter DATA_WIDTH = 8;

    reg clk, we;
    reg [ADDR_WIDTH-1:0] addr;
    reg [DATA_WIDTH-1:0] din;
    wire [DATA_WIDTH-1:0] dout;

    bram #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH))
        dut(.clk(clk), .we(we), .addr(addr), .din(din), .dout(dout));

    initial forever #5 clk = ~clk;

    initial begin
        $dumpfile("bram_tb.vcd");
        $dumpvars(0, bram_tb);

        clk = 0;
        we = 0;
        addr = 0;
        din = 0;

        // write 8'hAA to address 0
        @(negedge clk);
        addr = 4'h0; din = 8'hAA; we = 1;
        @(negedge clk);
        we = 0;

        // write 8'h55 to address 1
        @(negedge clk);
        addr = 4'h1; din = 8'h55; we = 1;
        @(negedge clk);
        we = 0;

        // read back address 0
        @(negedge clk);
        addr = 4'h0;
        @(negedge clk);
        $display("read: addr=%0h dout=%0h (expected aa)", addr, dout);

        // read back address 1
        @(negedge clk);
        addr = 4'h1;
        @(negedge clk);
        $display("read: addr=%0h dout=%0h (expected 55)", addr, dout);

        // overwrite address 0
        @(negedge clk);
        addr = 4'h0; din = 8'hFF; we = 1;
        @(negedge clk);
        we = 0;

        // read back overwritten address 0
        @(negedge clk);
        addr = 4'h0;
        @(negedge clk);
        $display("read: addr=%0h dout=%0h (expected ff)", addr, dout);

        $finish;
    end
endmodule
