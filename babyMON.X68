*-----------------------------------------------------------
* Operating system : babyMON
* Written by       : Logan Turner
* Date             : March 2014
* Description      : monitor program for a 68k-based microcomputer
*-----------------------------------------------------------


****************************************************************
* Assembly Constants:	(Note the offsets to account for no A0)
*
DUART   	EQU	    $100000     loaded in A0 when needed, regs are offsets
MR1A   	    EQU   	1	Mode Register1
MR2A  	    EQU   	1	points here after MR1A is set
SRA    	    EQU   	3   Status Register (read)
CSRA   	    EQU   	3   Clock Select Register
CRA   	    EQU   	5	Command Register
TBA		    EQU   	7   Transfer Holding Register
RBA		    EQU   	7	Receive Holding Register
ACR		    EQU	  	9	Auxiliary control register
RxRDY		EQU		0	Recieve ready bit position
TxRDY		EQU		2	Transmit ready bit position
TestBRG     EQU     5   Test BRG register
BAUD		EQU	  	$66   baud rate value = 115,200 baud
*
CR          EQU     $0D     Carriage Return
LF          EQU     $0A     Line Feed
ESC         EQU     $1B     Escape
DEL         EQU     $F7     Delete
BS          EQU     $08     Backspace

****************************************************************
* Main Program
*
STACK       EQU     $80800      RAM location for stack
PGMSTART    EQU     $81000      RAM location for uploaded S-Record

START   	ORG     $000000
        	DC.L    STACK
        	DC.L    MAIN

        	ORG     $000100        
MAIN    	JSR     INIT_DUART
            BRA     MENU

****************************************************************
* Menu
*
MENU        EQU     *
* Set default option
* Clear screen
* Draw banner
* Draw logo and options
* Draw carat
* Wait for character
* If ENTER, jump to option
* If arrow, change option
            MOVE.L  #00,D2              D2 represents which option is selected
MENU1       BSR     CLRSCREEN
            LEA     MENUBANNER(PC),A4   Draw menu
            BSR     PSTRING
            LEA     MENUSCREEN(PC),A4
            BSR     PSTRING
            LEA     OP1CARAT(PC),A4
            CMP.B   #00,D2              Option 1 (registers) selected?
            BEQ     MENU2
            LEA     OP2CARAT(PC),A4
            CMP.B   #01,D2              Option 2 (memory) selected?
            BEQ     MENU2
            LEA     OP3CARAT(PC),A4
            CMP.B   #02,D2              Option 3 (s-record) selected?
            BEQ     MENU2
            LEA     OP4CARAT(PC),A4     Option 4 (jump to program) must be selected
MENU2       BSR     PSTRING
            BSR     GCHAR
            CMP.B   #CR,D0               Get a character from user
            BEQ     MENU7               ENTER was hit
            CMP.B   #'a',D0
            BNE     MENU3
            ADD.B   #02,D2              If 'a' was hit, go backwards
MENU3       CMP.B   #'w',D0
            BNE     MENU4
            ADD.B   #02,D2              If 'w' was hit, go backwards
MENU4       ADD.B   #01,D2              Any other key goes forwards
            CMP.B   #03,D2
            BLE     MENU6
            SUB.B   #04,D2              If option selector is out of range, subtract 4
MENU6       BRA     MENU1
MENU7       CMP.B   #00,D2
            BEQ     MODREG              Branch to option 1 (registers)
            CMP.B   #01,D2
            BEQ     MODMEM              Branch to option 2 (memory)
            CMP.B   #02,D2
            BEQ     LDSREC              Branch to option 3 (load s-record)
            CMP.B   #03,D2
            BNE     MENU                Something went wrong, restart menu
            BRA     JMPPGM              Option 4, jump to program
            BRA     MENU

****************************************************************
* Modify Registers
*
MODREG      EQU     *
            BSR     CLRSCREEN
            LEA     REGBANNER(PC),A4    Draw banner
            BSR     PSTRING
            LEA     REGSCREEN(PC),A4     Draw mockup modify register screen
            BSR     PSTRING
            BSR     GCHAR
            BRA     MENU

****************************************************************
* Modify Memory
*           
*
MODMEM      EQU     *
            * set up default address block, view mode, address digit
            * A5 is the base address of the selected block
            MOVE.L  #PGMSTART,A5
            * D3 is View/Edit toggle (00 = View, FF = Edit)
            MOVE.B  #$00,D3
            * D4 is selected digit (View mode: 00-03, Edit mode: 00-1F)
            MOVE.B  #$00,D4
            * D5 is the iterating offset
            * D6 is the iterating block address
refreshMemory BSR     drawMemoryScreen
            BSR     editMemoryCommand
            BRA     refreshMemory
            
