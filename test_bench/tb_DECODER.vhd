-- Author      : Noridel Herron
-- Date        : 05/03/2025
-- randomized test bench for DECODER.vhd
-- File        : tb_DECODER.vhd
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.math_real.ALL;

library work;
use work.reusable_function.all;

entity tb_DECODER is
end tb_DECODER;

architecture behavior of tb_DECODER is

    component DECODER
        Port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        instr_in    : in  std_logic_vector(31 downto 0);
        data_in     : in  std_logic_vector(31 downto 0);
        wb_rd       : in  std_logic_vector(4 downto 0);  -- Writeback destination reg
        wb_reg_write: in  std_logic;                     -- Writeback enable signal

        -- control outputs to EX, MEM, WB            
        op          : out std_logic_vector(2 downto 0);  -- opcode control signal
        f3          : out std_logic_vector(2 downto 0);  -- function 3
        f7          : out std_logic_vector(6 downto 0);  -- function 7

        -- register file outputs
        reg_data1   : out std_logic_vector(31 downto 0);  -- value in register source 1
        reg_data2   : out std_logic_vector(31 downto 0);  -- value in register source 2 or immediate

        -- passthrough    
        rd_out      : out std_logic_vector(4 downto 0)
    );
    end component;

    signal clk              : std_logic := '0';
    signal rst              : std_logic := '1';
    signal instr_in         : std_logic_vector(31 downto 0) := (others => '0'); 
    signal f3               : std_logic_vector(2 downto 0);
    signal f7               : std_logic_vector(6 downto 0);
    signal op               : std_logic_vector(2 downto 0);
    signal reg_data1        : std_logic_vector(31 downto 0);
    signal reg_data2        : std_logic_vector(31 downto 0);
    signal rd_out, rd_tmp   : std_logic_vector(4 downto 0):= (others => '0');
    signal wb_rd            : std_logic_vector(4 downto 0) := (others => '0');
    signal wb_reg_write     : std_logic := '0';
    signal data_in          : std_logic_vector(31 downto 0):= (others => '0');

    constant clk_period     : time := 10 ns;

