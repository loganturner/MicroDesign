*-----------------------------------------------------------
* Operating system : babyMON
* Written by       : Logan Turner
* Date             : March 2014
* Description      : monitor program for a 68k-based microcomputer
*-----------------------------------------------------------

START

* Simulation vs. Hardware toggle
SIM         DC.B     0       ; 0 = hardware, 1 = simulation

; *******************************************************************
ROM         EQU     $00000000
RAM         EQU     $00080000
DUART   	EQU	    $00100000     loaded in A0 when needed, regs are offsets
*
STACK       EQU     $800	; MUST BE A VALID RAM LOCATION
*
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
BAUD		EQU	  	$CC   baud rate value = 19,200 baud
*
DATA        EQU     $C00
MAXCHR      EQU     64
LNBUFF      DS.B    MAXCHR
BUFFEND     EQU     LNBUFF+MAXCHR-1    
*
BS          EQU     $08     ; backspace
CR          EQU     $0D     ; carriage return
LF          EQU     $0A     ; line feed
SPACE       EQU     $20     ; space
WAIT        EQU     'W'     ; wait character
ESC         EQU     $1B     ; escape
CTRL_A      EQU     $01     ; force return to monitor

***************************************************************
* Main Program
*

  	        ORG     $8000
            DC.L    STACK
            DC.L    RESET
            
RESET       EQU     *     

* Configure I/O if running in simulation
            IF.B	SIM <NE> #0 THEN
	        MOVE.B	#$00,D1
	        MOVE.B	#12,D0
	        TRAP		#15
	        ENDI
*
NOSIM       LEA     DATA,A6
     	    JSR     INIT_DUART
     	    MOVE.B  'P',D0
     	    JSR     PCHAR
            LEA     BANNER(PC),A4
            BSR.S   HEADING
            LEA     PROMPT(PC),A4
            BSR.S   PSTRING
LOOP        JSR     MENU
		    JMP     LOOP
        
MENU        JSR     GCHAR
            MOVE.B  D2,D0
            JSR     PCHAR
		    RTS

****************************************************************
* Initialize Duart and basic routines
*

INIT_DUART  LEA	  	DUART,A0		A0 points to base DUART address

; Software reset:
      	    MOVE.B	    #$30,CRA(A0)	Reset TxA
		    MOVE.B	    #$20,CRA(A0)	Reset RxA
		    MOVE.B	    #$10,CRA(A0)	Reset MRA pointer

; Initialization:
            MOVE.B  	#$80,ACR(A0)	selects baud rate set 2
            MOVE.B  	#BAUD,CSRA(A0)  	set 19.2k baud Rx/Tx
      	    MOVE.B  	#$13,MR1A(A0)   	8-bits, no parity, 1 stop bit

; This is the most important register to set in the 68681 DUART.
; 07 sets: Normal mode, CTS and RTS disabled, stop bit length = 1
; For testing load $#47 to enable auto-echo
      	    MOVE.B	#$07,MR2A(A0)	

      	    MOVE.B	#$05,CRA(A0)	enable Tx and Rx
      	    RTS
      	    
NEWLINE     EQU         *
            MOVE.L      A4,-(A7)
            LEA         CRLF(PC),A4
            BSR.S       PSTRING
            MOVEM.L     (A7)+,A4
            RTS

PSTRING     EQU         *
            MOVE.L      D0,-(A7)
PS1         MOVE.B      (A4)+,D0
            BEQ.S       PS2
            BSR         PCHAR
            BRA         PS1
PS2         MOVE.L      (A7)+,D0
            RTS

HEADING     BSR         NEWLINE
            BSR         PSTRING
            BRA         NEWLINE
            BRA         NEWLINE

****************************************************************
*           Input a single character from port A (polled mode) into D2
*      	    
GCHAR	    IF.B	SIM <EQ> #0 THEN
	
            MOVE.L      D1,-(SP)
            LEA         DUART,A0
Input_poll  MOVE.B      SRA(A0),D1
            BTST        #RxRDY,D1
            BEQ         Input_poll
            MOVE.B      RBA(A0),D2
            MOVE.L      (SP)+, D1

	        ELSE
	
	        MOVE.L	D1, -(SP)	
	        MOVE.L	#05, D0
	        TRAP		#15		
	        MOVE.B	D1, D0
	        MOVE.L	(SP)+, D1
	
	        ENDI
	        RTS

****************************************************************
*           Transmit a single character in D0 from Port A (polled mode)
*
PCHAR	    IF.B	SIM <EQ> #0 THEN

            MOVE.L      D1,-(SP)
            LEA         DUART,A0
Output_poll MOVE.B      SRA(A0),D1
            BTST        #TxRDY,D1
            BEQ         Output_poll
            MOVE.B      D0,TBA(A0)
            MOVE.L      (SP)+,D1
	
	        ELSE
	
	        MOVE.L	D0, -(SP)	; Task
	        MOVE.L	D1, -(SP)	;Char to display
	        MOVE.B	D0, D1	
	        MOVE.L	#06, D0	
	        TRAP		#15		
	        MOVE.L	(SP)+, D1	
	        MOVE.L	(SP)+, D0	
	
	        ENDI
	        RTS
            
****************************************************************
*   GETLINE inputs a string of characters into a line buffer
*           A3 points to next free entry in line buffer
*           A2 points to end of buffer
*           A1 points to start of buffer
*           D0 holds character to be stored
*
GETLINE     LEA         LNBUFF(A6),A1
            LEA         (A1),A3
            LEA         MAXCHR(A1),A2
GETLN2      BSR         GCHAR
            CMP.B       #CTRL_A,D0
            BEQ.S       GETLN5
            CMP.B       #BS,D0
            BNE.S       GETLN3
            CMP.L       A1,A3
            BEQ         GETLN2
            LEA         -1(A3),A3
            BRA         GETLN2
GETLN3      MOVE.B      D0,(A3)+
            CMP.B       #CR,D0
            BNE.S       GETLN4
            BRA         NEWLINE
GETLN4      CMP.L       A2,A3
            BNE         GETLN2
GETLN5      BSR         NEWLINE
            BRA         GETLINE
            
****************************************************************
*   Strings!
*
CRLF        DC.B        CR,LF,0
BANNER 	    DC.B        '-- babyMON firmware for 68k -- written by Logan Turner --',0,0
PROMPT      DC.B        '> ',0

        	END         RESET







*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