editMemoryCommand  EQU     *
* Accepts a key of input from the user and performs a command based on it
* Inputs:   A5 = base address
*           D3 = view/edit toggle
*           D4 = selected digit
* Outputs:  A5 = change base address
*           D0 = input user character
*           D3 = change between view/edit
*           D4 = change selected digit
            
            BSR     GCHAR       Get char input from user into D0
            CMP.B   #ESC,D0     ESC = branch to menu
            BEQ     MENU
            CMP.B   #CR,D0      CR = toggle view/edit and set selected digit to $00
            BEQ     toggleViewEdit
            CMP.B   #BS,D0     Backspace = decrement selected digit
            BEQ     decrementSelectedDigit
            BSR     editDigitIfAscii 0-F = change selected digit of address or RAM and increment selected digit
            CMP.B   #'w',D0     w = decrement base address by $10
            BEQ     decrementBaseAddress
            CMP.B   #'s',D0     s = increment base address by $10
            BEQ     incrementBaseAddress
            BRA     incrementSelectedDigit anything else (tab, space) = increment selected digit

editDigitIfAscii MOVEM.L D0-D4,-(SP) Store into stack
            BSR     HexToBinary Convert character into nibble in D1
            BCS     ediaDone    If carry flag is set, not an ASCII char. Done
            CMP     #$FF,D3     Edit mode?
            BEQ     ediaEditMode Skip
            MOVEM.L D4,-(SP)    Store selected digit temporarily to stack
            MOVE.L  A5,D2       Work with the base address in D2
            LSR.L   #4,D2       Remove the bottom nibble of the address
            BRA     ediaSkip1
ediaRor     ROR.W   #4,D2       Rotate the base address until correct nibble is showing
            ADD     #1,D4       Increment the selected digit until it equals 03
ediaSkip1   CMP     #03,D4
            BNE     ediaRor
            AND.B   #$F0,D2 Clear bottom four bits of the base address
            ADD.B   D1,D2       Add user input value to the base address
            MOVEM.L (SP)+,D4    Retrieve selected digit from stack
            BRA     ediaSkip2
ediaRol     ROL.W   #4,D2       Rotate back
            ADD     #1,D4
ediaSkip2   CMP     #03,D4
            BNE     ediaRol
            LSL.L   #4,D2       Return useless bottom nibble
            MOVE.L  D2,A5       Put modified base address back into A5
            BRA     ediaDone
ediaEditMode MOVEM.L A5,-(SP)   Store A6 temporarily in the stack
            ROL.B   #4,D1       Flip the data for the first test
            MOVE.L  #$0F,D2     D2 holds the mask
ediaFlip    CMP     #0,D4       Is the selected digit zero?
            BEQ     ediaFlipDone
            ROL.B   #4,D1       If not, flip D1 and D2 and subtract 1 from selected digit
            ROL.B   #4,D2
            SUB     #1,D4
            CMP     #0,D4       Is the selected digit zero?
            BEQ     ediaFlipDone 
            ROL.B   #4,D1       If not, flip both bytes, subtract 1, and increment the address
            ROL.B   #4,D2
            SUB     #1,D4
            ADD.L   #1,A5       
            BRA     ediaFlip    Repeat
ediaFlipDone AND.B   D2,(A5) Clear the nibble
            ADD.B   D1,(A5) Add new data
            MOVEM.L (SP)+,A5    Retrieve A6
ediaDone    MOVEM.L (SP)+,D0-D4 Retrieve from stack
            RTS

toggleViewEdit CMP  #00,D3      View mode?
            BEQ     changeToEdit    Skip
            MOVE.L  #00,D3      Else change to view mode
            BRA     tveDone
changeToEdit MOVE.L #$FF,D3     Change to edit mode
tveDone     MOVE.L  #00,D4      Reset selected digit to 0
            RTS

decrementSelectedDigit SUB #1,D4 Subtract 1 from selected digit
            BPL     dsdDone     If positive, skip
            ADD     #$04,D4     Add $04
            CMP     #00,D3      If view mode, skip
            BEQ     dsdDone
            ADD     #$1C,D4     Add another $1C
dsdDone     RTS

decrementBaseAddress SUB #$10,A5 Add $10 to base address
            RTS

incrementBaseAddress ADD #$10,A5 Subtract $10 from base address
            RTS

incrementSelectedDigit ADD #1,D4 Add 1 to selected digit
            CMP     #00,D3      If view mode, skip
            BEQ     isdViewMode
            CMP     #$20,D4     If less than $20, done
            BMI     isdDone
            SUB     #$20,D4     Subtract $20
            BRA     isdDone     Done
isdViewMode CMP     #$04,D4     View mode: if less than $04, done
            BMI     isdDone
            SUB     #$04,D4     Subtract $04
isdDone     RTS

