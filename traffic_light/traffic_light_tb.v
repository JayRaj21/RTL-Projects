`timescale 1ns/1ps

module traffic_light_tb;
    reg clk, reset;
    wire [1:0] light_moore, light_mealy;

    traffic_light_moore dut_moore(.light(light_moore), .clk(clk), .reset(reset));
    traffic_light_mealy dut_mealy(.light(light_mealy), .clk(clk), .reset(reset));

    initial forever #5 clk = ~clk;

    initial begin
        $dumpfile("traffic_light_tb.vcd");
        $dumpvars(0, traffic_light_tb);

        clk = 0;
        reset = 1;

        @(negedge clk);
        reset = 0;

        // watch both run through a few full red/green/yellow cycles
        repeat (30) begin
            @(posedge clk);
            $display("t=%6t     moore=%b mealy=%b", $time, light_moore, light_mealy);
        end

        $finish;
    end
endmodule
