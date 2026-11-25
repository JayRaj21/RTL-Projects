`timescale 1ns/1ps

module cache_sa_cmp_tb;
    reg clk, reset, req, req2;
    reg [5:0] addr, addr2;
    wire v, hit, miss, m_req, m_done;
    wire [5:0] m_addr;
    wire [7:0] dout, m_dout;
    wire v2, hit2, miss2, m_req2, m_done2;
    wire [5:0] m_addr2;
    wire [7:0] dout2, m_dout2;

    backing_mem m1(.clk(clk), .reset(reset), .req(m_req), .addr(m_addr),
                    .busy(), .done(m_done), .dout(m_dout));

    cache_sa s(.clk(clk), .reset(reset), .req(req), .addr(addr), .v(v), .dout(dout),
               .hit(hit), .miss(miss), .m_req(m_req), .m_addr(m_addr),
               .m_done(m_done), .m_dout(m_dout));

    backing_mem m2(.clk(clk), .reset(reset), .req(m_req2), .addr(m_addr2),
                    .busy(), .done(m_done2), .dout(m_dout2));

    cache c(.clk(clk), .reset(reset), .req(req2), .addr(addr2), .v(v2), .dout(dout2),
            .hit(hit2), .miss(miss2), .m_req(m_req2), .m_addr(m_addr2),
            .m_done(m_done2), .m_dout(m_dout2));

    initial forever #5 clk = ~clk;

    integer n, f, n2, f2, k, errors;
    integer nhit, nmiss, nhit2, nmiss2;
    integer cm_s [1:8];
    integer cm_d [1:8];
    integer cyc_s, cyc_d;

    //ping-pongs 5/21, which share index 1: cache_sa keeps both resident,
    //cache (direct-mapped) thrashes. 10 is a non-conflicting reuse.
    reg [5:0] WL [1:8];
    integer DAT [1:8];
    integer CM_S [1:8];
    integer CM_D [1:8];

    //locality: 5,10,15 land in distinct sets, so cache_sa only ever fills way0
    reg [5:0] WL2 [1:7];
    integer DAT2 [1:7];
    integer CM_S2 [1:7];
    integer CM_D2 [1:7];

    //no reuse: 32..38; 36,37,38 share a set with 32,33,34 but nothing repeats
    reg [5:0] WL3 [1:7];
    integer DAT3 [1:7];
    integer CM_S3 [1:7];
    integer CM_D3 [1:7];

    initial begin
        $dumpfile("cache_sa_cmp_tb.vcd");
        $dumpvars(0, cache_sa_cmp_tb);

        clk = 0;
        reset = 1;
        req = 0;
        req2 = 0;
        errors = 0;

        WL[1]=5;  DAT[1]=105; CM_S[1]=6;  CM_D[1]=6;
        WL[2]=21; DAT[2]=121; CM_S[2]=12; CM_D[2]=12;
        WL[3]=5;  DAT[3]=105; CM_S[3]=13; CM_D[3]=18;
        WL[4]=21; DAT[4]=121; CM_S[4]=14; CM_D[4]=24;
        WL[5]=10; DAT[5]=110; CM_S[5]=20; CM_D[5]=30;
        WL[6]=5;  DAT[6]=105; CM_S[6]=21; CM_D[6]=36;
        WL[7]=21; DAT[7]=121; CM_S[7]=22; CM_D[7]=42;
        WL[8]=10; DAT[8]=110; CM_S[8]=23; CM_D[8]=43;

        WL2[1]=5;  DAT2[1]=105; CM_S2[1]=6;  CM_D2[1]=6;
        WL2[2]=10; DAT2[2]=110; CM_S2[2]=12; CM_D2[2]=12;
        WL2[3]=5;  DAT2[3]=105; CM_S2[3]=13; CM_D2[3]=13;
        WL2[4]=15; DAT2[4]=115; CM_S2[4]=19; CM_D2[4]=19;
        WL2[5]=5;  DAT2[5]=105; CM_S2[5]=20; CM_D2[5]=20;
        WL2[6]=10; DAT2[6]=110; CM_S2[6]=21; CM_D2[6]=21;
        WL2[7]=5;  DAT2[7]=105; CM_S2[7]=22; CM_D2[7]=22;

        WL3[1]=32; DAT3[1]=132; CM_S3[1]=6;  CM_D3[1]=6;
        WL3[2]=33; DAT3[2]=133; CM_S3[2]=12; CM_D3[2]=12;
        WL3[3]=34; DAT3[3]=134; CM_S3[3]=18; CM_D3[3]=18;
        WL3[4]=35; DAT3[4]=135; CM_S3[4]=24; CM_D3[4]=24;
        WL3[5]=36; DAT3[5]=136; CM_S3[5]=30; CM_D3[5]=30;
        WL3[6]=37; DAT3[6]=137; CM_S3[6]=36; CM_D3[6]=36;
        WL3[7]=38; DAT3[7]=138; CM_S3[7]=42; CM_D3[7]=42;

        repeat (2) @(posedge clk);
        reset <= 0;

        nhit = 0;
        nmiss = 0;
        nhit2 = 0;
        nmiss2 = 0;
        cyc_s = 0;
        cyc_d = 0;

        for (k = 1; k <= 8; k = k + 1) begin
            fork
                begin
                    req <= 1;
                    addr <= WL[k];
                    n = 0;
                    f = 0;
                    while (!f && n < 20) begin
                        @(posedge clk); #1;
                        n = n + 1;
                        if (n == 1) req <= 0;
                        nhit = nhit + (s.hit === 1);
                        nmiss = nmiss + (s.miss === 1);
                        if (v === 1) f = 1;
                    end
                    cyc_s = cyc_s + n;
                    cm_s[k] = cyc_s;
                    if (dout !== DAT[k]) begin
                        errors = errors + 1;
                        $display("FAIL: cache_sa access %0d data=%0d expected %0d", k, dout, DAT[k]);
                    end
                end
                begin
                    req2 <= 1;
                    addr2 <= WL[k];
                    n2 = 0;
                    f2 = 0;
                    while (!f2 && n2 < 20) begin
                        @(posedge clk); #1;
                        n2 = n2 + 1;
                        if (n2 == 1) req2 <= 0;
                        nhit2 = nhit2 + (c.hit === 1);
                        nmiss2 = nmiss2 + (c.miss === 1);
                        if (v2 === 1) f2 = 1;
                    end
                    cyc_d = cyc_d + n2;
                    cm_d[k] = cyc_d;
                    if (dout2 !== DAT[k]) begin
                        errors = errors + 1;
                        $display("FAIL: cache access %0d data=%0d expected %0d", k, dout2, DAT[k]);
                    end
                end
            join
        end

        for (k = 1; k <= 8; k = k + 1) begin
            if (cm_s[k] != CM_S[k]) begin
                errors = errors + 1;
                $display("FAIL: cache_sa completion cycle %0d=%0d expected %0d", k, cm_s[k], CM_S[k]);
            end
            if (cm_d[k] != CM_D[k]) begin
                errors = errors + 1;
                $display("FAIL: cache completion cycle %0d=%0d expected %0d", k, cm_d[k], CM_D[k]);
            end
        end

        if (nhit != 5) begin
            errors = errors + 1;
            $display("FAIL: cache_sa nhit=%0d expected 5", nhit);
        end
        if (nmiss != 3) begin
            errors = errors + 1;
            $display("FAIL: cache_sa nmiss=%0d expected 3", nmiss);
        end
        if (nhit2 != 1) begin
            errors = errors + 1;
            $display("FAIL: cache nhit=%0d expected 1", nhit2);
        end
        if (nmiss2 != 7) begin
            errors = errors + 1;
            $display("FAIL: cache nmiss=%0d expected 7", nmiss2);
        end

        if (s.vld0 !== 4'b0110) begin
            errors = errors + 1;
            $display("FAIL: s.vld0=%b expected 0110", s.vld0);
        end
        if (s.vld1 !== 4'b0010) begin
            errors = errors + 1;
            $display("FAIL: s.vld1=%b expected 0010", s.vld1);
        end
        if (s.lru !== 4'b0100) begin
            errors = errors + 1;
            $display("FAIL: s.lru=%b expected 0100", s.lru);
        end
        if (s.tag0[1] !== 1) begin
            errors = errors + 1;
            $display("FAIL: s.tag0[1]=%0d expected 1", s.tag0[1]);
        end
        if (s.tag1[1] !== 5) begin
            errors = errors + 1;
            $display("FAIL: s.tag1[1]=%0d expected 5", s.tag1[1]);
        end
        if (c.vld !== 4'b0110) begin
            errors = errors + 1;
            $display("FAIL: c.vld=%b expected 0110", c.vld);
        end
        if (c.tag[1] !== 5) begin
            errors = errors + 1;
            $display("FAIL: c.tag[1]=%0d expected 5", c.tag[1]);
        end
        if (c.tag[2] !== 2) begin
            errors = errors + 1;
            $display("FAIL: c.tag[2]=%0d expected 2", c.tag[2]);
        end

        $display("conflict: cache_sa=%0d cycles (%0d miss %0d hit)  cache=%0d cycles (%0d miss %0d hit)",
                  cm_s[8], nmiss, nhit, cm_d[8], nmiss2, nhit2);

        reset <= 1;
        repeat (2) @(posedge clk);
        reset <= 0;

        nhit = 0;
        nmiss = 0;
        nhit2 = 0;
        nmiss2 = 0;
        cyc_s = 0;
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
                        nhit = nhit + (s.hit === 1);
                        nmiss = nmiss + (s.miss === 1);
                        if (v === 1) f = 1;
                    end
                    cyc_s = cyc_s + n;
                    cm_s[k] = cyc_s;
                    if (dout !== DAT2[k]) begin
                        errors = errors + 1;
                        $display("FAIL: wl2 cache_sa access %0d data=%0d expected %0d", k, dout, DAT2[k]);
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
                        nhit2 = nhit2 + (c.hit === 1);
                        nmiss2 = nmiss2 + (c.miss === 1);
                        if (v2 === 1) f2 = 1;
                    end
                    cyc_d = cyc_d + n2;
                    cm_d[k] = cyc_d;
                    if (dout2 !== DAT2[k]) begin
                        errors = errors + 1;
                        $display("FAIL: wl2 cache access %0d data=%0d expected %0d", k, dout2, DAT2[k]);
                    end
                end
            join
        end

        for (k = 1; k <= 7; k = k + 1) begin
            if (cm_s[k] != CM_S2[k]) begin
                errors = errors + 1;
                $display("FAIL: wl2 cache_sa completion cycle %0d=%0d expected %0d", k, cm_s[k], CM_S2[k]);
            end
            if (cm_d[k] != CM_D2[k]) begin
                errors = errors + 1;
                $display("FAIL: wl2 cache completion cycle %0d=%0d expected %0d", k, cm_d[k], CM_D2[k]);
            end
        end

        if (nhit != 4) begin
            errors = errors + 1;
            $display("FAIL: wl2 cache_sa nhit=%0d expected 4", nhit);
        end
        if (nmiss != 3) begin
            errors = errors + 1;
            $display("FAIL: wl2 cache_sa nmiss=%0d expected 3", nmiss);
        end
        if (nhit2 != 4) begin
            errors = errors + 1;
            $display("FAIL: wl2 cache nhit=%0d expected 4", nhit2);
        end
        if (nmiss2 != 3) begin
            errors = errors + 1;
            $display("FAIL: wl2 cache nmiss=%0d expected 3", nmiss2);
        end

        if (s.vld0 !== 4'b1110) begin
            errors = errors + 1;
            $display("FAIL: wl2 s.vld0=%b expected 1110", s.vld0);
        end
        if (s.vld1 !== 4'b0000) begin
            errors = errors + 1;
            $display("FAIL: wl2 s.vld1=%b expected 0000", s.vld1);
        end
        if (s.lru !== 4'b1110) begin
            errors = errors + 1;
            $display("FAIL: wl2 s.lru=%b expected 1110", s.lru);
        end
        if (s.tag0[3] !== 3) begin
            errors = errors + 1;
            $display("FAIL: wl2 s.tag0[3]=%0d expected 3", s.tag0[3]);
        end
        if (c.vld !== 4'b1110) begin
            errors = errors + 1;
            $display("FAIL: wl2 c.vld=%b expected 1110", c.vld);
        end
        if (c.tag[3] !== 3) begin
            errors = errors + 1;
            $display("FAIL: wl2 c.tag[3]=%0d expected 3", c.tag[3]);
        end

        $display("locality: cache_sa=%0d cycles (%0d miss %0d hit)  cache=%0d cycles (%0d miss %0d hit)",
                  cm_s[7], nmiss, nhit, cm_d[7], nmiss2, nhit2);

        reset <= 1;
        repeat (2) @(posedge clk);
        reset <= 0;

        nhit = 0;
        nmiss = 0;
        nhit2 = 0;
        nmiss2 = 0;
        cyc_s = 0;
        cyc_d = 0;

        for (k = 1; k <= 7; k = k + 1) begin
            fork
                begin
                    req <= 1;
                    addr <= WL3[k];
                    n = 0;
                    f = 0;
                    while (!f && n < 20) begin
                        @(posedge clk); #1;
                        n = n + 1;
                        if (n == 1) req <= 0;
                        nhit = nhit + (s.hit === 1);
                        nmiss = nmiss + (s.miss === 1);
                        if (v === 1) f = 1;
                    end
                    cyc_s = cyc_s + n;
                    cm_s[k] = cyc_s;
                    if (dout !== DAT3[k]) begin
                        errors = errors + 1;
                        $display("FAIL: wl3 cache_sa access %0d data=%0d expected %0d", k, dout, DAT3[k]);
                    end
                end
                begin
                    req2 <= 1;
                    addr2 <= WL3[k];
                    n2 = 0;
                    f2 = 0;
                    while (!f2 && n2 < 20) begin
                        @(posedge clk); #1;
                        n2 = n2 + 1;
                        if (n2 == 1) req2 <= 0;
                        nhit2 = nhit2 + (c.hit === 1);
                        nmiss2 = nmiss2 + (c.miss === 1);
                        if (v2 === 1) f2 = 1;
                    end
                    cyc_d = cyc_d + n2;
                    cm_d[k] = cyc_d;
                    if (dout2 !== DAT3[k]) begin
                        errors = errors + 1;
                        $display("FAIL: wl3 cache access %0d data=%0d expected %0d", k, dout2, DAT3[k]);
                    end
                end
            join
        end

        for (k = 1; k <= 7; k = k + 1) begin
            if (cm_s[k] != CM_S3[k]) begin
                errors = errors + 1;
                $display("FAIL: wl3 cache_sa completion cycle %0d=%0d expected %0d", k, cm_s[k], CM_S3[k]);
            end
            if (cm_d[k] != CM_D3[k]) begin
                errors = errors + 1;
                $display("FAIL: wl3 cache completion cycle %0d=%0d expected %0d", k, cm_d[k], CM_D3[k]);
            end
        end

        if (nhit != 0) begin
            errors = errors + 1;
            $display("FAIL: wl3 cache_sa nhit=%0d expected 0", nhit);
        end
        if (nmiss != 7) begin
            errors = errors + 1;
            $display("FAIL: wl3 cache_sa nmiss=%0d expected 7", nmiss);
        end
        if (nhit2 != 0) begin
            errors = errors + 1;
            $display("FAIL: wl3 cache nhit=%0d expected 0", nhit2);
        end
        if (nmiss2 != 7) begin
            errors = errors + 1;
            $display("FAIL: wl3 cache nmiss=%0d expected 7", nmiss2);
        end

        if (s.vld0 !== 4'b1111) begin
            errors = errors + 1;
            $display("FAIL: wl3 s.vld0=%b expected 1111", s.vld0);
        end
        if (s.vld1 !== 4'b0111) begin
            errors = errors + 1;
            $display("FAIL: wl3 s.vld1=%b expected 0111", s.vld1);
        end
        if (s.lru !== 4'b1000) begin
            errors = errors + 1;
            $display("FAIL: wl3 s.lru=%b expected 1000", s.lru);
        end
        if (s.tag0[0] !== 8) begin
            errors = errors + 1;
            $display("FAIL: wl3 s.tag0[0]=%0d expected 8", s.tag0[0]);
        end
        if (s.tag1[0] !== 9) begin
            errors = errors + 1;
            $display("FAIL: wl3 s.tag1[0]=%0d expected 9", s.tag1[0]);
        end
        if (s.tag0[2] !== 8) begin
            errors = errors + 1;
            $display("FAIL: wl3 s.tag0[2]=%0d expected 8", s.tag0[2]);
        end
        if (s.tag1[2] !== 9) begin
            errors = errors + 1;
            $display("FAIL: wl3 s.tag1[2]=%0d expected 9", s.tag1[2]);
        end
        if (s.tag0[3] !== 8) begin
            errors = errors + 1;
            $display("FAIL: wl3 s.tag0[3]=%0d expected 8", s.tag0[3]);
        end
        if (c.vld !== 4'b1111) begin
            errors = errors + 1;
            $display("FAIL: wl3 c.vld=%b expected 1111", c.vld);
        end
        if (c.tag[0] !== 9) begin
            errors = errors + 1;
            $display("FAIL: wl3 c.tag[0]=%0d expected 9", c.tag[0]);
        end
        if (c.tag[2] !== 9) begin
            errors = errors + 1;
            $display("FAIL: wl3 c.tag[2]=%0d expected 9", c.tag[2]);
        end
        if (c.tag[3] !== 8) begin
            errors = errors + 1;
            $display("FAIL: wl3 c.tag[3]=%0d expected 8", c.tag[3]);
        end

        $display("no reuse: cache_sa=%0d cycles (%0d miss %0d hit)  cache=%0d cycles (%0d miss %0d hit)",
                  cm_s[7], nmiss, nhit, cm_d[7], nmiss2, nhit2);

        if (errors != 0)
            $display("FAIL (%0d errors)", errors);

        $finish;
    end
endmodule