drawMemoryScreen    EQU     *
* Redraws the whole screen for the modify memory feature
* Inputs:   A5 = base address block,
*           D3 = view/edit toggle
*           D4 = selected digit
            
            MOVEM.L   D5-D7,-(SP)         Store in stack
            BSR     CLRSCREEN
            LEA     MEMBANNER(PC),A4    Draw banner
            BSR     PSTRING
            LEA     MEMHEADER(PC),A4    Draw column headers
            BSR     PSTRING
            MOVE.L  A5,D7               Use D7 as the last block address
            MOVE.L  A5,D6               Copy base address to D6 for iteration
            SUB.L   #$80,D6             Subtract eight rows
MMD1        BSR     drawRow             Draw row
            ADD.L   #$10,D6             Go to next row
            CMP     D6,D7               Different than base address?
            BNE     MMD1                Do it again
            BSR     drawSpecialRow      Draw base row
            MOVE.L  A5,D7               Use D7 as the last block address
            ADD     #$80,D7             Add eight rows to D7
MMD2        ADD     #$10,D6             Go to next row
            BSR     drawRow             Draw row
            CMP     D6,D7               Have we reached the last row?
            BNE     MMD2                If not, do it again
            LEA     MEMFOOTER(PC),A4    Draw column footer
            BSR     PSTRING
            MOVEM.L   (SP)+,D5-D7         Restore from stack
            RTS

drawRow     EQU     *
* Draws a row of memory block address and memory byte data values for that block
* Inputs:   D6 = block address

            MOVE.L  D6,-(SP)
            MOVE.L  A4,-(SP)
            LEA     NOTICKSPACE(PC),A4  Show no tick by default
            CMP.B   #0,D6
            BNE     MMDRNOTICK
            LEA     TICKSPACE(PC),A4    If address block ends in #00, show tick
MMDRNOTICK  BSR     PSTRING
            BSR     drawFiveDigitAddress
            LEA     COLUMNSPACE(PC),A4  Display column spacing
            BSR     PSTRING
            BSR     drawRamData
            LEA     CRLF(PC),A4
            BSR     PSTRING
            MOVE.L  (SP)+,A4
            MOVE.L  (SP)+,D6
            RTS

drawSpecialRow      EQU     *
* Draws the row of memory that is being viewed or edited currently
* Inputs:   D3 = view/edit toggle
*           D4 = selected digit
*           D6 = block address
            
            MOVE.L  A4,-(SP)
            LEA     NOTICKSPACE(PC),A4  Show no tick by default
            CMP.B   #0,D6               Address end in 00?   
            BNE     noTick              If not, skip
            LEA     TICKSPACE(PC),A4    Load tick
            CMP.B   #00,D3              View mode?
            BNE     doneWithStupid      If not, tick only
            LEA     LCARATTICK(PC),A4   Load leftCarat and tick
            BRA     doneWithStupid      Done
noTick      CMP.B   #00,D3              No tick and no carat?
            BNE     doneWithStupid      Done
            LEA     LEFTCARAT(PC),A4    Else load leftCarat only
doneWithStupid  BSR     PSTRING         Print
            CMP.B   #$FF,D3             Edit mode?
            BEQ     noSpecialAddress    Skip the selectable addressing
            BSR     drawSpecialFiveDigitAddress Draw special five-digit address
            BRA     specialAddress      Else do it
noSpecialAddress BSR     drawFiveDigitAddress    Draw regular five-digit address
specialAddress LEA     NORCARAT(PC),A4     Show no right carat by default
            CMP.B   #00,D3              View mode?
            BNE     noRightCarat        If not, no right carat
            LEA     RCARAT(PC),A4       Else do show it
noRightCarat BSR    PSTRING             Print
            LEA     NOLDUBCARAT(PC),A4  Show no leftDoubleCarat by default
            CMP.B   #$FF,D3             Edit mode?
            BNE     noLeftDoubleCarat   If not, no leftDoubleCarat
            LEA     LDUBCARAT(PC),A4    Else do show it
noLeftDoubleCarat BSR   PSTRING         Print
            CMP.B   #00,D3              View mode?
            BEQ     noSpecialRamData    Skip the selectable RAM data
            BSR     drawSpecialRamData  Draw selectable row of bytes from RAM
            BRA     specialRamData      Else do it
noSpecialRamData BSR     drawRamData         Draw regular row of bytes from RAM
specialRamData CMP.B   #$FF,D3             Edit mode?
            BNE     noRightDoubleCarat  If not, no rightDoubleCarat
            LEA     RDUBCARAT(PC),A4    Else do show it
            BSR     PSTRING             Print
noRightDoubleCarat LEA     CRLF(PC),A4
            BSR     PSTRING
            MOVE.L  (SP)+,A4
            RTS

drawRamData EQU     *
* Draws specifically the RAM data for a particular row
* Inputs:   D6 = block address
            
            MOVEM.L A3,-(SP)            Store on stack
            MOVEM.L D2-D5,-(SP)
            ; Eight times: retrieve two bytes, print two bytes
            MOVE.L  D6,A3               A3 is used to retrieve the data
            MOVE.L  D6,D5               D5 is the last address in this row
            ADD     #$10,D5             D5 holds D6's value plus $10
