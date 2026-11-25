`timescale 1ns/1ps

module core_cmp_tb2;
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

    //both DUTs share one clk and one reset, so cycle counts are directly
    //comparable. the speedup below is overlap across independent
    //instructions, not just reordering - the in-order core is fully serial
    ooo_core2 ooo(.clk(clk), .reset(reset), .cdb_v(ooo_cdb_v), .cdb_tag(ooo_cdb_tag),
                  .cdb_val(ooo_cdb_val), .cdb_pc(ooo_cdb_pc), .c_v(ooo_c_v),
                  .c_rd(ooo_c_rd), .c_val(ooo_c_val), .c_pc(ooo_c_pc));

    inorder_core2 ino(.clk(clk), .reset(reset), .c_v(ino_c_v), .c_rd(ino_c_rd),
                       .c_val(ino_c_val), .c_pc(ino_c_pc));

    initial forever #5 clk = ~clk;

    integer i;
    integer ooo_ncommit, ino_ncommit, errors;
    integer ooo_cm [1:7];
    integer ino_cm [1:7];
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
        $dumpfile("core_cmp_tb2.vcd");
        $dumpvars(0, core_cmp_tb2);

        clk = 0;
        reset = 1;
        errors = 0;
        ooo_ncommit = 0;
        ino_ncommit = 0;
        for (i = 1; i <= 7; i = i + 1) begin
            ooo_cm[i] = 0;
            ino_cm[i] = 0;
        end

        repeat (2) @(posedge clk);
        reset <= 0;

        for (i = 1; i <= 45; i = i + 1) begin
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

        if (ooo_ncommit != 7) begin
            errors = errors + 1;
            $display("FAIL: ooo ncommit=%0d expected 7", ooo_ncommit);
        end
        if (ino_ncommit != 7) begin
            errors = errors + 1;
            $display("FAIL: ino ncommit=%0d expected 7", ino_ncommit);
        end

        report_register(1, 5);
        report_register(2, 6);
        report_register(3, 11);
        report_register(4, 6);
        report_register(5, 25);
        report_register(6, 31);

        ooo_cyc = ooo_cm[7];
        ino_cyc = ino_cm[7];

        $display("in-order=%0d cycles  ooo=%0d cycles", ino_cyc, ooo_cyc);
        $display("I1 commit: ino=%0d ooo=%0d (same latency)", ino_cm[1], ooo_cm[1]);
        $display("ino mul gaps=%0d %0d, add gaps=%0d %0d %0d %0d",
                  ino_cm[2] - ino_cm[1], ino_cm[6] - ino_cm[5],
                  ino_cm[3] - ino_cm[2], ino_cm[4] - ino_cm[3],
                  ino_cm[5] - ino_cm[4], ino_cm[7] - ino_cm[6]);

        if (ino_cyc <= ooo_cyc) begin
            errors = errors + 1;
            $display("FAIL: in-order not slower than ooo (ino=%0d ooo=%0d)", ino_cyc, ooo_cyc);
        end

        if (ino_cm[1] != ooo_cm[1]) begin
            errors = errors + 1;
            $display("FAIL: I1 commit cycle differs (ino=%0d ooo=%0d)", ino_cm[1], ooo_cm[1]);
        end

        //each add/sub takes exactly 4 cycles ISS->EX->WT->CM; a core that
        //pipelined past a mul would still show equal add gaps here, but the
        //mul gap would collapse to 4 too instead of staying inflated by the
        //stall, so pinning the add gaps to the exact constant 4 (rather than
        //comparing them to each other) is what actually catches an
        //overlapping design - it can't shrink its add gaps to hide an
        //overlapped mul without failing the == 4 checks
        if (!((ino_cm[3] - ino_cm[2] == 4) &&
              (ino_cm[4] - ino_cm[3] == 4) &&
              (ino_cm[5] - ino_cm[4] == 4) &&
              (ino_cm[7] - ino_cm[6] == 4) &&
              (ino_cm[2] - ino_cm[1] > 4) &&
              (ino_cm[6] - ino_cm[5] > 4))) begin
            errors = errors + 1;
            $display("FAIL: ino did not serialize around both muls as expected");
        end

        if (errors != 0)
            $display("FAIL (%0d errors)", errors);

        $finish;
    end
endmodule
