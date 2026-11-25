`timescale 1ns/1ps

module cache_nru(clk, reset, req, addr, v, dout, hit, miss, m_req, m_addr, m_done, m_dout);
    parameter ADDR_WIDTH = 6;
    parameter DATA_WIDTH = 8;
    parameter SETS = 4;
    parameter SW = $clog2(SETS);
    parameter TW = ADDR_WIDTH - SW;

    parameter IDLE = 1'b0;
    parameter FETCH = 1'b1;

    input clk, reset, req;
    input [ADDR_WIDTH-1:0] addr;
    output reg v, hit, miss;
    output reg [DATA_WIDTH-1:0] dout;
    output reg m_req;
    output [ADDR_WIDTH-1:0] m_addr;
    input m_done;
    input [DATA_WIDTH-1:0] m_dout;

    reg [SETS-1:0] vld0, vld1, vld2, vld3;
    reg [TW-1:0] tag0 [0:SETS-1];
    reg [TW-1:0] tag1 [0:SETS-1];
    reg [TW-1:0] tag2 [0:SETS-1];
    reg [TW-1:0] tag3 [0:SETS-1];
    reg [DATA_WIDTH-1:0] data0 [0:SETS-1];
    reg [DATA_WIDTH-1:0] data1 [0:SETS-1];
    reg [DATA_WIDTH-1:0] data2 [0:SETS-1];
    reg [DATA_WIDTH-1:0] data3 [0:SETS-1];
    reg [3:0] rb [0:SETS-1]; //bit w = R bit of way w
    reg [ADDR_WIDTH-1:0] ra;
    reg st;

    integer j;

    wire [SW-1:0] idx = addr[SW-1:0];
    wire [TW-1:0] tg = addr[ADDR_WIDTH-1:SW];
    wire h0 = vld0[idx] && tag0[idx] == tg;
    wire h1 = vld1[idx] && tag1[idx] == tg;
    wire h2 = vld2[idx] && tag2[idx] == tg;
    wire h3 = vld3[idx] && tag3[idx] == tg;
    wire hc = h0 | h1 | h2 | h3;
    wire [1:0] hw = h0 ? 2'd0 : h1 ? 2'd1 : h2 ? 2'd2 : 2'd3;

    wire [SW-1:0] rs = ra[SW-1:0];
    wire full = vld0[rs] & vld1[rs] & vld2[rs] & vld3[rs];
    wire [1:0] iw = !vld0[rs] ? 2'd0 : !vld1[rs] ? 2'd1 : !vld2[rs] ? 2'd2 : 2'd3;
    wire [3:0] rbr = rb[rs];
    wire [1:0] vw = !full ? iw :
                    rbr == 4'hf ? 2'd0 :
                    !rbr[0] ? 2'd0 :
                    !rbr[1] ? 2'd1 :
                    !rbr[2] ? 2'd2 : 2'd3;

    assign m_addr = ra;

    always @(posedge clk) begin
        if (reset) begin
            vld0 <= 0;
            vld1 <= 0;
            vld2 <= 0;
            vld3 <= 0;
            for (j = 0; j < SETS; j = j + 1)
                rb[j] <= 0;
            st <= IDLE;
            m_req <= 0;
            v <= 0;
            hit <= 0;
            miss <= 0;
        end
        else begin
            v <= 0;
            hit <= 0;
            miss <= 0;
            m_req <= 0;

            if (st == IDLE && req && hc) begin
                v <= 1;
                hit <= 1;
                dout <= h0 ? data0[idx] : h1 ? data1[idx] : h2 ? data2[idx] : data3[idx];
                rb[idx] <= rb[idx] | (4'b0001 << hw);
            end
            else if (st == IDLE && req && !hc) begin
                miss <= 1;
                ra <= addr;
                m_req <= 1;
                st <= FETCH;
            end
            else if (st == FETCH && m_done) begin
                case (vw)
                    2'd0: begin data0[rs] <= m_dout; tag0[rs] <= ra[ADDR_WIDTH-1:SW]; vld0[rs] <= 1; end
                    2'd1: begin data1[rs] <= m_dout; tag1[rs] <= ra[ADDR_WIDTH-1:SW]; vld1[rs] <= 1; end
                    2'd2: begin data2[rs] <= m_dout; tag2[rs] <= ra[ADDR_WIDTH-1:SW]; vld2[rs] <= 1; end
                    2'd3: begin data3[rs] <= m_dout; tag3[rs] <= ra[ADDR_WIDTH-1:SW]; vld3[rs] <= 1; end
                endcase
                rb[rs] <= ((full && rbr == 4'hf) ? 4'h0 : rbr) | (4'b0001 << vw);
                dout <= m_dout;
                v <= 1;
                st <= IDLE;
            end
        end
    end
endmodule
