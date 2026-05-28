-------------------------------------------------
-- pcm3010_top.vhd  FIXED v3
-- voice_compression_top no longer needs lrck
-- Both L and R triggered by same data_valid
-------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY pcm3010_top IS
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
END ENTITY pcm3010_top;

ARCHITECTURE structural OF pcm3010_top IS

    COMPONENT clock_gen IS
        PORT(
            clk        : IN  STD_LOGIC;
            rst        : IN  STD_LOGIC;
            scki_out   : OUT STD_LOGIC;
            bck_out    : OUT STD_LOGIC;
            lrck_out   : OUT STD_LOGIC;
            clk_stable : OUT STD_LOGIC
        );
    END COMPONENT;

    COMPONENT fsm_controller IS
        PORT(
            clk            : IN  STD_LOGIC;
            rst            : IN  STD_LOGIC;
            start          : IN  STD_LOGIC;
            clk_stable     : IN  STD_LOGIC;
            rx_done        : IN  STD_LOGIC;
            tx_done        : IN  STD_LOGIC;
            power_down_req : IN  STD_LOGIC;
            pdwn           : OUT STD_LOGIC;
            fmt0           : OUT STD_LOGIC;
            fmt1           : OUT STD_LOGIC;
            demp0          : OUT STD_LOGIC;
            demp1          : OUT STD_LOGIC;
            rx_en          : OUT STD_LOGIC;
            tx_en          : OUT STD_LOGIC;
            clk_en         : OUT STD_LOGIC;
            rst_codec      : OUT STD_LOGIC
        );
    END COMPONENT;

    COMPONENT adc_receiver IS
        PORT(
            clk        : IN  STD_LOGIC;
            rst        : IN  STD_LOGIC;
            rx_en      : IN  STD_LOGIC;
            bck        : IN  STD_LOGIC;
            lrck       : IN  STD_LOGIC;
            dout       : IN  STD_LOGIC;
            left_data  : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
            right_data : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
            rx_done    : OUT STD_LOGIC;
            data_valid : OUT STD_LOGIC
        );
    END COMPONENT;

    COMPONENT voice_compression_top IS
        PORT(
            clk              : IN  STD_LOGIC;
            rst              : IN  STD_LOGIC;
            en               : IN  STD_LOGIC;
            left_data_in     : IN  STD_LOGIC_VECTOR(23 DOWNTO 0);
            right_data_in    : IN  STD_LOGIC_VECTOR(23 DOWNTO 0);
            data_valid_in    : IN  STD_LOGIC;
            left_data_out    : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
            right_data_out   : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
            data_valid_out   : OUT STD_LOGIC;
            left_code_out    : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            right_code_out   : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            left_step_out    : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
            right_step_out   : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
        );
    END COMPONENT;

    COMPONENT dac_transmitter IS
        PORT(
            clk        : IN  STD_LOGIC;
            rst        : IN  STD_LOGIC;
            tx_en      : IN  STD_LOGIC;
            bck        : IN  STD_LOGIC;
            lrck       : IN  STD_LOGIC;
            left_data  : IN  STD_LOGIC_VECTOR(23 DOWNTO 0);
            right_data : IN  STD_LOGIC_VECTOR(23 DOWNTO 0);
            din        : OUT STD_LOGIC;
            tx_done    : OUT STD_LOGIC
        );
    END COMPONENT;

    -- Internal signals
    SIGNAL scki_i      : STD_LOGIC := '0';
    SIGNAL bck_i       : STD_LOGIC := '0';
    SIGNAL lrck_i      : STD_LOGIC := '0';
    SIGNAL clk_stab_i  : STD_LOGIC := '0';
    SIGNAL rx_en_i     : STD_LOGIC := '0';
    SIGNAL tx_en_i     : STD_LOGIC := '0';
    SIGNAL clk_en_i    : STD_LOGIC := '0';
    SIGNAL rst_cod_i   : STD_LOGIC := '0';
    SIGNAL left_adc_i  : STD_LOGIC_VECTOR(23 DOWNTO 0) := (OTHERS => '0');
    SIGNAL right_adc_i : STD_LOGIC_VECTOR(23 DOWNTO 0) := (OTHERS => '0');
    SIGNAL rx_done_i   : STD_LOGIC := '0';
    SIGNAL adc_dv_i    : STD_LOGIC := '0';
    SIGNAL left_comp_i : STD_LOGIC_VECTOR(23 DOWNTO 0) := (OTHERS => '0');
    SIGNAL right_comp_i: STD_LOGIC_VECTOR(23 DOWNTO 0) := (OTHERS => '0');
    SIGNAL comp_dv_i   : STD_LOGIC := '0';
    SIGNAL din_i       : STD_LOGIC := '0';
    SIGNAL tx_done_i   : STD_LOGIC := '0';

BEGIN

    scki           <= scki_i;
    bck            <= bck_i;
    lrck           <= lrck_i;
    din            <= din_i;
    left_data_out  <= left_comp_i;
    right_data_out <= right_comp_i;
    data_valid     <= comp_dv_i;

    U1 : clock_gen
        PORT MAP(
            clk        => clk,
            rst        => rst,
            scki_out   => scki_i,
            bck_out    => bck_i,
            lrck_out   => lrck_i,
            clk_stable => clk_stab_i
        );

    U2 : fsm_controller
        PORT MAP(
            clk            => clk,
            rst            => rst,
            start          => start,
            clk_stable     => clk_stab_i,
            rx_done        => rx_done_i,
            tx_done        => tx_done_i,
            power_down_req => power_down_req,
            pdwn           => pdwn,
            fmt0           => fmt0,
            fmt1           => fmt1,
            demp0          => demp0,
            demp1          => demp1,
            rx_en          => rx_en_i,
            tx_en          => tx_en_i,
            clk_en         => clk_en_i,
            rst_codec      => rst_cod_i
        );

    U3 : adc_receiver
        PORT MAP(
            clk        => clk,
            rst        => rst,
            rx_en      => rx_en_i,
            bck        => bck_i,
            lrck       => lrck_i,
            dout       => dout,
            left_data  => left_adc_i,
            right_data => right_adc_i,
            rx_done    => rx_done_i,
            data_valid => adc_dv_i
        );

    -- U4: Voice Compression
    -- LEFT and RIGHT both triggered by adc_dv_i
    -- They differ because inputs differ!
    U4 : voice_compression_top
        PORT MAP(
            clk            => clk,
            rst            => rst,
            en             => rx_en_i,
            left_data_in   => left_adc_i,
            right_data_in  => right_adc_i,
            data_valid_in  => adc_dv_i,
            left_data_out  => left_comp_i,
            right_data_out => right_comp_i,
            data_valid_out => comp_dv_i,
            left_code_out  => left_adpcm_code,
            right_code_out => right_adpcm_code,
            left_step_out  => left_step_size,
            right_step_out => right_step_size
        );

    U5 : dac_transmitter
        PORT MAP(
            clk        => clk,
            rst        => rst,
            tx_en      => tx_en_i,
            bck        => bck_i,
            lrck       => lrck_i,
            left_data  => left_comp_i,
            right_data => right_comp_i,
            din        => din_i,
            tx_done    => tx_done_i
        );

END ARCHITECTURE structural;