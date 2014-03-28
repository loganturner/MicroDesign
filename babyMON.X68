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
BAUD		EQU	  	$CC   baud rate value = 19,200 baud
*
CR          EQU     $0D     Carriage Return
LF          EQU     $0A     Line Feed

****************************************************************
* Main Program
*
STACK       EQU     $80800	; MUST BE A VALID RAM LOCATION


START   	ORG     $000000
        	DC.L    STACK
        	DC.L    MAIN

        	ORG     $000100        
MAIN    	JSR     INIT_DUART
            LEA     BANNER(PC),A4
            BSR     HEADING
            BRA     GETLINE

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
            LEA         DUART,A0
Input_poll  MOVE.B      SRA(A0),D1
            BTST        #RxRDY,D1
            BEQ         Input_poll
            MOVE.B      RBA(A0),D0
            MOVE.L      (SP)+, D1
            BSR         PCHAR       Echo Input
	        RTS

GCHARSIM    EQU         *
	        MOVE.L	D1, -(SP)	
	        MOVE.L	#05, D0
	        TRAP		#15		
	        MOVE.B	D1, D0
	        MOVE.L	(SP)+, D1
	        BSR         PCHAR       Echo Input
	        RTS

* Transmit a single character in D0 from Port A (polled mode)

PCHARHAR    MOVE.L      D1,-(SP)
            LEA         DUART,A0
Output_poll MOVE.B      SRA(A0),D1
            BTST        #TxRDY,D1
            BEQ         Output_poll
            MOVE.B      D0,TBA(A0)
            MOVE.L      (SP)+,D1
            RTS
	
PCHARSIM    EQU         *
	        MOVE.L	D0, -(SP)	; Task
	        MOVE.L	D1, -(SP)	;Char to display
	        MOVE.B	D0, D1	
	        MOVE.L	#06, D0	
	        TRAP		#15		
	        MOVE.L	(SP)+, D1	
	        MOVE.L	(SP)+, D0
	        RTS

* Display the string pointed at by A4

PSTRING     EQU         *
            MOVE.L      D0,-(A7)
PS1         MOVE.B      (A4)+,D0
            BEQ.S       PS2
            BSR         PCHAR
            BRA         PS1
PS2         MOVE.L      (A7)+,D0
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

****************************************************************
* Strings and Constants in ROM
*
BANNER      DC.B    '-- babyMON, a monitor for a 68k-based microcomputer --',0,0
CRLF        DC.B    CR,LF,0
PROMPT      DC.B    '> ',0
GCHAR       EQU     GCHARHAR
PCHAR       EQU     PCHARHAR
INIT_DUART  EQU     INITDHAR

        	END     MAIN










*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
