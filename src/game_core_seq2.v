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
    output reg         game_over
);

    reg  [3:0]  matrix_row;    // Target row index to display (0 to 15)
    reg [3:0]  food_x;        // Current X position of target food
    reg [3:0]  food_y;        // Current Y position of target food
    // Direction Definitions (Breadcrumbs stored in the map)
    // Absolute Direction Codes (Used inside registers for Head & Tail state)
    localparam ABS_UP    = 2'b00;
    localparam ABS_DOWN  = 2'b01;
    localparam ABS_LEFT  = 2'b10;
    localparam ABS_RIGHT = 2'b11;

    // Relative Map Cell Encodings (Strict 3-state map)
    localparam CELL_EMPTY    = 2'b00;
    localparam MAP_TURN_RT   = 2'b01; // Relative Right Turn
    localparam MAP_TURN_LF   = 2'b10; // Relative Left Turn
    localparam MAP_STRAIGHT  = 2'b11; // Relative Straight Path

    localparam TR       = 2'b11; 
    localparam TL       = 2'b10;
    localparam BR       = 2'b01;
    localparam BL       = 2'b00;

    // FSM State Encodings
    localparam STATE_IDLE        = 3'b000;
    localparam STATE_MOVE_HEAD   = 3'b001;
    localparam STATE_MOVE_TAIL   = 3'b010;
    localparam STATE_RENDER_ROW  = 3'b011;
    localparam STATE_RENDER_TX   = 3'b100;
    localparam STATE_LOAD_MATRIX = 3'b101;
    localparam STATE_WAIT_CS_DEL = 3'b110;
    localparam STATE_RENDER_COLS = 3'b111;

    // --- Register Storage Structures ---
    // The 512-bit Map Array: 16 rows x 16 columns x 2 bits per cell
    // We treat 2'b00 as EMPTY if the head/tail pointers don't occupy it.
    reg [1:0] snake_map [0:15][0:15];
    
    reg [3:0] head_x, head_y;
    reg [1:0] head_dir;
    reg [1:0] tail_dir;
    reg [3:0] tail_x, tail_y;

    // State Machine and Render Registers
    reg [2:0]  state;
    reg [3:0]  r_row;
    reg [3:0]  r_col;
    reg [1:0]  quadrant;
    reg [15:0] row_accum;
    integer    i, j;

    wire [3:0] r_row_matrix = (quadrant[1]) ? r_row + 8: r_row;
    wire [15:0] m_data = (quadrant[0]) ? {4'd0,(r_row +4'd1),row_accum[7:0]}: {4'd0,(r_row +4'd1),row_accum[15:8]};

    // Head Look-Ahead Evaluation
    wire [3:0] next_head_x = (head_dir == ABS_LEFT)  ? head_x - 1'b1 : (head_dir == ABS_RIGHT) ? head_x + 1'b1 : head_x;
    wire [3:0] next_head_y = (head_dir == ABS_UP)    ? head_y - 1'b1 : (head_dir == ABS_DOWN)  ? head_y + 1'b1 : head_y;

    // Tail Look-Ahead Evaluation (Calculated based on current absolute tail direction)
    wire [3:0] next_tail_x = (tail_dir == ABS_LEFT)  ? tail_x - 1'b1 : (tail_dir == ABS_RIGHT) ? tail_x + 1'b1 : tail_x;
    wire [3:0] next_tail_y = (tail_dir == ABS_UP)    ? tail_y - 1'b1 : (tail_dir == ABS_DOWN)  ? tail_y + 1'b1 : tail_y;


    //// Look-Ahead registers for calculating next positions
    //wire [3:0] next_head_x = (head_dir == DIR_LEFT)  ? head_x - 1'b1 : (head_dir == DIR_RIGHT) ? head_x + 1'b1 : head_x;
    //wire [3:0] next_head_y = (head_dir == DIR_UP)    ? head_y - 1'b1 : (head_dir == DIR_DOWN)  ? head_y + 1'b1 : head_y;
//
    //// Tail tracking lookup from the current tail tile breadcrumb
    //wire [1:0] current_tail_crumb = snake_map[tail_y][tail_x];
    //wire [3:0] next_tail_x = (current_tail_crumb == DIR_LEFT)  ? tail_x - 1'b1 : (current_tail_crumb == DIR_RIGHT) ? tail_x + 1'b1 : tail_x;
    //wire [3:0] next_tail_y = (current_tail_crumb == DIR_UP)    ? tail_y - 1'b1 : (current_tail_crumb == DIR_DOWN)  ? tail_y + 1'b1 : tail_y;
