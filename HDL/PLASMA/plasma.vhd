---------------------------------------------------------------------
-- TITLE: Plasma (CPU core with memory)
-- AUTHOR: Steve Rhoads (rhoadss@yahoo.com)
-- DATE CREATED: 6/4/02
-- FILENAME: plasma.vhd
-- PROJECT: Plasma CPU core
-- COPYRIGHT: Software placed into the public domain by the author.
--    Software 'as is' without warranty.  Author liable for nothing.
-- DESCRIPTION:
--    This entity combines the CPU core with memory and a UART.
--
-- Memory Map:
--   0x00000000 - 0x0000ffff   Internal RAM (8KB) - 0000 0000 0000
--   0x10000000 - 0x100fffff   External RAM (1MB) - 0001 0000 0000

--   Access all Misc registers with 32-bit accesses
--   0x20000000  Uart Write (will pause CPU if busy)
--   0x20000000  Uart Read
--   0x20000010  IRQ Mask
--   0x20000020  IRQ Status
--   0x20000030  GPIO0 Out Set bits
--   0x20000040  GPIO0 Out Clear bits
--   0x20000050  GPIOA In
--   0x20000060  Counter
--   0x20000070  Ethernet transmit count
--   IRQ bits:
--      7   GPIO31
--      6  ^GPIO31
--      5   EthernetSendDone
--      4   EthernetReceive
--      3   Counter(18)
--      2  ^Counter(18)
--      1  ^UartWriteBusy
--      0   UartDataAvailable
--   0x30000000  FIFO IN  EMPTY
--   0x30000010  FIFO OUT EMPTY
--   0x30000020  FIFO IN  VALID
--   0x30000030  FIFO OUT VALID
--   0x30000040  FIFO IN  FULL
--   0x30000050  FIFO IN  FULL
--   0x30000060  FIFO IN  COUNTER
--   0x30000070  FIFO OUT COUNTER
--   0x30000080  FIFO IN  READ DATA
--   0x30000090  FIFO OUT WRITE DATA
--   0x40000000  COPROCESSOR 1 (reset)
--   0x40000010  COPROCESSOR 1 (input/output)

--   0x40000030  COPROCESSOR 2 (reset)
--   0x40000040  COPROCESSOR 2 (input/output)

--   0x40000060  COPROCESSOR 3 (reset)
--   0x40000070  COPROCESSOR 3 (input/output)

----   0x40000090  COPROCESSOR 4 (reset)
----   0x400000A0  COPROCESSOR 4 (input/output)

--   0x40000090  OLED (reset)
--   0x400000A0  OLED (input/output)

--   0x400000C0  CONTROLLER SWITCH LED (reset)
--   0x400000D0  CONTROLLER SWITCH LED (input/output)

--   0x40000100  Buttons controller values
--   0x40000104  Buttons controller change

--   0x40000200  Seven segment display input

--   0x80000000  DMA ENGINE (NOT WORKING YET)
---------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.mlite_pack.all;

entity plasma is
   generic(memory_type : string := "XILINX_16X"; --"DUAL_PORT_" "ALTERA_LPM";
           log_file    : string := "UNUSED";
           ethernet    : std_logic  := '0';
           eUart       : std_logic  := '0';
           use_cache   : std_logic  := '0';
           CLK_FREQ_HZ : integer := 100000000;        -- by default, we run at 100MHz
           LEFT_SIDE   : boolean := False );
   port(clk          : in std_logic;
			clk_VGA			: in std_logic;
				reset        : in std_logic;

				uart_write   : out std_logic;
				uart_read    : in std_logic;

				address      : out std_logic_vector(31 downto 2);
				byte_we      : out std_logic_vector(3  downto 0);
				--data_write   : out std_logic_vector(31 downto 0);
				--data_read    : in  std_logic_vector(31 downto 0);
				---mem_pause_in : in std_logic;
				no_ddr_start : out std_logic;
				no_ddr_stop  : out std_logic;

				-- BLG START
				fifo_1_out_data  : IN  STD_LOGIC_VECTOR (31 DOWNTO 0);
				fifo_1_read_en   : OUT STD_LOGIC;
				fifo_1_empty     : IN  STD_LOGIC;
				fifo_2_in_data   : OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
				fifo_1_write_en  : OUT STD_LOGIC;
				fifo_2_full      : IN  STD_LOGIC;

				fifo_1_full      : IN STD_LOGIC;
				fifo_1_valid     : IN STD_LOGIC;
				fifo_2_empty     : IN STD_LOGIC;
				fifo_2_valid     : IN STD_LOGIC;
				fifo_1_compteur  : IN STD_LOGIC_VECTOR (31 DOWNTO 0);
				fifo_2_compteur  : IN STD_LOGIC_VECTOR (31 DOWNTO 0);
				-- BLG END

				VGA_hs       : out std_logic;   -- horisontal vga syncr.
				VGA_vs       : out std_logic;   -- vertical vga syncr.
				VGA_red      : out std_logic_vector(3 downto 0);   -- red output
				VGA_green    : out std_logic_vector(3 downto 0);   -- green output
				VGA_blue     : out std_logic_vector(3 downto 0);   -- blue output

				sw           : in  std_logic_vector(15 downto 0);
                led          : out std_logic_vector(15 downto 0);

                RGB1_Red     : out std_logic;
                RGB1_Green   : out std_logic;
                RGB1_Blue    : out std_logic;
                RGB2_Red     : out std_logic;
                RGB2_Green   : out std_logic;
                RGB2_Blue    : out std_logic;

                OLED_PMOD_CS      	: out STD_LOGIC;
          			OLED_PMOD_MOSI    	: out STD_LOGIC;
           			OLED_PMOD_SCK     	: out STD_LOGIC;
          			OLED_PMOD_DC      	: out STD_LOGIC;
           			OLED_PMOD_RES     	: out STD_LOGIC;
          			OLED_PMOD_VCCEN   	: out STD_LOGIC;
         			  OLED_PMOD_EN      	: out STD_LOGIC;


                seg          : out std_logic_vector(6 downto 0);
                an           : out std_logic_vector(7 downto 0);

                btnCpuReset  : in std_logic;
                btnC         : in std_logic;
                btnU         : in std_logic;
                btnL         : in std_logic;
                btnR         : in std_logic;
                btnD         : in std_logic;

				gpio0_out    : out std_logic_vector(31 downto 0);
				gpioA_in     : in  std_logic_vector(31 downto 0));
