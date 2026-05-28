-------------------------------------------------
-- adpcm_decoder.vhd  FIXED
-- Single process - no pipeline timing issues
-- Input  : 4-bit ADPCM code
-- Output : 24-bit reconstructed PCM sample
-- Standard: IMA-ADPCM
-- Active LOW reset
-------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY adpcm_decoder IS
    PORT(
        clk        : IN  STD_LOGIC;
        rst        : IN  STD_LOGIC;
        en         : IN  STD_LOGIC;
        code_in    : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
        code_vld   : IN  STD_LOGIC;
        sample_out : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
        sample_vld : OUT STD_LOGIC
    );
END ENTITY adpcm_decoder;

ARCHITECTURE rtl OF adpcm_decoder IS

    TYPE step_table_type IS ARRAY(0 TO 88) OF INTEGER;
    CONSTANT STEP_TABLE : step_table_type := (
        7,     8,     9,    10,    11,    12,    13,    14,
       16,    17,    19,    21,    23,    25,    28,    31,
       34,    37,    41,    45,    50,    55,    60,    66,
       73,    80,    88,    97,   107,   118,   130,   143,
      157,   173,   190,   209,   230,   253,   279,   307,
      337,   371,   408,   449,   494,   544,   598,   658,
      724,   796,   876,   963,  1060,  1166,  1282,  1411,
     1552,  1707,  1878,  2066,  2272,  2499,  2749,  3024,
     3327,  3660,  4026,  4428,  4871,  5358,  5894,  6484,
     7132,  7845,  8630,  9493, 10442, 11487, 12635, 13899,
     15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794,
     32767
    );

    TYPE index_table_type IS ARRAY(0 TO 7) OF INTEGER;
    CONSTANT INDEX_TABLE : index_table_type := (
        -1, -1, -1, -1, 2, 4, 6, 8
    );

    -- State - each decoder instance has its own!
    SIGNAL predicted   : SIGNED(23 DOWNTO 0)   := (OTHERS => '0');
    SIGNAL step_idx    : INTEGER RANGE 0 TO 88  := 0;
    SIGNAL step_size   : INTEGER RANGE 0 TO 32767 := 7;

    SIGNAL sample_r    : STD_LOGIC_VECTOR(23 DOWNTO 0) := (OTHERS => '0');
    SIGNAL sample_vld_r: STD_LOGIC := '0';

BEGIN

    sample_out <= sample_r;
    sample_vld <= sample_vld_r;

    -------------------------------------------------
    -- SINGLE PROCESS: decode in one clock
    -------------------------------------------------
    DEC_PROC : PROCESS(clk, rst)
        VARIABLE sign_bit : STD_LOGIC;
        VARIABLE mag      : UNSIGNED(2 DOWNTO 0);
        VARIABLE delta    : INTEGER;
        VARIABLE np       : SIGNED(24 DOWNTO 0);
        VARIABLE clamped  : SIGNED(23 DOWNTO 0);
        VARIABLE ni       : INTEGER;
    BEGIN
        IF rst = '0' THEN
            predicted    <= (OTHERS => '0');
            step_idx     <= 0;
            step_size    <= 7;
            sample_r     <= (OTHERS => '0');
            sample_vld_r <= '0';

        ELSIF rising_edge(clk) THEN
            sample_vld_r <= '0';

            IF en = '1' AND code_vld = '1' THEN

                -- Step 1: extract sign and magnitude
                sign_bit := code_in(3);
                mag      := UNSIGNED(code_in(2 DOWNTO 0));

                -- Step 2: reconstruct delta
                delta := (step_size     * TO_INTEGER(UNSIGNED'("" & mag(2)))) +
                         (step_size / 2 * TO_INTEGER(UNSIGNED'("" & mag(1)))) +
                         (step_size / 4 * TO_INTEGER(UNSIGNED'("" & mag(0)))) +
                         (step_size / 8);

                -- Step 3: update predictor
                IF sign_bit = '1' THEN
                    np := predicted - TO_SIGNED(delta, 25);
                ELSE
                    np := predicted + TO_SIGNED(delta, 25);
                END IF;

                -- Clamp to 24-bit signed range
                IF np > TO_SIGNED(8388607, 25) THEN
                    clamped := TO_SIGNED(8388607, 24);
                ELSIF np < TO_SIGNED(-8388608, 25) THEN
                    clamped := TO_SIGNED(-8388608, 24);
                ELSE
                    clamped := np(23 DOWNTO 0);
                END IF;

                predicted <= clamped;

                -- Step 4: update step index
                ni := step_idx + INDEX_TABLE(TO_INTEGER(mag));
                IF ni < 0  THEN ni := 0;  END IF;
                IF ni > 88 THEN ni := 88; END IF;
                step_idx  <= ni;
                step_size <= STEP_TABLE(ni);

                -- Step 5: output
                sample_r     <= STD_LOGIC_VECTOR(clamped);
                sample_vld_r <= '1';

            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE rtl;