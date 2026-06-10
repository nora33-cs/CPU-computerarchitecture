`timescale 1ns / 1ps

module CPU_Top_tb;

reg clk, reset;
wire [63:0] pc_out;
wire [31:0] instr_out;
wire [63:0] alu_out;
wire [63:0] x1, x2, x3, x6;

CPU_Top uut (
    .clk(clk), .reset(reset), .pc_out(pc_out), .instr_out(instr_out),
    .alu_out(alu_out), .x1(x1), .x2(x2), .x3(x3), .x6(x6)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    $display("");
    $display("========================================");
    $display("RISC-V CPU SIMULATION");
    $display("========================================");
    
    reset = 1;
    #10;
    reset = 0;
    
    #200;
    
    $display("");
    $display("========================================");
    $display("FINAL RESULTS:");
    $display("========================================");
    $display("x1 = %0d (should be 5)", x1);
    $display("x2 = %0d (should be 3)", x2);
    $display("x3 = %0d (should be 8)", x3);
    $display("x6 = %0d (should be 42)", x6);
    $display("========================================");
    
    if (x1 == 5 && x2 == 3 && x3 == 8 && x6 == 42)
        $display("✅✅✅ CPU WORKS! ✅✅✅");
    else
        $display("❌❌❌ CPU FAILS ❌❌❌");
    
    $finish;
end

always @(posedge clk) begin
    $display("PC=%0d | x1=%0d | x2=%0d | x3=%0d | x6=%0d", 
             pc_out, x1, x2, x3, x6);
end

endmodule