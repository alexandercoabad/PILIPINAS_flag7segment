// /*
//  * Combined: DVD Bouncing Flag Screensaver + PILIPINAS 7-Segment Display
//  * SPDX-License-Identifier: Apache-2.0
//  */

// `default_nettype none

// parameter LOGO_WIDTH    = 128;
// parameter LOGO_HEIGHT   = 64;
// parameter DISPLAY_WIDTH  = 640;
// parameter DISPLAY_HEIGHT = 480;

// module tt_um_combined (
//     input  wire [7:0] ui_in,
//     output wire [7:0] uo_out,
//     input  wire [7:0] uio_in,
//     output wire [7:0] uio_out,
//     output wire [7:0] uio_oe,
//     input  wire       ena,
//     input  wire       clk,
//     input  wire       rst_n
// );

//     // -------------------------------------------------------
//     // VGA Sync Generator (shared)
//     // -------------------------------------------------------
//     wire hsync;
//     wire vsync;
//     wire video_active;
//     wire [9:0] pix_x;
//     wire [9:0] pix_y;

//     vga_sync_generator vga_sync_gen (
//         .clk(clk),
//         .reset(~rst_n),
//         .hsync(hsync),
//         .vsync(vsync),
//         .display_on(video_active),
//         .hpos(pix_x),
//         .vpos(pix_y)
//     );

//     // -------------------------------------------------------
//     // DVD BOUNCING FLAG LOGIC
//     // -------------------------------------------------------
//     wire [9:0] logo_x = pix_x - logo_left;
//     wire [9:0] logo_y = pix_y - logo_top;

//     wire logo_region = (pix_x >= logo_left && pix_x < logo_left + LOGO_WIDTH) &&
//                        (pix_y >= logo_top  && pix_y < logo_top  + LOGO_HEIGHT);

//     // Wave engine ‚Äî 16-step sine LUT for smoother flag edges
//     reg [5:0] wave_timer;
//     wire [5:0] wave_index = logo_x[5:0] + wave_timer;
//     reg signed [4:0] sine_offset;

//     always @(*) begin
//         case (wave_index[5:2])
//             4'b0000: sine_offset =  5'sb00000; //  0
//             4'b0001: sine_offset =  5'sb00001; //  1
//             4'b0010: sine_offset =  5'sb00010; //  2
//             4'b0011: sine_offset =  5'sb00011; //  3
//             4'b0100: sine_offset =  5'sb00100; //  4
//             4'b0101: sine_offset =  5'sb00011; //  3
//             4'b0110: sine_offset =  5'sb00010; //  2
//             4'b0111: sine_offset =  5'sb00001; //  1
//             4'b1000: sine_offset =  5'sb00000; //  0
//             4'b1001: sine_offset = -5'sb00001; // -1
//             4'b1010: sine_offset = -5'sb00010; // -2
//             4'b1011: sine_offset = -5'sb00011; // -3
//             4'b1100: sine_offset = -5'sb00100; // -4
//             4'b1101: sine_offset = -5'sb00011; // -3
//             4'b1110: sine_offset = -5'sb00010; // -2
//             4'b1111: sine_offset = -5'sb00001; // -1
//         endcase
//     end

//     wire signed [11:0] full_y_calc  = $signed({1'b0, logo_y[5:0]}) + sine_offset;
//     wire               out_of_bounds = (full_y_calc < 0) || (full_y_calc > 63);

//     wire [1:0] pixel_color;
//     bitmap_rom rom1 (
//         .x(logo_x[6:0]),
//         .y(full_y_calc[5:0]),
//         .pixel_color(pixel_color)
//     );

//     // Flag RGB
//     reg flag_r, flag_g, flag_b;
//     always @(*) begin
//         if (!video_active || !logo_region || out_of_bounds) begin
//             flag_r = 0; flag_g = 0; flag_b = 0;
//         end else begin
//             case (pixel_color)
//                 2'b01: begin flag_r = 1; flag_g = 1; flag_b = 1; end          // White
//                 2'b10: begin                                                    // Blue / Red halves
//                     if (full_y_calc[5:0] < 32) begin
//                         flag_r = 0; flag_g = 0; flag_b = 1;
//                     end else begin
//                         flag_r = 1; flag_g = 0; flag_b = 0;
//                     end
//                 end
//                 2'b11: begin flag_r = 1; flag_g = 1; flag_b = 0; end          // Gold
//                 default: begin flag_r = 0; flag_g = 0; flag_b = 0; end
//             endcase
//         end
//     end

