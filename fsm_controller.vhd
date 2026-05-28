
-------------------------------------------------
-- fsm_controller.vhd (CONTINUOUS RUN MODE)
-- Active LOW reset: rst=0 clear, rst=1 run
-- RX and TX enabled together in FSM_RUN
-------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY fsm_controller IS
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
END ENTITY fsm_controller;

ARCHITECTURE fsm_arch OF fsm_controller IS

    TYPE ctrl_state_type IS (
        FSM_IDLE,
        FSM_RESET,
        FSM_INIT,
        FSM_CLK_GEN,
        FSM_SYNC,
        FSM_RUN,
        FSM_POWER_DOWN
    );

    SIGNAL cur_st        : ctrl_state_type := FSM_IDLE;
    SIGNAL nxt_st        : ctrl_state_type := FSM_IDLE;

    CONSTANT RESET_COUNT : INTEGER := 1024;
    SIGNAL   rst_cnt     : INTEGER RANGE 0 TO 1025 := 0;
    SIGNAL   rst_done    : STD_LOGIC := '0';

    CONSTANT SYNC_COUNT  : INTEGER := 1;
    SIGNAL   syn_cnt     : INTEGER RANGE 0 TO 2 := 0;
    SIGNAL   syn_done    : STD_LOGIC := '0';

    SIGNAL s_latch       : STD_LOGIC := '0';

    SIGNAL pdwn_r        : STD_LOGIC := '0';
    SIGNAL fmt0_r        : STD_LOGIC := '0';
    SIGNAL fmt1_r        : STD_LOGIC := '0';
    SIGNAL demp0_r       : STD_LOGIC := '1';
    SIGNAL demp1_r       : STD_LOGIC := '0';
    SIGNAL rx_en_r       : STD_LOGIC := '0';
    SIGNAL tx_en_r       : STD_LOGIC := '0';
    SIGNAL clk_en_r      : STD_LOGIC := '0';
    SIGNAL rst_codec_r   : STD_LOGIC := '0';

