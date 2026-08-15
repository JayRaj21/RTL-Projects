module traffic_light_moore(light, clk, reset, walk_request);
    output reg [1:0] light;
    input clk, reset, walk_request;

    parameter RED    = 2'b00;
    parameter GREEN  = 2'b01;
    parameter YELLOW = 2'b10;
    parameter FLASH  = 2'b11; //pedestrian "walk" flash

    parameter RED_TIME    = 4; //cycles spent in each state
    parameter GREEN_TIME  = 4;
    parameter YELLOW_TIME = 2;
    parameter FLASH_TIME  = 2;

    reg [1:0] state, next_state;
    reg [3:0] count;
    reg walk_latched;

    always @(*) begin
       //Moore: output depends only on state, never on walk_request directly
       light = state;
       case (state)
        RED:     next_state = GREEN;
        GREEN:   next_state = walk_latched ? FLASH : YELLOW;
        FLASH:   next_state = YELLOW;
        YELLOW:  next_state = RED;
        default: next_state = RED;
       endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            state <= RED;
            count <= 0;
            walk_latched <= 0;
        end 
        else if ((state == RED && count == RED_TIME-1) || (state == GREEN  && count == GREEN_TIME-1) || 
                (state == FLASH  && count == FLASH_TIME-1) || (state == YELLOW && count == YELLOW_TIME-1)) begin
            state <= next_state;
            count <= 0;
            if (state == GREEN)
                walk_latched <= 0;
        end 
        else begin
            count <= count + 1;
            if (state == GREEN && walk_request)
                walk_latched <= 1;
        end
    end
endmodule


module traffic_light_mealy(light, clk, reset, walk_request);
    output reg [1:0] light;
    input clk, reset, walk_request;

    parameter RED    = 2'b00;
    parameter GREEN  = 2'b01;
    parameter YELLOW = 2'b10;
    parameter FLASH  = 2'b11; //pedestrian "walk" flash

    parameter RED_TIME    = 4; //cycles spent in each state
    parameter GREEN_TIME  = 4;
    parameter YELLOW_TIME = 2;

    reg [1:0] state, next_state;
    reg [3:0] count;

    always @(*) begin
       //Mealy: output depends on state AND the live walk_request input,
       //so it can react within the same cycle instead of waiting on clk
       light = (state == GREEN && walk_request) ? FLASH : state;
       case (state)
        RED:     next_state = GREEN;
        GREEN:   next_state = YELLOW;
        YELLOW:  next_state = RED;
        default: next_state = RED;
       endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            state <= RED;
            count <= 0;
        end 
        else if ((state == RED && count == RED_TIME-1) || (state == GREEN  && count == GREEN_TIME-1) || (state == YELLOW && count == YELLOW_TIME-1)) begin
            state <= next_state;
            count <= 0;
        end 
        else begin
            count <= count + 1;
        end
    end
endmodule