//
    wire eating_food = (next_head_x == food_x) && (next_head_y == food_y);



    // --- ENCODER LOGIC (What code does the Head drop behind?) ---
    reg [1:0] relative_crumb;
    always @(*) begin
        if (user_dir == head_dir) begin
            relative_crumb = MAP_STRAIGHT;
        end else begin
            case (head_dir)
                ABS_UP:    relative_crumb = (user_dir == ABS_RIGHT) ? MAP_TURN_RT : MAP_TURN_LF;
                ABS_DOWN:  relative_crumb = (user_dir == ABS_LEFT)  ? MAP_TURN_RT : MAP_TURN_LF;
                ABS_LEFT:  relative_crumb = (user_dir == ABS_UP)    ? MAP_TURN_RT : MAP_TURN_LF;
                ABS_RIGHT: relative_crumb = (user_dir == ABS_DOWN)  ? MAP_TURN_RT : MAP_TURN_LF;
                default:   relative_crumb = MAP_STRAIGHT;
            endcase
        end
    end

    // --- DECODER LOGIC (How does the Tail interpret the breadcrumb it steps on?) ---
    reg [1:0] next_tail_dir;
    always @(*) begin
        case (snake_map[next_tail_y][next_tail_x])
            MAP_TURN_RT: begin // Adjust absolute tracking based on a right turn command
                case (tail_dir)
                    ABS_UP:    next_tail_dir = ABS_RIGHT;
                    ABS_DOWN:  next_tail_dir = ABS_LEFT;
                    ABS_LEFT:  next_tail_dir = ABS_UP;
                    ABS_RIGHT: next_tail_dir = ABS_DOWN;
                    default: next_tail_dir = ABS_RIGHT;
                endcase
            end
            MAP_TURN_LF: begin // Adjust absolute tracking based on a left turn command
                case (tail_dir)
                    ABS_UP:    next_tail_dir = ABS_LEFT;
                    ABS_DOWN:  next_tail_dir = ABS_RIGHT;
                    ABS_LEFT:  next_tail_dir = ABS_DOWN;
                    ABS_RIGHT: next_tail_dir = ABS_UP;
                    default: next_tail_dir = ABS_LEFT;
                endcase
            end
            default: next_tail_dir = tail_dir; // MAP_STRAIGHT or CELL_EMPTY keeps current heading
        endcase
    end

    reg [3:0] delay_counter;
    // --- MAIN CORE STATE MACHINE ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= STATE_IDLE;
            head_x       <= 4'd2;
            head_y       <= 4'd7;
            head_dir     <= ABS_RIGHT;
            tail_x       <= 4'd2;
            tail_y       <= 4'd7;
            tail_dir     <= ABS_RIGHT;
            game_over    <= 1'b0;
            matrix_valid <= 1'b0;
            matrix_row   <= 4'd0;
            matrix_data  <= 16'd0;
            r_row        <= 4'd0;
            r_col        <= 4'd0;
            quadrant  <= TL;
            row_accum    <= 16'd0;
            delay_counter <= 0;
            
            // Clear the 512-bit map memory explicitly on reset
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    snake_map[i][j] <= CELL_EMPTY;
                end
            end
            
        end else begin
            //matrix_valid <= 1'b0; // Default pulse management

            case (state)
                STATE_IDLE: begin
                    if (game_tick && !game_over) begin
                        // Enforce 180-degree blind-turn restriction safety locks
                        if ((user_dir == ABS_UP    && head_dir != ABS_DOWN)  ||
                            (user_dir == ABS_DOWN  && head_dir != ABS_UP)    ||
                            (user_dir == ABS_LEFT  && head_dir != ABS_RIGHT) ||
                            (user_dir == ABS_RIGHT && head_dir != ABS_LEFT)) begin
                            
                            // Drop the computed relative crumb BEFORE changing the head's absolute direction
                            snake_map[head_y][head_x] <= relative_crumb;
                            head_dir <= user_dir;
                        end else begin
                            // If no turn or invalid turn, the snake moves straight ahead
                            snake_map[head_y][head_x] <= MAP_STRAIGHT;
                        end
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
                    else if (snake_map[next_head_y][next_head_x] != CELL_EMPTY || 
                            (next_head_x == tail_x && next_head_y == tail_y)) begin
                        game_over <= 1'b1;
                        state     <= STATE_IDLE;
                    end 
                    else begin
                        // Apply calculated forward look-ahead coordinates to head registers
                        head_x <= next_head_x;
                        head_y <= next_head_y;
                        state  <= STATE_MOVE_TAIL;
                    end
                end

                STATE_MOVE_TAIL: begin
                    if (eating_food) begin
                        r_row <= 4'd0;
                        state <= STATE_RENDER_ROW;
                    end else begin
                        // Clear the cell the tail is currently leaving
                        snake_map[tail_y][tail_x] <= CELL_EMPTY;
                        
                        // Dynamically update the tail's absolute direction tracking based on the cell it's moving into
                        tail_dir <= next_tail_dir;
                        
                        // Advance tail registers
                        tail_x <= next_tail_x;
                        tail_y <= next_tail_y;
                        
                        r_row <= 4'd0;
                        state <= STATE_RENDER_ROW;
                    end
                end

                // --- STREAMING RENDER GENERATION ---
                // No internal loops or multipliers required. We build each row using an unrolled
                // check on the 16 parallel elements for the currently active row index.
                STATE_RENDER_ROW: begin
                        if (game_over) begin
                            row_accum <= 16'hFFFF;
                            state <= STATE_RENDER_TX;
                        end else begin
                            r_col <= 0;
                            //for (i = 0; i < 16; i = i + 1) begin
                            //    // A pixel is ON if it contains a breadcrumb, is the active head, or is the food location
                            //    /*if ((snake_map[r_row][i] != CELL_EMPTY) || 
                            //        (i == head_x && r_row == head_y)    || 
                            //        (i == tail_x && r_row == tail_y)    ||
                            //        (i == food_x && r_row == food_y)) begin*/
                            //    if ((snake_map[r_row_matrix][i] != CELL_EMPTY) ||
                            //        (i[3:0] == food_x && r_row_matrix == food_y)) begin
                            //        row_accum[i] <= 1'b1;
                            //    end else begin
                            //        row_accum[i] <= 1'b0;
                            //    end
                            //end
                            //state <= STATE_RENDER_COLS;
                            if(r_col==15) begin
                                r_col <= 0;
                                state <= STATE_RENDER_TX;
                            end else begin
                                r_col <= r_col + 1;
                                state <= STATE_RENDER_ROW;
                            end
                            if ((snake_map[r_row_matrix][r_col] != CELL_EMPTY) ||
                                (r_col == head_x && r_row_matrix == head_y)    || 
                                (r_col == tail_x && r_row_matrix == tail_y)    ||
                                (r_col == food_x && r_row_matrix == food_y)) begin
                                row_accum[r_col] <= 1'b1;
                            end else begin
                                row_accum[r_col] <= 1'b0;
                            end
                        end
                end

                STATE_RENDER_TX: begin
                    matrix_data  <= m_data;//row_accum;
                    if (matrix_ready) begin
                        matrix_data  <= m_data;//row_accum;
                        matrix_row   <= r_row;
                        if (r_row == 4'd8 && quadrant==TL) begin
                            state <= STATE_IDLE; // Completed full panel frame layout refresh
                            matrix_valid <= 1'b0;
                            
                        end else begin
                            if (quadrant==BR) begin
                                r_row <= r_row + 1'b1;
                                state <= STATE_WAIT_CS_DEL;
                            end else begin
                                state <= STATE_RENDER_ROW;
                            end
                            
                            matrix_valid <= 1'b1;
                            quadrant <= quadrant + 1;
                        end
                    end 
                end

                STATE_LOAD_MATRIX: begin
                    if (!matrix_ready) begin
                        matrix_valid <= 1'b1;
                        if (quadrant==BL) begin
                            r_row <= r_row + 1'b1;
                            delay_counter <= 0;
                            state <= STATE_WAIT_CS_DEL;
                        end if (quadrant==TL) begin
                            state <= STATE_RENDER_ROW;
                        end else begin
                            state <= STATE_RENDER_TX;
                        end
                        
                    end
                end

                STATE_WAIT_CS_DEL: begin
                    matrix_valid <= 1'b0;
                    if (matrix_ready) begin
                        if (delay_counter==15) begin
                            delay_counter <= 0;
                            state <= STATE_RENDER_ROW;
                        end else begin
                            delay_counter <= delay_counter +1 ;
                        end
                    end
                end

                default: state <= STATE_IDLE;
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
        food_x <= 7;
        food_y <= 7;
    end else begin
        if(eating_food) begin
            food_x <= rnd_counter[7:4];
            food_y <= rnd_counter[3:0];
        end 
    end
end


endmodule
