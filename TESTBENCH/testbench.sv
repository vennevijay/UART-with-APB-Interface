

`timescale 1ns/1ps

module tb_uart_apb;

  //----------------------------------------
  // Parameters
  //----------------------------------------
  localparam CLK_FREQ = 50_000_000;
  localparam BAUD     = 115200;
  localparam CLK_PERIOD = 20;

  //----------------------------------------
  // APB Interface
  //----------------------------------------
  reg         PCLK;
  reg         PRESETn;
  reg         PSEL;
  reg         PENABLE;
  reg         PWRITE;
  reg  [7:0]  PADDR;
  reg  [31:0] PWDATA;
  wire [31:0] PRDATA;
  wire        PREADY;

  //----------------------------------------
  // UART signals
  //----------------------------------------
  wire tx;
  wire rx;
  assign rx = tx; // loopback

  //----------------------------------------
  // DUT instance
  //----------------------------------------
  uart_apb #(
    .CLK_FREQ(CLK_FREQ),
    .BAUD(BAUD)
  ) dut (
    .PCLK(PCLK),
    .PRESETn(PRESETn),
    .PSEL(PSEL),
    .PENABLE(PENABLE),
    .PWRITE(PWRITE),
    .PADDR(PADDR),
    .PWDATA(PWDATA),
    .PRDATA(PRDATA),
    .PREADY(PREADY),
    .tx(tx),
    .rx(rx)
  );

  //----------------------------------------
  // Clock generation
  //----------------------------------------
  initial PCLK = 0;
  always #(CLK_PERIOD/2) PCLK = ~PCLK;

  //----------------------------------------
  // Reset
  //----------------------------------------
  initial begin
    PRESETn = 0;
    PSEL    = 0;
    PENABLE = 0;
    PWRITE  = 0;
    PADDR   = 0;
    PWDATA  = 0;
    #(10*CLK_PERIOD);
    PRESETn = 1;
    $display("[%0t] Reset deasserted.", $time);
  end

  //----------------------------------------
  // Monitor UART TX/RX changes
  //----------------------------------------
  initial begin
    $monitor("[%0t] TX=%b RX=%b tx_busy=%b rx_ready=%b tx_reg=0x%0h rx_reg=0x%0h",
              $time, tx, rx, dut.tx_busy, dut.rx_ready, dut.tx_reg, dut.rx_reg);
  end

  //----------------------------------------
  // APB Write
  //----------------------------------------
  task apb_write(input [7:0] addr, input [31:0] data);
    begin
      @(posedge PCLK);
      PSEL    <= 1;
      PWRITE  <= 1;
      PADDR   <= addr;
      PWDATA  <= data;
      PENABLE <= 0;

      @(posedge PCLK);
      PENABLE <= 1;
      @(posedge PCLK);
      PSEL    <= 0;
      PENABLE <= 0;
      PWRITE  <= 0;
      $display("[%0t] APB WRITE -> Addr:0x%0h Data:0x%0h", $time, addr, data);
    end
  endtask

  //----------------------------------------
  // APB Read
  //----------------------------------------
  task apb_read(input [7:0] addr, output [31:0] data);
    begin
      @(posedge PCLK);
      PSEL    <= 1;
      PWRITE  <= 0;
      PADDR   <= addr;
      PENABLE <= 0;

      @(posedge PCLK);
      PENABLE <= 1;
      @(posedge PCLK);
      data = PRDATA;
      PSEL    <= 0;
      PENABLE <= 0;
      $display("[%0t] APB READ  <- Addr:0x%0h Data:0x%0h", $time, addr, data);
    end
  endtask

  //----------------------------------------
  // Test Sequence
  //----------------------------------------
  reg [31:0] read_data;
  reg [7:0]  tx_byte;

  initial begin
    @(posedge PRESETn);
    #(5*CLK_PERIOD);

    $display("===== UART-APB LOOPBACK TEST START =====");

    tx_byte = 8'hA5; // Test byte
    $display("[%0t] Sending TX byte 0x%0h via APB...", $time, tx_byte);
    apb_write(8'h00, {24'b0, tx_byte});

    // Wait long enough for TX to finish and RX to complete
    #(1_000_000_000 / BAUD * 12);

    // Read received byte
    apb_read(8'h00, read_data);
    $display("[%0t] Received byte from RX reg = 0x%0h", $time, read_data[7:0]);

    // Check status
    apb_read(8'h04, read_data);
    $display("[%0t] Status Register = 0x%0h (tx_busy=%0b, rx_ready=%0b)",
              $time, read_data[1:0], read_data[0], read_data[1]);

    if (read_data[7:0] == tx_byte)
      $display("✅ TEST PASSED: TX=RX=0x%0h", tx_byte);
    else
      $display("❌ TEST FAILED: TX=0x%0h RX=0x%0h", tx_byte, read_data[7:0]);

    $display("===== TEST COMPLETE =====");
    $finish;
  end

  //----------------------------------------
  // Optional VCD Dump
  //----------------------------------------
  initial begin
    $dumpfile("uart_apb_tb.vcd");
    $dumpvars(0, tb_uart_apb);
  end

endmodule

