`timescale 1ns/1ps

module inorder_core(clk, reset, c_v, c_rd, c_val, c_pc);
    //non-overlapping in-order core: one instruction at a time, through
    //issue/execute/wait/commit, reusing ooo_core's own fu's and regfile
    parameter PROG_LEN = 5;
    parameter S_ISS = 2'd0;
    parameter S_EX  = 2'd1;
    parameter S_WT  = 2'd2;
    parameter S_CM  = 2'd3;

    input clk, reset;
    output c_v;
    output [2:0] c_rd;
    output [7:0] c_val;
    output [2:0] c_pc;

    reg [2:0] pc;
    reg [1:0] st;

    reg [7:0] a_r, b_r, val_r;
    reg sub_r, mul_r;
    reg [2:0] rd_r;

    assign c_v   = (st == S_CM);
    assign c_rd  = rd_r;
    assign c_val = val_r;
    assign c_pc  = pc;

    wire [15:0] instr;
    imem imem0(.addr(pc), .instr(instr));

    wire [2:0] opcode = instr[15:13];
    wire [2:0] dest   = instr[12:10];
    wire [2:0] rs1    = instr[9:7];
    wire [2:0] rs2    = instr[6:4];
    wire [3:0] imm    = instr[3:0];

    wire use_imm = opcode[2];
    wire [1:0] fop = opcode[1:0];
    wire is_mul = fop[1];

    wire [7:0] rd1, rd2;

    arf rf(.clk(clk), .reset(reset), .we(c_v), .rs1(rs1), .rs2(rs2),
           .rd(c_rd), .wd(c_val), .rd1(rd1), .rd2(rd2));

    wire add_v, mul_v;
    wire [7:0] add_val, mul_val;

    add_fu add0(.clk(clk), .reset(reset), .start((st == S_EX) & !mul_r), .sub(sub_r),
                .a(a_r), .b(b_r), .tag(2'd0),
                .grant((st == S_WT) & !mul_r & add_v),
                .v(add_v), .tag_o(), .val(add_val), .free());

    mul_fu mul0(.clk(clk), .reset(reset), .start((st == S_EX) & mul_r),
                .a(a_r), .b(b_r), .tag(2'd0),
                .grant((st == S_WT) & mul_r & mul_v),
                .v(mul_v), .tag_o(), .val(mul_val), .free());

    wire fu_v   = mul_r ? mul_v   : add_v;
    wire [7:0] fu_val = mul_r ? mul_val : add_val;

    always @(posedge clk) begin
        if (reset) begin
            pc <= 3'd0;
            st <= S_ISS;
        end else begin
            case (st)
                S_ISS: begin
                    if (pc < PROG_LEN) begin
                        a_r   <= rd1;
                        b_r   <= use_imm ? {4'b0, imm} : rd2;
                        sub_r <= fop[0];
                        mul_r <= is_mul;
                        rd_r  <= dest;
                        st    <= S_EX;
                    end
                end
                S_EX: begin
                    st <= S_WT;
                end
                S_WT: begin
                    if (fu_v) begin
                        val_r <= fu_val;
                        st    <= S_CM;
                    end
                end
                S_CM: begin
                    pc <= pc + 3'd1;
                    st <= S_ISS;
                end
            endcase
        end
    end
endmodule
