`timescale 1ns/1ps

module simt_lane(clk, reset, active, op, data_in, result, pred);
    //one lane: own data, own result, own predicate
    input clk, reset, active;
    input [1:0] op;
    input [7:0] data_in;
    output reg [7:0] result;
    output reg pred;

    always @(posedge clk) begin
        if (reset) begin
            result <= 8'd0;
            pred   <= 1'b0;
        end else if (active) begin
            case (op)
                2'd1: pred   <= (data_in > 8'd5); //compute predicate, all lanes active
                2'd2: result <= data_in * 2;       //then-path, only pred-true lanes active
                2'd3: result <= data_in + 1;       //else-path, only pred-false lanes active
                default: ; //nop
            endcase
        end
    end
endmodule


module simt_core(clk, reset, step);
    //N lanes, one shared instruction (step) issued to every lane each cycle
    parameter LANES = 4;
    input clk, reset;
    input [1:0] step;

    reg [7:0] data [0:LANES-1]; //private per-lane data, like per-thread input
    wire [7:0] result [0:LANES-1];
    wire pred [0:LANES-1];

    initial begin
        data[0] = 8'd3;
        data[1] = 8'd7;
        data[2] = 8'd2;
        data[3] = 8'd9;
    end

    genvar i;
    generate
        for (i = 0; i < LANES; i = i + 1) begin : lane
            wire active = (step == 2'd1) ? 1'b1 :
                          (step == 2'd2) ? pred[i] :
                          (step == 2'd3) ? ~pred[i] : 1'b0;

            simt_lane lane_inst(.clk(clk), .reset(reset), .active(active), .op(step),
                                 .data_in(data[i]), .result(result[i]), .pred(pred[i]));
        end
    endgenerate
endmodule
