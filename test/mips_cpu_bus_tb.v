module mips_cpu_bus_tb;
    timeunit 1ns / 10ps;

    parameter RAM_INIT_FILE = "test/01-binary/countdown.hex.txt";
    //why is this just one preset input file?
    // possibly ask on Friday's class
    parameter TIMEOUT_CYCLES = 10000;

    // inputs
    logic clk;
    logic rst;

    // outputs
    logic active; // detects when the cpu has finished executing instructions, 0 when finished
    logic[31:0] register_v0; // output of register 2, used for testing

    // wires to connect to the RAM
    logic[31:0] address;
    logic write;
    logic read;
    input logic waitrequest;
    logic[31:0] writedata;
    logic[3:0] byteenable;
    logic[31:0] readdata;

    // instianting everything and making the needed connections
    // might have to make all of the relevant connections including ALU, multiplexers, etc.
    RAM_8x4096 #(RAM_INIT_FILE) ramInst(clk, address, write, read, writedata, readdata);
    // instantiating the RAM
    [/*CPU module name*/] cpuInst(clk, rst, active, register_v0, address, \
      write, read, waitrequest, writedata, byteenable, readdata);
    // instantiating the CPU

    //might need to instantiate a cache here if present

    // Generate clock
    initial begin //initial block that is time driven
        clk=0;

        repeat (TIMEOUT_CYCLES) begin
            #10;
            clk = !clk;
            #10;
            clk = !clk;
        end
        // clock is created here in the test bench
        $fatal(2, "Simulation did not finish within %d cycles.", TIMEOUT_CYCLES);
    end

    initial begin //initial block that is event driven and runs in parallel
    //to the time driven block
        rst <= 0;

        @(posedge clk);
        rst <= 1;

        @(posedge clk);
        rst <= 0;

        @(posedge clk);
        assert(active==1)
        else $display("TB : CPU did not set active=1 after reset.");

        while (active) begin
            @(posedge clk);
        end
        // checking if active is still = 1 at every positive clock edge.
        // this means that if the program stops active meaning we've reached
        // the end of the instructions, we can $finish
        $display("TB : finished; active=0");

        // identifying the output and outputting to a stdout file
        $display("RESULT : %d", register_v0);

        // needs to verify if the we have returned to address 0 before finishing
        // should be fine placing this here at the end since we have supposedly
        // finished
        assert(address==0)
        else $display("TB : CPU did not return to address 0 at the end")

        // also needs to check if every register (including the PC has been set to 0)


        $finish; //makes the simulator exit and passes control back to the host
        // operating system

    end



endmodule