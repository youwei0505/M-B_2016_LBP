
`timescale 1ns/10ps
module LBP ( clk, reset, gray_addr, gray_req, gray_ready, gray_data, lbp_addr, lbp_valid, lbp_data, finish);
input   	clk;
input   	reset;
output  reg [13:0] 	gray_addr;
output  reg        	gray_req;
input   	gray_ready;
input   [7:0] 	gray_data;
output  reg [13:0] 	lbp_addr;
output  reg     	lbp_valid;
output  reg [7:0] 	lbp_data;
output  reg     	finish;

//reg
reg [2:0] curt_state;
reg [2:0] next_state;
reg [7:0] addr_counter_x;
reg [7:0] addr_counter_y;
reg [13:0] pixel_addr;
reg [13:0] next_gray_addr;
reg [8:0] result;
reg first_flag;

reg [7:0] image_buffer[8:0];
// reg [8:0] data_buffer[8:0];
// reg [8:0] temp_buffer[8:0];
reg result_buffer[8:0];
reg [7:0] image_buffer_counter;

//State
localparam READ = 0;
localparam OTHER_READ = 1;
localparam CAL = 2;
localparam MOVE = 3;
localparam WRITE_OUT = 4; 
localparam DONE = 5; 

//C 
always @( * ) // State Control ( next state condition )
begin 
    case ( curt_state )
        READ : 
        begin            
            // the lastest line
            if( pixel_addr == 16383)
                next_state = DONE;
            // Outer box is zero
            if( pixel_addr <= 128 || pixel_addr[6:0] == 127 || pixel_addr[6:0] == 0 || pixel_addr >= 16256)
                next_state = WRITE_OUT;
            else
            begin
                if ( image_buffer_counter == 9 )
                    next_state = MOVE;
                else     
                    next_state = READ;
            end
        end
        // CAL : 
        // begin
        //     next_state = MOVE;
        // end
        MOVE : 
        begin
            next_state = WRITE_OUT;
        end
        WRITE_OUT : 
        begin
            if ( pixel_addr == 16383 )
                next_state = DONE;
            else if ( pixel_addr < 128 || pixel_addr[6:0] == 127 || pixel_addr >= 16256)
                next_state = WRITE_OUT;
            else
                next_state = READ;
        end
        DONE :
        begin
            next_state = DONE;
        end
    endcase    
end


// Compute data_buff address
// Cal position
always @( * ) 
begin
    case( image_buffer_counter )
        0 : next_gray_addr = pixel_addr - 129;
        1 : next_gray_addr = pixel_addr - 128;
        2 : next_gray_addr = pixel_addr - 127;
        3 : next_gray_addr = pixel_addr - 1  ;
        4 : next_gray_addr = pixel_addr      ;
        5 : next_gray_addr = pixel_addr + 1  ;
        6 : next_gray_addr = pixel_addr + 127; 
        7 : next_gray_addr = pixel_addr + 128;
        8 : next_gray_addr = pixel_addr + 129;
        default: next_gray_addr = 0;
	endcase
end

// Determine 1 or 0
always @( * ) 
begin
    result_buffer[1] <= ( image_buffer[4] > image_buffer[1] ) ? 0:1;
    result_buffer[0] <= ( image_buffer[4] > image_buffer[0] ) ? 0:1;
    result_buffer[2] <= ( image_buffer[4] > image_buffer[2] ) ? 0:1;
    result_buffer[3] <= ( image_buffer[4] > image_buffer[3] ) ? 0:1;
    result_buffer[4] <= image_buffer[4];
    result_buffer[5] <= ( image_buffer[4] > image_buffer[5] ) ? 0:1;
    result_buffer[6] <= ( image_buffer[4] > image_buffer[6] ) ? 0:1;
    result_buffer[7] <= ( image_buffer[4] > image_buffer[7] ) ? 0:1;
    result_buffer[8] <= ( image_buffer[4] > image_buffer[8] ) ? 0:1;
end

// Output Result
always @( * ) 
begin
    if ( pixel_addr <= 128 || pixel_addr[6:0] == 127 || pixel_addr[6:0] == 0 || pixel_addr >= 16256)
        result <= 0;
    else 
        result <= {
            8'b0,
            result_buffer[8],//2*7
            result_buffer[7],//2*6
            result_buffer[6],//2*5
            result_buffer[5],//2*4
            result_buffer[3],//2*3
            result_buffer[2],//2*2
            result_buffer[1],//2*1
            result_buffer[0] //2*0
            };
end

//S Circuit
always @( posedge clk or posedge reset) // Data process and control signal
begin 
    //Initial, active high asynchronous
    if ( reset ) 
    begin     
        curt_state     <= 0; 
        addr_counter_x <= 0;
        addr_counter_y <= 0;
        gray_req       <= 0;
        gray_addr      <= 0;
        lbp_valid      <= 0;
        finish         <= 0;
        pixel_addr     <= 0;
        image_buffer_counter <= 0;
        first_flag <= 1;

        // temp_buffer[0] <= 0;
        // temp_buffer[1] <= 0;
        // temp_buffer[2] <= 0;
        // temp_buffer[3] <= 0;
        // temp_buffer[4] <= 0;
        // temp_buffer[5] <= 0;
        // temp_buffer[6] <= 0;
        // temp_buffer[7] <= 0;
        // temp_buffer[8] <= 0;

    end 
    else 
    begin
        curt_state <= next_state; 
        
        case ( curt_state )
            READ : 
            begin
                lbp_valid <= 0;
                if( gray_ready == 1)
                begin                    
                    gray_req  <= 1;
                end  

                gray_addr <= next_gray_addr;

                if ( pixel_addr <= 128 || pixel_addr[6:0] == 127 || pixel_addr[6:0] == 0 || pixel_addr >= 16256)
                begin
                    
                end
                else
                begin
                    image_buffer_counter <= image_buffer_counter + 1;   
                    // if( first_flag )
                    // begin
                    //     image_buffer_counter <= image_buffer_counter + 1;        
                    // end      
                    // else
                    // begin
                    //     image_buffer_counter <= image_buffer_counter + 3;
                    // end  
                    
                    
                    if( gray_req )
                    begin      
                        image_buffer[image_buffer_counter - 1] <= gray_data;                         
                    end

                    if( image_buffer_counter == 9 )
                    begin
                        // first_flag <= 0;
                        gray_req <= 0;
                        image_buffer_counter <= 0;
                        // addr_counter_x <= addr_counter_x + 1; 
                    end
                end 
            end  
                      
            // CAL : 
            // begin  
            //     // if( first_flag )
            //     // begin
            //     //     data_buffer[0] <= image_buffer[0];
            //     //     data_buffer[1] <= image_buffer[1];
            //     //     data_buffer[2] <= image_buffer[2];
            //     //     data_buffer[3] <= image_buffer[3];               
            //     //     data_buffer[4] <= image_buffer[4];
            //     //     data_buffer[5] <= image_buffer[5];
            //     //     data_buffer[6] <= image_buffer[6]; 
            //     //     data_buffer[7] <= image_buffer[7]; 
            //     //     data_buffer[8] <= image_buffer[8];
            //     // end
            //     // else
            //     // begin
            //     //     data_buffer[0] <= temp_buffer[1];
            //     //     data_buffer[1] <= temp_buffer[2];
            //     //     data_buffer[2] <= image_buffer[2];
            //     //     data_buffer[3] <= temp_buffer[4];               
            //     //     data_buffer[4] <= temp_buffer[5];
            //     //     data_buffer[5] <= image_buffer[5];
            //     //     data_buffer[6] <= temp_buffer[7]; 
            //     //     data_buffer[7] <= temp_buffer[8]; 
            //     //     data_buffer[8] <= image_buffer[8];
            //     // end
                
            // end
            // MOVE :
            // begin   

            //     temp_buffer[0] <= image_buffer[0];
            //     temp_buffer[1] <= image_buffer[1];
            //     temp_buffer[2] <= image_buffer[2];
            //     temp_buffer[3] <= image_buffer[3];                
            //     temp_buffer[4] <= image_buffer[4];
            //     temp_buffer[5] <= image_buffer[5];
            //     temp_buffer[6] <= image_buffer[6]; 
            //     temp_buffer[7] <= image_buffer[7];
            //     temp_buffer[8] <= image_buffer[8]; 
                
            // end
            WRITE_OUT : 
            begin                
                lbp_addr <= pixel_addr;
                lbp_data <= result;
                lbp_valid <= 1;
                pixel_addr <= pixel_addr + 1;
            end
            DONE : 
            begin
                finish <= 1;
            end
        endcase 
        
    end
end 


endmodule
