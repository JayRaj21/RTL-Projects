module regfile(clk, we, rs1, rs2, rd, wd, rd1, rd2);
    input clk, we;
    input [4:0] rs1, rs2, rd;
    input [31:0] wd;
    output [31:0] rd1, rd2;

    reg [31:0] regs [1:31]; //x0 is hardwired to 0, never stored

    //same-cycle write/read bypass: if WB is writing the register ID is
    //reading this same cycle, the plain array read would return the
    //stale pre-write value - EX-stage forwarding can't cover this case
    //because by the time the dependent instruction reaches EX, this
    //write has already scrolled past the MEM/WB pipeline register
    assign rd1 = (rs1 == 0) ? 32'b0 : (we && rd == rs1) ? wd : regs[rs1];
    assign rd2 = (rs2 == 0) ? 32'b0 : (we && rd == rs2) ? wd : regs[rs2];

    always @(posedge clk) begin
        if (we && rd != 0)
            regs[rd] <= wd;
    end
endmodule


module alu(a, b, alu_op, result, zero);
    input [31:0] a, b;
    input alu_op; //0=add, 1=sub
    output [31:0] result;
    output zero;

    assign result = alu_op ? (a - b) : (a + b);
    assign zero = (result == 32'b0);
endmodule


module imm_gen(instr, imm);
    input [31:0] instr;
    output reg [31:0] imm;
    wire [6:0] opcode = instr[6:0];

    always @(*) begin
        case (opcode)
            7'b0010011, 7'b0000011: //I-type: addi, lw
                imm = {{20{instr[31]}}, instr[31:20]};
            7'b0100011: //S-type: sw
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            7'b1100011: //B-type: beq
                imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            default:
                imm = 32'b0;
        endcase
    end
endmodule


module control(opcode, funct7, reg_write, alu_src, mem_read, mem_write, mem_to_reg, branch, alu_op);
    input [6:0] opcode;
    input [6:0] funct7;
    output reg reg_write, alu_src, mem_read, mem_write, mem_to_reg, branch, alu_op;

    always @(*) begin
        reg_write = 0; alu_src = 0; mem_read = 0;
        mem_write = 0; mem_to_reg = 0; branch = 0; alu_op = 0;
        case (opcode)
            7'b0110011: begin //add/sub
                reg_write = 1;
                alu_op = funct7[5]; //0=add, 1=sub
            end
            7'b0010011: begin //addi
                reg_write = 1;
                alu_src = 1;
            end
            7'b0000011: begin //lw
                reg_write = 1;
                alu_src = 1;
                mem_read = 1;
                mem_to_reg = 1;
            end
            7'b0100011: begin //sw
                alu_src = 1;
                mem_write = 1;
            end
            7'b1100011: begin //beq
                branch = 1;
                alu_op = 1; //subtract for equality compare
            end
            default: ; //unrecognized opcode behaves as a safe no-op
        endcase
    end
endmodule


module hazard_unit(id_ex_mem_read, id_ex_rd, if_id_rs1, if_id_rs2, stall);
    input id_ex_mem_read;
    input [4:0] id_ex_rd, if_id_rs1, if_id_rs2;
    output stall;

    //load-use hazard: the instruction right behind a load needs its result
    //one cycle before forwarding can supply it, so we stall instead
    assign stall = id_ex_mem_read && (id_ex_rd != 0) &&
                   ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2));
endmodule


module forward_unit(ex_mem_reg_write, ex_mem_rd, mem_wb_reg_write, mem_wb_rd,
                     id_ex_rs1, id_ex_rs2, forward_a, forward_b);
    input ex_mem_reg_write, mem_wb_reg_write;
    input [4:0] ex_mem_rd, mem_wb_rd, id_ex_rs1, id_ex_rs2;
    output reg [1:0] forward_a, forward_b; //00=none, 01=from MEM/WB, 10=from EX/MEM

    always @(*) begin
        if (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs1))
            forward_a = 2'b10;
        else if (mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs1))
            forward_a = 2'b01;
        else
            forward_a = 2'b00;

        if (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs2))
            forward_b = 2'b10;
        else if (mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == id_ex_rs2))
            forward_b = 2'b01;
        else
            forward_b = 2'b00;
    end
endmodule


