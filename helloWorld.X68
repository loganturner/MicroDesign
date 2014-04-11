*-----------------------------------------------------------
* Title      : Hello World
* Written by : Logan Turner
* Date       :
* Description:
*-----------------------------------------------------------
    ORG    $0000
START:

hi         MOVE.L   #PSTRING,A1
           LEA      helloWorld(PC),A4
           JSR      (A1)
           BRA      hi
    SIMHALT             ; halt simulator

* Variables and constants
PSTRING     EQU     $50
CR          EQU     $0D     Carriage Return
LF          EQU     $0A     Line Feed
helloWorld  DC.B    'Hello World!',CR,LF,0,0
    END    START

*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
