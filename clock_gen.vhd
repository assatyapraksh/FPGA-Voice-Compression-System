

-------------------------------------------------
-- clock_gen.vhd
-- MATHEMATICAL PROOF IN CODE:
-- BCK_HALF  = 33
-- LRCK_FULL = 128 x 33 = 4224
-- BCK full period = 33 x 2 = 66 counts
-- BCK per LRCK = 4224 / 66 = 64.0 EXACT
-- NO PHASE DRIFT GUARANTEED!
-------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY clock_gen IS
    PORT(
        clk        : IN  STD_LOGIC;
        rst        : IN  STD_LOGIC;
        scki_out   : OUT STD_LOGIC;
        bck_out    : OUT STD_LOGIC;
        lrck_out   : OUT STD_LOGIC;
        clk_stable : OUT STD_LOGIC
    );
END ENTITY clock_gen;

ARCHITECTURE fsm_arch OF clock_gen IS

    TYPE clk_state_type IS (
        CLK_ST_IDLE,
        CLK_ST_RUNNING,
        CLK_ST_STABLE
    );

    SIGNAL clk_cur   : clk_state_type := CLK_ST_IDLE;
    SIGNAL clk_nxt   : clk_state_type := CLK_ST_IDLE;

    -- SCKI = 200MHz/16 = 12.5MHz
    CONSTANT SCKI_DIV  : INTEGER := 16;

    -----------------------------------------------
    -- LINE 40: BCK_HALF = 33
    -- BCK full period = 33 x 2 = 66 clock cycles
    -- BCK frequency = 200MHz/66 = 3.03MHz
    CONSTANT BCK_HALF  : INTEGER := 33;

    -- LINE 44: LRCK_FULL = BCK_HALF x 128 = 4224
    -- This is the KEY line that guarantees
    -- EXACTLY 64 BCK cycles per LRCK period!
    -- Because: 4224/66 = 64.0 EXACT!
    CONSTANT LRCK_FULL : INTEGER := 128 * BCK_HALF;
    -- = 128 x 33 = 4224

    -- LINE 50: LRCK_HALF = LRCK_FULL/2 = 2112
    CONSTANT LRCK_HALF : INTEGER := LRCK_FULL / 2;
    -- = 4224/2 = 2112
    -----------------------------------------------

    -- SCKI counter
    SIGNAL scki_cnt  : INTEGER RANGE 0 TO 16   := 0;

    -- Master counter counts 0 to LRCK_FULL-1
    -- = 0 to 4223
    SIGNAL m_cnt     : INTEGER RANGE 0 TO 4223 := 0;

    -- Stability counter
    SIGNAL s_cnt     : INTEGER RANGE 0 TO 4224 := 0;

    -- Clock output registers
    SIGNAL scki_reg  : STD_LOGIC := '0';
    SIGNAL bck_reg   : STD_LOGIC := '0';
    SIGNAL lrck_reg  : STD_LOGIC := '0';
    SIGNAL stab_reg  : STD_LOGIC := '0';

