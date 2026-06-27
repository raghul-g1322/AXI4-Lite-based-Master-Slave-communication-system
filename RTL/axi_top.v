module axi_top #(parameter ADDR_WIDTH = 32, parameter DATA_WIDTH = 32) (
    input  wire                  ACLK,
    input  wire                  ARSTn,
    output wire [15:0]           LED,      // Peripheral output from slave
    output wire                  WR_ERR,   // Error from Master
    output wire                  RD_ERR    // Error from Master
);

    // AXI4-Lite Interconnect Signals
    // Write Address
    wire [ADDR_WIDTH-1:0] AWADDR;
    wire                  AWVALID;
    wire                  AWREADY;

    // Write Data
    wire [DATA_WIDTH-1:0] WDATA;
    wire [(DATA_WIDTH/8)-1:0] WSTRB;
    wire                  WVALID;
    wire                  WREADY;

    // Write Response
    wire [1:0]            BRESP;
    wire                  BVALID;
    wire                  BREADY;

    // Read Address
    wire [ADDR_WIDTH-1:0] ARADDR;
    wire                  ARVALID;
    wire                  ARREADY;

    // Read Data + Response
    wire [DATA_WIDTH-1:0] RDATA;
    wire [1:0]            RRESP;
    wire                  RVALID;
    wire                  RREADY;
    
    wire clk_out;
    
    // CLK Divider
    clk_div_axi U_CLK_DIV (.clk(ACLK),
                           .rstn(ARSTn),
                           .clk_out(clk_out));
                           
    // Master Instance
    axi_master #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) U_MASTER (
        .ACLK(clk_out),
        .ARSTn(ARSTn),

        // Write Address Channel
        .AWADDR(AWADDR),
        .AWVALID(AWVALID),
        .AWREADY(AWREADY),

        // Write Data Channel
        .WDATA(WDATA),
        .WSTRB(WSTRB),
        .WVALID(WVALID),
        .WREADY(WREADY),

        // Write Response Channel
        .BREADY(BREADY),
        .BRESP(BRESP),
        .BVALID(BVALID),

        // Read Address Channel
        .ARADDR(ARADDR),
        .ARVALID(ARVALID),
        .ARREADY(ARREADY),

        // Read Data Channel
        .RREADY(RREADY),
        .RVALID(RVALID),
        .RDATA(RDATA),
        .RRESP(RRESP),

        // Error Outputs
        .WR_ERR(WR_ERR),
        .RD_ERR(RD_ERR)
    );

    // Slave Instance
    axi_slave #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) U_SLAVE (
        .ACLK(clk_out),
        .ARSTn(ARSTn),

        // Write Address Channel
        .AWADDR(AWADDR),
        .AWVALID(AWVALID),
        .AWREADY(AWREADY),

        // Write Data Channel
        .WDATA(WDATA),
        .WSTRB(WSTRB),
        .WVALID(WVALID),
        .WREADY(WREADY),

        // Write Response Channel
        .BREADY(BREADY),
        .BRESP(BRESP),
        .BVALID(BVALID),

        // Read Address Channel
        .ARADDR(ARADDR),
        .ARVALID(ARVALID),
        .ARREADY(ARREADY),

        // Read Data Channel
        .RREADY(RREADY),
        .RVALID(RVALID),
        .RDATA(RDATA),
        .RRESP(RRESP),

        // Peripheral
        .LED(LED)
    );

endmodule
