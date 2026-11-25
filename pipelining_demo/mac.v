// MAC = Multiply-ACcumulate: out = (a * b) + c.
// A common building block in DSP/GPU/neural-net hardware (convolutions,
// dot products, and FIR filters are all chains of MAC operations), and
// a good small example for contrasting unpipelined vs. pipelined design.

module mac_unpipelined(out, a, b, c);
    parameter WIDTH = 8;
    output [2*WIDTH-1:0] out;
    input [WIDTH-1:0] a, b, c;

    //both the multiply and the add happen in a single combinational path
    assign out = (a * b) + c;
endmodule


module mac_pipelined(out, clk, a, b, c);
    parameter WIDTH = 8;
    output reg [2*WIDTH-1:0] out;
    input clk;
    input [WIDTH-1:0] a, b, c;

    reg [2*WIDTH-1:0] product;
    reg [WIDTH-1:0] c_delayed; //c delayed one cycle to stay aligned with product

    always @(posedge clk) begin
        //stage 1: multiply only
        product <= a * b;
        c_delayed <= c;
    end

    always @(posedge clk) begin
        //stage 2: add only
        out <= product + c_delayed;
    end
endmodule