getData     MOVE.W  (A3),D2             Retrieve two bytes into D2
            BSR     BinaryToAsciiHex    Convert into ASCII, store in D3
            ; print four hex digits as two pairs with a space in between
            MOVE.L  #$FF,D4             Put a space when printing
            BSR     Print4AsciiHex      Print four hex characters
            ; add 2
            ADD     #2,A3               Add 2 to the address
            ; if not the last address, do it again
            CMP     A3,D5               Is this too far?
            BNE     getData             If not, do it again
            MOVEM.L (SP)+,D2-D5
            MOVEM.L (SP)+,A3            Restore from stack
            RTS

drawSpecialRamData EQU     *
* Draws specifically the RAM data for a particular row
* Inputs:   D6 = block address
*           D4 = selected digit
            
            MOVEM.L A3,-(SP)            Store on stack
            MOVEM.L D2-D5,-(SP)
            ; Eight times: retrieve two bytes, print two bytes
            MOVE.L  D6,A3               A3 is used to retrieve the data
            MOVE.L  D6,D5               D5 is the last address in this row
            ADD     #$10,D5             D5 holds D6's value plus $10
getSpecialData     MOVE.W  (A3),D2             Retrieve two bytes into D2
            BSR     BinaryToAsciiHex    Convert into ASCII, store in D3
            CMP     #0,D4               Is D4 negative?
            BMI     noUnderscore        Skip underscoring
            CMP     #4,D4               Is D4 = 4 or greater?
            BPL     noUnderscore        Skip underscoring
            MOVEM.L D4,-(SP)            Temporarily store D4
rotateRamLeft ROL.L   #8,D3             Rotate left
            SUB     #1,D4               Subtract 1 from D4
            BPL     rotateRamLeft       If negative continue, else repeat
            MOVE.B  #'_',D3             Replace byte with '_'
            MOVEM.L (SP),D4             Copy D4 from stack
rotateRamRight ROR.L   #8,D3            Rotate right
            SUB     #1,D4               Subtract 1 from D4
            BPL     rotateRamRight      If negative continue, else repeat
            MOVEM.L (SP)+,D4            Retrieve D4 from stack
noUnderscore MOVEM.L D4,-(SP)            Temporarily store D4
            MOVE.L  #$FF,D4            Put a space when printing
            BSR     Print4AsciiHex      Print four hex characters
            MOVEM.L (SP)+,D4            Retrieve D4 from stack
            ADD     #2,A3               Add 2 to the address
            SUB     #4,D4               Subtract 4 from D4
            CMP     A3,D5               Is this too far?
            BNE     getSpecialData      If not, do it again
            MOVEM.L (SP)+,D2-D5
            MOVEM.L (SP)+,A3            Restore from stack
            RTS

drawFiveDigitAddress   EQU     *
* Prints a five-digit address
* Inputs:   D6 = block address
            
            MOVEM.L   D0-D4,-(SP)         Store in stack
            MOVE.L  D6,D2               Move address into input for conversion subroutine
            ROR.L   #4,D2               Rotate last useless nibble out of the way
            BSR     BinaryToAsciiHex    Convert to ASCII, store in D3
            MOVE.L  #0,D4               No space in between when printing
            BSR     Print4AsciiHex      Print
            MOVE.L  #'0',D0             Load trailing '0' into print input
            BSR     PCHAR               Print
            MOVEM.L   (SP)+,D0-D4         Restore from stack
            RTS
            
drawSpecialFiveDigitAddress   EQU     *
* Prints a five-digit address
* Inputs:   D6 = block address
*           D4 = selected digit
            
            MOVEM.L   D0-D4,-(SP)         Store in stack
            MOVE.L  D6,D2               Move address into input for conversion subroutine
            ROR.L   #4,D2               Rotate last useless nibble out of the way
            BSR     BinaryToAsciiHex    Convert to ASCII, store in D3
            MOVEM.L D4,-(SP)            Store D4 on the stack
rotateLeft  ROL.L   #8,D3               Rotate left
            SUB     #1,D4               Subtract 1 from D4
            BPL     rotateLeft          If negative continue, else repeat
            MOVE.B  #'_',D3             Replace byte with '_'
            MOVEM.L (SP)+,D4            Restore D4 from stack
rotateRight ROR.L   #8,D3               Rotate right
            SUB     #1,D4               Subtract 1 from D4
            BPL     rotateRight         If negative continue, else repeat
            MOVE.L  #0,D4               No space in between when printing
            BSR     Print4AsciiHex      Print
            MOVE.L  #'0',D0             Load trailing '0' into print input
            BSR     PCHAR               Print
            MOVEM.L   (SP)+,D0-D4         Restore from stack
            RTS