end; --entity plasma

architecture logic of plasma is
   signal address_next      : std_logic_vector(31 downto 2);
   signal byte_we_next      : std_logic_vector(3 downto 0);
   signal cpu_address       : std_logic_vector(31 downto 0);
   signal cpu_byte_we       : std_logic_vector(3 downto 0);
   signal cpu_data_w        : std_logic_vector(31 downto 0);
   signal cpu_data_r        : std_logic_vector(31 downto 0);
   signal cpu_pause         : std_logic;

   signal ppcie_rdata       : std_logic_vector(31 downto 0);

   signal data_read_uart    : std_logic_vector(7 downto 0);
   signal data_vga_read     : std_logic_vector(31 downto 0);
   signal write_enable      : std_logic;
   signal eth_pause_in      : std_logic;
   signal eth_pause         : std_logic;
   signal mem_busy          : std_logic;

   signal enable_misc       : std_logic;
   signal enable_uart       : std_logic;
   signal enable_uart_read  : std_logic;
   signal enable_uart_write : std_logic;
   signal enable_eth        : std_logic;
   signal enable_local_mem  : std_logic;
   signal enable_buttons    : std_logic;
   signal enable_vga        : std_logic;
   signal enable_vga_read   : std_logic;
   signal enable_vga_write  : std_logic;
   signal ctrl_7seg_valid   : std_logic;

   signal ctrl_SL_reset     : std_logic;
   signal ctrl_SL_valid	    : std_logic;
   signal ctrl_SL_output    : std_logic_vector(31 downto 0);

   signal oled_reset        : std_logic;
   signal oled_valid	      : std_logic;
   signal oled_output	      : std_logic_vector( 31 downto 0 ):= "00000000000000000000000000000000";

   signal buttons_values    : std_logic_vector(31 downto 0);
   signal buttons_change    : std_logic_vector(31 downto 0);

   signal gpio0_reg         : std_logic_vector(31 downto 0);
   signal uart_write_busy   : std_logic;
   signal uart_data_avail   : std_logic;
   signal irq_mask_reg      : std_logic_vector(7 downto 0);
   signal irq_status        : std_logic_vector(7 downto 0);
   signal irq               : std_logic;
   signal irq_eth_rec       : std_logic;
   signal irq_eth_send      : std_logic;
   signal counter_reg       : std_logic_vector(31 downto 0);

   signal ram_boot_enable   : std_logic;
   signal ram_enable        : std_logic;
   signal ram_byte_we       : std_logic_vector( 3 downto 0);
   signal ram_address       : std_logic_vector(31 downto 2);
   signal ram_data_w        : std_logic_vector(31 downto 0);
   signal ram_data_r        : std_logic_vector(31 downto 0);
   signal ram_data_lm       : std_logic_vector(31 downto 0);

   signal dma_address       : std_logic_vector(31 downto 0);
   signal dma_byte_we       : std_logic_vector( 3 downto 0);
   signal dma_data_write    : std_logic_vector(31 downto 0);
   signal dma_data_read     : std_logic_vector(31 downto 0);
   signal dma_start         : std_logic;

   signal cop_1_reset       : std_logic;
   signal cop_1_valid       : std_logic;
   signal cop_1_output      : std_logic_vector(31 downto 0);
   signal cop_2_reset       : std_logic;
   signal cop_2_valid       : std_logic;
   signal cop_2_output      : std_logic_vector(31 downto 0);
   signal cop_3_reset       : std_logic;
   signal cop_3_valid       : std_logic;
   signal cop_3_output      : std_logic_vector(31 downto 0);
   signal cop_4_reset       : std_logic;
   signal cop_4_valid       : std_logic;
   signal cop_4_output      : std_logic_vector(31 downto 0);

   signal cache_access      : std_logic;
   signal cache_checking    : std_logic;
   signal cache_miss        : std_logic;
   signal cache_hit         : std_logic;


	COMPONENT memory_64k
    Port ( clk       : in   STD_LOGIC;
           addr_in   : in   STD_LOGIC_VECTOR (31 downto 2);
           data_in   : in   STD_LOGIC_VECTOR (31 downto 0);
           enable    : in   STD_LOGIC;
           we_select : in   STD_LOGIC_VECTOR (3 downto 0);
           data_out  : out  STD_LOGIC_VECTOR (31 downto 0));
	end COMPONENT;

	component vga_ctrl is
      port(
         clock           : in  std_logic;
         clock_vga       : in  std_logic;
         reset           : in  std_logic;
         vga_w           : in  std_logic_vector(31 downto 0);
         vga_w_en        : in  std_logic;
         vga_r           : out std_logic_vector(31 downto 0);
         vga_r_en        : in std_logic;
         VGA_hs          : out std_logic;   -- horisontal vga syncr.
         VGA_vs          : out std_logic;   -- vertical vga syncr.
         VGA_red         : out std_logic_vector(3 downto 0);   -- red output
         VGA_green       : out std_logic_vector(3 downto 0);   -- green output
         VGA_blue        : out std_logic_vector(3 downto 0)   -- blue output
      );
   end component;

	component ctrl_SL is
	   port(
	   		clock			: in  std_logic;
			reset			: in  std_logic;
			INPUT_1			: in  std_logic_vector(31 downto 0);
			INPUT_1_valid	: in  std_logic;
			OUTPUT_1		: out std_logic_vector(31 downto 0);
			SW				: in std_logic_vector(15 downto 0);
			LED				: out std_logic_vector(15 downto 0);
			RGB1_Red		: out  std_logic;
			RGB2_Red		: out  std_logic;
			RGB1_Green		: out  std_logic;
			RGB2_Green		: out  std_logic;
			RGB1_Blue		: out  std_logic;
			RGB2_Blue		: out  std_logic
		);
	end component;


  component PmodOLEDrgb_charmap is
      Generic (CLK_FREQ_HZ : integer := 100000000;        -- by default, we run at 100MHz
               PARAM_BUFF  : boolean := False;            -- if True, no need to hold inputs while module busy
               LEFT_SIDE   : boolean := False);           -- True if the Pmod is on the left side of the board
      Port (clk          : in  STD_LOGIC;
            reset        : in  STD_LOGIC;

            char_write   : in  STD_LOGIC;
            char_col     : in  STD_LOGIC_VECTOR(3 downto 0);
            char_row     : in  STD_LOGIC_VECTOR(2 downto 0);
            char         : in  STD_LOGIC_VECTOR(7 downto 0);
            ready        : out STD_LOGIC;
            foregnd      : in  STD_LOGIC_VECTOR(7 downto 0):=x"FF";
            backgnd      : in  STD_LOGIC_VECTOR(7 downto 0):=x"00";
            scroll_up    : in  STD_LOGIC := '0';
            row_clear    : in  STD_LOGIC := '0';
            screen_clear : in  STD_LOGIC;

            PMOD_CS      : out STD_LOGIC;
            PMOD_MOSI    : out STD_LOGIC;
            PMOD_SCK     : out STD_LOGIC;
            PMOD_DC      : out STD_LOGIC;
            PMOD_RES     : out STD_LOGIC;
            PMOD_VCCEN   : out STD_LOGIC;
            PMOD_EN      : out STD_LOGIC);
  end component;

