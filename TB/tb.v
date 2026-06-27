`timescale 1ns/1ps

module tb;

    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;

    // Testbench Signals
    reg  ACLK;
    reg  ARSTn;
    wire [15:0] LED;
    wire WR_ERR;
    wire RD_ERR;

    // Clock Generation (100 MHz = 10 ns period)
    initial ACLK = 1'b0;
    always #5 ACLK = ~ACLK;  

    // DUT Instance
    axi_top #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) DUT (
        .ACLK(ACLK),
        .ARSTn(ARSTn),
        .LED(LED),
        .WR_ERR(WR_ERR),
        .RD_ERR(RD_ERR)
    );

    // Reset Logic
    initial begin
        ARSTn = 1'b0;
        #20;             // Hold reset low for some cycles
        ARSTn = 1'b1;
    end

    // Monitor signals continuously
    initial begin
        $monitor("[%0t] LED = %h | WR_ERR = %b | RD_ERR = %b", 
                  $time, LED, WR_ERR, RD_ERR);
    end

    // Simulation Control
    initial begin

        // Run simulation for enough time to see transactions
        #1000;
        $finish;
    end

endmodule
