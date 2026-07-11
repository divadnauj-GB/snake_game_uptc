module game_core(
    input clk_50,
    input slow_clk,
    input reset_n,
    input [1:0] dir,
    input  spi_finish,
    output reg spi_start,
    output reg spi_enable,
    output wire game_over,
    output wire [4:0] snake_len, 
    output reg [15:0] dynamic_command
);

localparam RESET        = 5'b00000;
localparam WAIT_TRIGGER = 5'b00001;
localparam UPDATE_HEAD  = 5'b00010;
localparam CHECK_EDGES  = 5'b00011;
localparam CHECK_BODY   = 5'b00100;
localparam EAT_FOOD     = 5'b00101;
localparam EAT_VENOM    = 5'b00110;
localparam NEW_FOOD     = 5'b00111;
localparam NEW_VENOM    = 5'b01000;
localparam SHOW_GAME    =  5'b01001;
localparam UPDATE_TAIL  = 5'b01010;
localparam GAME_OVER    = 5'b01011;
localparam CHECK_NEW_FOOD    = 5'b01100;
localparam CHECK_NEW_VENOM   = 5'b01101;
localparam SHORT_SNAKE       = 5'b01110;
localparam SHORT_SNAKE_U       = 5'b01111;
localparam SHORT_SNAKE_D       = 5'b10000;
localparam SHORT_SNAKE_L       = 5'b10001;
localparam SHORT_SNAKE_R       = 5'b10010;
localparam UPDATE_TAIL_U    = 5'b10011;
localparam UPDATE_TAIL_D    = 5'b10100;
localparam UPDATE_TAIL_L    = 5'b10101;
localparam UPDATE_TAIL_R    = 5'b10110;

wire feedback;
reg new_food, new_venom, update_head, update_tail, edge_collide, show_finished;
reg [3:0] show_state;
reg display_game;
reg [3:0] counter;

reg [4:0] curr_state, next_state;
reg [19:0] timer_count;

reg [1:0] h_dir;
reg [3:0] h_x;
reg [3:0] h_y;

reg [1:0] t_dir;
reg [3:0] t_x;
reg [3:0] t_y;

reg [3:0] f_x;
reg [3:0] f_y;

reg [3:0] v_x;
reg [3:0] v_y;

reg [3:0] gp_x;
reg [3:0] gp_y;

reg [7:0] rnd_counter;

reg [15:0] mem [0:15] ;
reg mem_rdata;
reg [15:0] mem_rdata_w;
reg mem_wdata;
reg mem_wr;
reg [7:0] mem_addr;
reg [7:0] mem_addr_reg;
reg [2:0] mem_sel_addr;

reg timer_flag;
reg [1:0] prev_dir;

/*FSM*/
always @(posedge clk_50, negedge reset_n) begin
    if(!reset_n) begin
        curr_state <= RESET;
    end else begin
        curr_state <= next_state;
    end
end

