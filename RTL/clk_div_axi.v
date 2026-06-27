module clk_div_axi (
    input  wire clk,    // 100 MHz input clock
    input  wire rstn,     // Active-high reset
    output reg  clk_out    // 10 Hz output clock
);

    // 10,000,000 cycles needed → counter needs 24 bits (2^24 = 16,777,216 > 10,000,000)
    reg [23:0] counter;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            counter <= 24'd0;
            clk_out <= 1'b0;
        end else begin
            if (counter == 24'd4_999_999) begin
                counter <= 24'd0;
                clk_out <= ~clk_out;   // toggle output
            end else begin
                counter <= counter + 1'b1;
            end
        end
    end
endmodule