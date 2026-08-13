`timescale 1ns/1ps

module simple_calc_tb;
    reg [3:0] a, b, op;
    reg cin, dir;
    wire [7:0] out;
    wire cout;

    simple_calculator dut(.out(out), .cout(cout), .a(a), .b(b), .op(op), .cin(cin), .dir(dir));

    initial begin
        $dumpfile("simple_calc_tb.vcd");
        $dumpvars(0, simple_calc_tb);

        cin = 0;
        dir = 0;

        // add: 3 + 4 = 7
        a = 4'd3; b = 4'd4; op = 4'b0001;
        #10 $display("add:   %0d + %0d = %0d (cout=%0d)", a, b, out, cout);

        // add with carry out: 15 + 1 = 16
        a = 4'd15; b = 4'd1; op = 4'b0001;
        #10 $display("add:   %0d + %0d = %0d (cout=%0d)", a, b, out, cout);

        // subtract: 9 - 3 = 6
        a = 4'd9; b = 4'd3; op = 4'b0010;
        #10 $display("sub:   %0d - %0d = %0d (cout=%0d)", a, b, out, cout);

        // subtract with borrow: 3 - 9 (wraps via two's complement)
        a = 4'd3; b = 4'd9; op = 4'b0010;
        #10 $display("sub:   %0d - %0d = %0d (cout=%0d)", a, b, out, cout);

        // mult: 5 * 3 = 15
        a = 4'd5; b = 4'd3; op = 4'b0100;
        #10 $display("mult:  %0d * %0d = %0d", a, b, out);

        // mult: 3 * 3 = 9
        a = 4'd3; b = 4'd3; op = 4'b0100;
        #10 $display("mult:  %0d * %0d = %0d", a, b, out);

        // shift left: 3 << 1 = 6
        a = 4'd3; dir = 0; op = 4'b1000;
        #10 $display("shift: %0d << 1 = %0d", a, out);

        // shift right: 8 >> 1 = 4
        a = 4'd8; dir = 1; op = 4'b1000;
        #10 $display("shift: %0d >> 1 = %0d", a, out);

        $finish;
    end
endmodule
