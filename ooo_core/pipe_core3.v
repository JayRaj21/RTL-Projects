`timescale 1ns/1ps

module pipe_core3(clk, reset, c_v, c_rd, c_val, c_pc);
    //3-stage in-order core (fd/ex/wb), single wb slot, no rob - checks
    //whether ooo's win over the serial core comes from reordering or just
    //from pipelining
    parameter PROG_LEN = 5;
    input clk, reset;
    output c_v;
    output [2:0] c_rd;
    output [7:0] c_val;
    output [3:0] c_pc;

    //fd
    reg [3:0] pc;

    wire [15:0] instr;
    imem3 imem0(.addr(pc[2:0]), .instr(instr));

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

    //ex pipeline regs
    reg ex_v;
    reg [7:0] ex_a, ex_b;
    reg [2:0] ex_rs1, ex_rs2, ex_rd;
    reg [3:0] ex_pc;
    reg ex_ui, ex_sub, ex_mul;

    //wb pipeline regs - fu only carries a 2-bit tag, not rd/pc, so track them here
    reg wb_v;
    reg [2:0] wb_rd;
    reg [3:0] wb_pc;
    reg wb_mul;

    wire add_v, mul_v;
    wire [7:0] add_val, mul_val;

    assign c_v   = wb_v && (wb_mul ? mul_v : add_v);
    assign c_rd  = wb_rd;
    assign c_pc  = wb_pc;
    assign c_val = wb_mul ? mul_val : add_val;

    wire stall = ex_v && wb_v && !c_v;
    wire go    = ex_v && !stall;

    //fd bypass: producer two ahead, committing while this instr is in fd
    wire byp_a = c_v && c_rd != 0 && c_rd == rs1;
    wire byp_b = c_v && c_rd != 0 && c_rd == rs2;
    wire [7:0] fd_a = byp_a ? c_val : rd1;
    wire [7:0] fd_b = use_imm ? {4'b0, imm} : byp_b ? c_val : rd2;

    //ex forward: producer one ahead, committing the cycle this instr starts
    wire fwd_a = c_v && c_rd != 0 && c_rd == ex_rs1;
    wire fwd_b = !ex_ui && c_v && c_rd != 0 && c_rd == ex_rs2;
    wire [7:0] fa = fwd_a ? c_val : ex_a;
    wire [7:0] fb = fwd_b ? c_val : ex_b;

    add_fu add0(.clk(clk), .reset(reset), .start(go & !ex_mul), .sub(ex_sub),
                .a(fa), .b(fb), .tag(2'd0),
                .grant(c_v & !wb_mul),
                .v(add_v), .tag_o(), .val(add_val), .free());

    mul_fu mul0(.clk(clk), .reset(reset), .start(go & ex_mul),
                .a(fa), .b(fb), .tag(2'd0),
                .grant(c_v & wb_mul),
                .v(mul_v), .tag_o(), .val(mul_val), .free());

    always @(posedge clk) begin
        if (reset)
            pc <= 4'd0;
        else if (!stall && pc < PROG_LEN)
            pc <= pc + 4'd1;
    end

    always @(posedge clk) begin
        if (reset) begin
            ex_v <= 1'b0;
        end else if (!stall) begin
            ex_v   <= (pc < PROG_LEN);
            ex_a   <= fd_a;
            ex_b   <= fd_b;
            ex_rs1 <= rs1;
            ex_rs2 <= rs2;
            ex_ui  <= use_imm;
            ex_rd  <= dest;
            ex_pc  <= pc;
            ex_sub <= fop[0];
            ex_mul <= is_mul;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            wb_v <= 1'b0;
        end else if (go) begin
            wb_v   <= 1'b1;
            wb_rd  <= ex_rd;
            wb_pc  <= ex_pc;
            wb_mul <= ex_mul;
        end else if (c_v) begin
            wb_v <= 1'b0;
        end
    end

endmodule
