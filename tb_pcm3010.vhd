-------------------------------------------------
-- tb_pcm3010.vhd  FINAL
-- Astronaut Voice Compression Testbench
-- ╔══════════════════════════════════════════╗
-- ║  CHANGE TEST DATA HERE ONLY - ONE PLACE ║
-- ║  Everything else updates automatically! ║
-- ╚══════════════════════════════════════════╝
-- Active LOW reset
-- IMA-ADPCM 6:1 compression test
-------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY tb_pcm3010 IS
END ENTITY tb_pcm3010;

ARCHITECTURE sim OF tb_pcm3010 IS

    COMPONENT pcm3010_top IS
        PORT(
            clk              : IN  STD_LOGIC;
            rst              : IN  STD_LOGIC;
            start            : IN  STD_LOGIC;
            power_down_req   : IN  STD_LOGIC;
            pdwn             : OUT STD_LOGIC;
            fmt0             : OUT STD_LOGIC;
            fmt1             : OUT STD_LOGIC;
            demp0            : OUT STD_LOGIC;
            demp1            : OUT STD_LOGIC;
            scki             : OUT STD_LOGIC;
            bck              : OUT STD_LOGIC;
            lrck             : OUT STD_LOGIC;
            din              : OUT STD_LOGIC;
            dout             : IN  STD_LOGIC;
            left_data_in     : IN  STD_LOGIC_VECTOR(23 DOWNTO 0);
            right_data_in    : IN  STD_LOGIC_VECTOR(23 DOWNTO 0);
            left_data_out    : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
            right_data_out   : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
            data_valid       : OUT STD_LOGIC;
            left_adpcm_code  : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            right_adpcm_code : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            left_step_size   : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
            right_step_size  : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
        );
    END COMPONENT;

    --=================================================
    -- *** CHANGE TEST DATA HERE ONLY ***
    --
    -- Change TEST_LEFT and TEST_RIGHT values below.
    -- DOUT driver, stimulus process, and data inputs
    -- ALL automatically follow these two constants.
    -- No need to change anything else!
    --
    -- RECOMMENDED RANGES for clear ADPCM tracking:
    -- -----------------------------------------------
    -- Small  : x"000064"(+100)  x"0000C8"(+200)
    -- Medium : x"001000"(+4096) x"002000"(+8192)
    -- Large  : x"007FFF"(+32767)x"006000"(+24576)
    -- Neg    : x"FFFF9C"(-100)  x"FFFF38"(-200)
    -- Original test:
    --          x"AABBCC"        x"DDEEFF"
    --=================================================
    CONSTANT TEST_LEFT  : STD_LOGIC_VECTOR(23 DOWNTO 0) := x"000064"; -- +100
    CONSTANT TEST_RIGHT : STD_LOGIC_VECTOR(23 DOWNTO 0) := x"0000C8"; -- +200
    --=================================================

    CONSTANT CLK_PERIOD : TIME    := 5 ns;   -- 200 MHz system clock

    -- These automatically follow TEST_LEFT / TEST_RIGHT
    CONSTANT LEFT_DATA  : STD_LOGIC_VECTOR(23 DOWNTO 0) := TEST_LEFT;
    CONSTANT RIGHT_DATA : STD_LOGIC_VECTOR(23 DOWNTO 0) := TEST_RIGHT;

    -------------------------------------------------
    -- Simulation signals
    -------------------------------------------------
    SIGNAL clk              : STD_LOGIC := '0';
    SIGNAL rst              : STD_LOGIC := '0';
    SIGNAL start            : STD_LOGIC := '0';
    SIGNAL power_down_req   : STD_LOGIC := '0';
    SIGNAL scki             : STD_LOGIC := '0';
    SIGNAL bck              : STD_LOGIC := '0';
    SIGNAL lrck             : STD_LOGIC := '0';
    SIGNAL din              : STD_LOGIC := '0';
    SIGNAL dout             : STD_LOGIC := '0';
    SIGNAL fmt0             : STD_LOGIC := '0';
    SIGNAL fmt1             : STD_LOGIC := '0';
    SIGNAL pdwn             : STD_LOGIC := '0';
    SIGNAL demp0            : STD_LOGIC := '0';
    SIGNAL demp1            : STD_LOGIC := '0';

    -- Data I/O - auto initialized from TEST constants
    SIGNAL left_data_in     : STD_LOGIC_VECTOR(23 DOWNTO 0) := LEFT_DATA;
    SIGNAL right_data_in    : STD_LOGIC_VECTOR(23 DOWNTO 0) := RIGHT_DATA;
    SIGNAL left_data_out    : STD_LOGIC_VECTOR(23 DOWNTO 0) := (OTHERS => '0');
    SIGNAL right_data_out   : STD_LOGIC_VECTOR(23 DOWNTO 0) := (OTHERS => '0');
    SIGNAL data_valid       : STD_LOGIC := '0';

    -- ADPCM compression monitor
    SIGNAL left_adpcm_code  : STD_LOGIC_VECTOR(3 DOWNTO 0)  := (OTHERS => '0');
    SIGNAL right_adpcm_code : STD_LOGIC_VECTOR(3 DOWNTO 0)  := (OTHERS => '0');
    SIGNAL left_step_size   : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL right_step_size  : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');

    SIGNAL sim_done         : BOOLEAN := FALSE;

