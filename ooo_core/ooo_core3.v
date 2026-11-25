`timescale 1ns/1ps

module imem3(addr, instr);
    //instruction layout (16 bits):
    //  [15:13] opcode
    //  [12:10] rd
    //  [9:7]   rs1
    //  [6:4]   rs2
    //  [3:0]   imm
    parameter OP_ADD  = 3'b000;
    parameter OP_SUB  = 3'b001;
    parameter OP_MUL  = 3'b010;
    parameter OP_ADDI = 3'b100;
    parameter OP_SUBI = 3'b101;
    parameter OP_MULI = 3'b110;

    input [2:0] addr;
    output [15:0] instr;

    reg [15:0] program [0:7];

    initial begin
        program[0] = {OP_ADDI, 3'd1, 3'd0, 3'd0, 4'd5}; //x1 = x0 + 5
        program[1] = {OP_ADDI, 3'd2, 3'd1, 3'd0, 4'd1}; //x2 = x1 + 1
        program[2] = {OP_ADDI, 3'd3, 3'd2, 3'd0, 4'd1}; //x3 = x2 + 1
        program[3] = {OP_ADDI, 3'd4, 3'd3, 3'd0, 4'd1}; //x4 = x3 + 1
        program[4] = {OP_ADDI, 3'd5, 3'd4, 3'd0, 4'd1}; //x5 = x4 + 1
    end

    assign instr = program[addr];
endmodule


module ooo_core3(clk, reset, cdb_v, cdb_tag, cdb_val, cdb_pc, c_v, c_rd, c_val, c_pc);
    //pure dependency chain: every instruction needs the one before it, so
    //there's no ilp for ooo to exploit - this is the no-speedup control case
    parameter PROG_LEN = 5;
    input clk, reset;
    output cdb_v;
    output [1:0] cdb_tag;
    output [7:0] cdb_val;
    output [2:0] cdb_pc;
    output c_v;
    output [2:0] c_rd;
    output [7:0] c_val;
    output [2:0] c_pc;

    //fetch
    reg [2:0] pc;
    wire iss;

    always @(posedge clk) begin
        if (reset)
            pc <= 3'd0;
        else if (iss)
            pc <= pc + 3'd1;
    end

    wire [15:0] instr;
    imem3 imem0(.addr(pc), .instr(instr));

    wire [2:0] opcode = instr[15:13];
    wire [2:0] dest   = instr[12:10];
    wire [2:0] rs1    = instr[9:7];
    wire [2:0] rs2    = instr[6:4];
    wire [3:0] imm    = instr[3:0];

    wire use_imm = opcode[2];
    wire [1:0] fop = opcode[1:0];
    wire is_mul = fop[1];

    //rat: busy means the value is still in flight, tag points at the rob entry
    reg rat_busy [0:7];
    reg [1:0] rat_tag [0:7];
    integer k;

    wire [7:0] rd1, rd2;
    wire [1:0] tail, head;
    wire rob_full;
    wire rj_done, rk_done;
    wire [7:0] rj_val, rk_val;

    wire [1:0] qj = rat_tag[rs1];
    wire [1:0] qk = rat_tag[rs2];

    wire jp = rat_busy[rs1];
    wire kp = rat_busy[rs2];

    wire jcdb = cdb_v && (cdb_tag == qj);
    wire kcdb = cdb_v && (cdb_tag == qk);

    wire [7:0] vj = !jp ? rd1 : rj_done ? rj_val : jcdb ? cdb_val : 8'd0;
    wire qjv      = jp && !rj_done && !jcdb;

    wire [7:0] vk_reg = !kp ? rd2 : rk_done ? rk_val : kcdb ? cdb_val : 8'd0;
    wire qkv_reg      = kp && !rk_done && !kcdb;

    wire [7:0] vk = use_imm ? {4'b0, imm} : vk_reg;
    wire qkv      = use_imm ? 1'b0 : qkv_reg;

    wire add_full, mul_full;
    assign iss = (pc < PROG_LEN) && !rob_full && !(is_mul ? mul_full : add_full);

    //rat update: clear the busy bit on commit, only if nothing newer remapped it
    always @(posedge clk) begin
        if (reset) begin
            for (k = 0; k < 8; k = k + 1)
                rat_busy[k] <= 1'b0;
        end else begin
            if (c_v) begin
                if (rat_busy[c_rd] && rat_tag[c_rd] == head && !(iss && dest == c_rd))
                    rat_busy[c_rd] <= 1'b0;
            end
            if (iss && dest != 0) begin
                rat_busy[dest] <= 1'b1;
                rat_tag[dest]  <= tail;
            end
        end
    end

    //cdb arbiter: mul wins cdb ties, add just holds its result a cycle
    wire add_v, mul_v;
    wire [1:0] add_tag, mul_tag;
    wire [7:0] add_val, mul_val;
    wire add_free, mul_free;

    assign cdb_v   = mul_v | add_v;
    assign cdb_tag = mul_v ? mul_tag : add_tag;
    assign cdb_val = mul_v ? mul_val : add_val;

    wire mul_gnt = mul_v;
    wire add_gnt = add_v & !mul_v;

    arf rf(.clk(clk), .reset(reset), .we(c_v), .rs1(rs1), .rs2(rs2),
           .rd(c_rd), .wd(c_val), .rd1(rd1), .rd2(rd2));

    rob rob0(.clk(clk), .reset(reset), .alloc(iss), .a_rd(dest), .a_pc(pc),
             .cdb_v(cdb_v), .cdb_tag(cdb_tag), .cdb_val(cdb_val),
             .rj_tag(qj), .rk_tag(qk),
             .tail(tail), .full(rob_full), .head(head),
             .rj_done(rj_done), .rj_val(rj_val), .rk_done(rk_done), .rk_val(rk_val),
             .c_v(c_v), .c_rd(c_rd), .c_val(c_val), .c_pc(c_pc), .cdb_pc(cdb_pc));

    wire add_d_v;
    wire [1:0] add_d_op, add_d_dst;
    wire [7:0] add_d_a, add_d_b;

    rs rs_add(.clk(clk), .reset(reset), .we(iss & !is_mul),
              .w_op(fop), .w_vj(vj), .w_qjv(qjv), .w_qj(qj),
              .w_vk(vk), .w_qkv(qkv), .w_qk(qk), .w_dst(tail),
              .cdb_v(cdb_v), .cdb_tag(cdb_tag), .cdb_val(cdb_val),
              .fu_free(add_free), .full(add_full),
              .d_v(add_d_v), .d_op(add_d_op), .d_a(add_d_a), .d_b(add_d_b), .d_dst(add_d_dst));

    add_fu add0(.clk(clk), .reset(reset), .start(add_d_v), .sub(add_d_op[0]),
                .a(add_d_a), .b(add_d_b), .tag(add_d_dst),
                .grant(add_gnt), .v(add_v), .tag_o(add_tag), .val(add_val), .free(add_free));

    wire mul_d_v;
    wire [1:0] mul_d_op, mul_d_dst;
    wire [7:0] mul_d_a, mul_d_b;

    rs rs_mul(.clk(clk), .reset(reset), .we(iss & is_mul),
              .w_op(fop), .w_vj(vj), .w_qjv(qjv), .w_qj(qj),
              .w_vk(vk), .w_qkv(qkv), .w_qk(qk), .w_dst(tail),
              .cdb_v(cdb_v), .cdb_tag(cdb_tag), .cdb_val(cdb_val),
              .fu_free(mul_free), .full(mul_full),
              .d_v(mul_d_v), .d_op(mul_d_op), .d_a(mul_d_a), .d_b(mul_d_b), .d_dst(mul_d_dst));

    mul_fu mul0(.clk(clk), .reset(reset), .start(mul_d_v),
                .a(mul_d_a), .b(mul_d_b), .tag(mul_d_dst),
                .grant(mul_gnt), .v(mul_v), .tag_o(mul_tag), .val(mul_val), .free(mul_free));

endmodule
