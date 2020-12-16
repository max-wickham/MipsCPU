module Decoder(
    input logic clk,
    input logic[31:0] Instr,
    input logic stall,
    input logic OutLSB,
    input logic Rst,
    input logic PCIs0,
    input logic waitrequest,
    output logic ExtSel,
    output logic IrSel,
   // output logic IrWrite,
    output logic IorD,
    output logic ALUSrcA,
    output logic[1:0] ALUSrcB,
    output logic[4:0] ALUControl,
    output logic ALUSel,
    output logic IrWrite,
    output logic PCWrite,
    output logic RegWrite,
    output logic MemtoReg, 
    output logic PCSrc,
    output logic RegDst,
    output logic MemWrite,
    output logic MemRead,
    output logic Active,
    output logic Is_Jump,
    output logic Link,
    output logic[3:0] byteenable
);


  logic is_branch_delay, is_branch_delay_next;
  /* Using an enum to define constants */
  typedef enum logic[5:0] {
        R_TYPE = 6'b000000,
        BLT_TYPE = 6'b000001,
        LW = 6'b100011,
        SW = 6'b101011,
        ADDIU = 6'b001001,
        ANDI = 6'b001100,
        J = 6'b000010,
        LB = 6'b100000,
        ORI = 6'b001101,
        SLTI = 6'b001010,
        BGTZ = 6'b000111,
        BLEZ = 6'b000110,
       // J = 6'b000010,
        BEQ = 6'b000101,
        BNE = 6'b000100,
        SLTIU = 6'b101000,
        JAL = 6'b000011
   } opcode_t;

  /* Another enum to define CPU states. */
  typedef enum logic[2:0] {
      FETCH = 3'b000,
      DECODE = 3'b001,
      EXEC_1  = 3'b010,
      EXEC_2  = 3'b011,
      EXEC_3 = 3'b100,
      HALTED = 3'b101,
      STALL = 3'b110
  } state_t;

  /*enum for R-Type*/
  /* Using an enum to define constants */
  typedef enum logic[5:0] {
      ADDU = 6'b100001,
      AND = 6'b100100,
      OR =  6'b100101,
      MTHI = 6'b010001,
      MTLO = 6'b010011,
      JALR = 6'b001001,
      JR = 6'b001000,
      BRANCH = 6'b000001
  } rtype_t;

  typedef enum logic[4:0] {
      BGEZ = 5'b00001,
      BGEZAL = 5'b10001,
      BLTZ =  5'b00000,
      BLTZAL = 5'b10000
  } branch_lg;



  opcode_t instr_opcode;
  state_t state;
  rtype_t Funct;
  branch_lg branch_code;
  logic Extra;
  assign byteenable = 4'b1111;


  // Break-down the instruction into fields
  // these are just wires for our convenience
  logic[31:0] instr = Instr;
  assign instr_opcode = instr[31:26];
  assign Funct = instr[5:0];
  assign branch_code = instr[20:16];

  //skip instruction register
  assign IrSel = (state == DECODE) ? 0 : 1;
  assign PCWrite = (state == FETCH) ? 1 : 0;
  assign Is_Jump = (instr_opcode == J || instr_opcode == JAL) && (state == EXEC_1);
  assign Link = (instr_opcode == JAL) && (state == EXEC_1); 
  assign MemRead = (instr_opcode == LW) && (state == EXEC_2) || (state == FETCH) || (state == STALL);
  assign MemWrite = (instr_opcode == SW) && (state == EXEC_2);

  assign Active = state != HALTED;
  /* We are targetting an FPGA, which means we can specify the power-on value of the
      circuit. So here we set the initial state to 0, and set the output value to
      indicate the CPU is not running.
  */
  initial begin
      state = HALTED;
  end

  //State machine
  always_ff @(posedge clk) begin
      case (state)
          FETCH: state <= PCIs0?HALTED:waitrequest?STALL:DECODE;
          STALL: state <= PCIs0?HALTED:waitrequest?STALL:DECODE;
          DECODE: state <= PCIs0?HALTED:EXEC_1;
          EXEC_1: state <= PCIs0?HALTED:stall ? EXEC_1 : Extra ? EXEC_2 : FETCH;
          EXEC_2: state <= PCIs0? HALTED : waitrequest? EXEC_2 : Extra ? EXEC_3 : FETCH;
          EXEC_3: state <= PCIs0?HALTED:FETCH;
          HALTED: state <= Rst ? FETCH : HALTED;
          default: state <= HALTED;
      endcase
      //is_branch_delay <= write_branch_delay == 1 ? is_branch_delay_next : is_branch_delay;
      is_branch_delay <= is_branch_delay_next;
  end



  //Implement here your instructions! beware of the Extra signal. set Extra to 0 if you don't need a new state
  //Decode logic
  always_comb begin
      if (Rst == 1) begin
        is_branch_delay_next = 1;
      end
      //if (instr_opcode == STALL) begin
      //  MemRead = 1;
      //end
      if (instr_opcode == FETCH)begin
        //MemRead = 1;
        if (is_branch_delay == 1) begin
          PCSrc = 1;
          IorD = 0;
          Extra = 0;
        end
        else begin
          PCSrc = 0;
          IorD = 0;
          ALUSrcA = 0;
          ALUSrcB = 11;
          ALUControl = 00010;
          ALUSel = 0;
          ExtSel = 0;
          Extra = 0;
        end
      end
      else if (state == DECODE) begin
        if(instr_opcode != J  && instr_opcode != JAL) begin  
          ALUSrcA = 0;
          ALUSrcB = 11;
          ExtSel = 0;
          ALUControl = 01101;
        end
        else begin
          //ALUSrcA = 0;
          ALUSrcB = 11;
          ExtSel = 1;
          ALUControl = 001011; //this needs to be pass through for B
        end
      end
      else begin
          case (instr_opcode)

              R_TYPE: begin
                  if (Funct == MTHI || Funct == MTLO) begin
                  case (state) 
                    EXEC_1: begin
                      Extra = 0;
                      is_branch_delay_next = 0;
                    end
                  endcase
                end
                else if (Funct == JALR ) begin
                  case (state)
                    EXEC_1: begin
                      ALUSrcA = 0; //Send the PC to the ALU, the ALU needs to add 4 to it
                      ALUSrcB = 01;
                      ALUControl = 00010;//add opcode
                      ALUSel = 0;
                      RegDst = 1;
                      MemtoReg = 1;
                      RegWrite = 1;//write to memory the return address
                      Extra = 1;
                    end
                    EXEC_2: begin
                      ALUSrcA = 1; 
                      ALUControl = 01110; //Pass through opcode, output of ALU should be SrcA
                      ALUSel = 0; //skip the ALU register
                      is_branch_delay_next = 1;
                      Extra = 0;
                    end
                  endcase
                end
                else if (Funct == JR ) begin
                  case (state)
                    EXEC_1: begin
                      ALUSrcA = 1;
                      ALUControl = 01110;
                      ALUSel = 0; //skip the ALU register
                      is_branch_delay_next = 1;
                      Extra = 0;
                    end
                  endcase
                end
                else begin
                  case (state)
                    EXEC_1: begin
                      ALUSrcA = 1;
                      ALUSrcB = 00;
                      ALUControl = 01111;
                      Extra = 1;
                    end
                    EXEC_2: begin
                      ALUSel = 1;
                      RegDst = 1;
                      MemtoReg = 1;
                      RegWrite = 1;
                      Extra = 0;
                      is_branch_delay_next = 0;
                    end
                  endcase
                end
              end
              LW: case (state)
                  EXEC_1: begin
                      ALUSrcA = 1;
                      ALUSrcB = 10;
                      ALUControl = 00010;
                      ExtSel = 0;
                      Extra = 1;
                  end
                  EXEC_2: begin
                      IorD = 1;
                      Extra = 1;
                      ALUSel = 0;
                  end
                  EXEC_3: begin
                      RegDst = 0;
                      MemtoReg = 1;
                      RegWrite = 1;
                      is_branch_delay_next = 0;
                  end
              endcase

              SW: case(state)
                  EXEC_1: begin
                    ALUSrcA= 1;
                    ALUSrcB= 10;
                    ALUControl = 00010;
                    Extra=1;
                  end
                  EXEC_2: begin
                    IorD=1;
                    //MemWrite=1;
                    is_branch_delay_next = 0;
                  end
              endcase

              /*J: case(state)
                EXEC_1: begin
                  PCSrc=1;
                  PCWrite=1;
                end
              endcase*/

              ORI: case(state)
                EXEC_1: begin
                  ALUSrcA = 1;
                  ALUSrcB = 10;
                  ALUControl = 00001;
                  ExtSel = 1;
                  Extra = 1;
                end
                EXEC_2: begin
                  RegDst = 0;
                  MemtoReg = 0;
                  RegWrite = 1;
                  ALUSel = 1;
                  is_branch_delay_next = 0;
                  Extra= 0;
                end
              endcase

              ANDI: case(state)
                EXEC_1: begin
                  ALUSrcA = 1;
                  ALUSrcB = 10;
                  ExtSel = 0; 
                  ALUControl = 00000;
                  Extra = 1;
                end
                EXEC_2: begin
                  RegDst = 0;
                  MemtoReg = 1;
                  RegWrite = 1;
                  ALUSel=1;
                  is_branch_delay_next = 0;
                  Extra = 0;
                end
              endcase

              LB: case(state)
                EXEC_1: begin
                  ALUSrcA = 1;
                  ALUSrcB = 10;
                  ALUControl = 00010;
                  Extra = 1;
                end
                EXEC_2: begin
                  IorD = 1;
                  Extra = 1;
                end
                EXEC_3: begin
                  RegDst = 0;
                  MemtoReg = 1;
                  RegWrite = 1;
                end
              endcase

              SLTI: case(state)
                EXEC_1: begin
                  ALUSrcA = 1;
                  ExtSel = 0; 
                  ALUSrcB = 10;
                  ALUControl = 00111;
                  Extra = 1;
                end
                EXEC_2: begin
                  RegDst = 0;
                  MemtoReg = 0;
                  RegWrite = 1;
                  ALUSel = 1;
                  Extra = 0;
                  is_branch_delay_next = 0;
                end
              endcase

              SLTIU: case(state)
                EXEC_1: begin
                  ALUSrcA = 1;
                  ExtSel = 1; 
                  ALUSrcB = 10;
                  ALUControl = 00111;
                  Extra = 1;
                end
                EXEC_2: begin
                  RegDst = 0;
                  MemtoReg = 0;
                  RegWrite = 1;
                  ALUSel = 1;
                  Extra = 0;
                  is_branch_delay_next = 0;
                end
              endcase



              BGTZ: case(state)
                EXEC_1:begin
                  ALUSrcA=1;
                  ALUSrcB=00;
                  ALUControl = 00111;
                  ALUSel = 1;
                  is_branch_delay_next = (OutLSB == 1)?0:1;//this isnt an output 
                end
              endcase
              BLT_TYPE: begin
                case(branch_code)
                  BLEZ: case(state) //done ////branch
                    EXEC_1: begin
                      ALUSrcA = 1;
                      ALUControl = 01100;
                      is_branch_delay_next=(OutLSB == 1)?1:0;
                      Extra = 0;
                      ALUSel = 1;
                    end
                  endcase

                  BGEZ: case(state) //done    ///branch
                    EXEC_1: begin
                      ALUSrcA = 1;
                      ALUControl = 01100;
                      is_branch_delay_next=(OutLSB == 0)?1:0;
                      Extra = 0;
                      ALUSel = 1;
                    end
                  endcase
                endcase
              end

              BEQ: case(state) //done
                EXEC_1: begin
                  ALUSrcA = 1;
                  ALUSrcB = 00;
                  ALUControl = 01010;
                  is_branch_delay_next=(OutLSB == 1)?1:0;
                  Extra = 0;
                  ALUSel = 1;
                end
              endcase

              BNE: case(state) //done
                EXEC_1: begin
                  ALUSrcA = 1;
                  ALUSrcB = 00;
                  ALUControl = 01010;
                  is_branch_delay_next=(OutLSB == 0)?1:0;
                  Extra = 0;
                  ALUSel = 1;
                end
              endcase

              BGEZAL: case(state) //TODO
                EXEC_1: begin
                  ALUSrcA = 1;
                  ALUControl = 01100;
                  is_branch_delay_next=(OutLSB == 0)?1:0;
                  Extra = 0;
                  ALUSel = 1;
                end
              endcase

              BLEZ: case(state) //done
                EXEC_1: begin
                  ALUSrcA = 1;
                  ALUControl = 01100;
                  is_branch_delay_next=(OutLSB == 1)?1:0;
                  Extra = 0;
                  ALUSel = 1;
                end
              endcase

              J: case(state)  //Done
                EXEC_1: begin
                  is_branch_delay_next = 1;
                  Extra = 0;
                  ExtSel = 1;
                  ALUSrcB = 11;
                  ALUSel = 1;
                end
              endcase

              JAL: case(state)  //Done
                EXEC_1: begin
                  ExtSel = 1;
                  ALUSrcA = 0;
                  ALUSrcB = 01;
                  ALUControl = 00010;
                  is_branch_delay_next=1;
                  Extra = 0;
                  ALUSel = 0;
                end
              endcase

              SLTIU: case(state)  //Done
                EXEC_1: begin
                  ALUSrcA = 1;
                  ALUSrcB = 10;
                  ExtSel = 1;
                  ALUControl = 01001;
                  Extra = 1;
                  ALUSel= 0;
                end
                EXEC_2:begin
                  ALUSel = 1;
                  MemtoReg = 1;
                  RegDst = 1;
                  Extra = 0;
                  RegWrite = 1; 
                  is_branch_delay_next = 0;
                end
              endcase

              ADDIU: case (state)
                EXEC_1: begin
                  ExtSel = 1;
                  ALUSrcB = 10;
                  ALUSrcA = 1;
                  ALUControl = 00010;
                  Extra = 1;
                end
                EXEC_2: begin
                  ALUSel = 1;
                  MemtoReg = 1;
                  RegDst = 1;
                  is_branch_delay_next = 0;
                  RegWrite = 1;
                  Extra = 0;
                end
              endcase
          endcase
      end
  end
endmodule
