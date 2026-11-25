`timescale 1ns/1ps

module pipe_cmp_tb3;
    reg clk, reset;

    wire ooo_cdb_v;
    wire [1:0] ooo_cdb_tag;
    wire [7:0] ooo_cdb_val;
    wire [2:0] ooo_cdb_pc;
    wire ooo_c_v;
    wire [2:0] ooo_c_rd;
    wire [7:0] ooo_c_val;
    wire [2:0] ooo_c_pc;

    wire pip_c_v;
    wire [2:0] pip_c_rd;
    wire [7:0] pip_c_val;
    wire [3:0] pip_c_pc;

    //ooo vs pipelined in-order: both run program 3's pure dependency chain
    //on a shared clk/reset, to see if pipelining alone gets most of ooo's win
    ooo_core3 ooo(.clk(clk), .reset(reset), .cdb_v(ooo_cdb_v), .cdb_tag(ooo_cdb_tag),
                  .cdb_val(ooo_cdb_val), .cdb_pc(ooo_cdb_pc), .c_v(ooo_c_v),
                  .c_rd(ooo_c_rd), .c_val(ooo_c_val), .c_pc(ooo_c_pc));

    pipe_core3 pip(.clk(clk), .reset(reset), .c_v(pip_c_v), .c_rd(pip_c_rd),
                   .c_val(pip_c_val), .c_pc(pip_c_pc));

    initial forever #5 clk = ~clk;

    integer i;
    integer ooo_ncommit, pip_ncommit, errors;
    integer ooo_cm [1:5];
    integer pip_cm [1:5];
    integer nstall, nfwd, nbyp;

    //pinned from simulation - see plan step 1 and step 3
    integer OOO_CM [1:5];
    integer PIPE_CM [1:5];

    task report_register(input [2:0] reg_num, input [7:0] expected);
        reg [7:0] ooo_val, pip_val;
        begin
            ooo_val = ooo.rf.registers[reg_num];
            pip_val = pip.rf.registers[reg_num];
            $display("x%0d ooo=%0d pip=%0d (expect %0d)", reg_num, ooo_val, pip_val, expected);
            if (ooo_val !== expected) errors = errors + 1;
            if (pip_val !== expected) errors = errors + 1;
        end
    endtask

    initial begin
        $dumpfile("pipe_cmp_tb3.vcd");
        $dumpvars(0, pipe_cmp_tb3);

        clk = 0;
        reset = 1;
        errors = 0;
        ooo_ncommit = 0;
        pip_ncommit = 0;
        nstall = 0;
        nfwd = 0;
        nbyp = 0;
        for (i = 1; i <= 5; i = i + 1) begin
            ooo_cm[i] = 0;
            pip_cm[i] = 0;
        end

        OOO_CM[1] = 3;  OOO_CM[2] = 5;  OOO_CM[3] = 7;  OOO_CM[4] = 9;  OOO_CM[5] = 11;
        PIPE_CM[1] = 2; PIPE_CM[2] = 3; PIPE_CM[3] = 4; PIPE_CM[4] = 5; PIPE_CM[5] = 6;

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
                if (ooo_c_rd != ooo_c_pc + 1) begin
                    errors = errors + 1;
                    $display("FAIL: ooo c_rd=%0d expected %0d", ooo_c_rd, ooo_c_pc + 1);
                end
                if (ooo_c_val !== ooo_c_pc + 5) begin
                    errors = errors + 1;
                    $display("FAIL: ooo c_val=%0d expected %0d", ooo_c_val, ooo_c_pc + 5);
                end
                ooo_cm[ooo_c_pc + 1] = i;
                ooo_ncommit = ooo_ncommit + 1;
            end

            if (pip_c_v) begin
                $display("cyc=%0d PIPE COMMIT: I%0d rd=%0d val=%0d", i, pip_c_pc + 1, pip_c_rd, pip_c_val);
                if (pip_c_pc + 1 != pip_ncommit + 1) begin
                    errors = errors + 1;
                    $display("FAIL: pipe out-of-order commit, got I%0d expected I%0d", pip_c_pc + 1, pip_ncommit + 1);
                end
                if (pip_c_rd != pip_c_pc + 1) begin
                    errors = errors + 1;
                    $display("FAIL: pipe c_rd=%0d expected %0d", pip_c_rd, pip_c_pc + 1);
                end
                if (pip_c_val !== pip_c_pc + 5) begin
                    errors = errors + 1;
                    $display("FAIL: pipe c_val=%0d expected %0d", pip_c_val, pip_c_pc + 5);
                end
                pip_cm[pip_c_pc + 1] = i;
                pip_ncommit = pip_ncommit + 1;
            end

            nstall = nstall + (pip.stall === 1);
            nfwd   = nfwd   + (pip.go === 1 && (pip.fwd_a === 1 || pip.fwd_b === 1));
            nbyp   = nbyp   + (pip.byp_a === 1 || pip.byp_b === 1);
        end

        if (ooo_ncommit != 5) begin
            errors = errors + 1;
            $display("FAIL: ooo ncommit=%0d expected 5", ooo_ncommit);
        end
        if (pip_ncommit != 5) begin
            errors = errors + 1;
            $display("FAIL: pipe ncommit=%0d expected 5", pip_ncommit);
        end

        report_register(1, 5);
        report_register(2, 6);
        report_register(3, 7);
        report_register(4, 8);
        report_register(5, 9);

        for (i = 1; i <= 5; i = i + 1) begin
            if (ooo_cm[i] != OOO_CM[i]) begin
                errors = errors + 1;
                $display("FAIL: ooo I%0d commit cycle=%0d expected %0d", i, ooo_cm[i], OOO_CM[i]);
            end
            if (pip_cm[i] != PIPE_CM[i]) begin
                errors = errors + 1;
                $display("FAIL: pipe I%0d commit cycle=%0d expected %0d", i, pip_cm[i], PIPE_CM[i]);
            end
        end

        if (nstall != 0) begin
            errors = errors + 1;
            $display("FAIL: nstall=%0d expected 0", nstall);
        end
        if (nfwd != 4) begin
            errors = errors + 1;
            $display("FAIL: nfwd=%0d expected 4", nfwd);
        end
        if (nbyp != 0) begin
            errors = errors + 1;
            $display("FAIL: nbyp=%0d expected 0", nbyp);
        end

        $display("pipe=%0d cycles  ooo=%0d cycles", pip_cm[5], ooo_cm[5]);

        if (errors != 0)
            $display("FAIL (%0d errors)", errors);

        $finish;
    end
endmodule
