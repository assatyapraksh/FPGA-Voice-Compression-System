-------------------------------------------------
-- adc_receiver.vhd (32-slot aware: 24 data + 8 pad)
-- Active LOW reset
-- Captures on BCK falling edge
-------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY adc_receiver IS
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
END ENTITY adc_receiver;

ARCHITECTURE rtl OF adc_receiver IS
    SIGNAL bck_prev   : STD_LOGIC := '0';
    SIGNAL lrck_prev  : STD_LOGIC := '0';
    SIGNAL bck_fall   : STD_LOGIC := '0';
    SIGNAL lrck_fall  : STD_LOGIC := '0';
    SIGNAL lrck_rise  : STD_LOGIC := '0';

    SIGNAL slot_cnt   : INTEGER RANGE 0 TO 31 := 0;
    SIGNAL chan_sel   : STD_LOGIC := '0'; -- '0' left, '1' right

    SIGNAL left_sr    : STD_LOGIC_VECTOR(23 DOWNTO 0) := (OTHERS => '0');
    SIGNAL right_sr   : STD_LOGIC_VECTOR(23 DOWNTO 0) := (OTHERS => '0');
    SIGNAL left_reg   : STD_LOGIC_VECTOR(23 DOWNTO 0) := (OTHERS => '0');
    SIGNAL right_reg  : STD_LOGIC_VECTOR(23 DOWNTO 0) := (OTHERS => '0');

    SIGNAL rx_done_r  : STD_LOGIC := '0';
    SIGNAL dv_r       : STD_LOGIC := '0';
BEGIN
    left_data  <= left_reg;
    right_data <= right_reg;
    rx_done    <= rx_done_r;
    data_valid <= dv_r;

    EDGE_DET : PROCESS(clk, rst)
    BEGIN
        IF rst='0' THEN
            bck_prev  <= '0';
            lrck_prev <= '0';
            bck_fall  <= '0';
            lrck_fall <= '0';
            lrck_rise <= '0';
        ELSIF rising_edge(clk) THEN
            IF (bck_prev='1' AND bck='0') THEN bck_fall<='1'; ELSE bck_fall<='0'; END IF;
            IF (lrck_prev='1' AND lrck='0') THEN lrck_fall<='1'; ELSE lrck_fall<='0'; END IF;
            IF (lrck_prev='0' AND lrck='1') THEN lrck_rise<='1'; ELSE lrck_rise<='0'; END IF;
            bck_prev  <= bck;
            lrck_prev <= lrck;
        END IF;
    END PROCESS;

    RX_PROC : PROCESS(clk, rst)
    BEGIN
        IF rst='0' THEN
            slot_cnt  <= 0;
            chan_sel  <= '0';
            left_sr   <= (OTHERS=>'0');
            right_sr  <= (OTHERS=>'0');
            left_reg  <= (OTHERS=>'0');
            right_reg <= (OTHERS=>'0');
            rx_done_r <= '0';
            dv_r      <= '0';

        ELSIF rising_edge(clk) THEN
            rx_done_r <= '0';
            dv_r      <= '0';

            IF rx_en='0' THEN
                slot_cnt <= 0;
            ELSE
                -- Channel start markers
                IF lrck_fall='1' THEN
                    chan_sel <= '0';
                    slot_cnt <= 0;
                    left_sr  <= (OTHERS=>'0');
                ELSIF lrck_rise='1' THEN
                    chan_sel <= '1';
                    slot_cnt <= 0;
                    right_sr <= (OTHERS=>'0');
                END IF;

                IF bck_fall='1' THEN
                    -- capture only valid 24 bits
                    IF slot_cnt <= 23 THEN
                        IF chan_sel='0' THEN
                            left_sr <= left_sr(22 DOWNTO 0) & dout;
                        ELSE
                            right_sr <= right_sr(22 DOWNTO 0) & dout;
                        END IF;
                    END IF;

                    IF slot_cnt=31 THEN
                        slot_cnt <= 0;
                        IF chan_sel='1' THEN
                            left_reg  <= left_sr;
                            right_reg <= right_sr;
                            rx_done_r <= '1';
                            dv_r      <= '1';
                        END IF;
                    ELSE
                        slot_cnt <= slot_cnt + 1;
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE rtl;