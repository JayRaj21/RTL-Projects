`timescale 1ns/1ps

module cache_sa_tb;
    reg clk, reset, req;
    reg [5:0] addr;
    wire v, hit, miss, m_req, m_done;
    wire [5:0] m_addr;
    wire [7:0] dout, m_dout;

    backing_mem m(.clk(clk), .reset(reset), .req(m_req), .addr(m_addr),
                   .busy(), .done(m_done), .dout(m_dout));

    cache_sa c(.clk(clk), .reset(reset), .req(req), .addr(addr), .v(v), .dout(dout),
               .hit(hit), .miss(miss), .m_req(m_req), .m_addr(m_addr),
               .m_done(m_done), .m_dout(m_dout));

    initial forever #5 clk = ~clk;

    integer i, n;
    integer nhit, nmiss, nmem, tot, errors, f;
    integer hit0, miss0;

    //5/21/37/53 all map to set 1 (idx1); 10 maps to set 2 (idx2), no conflict
    reg [5:0] ADDR [1:14];
    reg ISHIT [1:14];
    integer CYC [1:14];
    integer DAT [1:14];
    reg [3:0] V0 [1:14];
    reg [3:0] V1 [1:14];
    reg [3:0] L [1:14];
    reg [3:0] T0 [1:14];
    reg [3:0] T1 [1:14];

    initial begin
        $dumpfile("cache_sa_tb.vcd");
        $dumpvars(0, cache_sa_tb);

        clk = 0;
        reset = 1;
        req = 0;
        errors = 0;
        nhit = 0;
        nmiss = 0;
        nmem = 0;
        tot = 0;

        ADDR[1]=5;  ISHIT[1]=0; CYC[1]=6; DAT[1]=105; V0[1]=4'b0010; V1[1]=4'b0000; L[1]=4'b0010; T0[1]=1;    T1[1]=4'bx;
        ADDR[2]=5;  ISHIT[2]=1; CYC[2]=1; DAT[2]=105; V0[2]=4'b0010; V1[2]=4'b0000; L[2]=4'b0010; T0[2]=1;    T1[2]=4'bx;
        ADDR[3]=10; ISHIT[3]=0; CYC[3]=6; DAT[3]=110; V0[3]=4'b0110; V1[3]=4'b0000; L[3]=4'b0110; T0[3]=1;    T1[3]=4'bx;
        ADDR[4]=21; ISHIT[4]=0; CYC[4]=6; DAT[4]=121; V0[4]=4'b0110; V1[4]=4'b0010; L[4]=4'b0100; T0[4]=1;    T1[4]=5;
        ADDR[5]=5;  ISHIT[5]=1; CYC[5]=1; DAT[5]=105; V0[5]=4'b0110; V1[5]=4'b0010; L[5]=4'b0110; T0[5]=1;    T1[5]=5;
        ADDR[6]=21; ISHIT[6]=1; CYC[6]=1; DAT[6]=121; V0[6]=4'b0110; V1[6]=4'b0010; L[6]=4'b0100; T0[6]=1;    T1[6]=5;
        ADDR[7]=5;  ISHIT[7]=1; CYC[7]=1; DAT[7]=105; V0[7]=4'b0110; V1[7]=4'b0010; L[7]=4'b0110; T0[7]=1;    T1[7]=5;
        ADDR[8]=37; ISHIT[8]=0; CYC[8]=6; DAT[8]=137; V0[8]=4'b0110; V1[8]=4'b0010; L[8]=4'b0100; T0[8]=1;    T1[8]=9;
        ADDR[9]=5;  ISHIT[9]=1; CYC[9]=1; DAT[9]=105; V0[9]=4'b0110; V1[9]=4'b0010; L[9]=4'b0110; T0[9]=1;    T1[9]=9;
        ADDR[10]=21; ISHIT[10]=0; CYC[10]=6; DAT[10]=121; V0[10]=4'b0110; V1[10]=4'b0010; L[10]=4'b0100; T0[10]=1; T1[10]=5;
        ADDR[11]=10; ISHIT[11]=1; CYC[11]=1; DAT[11]=110; V0[11]=4'b0110; V1[11]=4'b0010; L[11]=4'b0100; T0[11]=1; T1[11]=5;
        ADDR[12]=53; ISHIT[12]=0; CYC[12]=6; DAT[12]=153; V0[12]=4'b0110; V1[12]=4'b0010; L[12]=4'b0110; T0[12]=13; T1[12]=5;
        ADDR[13]=21; ISHIT[13]=1; CYC[13]=1; DAT[13]=121; V0[13]=4'b0110; V1[13]=4'b0010; L[13]=4'b0100; T0[13]=13; T1[13]=5;
        ADDR[14]=5;  ISHIT[14]=0; CYC[14]=6; DAT[14]=105; V0[14]=4'b0110; V1[14]=4'b0010; L[14]=4'b0110; T0[14]=1; T1[14]=5;

        repeat (2) @(posedge clk);
        reset <= 0;

        for (i = 1; i <= 14; i = i + 1) begin
            hit0 = nhit;
            miss0 = nmiss;

            req <= 1;
            addr <= ADDR[i];
            n = 0;
            f = 0;
            while (!f && n < 20) begin
                @(posedge clk); #1;
                n = n + 1;
                if (n == 1) req <= 0;
                //access 1 is a miss (addr=5); perturb addr mid-FETCH with a
                //different-set address (10) to prove refill uses ra, not addr
                if (i == 1 && n >= 2 && n <= 4) addr <= 10;
                nhit = nhit + (c.hit === 1);
                nmiss = nmiss + (c.miss === 1);
                nmem = nmem + (c.m_req === 1);
                if (v === 1) f = 1;
            end

            if (n >= 20) begin
                errors = errors + 1;
                $display("FAIL: access %0d never completed", i);
            end

            tot = tot + n;

            $display("access %0d addr=%0d cyc=%0d data=%0d %s", i, ADDR[i], n, dout,
                      ISHIT[i] ? "hit" : "miss");

            if (n != CYC[i]) begin
                errors = errors + 1;
                $display("FAIL: access %0d cycles=%0d expected %0d", i, n, CYC[i]);
            end
            if (dout !== DAT[i]) begin
                errors = errors + 1;
                $display("FAIL: access %0d data=%0d expected %0d", i, dout, DAT[i]);
            end
            if (ISHIT[i]) begin
                if (nhit - hit0 != 1 || nmiss - miss0 != 0) begin
                    errors = errors + 1;
                    $display("FAIL: access %0d expected hit pulse", i);
                end
            end
            else begin
                if (nmiss - miss0 != 1 || nhit - hit0 != 0) begin
                    errors = errors + 1;
                    $display("FAIL: access %0d expected miss pulse", i);
                end
            end

            if (c.vld0 !== V0[i]) begin
                errors = errors + 1;
                $display("FAIL: access %0d vld0=%b expected %b", i, c.vld0, V0[i]);
            end
            if (c.vld1 !== V1[i]) begin
                errors = errors + 1;
                $display("FAIL: access %0d vld1=%b expected %b", i, c.vld1, V1[i]);
            end
            if (c.lru !== L[i]) begin
                errors = errors + 1;
                $display("FAIL: access %0d lru=%b expected %b", i, c.lru, L[i]);
            end
            if (c.tag0[1] !== T0[i]) begin
                errors = errors + 1;
                $display("FAIL: access %0d tag0[1]=%0d expected %0d", i, c.tag0[1], T0[i]);
            end
            if (c.tag1[1] !== T1[i]) begin
                errors = errors + 1;
                $display("FAIL: access %0d tag1[1]=%0d expected %0d", i, c.tag1[1], T1[i]);
            end
        end

        if (c.tag0[2] !== 2) begin
            errors = errors + 1;
            $display("FAIL: tag0[2]=%0d expected 2", c.tag0[2]);
        end

        if (nhit != 7) begin
            errors = errors + 1;
            $display("FAIL: nhit=%0d expected 7", nhit);
        end
        if (nmiss != 7) begin
            errors = errors + 1;
            $display("FAIL: nmiss=%0d expected 7", nmiss);
        end
        if (nmem != 7) begin
            errors = errors + 1;
            $display("FAIL: nmem=%0d expected 7", nmem);
        end
        if (tot != 49) begin
            errors = errors + 1;
            $display("FAIL: cycles=%0d expected 49", tot);
        end

        $display("hits=%0d misses=%0d cycles=%0d", nhit, nmiss, tot);

        if (errors != 0)
            $display("FAIL (%0d errors)", errors);

        $finish;
    end
endmodule