BEGIN

    scki_out   <= scki_reg;
    bck_out    <= bck_reg;
    lrck_out   <= lrck_reg;
    clk_stable <= stab_reg;

    -- State Register
    ST_REG : PROCESS(clk, rst)
    BEGIN
        IF rst = '0' THEN
            clk_cur <= CLK_ST_IDLE;
        ELSIF rising_edge(clk) THEN
            clk_cur <= clk_nxt;
        END IF;
    END PROCESS;

    -- Next State Logic
    NSL : PROCESS(clk_cur, s_cnt)
    BEGIN
        CASE clk_cur IS
            WHEN CLK_ST_IDLE =>
                clk_nxt <= CLK_ST_RUNNING;
            WHEN CLK_ST_RUNNING =>
                IF s_cnt = LRCK_FULL - 1 THEN
                    clk_nxt <= CLK_ST_STABLE;
                ELSE
                    clk_nxt <= CLK_ST_RUNNING;
                END IF;
            WHEN CLK_ST_STABLE =>
                clk_nxt <= CLK_ST_STABLE;
            WHEN OTHERS =>
                clk_nxt <= CLK_ST_IDLE;
        END CASE;
    END PROCESS;

    -- Stability Counter
    STAB_CNT : PROCESS(clk, rst)
    BEGIN
        IF rst = '0' THEN
            s_cnt <= 0;
        ELSIF rising_edge(clk) THEN
            IF clk_cur = CLK_ST_RUNNING THEN
                IF s_cnt < LRCK_FULL - 1 THEN
                    s_cnt <= s_cnt + 1;
                END IF;
            ELSE
                s_cnt <= 0;
            END IF;
        END IF;
    END PROCESS;

    -- SCKI Generator 12.5MHz
    SCKI_GEN : PROCESS(clk, rst)
    BEGIN
        IF rst = '0' THEN
            scki_cnt <= 0;
            scki_reg <= '0';
        ELSIF rising_edge(clk) THEN
            IF scki_cnt = (SCKI_DIV/2) - 1 THEN
                scki_reg <= NOT scki_reg;
                scki_cnt <= 0;
            ELSE
                scki_cnt <= scki_cnt + 1;
            END IF;
        END IF;
    END PROCESS;

    -----------------------------------------------
    -- LINE 130: MASTER COUNTER
    -- This is the SINGLE counter that drives
    -- BOTH BCK and LRCK
    -- Counts 0 to LRCK_FULL-1 = 0 to 4223
    -- Resets every LRCK period
    -- This guarantees BCK and LRCK stay
    -- perfectly synchronized FOREVER!
    -----------------------------------------------
    MSTR_CNT : PROCESS(clk, rst)
    BEGIN
        IF rst = '0' THEN
            m_cnt <= 0;
        ELSIF rising_edge(clk) THEN
            IF clk_cur = CLK_ST_RUNNING OR
               clk_cur = CLK_ST_STABLE THEN
                IF m_cnt = LRCK_FULL - 1 THEN
                    -- Reset at 4223
                    -- Back to 0 every LRCK period
                    m_cnt <= 0;
                ELSE
                    m_cnt <= m_cnt + 1;
                END IF;
            ELSE
                m_cnt <= 0;
            END IF;
        END IF;
    END PROCESS;

    -----------------------------------------------
    -- LINE 155: LRCK GENERATOR
    -- Driven by master counter m_cnt
    -- LOW  when m_cnt = 0    to 2111
    -- HIGH when m_cnt = 2112 to 4223
    -- Period = 4224 counts = LRCK_FULL
    -----------------------------------------------
    LRCK_GEN : PROCESS(clk, rst)
    BEGIN
        IF rst = '0' THEN
            lrck_reg <= '0';
        ELSIF rising_edge(clk) THEN
            IF clk_cur = CLK_ST_RUNNING OR
               clk_cur = CLK_ST_STABLE THEN
                IF m_cnt < LRCK_HALF THEN
                    lrck_reg <= '0';
                ELSE
                    lrck_reg <= '1';
                END IF;
            ELSE
                lrck_reg <= '0';
            END IF;
        END IF;
    END PROCESS;

    -----------------------------------------------
    -- LINE 178: BCK GENERATOR
    -- THIS IS THE KEY IMPLEMENTATION LINE!
    -- BCK toggles when m_cnt MOD BCK_HALF = 0
    -- = when m_cnt = 0,33,66,99,...,4191
    -- Total toggles = 4224/33 = 128
    -- BCK cycles    = 128/2   = 64
    --
    -- PROOF: 4224 / 66 = 64.0 EXACT
    -- 64 BCK cycles per LRCK period ✅
    -- NO PHASE DRIFT ✅
    -- CONSTANT OUTPUT ✅
    -----------------------------------------------
    BCK_GEN : PROCESS(clk, rst)
    BEGIN
        IF rst = '0' THEN
            bck_reg <= '0';
        ELSIF rising_edge(clk) THEN
            IF clk_cur = CLK_ST_RUNNING OR
               clk_cur = CLK_ST_STABLE THEN
                -- THIS LINE implements 64 BCK per LRCK:
                IF (m_cnt MOD BCK_HALF) = 0 THEN
                    bck_reg <= NOT bck_reg;
                END IF;
            ELSE
                bck_reg <= '0';
            END IF;
        END IF;
    END PROCESS;

    -- Stable Output
    STAB_OUT : PROCESS(clk, rst)
    BEGIN
        IF rst = '0' THEN
            stab_reg <= '0';
        ELSIF rising_edge(clk) THEN
            IF clk_cur = CLK_ST_STABLE THEN
                stab_reg <= '1';
            ELSE
                stab_reg <= '0';
            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE fsm_arch;