always @(*) begin
    case (curr_state)
        RESET: begin
            next_state = NEW_FOOD;
        end
        WAIT_TRIGGER: begin
            if (timer_flag|| (h_dir!=dir) ) begin
                next_state = UPDATE_HEAD;
            end else begin
                next_state = WAIT_TRIGGER;
            end
        end
        UPDATE_HEAD: begin
            next_state = CHECK_EDGES;
        end
        CHECK_EDGES: begin
            if (edge_collide) begin
                next_state = GAME_OVER;
            end else begin
                next_state = CHECK_BODY;
            end
        end
        CHECK_BODY: begin
            if ((h_x[3:0]==f_x && h_y[3:0]==f_y)) begin
                next_state = EAT_FOOD;
            end else if (h_x[3:0]==v_x && h_y[3:0]==v_y) begin
                next_state = EAT_VENOM;
            end else begin
                if (mem_rdata && (mem_addr[7:4]!=f_y && mem_addr[3:0]!=f_x && mem_addr[7:4]!=v_y && mem_addr[3:0]!=v_x)) begin
                    next_state = GAME_OVER;
                end else begin
                    next_state = UPDATE_TAIL;
                end
            end
        end
        EAT_FOOD: begin
            if ((h_x[3:0]==f_x && h_y[3:0]==f_y)) begin
                next_state = NEW_FOOD;
            end else begin
                next_state = EAT_VENOM;
            end
        end
        EAT_VENOM: begin
            if ((h_x[3:0]==v_x && h_y[3:0]==v_y)) begin
                next_state = NEW_VENOM;
            end else begin
                next_state = UPDATE_TAIL;
            end
        end
        NEW_FOOD: begin
            next_state = CHECK_NEW_FOOD;
        end
        CHECK_NEW_FOOD: begin
            if (mem_rdata || (v_x==f_x && v_y==f_y)) begin
                next_state = NEW_FOOD;
            end else begin
                next_state = SHOW_GAME;
            end
        end
        NEW_VENOM: begin
            next_state = CHECK_NEW_VENOM;
        end
        CHECK_NEW_VENOM: begin
            if (mem_rdata || (v_x==f_x && v_y==f_y)) begin
                next_state = NEW_VENOM;
            end else begin
                next_state = SHORT_SNAKE;
            end
        end
        SHORT_SNAKE: begin
            if ((t_x==h_x && t_y==h_y)) begin
                next_state = GAME_OVER;
            end else begin
                next_state = SHORT_SNAKE_U;
                
            end
        end
        SHORT_SNAKE_U: begin
            if (mem_rdata && (~(t_x==f_x && t_y==f_y) && ~(t_x==v_x && t_y==v_y))) begin
                next_state = UPDATE_TAIL;
            end else begin
                next_state = SHORT_SNAKE_D;
            end
        end
        SHORT_SNAKE_D: begin
            if (mem_rdata && (~(t_x==f_x && t_y==f_y) && ~(t_x==v_x && t_y==v_y))) begin
                next_state = UPDATE_TAIL;
            end else begin
                next_state = SHORT_SNAKE_L;
            end
        end
        SHORT_SNAKE_L: begin
            if (mem_rdata && (~(t_x==f_x && t_y==f_y) && ~(t_x==v_x && t_y==v_y))) begin
                next_state = UPDATE_TAIL;
            end else begin
                next_state = SHORT_SNAKE_R;
            end
        end
        SHORT_SNAKE_R: begin
            if (mem_rdata && (~(t_x==f_x && t_y==f_y) && ~(t_x==v_x && t_y==v_y))) begin
                next_state = UPDATE_TAIL;
            end else begin
                next_state = UPDATE_TAIL;
            end
        end
        UPDATE_TAIL: begin
            next_state = UPDATE_TAIL_U;
        end
        UPDATE_TAIL_U: begin
            if (mem_rdata && (~(t_x==f_x && t_y==f_y) && ~(t_x==v_x && t_y==v_y))) begin
                next_state = SHOW_GAME;
            end else begin
                next_state = UPDATE_TAIL_D;
            end
        end
        UPDATE_TAIL_D: begin
            if (mem_rdata && (~(t_x==f_x && t_y==f_y) && ~(t_x==v_x && t_y==v_y))) begin
                next_state = SHOW_GAME;
            end else begin
                next_state = UPDATE_TAIL_L;
            end
        end
        UPDATE_TAIL_L: begin
            if (mem_rdata && (~(t_x==f_x && t_y==f_y) && ~(t_x==v_x && t_y==v_y))) begin
                next_state = SHOW_GAME;
            end else begin
                next_state = UPDATE_TAIL_R;
            end
        end
        UPDATE_TAIL_R: begin
            if (mem_rdata && (~(t_x==f_x && t_y==f_y) && ~(t_x==v_x && t_y==v_y))) begin
                next_state = SHOW_GAME;
            end else begin
                next_state = SHOW_GAME;
            end
        end
        SHOW_GAME: begin
            if (show_finished) begin
                next_state = WAIT_TRIGGER;
            end else begin
                next_state = SHOW_GAME;
            end
        end
        GAME_OVER: begin
            next_state = GAME_OVER;
            //$finish;
        end
        default: 
            next_state = RESET;
    endcase
end


