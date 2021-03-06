module ALU(
    input logic[4:0] ALUControl,
    input logic[31:0] SrcA,
    input logic[31:0] SrcB,
    input logic clk,

    output logic[31:0] ALUResult
);

    //it is assumed that sign extension happens outside the ALU. Thus for ADDI we sign extend the
    //immediate field before it reaches the ALU input and for ADDU we use ALUControl = 010.
    //This ALU does not handle exceptions.

    //varible to store subtraction result for SLT
    logic[31:0] SLT_sub;
    logic[31:0] JConst;
    assign JConst = {4'b0000,SrcA[26:0],2'b00};
    logic signed[31:0] NegSrcB;

    assign NegSrcB=SrcB;

    //LWL and LWR
    logic[15:0] SrcA_right;
    logic[15:0] SrcA_left;
    logic[15:0] SrcB_right;
    logic[15:0] SrcB_left; 

    logic[31:0] LWL_out;
    logic[31:0] LWR_out;
    

    assign SrcA_right = SrcA[15:0];
    assign SrcA_left = SrcA[31:16];
    assign SrcB_right = SrcB[15:0];
    assign SrcB_left = SrcB[31:16];

    //assign LWL_out = {SrcA_left,SrcB_right};
    //assign LWR_out = {SrcB_left,SrcA_right};
    
    //logic signed SrcASigned;
    logic[31:0] prev_out;
    logic[31:0] mem_add;
    logic[2:0] byte_number;
    logic[31:0] lwl_out;
    logic[31:0] lwr_out;

    LWRL_mod lwrl_mod(
        .SrcA(SrcA),
        .SrcB(SrcB),
        .byte_number(byte_number),
        .LWL(lwl_out),
        .LWR(lwr_out)
    );


    always_comb begin
        case (ALUControl)
            5'b00000  :   begin
                // logical AND
                ALUResult = SrcA & SrcB;
            end
            5'b00001  :   begin
                // logical OR
                ALUResult = SrcA | SrcB;
            end
            5'b00010  :   begin
                // Addition
                ALUResult = SrcA + SrcB;
            end
            5'b00011  :   begin
                // logical XOR
                ALUResult = SrcA ^ SrcB;
            end
            5'b00100  :   begin
                // shift left logical
                ALUResult = SrcB << SrcA;
            end
            5'b00101  :   begin
                // shift right logical
                ALUResult = SrcB >> SrcA;
            end
            5'b00110  :   begin
                // Subtraction
                ALUResult = SrcA - SrcB;
            end
            5'b00111  :   begin
                // SLT (Comparison signed)
                SLT_sub = SrcA - SrcB;
                if((SLT_sub >> 31) == 1)begin
                    ALUResult = 1;
                end else begin
                    ALUResult = 0;
                end
            end
            5'b01000 :   begin
                //SRA
                ALUResult = NegSrcB >>> SrcA;
            end
            5'b01001 : begin
                // SLTU (Comparison unsigned)
                if(SrcA < SrcB) begin
                    ALUResult = 1;
                end else begin
                    ALUResult = 0;
                end
            end
            5'b01010 : begin
                // is equal to 0
                SLT_sub = SrcA - SrcB;
                if( SLT_sub == 0) begin
                    ALUResult = 1;
                end else begin
                    ALUResult = 0;
                end
            end
            5'b01011 : begin
                // increment PC for branch
                ALUResult = SrcB;
            end
            5'b01100 : begin
                // is SrcA < 0
                SLT_sub = SrcA - 0;
                if((SLT_sub >> 31) == 1)begin
                    ALUResult = 1;
                end else begin
                    ALUResult = 0;
                end
            end
            5'b01101 : begin
                // needed for jumps
                ALUResult = SrcA + SrcB;
            end
            5'b01110 : begin
                //pass through SrcA
                ALUResult = SrcA;
            end

            //5'b01111 /*R-type*/

            5'b10000 : begin
                //is SrcA <= 0
                SLT_sub = SrcA - 1;
                if((SLT_sub >> 31) == 1)begin
                    ALUResult = 1;
                end else begin
                    ALUResult = 0;
                end
            end
            5'b10001 : begin
                //Jump
                ALUResult = JConst;
            end
            5'b10010 : begin
                //LWL source A is Ram
                mem_add = prev_out + 3;
                byte_number = (mem_add % 4) + 1; 
                ALUResult = lwl_out; ///
            end
            5'b10011 : begin
                //LWR source A is Ram
                mem_add = prev_out;
                byte_number = 4 - (mem_add % 4); 
                ALUResult = lwr_out;
                //ALUResult = LWL_out;
            end
            5'b10100 : begin
                //LUI
                ALUResult = SrcB << 16;
            end
            5'b10101 : begin
                //LWL MEM
                ALUResult = SrcB + SrcA - 3;
            end
            default: begin
                //$display("Unknown alu operand");
                ALUResult = 32'hxxxxxxxx;
            end
        endcase
    end

    always_ff  @(posedge clk) begin
        prev_out <= ALUResult;
    end

endmodule
