
`timescale 1ns/1ns

module top(
   input  wire          CLK,                  // Oscillator
   input  wire          RESETn,
   // Debug
   input  wire          TDI,                  // JTAG TDI
   input  wire          TCK,                  // SWD Clk / JTAG TCK
   inout  wire          TMS,                  // SWD I/O / JTAG TMS
   output wire          TDO,                   // SWV     / JTAG TDO


  //peripherals ports

  inout  wire  [7:0]    b_pad_gpio_porta,
  output wire  [9:2]    LEDR_OFF,

  input  wire           uart1_rxd,
  output wire           uart1_txd,

  input  wire           uart2_rxd,
  output wire           uart2_txd,

    // Timer
  input  wire           timer0_extin,
  input  wire           timer1_extin,

  input  wire           i2s_sd,
  output wire           i2s_sck,
  output wire           i2s_ws,

  output wire           SDRAM_CLK,
  output wire           SDRAM_CKE,
  output wire           SDRAM_CSn,
  output wire           SDRAM_RASn,
  output wire           SDRAM_CASn,
  output wire           SDRAM_WEn,
  output wire  [12:0]   SDRAM_ADDR,
  output wire  [1:0]    SDRAM_BA,
  inout  wire  [15:0]   SDRAM_DQ,
  output wire  [1:0]    SDRAM_DQM

);

   assign LEDR_OFF = 8'd0;

   wire [31:0]apb_int;
   wire  [239:0] irq = {208'b0000_0000_0000_0000, apb_int};
   wire          HCLK;
   wire          clk100_unused;

   


    //Internal wires
    //
    //
   /////////////////////////////////////////////////////////////////////////////
   // Connect Code Bus to ROM
   /////////////////////////////////////////////////////////////////////////////

   // CPU I-Code bus
   wire   [31:0] haddri;
   wire    [1:0] htransi;
   wire    [2:0] hsizei;
   wire    [2:0] hbursti;
   wire    [3:0] hproti;
   wire    [1:0] memattri;
   wire   [31:0] hrdatai;
   wire          hreadyi;


   // CPU D-Code bus
   wire   [31:0] haddrd;
   wire    [1:0] htransd;
   wire    [1:0] hmasterd;
   wire    [2:0] hsized;
   wire    [2:0] hburstd;
   wire    [3:0] hprotd;
   wire    [1:0] memattrd;
   wire   [31:0] hwdatad;
   wire          hwrited;
   wire          exreqd;
   wire   [31:0] hrdatad;
   wire          hreadyd;
 
   wire          exrespd = 1'b0;

  
   /////////////////////////////////////////////////////////////////////////////
   // Connect System Bus to RAM and Peripherals
   /////////////////////////////////////////////////////////////////////////////

   // CPU System bus
   wire   [31:0] haddrs; 
   wire    [2:0] hbursts; 
   wire          hmastlocks; 
   wire    [3:0] hprots; 
   wire    [2:0] hsizes; 
   wire    [1:0] htranss; 
   wire   [31:0] hwdatas; 
   wire          hwrites; 
   wire   [31:0] hrdatas; 
   wire          hreadys; 

   wire          exresps = 1'b0;


   /////////////////////////////////////////////////////////////////////////////
   // Debug Signals
   /////////////////////////////////////////////////////////////////////////////

   // Debug signals (TDO pin is used for SWV unless JTAG mode is active)
   wire          dbg_tdo;                    // SWV / JTAG TDO
   wire          dbg_tdo_nen;                // SWV / JTAG TDO tristate enable (active low)
   wire          dbg_swdo;                   // SWD I/O 3-state output
   wire          dbg_swdo_en;                // SWD I/O 3-state enable
   wire          dbg_jtag_nsw;               // SWD in JTAG state (HIGH)
   wire          dbg_swo;                    // Serial wire viewer/output
   wire          tdo_enable     = !dbg_tdo_nen | !dbg_jtag_nsw;
   wire          tdo_tms        = dbg_jtag_nsw         ? dbg_tdo    : dbg_swo;
   assign        TMS            = dbg_swdo_en          ? dbg_swdo   : 1'bz;
   assign        TDO            = tdo_enable           ? tdo_tms    : 1'bz;

   // CoreSight requires a loopback from REQ to ACK for a minimal
   // debug power control implementation
   wire          cpu0cdbgpwrupreq;          // Debug Power Domain up request
   wire          cpu0cdbgpwrupack;          // Debug Power Domain up acknowledge
   assign        cpu0cdbgpwrupack = cpu0cdbgpwrupreq;

     //BusMatrix
  
    // output port mi0
    wire         hselmi0;          // slave select
    wire  [31:0] haddrmi0;         // address bus
    wire   [1:0] htransmi0;        // transfer type
    wire         hwritemi0;        // transfer direction
    wire   [2:0] hsizemi0;         // transfer size
    wire   [2:0] hburstmi0;        // burst type
    wire   [3:0] hprotmi0;         // protection control
    wire   [3:0] hmastermi0;       // master select
    wire  [31:0] hwdatami0;        // write data
    wire         hmastlockmi0;     // locked sequence
    wire         hreadymuxmi0;     // transfer done

    wire  [31:0] hrdatami0;        // read data bus
    wire         hreadyoutmi0;     // hready feedback
    wire   [1:0] hrespmi0;         // transfer response
    wire  [31:0] hausermi0;        // address user signals
    wire  [31:0] hwusermi0;        // write-data usER signals
    wire  [31:0] hrusermi0;        // read-data useR signals

    // output port mi1
    wire         hselmi1;          // slave select
    wire  [31:0] haddrmi1;         // address bus
    wire   [1:0] htransmi1;        // transfer type
    wire         hwritemi1;        // transfer direction
    wire   [2:0] hsizemi1;         // transfer size
    wire   [2:0] hburstmi1;        // burst type
    wire   [3:0] hprotmi1;         // protection control
    wire   [3:0] hmastermi1;       // master select
    wire  [31:0] hwdatami1;        // write data
    wire         hmastlockmi1;     // locked sequence
    wire         hreadymuxmi1;     // transfer done

    wire  [31:0] hrdatami1;        // read data bus
    wire         hreadyoutmi1;     // hready feedback
    wire   [1:0] hrespmi1;         // transfer response
    wire  [31:0] hausermi1;        // address user signals
    wire  [31:0] hwusermi1;        // write-data usER signals
    wire  [31:0] hrusermi1;        // read-data useR signals

    // output port mi2
    wire         hselmi2;          // slave select
    wire  [31:0] haddrmi2;         // address bus
    wire   [1:0] htransmi2;        // transfer type
    wire         hwritemi2;        // transfer direction
    wire   [2:0] hsizemi2;         // transfer size
    wire   [2:0] hburstmi2;        // burst type
    wire   [3:0] hprotmi2;         // protection control
    wire   [3:0] hmastermi2;       // master select
    wire  [31:0] hwdatami2;        // write data
    wire         hmastlockmi2;     // locked sequence
    wire         hreadymuxmi2;     // transfer done

    wire  [31:0] hrdatami2;        // read data bus
    wire         hreadyoutmi2;     // hready feedback
    wire   [1:0] hrespmi2;         // transfer response
    wire  [31:0] hausermi2;        // address user signals
    wire  [31:0] hwusermi2;        // write-data usER signal
    wire  [31:0] hrusermi2;        // read-data useR signals

    // output port mi3
    wire         hselmi3;          // slave select
    wire  [31:0] haddrmi3;         // address bus
    wire   [1:0] htransmi3;        // transfer type
    wire         hwritemi3;        // transfer direction
    wire   [2:0] hsizemi3;         // transfer size
    wire   [2:0] hburstmi3;        // burst type
    wire   [3:0] hprotmi3;         // protection control
    wire   [3:0] hmastermi3;       // master select
    wire  [31:0] hwdatami3;        // write data
    wire         hmastlockmi3;     // locked sequence
    wire         hreadymuxmi3;     // transfer done

    wire  [31:0] hrdatami3;        // read data bus
    wire         hreadyoutmi3;     // hready feedback
    wire   [1:0] hrespmi3;         // transfer response
    wire  [31:0] hausermi3;        // address user signals
    wire  [31:0] hwusermi3;        // write-data usER signal
    wire  [31:0] hrusermi3;        // read-data useR signals

    wire         i2s_irq;



   /////////////////////////////////////////////////////////////////////////////
   // Cortex-M0 Core
   /////////////////////////////////////////////////////////////////////////////

   // DesignStart simplified integration level
   CORTEXM3INTEGRATIONDS u_CORTEXM3INTEGRATION (
      // Inputs
      .ISOLATEn       (1'b1),               // Active low to isolate core power domain
      .RETAINn        (1'b1),               // Active low to retain core state during power-down

      // Resets
      .PORESETn       (RESETn),            // Power on reset - reset processor and debugSynchronous to FCLK and HCLK
      .SYSRESETn      (RESETn),      // System reset   - reset processor onlySynchronous to FCLK and HCLK
      .RSTBYPASS      (1'b0),               // Reset bypass - active high to disable internal generated reset for testing (e.gATPG)
      .CGBYPASS       (1'b0),               // Clock gating bypass - active high to disable internal clock gating for testing
      .SE             (1'b0),               // DFT is tied off in this example

      // Clocks
      .FCLK           (HCLK),              // Free running clock - NVIC, SysTick, debug
      .HCLK           (HCLK),              // System clock - AHB, processor
                                            // it is separated so that it can be gated off when no debugger is attached
      .TRACECLKIN     (1'B0),               // Trace clock input.  REVISIT, does it want its own named signal as an input?
      // SysTick
      .STCLK          (HCLK),              // External reference clock for SysTick (Not really a clock, it is sampled by DFF)
                                            // Must be synchronous to FCLK or tied when no alternative clock source
      .STCALIB        ({1'b1,               // No alternative clock source
                        1'b0,               // Exact multiple of 10ms from FCLK
                        24'h03D090}),       // 10 ms calibration value for 25 MHz source

      .AUXFAULT       ({32{1'b0}}),         // Auxiliary Fault Status Register inputs: Connect to fault status generating logic
                                            // if required. Result appears in the Auxiliary Fault Status Register at address
                                            // 0xE000ED3C. A one-cycle pulse of information results in the information being stored
                                            // in the corresponding bit until a write-clear occurs.

      // Configuration - system
      .BIGEND         (1'b0),               // Select when exiting system reset - Peripherals in this system do not support BIGEND
      .DNOTITRANS     (1'b1),               // I-CODE & D-CODE merging configuration.
                                            // This disable I-CODE from generating a transfer when D-CODE bus need a transfer
                                            // Must be HIGH when using the Designstart system

      // SWJDAP signal for single processor mode
      .nTRST          (1'b1),               // JTAG TAP Reset
      .SWCLKTCK       (TCK),                // SW/JTAG Clock
      .SWDITMS        (TMS),                // SW Debug Data In / JTAG Test Mode Select
      .TDI            (TDI),                // JTAG TAP Data In / Alternative input function
      .CDBGPWRUPACK   (cpu0cdbgpwrupack),   // Debug Power Domain up acknowledge.

      // IRQs
      .INTISR         (irq[239:0]),         // Interrupts
      .INTNMI         (1'b0),               // Non-maskable Interrupt

      // I-CODE Bus
      .HREADYI        (hreadyi),            // I-CODE bus ready
      .HRDATAI        (hrdatai),            // I-CODE bus read data
      .HRESPI         (2'b00),             // I-CODE bus response
      .IFLUSH         (1'b0),               // Prefetch flush - fixed when using the Designstart system

      // D-CODE Bus
      .HREADYD        (hreadyd),            // D-CODE bus ready
      .HRDATAD        (hrdatad),            // D-CODE bus read data
      .HRESPD         (2'b00),             // D-CODE bus response
      .EXRESPD        (exrespd),            // D-CODE bus exclusive response

      // System Bus
      .HREADYS        (hreadys),            // System bus ready
      .HRDATAS        (hrdatas),            // System bus read data
      .HRESPS         (2'b00),             // System bus response
      .EXRESPS        (exresps),            // System bus exclusive response

      // Sleep
      .RXEV           (1'b0),               // Receive Event input
      .SLEEPHOLDREQn  (1'b1),               // Extend Sleep request

      // External Debug Request
      .EDBGRQ         (1'b0),               // External Debug request to CPU
      .DBGRESTART     (1'b0),               // Debug Restart request - Not needed in a single CPU system

      // DAP HMASTER override
      .FIXMASTERTYPE  (1'b0),               // Tie High to override HMASTER for AHB-AP accesses

      // WIC
      .WICENREQ       (1'b0),               // Active HIGH request for deep sleep to be WIC-based deep sleep
                                            // This should be driven from a PMU

      // Timestamp interface
      .TSVALUEB       ({48{1'b0}}),         // Binary coded timestamp value for trace - Trace is not used in this course
      // Timestamp clock ratio change is rarely used

      // Configuration - debug
      .DBGEN          (1'b1),               // Halting Debug Enable
      .NIDEN          (1'b1),               // Non-invasive debug enable for ETM
      .MPUDISABLE     (1'b0),               // Tie high to emulate processor with no MPU

      // SWJDAP signal for single processor mode
      .TDO            (dbg_tdo),            // JTAG TAP Data Out // REVISIT needs mux for SWV
      .nTDOEN         (dbg_tdo_nen),        // TDO enable
      .CDBGPWRUPREQ   (cpu0cdbgpwrupreq),   // Debug Power Domain up request
      .SWDO           (dbg_swdo),           // SW Data Out
      .SWDOEN         (dbg_swdo_en),        // SW Data Out Enable
      .JTAGNSW        (dbg_jtag_nsw),       // JTAG/not Serial Wire Mode

      // Single Wire Viewer
      .SWV            (dbg_swo),            // SingleWire Viewer Data

      // TPIU signals for single processor mode
      .TRACECLK       (),                   // TRACECLK output
      .TRACEDATA      (),                   // Trace Data

      // CoreSight AHB Trace Macrocell (HTM) bus capture interface
      // Connected here for visibility but usually not used in SoC.
      .HTMDHADDR      (),                   // HTM data HADDR
      .HTMDHTRANS     (),                   // HTM data HTRANS
      .HTMDHSIZE      (),                   // HTM data HSIZE
      .HTMDHBURST     (),                   // HTM data HBURST
      .HTMDHPROT      (),                   // HTM data HPROT
      .HTMDHWDATA     (),                   // HTM data HWDATA
      .HTMDHWRITE     (),                   // HTM data HWRITE
      .HTMDHRDATA     (),                   // HTM data HRDATA
      .HTMDHREADY     (),                   // HTM data HREADY
      .HTMDHRESP      (),                   // HTM data HRESP

      // AHB I-Code bus
      .HADDRI         (haddri),             // I-CODE bus address
      .HTRANSI        (htransi),            // I-CODE bus transfer type
      .HSIZEI         (hsizei),             // I-CODE bus transfer size
      .HBURSTI        (hbursti),            // I-CODE bus burst length
      .HPROTI         (hproti),             // i-code bus protection
      .MEMATTRI       (memattri),           // I-CODE bus memory attributes

      // AHB D-Code bus
      .HADDRD         (haddrd),             // D-CODE bus address
      .HTRANSD        (htransd),            // D-CODE bus transfer type
      .HSIZED         (hsized),             // D-CODE bus transfer size
      .HWRITED        (hwrited),            // D-CODE bus write not read
      .HBURSTD        (hburstd),            // D-CODE bus burst length
      .HPROTD         (hprotd),             // D-CODE bus protection
      .MEMATTRD       (memattrd),           // D-CODE bus memory attributes
      .HMASTERD       (hmasterd),           // D-CODE bus master
      .HWDATAD        (hwdatad),            // D-CODE bus write data
      .EXREQD         (exreqd),             // D-CODE bus exclusive request

      // AHB System bus
      .HADDRS         (haddrs),             // System bus address
      .HTRANSS        (htranss),            // System bus transfer type
      .HSIZES         (hsizes),             // System bus transfer size
      .HWRITES        (hwrites),            // System bus write not read
      .HBURSTS        (hbursts),            // System bus burst length
      .HPROTS         (hprots),             // System bus protection
      .HMASTLOCKS     (hmastlocks),         // System bus lock
      .MEMATTRS       (),                   // System bus memory attributes
      .HMASTERS       (),                   // System bus master
      .HWDATAS        (hwdatas),            // System bus write data
      .EXREQS         (),                   // System bus exclusive request

      // Status
      .BRCHSTAT       (),                   // Branch State
      .HALTED         (),                   // The processor is halted
      .DBGRESTARTED   (),                   // Debug Restart interface handshaking
      .LOCKUP         (lockup),             // The processor is locked up
      .SLEEPING       (),                   // The processor is in sleep mdoe (sleep/deep sleep)
      .SLEEPDEEP      (),                   // The processor is in deep sleep mode
      .SLEEPHOLDACKn  (),                   // Acknowledge for SLEEPHOLDREQn
      .ETMINTNUM      (),                   // Current exception number
      .ETMINTSTAT     (),                   // Exception/Interrupt activation status
      .CURRPRI        (),                   // Current exception priority
      .TRCENA         (),                   // Trace Enable

      // Reset Request
      .SYSRESETREQ    (),      // System Reset Request

      // Events
      .TXEV           (),                   // Transmit Event

      // Clock gating control
      .GATEHCLK       (),                   // when high, HCLK can be turned off

      .WAKEUP         (),                   // Active HIGH signal from WIC to the PMU that indicates a wake-up event has
                                            // occurred and the system requires clocks and power
      .WICENACK       ()                    // Acknowledge for WICENREQ - WIC operation deep sleep mode
   );


   //BusMatrix instantiation

   BusMatrix4x4 u_BusMatrix4x4 (

    // Common AHB signals
    .HCLK		(HCLK),
    .HRESETn		(RESETn),

    // System address remapping control
    .REMAP		({4{1'b0}}),

    // Input port SI0 (inputs from master 0)
    .HSELS0			(htranss[1]),
    .HADDRS0			(haddrs),
    .HTRANSS0		(htranss),
    .HWRITES0		(hwrites),
    .HSIZES0			(hsizes),
    .HBURSTS0		(hbursts),
    .HPROTS0			(hprots),
    .HMASTERS0		(4'b0000),
    .HWDATAS0		(hwdatas),
    .HMASTLOCKS0	(1'b0),
    .HREADYS0		(hreadys),
    .HAUSERS0		({32{1'b0}}),
    .HWUSERS0		({32{1'b0}}),

    
    // Input port SI1 (inputs from master 1)
    .HSELS1			(htransd[1]),
    .HADDRS1			(haddrd),
    .HTRANSS1		(htransd),
    .HWRITES1		(hwrited),
    .HSIZES1			(hsized),
    .HBURSTS1		(hburstd),
    .HPROTS1			(hprotd),
    .HMASTERS1		(4'b0001),
    .HWDATAS1		(hwdatad),
    .HMASTLOCKS1	(1'b0),
    .HREADYS1		(hreadyd),
    .HAUSERS1		({32{1'b0}}),
    .HWUSERS1		({32{1'b0}}),

    // Input port SI2 (inputs from master 2)
    .HSELS2			(htransi[1]),
    .HADDRS2			(haddri),
    .HTRANSS2		(htransi),
    .HWRITES2		(1'b0),
    .HSIZES2			(hsizei),
    .HBURSTS2		(hbursti),
    .HPROTS2			(hproti),
    .HMASTERS2		(4'b0010),
    .HWDATAS2		({32{1'b0}}),
    .HMASTLOCKS2	(1'b0),
    .HREADYS2		(hreadyi),
    .HAUSERS2		({32{1'b0}}),
    .HWUSERS2		({32{1'b0}}),

    // Input port SI3 (unused master)
    .HSELS3			(1'b0),
    .HADDRS3			(32'h0000_0000),
    .HTRANSS3		(2'b00),
    .HWRITES3		(1'b0),
    .HSIZES3			(3'b010),
    .HBURSTS3		(3'b000),
    .HPROTS3			(4'b0011),
    .HMASTERS3		(4'b0011),
    .HWDATAS3		(32'h0000_0000),
    .HMASTLOCKS3	(1'b0),
    .HREADYS3		(1'b1),
    .HAUSERS3		({32{1'b0}}),
    .HWUSERS3		({32{1'b0}}),


    // Output port MI0 (inputs from slave 0)
    .HRDATAM0		(hrdatami0),
    .HREADYOUTM0	(hreadyoutmi0),
    .HRESPM0			(hrespmi0),
    .HRUSERM0		(32'b0),

    // Output port MI1 (inputs from slave 1)
    .HRDATAM1		(hrdatami1),
    .HREADYOUTM1	(hreadyoutmi1),
    .HRESPM1			(hrespmi1),
    .HRUSERM1		(32'b0),

    // Output port MI2 (inputs from slave 2)
    .HRDATAM2		(hrdatami2),
    .HREADYOUTM2	(hreadyoutmi2),
    .HRESPM2			(hrespmi2),
    .HRUSERM2		(32'b0),

    // Output port MI3 (inputs from I2S FIFO slave)
    .HRDATAM3		(hrdatami3),
    .HREADYOUTM3	(hreadyoutmi3),
    .HRESPM3			(hrespmi3),
    .HRUSERM3		(32'b0),

    // Scan test dummy signals; not connected until scan insertion
    .SCANENABLE		(1'b0),   // Scan Test Mode Enable
    .SCANINHCLK		(1'b0),   // Scan Chain Input


    // Output port MI0 (outputs to slave 0)
    .HSELM0			(hselmi0		),
    .HADDRM0			(haddrmi0		),
    .HTRANSM0		(htransmi0	),
    .HWRITEM0		(hwritemi0	),
    .HSIZEM0			(hsizemi0		),
    .HBURSTM0		(hburstmi0	),
    .HPROTM0			(hprotmi0		),
    .HMASTERM0		(hmastermi0	),
    .HWDATAM0		(hwdatami0	),
    .HMASTLOCKM0	(hmastlockmi0),
    .HREADYMUXM0	(hreadymuxmi0	),
    .HAUSERM0		(hausermi0	),
    .HWUSERM0		(hwusermi0	),

    // Output port MI1 (outputs to slave 1)
    .HSELM1			(hselmi1		),
    .HADDRM1			(haddrmi1		),
    .HTRANSM1		(htransmi1	),
    .HWRITEM1		(hwritemi1	),
    .HSIZEM1			(hsizemi1		),
    .HBURSTM1		(hburstmi1	),
    .HPROTM1			(hprotmi1		),
    .HMASTERM1		(hmastermi1	),
    .HWDATAM1		(hwdatami1	),
    .HMASTLOCKM1	(hmastlockmi1),
    .HREADYMUXM1	(hreadymuxmi1	),
    .HAUSERM1		(hausermi1	),
    .HWUSERM1		(hwusermi1	),

    // Output port MI2 (outputs to slave 2)
    .HSELM2			(hselmi2		),
    .HADDRM2			(haddrmi2		),
    .HTRANSM2		(htransmi2	),
    .HWRITEM2		(hwritemi2	),
    .HSIZEM2			(hsizemi2		),
    .HBURSTM2		(hburstmi2	),
    .HPROTM2			(hprotmi2		),
    .HMASTERM2		(hmastermi2	),
    .HWDATAM2		(hwdatami2	),
    .HMASTLOCKM2	(hmastlockmi2),
    .HREADYMUXM2	(hreadymuxmi2	),
    .HAUSERM2		(hausermi2	),
    .HWUSERM2		(hwusermi2	),

    // Output port MI3 (outputs to I2S FIFO slave)
    .HSELM3			(hselmi3		),
    .HADDRM3			(haddrmi3		),
    .HTRANSM3		(htransmi3	),
    .HWRITEM3		(hwritemi3	),
    .HSIZEM3			(hsizemi3		),
    .HBURSTM3		(hburstmi3	),
    .HPROTM3			(hprotmi3		),
    .HMASTERM3		(hmastermi3	),
    .HWDATAM3		(hwdatami3	),
    .HMASTLOCKM3	(hmastlockmi3),
    .HREADYMUXM3	(hreadymuxmi3	),
    .HAUSERM3		(hausermi3	),
    .HWUSERM3		(hwusermi3	),

    // Input port SI0 (outputs to master 0)
    .HRDATAS0		(hrdatas		),
    .HREADYOUTS0	(hreadys		),
    .HRESPS0			(),
    .HRUSERS0		(),

    // Input port SI1 (outputs to master 1)
    .HRDATAS1		(hrdatad		),
    .HREADYOUTS1	(hreadyd		),
    .HRESPS1			(),
    .HRUSERS1		(),

     // Input port SI2 (outputs to master 2)
    .HRDATAS2		(hrdatai		),
    .HREADYOUTS2	(hreadyi		),
    .HRESPS2			(),
    .HRUSERS2		(),

    // Input port SI3 (outputs to unused master)
    .HRDATAS3		(),
    .HREADYOUTS3	(),
    .HRESPS3			(),
    .HRUSERS3		(),

    // Scan test dummy signals; not connected until scan insertion
    .SCANOUTHCLK	()  
);

//SRAM instantiation

AHB2MEM
   #(16)  U_SRAM 
   (
   .HSEL			(hselmi0		),
   .HCLK			(HCLK				),
   .HRESETn		(RESETn			),
   .HREADY		(hreadymuxmi0	),
   .HADDR			(haddrmi0		),
   .HTRANS		(htransmi0	),
   .HWRITE		(hwritemi0	),
   .HSIZE			(hsizemi0		),
   .HWDATA		(hwdatami0	),
   .HREADYOUT	(hreadyoutmi0),
   .HRDATA		(hrdatami0	)
   );
   
assign hrespmi0[1:0]=2'b0;

//apb_subsystem instantiation
cmsdk_apb_subsystem    u_apb_subsystem(
	.HCLK						(HCLK				),
	.HRESETn				(RESETn			),
              		             
	.HSEL						(hselmi1		),
	.HADDR					(haddrmi1[15:0]),
	.HTRANS					(htransmi1	),
	.HWRITE					(hwritemi1	),
	.HSIZE					(hsizemi1		),
	.HPROT					(hprotmi1		),
	.HREADY					(hreadymuxmi1	),
	.HWDATA					(hwdatami1	),
              		                   
	.HREADYOUT			(hreadyoutmi1),
	.HRDATA					(hrdatami1	),
	.HRESP					(hrespmi1[0]),
                                                
	.PCLK						(HCLK				),    
	.PCLKG					(HCLK				),  
	.PCLKEN					(1'b1				),  
	.PRESETn				(RESETn			),
	
	// Fixed: Connect unused APB output ports to avoid warnings
	.PADDR					(),            // APB address output (debug only)
	.PWRITE					(),            // APB write signal (debug only)
	.PWDATA					(),            // APB write data (debug only)
	.PENABLE				(),            // APB enable signal (debug only)
	.APBACTIVE				(),            // APB active indicator (power management)
                                     
	.ext12_psel			(),
	.ext13_psel			(),
	.ext14_psel			(),
	.ext15_psel			(),
                                     
	.ext12_prdata		(),
	.ext12_pready		(),
	.ext12_pslverr	(),
                                    
	.ext13_prdata		(),
	.ext13_pready		(),
	.ext13_pslverr	(),
                                       
	.ext14_prdata		(),
	.ext14_pready		(),
	.ext14_pslverr	(),
	                             
	.ext15_prdata		(),
	.ext15_pready		(),
	.ext15_pslverr	(),

	.b_pad_gpio_porta	(b_pad_gpio_porta[7:0]),
	                                       
	.uart1_rxd			(uart1_rxd		),
	.uart1_txd			(uart1_txd		),
	.uart1_txen			(uart1_txen		),
                	                                
	.uart2_rxd			(uart2_rxd		),
	.uart2_txd			(uart2_txd		),
	.uart2_txen			(uart2_txen		),
               
	.timer0_extin		(timer0_extin	),
	.timer1_extin		(timer1_extin	),
	.apbsubsys_interrupt (apb_int	),
	
	// Fixed: Connect unused watchdog signals (watchdog is disabled)
	.watchdog_interrupt	(),            // Watchdog interrupt (not used)
	.watchdog_reset		()             // Watchdog reset (not used)
	);

assign hrespmi1[1]=1'b0;

pll u_pll (
	.inclk0     (CLK),
	.c0         (SDRAM_CLK),
	.c1         (HCLK),
	.c2         (clk100_unused)
);

assign hrespmi2[1] = 1'b0;

ahb_lite_sdram u_ahb_lite_sdram (
	.HCLK       (HCLK),
	.HRESETn    (RESETn),
	.HADDR      (haddrmi2),
	.HBURST     (hburstmi2),
	.HMASTLOCK  (hmastlockmi2),
	.HPROT      (hprotmi2),
	.HSEL       (hselmi2),
	.HSIZE      (hsizemi2),
	.HTRANS     (htransmi2),
	.HWDATA     (hwdatami2),
	.HWRITE     (hwritemi2),
	.HREADY     (hreadymuxmi2),
	.HRDATA     (hrdatami2),
	.HREADYOUT  (hreadyoutmi2),
	.HRESP      (hrespmi2[0]),
	.SI_Endian  (1'b0),

	.CKE        (SDRAM_CKE),
	.CSn        (SDRAM_CSn),
	.RASn       (SDRAM_RASn),
	.CASn       (SDRAM_CASn),
	.WEn        (SDRAM_WEn),
	.ADDR       (SDRAM_ADDR),
	.BA         (SDRAM_BA),
	.DQ         (SDRAM_DQ),
	.DQM        (SDRAM_DQM)
);

ahb_i2s_fifo u_ahb_i2s_fifo (
	.HCLK       (HCLK),
	.HRESETn    (RESETn),
	.HSEL       (hselmi3),
	.HADDR      (haddrmi3),
	.HTRANS     (htransmi3),
	.HWRITE     (hwritemi3),
	.HSIZE      (hsizemi3),
	.HWDATA     (hwdatami3),
	.HREADY     (hreadymuxmi3),
	.HRDATA     (hrdatami3),
	.HREADYOUT  (hreadyoutmi3),
	.HRESP      (hrespmi3),

	.i2s_sd     (i2s_sd),
	.i2s_sck    (i2s_sck),
	.i2s_ws     (i2s_ws),
	.irq        (i2s_irq)
);

endmodule