always @(*) begin
    case (curr_state)
        RESET: begin
            new_venom = 0;
            new_food = 0;
            mem_sel_addr = 3'b011;
            display_game = 1'b0;
            
            update_head = 1'b0;
            update_tail = 1'b0;
            mem_wr       = 1'b1;
            mem_wdata    = 1'b1;
            gp_x         = 0 ;
            gp_y         = 0 ;
        end
        WAIT_TRIGGER: begin
            new_venom = 0;
            new_food = 0;
            mem_sel_addr = 3'b000;
            display_game = 1'b0;
            
            update_head = 1'b0;
            update_tail = 1'b0;
            mem_wr       = 1'b0;
            mem_wdata    = 1'b0;
            gp_x         = 0 ;
            gp_y         = 0 ;
        end
        UPDATE_HEAD: begin
            new_venom = 0;
            new_food = 0;
            mem_sel_addr = 3'b000;
            display_game = 1'b0;
            
            update_head = 1'b1;
            update_tail = 1'b0;
            mem_wr       = 1'b0;
            mem_wdata    = 1'b0;
            gp_x         = 0 ;
            gp_y         = 0 ;
        end
        CHECK_EDGES: begin
            new_venom = 0;
            new_food = 0;
            mem_sel_addr = 3'b000;
            display_game = 1'b0;
            
            update_head = 1'b0;
            update_tail = 1'b0;
            mem_wr       = 1'b0;
            mem_wdata    = 1'b0;
            gp_x         = 0 ;
            gp_y         = 0 ;
        end

        CHECK_BODY: begin
            if ((h_x[3:0]==f_x && h_y[3:0]==f_y)) begin
                new_venom = 0;
                new_food = 0;
                mem_sel_addr = 3'b000;
                display_game = 1'b0;
                
                update_head = 1'b0;
                update_tail = 1'b0;
                mem_wr       = 1'b1;
                mem_wdata    = 1'b1;
                gp_x         = 0 ;
                gp_y         = 0 ;
            end else if (h_x[3:0]==v_x && h_y[3:0]!=v_y) begin
                new_venom = 0;
                new_food = 0;
                mem_sel_addr = 3'b000;
                display_game = 1'b0;
                
                update_head = 1'b0;
                update_tail = 1'b0;
                mem_wr       = 1'b1;
                mem_wdata    = 1'b1;
                gp_x         = 0 ;
                gp_y         = 0 ;
            end else begin
                if (mem_rdata && (mem_addr[7:4]!=f_y && mem_addr[3:0]!=f_x && mem_addr[7:4]!=v_y && mem_addr[3:0]!=v_x)) begin
                    new_venom = 0;
                    new_food = 0;
                    mem_sel_addr = 3'b000;
                    display_game = 1'b0;
                    
                    update_head = 1'b0;
                    update_tail = 1'b0;
                    mem_wr       = 1'b0;
                    mem_wdata    = 1'b0;
                    gp_x         = 0 ;
                    gp_y         = 0 ;
                end else begin
                    new_venom = 0;
                    new_food = 0;
                    mem_sel_addr = 3'b000;
                    display_game = 1'b0;
                    
                    update_head = 1'b0;
                    update_tail = 1'b0;
                    mem_wr       = 1'b1;
                    mem_wdata    = 1'b1;
                    gp_x         = 0 ;
                    gp_y         = 0 ;
                end
                
            end
        end
        EAT_FOOD: begin
            new_venom = 0;
            new_food = 0;
            mem_sel_addr = 3'b000;
            display_game = 1'b0;
            
            update_head = 1'b0;
            update_tail = 1'b0;
            mem_wr       = 1'b0;
            mem_wdata    = 1'b0;
            gp_x         = 0 ;
            gp_y         = 0 ;
        end
        EAT_VENOM: begin
            new_venom = 0;
            new_food = 0;
            mem_sel_addr = 3'b000;
            display_game = 1'b0;
            
            update_head = 1'b0;
            update_tail = 1'b0;
            mem_wr       = 1'b0;
            mem_wdata    = 1'b0;
            gp_x         = 0 ;
            gp_y         = 0 ;
        end
        NEW_FOOD: begin
            new_venom = 0;
            new_food = 1;
            mem_sel_addr = 3'b010;
            display_game = 1'b0;
            
            update_head = 1'b0;
            update_tail = 1'b0;
            mem_wr       = 1'b0;
            mem_wdata    = 1'b0;
            gp_x         = 0 ;
            gp_y         = 0 ;
        end
        CHECK_NEW_FOOD: begin
            if (mem_rdata || (v_x==f_x && v_y==f_y)) begin
                new_venom     = 0;
                new_food      = 0;
                mem_sel_addr  = 3'b010;
                display_game   = 1'b0;
                
                update_head   = 1'b0;
                update_tail   = 1'b0;
                mem_wr        = 1'b0;
                mem_wdata     = 1'b0;
                gp_x          = 0 ;
                gp_y          = 0 ;
            end else begin
                new_venom     = 0;
                new_food      = 0;
                mem_sel_addr  = 3'b010;
                display_game   = 1'b0;
                
                update_head   = 1'b0;
                update_tail   = 1'b0;
                mem_wr        = 1'b1;
                mem_wdata     = 1'b1;
                gp_x          = 0 ;
                gp_y          = 0 ;
            end
            
        end
        NEW_VENOM: begin
            new_food = 0;
            new_venom = 1;
            mem_sel_addr = 3'b011;
            display_game = 1'b0;
            update_head = 1'b0;
            update_tail = 1'b0;
            mem_wr       = 1'b0;
            mem_wdata    = 1'b0;
            gp_x         = 0 ;
            gp_y         = 0 ;
        end
        CHECK_NEW_VENOM: begin
            new_food = 0;
            new_venom = 0;
            mem_sel_addr = 3'b011;
            display_game = 1'b0;
            update_head = 1'b0;
            update_tail = 1'b0;
            mem_wr       = 1'b0;
            mem_wdata    = 1'b0;
            gp_x         = 0 ;
            gp_y         = 0 ;
        end
        SHORT_SNAKE: begin
            new_food     = 0;
            new_venom    = 0;
            mem_sel_addr = 3'b001;
            display_game  = 1'b0;
            update_head = 1'b0;
            update_tail = 1'b0;
            mem_wr       = 1'b1;
            mem_wdata    = 1'b0;
            gp_x         = 0 ;
            gp_y         = 0 ;
        end
        SHORT_SNAKE_U: begin
            new_food     = 0;
            new_venom    = 0;
            mem_sel_addr = 3'b101;
            display_game  = 1'b0;
            update_head = 1'b0;
            mem_wr       = 1'b0;
            mem_wdata    = 1'b0;
            gp_x         = t_x + 1;
            gp_y         = t_y;
            if (mem_rdata && (~(t_x==f_x && t_y==f_y) && ~(t_x==v_x && t_y==v_y))) begin
                update_tail = 1'b1;
            end else begin
                update_tail = 1'b0;
            end
        end
        SHORT_SNAKE_D: begin
            new_food     = 0;
            new_venom    = 0;
            mem_sel_addr = 3'b101;
            display_game  = 1'b0;
            
            update_head = 1'b0;
            mem_wr       = 1'b0;
            mem_wdata    = 1'b0;
            gp_x         = t_x - 1;
            gp_y         = t_y;
            if (mem_rdata && (~(t_x==f_x && t_y==f_y) && ~(t_x==v_x && t_y==v_y))) begin
                update_tail = 1'b1;
            end else begin
                update_tail = 1'b0;
            end
        end
        SHORT_SNAKE_L: begin
            new_food     = 0;
            new_venom    = 0;
            mem_sel_addr = 3'b101;
            display_game  = 1'b0;
            update_head = 1'b0;
            mem_wr       = 1'b0;
            mem_wdata    = 1'b0;
            gp_x         = t_x;
            gp_y         = t_y+1;
            if (mem_rdata && (~(t_x==f_x && t_y==f_y) && ~(t_x==v_x && t_y==v_y))) begin
                update_tail = 1'b1;
            end else begin
                update_tail = 1'b0;
            end
        end
        SHORT_SNAKE_R: begin
            new_food     = 0;
            new_venom    = 0;
            mem_sel_addr = 3'b101;
            display_game  = 1'b0;
            update_head = 1'b0;
            mem_wr       = 1'b0;
            mem_wdata    = 1'b0;
            gp_x         = t_x ;
            gp_y         = t_y - 1;
            if (mem_rdata && (~(t_x==f_x && t_y==f_y) && ~(t_x==v_x && t_y==v_y))) begin
                update_tail = 1'b1;
            end else begin
                update_tail = 1'b0;
            end
        end
        UPDATE_TAIL: begin
            new_food     = 0;
            new_venom    = 0;
            mem_sel_addr = 3'b001;
            display_game  = 1'b0;
            update_head = 1'b0;
            update_tail = 1'b0;
            mem_wr       = 1'b1;
            mem_wdata    = 1'b0;
            gp_x         = 0 ;
            gp_y         = 0 ;
        end
        UPDATE_TAIL_U: begin
            new_food     = 0;
            new_venom    = 0;
            mem_sel_addr = 3'b101;
            display_game  = 1'b0;
            update_head = 1'b0;
            mem_wr       = 1'b0;
            mem_wdata    = 1'b0;
            gp_x         = t_x + 1 ;
            gp_y         = t_y ;
            if (mem_rdata && (~(t_x==f_x && t_y==f_y) && ~(t_x==v_x && t_y==v_y))) begin
                update_tail = 1'b1;
            end else begin
                update_tail = 1'b0;
            end
        end
        UPDATE_TAIL_D: begin
            new_food     = 0;
            new_venom    = 0;
            mem_sel_addr = 3'b101;
            display_game  = 1'b0;
            
            update_head = 1'b0;
            mem_wr       = 1'b0;
            mem_wdata    = 1'b0;
            gp_x         = t_x - 1 ;
            gp_y         = t_y ;
            if (mem_rdata && (~(t_x==f_x && t_y==f_y) && ~(t_x==v_x && t_y==v_y))) begin
                update_tail = 1'b1;
            end else begin
                update_tail = 1'b0;
            end
        end
        UPDATE_TAIL_L: begin
            new_food     = 0;
            new_venom    = 0;
            mem_sel_addr = 3'b101;
            display_game  = 1'b0;
            
            update_head = 1'b0;
            mem_wr       = 1'b0;
            mem_wdata    = 1'b0;
            gp_x         = t_x  ;
            gp_y         = t_y + 1 ;
            if (mem_rdata && (~(t_x==f_x && t_y==f_y) && ~(t_x==v_x && t_y==v_y))) begin
                update_tail = 1'b1;
            end else begin
                update_tail = 1'b0;
            end
        end
        UPDATE_TAIL_R: begin
            new_food     = 0;
            new_venom    = 0;
            mem_sel_addr = 3'b101;
            display_game  = 1'b0;
            
            update_head = 1'b0;
            mem_wr       = 1'b0;
            mem_wdata    = 1'b0;
            gp_x         = t_x ;
            gp_y         = t_y - 1;
            if (mem_rdata && (~(t_x==f_x && t_y==f_y) && ~(t_x==v_x && t_y==v_y))) begin
                update_tail = 1'b1;
            end else begin
                update_tail = 1'b0;
            end
        end

        SHOW_GAME: begin
            new_food     = 0;
            new_venom    = 0;
            mem_sel_addr = 3'b100;
            display_game  = 1'b1;
            
            update_head = 1'b0;
            update_tail = 1'b0;
            mem_wr       = 1'b0;
            mem_wdata    = 1'b0;
            gp_x         = 0 ;
            gp_y         = 0 ;
        end

        GAME_OVER: begin
            new_food     = 0;
            new_venom    = 0;
            mem_sel_addr = 3'b101;
            display_game  = 1'b0;
            
            update_head = 1'b0;
            update_tail = 1'b0;
            mem_wr       = 1'b0;
            mem_wdata    = 1'b0;
            gp_x         = 0 ;
            gp_y         = 0 ;
        end
        default: begin
            new_food     = 0;
            new_venom    = 0;
            mem_sel_addr = 3'b101;
            display_game  = 1'b0;
            update_head = 1'b0;
            update_tail = 1'b0;
            mem_wr       = 1'b0;
            mem_wdata    = 1'b0;
            gp_x         = 0 ;
            gp_y         = 0 ;
        end
    endcase
