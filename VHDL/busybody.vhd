----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:56:13 03/04/2014 
-- Design Name: 
-- Module Name:    busybody - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity busybody is
    Port ( LED : out  STD_LOGIC_VECTOR (9 downto 1);
           TestPointCustom : out  STD_LOGIC;
           HeaderCustom : inout  STD_LOGIC_VECTOR (7 downto 1);
           AddressHigh : in  STD_LOGIC_VECTOR (23 downto 16);
           AddressLow : in  STD_LOGIC_VECTOR (4 downto 1);
           FunctionCode : in  STD_LOGIC_VECTOR (2 downto 0);
           InterruptN : out  STD_LOGIC_VECTOR (2 downto 0);
           BusErrorN : out  STD_LOGIC;
           AutoVectorN : inout  STD_LOGIC;
           ResetN : inout  STD_LOGIC;
           HaltN : inout  STD_LOGIC;
           Mode : out  STD_LOGIC;
           Clock : in  STD_LOGIC;
           BusRequestN : out  STD_LOGIC;
           BusGrantAcknowledgeN : out  STD_LOGIC;
           BusGrantN : in  STD_LOGIC;
           DataTransferAcknowledgeN : out  STD_LOGIC;
           MpuReadWriteN : in  STD_LOGIC;
           LowerDataStrobeN : in  STD_LOGIC;
           UpperDataStrobeN : in  STD_LOGIC;
           AddressStrobeN : in  STD_LOGIC;
           LedDebug : out  STD_LOGIC;
           ButtonDebug : in  STD_LOGIC;
           ButtonReset : in  STD_LOGIC;
           DipSwitchN : in  STD_LOGIC_VECTOR (2 downto 1);
           RamUpperWriteEnableN : out  STD_LOGIC;
           RamUpperOutputEnableN : out  STD_LOGIC;
           RamUpperChipEnableN : out  STD_LOGIC;
           RamLowerWriteEnableN : out  STD_LOGIC;
           RamLowerOutputEnableN : out  STD_LOGIC;
           RamLowerChipEnableN : out  STD_LOGIC;
           RomUpperChipEnableN : out  STD_LOGIC;
           RomLowerChipEnableN : out  STD_LOGIC;
           DuartInterruptRequestN : in  STD_LOGIC;
           DuartDataTransferAcknowledgeN : in  STD_LOGIC;
           DuartReadWriteN : out  STD_LOGIC;
           DuartInterruptAcknowledgeN : out  STD_LOGIC;
           DuartChipSelectN : out  STD_LOGIC;
           DuartResetN : out  STD_LOGIC;
           DuartClock : in  STD_LOGIC);
end busybody;

architecture Behavioral of busybody is

    -- Active-HIGH negations of active-LOW signals
    signal Interrupt : STD_LOGIC_VECTOR (2 downto 0);
    signal BusError : STD_LOGIC;
    signal AutoVector : STD_LOGIC;
    signal Reset : STD_LOGIC;
    signal Halt : STD_LOGIC;
    signal BusRequest : STD_LOGIC;
    signal BusGrantAcknowledge : STD_LOGIC;
    signal BusGrant : STD_LOGIC;
    signal DataTransferAcknowledge : STD_LOGIC;
    signal MpuReadWrite : STD_LOGIC;
    signal LowerDataStrobe : STD_LOGIC;
    signal UpperDataStrobe : STD_LOGIC;
    signal AddressStrobe : STD_LOGIC;
    signal DipSwitch : STD_LOGIC_VECTOR (2 downto 1);
    signal RamUpperWriteEnable : STD_LOGIC;
    signal RamUpperOutputEnable : STD_LOGIC;
    signal RamUpperChipEnable : STD_LOGIC;
    signal RamLowerWriteEnable : STD_LOGIC;
    signal RamLowerOutputEnable : STD_LOGIC;
    signal RamLowerChipEnable : STD_LOGIC;
    signal RomUpperChipEnable : STD_LOGIC;
    signal RomLowerChipEnable : STD_LOGIC;
    signal DuartInterruptRequest : STD_LOGIC;
    signal DuartDataTransferAcknowledge : STD_LOGIC;
    signal DuartReadWrite : STD_LOGIC;
    signal DuartInterruptAcknowledge : STD_LOGIC;
    signal DuartChipSelect : STD_LOGIC;
    signal DuartReset : STD_LOGIC;
    
    -- Divided clock vector
    signal clockDivided : std_logic_vector (23 downto 0);
    
    -- Smaller parts of the clock vector
    signal i : std_logic_vector (3 downto 0);
    signal tq : std_logic;
    signal h : std_logic;
    signal q : std_logic;
    signal i0 : std_logic;
    signal i1 : std_logic;
    signal i2 : std_logic;
    signal i3 : std_logic;
    signal i4 : std_logic;
    signal i5 : std_logic;
    signal i6 : std_logic;
    signal i7 : std_logic;
    signal i8 : std_logic;
    signal i9 : std_logic;
    signal i10 : std_logic;
    signal i11 : std_logic;
    signal i12 : std_logic;
    signal i13 : std_logic;
    signal i14 : std_logic;
    signal i15 : std_logic;
    
    -- Bootup flag
    signal bootingUp : std_logic := '1';
    signal bootingUpVector : std_logic_vector (9 downto 1);
    
    -- Delayed address-ready flag for DTACK
    signal addressReady : std_logic := '0';
    
    -- Decorative LED patterns
    signal pingPattern : std_logic_vector (9 downto 1);
    signal loadingPattern : std_logic_vector (9 downto 1);

