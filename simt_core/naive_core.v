`timescale 1ns/1ps

module naive_core(clk, reset, busy, done);
    //one shared alu visits each lane in turn, same workload as simt_core
    parameter LANES = 4;
    input clk, reset;
    output busy;
    output done;

    reg [7:0] data [0:LANES-1];
    reg [7:0] result [0:LANES-1];
    reg pred [0:LANES-1];
    reg [1:0] phase; //0=pred, 1=then, 2=else, 3=done
    reg [2:0] idx;   //current lane

    initial begin
        data[0] = 8'd3;
        data[1] = 8'd7;
        data[2] = 8'd2;
        data[3] = 8'd9;
    end

    assign busy = (phase != 2'd3);
    assign done = (phase == 2'd3);

    always @(posedge clk) begin
        if (reset) begin
            phase <= 2'd0;
            idx   <= 3'd0;
        end else if (phase != 2'd3) begin
            case (phase)
                2'd0: pred[idx] <= (data[idx] > 8'd5);
                2'd1: if (pred[idx])  result[idx] <= data[idx] * 2;
                2'd2: if (!pred[idx]) result[idx] <= data[idx] + 1;
                default: ;
            endcase

            if (idx == LANES - 1) begin
                idx   <= 3'd0;
                phase <= phase + 2'd1;
            end else begin
                idx <= idx + 3'd1;
            end
        end
    end
endmodule
