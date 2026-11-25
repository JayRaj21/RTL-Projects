`timescale 1ns/1ps

module regfile(clk, reset, we, rs1, rs2, rd, wd, rd1, rd2);
    // 8 registers, 8 bits wide. x0 always reads as zero.
    input clk, reset, we;
    input [2:0] rs1, rs2, rd;
    input [7:0] wd;
    output [7:0] rd1, rd2;

    reg [7:0] registers [1:7];
    integer i;

    //bypass: if we're writing rd this cycle and reading the same reg, forward it
    assign rd1 = (rs1 == 0)        ? 8'd0 :
                 (we && rd == rs1) ? wd   :
                 registers[rs1];

    assign rd2 = (rs2 == 0)        ? 8'd0 :
                 (we && rd == rs2) ? wd   :
                 registers[rs2];

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


module alu(a, b, alu_op, result);
    input [7:0] a, b;
    input alu_op; //0 = add, 1 = subtract
    output [7:0] result;

    assign result = alu_op ? (a - b) : (a + b);
endmodule


module imem(addr, instr);
    //instruction layout (16 bits):
    //  [15:13] opcode
    //  [12:10] rd
    //  [9:7]   rs1
    //  [6:4]   rs2   (ADD/SUB/MUL)
    //  [3:0]   imm   (ADDI)
    parameter OP_ADD  = 3'b000;
    parameter OP_SUB  = 3'b001;
    parameter OP_ADDI = 3'b010;
    parameter OP_MUL  = 3'b011; //takes 2 cycles in EX - forces a real stall, forwarding alone can't fix it

    input [7:0] addr;
    output [15:0] instr;

    reg [15:0] program [0:31];

    initial begin
        program[0] = {OP_ADDI, 3'd1, 3'd0, 3'd0, 4'd5}; //x1 = 0 + 5
        program[1] = {OP_ADDI, 3'd2, 3'd0, 3'd0, 4'd3}; //x2 = 0 + 3
        program[2] = {OP_ADD,  3'd3, 3'd1, 3'd2, 4'd0}; //x3 = x1 + x2 (needs forwarding)
        program[3] = {OP_SUB,  3'd4, 3'd3, 3'd1, 4'd0}; //x4 = x3 - x1
        program[4] = {OP_ADD,  3'd5, 3'd4, 3'd2, 4'd0}; //x5 = x4 + x2
        program[5] = {OP_MUL,  3'd6, 3'd1, 3'd2, 4'd0}; //x6 = x1 * x2 (2-cycle EX, stalls the next instruction)
        program[6] = {OP_ADD,  3'd7, 3'd6, 3'd1, 4'd0}; //x7 = x6 + x1 (needs x6 right after the stall)
        program[7] = {OP_ADDI, 3'd0, 3'd0, 3'd0, 4'd0}; //nop
    end

    assign instr = program[addr];
endmodule


module pipelined_alu(clk, reset, wb_rd_addr, wb_rd_data, wb_reg_write);
    input clk, reset;
    output [2:0] wb_rd_addr;
    output [7:0] wb_rd_data;
    output wb_reg_write;

    parameter OP_SUB  = 3'b001;
    parameter OP_ADDI = 3'b010;
    parameter OP_MUL  = 3'b011;

    //per-stage delay so this can be timed against unpipelined_alu below
    parameter STAGE1_DELAY = 4; //fetch + reg read
    parameter STAGE2_DELAY = 4; //alu

    //stage 1: fetch + decode
    reg [7:0] pc;

    always @(posedge clk) begin
        if (reset)
            pc <= 8'd0;
        else if (!stall)
            pc <= pc + 8'd1;
    end

    wire [15:0] instr;
    imem imem0(.addr(pc), .instr(instr));

    wire [2:0] opcode = instr[15:13];
    wire [2:0] dest   = instr[12:10];
    wire [2:0] rs1    = instr[9:7];
    wire [2:0] rs2    = instr[6:4];
    wire [3:0] imm    = instr[3:0];

    wire use_imm = (opcode == OP_ADDI);
    wire is_sub  = (opcode == OP_SUB);
    wire is_mul  = (opcode == OP_MUL);

    wire [7:0] rd1_raw, rd2_raw;

    regfile rf(.clk(clk), .reset(reset), .we(wb_reg_write), .rs1(rs1), .rs2(rs2),
               .rd(wb_rd_addr), .wd(wb_rd_data), .rd1(rd1_raw), .rd2(rd2_raw));

    wire [7:0] rd1, rd2;
    assign #STAGE1_DELAY rd1 = rd1_raw;
    assign #STAGE1_DELAY rd2 = rd2_raw;

    //FD/EX pipeline register
    reg [7:0] ex_a, ex_b, ex_imm;
    reg [2:0] ex_dest, ex_rs1, ex_rs2;
    reg ex_write, ex_use_imm, ex_is_sub, ex_is_mul;

    always @(posedge clk) begin
        if (reset) begin
            ex_a       <= 8'd0;
            ex_b       <= 8'd0;
            ex_imm     <= 8'd0;
            ex_dest    <= 3'd0;
            ex_rs1     <= 3'd0;
            ex_rs2     <= 3'd0;
            ex_write   <= 1'b0;
            ex_use_imm <= 1'b0;
            ex_is_sub  <= 1'b0;
            ex_is_mul  <= 1'b0;
        end else if (!stall) begin
            //while stalled, hold ex_* as-is - the MUL already in EX needs
            //to stay put for its second cycle, so don't let a new fetch in
            ex_a       <= rd1;
            ex_b       <= rd2;
            ex_imm     <= {4'b0, imm};
            ex_dest    <= dest;
            ex_rs1     <= rs1;
            ex_rs2     <= rs2;
            ex_write   <= 1'b1; //nop writes x0, which is ignored
            ex_use_imm <= use_imm;
            ex_is_sub  <= is_sub;
            ex_is_mul  <= is_mul;
        end
    end

    //stage 2: execute. only one instruction can be ahead of EX (it's in WB),
    //so there's exactly one place to forward from
    wire fwd_a = wb_write && (wb_dest != 0) && (wb_dest == ex_rs1);
    wire fwd_b = wb_write && (wb_dest != 0) && (wb_dest == ex_rs2);

    wire [7:0] alu_a    = fwd_a ? wb_result : ex_a;
    wire [7:0] b_or_fwd = fwd_b ? wb_result : ex_b;
    wire [7:0] alu_b    = ex_use_imm ? ex_imm : b_or_fwd;

    //mul takes 2 cycles to clear EX, so forwarding alone can't feed its
    //result to the very next instruction in time - the instruction behind
    //it has to actually wait. held tracks whether this MUL has already
    //used its first cycle in EX; stall freezes pc and FD/EX for that cycle
    //and the bubble below keeps it from writing back early
    reg held;
    always @(posedge clk) begin
        if (reset)
            held <= 1'b0;
        else if (ex_is_mul && !held)
            held <= 1'b1;
        else
            held <= 1'b0;
    end
    wire stall = ex_is_mul && !held;

    wire [7:0] mul_raw;
    assign mul_raw = alu_a * alu_b;

    wire [7:0] result_raw;
    alu alu0(.a(alu_a), .b(alu_b), .alu_op(ex_is_sub), .result(result_raw));

    wire [7:0] result;
    assign #STAGE2_DELAY result = ex_is_mul ? mul_raw : result_raw;

    //EX/WB pipeline register
    reg wb_write;
    reg [7:0] wb_result;
    reg [2:0] wb_dest;

    always @(posedge clk) begin
        if (reset) begin
            wb_write  <= 1'b0;
            wb_result <= 8'd0;
            wb_dest   <= 3'd0;
        end else begin
            wb_write  <= stall ? 1'b0 : ex_write; //bubble during the mul's first EX cycle
            wb_result <= result;
            wb_dest   <= ex_dest;
        end
    end

    //stage 3: write-back
    assign wb_reg_write = wb_write;
    assign wb_rd_addr   = wb_dest;
    assign wb_rd_data   = wb_result;

endmodule


module unpipelined_alu(clk, reset, wb_rd_addr, wb_rd_data, wb_reg_write);
    //same program, but fetch + reg read + alu all complete in one cycle
    //instead of across pipeline stages
    input clk, reset;
    output [2:0] wb_rd_addr;
    output [7:0] wb_rd_data;
    output wb_reg_write;

    parameter OP_SUB  = 3'b001;
    parameter OP_ADDI = 3'b010;
    parameter OP_MUL  = 3'b011;

    //fetch+read+alu as one cumulative delay (8 = pipelined_alu's two 4ns
    //stages added together), applied once on the final result. NOT two
    //separate #4 delays - each assign only tracks its own input, so two
    //chained delays could each individually keep up with a 6ns clock even
    //though the real 8ns path shouldn't. see timing_demo.v for the same idea
    parameter CRIT_DELAY = 8;

    reg [7:0] pc;

    always @(posedge clk) begin
        if (reset)
            pc <= 8'd0;
        else
            pc <= pc + 8'd1;
    end

    wire [15:0] instr;
    imem imem0(.addr(pc), .instr(instr));

    wire [2:0] opcode = instr[15:13];
    wire [2:0] dest   = instr[12:10];
    wire [2:0] rs1    = instr[9:7];
    wire [2:0] rs2    = instr[6:4];
    wire [3:0] imm    = instr[3:0];

    wire use_imm = (opcode == OP_ADDI);
    wire is_sub  = (opcode == OP_SUB);
    wire is_mul  = (opcode == OP_MUL);

    wire [7:0] rd1, rd2;

    //note: if an instruction ever reads its own dest reg, regfile's bypass
    //would feed the not-yet-settled write-back value straight back into the
    //alu input. the current program never does this, so it's untested
    regfile rf(.clk(clk), .reset(reset), .we(wb_reg_write), .rs1(rs1), .rs2(rs2),
               .rd(wb_rd_addr), .wd(wb_rd_data), .rd1(rd1), .rd2(rd2));

    wire [7:0] alu_b = use_imm ? {4'b0, imm} : rd2;

    wire [7:0] alu_raw;
    alu alu0(.a(rd1), .b(alu_b), .alu_op(is_sub), .result(alu_raw));
    wire [7:0] result_raw = is_mul ? (rd1 * alu_b) : alu_raw;

    //dest is bundled together with the result and delayed as one signal, so
    //the write address and write data can't drift apart - two separate
    //delayed assigns could let one freeze while the other keeps tracking
    //the next instruction, writing the wrong data into the wrong register
    wire [10:0] wb_bundle_raw = {dest, result_raw};
    wire [10:0] wb_bundle;
    assign #CRIT_DELAY wb_bundle = wb_bundle_raw;

    assign wb_reg_write = 1'b1;
    assign wb_rd_addr   = wb_bundle[10:8];
    assign wb_rd_data   = wb_bundle[7:0];

endmodule
