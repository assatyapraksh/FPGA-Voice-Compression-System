-------------------------------------------------
-- voice_compression_top.vhd  FIXED v3
--
-- ROOT CAUSE OF BUG:
-- adc_receiver data_valid ALWAYS fires when
-- LRCK=HIGH (after right channel completes).
-- So splitting by LRCK meant LEFT encoder
-- NEVER received a valid pulse!
--
-- FIX:
-- Both LEFT and RIGHT encoders triggered by
-- same data_valid_in pulse.
-- They process different data (left_data_in
-- vs right_data_in) independently.
-- Each encoder/decoder has its own internal
-- predicted and step_size state - so outputs
-- will correctly differ!
--
-- Active LOW reset
-------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY voice_compression_top IS
    PORT(
        clk              : IN  STD_LOGIC;
        rst              : IN  STD_LOGIC;
        en               : IN  STD_LOGIC;

        -- From adc_receiver
        left_data_in     : IN  STD_LOGIC_VECTOR(23 DOWNTO 0);
        right_data_in    : IN  STD_LOGIC_VECTOR(23 DOWNTO 0);
        data_valid_in    : IN  STD_LOGIC;

        -- To dac_transmitter
        left_data_out    : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
        right_data_out   : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
        data_valid_out   : OUT STD_LOGIC;

        -- Debug ports
        left_code_out    : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        right_code_out   : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        left_step_out    : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        right_step_out   : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
    );
END ENTITY voice_compression_top;

ARCHITECTURE rtl OF voice_compression_top IS

    COMPONENT adpcm_encoder IS
        PORT(
            clk        : IN  STD_LOGIC;
            rst        : IN  STD_LOGIC;
            en         : IN  STD_LOGIC;
            sample_in  : IN  STD_LOGIC_VECTOR(23 DOWNTO 0);
            sample_vld : IN  STD_LOGIC;
            code_out   : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            code_vld   : OUT STD_LOGIC;
            step_out   : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
        );
    END COMPONENT;

    COMPONENT adpcm_decoder IS
        PORT(
            clk        : IN  STD_LOGIC;
            rst        : IN  STD_LOGIC;
            en         : IN  STD_LOGIC;
            code_in    : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
            code_vld   : IN  STD_LOGIC;
            sample_out : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
            sample_vld : OUT STD_LOGIC
        );
    END COMPONENT;

    -- LEFT channel signals
    SIGNAL left_code_i      : STD_LOGIC_VECTOR(3 DOWNTO 0)  := (OTHERS => '0');
    SIGNAL left_code_vld_i  : STD_LOGIC := '0';
    SIGNAL left_step_i      : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL left_out_i       : STD_LOGIC_VECTOR(23 DOWNTO 0) := (OTHERS => '0');
    SIGNAL left_out_vld_i   : STD_LOGIC := '0';

    -- RIGHT channel signals
    SIGNAL right_code_i     : STD_LOGIC_VECTOR(3 DOWNTO 0)  := (OTHERS => '0');
    SIGNAL right_code_vld_i : STD_LOGIC := '0';
    SIGNAL right_step_i     : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL right_out_i      : STD_LOGIC_VECTOR(23 DOWNTO 0) := (OTHERS => '0');
    SIGNAL right_out_vld_i  : STD_LOGIC := '0';

    -- Shared valid - both encoders fire together
    -- They process DIFFERENT data (left vs right)
    -- but same timing - that is correct!
    SIGNAL enc_vld_i        : STD_LOGIC := '0';

    -- Output registers
    SIGNAL left_reg         : STD_LOGIC_VECTOR(23 DOWNTO 0) := (OTHERS => '0');
    SIGNAL right_reg        : STD_LOGIC_VECTOR(23 DOWNTO 0) := (OTHERS => '0');
    SIGNAL dv_out_i         : STD_LOGIC := '0';

BEGIN

    -- Debug outputs
    left_code_out  <= left_code_i;
    right_code_out <= right_code_i;
    left_step_out  <= left_step_i;
    right_step_out <= right_step_i;

    -- Data outputs
    left_data_out  <= left_reg;
    right_data_out <= right_reg;
    data_valid_out <= dv_out_i;

    -------------------------------------------------
    -- Valid generation:
    -- Single pulse when adc_receiver has new data
    -- Both encoders process simultaneously -
    -- they differ because their inputs differ!
    -------------------------------------------------
    VLD_GEN : PROCESS(clk, rst)
    BEGIN
        IF rst = '0' THEN
            enc_vld_i <= '0';
        ELSIF rising_edge(clk) THEN
            enc_vld_i <= '0';
            IF en = '1' AND data_valid_in = '1' THEN
                enc_vld_i <= '1';
            END IF;
        END IF;
    END PROCESS;

    -------------------------------------------------
    -- U1: LEFT ENCODER
    -- Processes left_data_in → 4-bit code
    -------------------------------------------------
    U1_LEFT_ENC : adpcm_encoder
        PORT MAP(
            clk        => clk,
            rst        => rst,
            en         => en,
            sample_in  => left_data_in,
            sample_vld => enc_vld_i,
            code_out   => left_code_i,
            code_vld   => left_code_vld_i,
            step_out   => left_step_i
        );

    -------------------------------------------------
    -- U2: LEFT DECODER
    -- Reconstructs left audio from 4-bit code
    -------------------------------------------------
    U2_LEFT_DEC : adpcm_decoder
        PORT MAP(
            clk        => clk,
            rst        => rst,
            en         => en,
            code_in    => left_code_i,
            code_vld   => left_code_vld_i,
            sample_out => left_out_i,
            sample_vld => left_out_vld_i
        );

    -------------------------------------------------
    -- U3: RIGHT ENCODER
    -- Processes right_data_in → 4-bit code
    -------------------------------------------------
    U3_RIGHT_ENC : adpcm_encoder
        PORT MAP(
            clk        => clk,
            rst        => rst,
            en         => en,
            sample_in  => right_data_in,
            sample_vld => enc_vld_i,
            code_out   => right_code_i,
            code_vld   => right_code_vld_i,
            step_out   => right_step_i
        );

    -------------------------------------------------
    -- U4: RIGHT DECODER
    -- Reconstructs right audio from 4-bit code
    -------------------------------------------------
    U4_RIGHT_DEC : adpcm_decoder
        PORT MAP(
            clk        => clk,
            rst        => rst,
            en         => en,
            code_in    => right_code_i,
            code_vld   => right_code_vld_i,
            sample_out => right_out_i,
            sample_vld => right_out_vld_i
        );

    -------------------------------------------------
    -- Output latch process
    -- Captures L and R decoder outputs
    -- Asserts data_valid_out when both ready
    -------------------------------------------------
    OUT_LATCH : PROCESS(clk, rst)
        VARIABLE left_ready  : STD_LOGIC := '0';
        VARIABLE right_ready : STD_LOGIC := '0';
    BEGIN
        IF rst = '0' THEN
            left_reg    <= (OTHERS => '0');
            right_reg   <= (OTHERS => '0');
            dv_out_i    <= '0';
            left_ready  := '0';
            right_ready := '0';
        ELSIF rising_edge(clk) THEN
            dv_out_i <= '0';

            IF left_out_vld_i = '1' THEN
                left_reg  <= left_out_i;
                left_ready := '1';
            END IF;

            IF right_out_vld_i = '1' THEN
                right_reg  <= right_out_i;
                right_ready := '1';
            END IF;

            IF left_ready = '1' AND right_ready = '1' THEN
                dv_out_i    <= '1';
                left_ready  := '0';
                right_ready := '0';
            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE rtl;