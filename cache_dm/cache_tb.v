`timescale 1ns/1ps

module cache_tb;
    reg clk, reset, req;
    reg [5:0] addr;
    wire v, hit, miss, m_req, m_done;
    wire [5:0] m_addr;
    wire [7:0] dout, m_dout;

    backing_mem m(.clk(clk), .reset(reset), .req(m_req), .addr(m_addr),
                   .busy(), .done(m_done), .dout(m_dout));

    cache c(.clk(clk), .reset(reset), .req(req), .addr(addr), .v(v), .dout(dout),
            .hit(hit), .miss(miss), .m_req(m_req), .m_addr(m_addr),
            .m_done(m_done), .m_dout(m_dout));

    initial forever #5 clk = ~clk;

    integer i, n;
    integer nhit, nmiss, nmem, errors, f;
    integer hit0, miss0;

    //A=5 (tag1 idx1), B=10 (tag2 idx2), E=21 (tag5 idx1, conflicts with A)
    reg [5:0] ADDR [1:8];
    reg ISHIT [1:8];
    integer CYC [1:8];
    integer DAT [1:8];

    initial begin
        $dumpfile("cache_tb.vcd");
        $dumpvars(0, cache_tb);

        clk = 0;
        reset = 1;
        req = 0;
        errors = 0;
        nhit = 0;
        nmiss = 0;
        nmem = 0;

        ADDR[1] = 5;  ISHIT[1] = 0; CYC[1] = 6; DAT[1] = 105;
        ADDR[2] = 5;  ISHIT[2] = 1; CYC[2] = 1; DAT[2] = 105;
        ADDR[3] = 10; ISHIT[3] = 0; CYC[3] = 6; DAT[3] = 110;
        ADDR[4] = 5;  ISHIT[4] = 1; CYC[4] = 1; DAT[4] = 105;
        ADDR[5] = 21; ISHIT[5] = 0; CYC[5] = 6; DAT[5] = 121;
        ADDR[6] = 21; ISHIT[6] = 1; CYC[6] = 1; DAT[6] = 121;
        ADDR[7] = 5;  ISHIT[7] = 0; CYC[7] = 6; DAT[7] = 105;
        ADDR[8] = 10; ISHIT[8] = 1; CYC[8] = 1; DAT[8] = 110;

        repeat (2) @(posedge clk);
        reset <= 0;

        for (i = 1; i <= 8; i = i + 1) begin
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
                nhit = nhit + (c.hit === 1);
                nmiss = nmiss + (c.miss === 1);
                nmem = nmem + (c.m_req === 1);
                if (v === 1) f = 1;
            end

            if (n >= 20) begin
                errors = errors + 1;
                $display("FAIL: access %0d never completed", i);
            end

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

            if (i == 5 && c.tag[1] !== 5) begin
                errors = errors + 1;
                $display("FAIL: tag[1]=%0d expected 5 after access 5", c.tag[1]);
            end
            if (i == 7 && c.tag[1] !== 1) begin
                errors = errors + 1;
                $display("FAIL: tag[1]=%0d expected 1 after access 7", c.tag[1]);
            end
        end

        if (c.vld !== 4'b0110) begin
            errors = errors + 1;
            $display("FAIL: vld=%b expected 0110", c.vld);
        end

        if (nhit != 4) begin
            errors = errors + 1;
            $display("FAIL: nhit=%0d expected 4", nhit);
        end
        if (nmiss != 4) begin
            errors = errors + 1;
            $display("FAIL: nmiss=%0d expected 4", nmiss);
        end
        if (nmem != 4) begin
            errors = errors + 1;
            $display("FAIL: nmem=%0d expected 4", nmem);
        end

        $display("hits=%0d misses=%0d cycles=%0d", nhit, nmiss,
                  CYC[1]+CYC[2]+CYC[3]+CYC[4]+CYC[5]+CYC[6]+CYC[7]+CYC[8]);

        if (errors != 0)
            $display("FAIL (%0d errors)", errors);

        $finish;
    end
endmodule
