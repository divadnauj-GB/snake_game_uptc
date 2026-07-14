module game_core (
    input  wire        clk,           // Master system clock
    input  wire        rst_n,         // Active-low asynchronous reset
    input  wire        game_tick,     // Pulse signaling a game step (e.g., 5Hz)
    input  wire [1:0]  user_dir,      // User steering: 00=UP, 01=DOWN, 10=LEFT, 11=RIGHT
    
    // Interface to independent MAX7219 SPI driver block
    output reg  [15:0] matrix_data,   // 16-bit row vector to shift out
    output reg         matrix_valid,  // Pulsed high when a row is ready
    input  wire        matrix_ready,  // High if SPI transmitter is idle
    
    // Status flag
    output reg         game_over,
    output wire        set_timer,
    output wire [7:0]  score_out
);

    reg [3:0]  food_x;        // Current X position of target food
    reg [3:0]  food_y;        // Current Y position of target food
    // Direction Definitions (Breadcrumbs stored in the map)
    // Absolute Direction Codes (Used inside registers for Head & Tail state)
    localparam ABS_UP    = 2'b00;
    localparam ABS_DOWN  = 2'b01;
    localparam ABS_LEFT  = 2'b10;
    localparam ABS_RIGHT = 2'b11;

    localparam TR       = 2'b11; 
    localparam TL       = 2'b10;
    localparam BR       = 2'b01;
    localparam BL       = 2'b00;
    // FSM State Encodings
    localparam STATE_IDLE        = 4'b0000;
    localparam STATE_MOVE_HEAD   = 4'b0001;
    localparam STATE_MOVE_TAIL   = 4'b0010;
    localparam STATE_RENDER_ROW  = 4'b0011;
    localparam STATE_RENDER_TX   = 4'b0100;
    localparam STATE_LOAD_MATRIX = 4'b0101;
    localparam STATE_WAIT_CS_DEL = 4'b0110;
    localparam UPDATE_FIFO       = 4'b0111;
    localparam READ_FIFO         = 4'b1000;
    localparam STATE_INIT_MATRIX = 4'b1001;
    localparam STATE_RESET       = 4'b1010;

    reg [15:0] init_rom [0:4];


initial begin
    init_rom[0] = 16'h0900;
    init_rom[1] = 16'h0A02;
    init_rom[2] = 16'h0B07;
    init_rom[3] = 16'h0C01;
    init_rom[4] = 16'h0F00;
