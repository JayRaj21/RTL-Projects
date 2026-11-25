`timescale 1ns/1ps

module cache_sa(clk, reset, req, addr, v, dout, hit, miss, m_req, m_addr, m_done, m_dout);
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

    reg [SETS-1:0] vld0, vld1;
    reg [TW-1:0] tag0 [0:SETS-1];
    reg [TW-1:0] tag1 [0:SETS-1];
    reg [DATA_WIDTH-1:0] data0 [0:SETS-1];
    reg [DATA_WIDTH-1:0] data1 [0:SETS-1];
    reg [SETS-1:0] lru;
    reg [ADDR_WIDTH-1:0] ra;
    reg st;

    wire [SW-1:0] idx = addr[SW-1:0];
    wire [TW-1:0] tg = addr[ADDR_WIDTH-1:SW];
    wire h0 = vld0[idx] && tag0[idx] == tg;
    wire h1 = vld1[idx] && tag1[idx] == tg;
    wire hc = h0 || h1;

    wire [SW-1:0] rs = ra[SW-1:0];
    wire vw = !vld0[rs] ? 1'b0 : !vld1[rs] ? 1'b1 : lru[rs];

    assign m_addr = ra;

    always @(posedge clk) begin
        if (reset) begin
            vld0 <= 0;
            vld1 <= 0;
            lru <= 0;
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
                dout <= h0 ? data0[idx] : data1[idx];
                lru[idx] <= h0; //hitting way0 makes way1 LRU, and vice versa
            end
            else if (st == IDLE && req && !hc) begin
                miss <= 1;
                ra <= addr;
                m_req <= 1;
                st <= FETCH;
            end
            else if (st == FETCH && m_done) begin
                //victim chosen here, safe since no state changes while in FETCH
                if (vw) begin
                    data1[rs] <= m_dout;
                    tag1[rs] <= ra[ADDR_WIDTH-1:SW];
                    vld1[rs] <= 1;
                end
                else begin
                    data0[rs] <= m_dout;
                    tag0[rs] <= ra[ADDR_WIDTH-1:SW];
                    vld0[rs] <= 1;
                end
                lru[rs] <= !vw;
                dout <= m_dout;
                v <= 1;
                st <= IDLE;
            end
        end
    end
endmodule