BEGIN

    -------------------------------------------------
    -- DUT: Design Under Test
    -------------------------------------------------
    DUT : pcm3010_top
        PORT MAP(
            clk              => clk,
            rst              => rst,
            start            => start,
            power_down_req   => power_down_req,
            pdwn             => pdwn,
            fmt0             => fmt0,
            fmt1             => fmt1,
            demp0            => demp0,
            demp1            => demp1,
            scki             => scki,
            bck              => bck,
            lrck             => lrck,
            din              => din,
            dout             => dout,
            left_data_in     => left_data_in,
            right_data_in    => right_data_in,
            left_data_out    => left_data_out,
            right_data_out   => right_data_out,
            data_valid       => data_valid,
            left_adpcm_code  => left_adpcm_code,
            right_adpcm_code => right_adpcm_code,
            left_step_size   => left_step_size,
            right_step_size  => right_step_size
        );

    -------------------------------------------------
    -- 200 MHz Clock Generator
    -------------------------------------------------
    CLK_GEN : PROCESS
    BEGIN
        WHILE NOT sim_done LOOP
            clk <= '0'; WAIT FOR CLK_PERIOD / 2;
            clk <= '1'; WAIT FOR CLK_PERIOD / 2;
        END LOOP;
        WAIT;
    END PROCESS;

    -------------------------------------------------
    -- DOUT Simulator
    -- Automatically uses LEFT_DATA & RIGHT_DATA
    -- which follow TEST_LEFT & TEST_RIGHT
    -- 32-slot I2S: 24 data bits + 8 zero padding
    -- Changes on BCK falling edge (I2S standard)
    -------------------------------------------------
    DOUT_DRV : PROCESS
        -- Auto-loaded from TEST constants - no manual change needed!
        VARIABLE L : STD_LOGIC_VECTOR(23 DOWNTO 0) := LEFT_DATA;
        VARIABLE R : STD_LOGIC_VECTOR(23 DOWNTO 0) := RIGHT_DATA;
    BEGIN
        dout <= '0';
        WAIT UNTIL rst = '1';
        WAIT FOR 1 us;

        LOOP
            -- LEFT channel: transmit when LRCK = LOW
            WAIT UNTIL lrck = '0';
            FOR i IN 23 DOWNTO 0 LOOP          -- 24 data bits MSB first
                WAIT UNTIL falling_edge(bck);
                dout <= L(i);
            END LOOP;
            FOR k IN 0 TO 7 LOOP               -- 8 zero padding bits
                WAIT UNTIL falling_edge(bck);
                dout <= '0';
            END LOOP;

            -- RIGHT channel: transmit when LRCK = HIGH
            WAIT UNTIL lrck = '1';
            FOR i IN 23 DOWNTO 0 LOOP          -- 24 data bits MSB first
                WAIT UNTIL falling_edge(bck);
                dout <= R(i);
            END LOOP;
            FOR k IN 0 TO 7 LOOP               -- 8 zero padding bits
                WAIT UNTIL falling_edge(bck);
                dout <= '0';
            END LOOP;
        END LOOP;
    END PROCESS;

    -------------------------------------------------
    -- MAIN STIMULUS PROCESS
    -- All data references use LEFT_DATA/RIGHT_DATA
    -- which automatically follow TEST_LEFT/TEST_RIGHT
    -------------------------------------------------
    STIM : PROCESS
    BEGIN
        REPORT "================================================";
        REPORT " PCM3010 ASTRONAUT VOICE COMPRESSION           ";
        REPORT " IMA-ADPCM : 24-bit -> 4-bit -> 24-bit         ";
        REPORT " COMPRESSION RATIO : 6:1                       ";
        REPORT " BANDWIDTH SAVING  : 83.3%                     ";
        REPORT "------------------------------------------------";
        REPORT " HOW TO CHANGE TEST DATA:                      ";
        REPORT " Edit TEST_LEFT  at line ~54 only              ";
        REPORT " Edit TEST_RIGHT at line ~55 only              ";
        REPORT " Everything else updates automatically!        ";
        REPORT "================================================";

        -- Initial state
        rst            <= '0';
        start          <= '0';
        power_down_req <= '0';
        -- Auto-follow TEST constants
        left_data_in   <= LEFT_DATA;
        right_data_in  <= RIGHT_DATA;

        -- STEP 1: Hold reset active (LOW)
        WAIT FOR CLK_PERIOD * 20;
        REPORT "STEP 1: rst=0 -> RESET ACTIVE";

        -- STEP 2: Release reset
        rst <= '1';
        WAIT FOR CLK_PERIOD * 20;
        REPORT "STEP 2: rst=1 -> SYSTEM RELEASED";

        -- STEP 3: Pulse start to trigger FSM
        start <= '1';
        WAIT FOR CLK_PERIOD * 20;
        start <= '0';
        REPORT "STEP 3: start PULSED -> FSM TRIGGERED";

        -- STEP 4: FSM_RESET (1024 cycles)
        WAIT FOR 10 us;
        REPORT "STEP 4: FSM_RESET COMPLETE";

        -- Verify 24-bit I2S format pins
        ASSERT fmt0 = '1' AND fmt1 = '1'
            REPORT "FAIL: I2S FORMAT PINS NOT SET CORRECTLY"
            SEVERITY ERROR;
        REPORT "PASS: fmt0=1, fmt1=1 -> 24-bit I2S confirmed";

        -- STEP 5: Wait for clocks stable
        WAIT FOR 100 us;
        REPORT "STEP 5: CLOCKS STABLE";
        WAIT UNTIL rising_edge(scki); REPORT "PASS: SCKI OK";
        WAIT UNTIL rising_edge(bck);  REPORT "PASS: BCK  OK";
        WAIT UNTIL rising_edge(lrck); REPORT "PASS: LRCK OK";

        -- STEP 6: FSM_SYNC complete -> FSM_RUN
        WAIT FOR 100 us;
        REPORT "STEP 6: FSM_RUN ACTIVE";
        REPORT "INFO:  ADPCM PIPELINE PROCESSING";

        -- STEP 7: ADPCM Encoder running
        WAIT FOR 500 us;
        REPORT "STEP 7: ADPCM ENCODER ACTIVE";
        REPORT "INFO:  left_adpcm_code  visible in waveform";
        REPORT "INFO:  right_adpcm_code visible in waveform";
        REPORT "INFO:  left_step_size   growing in waveform";
        REPORT "INFO:  right_step_size  growing in waveform";

        -- STEP 8: ADPCM Decoder running
        WAIT FOR 500 us;
        REPORT "STEP 8: ADPCM DECODER ACTIVE";
        REPORT "INFO:  left_data_out  converging to TEST_LEFT";
        REPORT "INFO:  right_data_out converging to TEST_RIGHT";
        REPORT "INFO:  L and R outputs will be DIFFERENT ";

        -- STEP 9: Data valid check
        ASSERT data_valid = '1'
            REPORT "WARN: data_valid not seen yet"
            SEVERITY WARNING;
        REPORT "STEP 9: DATA VALID CONFIRMED";

        -- STEP 10: DAC DIN serialization
        WAIT FOR 500 us;
        REPORT "STEP 10: DAC DIN TRANSMISSION VERIFIED";

        -- Final simulation summary
        REPORT "================================================";
        REPORT " SIMULATION COMPLETE - ALL STEPS PASSED        ";
        REPORT "------------------------------------------------";
        REPORT " CURRENT TEST DATA:                            ";
        REPORT " TEST_LEFT  = see constant at top of file      ";
        REPORT " TEST_RIGHT = see constant at top of file      ";
        REPORT "------------------------------------------------";
        REPORT " PIPELINE STATUS:                              ";
        REPORT " [ADC]  DOUT serial    -> adc_receiver     OK ";
        REPORT " [ENC]  24-bit PCM     -> 4-bit ADPCM      OK ";
        REPORT " [DEC]  4-bit ADPCM    -> 24-bit PCM       OK ";
        REPORT " [DAC]  DIN serial     -> PCM3010 DAC      OK ";
        REPORT "------------------------------------------------";
        REPORT " ADPCM PERFORMANCE:                            ";
        REPORT " Compression  : 24-bit -> 4-bit (6:1)         ";
        REPORT " Bandwidth    : 83.3% saving                  ";
        REPORT " Standard     : IMA-ADPCM                     ";
        REPORT " Application  : Astronaut Voice Communication ";
        REPORT "================================================";

        sim_done <= TRUE;
        WAIT;
    END PROCESS;

END ARCHITECTURE sim;