`timescale 1ns/1ps

module riscv_subset_tb;
    reg clk, reset;
    wire [31:0] pc_out, wb_rd_data;
    wire [4:0] wb_rd_addr;
    wire wb_reg_write;

    riscv_subset dut(.clk(clk), .reset(reset), .pc_out(pc_out),
                      .wb_rd_addr(wb_rd_addr), .wb_rd_data(wb_rd_data), .wb_reg_write(wb_reg_write));

    initial forever #5 clk = ~clk;

    integer i;

    initial begin
        $dumpfile("riscv_subset_tb.vcd");
        $dumpvars(0, riscv_subset_tb);

        clk = 0;
        reset = 1;
        repeat (2) @(posedge clk);
        reset = 0;

        // run long enough for every instruction to drain through all 5 stages
        repeat (40) begin
            @(posedge clk);
            if (wb_reg_write)
                $display("t=%0t  WB: x%0d <= %0d", $time, wb_rd_addr, wb_rd_data);
        end

        $display("---");
        $display("x1=%0d (expect 5)",  dut.rf.regs[1]);
        $display("x2=%0d (expect 10)", dut.rf.regs[2]);
        $display("x3=%0d (expect 15)", dut.rf.regs[3]);
        $display("x4=%0d (expect 10)", dut.rf.regs[4]);
        $display("x5=%0d (expect 15)", dut.rf.regs[5]);
        $display("x6=%0d (expect 20)", dut.rf.regs[6]);
        $display("x7=%0d (expect x - uninitialized/never written, confirms branch flush)", dut.rf.regs[7]);
        $display("x8=%0d (expect 42, branch target)", dut.rf.regs[8]);
        $display("mem[0]=%0d (expect 15, from sw)", dut.dmem0.mem[0]);

        $finish;
    end
endmodule
