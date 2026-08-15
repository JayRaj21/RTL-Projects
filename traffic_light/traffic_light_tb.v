`timescale 1ns/1ps

module traffic_light_tb;
    reg clk, reset, walk_request;
    wire [1:0] light_moore, light_mealy;

    traffic_light_moore dut_moore(.light(light_moore), .clk(clk), .reset(reset), .walk_request(walk_request));
    traffic_light_mealy dut_mealy(.light(light_mealy), .clk(clk), .reset(reset), .walk_request(walk_request));

    initial 
        forever #5 clk = ~clk;

    initial begin
        $dumpfile("traffic_light_tb.vcd");
        $dumpvars(0, traffic_light_tb);

        clk = 0;
        reset = 1;
        walk_request = 0;

        @(negedge clk);
        reset = 0;

        // let both machines reach GREEN
        repeat (5) @(posedge clk);

        // press the walk button mid-cycle, before the next clk edge
        #2 walk_request = 1;
        $display("t=%6t walk_request asserted mid-cycle: moore=%b mealy=%b", $time, light_moore, light_mealy);

        repeat (6) begin
            @(posedge clk);
            $display("t=%6t     moore=%b mealy=%b", $time, light_moore, light_mealy);
        end

        walk_request = 0;

        repeat (6) begin
            @(posedge clk);
            $display("t=%6t     moore=%b mealy=%b", $time, light_moore, light_mealy);
        end

        $finish;
    end
endmodule
