module axi_master #(parameter ADDR_WIDTH = 32, parameter DATA_WIDTH = 32) (
    input wire ACLK, ARSTn,
    
    // Write Address Channel Ports
    output reg [ADDR_WIDTH-1:0] AWADDR,   // Write address
    output reg AWVALID,                   // Write address valid
    input wire AWREADY,                   // Write address ready
    
    // Write Data Channel Ports
    output reg [DATA_WIDTH-1:0] WDATA,    // Write data
    output reg [(DATA_WIDTH/8)-1:0] WSTRB,// Write strobes (byte enables)
    output reg WVALID,                    // Write data valid
    input wire WREADY,                    // Write data ready
    
    // Write Response Channel Ports
    output reg BREADY,                    // Write response ready
    input wire [1:0] BRESP,               // Write response (OKAY/SLVERR)
    input wire BVALID,                    // Write response valid
    
    // Read Address Channel Ports
    output reg [ADDR_WIDTH-1:0] ARADDR,   // Read address
    output reg ARVALID,                   // Read address valid
    input wire ARREADY,                   // Read address ready
    
    // Read Data and Response Channel Ports
    output reg RREADY,                    // Read data ready
    input wire RVALID,                    // Read data valid
    input wire [DATA_WIDTH-1:0] RDATA,    // Read data
    input wire [1:0] RRESP,               // Read response (OKAY/SLVERR)
    
    // Error flags
    output reg WR_ERR, RD_ERR             // Write error, Read error
    );
    
    // FSM states
    parameter   IDLE    = 3'd0,
                RD_ADDR = 3'd1,
                R_DATA  = 3'd2,
                WR_ADDR = 3'd3,
                W_RESP  = 3'd4;
    
    reg [2:0] cs, ns;                     // Current state, Next state
    reg [DATA_WIDTH-1:0] read_data;       // Internal register to hold read data

    // Sequential block: state + register updates
    always @ (posedge ACLK or negedge ARSTn) begin
        if(!ARSTn) begin
            // Reset all outputs and FSM state
            cs <= IDLE;
            AWADDR   <= {ADDR_WIDTH{1'b0}};
            AWVALID  <= 1'b0;
            WDATA    <= {DATA_WIDTH{1'b0}};
            WSTRB    <= {DATA_WIDTH/8{1'b1}};
            WVALID   <= 1'b0;
            BREADY   <= 1'b0;
            ARADDR   <= {ADDR_WIDTH{1'b0}};
            ARVALID  <= 1'b0;
            RREADY   <= 1'b0;
            read_data <= {DATA_WIDTH{1'b0}};
            RD_ERR   <= 1'b0;
            WR_ERR   <= 1'b0;
        end
        else begin
            cs <= ns;  // Update state
            // Rotate WSTRB every cycle (pattern for testing writes)
            WSTRB <= {~WSTRB[0], WSTRB[3:1]};
            
            // FSM actions
          //  BREADY <= 1'b0;
            case(cs)
                // Idle: issue a read address (e.g., reading from offset 0x04)
                IDLE :  begin
                            ARADDR  <= 32'h00000004;
                            ARVALID <= 1'b1;
                        end
                        
                // Read address phase: wait for ARREADY handshake
                RD_ADDR :   begin
                                ARVALID <= (ARREADY) ? 1'b0 : ARVALID;
                                RREADY  <= (ARREADY) ? 1'b1 : RREADY;
                            end
                            
                // Read data phase: capture data and check RRESP
                R_DATA :    begin
                                if (RVALID) begin
                                    if (RRESP == 2'b00) begin
                                        read_data <= RDATA; // Successful read
                                        RD_ERR    <= 1'b0;
                                    end else begin
                                        read_data <= 32'd0; // Error case
                                        RD_ERR    <= 1'b1;
                                    end
                                end else begin
                                    read_data <= read_data;
                                    RD_ERR    <= RD_ERR;
                                end
                                
                                RREADY  <= (RVALID) ? 1'b0 : RREADY;
                                AWADDR  <= (RVALID) ? 32'h00000000 : AWADDR; // Target write addr
                                
                                // Prepare write data = read data (or 0 if error)
                                if (RVALID) begin
                                    if (RRESP == 2'b00) begin
                                        WDATA <= RDATA;
                                    end else begin
                                        WDATA <= 32'd0;
                                    end
                                end else begin
                                    WDATA <= WDATA;
                                end 
                                
                                AWVALID <= (RVALID) ? 1'b1 : AWVALID; // Issue write address
                                WVALID  <= (RVALID) ? 1'b1 : WVALID;  // Issue write data
                            end
                            
                // Write address phase: wait for AWREADY
                WR_ADDR :   begin
                                AWVALID <= (AWREADY) ? 1'b0 : AWVALID;
                                WVALID <= (WREADY) ? 1'b0 : WVALID;
                                BREADY <= (WREADY) ? 1'b1 : 1'b0;
                            end
                            
                // Write response phase: check BRESP
                W_RESP :    begin
                                if(BVALID) begin
                                    BREADY <= 1'b0; // Handshake complete
                                    WR_ERR <= (BRESP == 2'b00) ? 1'b0 : 1'b1; // Error check
                                end else begin
                                    BREADY <= 1'b1; // Always ready for BRESP
                                end 
                            end
                            
                // Default: hold values
                default :   begin
                                AWADDR   <= AWADDR;
                                AWVALID  <= AWVALID;
                                WDATA    <= WDATA;
                                WVALID   <= WVALID;
                                BREADY   <= BREADY;
                                ARADDR   <= ARADDR;
                                ARVALID  <= ARVALID;
                                RREADY   <= RREADY;
                                read_data <= read_data;
                                RD_ERR   <= RD_ERR;
                                WR_ERR   <= WR_ERR;
                            end
                            
            endcase        
        end
    end
    
    // Combinational FSM: next state logic
    always @ (*) begin
        case(cs) 
            IDLE    : ns = RD_ADDR;                        // Start with read
            RD_ADDR : ns = (ARREADY) ? R_DATA : RD_ADDR;   // Wait for ARREADY
            R_DATA  : ns = (RVALID) ? WR_ADDR : R_DATA;    // Wait for RVALID
            WR_ADDR : ns = (AWREADY && WREADY) ? W_RESP : WR_ADDR;   // Wait for AWREADY
            W_RESP  : ns = (BVALID) ? IDLE : W_RESP;       // Wait for BRESP
            default : ns = IDLE;
        endcase
    end
endmodule
