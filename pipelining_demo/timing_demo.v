`timescale 1ns/1ps

// Demonstrates the REAL reason pipelining helps: it does not increase
// results-per-cycle (both designs below produce one result per clock
// in steady state) - it shortens the critical path per stage, which is
// what lets you run the clock faster in the first place.
//
// Icarus Verilog's plain `assign`/`always` logic has zero propagation
// delay by default, so without annotated delays there is nothing for a
// clock period to strain against. The #delay values below stand in for
// realistic gate delay, purely so this can be demonstrated in simulation.

module mac_unpipelined_timed(out, clk, a, b, c);
    parameter WIDTH = 8;
    parameter CRIT_DELAY = 8; //models the full multiply+add critical path (ns)
    output reg [2*WIDTH-1:0] out;
    input clk;
    input [WIDTH-1:0] a, b, c;

    wire [2*WIDTH-1:0] result_comb;
    assign #CRIT_DELAY result_comb = (a * b) + c;

    always @(posedge clk)
        out <= result_comb;
endmodule


module mac_pipelined_timed(out, clk, a, b, c);
    parameter WIDTH = 8;
    parameter STAGE_DELAY = 4; //each stage is roughly half the combined critical path (ns)
    output reg [2*WIDTH-1:0] out;
    input clk;
    input [WIDTH-1:0] a, b, c;

    wire [2*WIDTH-1:0] product_comb;
    assign #STAGE_DELAY product_comb = a * b;

    reg [2*WIDTH-1:0] product;
    reg [WIDTH-1:0] c_d1;

    always @(posedge clk) begin
        product <= product_comb;
        c_d1    <= c;
    end

    wire [2*WIDTH-1:0] sum_comb;
    assign #STAGE_DELAY sum_comb = product + c_d1;

    always @(posedge clk)
        out <= sum_comb;
endmodule