end


always @(*) begin
    case (mem_sel_addr)
        3'b000: mem_addr = {h_y[3:0],h_x[3:0]};
        3'b001: mem_addr = {t_y,t_x};
        3'b010: mem_addr = {f_y,f_x};
        3'b011: mem_addr = {v_y,v_x};
        3'b100: mem_addr = mem_addr_reg;
        3'b101: mem_addr = {gp_y,gp_x};
        default: 
            mem_addr = {h_y[3:0],h_x[3:0]};
    endcase
end

integer i;
always @(posedge clk_50, negedge reset_n) begin
    if(!reset_n) begin
        for (i=0;i<16;i=i+1) begin
            mem[i] <= 0;
        end
    end else begin
        if (mem_wr) begin
            mem[mem_addr[7:4]][mem_addr[3:0]] <= mem_wdata; 
        end
    end
end

always @(*) begin
    mem_rdata_w = mem[mem_addr[7:4]];
    mem_rdata = mem_rdata_w[mem_addr[3:0]];
end


assign feedback = rnd_counter[7] ^ rnd_counter[5] ^ rnd_counter[4] ^ rnd_counter[3];
always @(posedge clk_50 or negedge reset_n) begin
    if (!reset_n) begin
        rnd_counter <= 8'hFF; 
    end else begin
        rnd_counter <= {feedback, rnd_counter[7:1]};
    end
