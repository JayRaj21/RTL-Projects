`timescale 1ns/1ps

module cache_fifo_tb;
    reg clk, reset, req;
    reg [5:0] addr;
    wire v, hit, miss, m_req, m_done;
    wire [5:0] m_addr;
    wire [7:0] dout, m_dout;

    backing_mem m(.clk(clk), .reset(reset), .req(m_req), .addr(m_addr),
                   .busy(), .done(m_done), .dout(m_dout));

    cache_fifo c(.clk(clk), .reset(reset), .req(req), .addr(addr), .v(v), .dout(dout),
                 .hit(hit), .miss(miss), .m_req(m_req), .m_addr(m_addr),
                 .m_done(m_done), .m_dout(m_dout));

    initial forever #5 clk = ~clk;

    integer i, n;
    integer nhit, nmiss, nmem, tot, errors, f;
    integer hit0, miss0;

    //A=5 B=9 C=13 D=17 E=21 F=25 all map to set 1; 10 maps to set 2, no conflict
    reg [5:0] ADDR [1:12];
    reg ISHIT [1:12];
    integer CYC [1:12];
    integer DAT [1:12];
    reg [3:0] V [1:12];
    reg [3:0] T0 [1:12];
    reg [3:0] T1 [1:12];
    reg [3:0] T2 [1:12];
    reg [3:0] T3 [1:12];
    reg [1:0] S [1:12];

    initial begin
        $dumpfile("cache_fifo_tb.vcd");
        $dumpvars(0, cache_fifo_tb);

        clk = 0;
        reset = 1;
        req = 0;
        errors = 0;
        nhit = 0;
        nmiss = 0;
        nmem = 0;
        tot = 0;

        ADDR[1]=5;  ISHIT[1]=0; CYC[1]=6; DAT[1]=105;
        ADDR[2]=9;  ISHIT[2]=0; CYC[2]=6; DAT[2]=109;
        ADDR[3]=13; ISHIT[3]=0; CYC[3]=6; DAT[3]=113;
        ADDR[4]=17; ISHIT[4]=0; CYC[4]=6; DAT[4]=117;
        ADDR[5]=5;  ISHIT[5]=1; CYC[5]=1; DAT[5]=105;
        ADDR[6]=21; ISHIT[6]=0; CYC[6]=6; DAT[6]=121;
        ADDR[7]=5;  ISHIT[7]=0; CYC[7]=6; DAT[7]=105;
        ADDR[8]=13; ISHIT[8]=1; CYC[8]=1; DAT[8]=113;
        ADDR[9]=25; ISHIT[9]=0; CYC[9]=6; DAT[9]=125;
        ADDR[10]=5; ISHIT[10]=1; CYC[10]=1; DAT[10]=105;
        ADDR[11]=13; ISHIT[11]=0; CYC[11]=6; DAT[11]=113;
        ADDR[12]=10; ISHIT[12]=0; CYC[12]=6; DAT[12]=110;

        V[1]=4'b0001; V[2]=4'b0011; V[3]=4'b0111;
        V[4]=4'b1111; V[5]=4'b1111; V[6]=4'b1111; V[7]=4'b1111; V[8]=4'b1111;
        V[9]=4'b1111; V[10]=4'b1111; V[11]=4'b1111; V[12]=4'b1111;

        T0[1]=1;    T1[1]=4'bx; T2[1]=4'bx; T3[1]=4'bx;
        T0[2]=1;    T1[2]=2;    T2[2]=4'bx; T3[2]=4'bx;
        T0[3]=1;    T1[3]=2;    T2[3]=3;    T3[3]=4'bx;
        T0[4]=1;    T1[4]=2;    T2[4]=3;    T3[4]=4;
        T0[5]=1;    T1[5]=2;    T2[5]=3;    T3[5]=4;
        T0[6]=5;    T1[6]=2;    T2[6]=3;    T3[6]=4;
        T0[7]=5;    T1[7]=1;    T2[7]=3;    T3[7]=4;
        T0[8]=5;    T1[8]=1;    T2[8]=3;    T3[8]=4;
        T0[9]=5;    T1[9]=1;    T2[9]=6;    T3[9]=4;
        T0[10]=5;   T1[10]=1;   T2[10]=6;   T3[10]=4;
        T0[11]=5;   T1[11]=1;   T2[11]=6;   T3[11]=3;
        T0[12]=5;   T1[12]=1;   T2[12]=6;   T3[12]=3;

        S[1]=1;  S[2]=2;  S[3]=3;  S[4]=0;  S[5]=0;  S[6]=1;
        S[7]=2;  S[8]=2;  S[9]=3;  S[10]=3; S[11]=0; S[12]=0;

        repeat (2) @(posedge clk);
        reset <= 0;

        for (i = 1; i <= 12; i = i + 1) begin
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

            if ({c.vld3[1],c.vld2[1],c.vld1[1],c.vld0[1]} !== V[i]) begin
                errors = errors + 1;
                $display("FAIL: access %0d V=%b expected %b", i, {c.vld3[1],c.vld2[1],c.vld1[1],c.vld0[1]}, V[i]);
            end
            if (c.tag0[1] !== T0[i]) begin
                errors = errors + 1;
                $display("FAIL: access %0d tag0[1]=%0d expected %0d", i, c.tag0[1], T0[i]);
            end
            if (c.tag1[1] !== T1[i]) begin
                errors = errors + 1;
                $display("FAIL: access %0d tag1[1]=%0d expected %0d", i, c.tag1[1], T1[i]);
            end
            if (c.tag2[1] !== T2[i]) begin
                errors = errors + 1;
                $display("FAIL: access %0d tag2[1]=%0d expected %0d", i, c.tag2[1], T2[i]);
            end
            if (c.tag3[1] !== T3[i]) begin
                errors = errors + 1;
                $display("FAIL: access %0d tag3[1]=%0d expected %0d", i, c.tag3[1], T3[i]);
            end
            if (c.ptr[1] !== S[i]) begin
                errors = errors + 1;
                $display("FAIL: access %0d ptr[1]=%0d expected %0d", i, c.ptr[1], S[i]);
            end
        end

        if (c.tag0[2] !== 2) begin
            errors = errors + 1;
            $display("FAIL: tag0[2]=%0d expected 2", c.tag0[2]);
        end
        if (c.vld0 !== 4'b0110) begin
            errors = errors + 1;
            $display("FAIL: vld0=%b expected 0110", c.vld0);
        end
        if (c.vld1 !== 4'b0010) begin
            errors = errors + 1;
            $display("FAIL: vld1=%b expected 0010", c.vld1);
        end
        if (c.vld2 !== 4'b0010) begin
            errors = errors + 1;
            $display("FAIL: vld2=%b expected 0010", c.vld2);
        end
        if (c.vld3 !== 4'b0010) begin
            errors = errors + 1;
            $display("FAIL: vld3=%b expected 0010", c.vld3);
        end
        if (c.ptr[2] !== 1) begin
            errors = errors + 1;
            $display("FAIL: ptr[2]=%0d expected 1", c.ptr[2]);
        end

        if (nhit != 3) begin
            errors = errors + 1;
            $display("FAIL: nhit=%0d expected 3", nhit);
        end
        if (nmiss != 9) begin
            errors = errors + 1;
            $display("FAIL: nmiss=%0d expected 9", nmiss);
        end
        if (nmem != 9) begin
            errors = errors + 1;
            $display("FAIL: nmem=%0d expected 9", nmem);
        end
        if (tot != 57) begin
            errors = errors + 1;
            $display("FAIL: cycles=%0d expected 57", tot);
        end

        $display("hits=%0d misses=%0d cycles=%0d", nhit, nmiss, tot);

        if (errors != 0)
            $display("FAIL (%0d errors)", errors);

        $finish;
    end
endmodule