module imem(addr, instr);
    input [31:0] addr;
    output [31:0] instr;

    reg [31:0] mem [0:63];

    initial begin
        mem[0]  = 32'h00500093; //addi x1, x0, 5
        mem[1]  = 32'h00A00113; //addi x2, x0, 10
        mem[2]  = 32'h002081B3; //add  x3, x1, x2        (needs forwarding from x1,x2)
        mem[3]  = 32'h40118233; //sub  x4, x3, x1         (needs forwarding from x3)
        mem[4]  = 32'h00302023; //sw   x3, 0(x0)
        mem[5]  = 32'h00002283; //lw   x5, 0(x0)
        mem[6]  = 32'h00128333; //add  x6, x5, x1         (load-use hazard on x5, needs stall)
        mem[7]  = 32'h00108463; //beq  x1, x1, 8          (always taken, skips next instruction)
        mem[8]  = 32'h06300393; //addi x7, x0, 99         (must be flushed - never executes)
        mem[9]  = 32'h02A00413; //addi x8, x0, 42         (branch target)
        mem[10] = 32'h00000013; //nop
        mem[11] = 32'h00000013; //nop
        mem[12] = 32'h00000013; //nop
    end

    assign instr = mem[addr[31:2]];
endmodule


module dmem(clk, we, addr, wdata, rdata);
    input clk, we;
    input [31:0] addr, wdata;
    output [31:0] rdata;

    reg [31:0] mem [0:63];

    assign rdata = mem[addr[31:2]];

    always @(posedge clk) begin
        if (we)
            mem[addr[31:2]] <= wdata;
    end
endmodule


