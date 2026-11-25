module calculator_unpipelined(y, a, b, c, d);
    output [2:0] y;
    input a, b, c, d;

    //both adds and the multiply happen in one combinational path
    assign y = (a + b) * (c + d);
endmodule


module calculator_pipelined(y, clk, a, b, c, d);
    output reg [2:0] y;
    input clk;
    input a, b, c, d;

    reg [1:0] sum_ab, sum_cd;

    //stage 1: compute both partial sums
    always @(posedge clk) begin
        sum_ab <= a + b;
        sum_cd <= c + d;
    end

    //stage 2: multiply the partial sums
    always @(posedge clk) begin
        y <= sum_ab * sum_cd;
    end
endmodule
