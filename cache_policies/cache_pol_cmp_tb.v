`timescale 1ns/1ps

module cache_pol_cmp_tb;
    reg clk, reset;
    reg req1, req2, req3, req4;
    reg [5:0] addr1, addr2, addr3, addr4;
    wire v1, hit1, miss1, m_req1, m_done1;
    wire v2, hit2, miss2, m_req2, m_done2;
    wire v3, hit3, miss3, m_req3, m_done3;
    wire v4, hit4, miss4, m_req4, m_done4;
    wire [5:0] m_addr1, m_addr2, m_addr3, m_addr4;
    wire [7:0] dout1, dout2, dout3, dout4;
    wire [7:0] m_dout1, m_dout2, m_dout3, m_dout4;

    backing_mem m1(.clk(clk), .reset(reset), .req(m_req1), .addr(m_addr1),
                    .busy(), .done(m_done1), .dout(m_dout1));
    backing_mem m2(.clk(clk), .reset(reset), .req(m_req2), .addr(m_addr2),
                    .busy(), .done(m_done2), .dout(m_dout2));
    backing_mem m3(.clk(clk), .reset(reset), .req(m_req3), .addr(m_addr3),
                    .busy(), .done(m_done3), .dout(m_dout3));
    backing_mem m4(.clk(clk), .reset(reset), .req(m_req4), .addr(m_addr4),
                    .busy(), .done(m_done4), .dout(m_dout4));

    cache_lru c1(.clk(clk), .reset(reset), .req(req1), .addr(addr1), .v(v1), .dout(dout1),
                 .hit(hit1), .miss(miss1), .m_req(m_req1), .m_addr(m_addr1),
                 .m_done(m_done1), .m_dout(m_dout1));
    cache_fifo c2(.clk(clk), .reset(reset), .req(req2), .addr(addr2), .v(v2), .dout(dout2),
                  .hit(hit2), .miss(miss2), .m_req(m_req2), .m_addr(m_addr2),
                  .m_done(m_done2), .m_dout(m_dout2));
    cache_nru c3(.clk(clk), .reset(reset), .req(req3), .addr(addr3), .v(v3), .dout(dout3),
                 .hit(hit3), .miss(miss3), .m_req(m_req3), .m_addr(m_addr3),
                 .m_done(m_done3), .m_dout(m_dout3));
    cache_rand c4(.clk(clk), .reset(reset), .req(req4), .addr(addr4), .v(v4), .dout(dout4),
                  .hit(hit4), .miss(miss4), .m_req(m_req4), .m_addr(m_addr4),
                  .m_done(m_done4), .m_dout(m_dout4));

    initial forever #5 clk = ~clk;

    integer n1, n2, n3, n4, f1, f2, f3, f4, k, errors;
    integer nhit1, nmiss1, nhit2, nmiss2, nhit3, nmiss3, nhit4, nmiss4;
    integer cyc1, cyc2, cyc3, cyc4;
    integer cm1 [1:11];
    integer cm2 [1:11];
    integer cm3 [1:11];
    integer cm4 [1:11];

    //conflict workload: A B C D A E A C F A C, all mapping to set 1
    reg [5:0] WL [1:11];
    integer DAT [1:11];
    integer CM1 [1:11];
    integer CM2 [1:11];
    integer CM3 [1:11];
    integer CM4 [1:11];

    initial begin
        $dumpfile("cache_pol_cmp_tb.vcd");
        $dumpvars(0, cache_pol_cmp_tb);

        clk = 0;
        reset = 1;
        req1 = 0;
        req2 = 0;
        req3 = 0;
        req4 = 0;
        errors = 0;

        WL[1]=5;  DAT[1]=105; CM1[1]=6;  CM2[1]=6;  CM3[1]=6;  CM4[1]=6;
        WL[2]=9;  DAT[2]=109; CM1[2]=12; CM2[2]=12; CM3[2]=12; CM4[2]=12;
        WL[3]=13; DAT[3]=113; CM1[3]=18; CM2[3]=18; CM3[3]=18; CM4[3]=18;
        WL[4]=17; DAT[4]=117; CM1[4]=24; CM2[4]=24; CM3[4]=24; CM4[4]=24;
        WL[5]=5;  DAT[5]=105; CM1[5]=25; CM2[5]=25; CM3[5]=25; CM4[5]=25;
        WL[6]=21; DAT[6]=121; CM1[6]=31; CM2[6]=31; CM3[6]=31; CM4[6]=31;
        WL[7]=5;  DAT[7]=105; CM1[7]=32; CM2[7]=37; CM3[7]=37; CM4[7]=32;
        WL[8]=13; DAT[8]=113; CM1[8]=33; CM2[8]=38; CM3[8]=38; CM4[8]=38;
        WL[9]=25; DAT[9]=125; CM1[9]=39; CM2[9]=44; CM3[9]=44; CM4[9]=44;
        WL[10]=5; DAT[10]=105; CM1[10]=40; CM2[10]=45; CM3[10]=45; CM4[10]=50;
        WL[11]=13; DAT[11]=113; CM1[11]=41; CM2[11]=51; CM3[11]=46; CM4[11]=56;

        repeat (2) @(posedge clk);
        reset <= 0;

        nhit1 = 0; nmiss1 = 0;
        nhit2 = 0; nmiss2 = 0;
        nhit3 = 0; nmiss3 = 0;
        nhit4 = 0; nmiss4 = 0;
        cyc1 = 0; cyc2 = 0; cyc3 = 0; cyc4 = 0;

        for (k = 1; k <= 11; k = k + 1) begin
            fork
                begin
                    req1 <= 1;
                    addr1 <= WL[k];
                    n1 = 0;
                    f1 = 0;
                    while (!f1 && n1 < 20) begin
                        @(posedge clk); #1;
                        n1 = n1 + 1;
                        if (n1 == 1) req1 <= 0;
                        //access 1 is a miss (addr=5); perturb addr mid-FETCH with a
                        //different-set address (10) to prove refill uses ra, not addr
                        if (k == 1 && n1 >= 2 && n1 <= 4) addr1 <= 10;
                        nhit1 = nhit1 + (c1.hit === 1);
                        nmiss1 = nmiss1 + (c1.miss === 1);
                        if (v1 === 1) f1 = 1;
                    end
                    cyc1 = cyc1 + n1;
                    cm1[k] = cyc1;
                    if (dout1 !== DAT[k]) begin
                        errors = errors + 1;
                        $display("FAIL: lru access %0d data=%0d expected %0d", k, dout1, DAT[k]);
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
                        //access 1 is a miss (addr=5); perturb addr mid-FETCH with a
                        //different-set address (10) to prove refill uses ra, not addr
                        if (k == 1 && n2 >= 2 && n2 <= 4) addr2 <= 10;
                        nhit2 = nhit2 + (c2.hit === 1);
                        nmiss2 = nmiss2 + (c2.miss === 1);
                        if (v2 === 1) f2 = 1;
                    end
                    cyc2 = cyc2 + n2;
                    cm2[k] = cyc2;
                    if (dout2 !== DAT[k]) begin
                        errors = errors + 1;
                        $display("FAIL: fifo access %0d data=%0d expected %0d", k, dout2, DAT[k]);
                    end
                end
                begin
                    req3 <= 1;
                    addr3 <= WL[k];
                    n3 = 0;
                    f3 = 0;
                    while (!f3 && n3 < 20) begin
                        @(posedge clk); #1;
                        n3 = n3 + 1;
                        if (n3 == 1) req3 <= 0;
                        //access 1 is a miss (addr=5); perturb addr mid-FETCH with a
                        //different-set address (10) to prove refill uses ra, not addr
                        if (k == 1 && n3 >= 2 && n3 <= 4) addr3 <= 10;
                        nhit3 = nhit3 + (c3.hit === 1);
                        nmiss3 = nmiss3 + (c3.miss === 1);
                        if (v3 === 1) f3 = 1;
                    end
                    cyc3 = cyc3 + n3;
                    cm3[k] = cyc3;
                    if (dout3 !== DAT[k]) begin
                        errors = errors + 1;
                        $display("FAIL: nru access %0d data=%0d expected %0d", k, dout3, DAT[k]);
                    end
                end
                begin
                    req4 <= 1;
                    addr4 <= WL[k];
                    n4 = 0;
                    f4 = 0;
                    while (!f4 && n4 < 20) begin
                        @(posedge clk); #1;
                        n4 = n4 + 1;
                        if (n4 == 1) req4 <= 0;
                        //access 1 is a miss (addr=5); perturb addr mid-FETCH with a
                        //different-set address (10) to prove refill uses ra, not addr
                        if (k == 1 && n4 >= 2 && n4 <= 4) addr4 <= 10;
                        nhit4 = nhit4 + (c4.hit === 1);
                        nmiss4 = nmiss4 + (c4.miss === 1);
                        if (v4 === 1) f4 = 1;
                    end
                    cyc4 = cyc4 + n4;
                    cm4[k] = cyc4;
                    if (dout4 !== DAT[k]) begin
                        errors = errors + 1;
                        $display("FAIL: rand access %0d data=%0d expected %0d", k, dout4, DAT[k]);
                    end
                end
            join
        end

        for (k = 1; k <= 11; k = k + 1) begin
            if (cm1[k] != CM1[k]) begin
                errors = errors + 1;
                $display("FAIL: lru completion cycle %0d=%0d expected %0d", k, cm1[k], CM1[k]);
            end
            if (cm2[k] != CM2[k]) begin
                errors = errors + 1;
                $display("FAIL: fifo completion cycle %0d=%0d expected %0d", k, cm2[k], CM2[k]);
            end
            if (cm3[k] != CM3[k]) begin
                errors = errors + 1;
                $display("FAIL: nru completion cycle %0d=%0d expected %0d", k, cm3[k], CM3[k]);
            end
            if (cm4[k] != CM4[k]) begin
                errors = errors + 1;
                $display("FAIL: rand completion cycle %0d=%0d expected %0d", k, cm4[k], CM4[k]);
            end
        end

        if (nhit1 != 5) begin
            errors = errors + 1;
            $display("FAIL: lru nhit=%0d expected 5", nhit1);
        end
        if (nmiss1 != 6) begin
            errors = errors + 1;
            $display("FAIL: lru nmiss=%0d expected 6", nmiss1);
        end
        if (nhit2 != 3) begin
            errors = errors + 1;
            $display("FAIL: fifo nhit=%0d expected 3", nhit2);
        end
        if (nmiss2 != 8) begin
            errors = errors + 1;
            $display("FAIL: fifo nmiss=%0d expected 8", nmiss2);
        end
        if (nhit3 != 4) begin
            errors = errors + 1;
            $display("FAIL: nru nhit=%0d expected 4", nhit3);
        end
        if (nmiss3 != 7) begin
            errors = errors + 1;
            $display("FAIL: nru nmiss=%0d expected 7", nmiss3);
        end
        if (nhit4 != 2) begin
            errors = errors + 1;
            $display("FAIL: rand nhit=%0d expected 2", nhit4);
        end
        if (nmiss4 != 9) begin
            errors = errors + 1;
            $display("FAIL: rand nmiss=%0d expected 9", nmiss4);
        end

        if (c1.tag0[1] !== 1 || c1.tag1[1] !== 5 || c1.tag2[1] !== 3 || c1.tag3[1] !== 6) begin
            errors = errors + 1;
            $display("FAIL: lru final tags=%0d,%0d,%0d,%0d expected 1,5,3,6",
                      c1.tag0[1], c1.tag1[1], c1.tag2[1], c1.tag3[1]);
        end
        if (c1.age[1] !== 8'h8D) begin
            errors = errors + 1;
            $display("FAIL: lru final age=%h expected 8D", c1.age[1]);
        end

        if (c2.tag0[1] !== 5 || c2.tag1[1] !== 1 || c2.tag2[1] !== 6 || c2.tag3[1] !== 3) begin
            errors = errors + 1;
            $display("FAIL: fifo final tags=%0d,%0d,%0d,%0d expected 5,1,6,3",
                      c2.tag0[1], c2.tag1[1], c2.tag2[1], c2.tag3[1]);
        end
        if (c2.ptr[1] !== 0) begin
            errors = errors + 1;
            $display("FAIL: fifo final ptr=%0d expected 0", c2.ptr[1]);
        end

        if (c3.tag0[1] !== 5 || c3.tag1[1] !== 1 || c3.tag2[1] !== 3 || c3.tag3[1] !== 6) begin
            errors = errors + 1;
            $display("FAIL: nru final tags=%0d,%0d,%0d,%0d expected 5,1,3,6",
                      c3.tag0[1], c3.tag1[1], c3.tag2[1], c3.tag3[1]);
        end
        if (c3.rb[1] !== 4'hf) begin
            errors = errors + 1;
            $display("FAIL: nru final rb=%b expected 1111", c3.rb[1]);
        end

        if (c4.tag0[1] !== 6 || c4.tag1[1] !== 1 || c4.tag2[1] !== 3 || c4.tag3[1] !== 4) begin
            errors = errors + 1;
            $display("FAIL: rand final tags=%0d,%0d,%0d,%0d expected 6,1,3,4",
                      c4.tag0[1], c4.tag1[1], c4.tag2[1], c4.tag3[1]);
        end
        if (c4.lfsr !== 4'b0100) begin
            errors = errors + 1;
            $display("FAIL: rand final lfsr=%b expected 0100", c4.lfsr);
        end

        $display("conflict: lru=%0d (%0d miss %0d hit) fifo=%0d (%0d miss %0d hit) nru=%0d (%0d miss %0d hit) rand=%0d (%0d miss %0d hit)",
                  cm1[11], nmiss1, nhit1, cm2[11], nmiss2, nhit2, cm3[11], nmiss3, nhit3, cm4[11], nmiss4, nhit4);

        if (errors != 0)
            $display("FAIL (%0d errors)", errors);

        $finish;
    end
endmodule