//     // Bouncing position state
//     reg [9:0] logo_left, logo_top;
//     reg       dir_x, dir_y;
//     reg [9:0] prev_y;

//     always @(posedge clk) begin
//         if (~rst_n) begin
//             logo_left  <= 200;
//             logo_top   <= 100;   // keep flag above the text band (y < 355)
//             dir_x      <= 1;
//             dir_y      <= 0;
//             wave_timer <= 0;
//             prev_y     <= 0;
//         end else begin
//             prev_y <= pix_y;
//             if (pix_y == 0 && prev_y != pix_y) begin
//                 wave_timer <= wave_timer + 1;

//                 logo_left <= logo_left + (dir_x ? 1 : -1);
//                 logo_top  <= logo_top  + (dir_y ? 1 : -1);

//                 if (logo_left <= 1 && !dir_x)
//                     dir_x <= 1;
//                 if (logo_left >= (DISPLAY_WIDTH - LOGO_WIDTH - 1) && dir_x)
//                     dir_x <= 0;
//                 if (logo_top <= 1 && !dir_y)
//                     dir_y <= 1;
//                 // Clamp bounce ceiling to stay above the text band (y = 355)
//                 if (logo_top >= (355 - LOGO_HEIGHT - 1) && dir_y)
//                     dir_y <= 0;
//             end
//         end
//     end

//     // -------------------------------------------------------
//     // PILIPINAS 7-SEGMENT TEXT LOGIC  (y: 355‚Äì474)
//     // -------------------------------------------------------
//     reg [11:0] seg_counter;
//     wire [3:0] current_stage = seg_counter[9:6];
//     wire       show_full_word = (current_stage >= 4'd9);

//     reg [7:0] countdown [8:0];
//     initial begin
//         countdown[0] = 8'b01110011; // P
//         countdown[1] = 8'b00000110; // I
//         countdown[2] = 8'b00111000; // L
//         countdown[3] = 8'b00000110; // I
//         countdown[4] = 8'b01110011; // P
//         countdown[5] = 8'b00000110; // I
//         countdown[6] = 8'b00110111; // N
//         countdown[7] = 8'b01110111; // A
//         countdown[8] = 8'b01101101; // S
//     end

//     // Advance counter on vsync
//     always @(posedge vsync, negedge rst_n) begin
//         if (~rst_n) seg_counter <= 0;
//         else        seg_counter <= seg_counter + 1;
//     end

//     // Digit slot mapping ‚Äî 9 letters √ó 68 px = 612 px, centred: (640-612)/2 = 14 px margin
//     localparam MARGIN = 10'd14;
//     wire [3:0] digit_select = (pix_x < MARGIN + 68)  ? 4'd0 :
//                               (pix_x < MARGIN + 136) ? 4'd1 :
//                               (pix_x < MARGIN + 204) ? 4'd2 :
//                               (pix_x < MARGIN + 272) ? 4'd3 :
//                               (pix_x < MARGIN + 340) ? 4'd4 :
//                               (pix_x < MARGIN + 408) ? 4'd5 :
//                               (pix_x < MARGIN + 476) ? 4'd6 :
//                               (pix_x < MARGIN + 544) ? 4'd7 : 4'd8;

//     wire [9:0] x_offset = (digit_select == 4'd0) ? MARGIN + 10'd0   :
//                           (digit_select == 4'd1) ? MARGIN + 10'd68  :
//                           (digit_select == 4'd2) ? MARGIN + 10'd136 :
//                           (digit_select == 4'd3) ? MARGIN + 10'd204 :
//                           (digit_select == 4'd4) ? MARGIN + 10'd272 :
//                           (digit_select == 4'd5) ? MARGIN + 10'd340 :
//                           (digit_select == 4'd6) ? MARGIN + 10'd408 :
//                           (digit_select == 4'd7) ? MARGIN + 10'd476 : MARGIN + 10'd544;

