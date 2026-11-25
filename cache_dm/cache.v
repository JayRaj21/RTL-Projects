`timescale 1ns/1ps

module backing_mem(clk, reset, req, addr, busy, done, dout);
    parameter ADDR_WIDTH = 6;
    parameter DATA_WIDTH = 8;
    parameter LATENCY = 4;

    input clk, reset, req;
    input [ADDR_WIDTH-1:0] addr;
    output busy, done;
    output [DATA_WIDTH-1:0] dout;

    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];
    reg [ADDR_WIDTH-1:0] ra;
    reg [3:0] cnt; //supports LATENCY up to 16
    reg busy;

    integer i;
    initial begin
        for (i = 0; i < (1<<ADDR_WIDTH); i = i + 1)
            mem[i] = 8'd100 + i;
    end

    assign done = busy && cnt == 0;
    assign dout = mem[ra];

    always @(posedge clk) begin
        if (reset) busy <= 0;
        else if (req && (!busy || done)) begin
            ra <= addr;
            busy <= 1;
            cnt <= LATENCY - 1;
        end
        else if (busy && cnt != 0) cnt <= cnt - 1;
        else if (busy) busy <= 0;
    end
endmodule


module cache(clk, reset, req, addr, v, dout, hit, miss, m_req, m_addr, m_done, m_dout);
    parameter ADDR_WIDTH = 6;
    parameter DATA_WIDTH = 8;
    parameter LINES = 4;
    parameter IW = $clog2(LINES);
    parameter TW = ADDR_WIDTH - IW;

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

    reg [LINES-1:0] vld;
    reg [TW-1:0] tag [0:LINES-1];
    reg [DATA_WIDTH-1:0] data [0:LINES-1];
    reg [ADDR_WIDTH-1:0] ra;
    reg st;

    wire [IW-1:0] idx = addr[IW-1:0];
    wire [TW-1:0] tg = addr[ADDR_WIDTH-1:IW];
    wire hc = vld[idx] && tag[idx] == tg;

    assign m_addr = ra;

    always @(posedge clk) begin
        if (reset) begin
            vld <= 0;
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
                dout <= data[idx];
            end
            else if (st == IDLE && req && !hc) begin
                miss <= 1;
                ra <= addr;
                m_req <= 1;
                st <= FETCH;
            end
            else if (st == FETCH && m_done) begin
                data[ra[IW-1:0]] <= m_dout;
                tag[ra[IW-1:0]] <= ra[ADDR_WIDTH-1:IW];
                vld[ra[IW-1:0]] <= 1;
                dout <= m_dout;
                v <= 1;
                st <= IDLE;
            end
        end
    end
endmodule
