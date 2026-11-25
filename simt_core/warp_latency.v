`timescale 1ns/1ps

module warp(clk, reset, issue, data_in, ready, done, result);
    //one warp: load (LOAD_LATENCY cycles, runs on its own) then compute (data*2)
    parameter LOAD_LATENCY = 2;
    input clk, reset, issue;
    input [7:0] data_in;
    output ready; //this warp has something the scheduler could issue now
    output reg done;
    output reg [7:0] result;

    reg [1:0] state; //0=need_load, 1=loading, 2=need_compute, 3=done
    reg [7:0] timer;

    assign ready = (state == 2'd0) || (state == 2'd2);

    always @(posedge clk) begin
        if (reset) begin
            state  <= 2'd0;
            timer  <= 8'd0;
            done   <= 1'b0;
            result <= 8'd0;
        end else if (state == 2'd0 && issue) begin
            state <= 2'd1;
            timer <= LOAD_LATENCY;
        end else if (state == 2'd1) begin
            if (timer <= 8'd1)
                state <= 2'd2; //latency elapsed on its own, no issue needed
            else
                timer <= timer - 8'd1;
        end else if (state == 2'd2 && issue) begin
            result <= data_in * 2;
            done   <= 1'b1;
            state  <= 2'd3;
        end
    end
endmodule


module sequential_core(clk, reset, data0, data1, result0, result1, both_done);
    //no hiding: warp1 isn't even started until warp0 is fully done
    input clk, reset;
    input [7:0] data0, data1;
    output [7:0] result0, result1;
    output both_done;

    wire ready0, ready1, done0, done1;

    wire issue0 = ready0;
    wire issue1 = ready1 && done0; //warp1 waits for warp0 entirely

    warp w0(.clk(clk), .reset(reset), .issue(issue0), .data_in(data0), .ready(ready0), .done(done0), .result(result0));
    warp w1(.clk(clk), .reset(reset), .issue(issue1), .data_in(data1), .ready(ready1), .done(done1), .result(result1));

    assign both_done = done0 && done1;
endmodule


module hiding_core(clk, reset, data0, data1, result0, result1, both_done);
    //warp0 first, warp1 fills warp0's load bubble
    input clk, reset;
    input [7:0] data0, data1;
    output [7:0] result0, result1;
    output both_done;

    wire ready0, ready1, done0, done1;

    wire issue0 = ready0;
    wire issue1 = ready1 && !ready0; //fill warp0's bubble with warp1's work

    warp w0(.clk(clk), .reset(reset), .issue(issue0), .data_in(data0), .ready(ready0), .done(done0), .result(result0));
    warp w1(.clk(clk), .reset(reset), .issue(issue1), .data_in(data1), .ready(ready1), .done(done1), .result(result1));

    assign both_done = done0 && done1;
endmodule
