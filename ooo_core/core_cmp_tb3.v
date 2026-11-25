`timescale 1ns/1ps

module core_cmp_tb3;
    reg clk, reset;

    wire ooo_cdb_v;
    wire [1:0] ooo_cdb_tag;
    wire [7:0] ooo_cdb_val;
    wire [2:0] ooo_cdb_pc;
    wire ooo_c_v;
    wire [2:0] ooo_c_rd;
    wire [7:0] ooo_c_val;
    wire [2:0] ooo_c_pc;

    wire ino_c_v;
    wire [2:0] ino_c_rd;
    wire [7:0] ino_c_val;
    wire [2:0] ino_c_pc;

    //pure dependency chain program: no ilp available, so ooo should give
    //zero speedup over in-order - both cores share one clk/reset for a
    //direct cycle-for-cycle comparison
    ooo_core3 ooo(.clk(clk), .reset(reset), .cdb_v(ooo_cdb_v), .cdb_tag(ooo_cdb_tag),
                  .cdb_val(ooo_cdb_val), .cdb_pc(ooo_cdb_pc), .c_v(ooo_c_v),
                  .c_rd(ooo_c_rd), .c_val(ooo_c_val), .c_pc(ooo_c_pc));

    inorder_core3 ino(.clk(clk), .reset(reset), .c_v(ino_c_v), .c_rd(ino_c_rd),
                       .c_val(ino_c_val), .c_pc(ino_c_pc));

    initial forever #5 clk = ~clk;

    integer i;
    integer ooo_ncommit, ino_ncommit, errors;
    integer ooo_cm [1:5];
    integer ino_cm [1:5];
    integer ooo_cyc, ino_cyc;

    task report_register(input [2:0] reg_num, input [7:0] expected);
        reg [7:0] ooo_val, ino_val;
        begin
            ooo_val = ooo.rf.registers[reg_num];
            ino_val = ino.rf.registers[reg_num];
            $display("x%0d ooo=%0d ino=%0d (expect %0d)", reg_num, ooo_val, ino_val, expected);
            if (ooo_val !== expected) errors = errors + 1;
            if (ino_val !== expected) errors = errors + 1;
        end
    endtask

    initial begin
        $dumpfile("core_cmp_tb3.vcd");
        $dumpvars(0, core_cmp_tb3);

        clk = 0;
        reset = 1;
        errors = 0;
        ooo_ncommit = 0;
        ino_ncommit = 0;
        for (i = 1; i <= 5; i = i + 1) begin
            ooo_cm[i] = 0;
            ino_cm[i] = 0;
        end

        repeat (2) @(posedge clk);
        reset <= 0;

        for (i = 1; i <= 30; i = i + 1) begin
            @(posedge clk); #1;

            if (ooo_c_v) begin
                $display("cyc=%0d OOO COMMIT: I%0d rd=%0d val=%0d", i, ooo_c_pc + 1, ooo_c_rd, ooo_c_val);
                if (ooo_c_pc + 1 != ooo_ncommit + 1) begin
                    errors = errors + 1;
                    $display("FAIL: ooo out-of-order commit, got I%0d expected I%0d", ooo_c_pc + 1, ooo_ncommit + 1);
                end
                ooo_cm[ooo_c_pc + 1] = i;
                ooo_ncommit = ooo_ncommit + 1;
            end

            if (ino_c_v) begin
                $display("cyc=%0d INO COMMIT: I%0d rd=%0d val=%0d", i, ino_c_pc + 1, ino_c_rd, ino_c_val);
                if (ino_c_pc + 1 != ino_ncommit + 1) begin
                    errors = errors + 1;
                    $display("FAIL: ino out-of-order commit, got I%0d expected I%0d", ino_c_pc + 1, ino_ncommit + 1);
                end
                ino_cm[ino_c_pc + 1] = i;
                ino_ncommit = ino_ncommit + 1;
            end
        end

        if (ooo_ncommit != 5) begin
            errors = errors + 1;
            $display("FAIL: ooo ncommit=%0d expected 5", ooo_ncommit);
        end
        if (ino_ncommit != 5) begin
            errors = errors + 1;
            $display("FAIL: ino ncommit=%0d expected 5", ino_ncommit);
        end

        report_register(1, 5);
        report_register(2, 6);
        report_register(3, 7);
        report_register(4, 8);
        report_register(5, 9);

        ooo_cyc = ooo_cm[5];
        ino_cyc = ino_cm[5];

        $display("in-order=%0d cycles  ooo=%0d cycles", ino_cyc, ooo_cyc);

        //pure dependency chain, no independent work anywhere - ooo has
        //nothing to reorder, so it should match the in-order core exactly,
        //cycle for cycle, not just in the final total
        if (ooo_cyc != ino_cyc) begin
            errors = errors + 1;
            $display("FAIL: ooo total cycles differ from in-order (ooo=%0d ino=%0d)", ooo_cyc, ino_cyc);
        end

        for (i = 1; i <= 5; i = i + 1) begin
            if (ooo_cm[i] != ino_cm[i]) begin
                errors = errors + 1;
                $display("FAIL: I%0d commit cycle differs (ooo=%0d ino=%0d)", i, ooo_cm[i], ino_cm[i]);
            end
        end

        if (errors == 0)
            $display("commits match exactly, cycle for cycle: no ILP available, no speedup from OOO");

        if (errors != 0)
            $display("FAIL (%0d errors)", errors);

        $finish;
    end
endmodule