begin  --architecture


   --RGB1_Red <= not btnCpuReset;
   --RGB1_Green <= btnD;
   --RGB1_Blue <= btnU;
   --RGB2_Red <= btnR;
   --RGB2_Green <= btnL;
   --RGB2_Blue <= btnC;

   --led <= sw;

   --seg <= "1011010";
   --an <= sw(7 downto 0);


   write_enable <= '1' when cpu_byte_we /= "0000" else '0';
   mem_busy     <= eth_pause;-- or mem_pause_in;
   cache_hit    <= cache_checking and not cache_miss;
   cpu_pause    <= (uart_write_busy and enable_uart and write_enable)    --UART busy
--						 or  cache_miss                                        --Cache wait
--                   or (cpu_address(31) and not cache_hit and mem_busy);  --DDR or flash
                   or (eth_pause);  -- DMA ENGINE FREEZE ALL (BLG)
   irq_status   <= gpioA_in(31) & not gpioA_in(31) &
                        irq_eth_send & irq_eth_rec &
                        counter_reg(18) & not counter_reg(18) &
                        not uart_write_busy & uart_data_avail;
   irq          <= '1' when (irq_status and irq_mask_reg) /= ZERO(7 downto 0) else '0';

   gpio0_out(31 downto 29) <= gpio0_reg(31 downto 29);
   gpio0_out(23 downto 0)  <= gpio0_reg(23 downto 0);

   enable_misc             <= '1' when cpu_address(30 downto 28) = "010" else '0';
   enable_uart             <= '1' when enable_misc = '1' and cpu_address(8 downto 4) = "00000" else '0';
   enable_uart_read        <= enable_uart and not write_enable;
   enable_uart_write       <= enable_uart and write_enable;
   enable_eth              <= '1' when enable_misc = '1' and cpu_address(8 downto 4) = "00111" else '0';
   enable_vga <= '1' when enable_misc = '1' and cpu_address(8 downto 4) = "10010" else '0';
   enable_vga_read <= enable_vga and not write_enable;
   enable_vga_write <= enable_vga and  write_enable;

   cpu_address(1 downto 0) <= "00";

	--
	-- ON GENERE LES SIGNAUX DE COMMANDE EN DIRECTION DU PORT PCIe
	--
	--fifo_1_read_en  <= '1' when ((cpu_address(31 downto 28) = "0011") AND (cpu_address(7 downto 4) = "1000")                         ) else '0';
   --fifo_1_write_en <= '1' when ((cpu_address(31 downto 28) = "0011") AND (cpu_address(7 downto 4) = "1001") AND (write_enable = '1')) else '0';
	fifo_1_read_en  <= '1' when (cpu_address = x"30000080") AND (cpu_pause    = '0')                         else '0';
   fifo_1_write_en <= '1' when (cpu_address = x"30000090") AND (cpu_pause    = '0') AND(write_enable = '1') else '0';

   cop_1_reset <= '1' when (cpu_address = x"40000000") AND (cpu_pause = '0') AND (write_enable = '1') else '0';
   cop_1_valid <= '1' when (cpu_address = x"40000004") AND (cpu_pause = '0') AND (write_enable = '1') else '0';

   cop_2_reset <= '1' when (cpu_address = x"40000030") AND (cpu_pause = '0') AND (write_enable = '1') else '0';
   cop_2_valid <= '1' when (cpu_address = x"40000034") AND (cpu_pause = '0') AND (write_enable = '1') else '0';

   cop_3_reset <= '1' when (cpu_address = x"40000060") AND (cpu_pause = '0') AND (write_enable = '1') else '0';
   cop_3_valid <= '1' when (cpu_address = x"40000064") AND (cpu_pause = '0') AND (write_enable = '1') else '0';

   cop_4_reset <= '1' when (cpu_address = x"40000090") AND (cpu_pause = '0') AND (write_enable = '1') else '0';
   cop_4_valid <= '1' when (cpu_address = x"40000094") AND (cpu_pause = '0') AND (write_enable = '1') else '0';

   oled_reset <= '1' when (cpu_address = x"400000A0") AND (cpu_pause = '0') AND (write_enable = '1') else '0';
   oled_valid <= '1' when (cpu_address = x"400000A4") AND (cpu_pause = '0') AND (write_enable = '1') else '0';

   ctrl_SL_reset <= '1' when (cpu_address = x"400000C0") AND (cpu_pause = '0') AND (write_enable = '1') else '0';
   ctrl_SL_valid <= '1' when (cpu_address = x"400000C4") AND (cpu_pause = '0') AND (write_enable = '1') else '0';

   enable_buttons <= '1' when (cpu_address = x"40000100" or cpu_address = x"40000104") AND (cpu_pause = '0') else '0';

   ctrl_7seg_valid <= '1' when (cpu_address = x"40000200") AND (cpu_pause = '0') else '0';

