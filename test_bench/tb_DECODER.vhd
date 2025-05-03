----------------------------------------------------------------------------------
-- Author      : Noridel Herron
-- Date        : 05/03/2025
-- randomized test bench for DECODER.vhd
-- File        : tb_DECODER.vhd
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.math_real.ALL;

entity tb_DECODER is
end tb_DECODER;

architecture behavior of tb_DECODER is

    component DECODER
        Port (
            clk         : in  std_logic;
            rst         : in  std_logic;
            instr_in    : in  std_logic_vector(31 downto 0);
            reg_write   : out std_logic;
            mem_read    : out std_logic;
            mem_write   : out std_logic;
            f3          : out std_logic_vector(2 downto 0);
            f7          : out std_logic_vector(6 downto 0);
            reg_data1   : out std_logic_vector(31 downto 0);
            reg_data2   : out std_logic_vector(31 downto 0);
            instr_out   : out std_logic_vector(31 downto 0)
        );
    end component;

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '1';
    signal instr_in    : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_write   : std_logic;
    signal mem_read    : std_logic;
    signal mem_write   : std_logic;
    signal f3          : std_logic_vector(2 downto 0);
    signal f7          : std_logic_vector(6 downto 0);
    signal reg_data1   : std_logic_vector(31 downto 0);
    signal reg_data2   : std_logic_vector(31 downto 0);
    signal instr_out   : std_logic_vector(31 downto 0);

    constant clk_period : time := 10 ns;

begin

    uut: DECODER
        port map (clk, rst, instr_in, reg_write, mem_read, mem_write, f3, f7, reg_data1, reg_data2, instr_out);

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

    stim_proc : process
        variable total_tests : integer := 1000;
        variable seed1, seed2 : positive := 42;
        variable rand_real : real;
        variable rand_int : integer;
        variable instr : std_logic_vector(31 downto 0);
        variable rd, rs1, rs2 : integer;
        variable imm : std_logic_vector(11 downto 0);
        variable pass_count, fail_count : integer := 0;
        variable rtype_fail, itype_fail, lw_fail, sw_fail, other_fail : integer := 0;
    begin
        rst <= '1';
        wait for clk_period;
        rst <= '0';
        wait for clk_period;

        for i in 0 to total_tests - 1 loop
            loop
                uniform(seed1, seed2, rand_real); rd := integer(rand_real * 32.0);
                if rd > 31 then rd := 31; end if;
                exit when rd /= 0;
            end loop;

            uniform(seed1, seed2, rand_real); rs1 := integer(rand_real * 32.0) mod 32;
            uniform(seed1, seed2, rand_real); rs2 := integer(rand_real * 32.0) mod 32;
            uniform(seed1, seed2, rand_real);
            imm := std_logic_vector(to_signed(integer(rand_real * 2048.0) - 1024, 12));
            uniform(seed1, seed2, rand_real); rand_int := integer(rand_real * 4.0);

            case rand_int is
                when 0 =>
                    instr := "0000000" & std_logic_vector(to_unsigned(rs2, 5)) &
                             std_logic_vector(to_unsigned(rs1, 5)) & "000" &
                             std_logic_vector(to_unsigned(rd, 5)) & "0110011";
                    instr_in <= instr;
                    wait for clk_period;
                    wait for 10 ns;
                    if reg_write = '1' and mem_read = '0' and mem_write = '0' then
                        pass_count := pass_count + 1;
                    else
                        fail_count := fail_count + 1; rtype_fail := rtype_fail + 1;
                    end if;

                when 1 =>
                    instr := imm & std_logic_vector(to_unsigned(rs1, 5)) & "000" &
                             std_logic_vector(to_unsigned(rd, 5)) & "0010011";
                    instr_in <= instr;
                    wait for clk_period;
                    wait for 10 ns;
                    if reg_write = '1' and mem_read = '0' and mem_write = '0' then
                        pass_count := pass_count + 1;
                    else
                        fail_count := fail_count + 1; itype_fail := itype_fail + 1;
                    end if;

                when 2 =>
                    instr := imm & std_logic_vector(to_unsigned(rs1, 5)) & "010" &
                             std_logic_vector(to_unsigned(rd, 5)) & "0000011";
                    instr_in <= instr;
                    wait for clk_period;
                    wait for 10 ns;
                    if reg_write = '1' and mem_read = '1' and mem_write = '0' then
                        pass_count := pass_count + 1;
                    else
                        fail_count := fail_count + 1; lw_fail := lw_fail + 1;
                    end if;

                when 3 =>
                    instr := imm(11 downto 5) & std_logic_vector(to_unsigned(rs2, 5)) &
                             std_logic_vector(to_unsigned(rs1, 5)) & "010" &
                             imm(4 downto 0) & "0100011";
                    instr_in <= instr;
                    wait for clk_period;
                    wait for 10 ns;
                    if reg_write = '0' and mem_read = '0' and mem_write = '1' then
                        pass_count := pass_count + 1;
                    else
                        fail_count := fail_count + 1; sw_fail := sw_fail + 1;
                    end if;

                when others => 
                    instr := std_logic_vector(to_unsigned(integer(rand_real * 2.0**32), 32));
                    instr_in <= instr;
                    wait for clk_period;
                    wait for 10 ns;
                    if reg_write = '0' and mem_read = '0' and mem_write = '0' then
                        pass_count := pass_count + 1;
                    else
                        fail_count := fail_count + 1; other_fail := other_fail + 1;
                    end if;
            end case;
        end loop;

        report "\n======= TEST SUMMARY =======";
        report "Passed: " & integer'image(pass_count);
        report "Failed: " & integer'image(fail_count);
        report "R-type Fails: " & integer'image(rtype_fail);
        report "I-type Fails: " & integer'image(itype_fail);
        report "LW Fails: " & integer'image(lw_fail);
        report "SW Fails: " & integer'image(sw_fail);
        report "Other-type Fails: " & integer'image(other_fail);
        wait;
    end process;

end behavior;
