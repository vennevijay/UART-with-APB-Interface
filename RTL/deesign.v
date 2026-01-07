//--------------------------------------
// UART with APB Interface (Minimal)
//--------------------------------------
module uart_apb #(
  parameter CLK_FREQ = 50_000_000,   // system clock (Hz)
  parameter BAUD     = 115200        // baud rate
)(
  input  wire        PCLK,    // APB clock
  input  wire        PRESETn, // APB reset (active low)
  input  wire        PSEL,
  input  wire        PENABLE,
  input  wire        PWRITE,
  input  wire [7:0]  PADDR,
  input  wire [31:0] PWDATA,
  output reg  [31:0] PRDATA,
  output wire        PREADY,

  // UART signals
  output reg         tx,
  input  wire        rx
);

  //--------------------------------
  // APB ready always 1 (no wait)
  //--------------------------------
  assign PREADY = 1'b1;

  //--------------------------------
  // Registers
  //--------------------------------
  reg [7:0] tx_reg;    // TX data register
  reg [7:0] rx_reg;    // RX data register
  reg       tx_busy;
  reg       rx_ready;

  //--------------------------------
  // Baud generator
  //--------------------------------
  localparam DIV = CLK_FREQ / BAUD;
  reg [15:0] baud_cnt;
  reg baud_tick;

  always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      baud_cnt <= 0;
      baud_tick <= 0;
    end else begin
      if (baud_cnt == DIV/2) begin
        baud_cnt <= 0;
        baud_tick <= 1;
      end else begin
        baud_cnt <= baud_cnt + 1;
        baud_tick <= 0;
      end
    end
  end

  //--------------------------------
  // APB read/write
  //--------------------------------
  always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      tx_reg   <= 0;
      rx_reg   <= 0;
      rx_ready <= 0;
    end else if (PSEL & PENABLE) begin
      if (PWRITE) begin
        case (PADDR)
          8'h00: tx_reg <= PWDATA[7:0];  // write TX data
        endcase
      end else begin
        case (PADDR)
          8'h00: PRDATA <= {24'b0, rx_reg};
          8'h04: PRDATA <= {30'b0, rx_ready, tx_busy};
        endcase
      end
    end
  end

  //--------------------------------
  // UART TX logic
  //--------------------------------
  reg [9:0] tx_shift;
  reg [3:0] tx_cnt;

  always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      tx <= 1'b1; // idle high
      tx_busy <= 0;
      tx_cnt <= 0;
    end else if (!tx_busy && (PSEL & PENABLE & PWRITE & PADDR==8'h00)) begin
      tx_shift <= {1'b1, tx_reg, 1'b0}; // stop, data, start
      tx_cnt <= 0;
      tx_busy <= 1;
    end else if (tx_busy && baud_tick) begin
      tx <= tx_shift[0];
      tx_shift <= {1'b1, tx_shift[9:1]};
      tx_cnt <= tx_cnt + 1;
      if (tx_cnt == 9) tx_busy <= 0;
    end
  end

  //--------------------------------
  // UART RX logic (very simple)
  //--------------------------------
  // (Not robust, for learning/verification only)
  reg [9:0] rx_shift;
  reg [3:0] rx_cnt;
  reg rx_busy;

  always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      rx_reg <= 0;
      rx_ready <= 0;
      rx_busy <= 0;
    end else if (!rx_busy && !rx) begin
      rx_busy <= 1;  // start bit detected
      rx_cnt <= 0;
    end else if (rx_busy && baud_tick) begin
      rx_shift <= {rx, rx_shift[9:1]};
      rx_cnt <= rx_cnt + 1;
      if (rx_cnt == 9) begin
        rx_busy <= 0;
        rx_reg <= rx_shift[8:1];  // store data
        rx_ready <= 1;
      end
    end
  end

endmodule