//     wire [9:0]  lx    = pix_x - x_offset;
//     wire [11:0] seg_x = (lx << 2) + 191;
//     wire [11:0] seg_y = ((pix_y - 355) << 2);

//     wire [7:0] slot_led = show_full_word              ? countdown[digit_select]  :
//                           (current_stage == digit_select) ? countdown[current_stage] :
//                           8'b00000000;

//     // Segment geometry ‚Äî GAP only applied to shared junction edges between segments.
//     // Outer boundary edges stay at original positions to preserve full thickness.
//     localparam GAP = 10;

//     // --- Segment A (top horizontal bar) ---
//     wire a0 = seg_y > 7   + GAP;           // junction: bottom edge shared with B/F tops
//     wire a1 = seg_x < seg_y + 392 - GAP;   // junction: diagonal shared with B
//     wire a2 = 454 - seg_x > seg_y;         // OUTER left diagonal ‚Äî unchanged
//     wire a3 = seg_y < 56  + GAP;           // OUTER top cap ‚Äî expanded outward to restore thickness
//     wire a4 = seg_x > seg_y + 185 + GAP;   // junction: inner diagonal shared with F
//     wire a5 = seg_x > 247 - seg_y + GAP;   // junction: inner diagonal shared with B
//     wire seg_a = a0 & a1 & a2 & a3 & a4 & a5;

//     // --- Segment B (upper-right vertical bar) ---
//     // Outer edges: b1 (right outer), b3 (outer left diagonal) ‚Äî unchanged
//     // Junction edges: b0 (meets A), b2 (meets G top), b4 (inner), b5 (top cap gap from A)
//     wire b0 = seg_x < seg_y + 392 - GAP;   // junction: shared with A
//     wire b1 = seg_x < 448;                 // OUTER right edge ‚Äî unchanged
//     wire b2 = 662 - seg_x > seg_y + GAP;   // junction: bottom diagonal shared with G
//     wire b3 = seg_x > seg_y + 185;         // OUTER left diagonal ‚Äî unchanged
//     wire b4 = seg_x > 399;                 // OUTER inner left ‚Äî unchanged
//     wire b5 = 455 - seg_x < seg_y - GAP;   // junction: top cap shared with A
//     wire seg_b = b0 & b1 & b2 & b3 & b4 & b5;

//     // --- Segment C (lower-right vertical bar) ---
//     // Outer edges: c1 (right outer), c4 (outer inner left) ‚Äî unchanged
//     // Junction edges: c0 (meets G bottom), c2 (meets D), c3 (inner), c5 (gap from G)
//     wire c0 = seg_x < seg_y + 184 - GAP;   // junction: top diagonal shared with G
//     wire c1 = seg_x < 448;                 // OUTER right edge ‚Äî unchanged
//     wire c2 = 872 - seg_x > seg_y + GAP;   // junction: bottom diagonal shared with D
//     wire c3 = seg_x + 23 > seg_y;          // OUTER left inner edge ‚Äî unchanged
//     wire c4 = seg_x > 399;                 // OUTER inner left ‚Äî unchanged
//     wire c5 = 663 - seg_x < seg_y - GAP;   // junction: top cap shared with G
//     wire seg_c = c0 & c1 & c2 & c3 & c4 & c5;

//     // --- Segment D (bottom horizontal bar) ---
//     wire d0 = seg_y > 423 + GAP;           // junction: top edge shared with C/E bottoms
//     wire d1 = seg_y > seg_x + 24  + GAP;   // junction: left diagonal shared with E
//     wire d2 = 872 - seg_x > seg_y + GAP;   // junction: right diagonal shared with C
//     wire d3 = seg_y < 472 + GAP;           // OUTER bottom cap ‚Äî expanded outward to restore thickness
//     wire d4 = seg_x > seg_y - 232  + GAP;  // junction: right inner shared with C
//     wire d5 = 663 - seg_x < seg_y - GAP;   // junction: left inner shared with E
//     wire seg_d = d0 & d1 & d2 & d3 & d4 & d5;

