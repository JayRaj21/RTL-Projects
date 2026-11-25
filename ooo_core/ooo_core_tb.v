`timescale 1ns/1ps

module ooo_core_tb;
    reg clk, reset;

    wire cdb_v;
    wire [1:0] cdb_tag;
    wire [7:0] cdb_val;
    wire [2:0] cdb_pc;
    wire c_v;
    wire [2:0] c_rd;
    wire [7:0] c_val;
    wire [2:0] c_pc;

    ooo_core dut(.clk(clk), .reset(reset), .cdb_v(cdb_v), .cdb_tag(cdb_tag),
                  .cdb_val(cdb_val), .cdb_pc(cdb_pc), .c_v(c_v), .c_rd(c_rd),
                  .c_val(c_val), .c_pc(c_pc));

    initial forever #5 clk = ~clk;

    integer cyc, ncommit, errors;
    integer cdb_cyc [1:5];
    integer i;
    reg [2:0] prev_pc;

    initial begin
        $dumpfile("ooo_core_tb.vcd");
        $dumpvars(0, ooo_core_tb);

        clk = 0;
        reset = 1;
        cyc = 0;
        ncommit = 0;
        errors = 0;
        for (i = 1; i <= 5; i = i + 1)
            cdb_cyc[i] = 0;

        repeat (2) @(posedge clk);
        reset <= 0;
        prev_pc = dut.pc;

        repeat (20) begin
            @(posedge clk); #1;
            cyc = cyc + 1;

            //pc has already advanced past the issuing instruction by this
            //point in the cycle, so detect the issue by watching for the
            //pc change rather than reading dut.iss after the fact
            if (dut.pc != prev_pc)
                $display("t=%0t cyc=%0d ISS: I%0d pc=%0d", $time, cyc, prev_pc + 1, prev_pc);
            prev_pc = dut.pc;

            if (cdb_v) begin
                $display("t=%0t cyc=%0d CDB: I%0d tag=%0d val=%0d", $time, cyc, cdb_pc + 1, cdb_tag, cdb_val);
                cdb_cyc[cdb_pc + 1] = cyc;
            end

            if (c_v) begin
                $display("t=%0t cyc=%0d COMMIT: I%0d rd=%0d val=%0d", $time, cyc, c_pc + 1, c_rd, c_val);
                if (c_pc + 1 != ncommit + 1) begin
                    errors = errors + 1;
                    $display("FAIL: out-of-order commit, got I%0d expected I%0d", c_pc + 1, ncommit + 1);
                end
                ncommit = ncommit + 1;
            end
        end

        #1;

        if (cdb_cyc[3] != 0 && cdb_cyc[2] != 0 && cdb_cyc[3] < cdb_cyc[2])
            $display("I3 done cyc %0d < I2 done cyc %0d", cdb_cyc[3], cdb_cyc[2]);
        else begin
            errors = errors + 1;
            $display("FAIL: I3 did not finish before I2 (I3=%0d I2=%0d)", cdb_cyc[3], cdb_cyc[2]);
        end

        if (ncommit != 5) begin
            errors = errors + 1;
            $display("FAIL: ncommit=%0d expected 5", ncommit);
        end

        $display("x1=%0d (expect 5)",  dut.rf.registers[1]);
        $display("x2=%0d (expect 15)", dut.rf.registers[2]);
        $display("x3=%0d (expect 7)",  dut.rf.registers[3]);
        $display("x4=%0d (expect 6)",  dut.rf.registers[4]);
        $display("x5=%0d (expect 16)", dut.rf.registers[5]);

        if (dut.rf.registers[1] !== 5)  errors = errors + 1;
        if (dut.rf.registers[2] !== 15) errors = errors + 1;
        if (dut.rf.registers[3] !== 7)  errors = errors + 1;
        if (dut.rf.registers[4] !== 6)  errors = errors + 1;
        if (dut.rf.registers[5] !== 16) errors = errors + 1;

        if (errors == 0)
            $display("PASS");
        else
            $display("FAIL (%0d errors)", errors);

        $finish;
    end
endmodule
