`timescale 1ns/1ps

module synch_fifo_tb;
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4;

    reg clk, reset, wr_en, rd_en;
    reg [DATA_WIDTH-1:0] wr_data;
    wire [DATA_WIDTH-1:0] rd_data;
    wire [ADDR_WIDTH:0] wr_ptr, rd_ptr;
    wire empty, full;

    synch_fifo #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) dut(
        .clk(clk), .reset(reset),
        .wr_en(wr_en), .wr_data(wr_data), .wr_ptr(wr_ptr),
        .rd_en(rd_en), .rd_data(rd_data), .rd_ptr(rd_ptr),
        .empty(empty), .full(full)
    );

    initial forever #5 clk = ~clk;

    integer i;

    initial begin
        $dumpfile("synch_fifo_tb.vcd");
        $dumpvars(0, synch_fifo_tb);

        clk = 0;
        reset = 1;
        wr_en = 0;
        rd_en = 0;
        wr_data = 0;

        @(negedge clk);
        reset = 0;
        $display("after reset: empty=%b full=%b", empty, full);

        // fill the fifo completely (16 words)
        for (i = 0; i < 16; i = i + 1) begin
            @(negedge clk);
            wr_en = 1;
            wr_data = i;
        end
        @(negedge clk);
        wr_en = 0;
        $display("after 16 writes: empty=%b full=%b wr_ptr=%0d rd_ptr=%0d", empty, full, wr_ptr, rd_ptr);

        
        @(negedge clk);
        wr_en = 1;
        wr_data = 8'hFF;
        @(negedge clk);
        wr_en = 0;
        $display("write while full ignored: full=%b wr_ptr=%0d", full, wr_ptr);

        // drain the fifo completely
        for (i = 0; i < 16; i = i + 1) begin
            @(negedge clk);
            rd_en = 1;
            $display("read: rd_data=%0d empty=%b full=%b", rd_data, empty, full);
        end
        @(negedge clk);
        rd_en = 0;
        $display("after 16 reads: empty=%b full=%b", empty, full);

        $finish;
    end
endmodule
