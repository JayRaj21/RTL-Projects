`timescale 1ns/1ps

module pipelined_alu_tb;
    reg clk, reset;
    wire [2:0] wb_rd_addr;
    wire [7:0] wb_rd_data;
    wire wb_reg_write;

    pipelined_alu dut(.clk(clk), .reset(reset), .wb_rd_addr(wb_rd_addr),
                       .wb_rd_data(wb_rd_data), .wb_reg_write(wb_reg_write));

    initial forever #5 clk = ~clk;

    initial begin
        $dumpfile("pipelined_alu_tb.vcd");
        $dumpvars(0, pipelined_alu_tb);

        clk = 0;
        reset = 1;
        repeat (2) @(posedge clk);
        reset = 0;

        repeat (14) begin
            @(posedge clk);
            if (wb_reg_write)
                $display("t=%0t  WB: x%0d <= %0d", $time, wb_rd_addr, wb_rd_data);
        end

        $display("---");
        $display("x1=%0d (expect 5)",  dut.rf.registers[1]);
        $display("x2=%0d (expect 3)",  dut.rf.registers[2]);
        $display("x3=%0d (expect 8)",  dut.rf.registers[3]);
        $display("x4=%0d (expect 3)",  dut.rf.registers[4]);
        $display("x5=%0d (expect 6)",  dut.rf.registers[5]);
        $display("x6=%0d (expect 15)", dut.rf.registers[6]); //mul, 2-cycle EX
        $display("x7=%0d (expect 20)", dut.rf.registers[7]); //needs x6 right after the stall

        $finish;
    end
endmodule
