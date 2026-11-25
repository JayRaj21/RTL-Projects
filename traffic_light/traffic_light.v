module traffic_light_moore(light, clk, reset);
    output reg [1:0] light;
    input clk, reset;

    parameter RED    = 2'b00;
    parameter GREEN  = 2'b01;
    parameter YELLOW = 2'b10;

    parameter RED_TIME    = 4; //cycles spent in each state
    parameter GREEN_TIME  = 4;
    parameter YELLOW_TIME = 2;

    reg [1:0] state, next_state;
    reg [3:0] count;

    always @(*) begin
       //Moore: output depends only on state
       light = state;
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
        else if ((state == RED    && count == RED_TIME-1)   ||
                 (state == GREEN  && count == GREEN_TIME-1) ||
                 (state == YELLOW && count == YELLOW_TIME-1)) begin
            state <= next_state;
            count <= 0;
        end
        else begin
            count <= count + 1;
        end
    end
endmodule


module traffic_light_mealy(light, clk, reset);
    output reg [1:0] light;
    input clk, reset;

    parameter RED    = 2'b00;
    parameter GREEN  = 2'b01;
    parameter YELLOW = 2'b10;

    parameter RED_TIME    = 4; //cycles spent in each state
    parameter GREEN_TIME  = 4;
    parameter YELLOW_TIME = 2;

    reg [1:0] state, next_state;
    reg [3:0] count;

    always @(*) begin
       //Mealy: output logic kept separate from the Moore version,
       //but with no live input to react to, it reduces to state-only too
       light = state;
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
        else if ((state == RED    && count == RED_TIME-1)   ||
                 (state == GREEN  && count == GREEN_TIME-1) ||
                 (state == YELLOW && count == YELLOW_TIME-1)) begin
            state <= next_state;
            count <= 0;
        end
        else begin
            count <= count + 1;
        end
    end
endmodule