****************************************************************
* Load S-Record
*
LDSREC      EQU     *
            BRA     MENU
****************************************************************
* Jump to Program
*
JMPPGM      EQU     *
            CMP.B   #$FF,PGMSTART
            BEQ     JMPPGM1
            JSR     PGMSTART
            BRA     MENU
JMPPGM1     BSR     CLRSCREEN
            LEA     PGMBANNER(PC),A4    Draw banner
            BSR     PSTRING
            LEA     PGMNOTLD(PC),A4     Draw "program not found" screen
            BSR     PSTRING
            BSR     GCHAR
            BRA     MENU

****************************************************************
* Initialize DUART
*
INITDSIM    EQU     *
	        MOVE.B	#$00,D1
	        MOVE.B	#12,D0
	        TRAP		#15
	        RTS

INITDHAR    EQU     *
            LEA	  	    DUART,A0		A0 points to base DUART address

; Software reset:
      	    MOVE.B	    #$30,CRA(A0)	Reset TxA
		    MOVE.B	    #$20,CRA(A0)	Reset RxA
		    MOVE.B	    #$10,CRA(A0)	Reset MRA pointer

; Initialization:
            CMP.B       #0,TestBRG(A0)  Toggle BRG test mode
            MOVE.B  	#$80,ACR(A0)	selects baud rate set 2
            MOVE.B  	#BAUD,CSRA(A0)  	set 19.2k baud Rx/Tx
      	    MOVE.B  	#$13,MR1A(A0)   	8-bits, no parity, 1 stop bit

; This is the most important register to set in the 68681 DUART.
; 07 sets: Normal mode, CTS and RTS disabled, stop bit length = 1
; For testing load $#47 to enable auto-echo
      	    MOVE.B	#$07,MR2A(A0)	

      	    MOVE.B	#$05,CRA(A0)	enable Tx and Rx
      	    RTS
      	    
****************************************************************
* I/O Subroutines

* Input a single character from port A (polled mode) into D0

GCHARHAR    EQU         *
	        MOVE.L      D1,-(SP)
	        MOVE.L      A1,-(SP)
            LEA         DUART,A0
Input_poll  MOVE.B      SRA(A0),D1
            BTST        #RxRDY,D1
            BEQ         Input_poll
            MOVE.B      RBA(A0),D0
            MOVE.L      (SP)+,A0
            MOVE.L      (SP)+,D1
            *BSR         PCHAR       Echo Input
	        RTS

GCHARSIM    EQU         *
	        MOVE.L	D1, -(SP)	
	        MOVE.L	#05, D0
	        TRAP		#15		
	        MOVE.B	D1, D0
	        MOVE.L	(SP)+,D1
	        *BSR         PCHAR       Echo Input
	        RTS

* Transmit a single character in D0 from Port A (polled mode)

PCHARHAR    MOVEM.L       D0-D1,-(SP)
            MOVEM.L       A0,-(SP)
            LEA         DUART,A0
Output_poll MOVE.B      SRA(A0),D1
            BTST        #TxRDY,D1
            BEQ         Output_poll
            MOVE.B      D0,TBA(A0)
            MOVEM.L       (SP)+,A0
            MOVEM.L       (SP)+,D0-D1
            RTS
	
PCHARSIM    EQU         *
	        MOVEM.L	D0-D1, -(SP)
	        MOVE.B	D0, D1	
	        MOVE.L	#06, D0	
	        TRAP		#15	
	        MOVEM.L	(SP)+,D0-D1
	        RTS

* Display the string pointed at by A4

PSTRING     EQU         *
            MOVEM.L       D0,-(SP)
            MOVEM.L       A4,-(SP)
PS1         MOVE.B      (A4)+,D0
            BEQ.S       PS2
            BSR         PCHAR
            BRA         PS1
PS2         MOVEM.L       (SP)+,A4
            MOVEM.L       (SP)+,D0
            RTS

* Move cursor to start of newline

NEWLINE     EQU         *
            MOVEM.L     A4,-(A7)
            LEA         CRLF(PC),A4
            BSR         PSTRING
            MOVEM.L     (A7)+,A4
            RTS

* Print string with newline

HEADING     BSR         NEWLINE
            BSR         PSTRING
            BRA         NEWLINE

* Get line of input from user

GETLINE     EQU         *
            MOVEM.L     A4,-(A7)
            LEA         PROMPT(PC),A4
            BSR         PSTRING         Print prompt character
            MOVEM.L     (A7)+,A4
GETL1       BSR         GCHAR
            BRA         GETL1

* Get a single numeric character between 1 and 4 from user

GETNUM      EQU         *
            MOVEM.L     A4,-(A7)
            LEA         NUMPROMPT(PC),A4
            BSR         PSTRING         Print prompt character
            MOVEM.L     (A7)+,A4