--   assert cop_4_valid /= '1' severity failure;
	--
	-- ON LIT/ECRIT DANS LA MEMOIRE LOCALE UNIQUEMENT LORSQUE LE BUS
	-- D'ADRESSE (MSB) = "001". SINON ON ADRESSE UN AUTRE PERIPHERIQUE
	--

   --dram_procr: process(clk)
   --begin
   --	if rising_edge(clk) then
	--		ppcie_rdata <= pcie_rdata;
	--	end if;
   --end process;

	--
	-- INTERNAL RAM MEMORY (64ko)
	--
--	enable_local_mem        <= '1' when (cpu_address(31 downto 28) = "0001") else '0';
--	enable_local_mem <= '1' when (ram_address(31 downto 28) = "0001") else '0';


   local_memory: memory_64k
      port map (
         clk        => clk,
			   addr_in	  => ram_address, --cpu_data_r,
         data_in    => ram_data_w,
         enable     => enable_local_mem,
         we_select  => ram_byte_we,
         data_out   => ram_data_lm
		);

	--
	--
	--
   u1_cpu: mlite_cpu
      generic map (memory_type => memory_type)
      PORT MAP (
         clk          => clk,
         reset_in     => reset,
         intr_in      => irq,

         address_next => address_next,             --before rising_edge(clk)
         byte_we_next => byte_we_next,

         address      => cpu_address(31 downto 2), --after rising_edge(clk)
         byte_we      => cpu_byte_we,
         data_w       => cpu_data_w,
         data_r       => cpu_data_r,
         mem_pause    => cpu_pause);


	--
	--
	--
   opt_cache: if use_cache = '0' generate
      cache_access   <= '0';
      cache_checking <= '0';
      cache_miss     <= '0';
   end generate;

	--
	--
	--
   opt_cache2: if use_cache = '1' generate
   --Control 4KB unified cache that uses the upper 4KB of the 8KB
   --internal RAM.  Only lowest 2MB of DDR is cached.
   u_cache: cache
      generic map (memory_type => memory_type)
      PORT MAP (
         clk            => clk,
         reset          => reset,
         address_next   => address_next,
         byte_we_next   => byte_we_next,
         cpu_address    => cpu_address(31 downto 2),
         mem_busy       => mem_busy,

         cache_access   => cache_access,    --access 4KB cache
         cache_checking => cache_checking,  --checking if cache hit
         cache_miss     => cache_miss);     --cache miss
   end generate; --opt_cache2

   no_ddr_start <= not eth_pause and cache_checking;
   no_ddr_stop  <= not eth_pause and cache_miss;
   eth_pause_in <= (not eth_pause and cache_miss and not cache_checking);


	--
	--
	--
   misc_proc: process(clk, reset, cpu_address, enable_misc,
      ram_data_r, data_read_uart, cpu_pause, enable_buttons,
      irq_mask_reg, irq_status, gpio0_reg, write_enable,
      cache_checking,
      gpioA_in, counter_reg, cpu_data_w, ram_data_lm,
		fifo_1_empty, fifo_2_empty, fifo_1_full, fifo_2_full,
		fifo_1_valid, fifo_2_valid, fifo_1_compteur, fifo_2_compteur, fifo_1_out_data)
   begin
      case cpu_address(30 downto 28) is

			-- ON LIT LES DONNEES DE LA MEMOIRE INTERNE
      	when "000" =>         --internal ROM
         	cpu_data_r <= ram_data_r;

			-- ON LIT LES DONNEES DE LA MEMOIRE EXTERNE (LOCAL RAM)
      	when "001" =>         --external (local) RAM
         	--if cache_checking = '1' then
         	--cpu_data_r <= ram_data_r; --cache
         	--else
         	--cpu_data_r <= data_read; --DDR
         	--end if;
				cpu_data_r <= ram_data_lm;

			-- ON LIT LES DONNEES DES PERIPHERIQUES MISC.
	when "010" =>         --misc
         	case cpu_address(8 downto 4) is
         		when "00000" =>      --uart
         		   cpu_data_r <= ZERO(31 downto 8) & data_read_uart;
        		when "00001" =>      --irq_mask
            		cpu_data_r <= ZERO(31 downto 8) & irq_mask_reg;
         		when "00010" =>      --irq_status
         		   cpu_data_r <= ZERO(31 downto 8) & irq_status;
         		when "00011" =>      --gpio0
            		cpu_data_r <= gpio0_reg;
         		when "00101" =>      --gpioA
            		cpu_data_r <= gpioA_in;
         		when "00110" =>      --counter
            		cpu_data_r <= counter_reg;
         		when "10000" =>      --buttons
            		cpu_data_r <= buttons_values;
         		when "10001" =>      --buttons
            		cpu_data_r <= buttons_change;
            		when "10010" => -- vga
            	  	cpu_data_r <= data_vga_read;
			when others =>		 -- ce n'est pas pr\E9vu...
			cpu_data_r <= x"FFFFFFFF";
		end case;

			-- ON LIT LES DONNEES EN PROVENANCE DU PCIe 0x3....XX
	when "011" =>
         	case cpu_address(7 downto 4) is
					when "0000"  => cpu_data_r <= ZERO(31 downto 1) & fifo_1_empty;
					when "0001"  => cpu_data_r <= ZERO(31 downto 1) & fifo_2_empty;
					when "0010"  => cpu_data_r <= ZERO(31 downto 1) & fifo_1_full;
					when "0011"  => cpu_data_r <= ZERO(31 downto 1) & fifo_2_full;
					when "0100"  => cpu_data_r <= ZERO(31 downto 1) & fifo_1_valid;
					when "0101"  => cpu_data_r <= ZERO(31 downto 1) & fifo_2_valid;
					when "0110"  => cpu_data_r <= fifo_1_compteur;
					when "0111"  => cpu_data_r <= fifo_2_compteur;
					when "1000"  => cpu_data_r <= fifo_1_out_data;
					when others =>		 -- ce n'est pas pr\E9vu...
						cpu_data_r <= x"FFFFFFFF";
         	end case;

			--
			-- LECTURE DES RESULTATS DES COPROCESSEURS
			--
	when "100" =>
		case cpu_address is
			when x"40000100" => cpu_data_r <= buttons_values;
			when x"40000104" => cpu_data_r <= buttons_change;
			when others =>
			 	case cpu_address(7 downto 0) is
							when "00000100"  => cpu_data_r <= cop_1_output;      -- COPROCESSOR 1 (OUTPUT)
							when "00110100"  => cpu_data_r <= cop_2_output;      -- COPROCESSOR 2 (OUTPUT)
							when "01100100"  => cpu_data_r <= cop_3_output;      -- COPROCESSOR 3 (OUTPUT)
							when "10010100"  => cpu_data_r <= cop_4_output;      -- COPROCESSOR 4 (OUTPUT)
              when "10100100"  => cpu_data_r <= oled_output;    -- CONTROLLER SWITCH LED (OUTPUT)
							when "11000100"  => cpu_data_r <= ctrl_SL_output;    -- CONTROLLER SWITCH LED (OUTPUT)
							when others =>	 cpu_data_r <= x"FFFFFFFF";
			 	end case;
		end case;

			--when "011" =>         --flash
         --	cpu_data_r <= data_read;
      	when others =>
      	   cpu_data_r <= ZERO(31 downto 8) & x"FF";
      end case;



      if reset = '1' then
         irq_mask_reg <= ZERO(7 downto 0);
         gpio0_reg    <= ZERO;
         counter_reg  <= ZERO;
      elsif rising_edge(clk) then
         if cpu_pause = '0' then
            if enable_misc = '1' and write_enable = '1' then
               if cpu_address(6 downto 4) = "001" then
                  irq_mask_reg <= cpu_data_w(7 downto 0);
               elsif cpu_address(6 downto 4) = "011" then
                  gpio0_reg <= gpio0_reg or cpu_data_w;
               elsif cpu_address(6 downto 4) = "100" then
                  gpio0_reg <= gpio0_reg and not cpu_data_w;
               end if;
            end if;
         end if;
         counter_reg <= bv_inc(counter_reg);
      end if;
   end process;



   ram_proc: process(cache_access, cache_miss,
                     address_next, cpu_address,
                     byte_we_next, cpu_data_w,
							dma_address,
							dma_byte_we, eth_pause,
							dma_data_write,
							dma_start)
   begin
      if eth_pause = '1' then    --Check if cache hit or write through
         if dma_address(31 downto 28) = "0000" then
            ram_boot_enable <= '1';
         else
            ram_boot_enable <= '0';
         end if;
         if dma_address(31 downto 28) = "0001" then
            enable_local_mem <= '1';
         else
            enable_local_mem <= '0';
         end if;

		   ram_address <= dma_address(31 downto 2);	-- adr from ram
		   ram_byte_we <= dma_byte_we;
         ram_data_w  <= dma_data_write;

		else --Normal non-cache access
         if address_next(31 downto 28) = "0000" then
            ram_boot_enable <= '1';
         else
            ram_boot_enable <= '0';
         end if;
         if address_next(31 downto 28) = "0001" then
            enable_local_mem <= '1';
         else
            enable_local_mem <= '0';
         end if;
         ram_byte_we              <= byte_we_next;
         ram_address(31 downto 2) <= address_next(31 downto 2);
         ram_data_w               <= cpu_data_w;
      end if;
   end process;

	--
	-- RAM DATA CONTROLLER
	--
   --ram_boot_enable <= '1' WHEN (ram_enable = '1') AND eth_pause = '0' ELSE '0';
   u2_boot: ram
      generic map (memory_type => memory_type)
      port map (
         clk               => clk,
         enable            => ram_boot_enable,
         write_byte_enable => ram_byte_we,
         address           => ram_address,
         data_write        => ram_data_w,
         data_read         => ram_data_r);


	-- ON RELIT L'ENTREE DU PCIe (port de sortie) AU BUS DE DONNEE DU PROCESSEUR
	-- PLASMA
	fifo_2_in_data <= cpu_data_w;

	--
	-- UART CONTROLLER CAN BE REMOVED (FOR ASIC DESIGN)
	--
   uart_gen: if eUart = '1' generate
	   u3_uart: uart
      generic map (log_file => log_file)
      port map(
         clk          => clk,
         reset        => reset,
         enable_read  => enable_uart_read,
         enable_write => enable_uart_write,
         data_in      => cpu_data_w(7 downto 0),
         data_out     => data_read_uart,
         uart_read    => uart_read,
         uart_write   => uart_write,
         busy_write   => uart_write_busy,
         data_avail   => uart_data_avail
		);
   end generate;

   uart_gen2: if eUart = '0' generate
         data_read_uart  <= "00000000";
         uart_write_busy <= '0';
         uart_data_avail <= '0';
   end generate;

	--
	-- Buttons controller
	--

  plasma_buttons_controller: buttons_controller
      port map(
         clock          => clk,
         reset        => reset,
         buttons_access => enable_buttons,
	 btnC => btnC,
	 btnU => btnU,
         btnD => btnD,
         btnL => btnL,
         btnR => btnR,
         buttons_values => buttons_values,
         buttons_change => buttons_change
      );

