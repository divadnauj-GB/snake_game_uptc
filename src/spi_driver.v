module spi_driver(
    input clk_50,
    input reset_n,
    input slow_clk,
    input [15:0] dynamic_command,
    input spi_enable,
    input spi_start,
    output reg spi_finish,
    output MAX_DIN,
    output MAX_CLK,
    output MAX_CS
);

    reg din_reg = 0;
    reg clk_reg = 0;


    assign MAX_DIN = din_reg;
    assign MAX_CLK = clk_reg;
    assign MAX_CS  = spi_enable;

    reg [15:0] shift_reg = 0;
    reg [5:0] bit_count = 0;
    reg [2:0] state = 0;

    always @(posedge clk_50, negedge reset_n) begin
        if (!reset_n) begin
            state <= 0;
            shift_reg <= 0; 
            bit_count <= 16;
            clk_reg   <= 0;
            din_reg <= 0;
            spi_finish <= 0;
        end else begin
            if (slow_clk) begin
                case(state)
                    0: begin
                        if(spi_start) begin
                            shift_reg <= dynamic_command; 
                            bit_count <= 16;
                            clk_reg   <= 0;
                            state     <= 1;
                            spi_finish <= 0;
                        end else begin
                            state     <= 0;
                            clk_reg   <= 0;
                            bit_count <= 16;
                            spi_finish <= 0;
                        end
                    end
                    1: begin
                        din_reg <= shift_reg[15];
                        state   <= 2;
                    end
                    2: begin
                        state <= 3;
                    end
                    3: begin
                        clk_reg <= 1;
                        state   <= 4;
                    end
                    4: begin
                        clk_reg   <= 0;
                        shift_reg <= shift_reg << 1;
                        bit_count <= bit_count - 1;
                        if(bit_count == 1) state <= 5;
                        else               state <= 1;
                    end
                    5: begin
                        spi_finish <= 1;
                        if(spi_start) begin
                            state     <= 5;  
                        end else begin
                            state     <= 0; 
                        end
                    end
                    default: state <= 0;
                endcase
            end
        end
    end

endmodule
