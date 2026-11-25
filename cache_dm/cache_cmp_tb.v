`timescale 1ns/1ps

module cache_cmp_tb;
    reg clk, reset, req, req2;
    reg [5:0] addr, addr2;
    wire v, hit, miss, m_req, m_done;
    wire [5:0] m_addr;
    wire [7:0] dout, m_dout;
    wire busy2, done2;
    wire [7:0] dout2;

    backing_mem m1(.clk(clk), .reset(reset), .req(m_req), .addr(m_addr),
                    .busy(), .done(m_done), .dout(m_dout));

    cache c(.clk(clk), .reset(reset), .req(req), .addr(addr), .v(v), .dout(dout),
            .hit(hit), .miss(miss), .m_req(m_req), .m_addr(m_addr),
            .m_done(m_done), .m_dout(m_dout));

    backing_mem m2(.clk(clk), .reset(reset), .req(req2), .addr(addr2),
                    .busy(busy2), .done(done2), .dout(dout2));

    initial forever #5 clk = ~clk;

    integer i, n, f, n2, f2, errors;
    integer nhit, nmiss;
    integer cm_c [1:7];
    integer cm_d [1:7];

    reg [5:0] WL1 [1:7];
    integer DAT1 [1:7];
    integer CM_C1 [1:7];
    integer CM_D1 [1:7];

    reg [5:0] WL2 [1:7];
    integer DAT2 [1:7];
    integer CM_C2 [1:7];
    integer CM_D2 [1:7];

    integer cyc_c, cyc_d, k;

    initial begin
        $dumpfile("cache_cmp_tb.vcd");
        $dumpvars(0, cache_cmp_tb);

        clk = 0;
        reset = 1;
        req = 0;
        req2 = 0;
        errors = 0;

        //workload 1: has reuse, A=5 B=10 C=15 (tags/indices distinct, no conflicts)
        WL1[1] = 5;  DAT1[1] = 105; CM_C1[1] = 6;  CM_D1[1] = 4;
        WL1[2] = 10; DAT1[2] = 110; CM_C1[2] = 12; CM_D1[2] = 8;
        WL1[3] = 5;  DAT1[3] = 105; CM_C1[3] = 13; CM_D1[3] = 12;
        WL1[4] = 15; DAT1[4] = 115; CM_C1[4] = 19; CM_D1[4] = 16;
        WL1[5] = 5;  DAT1[5] = 105; CM_C1[5] = 20; CM_D1[5] = 20;
        WL1[6] = 10; DAT1[6] = 110; CM_C1[6] = 21; CM_D1[6] = 24;
        WL1[7] = 5;  DAT1[7] = 105; CM_C1[7] = 22; CM_D1[7] = 28;

        //workload 2: no reuse, 32..38
        WL2[1] = 32; DAT2[1] = 132; CM_C2[1] = 6;  CM_D2[1] = 4;
        WL2[2] = 33; DAT2[2] = 133; CM_C2[2] = 12; CM_D2[2] = 8;
        WL2[3] = 34; DAT2[3] = 134; CM_C2[3] = 18; CM_D2[3] = 12;
        WL2[4] = 35; DAT2[4] = 135; CM_C2[4] = 24; CM_D2[4] = 16;
        WL2[5] = 36; DAT2[5] = 136; CM_C2[5] = 30; CM_D2[5] = 20;
        WL2[6] = 37; DAT2[6] = 137; CM_C2[6] = 36; CM_D2[6] = 24;
        WL2[7] = 38; DAT2[7] = 138; CM_C2[7] = 42; CM_D2[7] = 28;

        repeat (2) @(posedge clk);
        reset <= 0;

        nhit = 0;
        nmiss = 0;
        cyc_c = 0;
        cyc_d = 0;
        for (k = 1; k <= 7; k = k + 1) begin
            fork
                begin
                    req <= 1;
                    addr <= WL1[k];
                    n = 0;
                    f = 0;
                    while (!f && n < 20) begin
                        @(posedge clk); #1;
                        n = n + 1;
                        if (n == 1) req <= 0;
                        nhit = nhit + (c.hit === 1);
                        nmiss = nmiss + (c.miss === 1);
                        if (v === 1) f = 1;
                    end
                    cyc_c = cyc_c + n;
                    cm_c[k] = cyc_c;
                    if (dout !== DAT1[k]) begin
                        errors = errors + 1;
                        $display("FAIL: wl1 cache access %0d data=%0d expected %0d", k, dout, DAT1[k]);
                    end
                end
                begin
                    req2 <= 1;
                    addr2 <= WL1[k];
                    n2 = 0;
                    f2 = 0;
                    while (!f2 && n2 < 20) begin
                        @(posedge clk); #1;
                        n2 = n2 + 1;
                        if (n2 == 1) req2 <= 0;
                        if (done2 === 1) f2 = 1;
                    end
                    cyc_d = cyc_d + n2;
                    cm_d[k] = cyc_d;
                    if (dout2 !== DAT1[k]) begin
                        errors = errors + 1;
                        $display("FAIL: wl1 no-cache access %0d data=%0d expected %0d", k, dout2, DAT1[k]);
                    end
                end
            join
        end

        for (k = 1; k <= 7; k = k + 1) begin
            if (cm_c[k] != CM_C1[k]) begin
                errors = errors + 1;
                $display("FAIL: wl1 cache completion cycle %0d=%0d expected %0d", k, cm_c[k], CM_C1[k]);
            end
            if (cm_d[k] != CM_D1[k]) begin
                errors = errors + 1;
                $display("FAIL: wl1 no-cache completion cycle %0d=%0d expected %0d", k, cm_d[k], CM_D1[k]);
            end
        end

        if (nhit != 4) begin
            errors = errors + 1;
            $display("FAIL: workload1 nhit=%0d expected 4", nhit);
        end
        if (nmiss != 3) begin
            errors = errors + 1;
            $display("FAIL: workload1 nmiss=%0d expected 3", nmiss);
        end
        $display("locality: cache=%0d cycles (%0d miss %0d hit)  no-cache=%0d cycles",
                  cm_c[7], nmiss, nhit, cm_d[7]);

        reset <= 1;
        repeat (2) @(posedge clk);
        reset <= 0;

        nhit = 0;
        nmiss = 0;
        cyc_c = 0;
        cyc_d = 0;
        for (k = 1; k <= 7; k = k + 1) begin
            fork
                begin
                    req <= 1;
                    addr <= WL2[k];
                    n = 0;
                    f = 0;
                    while (!f && n < 20) begin
                        @(posedge clk); #1;
                        n = n + 1;
                        if (n == 1) req <= 0;
                        nhit = nhit + (c.hit === 1);
                        nmiss = nmiss + (c.miss === 1);
                        if (v === 1) f = 1;
                    end
                    cyc_c = cyc_c + n;
                    cm_c[k] = cyc_c;
                    if (dout !== DAT2[k]) begin
                        errors = errors + 1;
                        $display("FAIL: wl2 cache access %0d data=%0d expected %0d", k, dout, DAT2[k]);
                    end
                end
                begin
                    req2 <= 1;
                    addr2 <= WL2[k];
                    n2 = 0;
                    f2 = 0;
                    while (!f2 && n2 < 20) begin
                        @(posedge clk); #1;
                        n2 = n2 + 1;
                        if (n2 == 1) req2 <= 0;
                        if (done2 === 1) f2 = 1;
                    end
                    cyc_d = cyc_d + n2;
                    cm_d[k] = cyc_d;
                    if (dout2 !== DAT2[k]) begin
                        errors = errors + 1;
                        $display("FAIL: wl2 no-cache access %0d data=%0d expected %0d", k, dout2, DAT2[k]);
                    end
                end
            join
        end

        for (k = 1; k <= 7; k = k + 1) begin
            if (cm_c[k] != CM_C2[k]) begin
                errors = errors + 1;
                $display("FAIL: wl2 cache completion cycle %0d=%0d expected %0d", k, cm_c[k], CM_C2[k]);
            end
            if (cm_d[k] != CM_D2[k]) begin
                errors = errors + 1;
                $display("FAIL: wl2 no-cache completion cycle %0d=%0d expected %0d", k, cm_d[k], CM_D2[k]);
            end
        end

        if (nhit != 0) begin
            errors = errors + 1;
            $display("FAIL: workload2 nhit=%0d expected 0", nhit);
        end
        if (nmiss != 7) begin
            errors = errors + 1;
            $display("FAIL: workload2 nmiss=%0d expected 7", nmiss);
        end
        //the cache only pays off when addresses repeat; with no reuse, every
        //access pays the full latency plus the cache overhead
        $display("no reuse: cache=%0d cycles (%0d miss %0d hit)  no-cache=%0d cycles",
                  cm_c[7], nmiss, nhit, cm_d[7]);

        if (errors != 0)
            $display("FAIL (%0d errors)", errors);

        $finish;
    end
endmodule