GETNUM1     BSR         GCHAR
            CMP.B       #$31,D0
            BLT         GETNUM1
            CMP.B       #$34,D0
            BGT         GETNUM1
            BSR         NEWLINE
            RTS

* Get a navigational character (ESC, ENTER, arrow key) from the user

GETNAV      EQU         *
            BSR         GCHAR
            CMP.B       #ESC,D0
            BEQ         GETNAV1
            CMP.B       #CR,D0
            BEQ         GETNAV1
            BRA         GETNAV
GETNAV1     RTS

* Clear the screen

CLRSCHAR    EQU         *
            LEA         CLRSCNESC(PC),A4
            BSR         PSTRING
            RTS

CLRSCSIM    EQU         *
            MOVE.L	D0, -(SP)
	        MOVE.L	D1, -(SP)
	        MOVE.L	#11, D0
	        MOVE.W  #$FF00,D1
	        TRAP		#15		
	        MOVE.L	(SP)+,D1	
	        MOVE.L	(SP)+,D0
	        RTS

*-----------------------------------------------------------
        
DecimalToBinary EQU     *
        ; This subroutine accepts an ASCII digit in D0
        ; and stores its binary value in D1. If the digit
        ; is not between 0-9, D3 holds junk and flag C is set
        
        MOVE.B      D0,D1   ; copy input into output
        ADD.B       #$C6,D1 ; test upper boundary
        BCS         END1    ; error if carry
        SUB.B       #$F6,D1 ; test lower boundary
END1    RTS                 ; return from subroutine

*-----------------------------------------------------------

HexToBinary     EQU     *
        ; This subroutine does the same as above except it
        ; will also accept hex values A-F (a-f).
        
        MOVE.B      D0,D1   ; copy input into output
        ADD.B       #$C6,D1 ; test upper decimal boundary
        BCS         CAPALPH ; try capital alpha if carry
        SUB.B       #$F6,D1 ; test lower decimal boundary
END2    RTS                 ; return from subroutine
CAPALPH ADD.B       #$F3,D1 ; test upper capital alpha boundary
        BCS         LOWALPH ; try lowercase alpha if carry
        SUB.B       #$F0,D1 ; clamp down to 10-15
        BCS         END2
        CMP.B       #$0A,D1 ; test lower capital alpha boundary
        BRA         END2
LOWALPH ADD.B       #$E0,D1 ; test upper lowercase alpha boundary
        BCS         END2    ; too big - not a hex digit
        SUB.B       #$F0,D1 ; clamp down to 10-15
        BCS         END2
        CMP.B       #$0A,D1 ; test lower lowercase alpha boundary
        BRA         END2

*-----------------------------------------------------------

BinaryToAsciiHex    EQU     *
        ; This subroutine converts a 16-bit word to four
        ; ASCII hex characters. Accepts input in D2 and
        ; stores four ASCII characters as LongWord in D3.
        
        MOVEM.L       D4-D7,-(A7) ; store the contents of D4-D7 on the stack
        
        MOVE.L      #0,D3       ; clear D3
        MOVE.W      D2,D3       ; copy input to be able to modify
        
        ; Move lowest nibble into D4
        ROL.L       #4,D3       ; shift original word one nibble left
        MOVE.B      D3,D4       ; copy "X0", where 'X' is the lowest nibble
        ROR.B       #4,D4       ; shift destination back to "0X"
        MOVE.B      #$00,D3     ; clear the lowest nibble of the original word
        ROR.L       #4,D3       ; shift D3 right to the next nibble
        
        ; Convert D4 into ASCII
        CMP.B       #$9,D4      ; does this print as a decimal or alpha char?
        BLE         LESS4       ; if low, skip next step
        ADD         #$7,D4      ; add extra amount for alpha char
LESS4   ADD         #$30,D4     ; add amount for ASCII decimal char
        
        ; Move next nibble into D5
        MOVE.B      D3,D5       ; copy "X0", where 'X' is the lowest nibble
        ROR.B       #4,D5       ; shift destination back to "0X"
        MOVE.B      #$00,D3     ; clear another nibble of the original word
        ROR.L       #4,D3       ; shift D3 right to the next nibble
        
        ; Convert D5 into ASCII
        CMP.B       #$9,D5      ; does this print as a decimal or alpha char?
        BLE         LESS5       ; if low, skip next step
        ADD         #$7,D5      ; add extra amount for alpha char
LESS5   ADD         #$30,D5     ; add amount for ASCII decimal char
        
        ; Move next nibble into D6
        MOVE.B      D3,D6       ; copy "X0", where 'X' is the lowest nibble
        ROR.B       #4,D6       ; shift destination back to "0X"
        MOVE.B      #$00,D3     ; clear another nibble of the original word
        ROR.L       #4,D3       ; shift D3 right to the next nibble
        
        ; Convert D6 into ASCII
        CMP.B       #$9,D6      ; does this print as a decimal or alpha char?
        BLE         LESS6       ; if low, skip next step
        ADD         #$7,D6      ; add extra amount for alpha char
