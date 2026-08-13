module simple_calculator(out, cout, a, b, op, cin, dir);
    output reg [7:0] out;
    output reg cout;
    input [3:0] a, b, op;
    input cin;
    input dir;

    wire [3:0] add_out, sub_out, shift_out;
    wire [7:0] mult_out;
    wire add_cout, sub_cout;

    add_4 u_add(.sum(add_out), .cout(add_cout), .a(a), .b(b), .cin(cin));
    subtract_4 u_sub(.out(sub_out), .cout(sub_cout), .a(a), .b(b));
    mult u_mult(.out(mult_out), .a(a), .b(b));
    shift u_shift(.out(shift_out), .in(a), .dir(dir));

    always @(*) begin
      case (op)
        4'b0001: begin out = {4'b0, add_out};   cout = add_cout; end //add
        4'b0010: begin out = {4'b0, sub_out};   cout = sub_cout; end //subtract
        4'b0100: begin out = mult_out;          cout = 1'b0;     end //mult
        4'b1000: begin out = {4'b0, shift_out}; cout = 1'b0;     end //shift
        default: begin out = 8'b0;              cout = 1'b0;     end
      endcase
    end

endmodule

module half_add(sum, c, a, b);
    output sum, c;
    input a, b;

    assign sum = a ^ b;
    assign c = a & b;
endmodule

module add(sum, cout, a, b, cin);
    output sum, cout;
    input a, b, cin;
    wire x, y, z;

    half_add h1(.sum(x), .c(y), .a(a), .b(b));
    half_add h2(.sum(sum), .c(z), .a(x), .b(cin));
    or o1(cout, y, z);
endmodule

module add_4(sum, cout, a, b, cin);
    output [3:0] sum;
    output cout;
    input [3:0] a, b;
    input cin;

    wire c1, c2, c3;

    add a1(.sum(sum[0]), .cout(c1), .a(a[0]), .b(b[0]), .cin(cin));
    add a2(.sum(sum[1]), .cout(c2), .a(a[1]), .b(b[1]), .cin(c1));
    add a3(.sum(sum[2]), .cout(c3), .a(a[2]), .b(b[2]), .cin(c2));
    add a4(.sum(sum[3]), .cout(cout), .a(a[3]), .b(b[3]), .cin(c3));
endmodule


module subtract_4(out, cout, a, b); //uses two-complement
    output [3:0] out;
    output cout;
    input [3:0] a, b;

    add_4 s1(.sum(out), .cout(cout), .a(a), .b(~b), .cin(1'b1));
endmodule


module mult(out, a, b);
    output [7:0] out;
    input [3:0] a, b;

    assign out = a * b;

endmodule

module shift(out, in, dir);
    output reg [3:0] out;
    input [3:0] in;
    input dir; //0 is shift left, 1 is shift right

    always @(*) begin
        if (dir)
            out = in >> 1;
        else
            out = in << 1;
    end
endmodule