end


always @(posedge clk_50, negedge reset_n) begin
    if (!reset_n) begin
        f_x <= 0;
        f_y <= 0;
    end else begin
        if(new_food) begin
            f_x <= rnd_counter[7:4];
            f_y <= rnd_counter[3:0];
        end 
    end
end

always @(posedge clk_50, negedge reset_n) begin
    if (!reset_n) begin
        v_x <= 7;
        v_y <= 7;
    end else begin
        if(new_venom) begin
            v_x <= rnd_counter[3:0];
            v_y <= rnd_counter[7:4];
        end 
    end
end



always @(posedge clk_50, negedge reset_n) begin
    if (!reset_n) begin
        h_x <= 0;
        h_y <= 0;
        h_dir <= 0;
        edge_collide <= 0;
    end else begin
        h_dir <= dir;
        if(update_head) begin
            case (h_dir)
                2'b00: begin
                    if(h_x==15) begin
                        edge_collide <= 1'b1;
                    end else begin
                        h_x <= h_x+1;
                    end
                end
                2'b10: begin
                    if(h_y==15) begin
                        edge_collide <= 1'b1;
                    end else begin
                        h_y <= h_y+1;
                    end
                end
                2'b01: begin
                    if(h_x==0) begin
                        edge_collide <= 1'b1;
                    end else begin
                        h_x <= h_x-1;
                    end
                end
                2'b11: begin
                    if(h_y==0) begin
                        edge_collide <= 1'b1;
                    end else begin
                        h_y <= h_y-1;
                    end
                end
                default: begin
                    h_x <= 0;
                    h_y <= 0;
                    edge_collide <= 0;
                end
            endcase
        end 
    end