LESS6   ADD         #$30,D6     ; add amount for ASCII decimal char
        
        ; Move highest nibble into D7
        MOVE.B      D3,D7       ; copy "X0", where 'X' is the lowest nibble
        ROR.B       #4,D7       ; shift destination back to "0X"
        MOVE.B      #$00,D3     ; clear another nibble of the original word
        ROR.L       #4,D3       ; shift D3 right to the next nibble
        
        ; Convert D7 into ASCII
        CMP.B       #$9,D7      ; does this print as a decimal or alpha char?
        BLE         LESS7       ; if low, skip next step
        ADD         #$7,D7      ; add extra amount for alpha char
LESS7   ADD         #$30,D7     ; add amount for ASCII decimal char

        ; Combine all ASCII characters into a single LongWord
        MOVE.B      D7,D3       ; first char
        ROL.L       #8,D3       ; shift left one byte to make room
        MOVE.B      D6,D3       ; second char
        ROL.L       #8,D3
        MOVE.B      D5,D3
        ROL.L       #8,D3
        MOVE.B      D4,D3
        
        MOVEM.L       (A7)+,D4-D7 ; retrieve the previous contents of D4-D7
        RTS

*-----------------------------------------------------------

****************************************************************
* String printing routines
*

Print4AsciiHex      EQU         *
* Print 4 ASCII characters stored as a longword
* Inputs: D3 = chars
*         D4 = include space when $FF

            MOVEM.L     D0,-(SP)    Store in stack
            MOVE.L      D3,D0       Input to print
            ROL.L       #8,D0       Rotate first byte to the bottom
            BSR         PCHAR       Print
            ROL.L       #8,D0       Rotate second byte in
            BSR         PCHAR       Print
            CMP         #$FF,D4     Need space in between?
            BNE         skipSpace1  If not, skip the space
            MOVEM.L     D0,-(SP)    Store temporarily on stack
            MOVE.L      #' ',D0     Input a space temporarily
            BSR         PCHAR       Print a space
            MOVEM.L     (SP)+,D0    Restore working digits from stack
skipSpace1  ROL.L       #8,D0       Rotate third byte in
            BSR         PCHAR       Print
            ROL.L       #8,D0       Rotate last byte back in
            BSR         PCHAR       Print
            CMP         #$FF,D4     Need space afterwards?
            BNE         skipSpace2  If not, skip second space
            MOVE.L      #' ',D0     Insert second space
            BSR         PCHAR       Print second space
skipSpace2  MOVEM.L     (SP)+,D0    Restore from stack
            RTS

****************************************************************
* Strings and Constants in ROM
*
CRLF        DC.B    CR,LF,0
CLRSCNESC   DC.B    ESC,'[2J'
PROMPT      DC.B    '> ',0
NUMPROMPT   DC.B    '#> ',0
MENUTEXT    DC.B    'Enter the number of one of the following options:',CR,LF,'1. View or modify a register',CR,LF,'2. View or modify a memory location',CR,LF,'3. Upload an S-record',CR,LF,'4. Jump to a memory location',0,0
OPNOTIMP1   DC.B    '(Option 1 not yet implemented)',0,0
OPNOTIMP2   DC.B    '(Option 2 not yet implemented)',0,0
OPNOTIMP3   DC.B    '(Option 3 not yet implemented)',0,0
OPNOTIMP4   DC.B    '(Option 4 not yet implemented)',0,0
MENUBANNER  DC.B    CR,LF,'                                   MAIN MENU',CR,LF,CR,LF,0,0
REGBANNER   DC.B    CR,LF,'<[ESC]                             REGISTERS',CR,LF,CR,LF,0,0
MEMBANNER   DC.B    CR,LF,'<[ESC]                               MEMORY ',CR,LF,CR,LF,0,0
PGMBANNER   DC.B    CR,LF,'<[ESC]                          JUMP TO PROGRAM',CR,LF,CR,LF,0,0
MENUSCREEN  DC.B    CR,LF
            DC.B    CR,LF
            DC.B    CR,LF
            DC.B    CR,LF
            DC.B    CR,LF
            DC.B    CR,LF
            DC.B    '                  _           _           __  __  ___  _   _  ',CR,LF
            DC.B    '                 | |__   __ _| |__  _   _|  \/  |/ _ \| \ | | ',CR,LF
            DC.B    '                 | ''_ \ / _` | ''_ \| | | | |\/| | | | |  \| | ',CR,LF
            DC.B    '                 | |_) | (_| | |_) | |_| | |  | | |_| | |\  | ',CR,LF
            DC.B    '                 |_.__/ \__,_|_.__/ \__, |_|  |_|\___/|_| \_| ',CR,LF
            DC.B    '                                    |___/         68k monitor ',CR,LF
            DC.B    CR,LF
            DC.B    CR,LF
            DC.B    CR,LF
            DC.B    CR,LF
            DC.B    '       Registers       Memory       Load S-Record       Jump to Program ',CR,LF,0,0