--   vga_controler: vga_ctrl port map(
--		clock          => clk,
--		clock_VGA      => clk_VGA,
--		reset          => reset,
--		vga_w         => cpu_data_w,
--		vga_w_en  => enable_vga_write,
--		vga_r       => data_vga_read,
--		vga_r_en => enable_vga_read,
--		VGA_hs => VGA_hs,
--		VGA_vs => VGA_vs,
--		VGA_red => VGA_red,
--		VGA_green => VGA_green,
--		VGA_blue => VGA_blue
--	);

	--
	-- ETHERNET CONTROLLER CAN BE REMOVED (FOR ASIC DESIGN)
	--
--   dma_gen: if ethernet = '2' generate
--      address      <= cpu_address(31 downto 2);
--      byte_we      <= cpu_byte_we;
--      data_write   <= cpu_data_w;
--      eth_pause    <= '0';
--      irq_eth_rec  <= '0';
--      irq_eth_send <= '0';
--      gpio0_out(28 downto 24) <= ZERO(28 downto 24);
--   end generate;

--   dma_gen2: if ethernet = '1' generate
--   u4_eth: eth_dma
--      port map(
--         clk         => clk,
--         reset       => reset,
--         enable_eth  => gpio0_reg(24),
--         select_eth  => enable_eth,
--         rec_isr     => irq_eth_rec,
--         send_isr    => irq_eth_send,
--
--         address     => address,      --to DDR
--         byte_we     => byte_we,
--         data_write  => data_write,
--         data_read   => data_read,
--         pause_in    => eth_pause_in,
--
--         mem_address => cpu_address(31 downto 2), --from CPU
--         mem_byte_we => cpu_byte_we,
--         data_w      => cpu_data_w,
--         pause_out   => eth_pause,
--
--         E_RX_CLK    => gpioA_in(20),
--         E_RX_DV     => gpioA_in(19),
--         E_RXD       => gpioA_in(18 downto 15),
--         E_TX_CLK    => gpioA_in(14),
--         E_TX_EN     => gpio0_out(28),
--         E_TXD       => gpio0_out(27 downto 24));
--   end generate;

	dma_start <= '1' when ((cpu_address(31 downto 28) = "1000") and (cpu_byte_we = "1111")) else '0';

	------------------------------------------------------------------------------------------------------
	--
	--
	--
	--
	--
	------------------------------------------------------------------------------------------------------

   dma_input_mux_proc: process(clk, reset, dma_address, enable_misc,
      ram_data_r, data_read_uart, cpu_pause,
      irq_mask_reg, irq_status, gpio0_reg, write_enable,
      cache_checking,
      gpioA_in, counter_reg, cpu_data_w, ram_data_lm,
		fifo_1_empty, fifo_2_empty, fifo_1_full, fifo_2_full,
		fifo_1_valid, fifo_2_valid, fifo_1_compteur, fifo_2_compteur, fifo_1_out_data)
   begin
      case dma_address(30 downto 28) is
      	when "000" =>         --internal ROM
         	dma_data_read <= ram_data_r;
      	when "001" =>         --external (local) RAM
				dma_data_read <= ram_data_lm;
			when "010" =>         --misc
         	case dma_address(6 downto 4) is
         		when "000" =>  dma_data_read <= ZERO(31 downto 8) & data_read_uart;
        		 	when "001" =>  dma_data_read <= ZERO(31 downto 8) & irq_mask_reg;
         		when "010" =>  dma_data_read <= ZERO(31 downto 8) & irq_status;
         		when "011" =>  dma_data_read <= gpio0_reg;
         		when "101" =>  dma_data_read <= gpioA_in;
         		when "110" =>  dma_data_read <= counter_reg;
					when others =>	dma_data_read <= x"FFFFFFFF";
				end case;
			when "011" =>
         	case dma_address(7 downto 4) is
					when "0000"  => dma_data_read <= ZERO(31 downto 1) & fifo_1_empty;
					when "0001"  => dma_data_read <= ZERO(31 downto 1) & fifo_2_empty;
					when "0010"  => dma_data_read <= ZERO(31 downto 1) & fifo_1_full;
					when "0011"  => dma_data_read <= ZERO(31 downto 1) & fifo_2_full;
					when "0100"  => dma_data_read <= ZERO(31 downto 1) & fifo_1_valid;
					when "0101"  => dma_data_read <= ZERO(31 downto 1) & fifo_2_valid;
					when "0110"  => dma_data_read <= fifo_1_compteur;
					when "0111"  => dma_data_read <= fifo_2_compteur;
					when "1000"  => dma_data_read <= fifo_1_out_data;
					when others  => dma_data_read <= x"FFFFFFFF";
         	end case;
      	when others =>
      	   dma_data_read <= ZERO(31 downto 8) & x"FF";
      end case;
	end process;

   u4_dma: entity WORK.dma_engine port map(
		clk         => clk,
		reset       => reset,
		start_dma   => dma_start,
		--
		address     => dma_address,	-- adr from ram
		byte_we     => dma_byte_we,
		data_write  => dma_data_write,
		data_read   => dma_data_read,
		--
		mem_address => cpu_address,	-- adr from cpu
		mem_byte_we => cpu_byte_we,
		data_w      => cpu_data_w,
		pause_out   => eth_pause
	);


	------------------------------------------------------------------------------------------------------
	--
	--
	--
	--
	--
	------------------------------------------------------------------------------------------------------

