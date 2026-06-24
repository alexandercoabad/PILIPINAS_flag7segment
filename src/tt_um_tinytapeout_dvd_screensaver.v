/*
 * Combined: DVD Bouncing Flag Screensaver + PILIPINAS 7-Segment Display
 * SPDX-License-Identifier: Apache-2.0
 * Developed by Alexander Co Abad
 */

`default_nettype none

parameter LOGO_WIDTH    = 128;
parameter LOGO_HEIGHT   = 64;
parameter DISPLAY_WIDTH  = 640;
parameter DISPLAY_HEIGHT = 480;

module tt_um_combined (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // -------------------------------------------------------
    // VGA Sync Generator (shared)
    // -------------------------------------------------------
    wire hsync;
    wire vsync;
    wire video_active;
    wire [9:0] pix_x;
    wire [9:0] pix_y;

    vga_sync_generator vga_sync_gen (
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(pix_x),
        .vpos(pix_y)
    );

    // -------------------------------------------------------
    // DVD BOUNCING FLAG LOGIC
    // -------------------------------------------------------
    wire [9:0] logo_x = pix_x - logo_left;
    wire [9:0] logo_y = pix_y - logo_top;

    wire logo_region = (pix_x >= logo_left && pix_x < logo_left + LOGO_WIDTH) &&
                       (pix_y >= logo_top  && pix_y < logo_top  + LOGO_HEIGHT);

    // Wave engine - 16-step sine LUT for smoother flag edges
    reg [5:0] wave_timer;
    wire [5:0] wave_index = logo_x[5:0] + wave_timer;
    reg signed [4:0] sine_offset;

    always @(*) begin
        case (wave_index[5:2])
            4'b0000: sine_offset =  5'sb00000; //  0
            4'b0001: sine_offset =  5'sb00001; //  1
            4'b0010: sine_offset =  5'sb00010; //  2
            4'b0011: sine_offset =  5'sb00011; //  3
            4'b0100: sine_offset =  5'sb00100; //  4
            4'b0101: sine_offset =  5'sb00011; //  3
            4'b0110: sine_offset =  5'sb00010; //  2
            4'b0111: sine_offset =  5'sb00001; //  1
            4'b1000: sine_offset =  5'sb00000; //  0
            4'b1001: sine_offset = -5'sb00001; // -1
            4'b1010: sine_offset = -5'sb00010; // -2
            4'b1011: sine_offset = -5'sb00011; // -3
            4'b1100: sine_offset = -5'sb00100; // -4
            4'b1101: sine_offset = -5'sb00011; // -3
            4'b1110: sine_offset = -5'sb00010; // -2
            4'b1111: sine_offset = -5'sb00001; // -1
        endcase
    end

    wire signed [11:0] full_y_calc  = $signed({1'b0, logo_y[5:0]}) + sine_offset;
    wire               out_of_bounds = (full_y_calc < 0) || (full_y_calc > 63);

    wire [1:0] pixel_color;
    bitmap_rom rom1 (
        .x(logo_x[6:0]),
        .y(full_y_calc[5:0]),
        .pixel_color(pixel_color)
    );

    // Flag RGB
    reg flag_r, flag_g, flag_b;
    always @(*) begin
        if (!video_active || !logo_region || out_of_bounds) begin
            flag_r = 0; flag_g = 0; flag_b = 0;
        end else begin
            case (pixel_color)
                2'b01: begin flag_r = 1; flag_g = 1; flag_b = 1; end          // White
                2'b10: begin                                                    // Blue / Red halves
                    if (full_y_calc[5:0] < 32) begin
                        flag_r = 0; flag_g = 0; flag_b = 1;
                    end else begin
                        flag_r = 1; flag_g = 0; flag_b = 0;
                    end
                end
                2'b11: begin flag_r = 1; flag_g = 1; flag_b = 0; end          // Gold
                default: begin flag_r = 0; flag_g = 0; flag_b = 0; end
            endcase
        end
    end

    // Bouncing position state
    reg [9:0] logo_left, logo_top;
    reg       dir_x, dir_y;
    reg [9:0] prev_y;

    always @(posedge clk) begin
        if (~rst_n) begin
            logo_left  <= 200;
            logo_top   <= 100;   // keep flag above the text band (y < 355)
            dir_x      <= 1;
            dir_y      <= 0;
            wave_timer <= 0;
            prev_y     <= 0;
        end else begin
            prev_y <= pix_y;
            if (pix_y == 0 && prev_y != pix_y) begin
                wave_timer <= wave_timer + 1;

                logo_left <= logo_left + (dir_x ? 1 : -1);
                logo_top  <= logo_top  + (dir_y ? 1 : -1);

                if (logo_left <= 1 && !dir_x)
                    dir_x <= 1;
                if (logo_left >= (DISPLAY_WIDTH - LOGO_WIDTH - 1) && dir_x)
                    dir_x <= 0;
                if (logo_top <= 1 && !dir_y)
                    dir_y <= 1;
                // Clamp bounce ceiling to stay above the text band (y = 355)
                if (logo_top >= (390 - LOGO_HEIGHT - 1) && dir_y)
                    dir_y <= 0;
            end
        end
    end

    // -------------------------------------------------------
    // PILIPINAS 7-SEGMENT TEXT LOGIC  (y: 355-474)
    // -------------------------------------------------------
    // Counter widened to 14 bits; stage tapped at [11:8] so each
    // letter displays for ~256 vsync pulses (~4.3 seconds at 60 Hz).
    reg [11:0] seg_counter;
    wire [3:0] current_stage = seg_counter[6:3];
    wire       show_full_word = (current_stage >= 4'd9);

    reg [7:0] countdown [8:0];
    initial begin
        countdown[0] = 8'b01110011; // P
        countdown[1] = 8'b00000110; // I
        countdown[2] = 8'b00111000; // L
        countdown[3] = 8'b00000110; // I
        countdown[4] = 8'b01110011; // P
        countdown[5] = 8'b00000110; // I
        countdown[6] = 8'b00110111; // N
        countdown[7] = 8'b01110111; // A
        countdown[8] = 8'b01101101; // S
    end

    // Advance counter on vsync
    always @(posedge vsync, negedge rst_n) begin
        if (~rst_n) seg_counter <= 0;
        else        seg_counter <= seg_counter + 1;
    end

    // -------------------------------------------------------
    // 7-SEGMENT GEOMETRY  (exact reference constants)
    // -------------------------------------------------------
    // The reference code works in full 640√ó480 pixel space.
    // We tile 9 digits across the screen. Each digit is offset
    // by xo (x-origin of that digit slot). The y band starts at
    // TEXT_Y0=355, so we subtract that to get local y = y - 355.
    //
    // All segment constants are IDENTICAL to the reference ‚Äî no
    // scaling. We simply replace x‚Üí(x-xo) and y‚Üí(y-TEXT_Y0).
    // Cell width = 256px mapped into 640/9 ‚âà 71px ‚Üí use 70px cell.
    // 9√ó70 = 630px, margin = (640-630)/2 = 5px each side.
    // -------------------------------------------------------

    localparam TEXT_Y0  = 10'd390;
    localparam TEXT_Y1  = 10'd480;  // full bottom of screen
    localparam CELL     = 10'd70;
    localparam MARGIN   = 10'd5;

    wire in_y_range     = (pix_y >= TEXT_Y0) && (pix_y < TEXT_Y1);
    wire in_x_range     = (pix_x >= MARGIN)  && (pix_x < MARGIN + 9*CELL);
    wire display_window = in_x_range && in_y_range;

    // Which digit slot?
    wire [3:0] digit_select =
        (pix_x < MARGIN +   CELL) ? 4'd0 :
        (pix_x < MARGIN + 2*CELL) ? 4'd1 :
        (pix_x < MARGIN + 3*CELL) ? 4'd2 :
        (pix_x < MARGIN + 4*CELL) ? 4'd3 :
        (pix_x < MARGIN + 5*CELL) ? 4'd4 :
        (pix_x < MARGIN + 6*CELL) ? 4'd5 :
        (pix_x < MARGIN + 7*CELL) ? 4'd6 :
        (pix_x < MARGIN + 8*CELL) ? 4'd7 : 4'd8;

    wire [9:0] xo = MARGIN + digit_select * CELL;  // x origin of digit

    // Map cell-local coords into the reference's active segment bbox.
    // Reference active bbox: x in [191..448] (257px wide), y in [7..472] (465px tall)
    // Our cell: x in [0..69] (70px), y in [0..124] (125px)
    //
    // rx = rx_raw * 257/70 + 191  ‚âà  rx_raw * 4 - rx_raw/2 + rx_raw/8 + rx_raw/32 + 191
    //                                             (‚âà rx_raw * 3.656 + 191, max‚Üí444)
    // ry = ry_raw * 465/125 + 7   ‚âà  ry_raw * 4 - ry_raw/4 - ry_raw/32 + 7
    //                                             (‚âà ry_raw * 3.719 + 7,   max‚Üí470)
    wire [9:0]  rx_raw = pix_x - xo;
    wire [9:0]  ry_raw = pix_y - TEXT_Y0;
    // Content occupies first 54px of the 70px cell; last 16px = inter-letter gap.
    // Scale rx_raw(0..54) ‚Üí 191..443 (full reference active width of 252px).
    // rx_raw(55..69) produces rx>443 which falls outside all segment conditions ‚Üí blank.
    wire [11:0] rx = (rx_raw << 2) + (rx_raw >> 1) + (rx_raw >> 4) + 191;
    wire [11:0] ry = (ry_raw * 5) + (ry_raw >> 2) + (ry_raw >> 4) + 7;  // ~5.3x ‚Üí fits 90px band (ry_raw=89‚Üí479)

    // LED pattern for this slot
    wire [7:0] slot_led = show_full_word
                          ? countdown[digit_select]
                          : (current_stage == digit_select)
                            ? countdown[current_stage]
                            : 8'b00000000;

    // ----------------------------------------------------------
    // Segment equations with diagonal gap between junctions.
    // GAP is added/subtracted on every shared diagonal edge so
    // neighbouring segments are separated by 2*GAP pixels along
    // the diagonal.  Outer boundary edges are unchanged.
    // ----------------------------------------------------------
    localparam GAP = 12;  // increase this value for wider gaps

    // Diagonal junction wires (each used by two segments)
    wire j_a1  = rx < ry + 392 - GAP;   // A/B top-right diagonal
    wire j_a4  = rx > ry + 185 + GAP;   // A/B inner-left diagonal
    wire j_a5  = rx > 247 - ry + GAP;   // A/F bottom-left diagonal
    wire j_a2  = 454 - rx > ry + GAP;   // A/F outer-left diagonal
    wire j_b2  = 662 - rx > ry + GAP;   // B/G/E right diagonal
    wire j_b5  = 455 - rx < ry - GAP;   // B/G/E inner-right diagonal
    wire j_c0  = rx < ry + 184 - GAP;   // C/F/G left diagonal
    wire j_c3  = rx + 23 > ry + GAP;    // C/F/G inner-left diagonal
    wire j_c2  = 872 - rx > ry + GAP;   // C/D right diagonal
    wire j_c5  = 663 - rx < ry - GAP;   // C/D inner-right diagonal
    wire j_d1  = ry > rx + 24 + GAP;    // D/E bottom-left diagonal

    // Segment A  (top horizontal bar)  ‚Äî outer edges a0,a3 unchanged
    wire seg_a = (ry > 3) & j_a1 & j_a2 & (ry < 62) & j_a4 & j_a5;

    // Segment B  (upper-right vertical bar)  ‚Äî outer edges b1,b4 unchanged
    wire seg_b = j_a1 & (rx < 448) & j_b2 & j_a4 & (rx > 399) & j_b5;

    // Segment C  (lower-right vertical bar)  ‚Äî outer edges c1,c4 unchanged
    wire seg_c = j_c0 & (rx < 448) & j_c2 & j_c3 & (rx > 399) & j_c5;

    // Segment D  (bottom horizontal bar)  ‚Äî outer edges d0,d3 unchanged
    wire seg_d = (ry > 418) & j_d1 & j_c2 & (ry < 477) & (rx > ry - 232) & j_c5;

    // Segment E  (lower-left vertical bar)  ‚Äî outer edges e1,e4 unchanged
    wire seg_e = j_d1 & (rx < 240) & j_b2 & (rx > ry - 232) & (rx > 191) & j_b5;

    // Segment F  (upper-left vertical bar)  ‚Äî outer edges f1,f4 unchanged
    wire seg_f = j_c0 & (rx < 240) & j_a2 & j_c3 & (rx > 191) & j_a5;

    // Segment G  (middle horizontal bar)  ‚Äî all edges are junctions
    wire seg_g = (ry > 210) & j_c0 & j_b2 & (ry < 267) & j_c3 & j_b5;

    wire text_pixel = display_window &&
                      ((seg_a & slot_led[0]) | (seg_b & slot_led[1]) |
                       (seg_c & slot_led[2]) | (seg_d & slot_led[3]) |
                       (seg_e & slot_led[4]) | (seg_f & slot_led[5]) |
                       (seg_g & slot_led[6]));

    // -------------------------------------------------------
    // PIXEL COMPOSITOR - text takes priority over flag
    // -------------------------------------------------------
    wire [5:0] green = 6'b001100;
    wire [5:0] black = 6'b000000;

    wire r_out = text_pixel ? 1'b0 : flag_r;
    wire g_out = text_pixel ? green[3] : flag_g;   // green[3]=1
    wire b_out = text_pixel ? 1'b0 : flag_b;

    // TinyVGA PMOD pinout
    assign uo_out  = {hsync, b_out, g_out, r_out, vsync, b_out, g_out, r_out};
    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000;

    wire _unused_ok = &{ena, ui_in, uio_in};

endmodule






