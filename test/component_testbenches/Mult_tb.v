module Mult_tb(
);
    //Inputs
    logic[31:0] SrcA, SrcB;
    logic[2:0] ALUControl;

    //Outputs
    logic[31:0] Hi;
    logic[31:0] Lo;
    logic[63:0] Out;

    assign Out[63:32] = Hi;
    assign Out[31:0] = Lo;

    logic clk;
    logic validIn;
    logic validOut;

    Mult mult(
            .clk(clk),
            .validIn(validIn),
            .validOut(validOut),
            .SrcA(SrcA), 
            .SrcB(SrcB),
            .Hi(Hi),
            .Lo(Lo)
    );

    integer i;


    initial begin
        //$dumpfile("multiplier_iterative.vcd");
        //$dumpvars(0, multiplier_iterative_tb);
        clk = 0;
        i = 0;
        #5;

        repeat (1000) begin
            i = i+1;
            #10 clk = !clk;
        end

        $fatal(2, "Fail : test-bench timed out without positive exit.");
    end



    initial begin
        SrcA = 32'd54;
        SrcB = 32'd101;

        validIn = 1;

        #10;

        validIn = 0;

        #20;

        while(validOut == 0) begin
            #10;
            //$display("Out=%d", validOut);
        end

        $display("Out=%d", Out);
        $display("I=%d",i);
        $finish;
    end


endmodule