//     // --- Segment E (lower-left vertical bar) ---
//     // Outer edges: e1 (left outer), e3 (outer right diagonal) ‚Äî unchanged
//     // Junction edges: e0 (meets D), e2 (meets G bottom), e4 (inner), e5 (gap from G)
//     wire e0 = seg_y > seg_x + 24  + GAP;   // junction: shared with D
//     wire e1 = seg_x < 240;                 // OUTER left edge ‚Äî unchanged
//     wire e2 = 662 - seg_x > seg_y + GAP;   // junction: bottom diagonal shared with G
//     wire e3 = seg_x > seg_y - 232;         // OUTER right diagonal ‚Äî unchanged
//     wire e4 = seg_x > 191;                 // OUTER inner right ‚Äî unchanged
//     wire e5 = 455 - seg_x < seg_y - GAP;   // junction: top cap shared with G
//     wire seg_e = e0 & e1 & e2 & e3 & e4 & e5;

//     // --- Segment F (upper-left vertical bar) ---
//     // Outer edges: f1 (left outer), f4 (outer inner right) ‚Äî unchanged
//     // Junction edges: f0 (meets G top), f2 (meets A), f3 (inner), f5 (gap from A)
//     wire f0 = seg_x < seg_y + 184 - GAP;   // junction: top diagonal shared with G
//     wire f1 = seg_x < 240;                 // OUTER left edge ‚Äî unchanged
//     wire f2 = 454 - seg_x > seg_y + GAP;   // junction: bottom diagonal shared with A
//     wire f3 = seg_x + 23 > seg_y;          // OUTER right inner edge ‚Äî unchanged
//     wire f4 = seg_x > 191;                 // OUTER inner right ‚Äî unchanged
//     wire f5 = 247 - seg_x < seg_y - GAP;   // junction: top cap shared with A
//     wire seg_f = f0 & f1 & f2 & f3 & f4 & f5;

//     // --- Segment G (middle horizontal bar) ---
//     // All four edges are junctions (touches B, C, E, F on all sides)
//     wire g0 = seg_y > 215 + GAP;           // junction: top edge shared with B/F
//     wire g1 = seg_x < seg_y + 184 - GAP;   // junction: left diagonal shared with F/C
//     wire g2 = 662 - seg_x > seg_y + GAP;   // junction: right diagonal shared with B/E
//     wire g3 = seg_y < 262 + GAP;           // OUTER bottom cap ‚Äî expanded outward to restore thickness
//     wire g4 = seg_x + 23 > seg_y  + GAP;   // junction: left inner shared with F
//     wire g5 = 455 - seg_x < seg_y - GAP;   // junction: right inner shared with B
//     wire seg_g = g0 & g1 & g2 & g3 & g4 & g5;

//     wire in_y_range      = (pix_y >= 355) && (pix_y < 475);
//     wire in_x_range      = (pix_x >= MARGIN) && (pix_x < MARGIN + 612);
//     wire display_window  = in_x_range && in_y_range;

//     wire text_pixel = display_window &&
//                       ((seg_a & slot_led[0]) | (seg_b & slot_led[1]) |
//                        (seg_c & slot_led[2]) | (seg_d & slot_led[3]) |
//                        (seg_e & slot_led[4]) | (seg_f & slot_led[5]) |
//                        (seg_g & slot_led[6]));

//     // -------------------------------------------------------
//     // PIXEL COMPOSITOR  ‚Äî text takes priority over flag
//     // -------------------------------------------------------
//     wire [5:0] green = 6'b001100;
//     wire [5:0] black = 6'b000000;

//     wire r_out = text_pixel ? 1'b0 : flag_r;
//     wire g_out = text_pixel ? green[3] : flag_g;   // green[3]=1
//     wire b_out = text_pixel ? 1'b0 : flag_b;

//     // TinyVGA PMOD pinout
//     assign uo_out  = {hsync, b_out, g_out, r_out, vsync, b_out, g_out, r_out};
//     assign uio_out = 8'b00000000;
//     assign uio_oe  = 8'b00000000;

//     wire _unused_ok = &{ena, ui_in, uio_in};

// endmodule