end
    // --- Register Storage Structures ---
    // The 512-bit Map Array: 16 rows x 16 columns x 2 bits per cell
    // We treat 2'b00 as EMPTY if the head/tail pointers don't occupy it.
    reg [7:0] snake [0:31];
    reg [4:0] head_ptr;
    reg [4:0] tail_ptr;
    reg [4:0] tail_ptr_bk;
    reg [4:0] read_ptr;
    wire [7:0] snake_rdat;
    reg wr_en;
    reg rd_en;
    reg last_was_read;
    reg [7:0] score;
    reg gen_food;

    wire full, empty;
    
    reg [3:0] head_x, head_y;
    reg [1:0] head_dir;
    reg [3:0] tail_x, tail_y;

    // State Machine and Render Registers
    reg [3:0]  state;
    reg [3:0]  r_row;
    reg [3:0]  r_col;
    reg [1:0]  quadrant;
    reg [15:0] row_accum;

    wire [3:0] r_row_matrix = (quadrant[1]) ? r_row + 4'd8: r_row;
    wire [15:0] m_data = (quadrant[0]) ? {4'd0,(r_row +4'd1),row_accum[7:0]}: {4'd0,(r_row +4'd1),row_accum[15:8]};

    // Head Look-Ahead Evaluation
    wire [3:0] next_head_x = (head_dir == ABS_LEFT)  ? head_x - 4'd1 : (head_dir == ABS_RIGHT) ? head_x + 4'd1 : head_x;
    wire [3:0] next_head_y = (head_dir == ABS_UP)    ? head_y - 4'd1 : (head_dir == ABS_DOWN)  ? head_y + 4'd1 : head_y;


    wire eating_food = (next_head_x == food_x) && (next_head_y == food_y);
    wire [15:0] rom_init_dat = init_rom[read_ptr[2:0]];
    integer i;
    // Write operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            head_ptr <= 5'd0;
            snake[0] <= 0;
        end else begin
            if (wr_en && !full) begin
                snake[head_ptr] <= {head_y,head_x};
                head_ptr <= head_ptr + 5'd1;
            end
        end
    end

    // Read operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tail_ptr <= 5'd0;
        end else begin
            if (rd_en && !empty) begin
                tail_ptr <= tail_ptr + 5'b1;
            end
        end
    end

    // Last operation tracker
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            last_was_read <= 1'b1; // Initialize as empty
        end else begin
            if (rd_en && !empty) begin
                last_was_read <= 1'b1;
            end else if (wr_en && !full) begin
                last_was_read <= 1'b0;
            end
            // else maintain current state
        end
    end

    assign full  = (head_ptr == tail_ptr) && !last_was_read;
    assign empty = (head_ptr == tail_ptr) &&  last_was_read;
    assign set_timer = eating_food&full;

    assign snake_rdat = snake[read_ptr];

    reg [3:0] delay_counter;
    // --- MAIN CORE STATE MACHINE ---


    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= STATE_RESET;
            head_x       <= 4'd2;
            head_y       <= 4'd7;
            head_dir     <= ABS_RIGHT;
            //tail_x       <= 4'd2;
            //tail_y       <= 4'd7;
            game_over    <= 1'b0;
            matrix_valid <= 1'b0;
            matrix_data  <= 16'd0;
            r_row        <= 4'd0;
            r_col        <= 4'd0;
            quadrant     <= TL;
            row_accum    <= 16'd0;
            delay_counter <= 0;
            rd_en       <= 0;
            wr_en       <= 0;
            read_ptr    <= 0;
            tail_ptr_bk <= 0;
            gen_food    <= 0;
        
            
        end else begin
            //matrix_valid <= 1'b0; // Default pulse management

            case (state)
                STATE_RESET: begin
                    if (matrix_ready) begin
                        matrix_data  <= rom_init_dat;//row_accum;
                        if (read_ptr==4'd5) begin
                            state <= STATE_IDLE;
                        end else begin
                            if (delay_counter==4'd4) begin
                                delay_counter <= 4'd0;
                                read_ptr <= read_ptr + 5'd1;
                                state <= STATE_INIT_MATRIX;
                            end else begin
                                delay_counter <= delay_counter + 4'd1;
                            end
                            
                        end
                        matrix_valid <= 0;
                    end
                end

                STATE_IDLE: begin
                    wr_en <= 0;
                    matrix_valid <= 0;
                    if ((head_dir!=user_dir) || (game_tick && !game_over)) begin
                        // Enforce 180-degree blind-turn restriction safety locks
                        if ((user_dir == ABS_UP    && head_dir != ABS_DOWN)  ||
                            (user_dir == ABS_DOWN  && head_dir != ABS_UP)    ||
                            (user_dir == ABS_LEFT  && head_dir != ABS_RIGHT) ||
                            (user_dir == ABS_RIGHT && head_dir != ABS_LEFT)) begin
                            // Drop the computed relative crumb BEFORE changing the head's absolute direction
                            head_dir <= user_dir;
                        end
                        //wr_en <= 1;
                        //head_dir <= user_dir;
                        read_ptr <= tail_ptr_bk;
                        state <= STATE_MOVE_HEAD;
                    end
                end

                STATE_MOVE_HEAD: begin
                    // 1. Boundary Wall Collision Check
                    if ((head_dir == ABS_UP    && head_y == 4'd0)  ||
                        (head_dir == ABS_DOWN  && head_y == 4'd15) ||
                        (head_dir == ABS_LEFT  && head_x == 4'd0)  ||
                        (head_dir == ABS_RIGHT && head_x == 4'd15)) begin
                        game_over <= 1'b1;
                        state     <= STATE_IDLE;
                    end 
                    // 2. Self-Collision Check via single-cycle lookups
                    else if (snake_rdat=={next_head_y,next_head_x}
                    //||   (next_head_x == tail_x && next_head_y == tail_y)
                    ) begin
                        game_over <= 1'b1;
                        state     <= STATE_IDLE;
                    end 
                    else if ((read_ptr!=(head_ptr-5'd1))&&(~empty)) begin
                        read_ptr <= read_ptr + 5'd1;
                        state     <= STATE_MOVE_HEAD;
                    end else begin
                        // Apply calculated forward look-ahead coordinates to head registers
                        read_ptr <= tail_ptr_bk;
                        if (!full) begin
                            wr_en <= 1;
                        end
                        state  <= UPDATE_FIFO;
                    end
                end

                UPDATE_FIFO: begin
                    wr_en <= 0;
                    read_ptr <= tail_ptr;
                    state  <= STATE_MOVE_TAIL;
                end

                STATE_MOVE_TAIL: begin
                    head_x <= next_head_x;
                    head_y <= next_head_y;
                    if (eating_food) begin
                        r_row <= 4'd0;
                        r_col <= 0;
                        rd_en <= 0;
                        gen_food <= 1;
                        read_ptr <= tail_ptr_bk;
                        state <= STATE_RENDER_ROW;
                    end else begin
                        // Clear the cell the tail is currently leaving
                        read_ptr <= tail_ptr_bk;
                        r_row <= 4'd0;
                        r_col <= 0;
                        gen_food <= 0;
                        if (!full) begin
                            rd_en <= 1;
                        end
                        //tail_x <= snake_rdat[3:0];
                        //tail_y <= snake_rdat[7:4];
                        r_row <= 4'd0;
                        state <= READ_FIFO;
                    end
                end

                READ_FIFO: begin
                    gen_food <= 0;
                    rd_en <= 0;
                    tail_ptr_bk <= tail_ptr;
                    read_ptr <= tail_ptr;
                    row_accum <= 0;
                    state <= STATE_RENDER_ROW;
                end

                STATE_RENDER_ROW: begin
                    gen_food <= 0;
                    rd_en <= 0;
                    wr_en <= 0;
                    if (game_over) begin
                        row_accum <= 16'hFFFF;
                        state <= STATE_RENDER_TX;
                    end else begin
                        if(r_col==15) begin
                            if (((read_ptr)!=(head_ptr-5'd1))&&(~empty)) begin
                                read_ptr <= read_ptr + 5'd1;
                                r_col <= 0;
                                state <= STATE_RENDER_ROW;
                            end else begin
                                r_col <= 0;
                                state <= STATE_RENDER_TX;
                            end
                        end else begin
                            r_col <= r_col + 4'd1;
                            state <= STATE_RENDER_ROW;
                        end
                        if ( (r_row_matrix==snake_rdat[7:4] && r_col==snake_rdat[3:0]) ||
                            (r_col == head_x && r_row_matrix == head_y)    || 
                            //(r_col == tail_x && r_row_matrix == tail_y)    ||
                            (r_col == food_x && r_row_matrix == food_y)) begin
                            row_accum[r_col] <= row_accum[r_col] | 1'b1;
                        end
                    end
                end
                STATE_RENDER_TX: begin
                    matrix_data  <= m_data;
                    if (matrix_ready) begin
                        matrix_data  <= m_data;//row_accum;
                        if (r_row == 4'd8 && quadrant==TL) begin
                            state <= STATE_IDLE; // Completed full panel frame layout refresh
                            matrix_valid <= 1'b0;
                            read_ptr <= tail_ptr_bk;
                        end else begin
                            if (quadrant==BR) begin
                                r_row <= r_row + 4'd1;
                                read_ptr <= tail_ptr_bk;
                                state <= STATE_WAIT_CS_DEL;
                            end else begin
                                row_accum <= 0;
                                state <= STATE_RENDER_ROW;
                                read_ptr <= tail_ptr_bk;
                                r_col <= 0;
                            end
                            
                            matrix_valid <= 1'b1;
                            quadrant <= quadrant + 2'd1;
                        end
                    end 
                end
                STATE_LOAD_MATRIX: begin
                    if (!matrix_ready) begin
                        matrix_valid <= 1'b1;
                        if (quadrant==BL) begin
                            r_row <= r_row + 4'd1;
                            delay_counter <= 0;
                            state <= STATE_WAIT_CS_DEL;
                        end if (quadrant==TL) begin
                            row_accum <= 0;
                            state <= STATE_RENDER_ROW;
                            read_ptr <= tail_ptr_bk;
                            r_col <= 0;
                        end else begin
                            state <= STATE_RENDER_TX;
                        end
                        
                    end
                end
                STATE_WAIT_CS_DEL: begin
                    matrix_valid <= 1'b0;
                    if (matrix_ready) begin
                        if (delay_counter==4'd4) begin
                            delay_counter <= 0;
                            row_accum <= 0;
                            state <= STATE_RENDER_ROW;
                            read_ptr <= tail_ptr_bk;
                            r_col <= 0;
                        end else begin
                            delay_counter <= delay_counter + 4'd1 ;
                        end
                    end
                end
                STATE_INIT_MATRIX: begin
                    if (matrix_ready) begin
                        matrix_valid <= 1;
                        if (delay_counter==4'd4) begin
                            delay_counter <= 0;
                            state <= STATE_RESET;
                        end else begin
                            delay_counter <= delay_counter + 4'd1;
                            state <= STATE_INIT_MATRIX;
                        end
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end
    

wire feedback;
reg [7:0] rnd_counter;

assign feedback = rnd_counter[7] ^ rnd_counter[5] ^ rnd_counter[4] ^ rnd_counter[3];
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rnd_counter <= 8'hFF; 
    end else begin
        rnd_counter <= {feedback, rnd_counter[7:1]};
    end
end



always @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
        food_x <= 3;
        food_y <= 7;
    end else begin
        if(gen_food) begin
            food_x <= rnd_counter[7:4];
            food_y <= rnd_counter[3:0];
        end 
    end
end

always @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        score <= 0;
    end else begin
        if (gen_food) begin
            if (score[3:0]<9) begin
                score[3:0] <= score[3:0] + 4'd1;
            end else begin
                score[3:0] <= 0;
                score[7:0] <= score[7:0] + 4'd1;
            end
        end
        
    end
end

assign score_out = score;


endmodule
