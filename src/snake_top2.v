module snake_top(
    input         CLOCK_50,  // Reloj de 50 MHz
    
    input  [3:0]  KEY,       // KEY3=Arriba, KEY2=Abajo, KEY1=Derecha, KEY0=Izquierda
    input  [0:0]  SW,        // SW[0] = RESET general del juego
    
    output        MAX_DIN,   // Salida de datos SPI
    output        MAX_CLK,   // Reloj SPI
    output        MAX_CS,    // Latch/Chip Select SPI
     
    output [3:0]  HEX0,      // Display 7 Segmentos: Unidades
    output [3:0]  HEX1       // Display 7 Segmentos: Decenas
);

    wire clean_key3;
    wire clean_key2;
    wire clean_key1;
    wire clean_key0;

    reg [4:0] div_counter;
    reg slow_clk;

    debounce buttUp (
        .clk(CLOCK_50),
        .rst_n(SW[0]),
        .input_signal(KEY[3]),
        .clean_signal(clean_key3)
    );
    
    debounce buttDwn (
        .clk(CLOCK_50),
        .rst_n(SW),
        .input_signal(KEY[2]),
        .clean_signal(clean_key2)
    );

    debounce buttR (
        .clk(CLOCK_50),
        .rst_n(SW[0]),
        .input_signal(KEY[1]),
        .clean_signal(clean_key1)
    );

    debounce buttL (
        .clk(CLOCK_50),
        .rst_n(SW[0]),
        .input_signal(KEY[0]),
        .clean_signal(clean_key0)
    );

    
    // =======================================================
    // --- DIVISOR DE RELOJ PARA EL SPI ---
    // =======================================================
    

    always @(posedge CLOCK_50, negedge SW[0]) begin
        if(!SW[0]) begin
            div_counter <= 0;
            slow_clk <= 0;
        end else if(div_counter == 5'd19) begin
            div_counter <= 0;
            slow_clk <= 1;
        end
        else begin
            div_counter <= div_counter + 1'b1;
            slow_clk <= 0;
        end
    end


    

    // =======================================================
    // --- REGISTRO Y CONTROL DE DIRECCIÓN SEGURO ---
    // =======================================================
    reg [1:0] dir;
    
    // Usamos lógica síncrona usando el reloj y el SW0 limpio
    /*
    always @(posedge CLOCK_50, negedge SW[0]) begin
        if (!SW[0]) begin
            dir <= 2'b00; // Al resetear, la serpiente apunta a la derecha
        end else begin
            // Derecha (No permite cambiar si vas a la Izquierda)
            if (!clean_key1 && (dir != 2'b01))      dir <= 2'b00; 
            // Izquierda (No permite cambiar si vas a la Derecha)
            else if (!clean_key0 && (dir != 2'b00)) dir <= 2'b01; 
            // Arriba (No permite cambiar si vas Abajo)
            else if (!clean_key3 && (dir != 2'b11)) dir <= 2'b10; 
            // Abajo (No permite cambiar si vas Arriba)
            else if (!clean_key2 && (dir != 2'b10)) dir <= 2'b11;
        end
    end
    */

    always @(posedge CLOCK_50, negedge SW[0]) begin
        if (!SW[0]) begin
            dir <= 2'b00; // Al resetear, la serpiente apunta a la derecha
        end else begin
            // Derecha (No permite cambiar si vas a la Izquierda)
            if (!clean_key1)      dir <= 2'b00; 
            // Izquierda (No permite cambiar si vas a la Derecha)
            else if (!clean_key0 ) dir <= 2'b01; 
            // Arriba (No permite cambiar si vas Abajo)
            else if (!clean_key3) dir <= 2'b10; 
            // Abajo (No permite cambiar si vas Arriba)
            else if (!clean_key2) dir <= 2'b11;
        end
    end

    wire [15:0] current_command;
    wire game_over_signal;
    wire [4:0] current_score;
    wire spi_enable, spi_start, spi_finish;
    // =======================================================
    // --- INSTANCIACIÓN DE MÓDULOS ---
    // =======================================================
    game_core juego (
        .clk_50(CLOCK_50),
        .reset_n(SW[0]), // Conectado al Switch 0 limpio
        .slow_clk(slow_clk),
        .dir(dir),
        .spi_finish(spi_finish),
        .spi_start(spi_start),
        .spi_enable(spi_enable),
        .game_over(game_over_signal),
        .snake_len(current_score),
        .dynamic_command(current_command)
    );

    spi_driver pantalla (
        .clk_50(CLOCK_50),
        .reset_n(SW[0]),
        .slow_clk(slow_clk),
        .dynamic_command(current_command),
        .spi_enable(spi_enable),
        .spi_start(spi_start),
        .spi_finish(spi_finish),
        .MAX_DIN(MAX_DIN),
        .MAX_CLK(MAX_CLK),
        .MAX_CS(MAX_CS)
    );
     
     
    assign HEX0=0;
    assign HEX1=0;

endmodule