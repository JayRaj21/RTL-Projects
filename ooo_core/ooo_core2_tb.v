`timescale 1ns/1ps

module ooo_core2_tb;
    reg clk, reset;

    wire cdb_v;
    wire [1:0] cdb_tag;
    wire [7:0] cdb_val;
    wire [2:0] cdb_pc;
    wire c_v;
    wire [2:0] c_rd;
    wire [7:0] c_val;
    wire [2:0] c_pc;

    ooo_core2 dut(.clk(clk), .reset(reset), .cdb_v(cdb_v), .cdb_tag(cdb_tag),
                  .cdb_val(cdb_val), .cdb_pc(cdb_pc), .c_v(c_v), .c_rd(c_rd),
                  .c_val(c_val), .c_pc(c_pc));

    initial forever #5 clk = ~clk;

    integer cyc, ncommit, errors;

    initial begin
        clk = 0;
        reset = 1;
        cyc = 0;
        ncommit = 0;
        errors = 0;

        repeat (2) @(posedge clk);
        reset <= 0;

        repeat (40) begin
            @(posedge clk); #1;
            cyc = cyc + 1;

            if (c_v) begin
                $display("t=%0t COMMIT: I%0d rd=%0d val=%0d", $time, c_pc + 1, c_rd, c_val);
                if (c_pc + 1 != ncommit + 1) begin
                    errors = errors + 1;
                    $display("FAIL: out-of-order commit, got I%0d expected I%0d", c_pc + 1, ncommit + 1);
                end
                ncommit = ncommit + 1;
            end
        end

        #1;

        if (ncommit != 7) begin
            errors = errors + 1;
            $display("FAIL: ncommit=%0d expected 7", ncommit);
        end

        $display("x1=%0d (expect 5)",  dut.rf.registers[1]);
        $display("x2=%0d (expect 6)",  dut.rf.registers[2]);
        $display("x3=%0d (expect 11)", dut.rf.registers[3]);
        $display("x4=%0d (expect 6)",  dut.rf.registers[4]);
        $display("x5=%0d (expect 25)", dut.rf.registers[5]);
        $display("x6=%0d (expect 31)", dut.rf.registers[6]);

        if (dut.rf.registers[1] !== 5)  errors = errors + 1;
        if (dut.rf.registers[2] !== 6)  errors = errors + 1;
        if (dut.rf.registers[3] !== 11) errors = errors + 1;
        if (dut.rf.registers[4] !== 6)  errors = errors + 1;
        if (dut.rf.registers[5] !== 25) errors = errors + 1;
        if (dut.rf.registers[6] !== 31) errors = errors + 1;

        if (errors == 0)
            $display("PASS");
        else
            $display("FAIL (%0d errors)", errors);

        $finish;
    end
endmodule