BEGIN

    pdwn      <= pdwn_r;
    fmt0      <= fmt0_r;
    fmt1      <= fmt1_r;
    demp0     <= demp0_r;
    demp1     <= demp1_r;
    rx_en     <= rx_en_r;
    tx_en     <= tx_en_r;
    clk_en    <= clk_en_r;
    rst_codec <= rst_codec_r;

    -------------------------------------------------
    -- START LATCH
    -------------------------------------------------
    START_LATCH : PROCESS(clk, rst)
    BEGIN
        IF rst = '0' THEN
            s_latch <= '0';
        ELSIF rising_edge(clk) THEN
            IF start = '1' THEN
                s_latch <= '1';
            ELSIF cur_st /= FSM_IDLE THEN
                s_latch <= '0';
            END IF;
        END IF;
    END PROCESS;

    -------------------------------------------------
    -- STATE REGISTER
    -------------------------------------------------
    ST_REG : PROCESS(clk, rst)
    BEGIN
        IF rst = '0' THEN
            cur_st <= FSM_IDLE;
        ELSIF rising_edge(clk) THEN
            cur_st <= nxt_st;
        END IF;
    END PROCESS;

    -------------------------------------------------
    -- RESET COUNTER
    -------------------------------------------------
    RST_CNT_PROC : PROCESS(clk, rst)
    BEGIN
        IF rst = '0' THEN
            rst_cnt  <= 0;
            rst_done <= '0';
        ELSIF rising_edge(clk) THEN
            IF cur_st = FSM_RESET THEN
                IF rst_cnt = RESET_COUNT - 1 THEN
                    rst_done <= '1';
                    rst_cnt  <= 0;
                ELSE
                    rst_cnt  <= rst_cnt + 1;
                    rst_done <= '0';
                END IF;
            ELSE
                rst_cnt  <= 0;
                rst_done <= '0';
            END IF;
        END IF;
    END PROCESS;

    -------------------------------------------------
    -- SYNC COUNTER
    -------------------------------------------------
    SYN_CNT_PROC : PROCESS(clk, rst)
    BEGIN
        IF rst = '0' THEN
            syn_cnt  <= 0;
            syn_done <= '0';
        ELSIF rising_edge(clk) THEN
            IF cur_st = FSM_SYNC THEN
                IF syn_cnt = SYNC_COUNT - 1 THEN
                    syn_done <= '1';
                    syn_cnt  <= 0;
                ELSE
                    syn_cnt  <= syn_cnt + 1;
                    syn_done <= '0';
                END IF;
            ELSE
                syn_cnt  <= 0;
                syn_done <= '0';
            END IF;
        END IF;
    END PROCESS;

    -------------------------------------------------
    -- NEXT STATE LOGIC
    -------------------------------------------------
    NSL : PROCESS(cur_st, s_latch, clk_stable, rst_done, syn_done, power_down_req)
    BEGIN
        CASE cur_st IS
            WHEN FSM_IDLE =>
                IF s_latch = '1' THEN
                    nxt_st <= FSM_RESET;
                ELSE
                    nxt_st <= FSM_IDLE;
                END IF;

            WHEN FSM_RESET =>
                IF rst_done = '1' THEN
                    nxt_st <= FSM_INIT;
                ELSE
                    nxt_st <= FSM_RESET;
                END IF;

            WHEN FSM_INIT =>
                nxt_st <= FSM_CLK_GEN;

            WHEN FSM_CLK_GEN =>
                IF clk_stable = '1' THEN
                    nxt_st <= FSM_SYNC;
                ELSE
                    nxt_st <= FSM_CLK_GEN;
                END IF;

            WHEN FSM_SYNC =>
                IF syn_done = '1' THEN
                    nxt_st <= FSM_RUN;
                ELSE
                    nxt_st <= FSM_SYNC;
                END IF;

            WHEN FSM_RUN =>
                IF power_down_req = '1' THEN
                    nxt_st <= FSM_POWER_DOWN;
                ELSE
                    nxt_st <= FSM_RUN;
                END IF;

            WHEN FSM_POWER_DOWN =>
                nxt_st <= FSM_IDLE;

            WHEN OTHERS =>
                nxt_st <= FSM_IDLE;
        END CASE;
    END PROCESS;

    -------------------------------------------------
    -- REGISTERED OUTPUT LOGIC
    -------------------------------------------------
    OUT_REG : PROCESS(clk, rst)
    BEGIN
        IF rst = '0' THEN
            pdwn_r      <= '0';
            fmt0_r      <= '0';
            fmt1_r      <= '0';
            demp0_r     <= '1';
            demp1_r     <= '0';
            rx_en_r     <= '0';
            tx_en_r     <= '0';
            clk_en_r    <= '0';
            rst_codec_r <= '0';

        ELSIF rising_edge(clk) THEN
            CASE cur_st IS
                WHEN FSM_IDLE =>
                    pdwn_r      <= '0';
                    fmt0_r      <= '0';
                    fmt1_r      <= '0';
                    demp0_r     <= '1';
                    demp1_r     <= '0';
                    rx_en_r     <= '0';
                    tx_en_r     <= '0';
                    clk_en_r    <= '0';
                    rst_codec_r <= '0';

                WHEN FSM_RESET =>
                    pdwn_r      <= '0';
                    fmt0_r      <= '0';
                    fmt1_r      <= '0';
                    demp0_r     <= '1';
                    demp1_r     <= '0';
                    rx_en_r     <= '0';
                    tx_en_r     <= '0';
                    clk_en_r    <= '0';
                    rst_codec_r <= '1';

                WHEN FSM_INIT =>
                    pdwn_r      <= '1';
                    fmt0_r      <= '1';
                    fmt1_r      <= '1';
                    demp0_r     <= '1';
                    demp1_r     <= '0';
                    rx_en_r     <= '0';
                    tx_en_r     <= '0';
                    clk_en_r    <= '0';
                    rst_codec_r <= '0';

                WHEN FSM_CLK_GEN =>
                    pdwn_r      <= '1';
                    fmt0_r      <= '1';
                    fmt1_r      <= '1';
                    demp0_r     <= '1';
                    demp1_r     <= '0';
                    rx_en_r     <= '0';
                    tx_en_r     <= '0';
                    clk_en_r    <= '1';
                    rst_codec_r <= '0';

                WHEN FSM_SYNC =>
                    pdwn_r      <= '1';
                    fmt0_r      <= '1';
                    fmt1_r      <= '1';
                    demp0_r     <= '1';
                    demp1_r     <= '0';
                    rx_en_r     <= '0';
                    tx_en_r     <= '0';
                    clk_en_r    <= '1';
                    rst_codec_r <= '0';

                WHEN FSM_RUN =>
                    pdwn_r      <= '1';
                    fmt0_r      <= '1';
                    fmt1_r      <= '1';
                    demp0_r     <= '1';
                    demp1_r     <= '0';
                    rx_en_r     <= '1';  -- continuous receive
                    tx_en_r     <= '1';  -- continuous transmit
                    clk_en_r    <= '1';
                    rst_codec_r <= '0';

                WHEN FSM_POWER_DOWN =>
                    pdwn_r      <= '0';
                    fmt0_r      <= '0';
                    fmt1_r      <= '0';
                    demp0_r     <= '1';
                    demp1_r     <= '0';
                    rx_en_r     <= '0';
                    tx_en_r     <= '0';
                    clk_en_r    <= '0';
                    rst_codec_r <= '0';

                WHEN OTHERS =>
                    pdwn_r      <= '0';
                    fmt0_r      <= '0';
                    fmt1_r      <= '0';
                    demp0_r     <= '1';
                    demp1_r     <= '0';
                    rx_en_r     <= '0';
                    tx_en_r     <= '0';
                    clk_en_r    <= '0';
                    rst_codec_r <= '0';
            END CASE;
        END IF;
    END PROCESS;

END ARCHITECTURE fsm_arch;