begin

   -- Negate active-LOW signals to active-HIGH
     InterruptN <= not(Interrupt);
     BusErrorN <= not(BusError);
     AutoVectorN <= not(AutoVector);
     ResetN <= not(Reset);
     HaltN <= not(Halt);
     BusRequestN <= not(BusRequest);
     BusGrantAcknowledgeN <= not(BusGrantAcknowledge);
     BusGrant <= not(BusGrantN);
     DataTransferAcknowledgeN <= not(DataTransferAcknowledge);
     MpuReadWrite <= not(MpuReadWriteN);
     LowerDataStrobe <= not(LowerDataStrobeN);
     UpperDataStrobe <= not(UpperDataStrobeN);
     AddressStrobe <= not(AddressStrobeN);
     DipSwitch <= not(DipSwitchN);
     RamUpperWriteEnableN <= not(RamUpperWriteEnable);
     RamUpperOutputEnableN <= not(RamUpperOutputEnable);
     RamUpperChipEnableN <= not(RamUpperChipEnable);
     RamLowerWriteEnableN <= not(RamLowerWriteEnable);
     RamLowerOutputEnableN <= not(RamLowerOutputEnable);
     RamLowerChipEnableN <= not(RamLowerChipEnable);
     RomUpperChipEnableN <= not(RomUpperChipEnable);
     RomLowerChipEnableN <= not(RomLowerChipEnable);
     DuartInterruptRequest <= not(DuartInterruptRequestN);
     DuartDataTransferAcknowledge <= not(DuartDataTransferAcknowledgeN);
     DuartReadWriteN <= not(DuartReadWrite);
     DuartInterruptAcknowledgeN <= not(DuartInterruptAcknowledge);
     DuartChipSelectN <= not(DuartChipSelect);
     DuartResetN <= not(DuartReset);
   
   -- Divide clock signal
   process (Clock)
   begin
      if (Clock'Event and Clock = '1') then
         clockDivided <= (clockDivided + '1');
         addressReady <= AddressStrobe;
      end if;
   end process;
   
   -- Define smaller clocks
   i <= (  3 => clockDivided(22), -- interval length 1/16
           2 => clockDivided(21),
           1 => clockDivided(20),
           0 => clockDivided(19));
   tq <= not(clockDivided(4));                           -- three-quarters brightness
   h <= (not(clockDivided(3)) and not(clockDivided(4))); -- half brightness
   q <= (not(clockDivided(2)) and not(clockDivided(3)) and not(clockDivided(4))); -- quarter brightness
   i0 <= not(i(3)) and not(i(2)) and not(i(1)) and not(i(0));
   i1 <= not(i(3)) and not(i(2)) and not(i(1)) and i(0);
   i2 <= not(i(3)) and not(i(2)) and i(1) and not(i(0));
   i3 <= not(i(3)) and not(i(2)) and i(1) and i(0);
   i4 <= not(i(3)) and i(2) and not(i(1)) and not(i(0));
   i5 <= not(i(3)) and i(2) and not(i(1)) and i(0);
   i6 <= not(i(3)) and i(2) and i(1) and not(i(0));
   i7 <= not(i(3)) and i(2) and i(1) and i(0);
   i8 <= i(3) and not(i(2)) and not(i(1)) and not(i(0));
   i9 <= i(3) and not(i(2)) and not(i(1)) and i(0);
   i10 <= i(3) and not(i(2)) and i(1) and not(i(0));
   i11 <= i(3) and not(i(2)) and i(1) and i(0);
   i12 <= i(3) and i(2) and not(i(1)) and not(i(0));
   i13 <= i(3) and i(2) and not(i(1)) and i(0);
   i14 <= i(3) and i(2) and i(1) and not(i(0));
   i15 <= i(3) and i(2) and i(1) and i(0);
   
   -- Bootup
   process(i15)
   begin
      if (i15'Event and i15 = '1') then
         bootingUp <= '0';
      end if;
   end process;
   
   bootingUpVector <= (others => bootingUp);
   
   -- Decorative LED "Ping" pattern
   pingPattern <= (  9 => (i8) or (i9 and tq) or (i10 and h) or (i11 and q),
                     8 => (i7) or (i8 and tq) or (i9) or (i10 and tq) or (i11 and h) or (i12 and q),
                     7 => (i6) or (i7 and tq) or (i8 and h) or (i9 and q) or (i10) or (i11 and tq) or (i12 and h) or (i13 and q),
                     6 => (i5) or (i6 and tq) or (i7 and h) or (i8 and q) or (i11) or (i12 and tq) or (i13 and h) or (i14 and q),
                     5 => (i4) or (i5 and tq) or (i6 and h) or (i7 and q) or (i12) or (i13 and tq) or (i14 and h) or (i15 and q),
                     4 => (i0 and q) or (i3) or (i4 and tq) or (i5 and h) or (i6 and q) or (i13) or (i14 and tq) or (i15 and h),
                     3 => (i0 and h) or (i1 and q) or (i2) or (i3 and tq) or (i4 and h) or (i5 and q) or (i14) or (i15 and tq),
                     2 => (i0 and tq) or (i1) or (i2 and tq) or (i3 and h) or (i4 and q) or (i15),
                     1 => (i0) or (i1 and tq) or (i2 and h) or (i3 and q)
                     );
   
   -- Decorative LED "Loading" pattern
   loadingPattern <= (  9 => i0 or i1 or i2 or i3 or i4 or i5 or i6 or i7 or i8,
                        8 => i1 or i2 or i3 or i4 or i5 or i6 or i7 or i8 or i9,
                        7 => i2 or i3 or i4 or i5 or i6 or i7 or i8 or i9 or i10,
                        6 => i3 or i4 or i5 or i6 or i7 or i8 or i9 or i10 or i11,
                        5 => i4 or i5 or i6 or i7 or i8 or i9 or i10 or i11 or i12,
                        4 => i5 or i6 or i7 or i8 or i9 or i10 or i11 or i12 or i13,
                        3 => i6 or i7 or i8 or i9 or i10 or i11 or i12 or i13 or i14,
                        2 => i7 or i8 or i9 or i10 or i11 or i12 or i13 or i14 or i15,
                        1 => i8 or i9 or i10 or i11 or i12 or i13 or i14 or i15
                        );
   
   -- Output values
   LED <= (bootingUpVector and loadingPattern) or (not(bootingUpVector) and pingPattern);
   TestPointCustom <= '0';
   HeaderCustom <= ( 1 => DuartReset,
                     2 => Reset,
                     3 => MpuReadWrite,
                     4 => AddressHigh(20),
                     5 => AddressHigh(19),
                     6 => AddressLow(2),
                     7 => AddressLow(1)
                     );
   Interrupt <= "000"; -- lowest bit is asserted when DUART need attention
   BusError <= '0'; -- tried to access an unused address
   AutoVector <= '0';
   Reset <= not(ButtonReset) or bootingUp;
   Halt <= not(ButtonReset) or bootingUp;
   Mode <= '1';
   BusRequest <= '0';
   BusGrantAcknowledge <= '0';
   DataTransferAcknowledge <= (addressReady and (UpperDataStrobe or LowerDataStrobe) and not(DuartChipSelect)) or (DuartChipSelect and DuartDataTransferAcknowledge);
   LedDebug <= not(ButtonDebug);
   RamUpperWriteEnable <= MpuReadWrite and RamUpperChipEnable;
   RamUpperOutputEnable <= not(MpuReadWrite) and RamUpperChipEnable;
   RamUpperChipEnable <= not(AddressHigh(20)) and AddressHigh(19) and UpperDataStrobe;
   RamLowerWriteEnable <= MpuReadWrite and RamLowerChipEnable;
   RamLowerOutputEnable <= not(MpuReadWrite) and RamLowerChipEnable;
   RamLowerChipEnable <= not(AddressHigh(20)) and AddressHigh(19) and LowerDataStrobe;
   RomUpperChipEnable <= not(AddressHigh(20)) and not(AddressHigh(19)) and UpperDataStrobe and AddressStrobe;
   RomLowerChipEnable <= not(AddressHigh(20)) and not(AddressHigh(19)) and LowerDataStrobe and AddressStrobe;
   DuartReadWrite <= MpuReadWrite and DuartChipSelect;
   DuartInterruptAcknowledge <= '0';
   DuartChipSelect <= AddressHigh(20) and not(AddressHigh(19)) and AddressStrobe;
   DuartReset <= not(ButtonReset) or bootingUp;

end Behavioral;

