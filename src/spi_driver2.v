module spi_driver(
    input clk_50,
    input reset_n,
    input slow_clk,
    input [15:0] dynamic_command,
    input spi_enable,
    output reg spi_finish,
    output MAX_DIN,
    output MAX_CLK,
    output MAX_CS
);

    reg din_reg;
    reg clk_reg;

    reg cs;
    assign MAX_DIN = din_reg;
    assign MAX_CLK = clk_reg;
    assign MAX_CS  = cs;

    reg [15:0] shift_reg;
    reg [5:0] bit_count;
    reg [2:0] state;
    

    wire start = spi_enable;
    always @(posedge clk_50, negedge reset_n) begin
        if (!reset_n) begin
            state <= 0;
            shift_reg <= 0; 
            bit_count <= 16;
            clk_reg   <= 0;
            din_reg <= 0;
            spi_finish <= 0;
            cs <= 1'b1;
        end else begin
            case(state)
                0: begin
                    if(start) begin
                        shift_reg <= dynamic_command; 
                        bit_count <= 16;
                        clk_reg   <= 0;
                        state     <= 1;
                        spi_finish <= 0;
                        cs <= ~spi_enable;
                    end else begin
                        state     <= 0;
                        clk_reg   <= 0;
                        bit_count <= 16;
                        spi_finish <= 1;
                        cs <= ~spi_enable;
                    end
                end
                1: begin
                    if(slow_clk) begin
                        din_reg <= shift_reg[15];
                        state   <= 2;
                    end
                end
                2: begin
                    if(slow_clk) begin
                        state <= 3;
                    end
                end
                3: begin
                    if(slow_clk) begin
                        clk_reg <= 1;
                        state   <= 4;
                    end
                end
                4: begin
                    if(slow_clk) begin
                        clk_reg   <= 0;
                        shift_reg <= shift_reg << 1;
                        bit_count <= bit_count - 1;
                        if(bit_count == 1) state <= 5;
                        else               state <= 1;
                    end
                end
                5: begin
                    if(slow_clk) begin
                        spi_finish <= 1 ;
                        state      <= 0;
                    end
                end
                default: state <= 0;
            endcase
        end
    end

endmodule