begin
    uut: DECODER port map (clk, rst, instr_in, data_in, wb_rd, wb_reg_write, op, f3, f7, reg_data1, reg_data2, rd_out);

    -- Clock generation only
    clk_process : process
    begin
        while now < 200000 ns loop
            clk <= '0';
            wait for clk_period / 2;
            clk <= '1';
            wait for clk_period / 2;
        end loop;
        wait;
    end process;

    -- Test logic and summary reporting
    stim_proc : process
        variable total_tests : integer := 5000;
        variable seed1, seed2 : positive := 42;
        variable rand_real : real;
        variable rand_int : integer;
        variable instr : std_logic_vector(31 downto 0);
        variable rd, rs1, rs2 : integer;
        variable imm : std_logic_vector(11 downto 0) := (others => '0');
        variable pass_count, fail_count : integer := 0;
        variable rtype_fail, itype_fail, lw_fail, sw_fail, other_fail : integer := 0;
        variable rd_fail, op_fail, func7_fail, func3_fail : integer := 0;
        variable wb_data : std_logic_vector(31 downto 0);
    begin
        report "TESTBENCH STARTED" severity warning;
        rst <= '1';
        wait for clk_period;
        rst <= '0';
        wait for clk_period;

        wb_data := std_logic_vector(to_unsigned(12345, 32));
        wb_rd <= "00011";
        data_in <= wb_data;
        wb_reg_write <= '1';
        wait for clk_period;
        wb_reg_write <= '0';

        for i in 0 to total_tests - 1 loop
        
            -- Generate value and secure from edge cases
            uniform(seed1, seed2, rand_real); 
            rd := integer(rand_real * 32.0) mod 32; 
              
            uniform(seed1, seed2, rand_real); 
            rs1 := integer(rand_real * 32.0) mod 32;
            
            uniform(seed1, seed2, rand_real); 
            rs2 := integer(rand_real * 32.0) mod 32;
            
            uniform(seed1, seed2, rand_real);
            imm := std_logic_vector(to_signed(integer(rand_real * 2048.0) - 1024, 12));
            
            uniform(seed1, seed2, rand_real); 
            rand_int := integer(rand_real * 5.0);

            case rand_int is
                when 0 => -- R-type
                    instr := "0000000" & std_logic_vector(to_unsigned(rs2, 5)) &
                             std_logic_vector(to_unsigned(rs1, 5)) & "000" &
                             std_logic_vector(to_unsigned(rd, 5)) & "0110011";
                    instr_in <= instr;
                    
                    -- give enough time for the module getting tested
                    wait until rising_edge(clk);
                    wait until rising_edge(clk);
                    wait for 1 ns;  -- Let rd_out stabilize
                    
                    -- Determine if any pass or fail in R-type       
                    if f3 = "000" and f7 = "0000000" and op = "001" and rd_out = std_logic_vector(to_unsigned(rd, 5)) then
                        pass_count := pass_count + 1;
                    else
                        fail_count := fail_count + 1;
                        rtype_fail := rtype_fail + 1;
                    end if;
                    
                    -- Narrow down the bugs
                    if f3 /= "000" then func3_fail := func3_fail + 1; end if;
                    if f7 /= "0000000" then func7_fail := func7_fail + 1; end if;
                    if op /= "001" then op_fail := op_fail + 1; end if;
                    if rd_out /= std_logic_vector(to_unsigned(rd, 5)) then 
                        rd_fail := rd_fail + 1;
                        assert false report "RD Mismatch (R-TYPE): expected = " & integer'image(rd) & 
                                            ", actual = " & integer'image(to_integer(unsigned(rd_out))) severity warning;
                    end if;
                when 1 => -- I-type
                    instr := imm & std_logic_vector(to_unsigned(rs1, 5)) & "000" &
                             std_logic_vector(to_unsigned(rd, 5)) & "0010011";
                    instr_in <= instr;
                    
                    -- give enough time for the module getting tested
                    wait until rising_edge(clk);
                    wait until rising_edge(clk);
                    wait for 1 ns;  -- Let rd_out stabilize
                    
                    -- Determine if any pass or fail in I-type    
                    if f3 = "000" and op = "001" and rd_out = std_logic_vector(to_unsigned(rd, 5)) then
                        pass_count := pass_count + 1;
                    else
                        fail_count := fail_count + 1;
                        itype_fail := itype_fail + 1;
                    end if;
                    
                    -- Narrow down the bugs
                    if f3 /= "000" then func3_fail := func3_fail + 1; end if;
                    if op /= "001" then op_fail := op_fail + 1; end if;
                    if rd_out /= std_logic_vector(to_unsigned(rd, 5)) then 
                        rd_fail := rd_fail + 1;
                        assert false report "RD Mismatch(I-TYPE): expected = " & integer'image(rd) & 
                                            ", actual = " & integer'image(to_integer(unsigned(rd_out))) severity warning;
                    end if;
                    
                when 2 => -- Load instruction (I-type also)
                    instr := imm & std_logic_vector(to_unsigned(rs1, 5)) & "010" &
                             std_logic_vector(to_unsigned(rd, 5)) & "0000011";
                    instr_in <= instr;
                    
                    -- give enough time for the module getting tested
                    wait until rising_edge(clk);
                    wait until rising_edge(clk);
                    wait for 1 ns;  -- Let rd_out stabilize
                    
                    -- Determine if any pass or fail in Load instruction 
                    if rd_out /= std_logic_vector(to_unsigned(rd, 5)) then rd_fail := rd_fail + 1; end if;
                    if f3 = "010" and op = "010" and rd_out = std_logic_vector(to_unsigned(rd, 5)) then
                        pass_count := pass_count + 1;               
                    else
                        fail_count := fail_count + 1;
                        lw_fail := lw_fail + 1;
                    end if;
                    
                    -- Narrow down the bugs
                    if f3 /= "010" then func3_fail := func3_fail + 1; end if;
                    if rd_out /= std_logic_vector(to_unsigned(rd, 5)) then 
                        rd_fail := rd_fail + 1;
                        assert false report "RD Mismatch(LOAD): expected = " & integer'image(rd) & 
                                            ", actual = " & integer'image(to_integer(unsigned(rd_out))) severity warning;
                    end if;     
                       
                when 3 =>
                    instr := imm(11 downto 5) & std_logic_vector(to_unsigned(rs2, 5)) &
                             std_logic_vector(to_unsigned(rs1, 5)) & "010" &
                             imm(4 downto 0) & "0100011";
                    instr_in <= instr;
                    
                    -- give enough time for the module getting tested
                    wait until rising_edge(clk);
                    wait until rising_edge(clk);
                    wait for 1 ns;  -- Let rd_out stabilize
                    
                    -- Determine if any pass or fail in S-type
                    if f3 = "010" and op = "011" then
                        pass_count := pass_count + 1;
                    else
                        fail_count := fail_count + 1;
                        sw_fail := sw_fail + 1;
                    end if;
                    
                    -- Narrow down the bugs
                    if f3 /= "010" then func3_fail := func3_fail + 1; end if;
                    if op /= "011" then op_fail := op_fail + 1; end if;            
                    
                when others =>
                    instr := std_logic_vector(to_unsigned(integer(rand_real * 2.0**32), 32));
                    instr_in <= instr;
                    
                    -- give enough time for the module getting tested
                    wait until rising_edge(clk);
                    wait until rising_edge(clk);
                    wait for 1 ns;  -- Let rd_out stabilize
                    
                    -- Determine if any pass or fail in S-type
                    if op = "000" then
                        pass_count := pass_count + 1;
                    else
                        fail_count := fail_count + 1;
                        other_fail := other_fail + 1;
                    end if;
                    
                    -- Narrow down the bugs
                    if op /= "000" then op_fail := op_fail + 1; end if;
                    
            end case;
             rd_tmp <= std_logic_vector(to_unsigned(rd, 5));
        end loop;

        -- Summary report
        report "======= TEST SUMMARY =======" severity note;
        report "Passed: " & integer'image(pass_count) severity note;
        report "Failed: " & integer'image(fail_count) severity note;
        report "R-type Fails: " & integer'image(rtype_fail) severity note;
        report "I-type Fails: " & integer'image(itype_fail) severity note;
        report "LW Fails: " & integer'image(lw_fail) severity note;
        report "SW Fails: " & integer'image(sw_fail) severity note;
        report "Other-type Fails: " & integer'image(other_fail) severity note;
        report "Func3 Fails: " & integer'image(func3_fail) severity note;
        report "Func7 Fails: " & integer'image(func7_fail) severity note;
        report "OP Fails: " & integer'image(op_fail) severity note;
        report "RD Fails: " & integer'image(rd_fail) severity note;
        wait;
    end process;
end behavior;