module riscv_subset(clk, reset, pc_out, wb_rd_addr, wb_rd_data, wb_reg_write);
    input clk, reset;
    output [31:0] pc_out;
    output [4:0] wb_rd_addr;
    output [31:0] wb_rd_data;
    output wb_reg_write;

    wire stall, branch_taken;
    wire [31:0] branch_target;

    //================= IF stage =================
    reg [31:0] pc;
    wire [31:0] instr_if;

    assign pc_out = pc;

    imem imem0(.addr(pc), .instr(instr_if));

    always @(posedge clk) begin
        if (reset)
            pc <= 32'b0;
        else if (branch_taken)
            pc <= branch_target;
        else if (stall)
            pc <= pc;
        else
            pc <= pc + 4;
    end

    //================= IF/ID pipeline register =================
    reg [31:0] if_id_instr, if_id_pc;

    always @(posedge clk) begin
        if (reset || branch_taken)
            if_id_instr <= 32'h00000013; //flush to nop
        else if (stall)
            if_id_instr <= if_id_instr; //hold
        else
            if_id_instr <= instr_if;

        if (!stall)
            if_id_pc <= pc;
    end

    //================= ID stage =================
    wire [6:0] opcode = if_id_instr[6:0];
    wire [6:0] funct7 = if_id_instr[31:25];
    wire [4:0] rs1    = if_id_instr[19:15];
    wire [4:0] rs2    = if_id_instr[24:20];
    wire [4:0] rd_id  = if_id_instr[11:7];

    wire [31:0] rs1_data, rs2_data, imm;
    wire id_reg_write, id_alu_src, id_mem_read, id_mem_write, id_mem_to_reg, id_branch, id_alu_op;

    regfile rf(.clk(clk), .we(wb_reg_write), .rs1(rs1), .rs2(rs2), .rd(wb_rd_addr),
               .wd(wb_rd_data), .rd1(rs1_data), .rd2(rs2_data));

    imm_gen immgen0(.instr(if_id_instr), .imm(imm));

    control ctrl0(.opcode(opcode), .funct7(funct7),
                  .reg_write(id_reg_write), .alu_src(id_alu_src), .mem_read(id_mem_read),
                  .mem_write(id_mem_write), .mem_to_reg(id_mem_to_reg),
                  .branch(id_branch), .alu_op(id_alu_op));

    hazard_unit hz0(.id_ex_mem_read(id_ex_mem_read), .id_ex_rd(id_ex_rd),
                     .if_id_rs1(rs1), .if_id_rs2(rs2), .stall(stall));

    //================= ID/EX pipeline register =================
    reg id_ex_reg_write, id_ex_alu_src, id_ex_mem_read, id_ex_mem_write,
        id_ex_mem_to_reg, id_ex_branch, id_ex_alu_op;
    reg [31:0] id_ex_rs1_data, id_ex_rs2_data, id_ex_imm, id_ex_pc;
    reg [4:0] id_ex_rs1, id_ex_rs2, id_ex_rd;

    always @(posedge clk) begin
        if (reset || branch_taken || stall) begin
            id_ex_reg_write  <= 0;
            id_ex_alu_src    <= 0;
            id_ex_mem_read   <= 0;
            id_ex_mem_write  <= 0;
            id_ex_mem_to_reg <= 0;
            id_ex_branch     <= 0;
            id_ex_alu_op     <= 0;
            id_ex_rs1_data   <= 0;
            id_ex_rs2_data   <= 0;
            id_ex_imm        <= 0;
            id_ex_pc         <= 0;
            id_ex_rs1        <= 0;
            id_ex_rs2        <= 0;
            id_ex_rd         <= 0;
        end else begin
            id_ex_reg_write  <= id_reg_write;
            id_ex_alu_src    <= id_alu_src;
            id_ex_mem_read   <= id_mem_read;
            id_ex_mem_write  <= id_mem_write;
            id_ex_mem_to_reg <= id_mem_to_reg;
            id_ex_branch     <= id_branch;
            id_ex_alu_op     <= id_alu_op;
            id_ex_rs1_data   <= rs1_data;
            id_ex_rs2_data   <= rs2_data;
            id_ex_imm        <= imm;
            id_ex_pc         <= if_id_pc;
            id_ex_rs1        <= rs1;
            id_ex_rs2        <= rs2;
            id_ex_rd         <= rd_id;
        end
    end

    //================= EX stage =================
    wire [1:0] forward_a, forward_b;

    forward_unit fu0(.ex_mem_reg_write(ex_mem_reg_write), .ex_mem_rd(ex_mem_rd),
                      .mem_wb_reg_write(mem_wb_reg_write), .mem_wb_rd(mem_wb_rd),
                      .id_ex_rs1(id_ex_rs1), .id_ex_rs2(id_ex_rs2),
                      .forward_a(forward_a), .forward_b(forward_b));

    wire [31:0] fwd_rs1_data = (forward_a == 2'b10) ? ex_mem_alu_result :
                               (forward_a == 2'b01) ? wb_rd_data : id_ex_rs1_data;
    wire [31:0] fwd_rs2_data = (forward_b == 2'b10) ? ex_mem_alu_result :
                               (forward_b == 2'b01) ? wb_rd_data : id_ex_rs2_data;

    wire [31:0] alu_in_b = id_ex_alu_src ? id_ex_imm : fwd_rs2_data;
    wire [31:0] alu_result;
    wire alu_zero;

    alu alu0(.a(fwd_rs1_data), .b(alu_in_b), .alu_op(id_ex_alu_op), .result(alu_result), .zero(alu_zero));

    assign branch_taken  = id_ex_branch && alu_zero;
    assign branch_target = id_ex_pc + id_ex_imm;

    //================= EX/MEM pipeline register =================
    reg ex_mem_reg_write, ex_mem_mem_read, ex_mem_mem_write, ex_mem_mem_to_reg;
    reg [31:0] ex_mem_alu_result, ex_mem_rs2_data;
    reg [4:0] ex_mem_rd;

    always @(posedge clk) begin
        if (reset) begin
            ex_mem_reg_write  <= 0;
            ex_mem_mem_read   <= 0;
            ex_mem_mem_write  <= 0;
            ex_mem_mem_to_reg <= 0;
            ex_mem_alu_result <= 0;
            ex_mem_rs2_data   <= 0;
            ex_mem_rd         <= 0;
        end else begin
            ex_mem_reg_write  <= id_ex_reg_write;
            ex_mem_mem_read   <= id_ex_mem_read;
            ex_mem_mem_write  <= id_ex_mem_write;
            ex_mem_mem_to_reg <= id_ex_mem_to_reg;
            ex_mem_alu_result <= alu_result;
            ex_mem_rs2_data   <= fwd_rs2_data; //store data also benefits from forwarding
            ex_mem_rd         <= id_ex_rd;
        end
    end

    //================= MEM stage =================
    wire [31:0] mem_rdata;

    dmem dmem0(.clk(clk), .we(ex_mem_mem_write), .addr(ex_mem_alu_result),
               .wdata(ex_mem_rs2_data), .rdata(mem_rdata));

    //================= MEM/WB pipeline register =================
    reg mem_wb_reg_write, mem_wb_mem_to_reg;
    reg [31:0] mem_wb_alu_result, mem_wb_mem_data;
    reg [4:0] mem_wb_rd;

    always @(posedge clk) begin
        if (reset) begin
            mem_wb_reg_write  <= 0;
            mem_wb_mem_to_reg <= 0;
            mem_wb_alu_result <= 0;
            mem_wb_mem_data   <= 0;
            mem_wb_rd         <= 0;
        end else begin
            mem_wb_reg_write  <= ex_mem_reg_write;
            mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_mem_data   <= mem_rdata;
            mem_wb_rd         <= ex_mem_rd;
        end
    end

    //================= WB stage =================
    assign wb_reg_write = mem_wb_reg_write;
    assign wb_rd_addr   = mem_wb_rd;
    assign wb_rd_data   = mem_wb_mem_to_reg ? mem_wb_mem_data : mem_wb_alu_result;

endmodule