--   u5a_coproc: entity WORK.coproc_1 port map(
--		clock          => clk,
--		reset          => cop_1_reset,
--		INPUT_1        => cpu_data_w,
--		INPUT_1_valid  => cop_1_valid,
--		OUTPUT_1       => cop_1_output
--	);

--   u5b_coproc: entity WORK.coproc_2 port map(
--		clock          => clk,
--		reset          => cop_2_reset,
--		INPUT_1        => cpu_data_w,
--		INPUT_1_valid  => cop_2_valid,
--		OUTPUT_1       => cop_2_output
--	);

--   u5c_coproc: entity WORK.coproc_3 port map(
--		clock          => clk,
--		reset          => cop_3_reset,
--		INPUT_1        => cpu_data_w,
--		INPUT_1_valid  => cop_3_valid,
--		OUTPUT_1       => cop_3_output
--	);

-- seven segment display management bloc


  ctrl_7seg1: entity WORK.ctrl_7seg port map(
      clock          => clk,
      reset          => reset,
      INPUT_1        => cpu_data_w,
      INPUT_1_valid  => ctrl_7seg_valid,
      OUTPUT_7s      => seg,
      AN             => an
  );

-- Controller Switchs/Leds
	plasma_ctrl_SL: ctrl_SL port map (
		clock			     => clk,
		reset			     => ctrl_SL_reset,
		INPUT_1		     => cpu_data_w,
		INPUT_1_valid	 => ctrl_SL_valid,
		OUTPUT_1		   => ctrl_SL_output,
		SW				     => sw,
		LED				     => led,
		RGB1_Red		   => RGB1_Red,
		RGB2_Red		   => RGB2_Red,
		RGB1_Green	   => RGB1_Green,
		RGB2_Green		 => RGB2_Green,
		RGB1_Blue		   => RGB1_Blue,
		RGB2_Blue		   => RGB2_Blue
	);


  -- OLED
  	plasma_oled: PmodOLEDrgb_charmap
    Generic map(CLK_FREQ_HZ => CLK_FREQ_HZ,
                PARAM_BUFF  => True,            -- necessary because we connect CPU bus directly and there is no solution to get it buffered
                LEFT_SIDE   => LEFT_SIDE)           -- True if the Pmod is on the left side of the board

     port map (
  		clk          => clk,
      reset        => oled_reset,

      char_write   => oled_valid,
      char_col     => cpu_data_w( 19 downto 16 ),
      char_row     => cpu_data_w( 10 downto 8 ),
      char         => cpu_data_w( 7 downto 0 ),
      ready        => oled_output(0),

      --scroll_up    => cpu_data_w(26),
      --row_clear    => cpu_data_w(25),
      screen_clear => cpu_data_w(24),

      PMOD_CS      => OLED_PMOD_CS,
      PMOD_MOSI    => OLED_PMOD_MOSI,
      PMOD_SCK     => OLED_PMOD_SCK,
      PMOD_DC      => OLED_PMOD_DC,
      PMOD_RES     => OLED_PMOD_RES,
      PMOD_VCCEN   => OLED_PMOD_VCCEN,
      PMOD_EN      => OLED_PMOD_EN
  	);

--	u5d_coproc: entity WORK.coproc_3 port map(-- atention 2x coproc 3
--         clock          => clk,
--         reset          => cop_4_reset,
--         INPUT_1        => cpu_data_w,
--         INPUT_1_valid  => cop_4_valid,
--         OUTPUT_1       => cop_4_output
--      );

--   u5d_coproc: entity WORK.coproc_4 port map(
--		clock          => clk,
--		clock_VGA      => clk_VGA,
--		reset          => cop_4_reset,
--		INPUT_1        => cpu_data_w,
--		INPUT_1_valid  => cop_4_valid,
--		OUTPUT_1       => cop_4_output,
--		VGA_hs => VGA_hs,
--		VGA_vs => VGA_vs,
--		VGA_red => VGA_red,
--		VGA_green => VGA_green,
--		VGA_blue => VGA_blue
--	);


end; --architecture logic