end

/*
always @(posedge clk_50, negedge reset_n) begin
    if (!reset_n) begin
        mem_addr_reg <= 0;
    end else begin
        if (inc_address) begin
            mem_addr_reg <= mem_addr_reg + 1;
        end
        if (rst_address) begin
             mem_addr_reg <= 0 ;
        end
    end
end
*/

reg [15:0] init_rom [0:4];
reg [2:0] idx;
initial begin
    init_rom[0] = 16'h0900;
    init_rom[1] = 16'h0A02;
    init_rom[2] = 16'h0B07;
    init_rom[3] = 16'h0C01;
    init_rom[4] = 16'h0F00;
end


always @(posedge clk_50, negedge reset_n) begin
    if (!reset_n) begin
        counter <= 0;
        mem_addr_reg <= 0;
        show_state <= 0;
        show_finished <= 1;
        dynamic_command <= 0;
        spi_enable <= 1;
        spi_start       <= 0;
        idx             <= 0;
    end else begin
        case (show_state)
            0: begin
                spi_enable      <= 0;
                dynamic_command <= init_rom[idx];
                if (spi_finish) begin
                    spi_start       <= 0;
                    show_state      <= 11 ;
                end else begin
                    spi_start       <= 1;
                    show_state      <= 0 ;
                end
            end
            11: begin
                if (spi_finish) begin
                    spi_start       <= 0;
                    show_state      <= 11 ;
                    if (counter==3) begin
                        spi_enable      <= 1;
                    end
                end else begin
                    if (counter==3) begin
                        counter <= 0;
                        if (idx==4) begin
                            show_state      <= 5;
                        end else begin
                            idx <= idx + 1 ;
                            show_state      <= 0;
                        end
                    end else begin
                        counter <= counter + 1;
                        show_state      <= 0 ;
                    end
                end
            end
            
            5: begin
                counter <= 0;
                show_finished <= 0;
                mem_addr_reg <= 0;
                if (display_game) begin
                    show_state <=6;
                end else begin
                    show_state <=5;
                end
            end
            6: begin
                mem_addr_reg[7:4] <= counter+8;
                show_state <= 2;
            end

            2: begin
                spi_enable      <= 0;
                dynamic_command <= {4'b0000,(counter+4'b0001),mem_rdata_w[15:8]};
                if (spi_finish) begin
                    spi_start       <= 0;
                    show_state      <= 12 ;
                end else begin
                    spi_start       <= 1;
                    show_state      <= 2 ;
                end
            end
            12: begin
                if (spi_finish) begin
                    spi_start       <= 0;
                    show_state      <= 12 ;
                end else begin
                    spi_start       <= 0;
                    show_state      <= 3 ;
                end
            end
            3: begin
                spi_enable      <= 0;
                dynamic_command <= {4'b0000,(counter+4'b0001),mem_rdata_w[7:0]};
                if (spi_finish) begin
                    spi_start       <= 0;
                    show_state      <= 13 ;
                end else begin
                    spi_start       <= 1;
                    show_state      <= 3 ;
                end
            end
            13: begin
                if (spi_finish) begin
                    spi_start       <= 0;
                    show_state      <= 13 ;
                end else begin
                    spi_start       <= 0;
                    show_state      <= 8 ;
                    mem_addr_reg[7:4] <= counter;
                end
            end
            8: begin
                spi_enable      <= 0;
                dynamic_command <= {4'b0000,(counter+4'b0001),mem_rdata_w[15:8]};
                if (spi_finish) begin
                    spi_start       <= 0;
                    show_state      <= 14 ;
                end else begin
                    spi_start       <= 1;
                    show_state      <= 8 ;
                end
            end
            14: begin
                if (spi_finish) begin
                    spi_start       <= 0;
                    show_state      <= 14 ;
                end else begin
                    spi_start       <= 0;
                    show_state      <= 9 ;
                end
            end
            9: begin
                spi_enable      <= 0;
                dynamic_command <= {4'b0000,(counter+4'b0001),mem_rdata_w[7:0]};
                if (spi_finish) begin
                    spi_start       <= 0;
                    show_state      <= 15 ;
                end else begin
                    spi_start       <= 1;
                    show_state      <= 9 ;
                end
            end
            15: begin
                if (spi_finish) begin
                    spi_start       <= 0;
                    show_state      <= 15 ;
                    spi_enable      <= 1;
                end else begin
                    spi_start       <= 0;
                    show_state      <= 10 ;
                    mem_addr_reg[7:4] <= counter + 8;
                end
            end
            10: begin
                if (counter==7) begin
                    show_state <= 4;
                end else begin
                    counter <= counter + 1;
                    show_state <= 6;
                end
            end
            4: begin
                show_finished <= 1;
                if (display_game) begin
                    show_state <= 4;
                    //$finish;
                end else begin
                    show_state <= 5;
                end
            end
            default: begin
                counter         <= 0;
                mem_addr_reg    <= 0;
                show_state      <= 0;
                show_finished   <= 1;
                dynamic_command <= 0;
            end
        endcase
    end
end

always @(posedge clk_50, negedge reset_n) begin
    if (!reset_n) begin
        t_x <= 0;
        t_y <= 0;
    end else begin
        if (update_tail) begin
            t_x <= mem_addr[3:0];
            t_y <= mem_addr[7:4];
        end
    end
end



always @(posedge clk_50, negedge reset_n) begin
    if(!reset_n) begin
        timer_count <= 0;
        timer_flag <= 1'b0;
    end else begin
        if (slow_clk) begin
            if (timer_count==(20'd250000-1)) begin
                timer_count <= 0;
                timer_flag <= 1'b1;
            end else begin
                timer_count <= timer_count + 1;
                timer_flag <= 1'b0;
            end
        end
    end
end


//assign dynamic_command = 0;
assign game_over = 0;
assign snake_len = 0;

endmodule
