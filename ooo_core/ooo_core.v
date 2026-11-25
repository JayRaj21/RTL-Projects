`timescale 1ns/1ps

module arf(clk, reset, we, rs1, rs2, rd, wd, rd1, rd2);
    //8 registers, 8 bits wide. x0 always reads as zero. written only by commit
    input clk, reset, we;
    input [2:0] rs1, rs2, rd;
    input [7:0] wd;
    output [7:0] rd1, rd2;

    reg [7:0] registers [1:7];
    integer i;

    assign rd1 = (rs1 == 0) ? 8'd0 : registers[rs1];
    assign rd2 = (rs2 == 0) ? 8'd0 : registers[rs2];

    always @(posedge clk) begin
        if (reset) begin
            //reset to x, not 0, so "never written" is visible, not confused with a real 0
            for (i = 1; i <= 7; i = i + 1)
                registers[i] <= 8'bx;
        end else if (we && rd != 0) begin
            registers[rd] <= wd;
        end
    end
endmodule


module imem(addr, instr);
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
        program[1] = {OP_MULI, 3'd2, 3'd1, 3'd0, 4'd3}; //x2 = x1 * 3, 3 cycles in mul
        program[2] = {OP_ADDI, 3'd3, 3'd1, 3'd0, 4'd2}; //x3 = x1 + 2, finishes before the mul
        program[3] = {OP_SUBI, 3'd4, 3'd3, 3'd0, 4'd1}; //x4 = x3 - 1, x3 via rob tag
        program[4] = {OP_ADDI, 3'd5, 3'd2, 3'd0, 4'd1}; //x5 = x2 + 1, waits on the mul
    end

    assign instr = program[addr];
endmodule


module add_fu(clk, reset, start, sub, a, b, tag, grant, v, tag_o, val, free);
    //1-cycle add/sub unit. result sits on the cdb the cycle after dispatch
    //and is held until granted
    input clk, reset, start, sub, grant;
    input [7:0] a, b;
    input [1:0] tag;
    output reg v;
    output reg [1:0] tag_o;
    output reg [7:0] val;
    output free;

    assign free = !v;

    always @(posedge clk) begin
        if (reset) begin
            v <= 1'b0;
        end else if (start) begin
            val   <= sub ? a - b : a + b;
            tag_o <= tag;
            v     <= 1'b1;
        end else if (grant) begin
            v <= 1'b0;
        end
    end
endmodule


module mul_fu(clk, reset, start, a, b, tag, grant, v, tag_o, val, free);
    //fixed-latency multiplier
    parameter MUL_LAT = 3;
    input clk, reset, start, grant;
    input [7:0] a, b;
    input [1:0] tag;
    output v;
    output [1:0] tag_o;
    output [7:0] val;
    output free;

    reg busy;
    reg [7:0] ra, rb;
    reg [1:0] tag_r;
    reg [1:0] cnt;

    assign v = (busy && cnt == 0);
    assign val = ra * rb;
    assign free = !busy;
    assign tag_o = tag_r;

    always @(posedge clk) begin
        if (reset) begin
            busy <= 1'b0;
        end else if (start) begin
            ra <= a;
            rb <= b;
            tag_r <= tag;
            busy <= 1'b1;
            cnt <= MUL_LAT - 1;
        end else if (busy && cnt != 0) begin
            cnt <= cnt - 1;
        end else if (busy && grant) begin
            busy <= 1'b0;
        end
    end
endmodule


module rs(clk, reset, we, w_op, w_vj, w_qjv, w_qj, w_vk, w_qkv, w_qk, w_dst,
          cdb_v, cdb_tag, cdb_val, fu_free, full, d_v, d_op, d_a, d_b, d_dst);
    //hardcoded 2-entry reservation station
    input clk, reset, we;
    input [1:0] w_op;
    input [7:0] w_vj;
    input w_qjv;
    input [1:0] w_qj;
    input [7:0] w_vk;
    input w_qkv;
    input [1:0] w_qk;
    input [1:0] w_dst;
    input cdb_v;
    input [1:0] cdb_tag;
    input [7:0] cdb_val;
    input fu_free;
    output full;
    output d_v;
    output [1:0] d_op;
    output [7:0] d_a, d_b;
    output [1:0] d_dst;

    reg busy0, busy1;
    reg [1:0] op0, op1;
    reg [7:0] vj0, vj1;
    reg qjv0, qjv1;
    reg [1:0] qj0, qj1;
    reg [7:0] vk0, vk1;
    reg qkv0, qkv1;
    reg [1:0] qk0, qk1;
    reg [1:0] dst0, dst1;

    wire wslot = !busy0 ? 1'b0 : 1'b1;
    wire rdy0  = busy0 & !qjv0 & !qkv0;
    wire rdy1  = busy1 & !qjv1 & !qkv1;
    wire dslot = rdy0 ? 1'b0 : 1'b1;

    assign full  = busy0 & busy1;
    assign d_v   = (rdy0 | rdy1) & fu_free;
    assign d_op  = dslot ? op1  : op0;
    assign d_a   = dslot ? vj1  : vj0;
    assign d_b   = dslot ? vk1  : vk0;
    assign d_dst = dslot ? dst1 : dst0;

    //write slot is never busy and dispatch slot always is, so these three
    //actions never touch the same entry
    always @(posedge clk) begin
        if (reset) begin
            busy0 <= 1'b0;
            busy1 <= 1'b0;
        end else begin
            if (d_v) begin
                if (dslot) busy1 <= 1'b0;
                else       busy0 <= 1'b0;
            end
            if (we) begin
                if (wslot) begin
                    busy1 <= 1'b1; op1 <= w_op; vj1 <= w_vj; qjv1 <= w_qjv; qj1 <= w_qj;
                    vk1 <= w_vk; qkv1 <= w_qkv; qk1 <= w_qk; dst1 <= w_dst;
                end else begin
                    busy0 <= 1'b1; op0 <= w_op; vj0 <= w_vj; qjv0 <= w_qjv; qj0 <= w_qj;
                    vk0 <= w_vk; qkv0 <= w_qkv; qk0 <= w_qk; dst0 <= w_dst;
                end
            end
            if (busy0 && qjv0 && cdb_v && qj0 == cdb_tag) begin
                vj0 <= cdb_val; qjv0 <= 1'b0;
            end
            if (busy0 && qkv0 && cdb_v && qk0 == cdb_tag) begin
                vk0 <= cdb_val; qkv0 <= 1'b0;
            end
            if (busy1 && qjv1 && cdb_v && qj1 == cdb_tag) begin
                vj1 <= cdb_val; qjv1 <= 1'b0;
            end
            if (busy1 && qkv1 && cdb_v && qk1 == cdb_tag) begin
                vk1 <= cdb_val; qkv1 <= 1'b0;
            end
        end
    end
endmodule


module rob(clk, reset, alloc, a_rd, a_pc, cdb_v, cdb_tag, cdb_val, rj_tag, rk_tag,
           tail, full, head, rj_done, rj_val, rk_done, rk_val, c_v, c_rd, c_val, c_pc, cdb_pc);
    parameter ROB_SIZE = 4;
    input clk, reset, alloc;
    input [2:0] a_rd;
    input [2:0] a_pc;
    input cdb_v;
    input [1:0] cdb_tag;
    input [7:0] cdb_val;
    input [1:0] rj_tag, rk_tag;
    output [1:0] tail;
    output full;
    output [1:0] head;
    output rj_done;
    output [7:0] rj_val;
    output rk_done;
    output [7:0] rk_val;
    output c_v;
    output [2:0] c_rd;
    output [7:0] c_val;
    output [2:0] c_pc;
    output [2:0] cdb_pc;

    reg done [0:ROB_SIZE-1];
    reg [2:0] rd [0:ROB_SIZE-1];
    reg [7:0] val [0:ROB_SIZE-1];
    reg [2:0] pc [0:ROB_SIZE-1];

    reg [1:0] head_r, tail_r;
    reg [2:0] count;
    integer i;

    assign head   = head_r;
    assign tail   = tail_r;
    assign full   = (count == ROB_SIZE);
    assign c_v    = (count != 0) && done[head_r];
    assign c_rd   = rd[head_r];
    assign c_val  = val[head_r];
    assign c_pc   = pc[head_r];
    //rj_done/rj_val cover the producer-finished-but-not-committed case,
    //and rk_* the same for a reg-reg source; neither path is exercised
    //by the current program, which only uses immediate-form instructions
    assign rj_done = done[rj_tag];
    assign rj_val  = val[rj_tag];
    assign rk_done = done[rk_tag];
    assign rk_val  = val[rk_tag];
    assign cdb_pc  = pc[cdb_tag]; //used only for the trace

    always @(posedge clk) begin
        if (reset) begin
            head_r <= 2'd0;
            tail_r <= 2'd0;
            count  <= 3'd0;
            for (i = 0; i < ROB_SIZE; i = i + 1)
                done[i] <= 1'b0;
        end else begin
            if (alloc) begin
                done[tail_r] <= 1'b0;
                rd[tail_r]   <= a_rd;
                pc[tail_r]   <= a_pc;
                tail_r <= tail_r + 2'd1;
            end
            if (cdb_v) begin
                done[cdb_tag] <= 1'b1;
                val[cdb_tag]  <= cdb_val;
            end
            if (c_v) begin
                head_r <= head_r + 2'd1;
            end
            count <= count + alloc - c_v;
        end
    end
endmodule


module ooo_core(clk, reset, cdb_v, cdb_tag, cdb_val, cdb_pc, c_v, c_rd, c_val, c_pc);
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
    imem imem0(.addr(pc), .instr(instr));

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
