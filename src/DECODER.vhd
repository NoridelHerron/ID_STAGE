----------------------------------------------------------------------------------
-- Author      : Noridel Herron
-- Date        : 05/03/2025
-- Description : Instruction Decode (ID) Stage for 5-Stage RISC-V Pipeline CPU
--               - Extracts opcode, rd, rs1, rs2, funct3, funct7, immediate
--               - Generates control signals for EX, MEM, WB stages
--               - Interfaces with register file to fetch operand values
--               - Accepts writeback data/signals from WB stage
-- File        : DECODER.vhd
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity DECODER is
    Port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        instr_in    : in  std_logic_vector(31 downto 0);
        data_in     : in  std_logic_vector(31 downto 0);
        wb_rd       : in  std_logic_vector(4 downto 0);  -- Writeback destination reg
        wb_reg_write: in  std_logic;                     -- Writeback enable signal

        -- control outputs to EX, MEM, WB       
        reg_write   : out std_logic;
        mem_read    : out std_logic;
        mem_write   : out std_logic;
        f3          : out std_logic_vector(2 downto 0);
        f7          : out std_logic_vector(6 downto 0);

        -- register file outputs
        reg_data1   : out std_logic_vector(31 downto 0);
        reg_data2   : out std_logic_vector(31 downto 0);

        -- passthrough
        instr_out   : out std_logic_vector(31 downto 0);
        rd_out      : out std_logic_vector(4 downto 0)
    );
end DECODER;

architecture behavior of DECODER is

    component RegisterFile
        Port (
            clk          : in  std_logic;
            rst          : in  std_logic;
            write_enable : in  std_logic;
            write_addr   : in  std_logic_vector(4 downto 0);
            write_data   : in  std_logic_vector(31 downto 0);
            read_addr1   : in  std_logic_vector(4 downto 0);
            read_addr2   : in  std_logic_vector(4 downto 0);
            read_data1   : out std_logic_vector(31 downto 0);
            read_data2   : out std_logic_vector(31 downto 0)
        );
    end component;

    -- Internal signals
    signal opcode           : std_logic_vector(6 downto 0);
    signal rs1_addr         : std_logic_vector(4 downto 0);
    signal rs2_addr         : std_logic_vector(4 downto 0);
    signal rd_addr          : std_logic_vector(4 downto 0);
    signal read_data1_int   : std_logic_vector(31 downto 0);
    signal read_data2_int   : std_logic_vector(31 downto 0);
    signal imm              : std_logic_vector(31 downto 0) := (others => '0');

begin

    -- Register file instantiation
    regfile_inst : RegisterFile port map (clk, rst, wb_reg_write, wb_rd, data_in, rs1_addr, rs2_addr, read_data1_int, read_data2_int);

    process(clk, rst)
    begin
        if rst = '1' then
            reg_data1 <= (others => '0');
            reg_data2 <= (others => '0');
            reg_write <= '0';
            mem_read  <= '0';
            mem_write <= '0';
            f3        <= (others => '0');
            f7        <= (others => '0');
            instr_out <= (others => '0');
            rd_out    <= (others => '0');
            opcode    <= (others => '0');
            imm       <= (others => '0');

        elsif rising_edge(clk) then
            -- Pass through instruction
            instr_out <= instr_in;
            -- this will ensure that the initial rd_out will not be undefined
            if instr_in /= "00000000000000000000000000000000" then
                opcode    <= instr_in(6 downto 0);
                f3        <= instr_in(14 downto 12);
                f7        <= instr_in(31 downto 25);
                rs1_addr  <= instr_in(19 downto 15);
                rs2_addr  <= instr_in(24 downto 20);
                rd_addr   <= instr_in(11 downto 7);
                rd_out    <= rd_addr;
            else
                opcode    <= (others => '0');
                f3        <= (others => '0');
                f7        <= (others => '0');
                rs1_addr  <= (others => '0');
                rs2_addr  <= (others => '0');
                rd_addr   <= (others => '0');
                rd_out    <= (others => '0');
            end if;

            -- Decode control signals & immediate
            case opcode is
                when "0110011" => -- R-type
                    reg_write <= '1';
                    mem_read  <= '0';
                    mem_write <= '0';
                    imm       <= (others => '0');
                    reg_data1 <= read_data1_int;
                    reg_data2 <= read_data2_int;

                when "0010011" => -- I-type
                    reg_write <= '1';
                    mem_read  <= '0';
                    mem_write <= '0';
                    imm       <= std_logic_vector(resize(signed(instr_in(31 downto 20)), 32));
                    reg_data1 <= read_data1_int;
                    reg_data2 <= imm;

                when "0000011" => -- LW
                    reg_write <= '1';
                    mem_read  <= '1';
                    mem_write <= '0';
                    imm       <= std_logic_vector(resize(signed(instr_in(31 downto 20)), 32));
                    reg_data1 <= read_data1_int;
                    reg_data2 <= imm;

                when "0100011" => -- SW
                    reg_write <= '0';
                    mem_read  <= '0';
                    mem_write <= '1';
                    imm       <= std_logic_vector(resize(signed(instr_in(31 downto 25) & instr_in(11 downto 7)), 32));
                    reg_data1 <= read_data1_int;
                    reg_data2 <= imm;

                when others =>
                    reg_write <= '0';
                    mem_read  <= '0';
                    mem_write <= '0';
                    imm       <= (others => '0');
                    reg_data1 <= (others => '0');
                    reg_data2 <= (others => '0');
            end case;
        end if;
    end process;

end behavior;