OP1CARAT    DC.B    '           ^',CR,LF,CR,LF,CR,LF,CR,LF,0,0
OP2CARAT    DC.B    '                         ^',CR,LF,CR,LF,CR,LF,CR,LF,0,0
OP3CARAT    DC.B    '                                          ^',CR,LF,CR,LF,CR,LF,CR,LF,0,0
OP4CARAT    DC.B    '                                                               ^',CR,LF,CR,LF,CR,LF,CR,LF,0,0
REGSCREEN   DC.B    CR,LF
            DC.B    '              DATA                  ADDRESS                  OTHER',CR,LF
            DC.B    '         --------------          --------------          --------------',CR,LF
            DC.B    CR,LF
            DC.B    '         D0 = $01020304          A0 = $01020304        ( US = $01020304 )',CR,LF
            DC.B    '                                                                      ^',CR,LF
            DC.B    '         D1 = $01020304          A1 = $01020304          SS = $01020304',CR,LF
            DC.B    CR,LF
            DC.B    '         D2 = $01020304        > A2 = $01020304 <        PC = $01020304',CR,LF
            DC.B    CR,LF
            DC.B    '         D3 = $01020304          A3 = $01020304',CR,LF
            DC.B    CR,LF
            DC.B    '         D4 = $01020304          A4 = $01020304',CR,LF
            DC.B    CR,LF
            DC.B    '       ( D5 = $01020304 )        A5 = $01020304',CR,LF
            DC.B    '                 ^',CR,LF
            DC.B    '         D6 = $01020304          A6 = $01020304',CR,LF
            DC.B    CR,LF
            DC.B    '         D7 = $01020304          A7 = $01020304',CR,LF
            DC.B    CR,LF
            DC.B    CR,LF,0,0
MEMSCREEN   DC.B    '           800B0      FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF',CR,LF
            DC.B    '           800C0      FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF',CR,LF
            DC.B    '           800D0      FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF',CR,LF
            DC.B    '           800E0      FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF',CR,LF
            DC.B    '           800F0      FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF',CR,LF
            DC.B    '       -   80100      FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF',CR,LF
            DC.B    '           80110      FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF',CR,LF
            DC.B    '           80120      FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF',CR,LF
            DC.B    '         > 801_0 < >> FF FF _F FF FF FF FF FF FF FF FF FF FF FF FF FF <<',CR,LF
            DC.B    '           80140      FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF',CR,LF
            DC.B    '           80150      FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF',CR,LF
            DC.B    '           80160      FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF',CR,LF
            DC.B    '           80170      FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF',CR,LF
            DC.B    '       -   80180      FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF',CR,LF
            DC.B    '           80190      FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF',CR,LF
            DC.B    '           801A0      FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF',CR,LF
            DC.B    '           801B0      FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF',CR,LF
            DC.B    '            ...                             ...                      ',0,0
MEMHEADER   DC.B    '          ADDRESS                          BYTES',CR,LF
            DC.B    '             $        0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F',CR,LF
            DC.B    '          -------    -------------------------------------------------',CR,LF
            DC.B    '            ...                             ...',CR,LF,0,0
TICKSPACE   DC.B    '       -   ',0,0
NOTICKSPACE DC.B    '           ',0,0
LEFTCARAT   DC.B    '         > ',0,0
LCARATTICK  DC.B    '       - > ',0,0
COLUMNSPACE DC.B    '      ',0,0
RCARAT      DC.B    ' < ',0,0
NORCARAT    DC.B  '   ',0,0
LDUBCARAT   DC.B    '>> ',0,0
NOLDUBCARAT   DC.B  '   ',0,0
RDUBCARAT   DC.B    '<<',0,0
MEMFOOTER   DC.B    '            ...                             ...                     ',0,0
MEMMADDR    DC.B    '800B0',0,0
MEMMOCKROW  DC.B    'FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF',0,0
PGMNOTLD    DC.B    CR,LF,CR,LF,CR,LF,CR,LF,CR,LF,CR,LF,CR,LF,CR,LF,CR,LF,CR,LF,'                    (No program found at RAM location $81000.)',CR,LF,CR,LF,CR,LF,CR,LF,CR,LF,CR,LF,CR,LF,CR,LF,CR,LF,CR,LF,0,0
GCHAR       EQU     GCHARHAR
PCHAR       EQU     PCHARHAR
INIT_DUART  EQU     INITDHAR
CLRSCREEN   EQU     CLRSCHAR

            END     MAIN


















*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
