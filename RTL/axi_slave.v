module axi_slave #(parameter ADDR_WIDTH = 32, parameter DATA_WIDTH = 32) (
    input ACLK, ARSTn,
    
    // Write Address Channel Ports
    input [ADDR_WIDTH-1:0] AWADDR,   // Write address
    input AWVALID,                   // Write address valid
    output reg AWREADY,              // Write address ready
    
    // Write Data Channel Ports
    input [DATA_WIDTH-1:0] WDATA,    // Write data
    input [(DATA_WIDTH/8)-1:0] WSTRB,// Write strobes (byte enables)
    input WVALID,                    // Write data valid
    output reg WREADY,               // Write data ready 
    
    // Write Response Channel Ports
    input BREADY,                    // Master ready to accept response
    output reg [1:0] BRESP,          // Write response
    output reg BVALID,               // Write response valid
    
    // Read Address Channel Ports
    input [ADDR_WIDTH-1:0] ARADDR,   // Read address
    input ARVALID,                   // Read address valid
    output reg ARREADY,              // Read address ready
    
    // Read Data and Response Channel Ports
    input RREADY,                    // Master ready to accept read data
    output reg RVALID,               // Read data valid
    output reg [DATA_WIDTH-1:0] RDATA, // Read data
    output reg [1:0] RRESP,          // Read response
    
    // Peripheral (LED output)
    output wire [15:0] LED    
    );
    
    // Internal Registers for peripherals
    reg [31:0] LED_reg;              // LED register (memory-mapped)
    reg [31:0] UP_Count_reg;         // Up counter
    reg [31:0] DW_Count_reg;         // Down counter 
    
    // Flags to track whether address/data/response captured
    reg aw_captured;                 
    reg w_captured;
    reg ar_captured;
    
    // Latched address/data/strobes
    reg [ADDR_WIDTH-1:0] aw_addr;
    reg [ADDR_WIDTH-1:0] ar_addr;
    reg [DATA_WIDTH-1:0] w_data;
    reg [(DATA_WIDTH/8)-1:0] w_strb;
    
    //------------------------------------
    // Write Address Capture Logic
    //------------------------------------
    always @ (posedge ACLK or negedge ARSTn) begin
        if(!ARSTn) begin
            aw_captured <= 1'b0;
            aw_addr <= {ADDR_WIDTH{1'b0}};
            AWREADY <= 1'b0;
        end
        else begin
            if(!aw_captured && AWVALID) begin
                // Capture address when valid
                aw_captured <= 1'b1;
                aw_addr <= AWADDR;
                AWREADY <= 1'b1;
            end
            else begin
                AWREADY <= 1'b0;
                // Release once transaction done
                if(w_captured && aw_captured && !BVALID)
                    aw_captured <= 1'b0;
                else
                    aw_captured <= aw_captured;
            end
        end
    end

    //------------------------------------
    // Write Data Capture Logic
    //------------------------------------
    always @ (posedge ACLK or negedge ARSTn) begin
        if(!ARSTn) begin
            w_captured <= 1'b0;
            w_data <= {DATA_WIDTH{1'b0}};
            w_strb <= {DATA_WIDTH/8{1'b0}};
            WREADY <= 1'b0;
        end
        else begin
            if(!w_captured && WVALID) begin
                // Capture data + strobes
                w_captured <= 1'b1;
                w_data <= WDATA;
                w_strb <= WSTRB;
                WREADY <= 1'b1;
            end
            else begin
                WREADY <= 1'b0;   
                // Release once response issued
                if(w_captured && aw_captured && !BVALID)
                    w_captured <= 1'b0;
                else
                    w_captured <= w_captured;
            end
        end
    end
    
    //------------------------------------
    // Write Response + Peripheral Update
    //------------------------------------
    always @ (posedge ACLK or negedge ARSTn) begin
        if(!ARSTn) begin
            BRESP <= 2'b00;             // Default response = OKAY
            BVALID <= 1'b0;
            LED_reg <= 32'd0;
            UP_Count_reg <= 32'h00000000;
            DW_Count_reg <= 32'hFFFFFFFF;
        end
        else begin
            // Continuous counters
            UP_Count_reg <= UP_Count_reg + 32'd1; 
            DW_Count_reg <= DW_Count_reg - 32'd1;
             
            // Perform write operation when both addr & data captured
            if(w_captured && aw_captured && !BVALID) begin
                case(aw_addr[3:2])
                    2'b00 : begin
                        // Write to LED register with byte enables
                        LED_reg[7:0]   <= (w_strb[0]) ? w_data[7:0]   : LED_reg[7:0];
                        LED_reg[15:8]  <= (w_strb[1]) ? w_data[15:8]  : LED_reg[15:8];
                        LED_reg[23:16] <= (w_strb[2]) ? w_data[23:16] : LED_reg[23:16];
                        LED_reg[31:24] <= (w_strb[3]) ? w_data[31:24] : LED_reg[31:24];
                    end
                    2'b01 : begin
                        // Reset UP counter
                        UP_Count_reg <= 32'h00000000;
                    end
                    2'b10 : begin
                        // Reset DOWN counter
                        DW_Count_reg <= 32'hFFFFFFFF;
                    end
                    default : begin
                        // Do nothing
                    end
                endcase
                // Send write response
                BVALID <= 1'b1;
                BRESP <= 2'b00; // OKAY
            end
            else begin
                // Clear BVALID when master accepts response
                if(BVALID && BREADY)
                    BVALID <= 1'b0;
                else
                    BVALID <= BVALID;
            end
        end
    end
 
    //------------------------------------
    // Read Address Capture Logic
    //------------------------------------
    always @ (posedge ACLK or negedge ARSTn) begin
        if (!ARSTn) begin
            ARREADY <= 1'b0;
            ar_captured <= 1'b0;
            ar_addr <= {ADDR_WIDTH{1'b0}};
        end else begin
            if (!ar_captured && ARVALID) begin
                // Capture read address
                ARREADY <= 1'b1;              
                ar_addr <= ARADDR;
                ar_captured <= 1'b1;
            end
            else begin
                ARREADY <= 1'b0;
                // Release after read completes
                if(RVALID && RREADY)
                    ar_captured <= 1'b0;
                else
                    ar_captured <= ar_captured;
            end
        end
    end
    
    //------------------------------------
    // Read Data Channel
    //------------------------------------
    always @ (posedge ACLK or negedge ARSTn) begin
        if(!ARSTn) begin
            RDATA <= {DATA_WIDTH{1'b0}};
            RRESP <= 2'b00;
            RVALID <= 1'b0;
        end
        else begin
            if(ar_captured && !RVALID) begin
                // Return data based on address
                case(ar_addr[3:2])
                    2'b00 : RDATA <= LED_reg;
                    2'b01 : RDATA <= UP_Count_reg;
                    2'b10 : RDATA <= DW_Count_reg;
                    default : RDATA <= 32'h00000000;
                endcase
                RVALID <= 1'b1;
                RRESP <= 2'b00; // OKAY
            end
            else begin
                // Clear valid when master accepts data
                if(RVALID && RREADY)
                    RVALID <= 1'b0;
                else
                    RVALID <= RVALID;
            end
        end
    end
    
    // Peripheral LED output
    assign LED = LED_reg[15:0];
endmodule
