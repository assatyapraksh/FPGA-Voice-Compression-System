
-------------------------------------------------
-- dac_transmitter.vhd (I2S/PCM SLOT-AWARE)
-- Active LOW reset
-- 32-bit slot per channel:
--   bit 0..23  : audio data (MSB first)
--   bit 24..31 : zero padding
-- Update on BCK falling edge
-------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY dac_transmitter IS
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
END ENTITY dac_transmitter;

ARCHITECTURE rtl OF dac_transmitter IS
    SIGNAL bck_prev   : STD_LOGIC := '0';
    SIGNAL lrck_prev  : STD_LOGIC := '0';
    SIGNAL bck_fall   : STD_LOGIC := '0';
    SIGNAL lrck_fall  : STD_LOGIC := '0';
    SIGNAL lrck_rise  : STD_LOGIC := '0';

    SIGNAL slot_cnt   : INTEGER RANGE 0 TO 31 := 0; -- 32 clocks per channel slot
    SIGNAL chan_sel   : STD_LOGIC := '0';           -- '0'=left, '1'=right
    SIGNAL shreg      : STD_LOGIC_VECTOR(23 DOWNTO 0) := (OTHERS => '0');

    SIGNAL din_r      : STD_LOGIC := '0';
    SIGNAL tx_done_r  : STD_LOGIC := '0';
BEGIN
    din     <= din_r;
    tx_done <= tx_done_r;

    -------------------------------------------------
    -- Edge detection in clk domain
    -------------------------------------------------
    EDGE_DET : PROCESS(clk, rst)
    BEGIN
        IF rst = '0' THEN
            bck_prev  <= '0';
            lrck_prev <= '0';
            bck_fall  <= '0';
            lrck_fall <= '0';
            lrck_rise <= '0';
        ELSIF rising_edge(clk) THEN
            IF (bck_prev='1' AND bck='0') THEN
                bck_fall <= '1';
            ELSE
                bck_fall <= '0';
            END IF;

            IF (lrck_prev='1' AND lrck='0') THEN
                lrck_fall <= '1';
            ELSE
                lrck_fall <= '0';
            END IF;

            IF (lrck_prev='0' AND lrck='1') THEN
                lrck_rise <= '1';
            ELSE
                lrck_rise <= '0';
            END IF;

            bck_prev  <= bck;
            lrck_prev <= lrck;
        END IF;
    END PROCESS;

    -------------------------------------------------
    -- Main TX process
    -------------------------------------------------
    TX_PROC : PROCESS(clk, rst)
    BEGIN
        IF rst = '0' THEN
            slot_cnt  <= 0;
            chan_sel  <= '0';
            shreg     <= (OTHERS => '0');
            din_r     <= '0';
            tx_done_r <= '0';

        ELSIF rising_edge(clk) THEN
            tx_done_r <= '0';

            IF tx_en = '0' THEN
                slot_cnt <= 0;
                din_r    <= '0';

            ELSE
                -- Channel boundary: load fresh sample at LRCK edges
                IF lrck_fall = '1' THEN
                    chan_sel <= '0';
                    shreg    <= left_data;
                    slot_cnt <= 0;
                ELSIF lrck_rise = '1' THEN
                    chan_sel <= '1';
                    shreg    <= right_data;
                    slot_cnt <= 0;
                END IF;

                -- Shift/update on each BCK falling edge
                IF bck_fall = '1' THEN
                    IF slot_cnt <= 23 THEN
                        -- Output MSB then shift left
                        din_r  <= shreg(23);
                        shreg  <= shreg(22 DOWNTO 0) & '0';
                    ELSE
                        -- Padding bits must be zero
                        din_r  <= '0';
                    END IF;

                    -- 32-bit slot counter
                    IF slot_cnt = 31 THEN
                        slot_cnt <= 0;
                        IF chan_sel = '1' THEN
                            tx_done_r <= '1'; -- one full LR frame complete (L+R)
                        END IF;
                    ELSE
                        slot_cnt <= slot_cnt + 1;
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE rtl;


