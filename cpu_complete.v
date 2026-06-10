`timescale 1ns / 1ps

// ============================================================
// TASK 1: ALU
// ============================================================
module ALU (
    input [63:0] A, B,
    input [3:0] ALUOp,
    output reg [63:0] Result,
    output reg Zero
);
always @(*) begin
    case (ALUOp)
        4'b0000: Result = A + B;
        4'b0001: Result = A - B;
        4'b0010: Result = A & B;
        4'b0011: Result = A | B;
        4'b0100: Result = A ^ B;
        4'b0101: Result = A << B[4:0];
        4'b0110: Result = A >> B[4:0];
        default: Result = 64'b0;
    endcase
    Zero = (Result == 64'b0);
end
endmodule

// ============================================================
// TASK 2: CONTROL UNIT
// ============================================================
module Control_Unit (
    input [6:0] opcode,
    input [2:0] funct3,
    input [6:0] funct7,
    output reg RegWrite,
    output reg MemRead,
    output reg MemWrite,
    output reg ALUSrc,
    output reg MemToReg,
    output reg Branch,
    output reg [3:0] ALUControl
);
always @(*) begin
    RegWrite = 0; MemRead = 0; MemWrite = 0; ALUSrc = 0; MemToReg = 0; Branch = 0; ALUControl = 4'b0000;
    case (opcode)
        7'b0110011: begin RegWrite = 1;
            if (funct3 == 3'b000 && funct7 == 7'b0000000) ALUControl = 4'b0000;
            else if (funct3 == 3'b000 && funct7 == 7'b0100000) ALUControl = 4'b0001;
            else if (funct3 == 3'b111) ALUControl = 4'b0010;
            else if (funct3 == 3'b110) ALUControl = 4'b0011;
            else if (funct3 == 3'b100) ALUControl = 4'b0100;
            else if (funct3 == 3'b001) ALUControl = 4'b0101;
            else if (funct3 == 3'b101) ALUControl = 4'b0110;
        end
        7'b0010011: begin RegWrite = 1; ALUSrc = 1;
            if (funct3 == 3'b000) ALUControl = 4'b0000;
            else if (funct3 == 3'b111) ALUControl = 4'b0010;
            else if (funct3 == 3'b110) ALUControl = 4'b0011;
            else if (funct3 == 3'b100) ALUControl = 4'b0100;
            else if (funct3 == 3'b001) ALUControl = 4'b0101;
            else if (funct3 == 3'b101) ALUControl = 4'b0110;
        end
        7'b0000011: begin RegWrite = 1; MemRead = 1; MemToReg = 1; ALUSrc = 1; ALUControl = 4'b0000; end
        7'b0100011: begin MemWrite = 1; ALUSrc = 1; ALUControl = 4'b0000; end
        7'b1100011: begin Branch = 1; ALUControl = 4'b0001; end
    endcase
end
endmodule

// ============================================================
// TASK 3A: REGISTER FILE
// ============================================================
module RegisterFile (
    input clk,
    input RegWrite,
    input [4:0] rs1, rs2, rd,
    input [63:0] write_data,
    output [63:0] read_data1,
    output [63:0] read_data2
);
reg [63:0] regs [31:0];
integer i;
initial for (i = 0; i < 32; i = i + 1) regs[i] = 64'b0;
always @(posedge clk) begin
    if (RegWrite && rd != 0) regs[rd] <= write_data;
    regs[0] <= 64'b0;
end
assign read_data1 = regs[rs1];
assign read_data2 = regs[rs2];
endmodule

// ============================================================
// TASK 3B: IMMEDIATE GENERATOR
// ============================================================
module ImmediateGenerator (
    input [31:0] instruction,
    output reg [63:0] imm_out
);
wire [6:0] opcode = instruction[6:0];
always @(*) begin
    case (opcode)
        7'b0010011, 7'b0000011: imm_out = {{52{instruction[31]}}, instruction[31:20]};
        7'b0100011: imm_out = {{52{instruction[31]}}, instruction[31:25], instruction[11:7]};
        7'b1100011: imm_out = {{51{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
        default: imm_out = 64'b0;
    endcase
end
endmodule

// ============================================================
// TASK 4: PC & BRANCH LOGIC
// ============================================================
module PC_Logic (
    input clk, reset,
    input Branch,
    input alu_zero,
    input [2:0] funct3,
    input [63:0] imm_ext,
    output reg [63:0] pc
);
wire [63:0] pc_plus4 = pc + 4;
wire [63:0] branch_target = pc + imm_ext;
wire take_branch = Branch & (funct3 == 3'b000 ? alu_zero : 1'b0);
wire [63:0] next_pc = take_branch ? branch_target : pc_plus4;
always @(posedge clk or posedge reset) begin
    if (reset) pc <= 64'b0;
    else pc <= next_pc;
end
endmodule

// ============================================================
// TASK 5A: INSTRUCTION MEMORY (FIXED ADDRESSING)
// ============================================================
module InstructionMemory (
    input [63:0] addr,
    output [31:0] instr
);
reg [31:0] mem [0:31];
initial begin
    // Instruction at address 0: addi x1, x0, 5
    mem[0] = 32'b000000000101_00000_000_00001_0010011;
    // Instruction at address 4: addi x2, x0, 3
    mem[1] = 32'b000000000011_00000_000_00010_0010011;
    // Instruction at address 8: add x3, x1, x2
    mem[2] = 32'b0000000_00010_00001_000_00011_0110011;
    // Instruction at address 12: addi x6, x0, 42
    mem[3] = 32'b000000101010_00000_000_00110_0010011;
end
// Divide address by 4 to get index (word addressing)
assign instr = mem[addr[4:2]];
endmodule

// ============================================================
// TASK 5B: DATA MEMORY
// ============================================================
module DataMemory (
    input clk, MemWrite, MemRead,
    input [63:0] addr,
    input [63:0] write_data,
    output reg [63:0] read_data
);
reg [63:0] mem [0:31];
integer i;
initial for (i = 0; i < 32; i = i + 1) mem[i] = 64'b0;
always @(posedge clk) begin
    if (MemWrite) mem[addr[4:2]] <= write_data;
end
always @(*) begin
    if (MemRead) read_data = mem[addr[4:2]];
    else read_data = 64'b0;
end
endmodule

// ============================================================
// TASK 5C: TOP LEVEL CPU
// ============================================================
module CPU_Top (
    input clk, reset,
    output [63:0] pc_out,
    output [31:0] instr_out,
    output [63:0] alu_out,
    output [63:0] x1, x2, x3, x6
);
wire [63:0] pc, imm_ext, read_data1, read_data2, write_data, alu_result, mem_read_data;
wire [31:0] instruction;
wire alu_zero;
wire RegWrite, MemRead, MemWrite, ALUSrc, MemToReg, Branch;
wire [3:0] ALUControl;

InstructionMemory imem(.addr(pc), .instr(instruction));
Control_Unit cu(.opcode(instruction[6:0]), .funct3(instruction[14:12]), .funct7(instruction[31:25]),
    .RegWrite(RegWrite), .MemRead(MemRead), .MemWrite(MemWrite), .ALUSrc(ALUSrc),
    .MemToReg(MemToReg), .Branch(Branch), .ALUControl(ALUControl));
ImmediateGenerator immgen(.instruction(instruction), .imm_out(imm_ext));
RegisterFile rf(.clk(clk), .RegWrite(RegWrite), .rs1(instruction[19:15]), .rs2(instruction[24:20]),
    .rd(instruction[11:7]), .write_data(write_data), .read_data1(read_data1), .read_data2(read_data2));

wire [63:0] alu_b = ALUSrc ? imm_ext : read_data2;
ALU alu(.A(read_data1), .B(alu_b), .ALUOp(ALUControl), .Result(alu_result), .Zero(alu_zero));

DataMemory dmem(.clk(clk), .MemWrite(MemWrite), .MemRead(MemRead), .addr(alu_result),
    .write_data(read_data2), .read_data(mem_read_data));

assign write_data = MemToReg ? mem_read_data : alu_result;

PC_Logic pc_logic(.clk(clk), .reset(reset), .Branch(Branch), .alu_zero(alu_zero),
    .funct3(instruction[14:12]), .imm_ext(imm_ext), .pc(pc));

assign pc_out = pc;
assign instr_out = instruction;
assign alu_out = alu_result;
assign x1 = rf.regs[1];
assign x2 = rf.regs[2];
assign x3 = rf.regs[3];
assign x6 = rf.regs[6];
endmodule
