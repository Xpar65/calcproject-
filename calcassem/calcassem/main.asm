;
; calcassem.asm
;
; Created: 17/09/2022 8:31:21 AM
; Author : liamc
.def numlow = R11
.def numhigh = R12
.def flags = R13
.def er1 = R14
.def scan = R15
.def TEMP = R16
.equ SP = 0xDF
.equ DDRBa = 0x17
.equ PINBa = 0x16
.equ PORTBa = 0x18
.equ DDRCa = 0x14
.equ PINCa = 0x13
.equ PORTCa = 0x15
.equ RAMstart = 0x0060

; Replace with your application code
start:
	LDI  TEMP,  SP    		; First, initialise the Stack pointer before we use it
	OUT  0x3D,  TEMP
	CALL init

main:
	CALL inputtoRAM
	CALL RAMconversion
	CALL Calc
	CALL display		//will wait for A to be pressed for it to continue 
RJMP main

inputtoRAM:
	PUSH R17
	CLR ZH
	CLR R2
	LDI ZL, RAMstart
	LDI R18, 129
	inputloop:				//every scancode will be saved to RAM upuntil A is pressed. 
		RCALL ReadKP		//scancode return in R15
		CPI R17, 28						; 
		BRSH er				//will jump out of loop if there has beeen too many inputs 
		ST Z+, scan
		INC R17
		CP scan, R18		//if the scancode is A then get out of loop
		BREQ outloopinput
		RJMP inputloop
	outloopinput:
	ST Z+, R2
	POP R17
RET

RAMconversion:
	PUSH R17
	PUSH R18
	CLR ZH
	CLR R2
	LDI ZL, RAMstart
	LDI R18, 1
	LDI R17, 2
	firstval:
		LD scan, Z+
		RCALL scantohex		//returns to temp
		RCALL updateflag
		AND R18, flags
		BREQ er
	valsafter:
		LD scan, Z+
		//need to check for null terminator
		RCALL scantohex		//returns to temp
		RCALL updateflag
		AND er1, flags
		BREQ erout
		AND R18, flags		//operator check
		BREQ operator
		AND R17, flags 
		BREQ negativenum
		normalnumber:
		//do someghin
		JMP valsafter
		operator:
		//do someghin
		JMP valsafter
//		negativenum 
		//do something
		JMP valsafter 
		erout:
		//error
RET	

er:
//do somethign maybe
RET

/*
flags go 4MSB -> error flags, 4LSB otheer flags
0bit, operator flag | 1bit -ve flag | 2bit x
4bit error flag | | | 
*/
updateflag:
	PUSH R17
	PUSH R20
	PUSH R21
	PUSH R22
	LDI R20, 1
	LDI R21, 2
	LDI R22, 16	
	MOV R17, scan
	CPI R17, 10
	BRSH negcheck 
	RJMP normalnum
	negcheck:
		CPI R17, 14
		BRNE operatorfoundbutisitdoubledup
	subtractcheck:
		AND R20, flags		//checks operator flag (if set that means that the previous was an operator meaning this is a -ve sign)
		BRNE operatorfound
		AND R21, flags		//checks if two -ve in a row
		BREQ error1 
		LDI R21
		OR flags, R21		//sets -ve sign flag. 
		AND flags, R21		// only -ve flag 
		RJMP scanout
	operatorfoundbutisitdoubledup:
		AND R20, flags
		BREQ error1 
	operatorfound:
		OR flags, R20		//sets operator flag 
	error1:
		OR flags, R22		// 0001 0000 set 
		RJMP scanout
	normalnum:
		AND flags, R21		//keeps the -ve flag on if set 
	scanout:
	POP R22
	POP R21
	POP R20
	POP R17
RET

Calc:
//will read from RAM what is produced by RAMconv
RET

display:
//
RET

ReadKP:
	PUSH R17 //mask
	PUSH R18 //mask2
	PUSH R19 //n
	PUSH R20 //n2
	PUSH R21 //pincval
	LDI R20, 5				//counter for 2nd loop (rowloop)
	LDI R17, 0x01			//starting at 0000 0001 (to determine what column)
	LDI R18, 0x10			//starting at 0001 0000 (to determine what row)
	LDI R20, 0x0F			//0000 1111 4MSB are inputs 4lsb are ouputs
	OUT DDRCa, R20		 
	col:			//loop determines which col is low 
		LDI R19, 4 
		LDI R18, 0x10
		COM R17			//compliments mask (turns 0's to 1's)
		OUT PORTCa, R17	//mask starts at 0000 0001, PORTC to be 1111 1110
		COM R17			//returning mask 
		dec R20				
		BRNE rowloop
		RJMP ReadKP
		rowloop:
			IN R21, PINCa		//reads the value of pinc 
			RCALL debounce		//debouncer returns 
			AND R21, R18		//AND will return zero when pinc goes low. (checking 4MSB)
			BREQ here1			//if zero flag set then break out of loop.
			LSL R18		
			Dec R19
			BRNE rowloop		//jumps back to col loop if n hasn't reached zero yet.
			LSL R17 
			RJMP col			//will jump back to begginning if column is not found. 
	here1:
	MOV scan, R18			//creating own scan code using mask
	OR scan, R17			//scan code now complete ie(1000 1000) = row 4 col 4
	POP R21
	POP R20
	POP R19
	POP R18
	POP R17
	RET

scantohex:
	// saving the ASCII val to Z reg
	PUSH R17 //n
	PUSH R18 //temp
	PUSH R19 //0 
	LDI ZH, high(Tble << 1)			; Initialize Z-pointer, ZH which is R31 is going to load the first byte of the address (00)
	LDI ZL, low(Tble << 1)
	LDI R17, 0
	LDI R19, 0			
	searchloop:
		CPI R17, 127					
		BRSH outloopna					; will break out of loop if search exceeds the table
		LPM R18, Z						; loads value at Z pointer
		CP R18, scan					; compares if this equals the scan value. Please note that the scan code was created 
		BREQ outloopfound 					//breaks if value is found. 
		INC ZL							; 
		ADC ZH, R19						//R18 = 0. 
		INC R17							// counting how far from beginnning of table. 
		JMP searchloop					;
	outloopfound:
	MOV Temp, R17	 //saving hex ascii value to temp 
	POP R19
	POP R18
	POP R17
	RET
	outloopna:
	CLR Temp	//if an errouneous value is entered then temp will be zero hence not update portB
	POP R19
	POP R18
	POP R17
	RET

debounce:
	//RCAll Delay //commented out only for debug purposes 
	PUSH R25 //used for new pincval
	IN R25, PINCa
	CP R21, R25
	BREQ equal //if the value hasn't changed after the delay then its good
	LDI R21, 255 //if the value has changed then PINC register is set to 255
	equal:
	POP R25
    	RET						

Init:
	PUSH R17
	PUSH R18
	LDI R17, 0xFF 
	LDI R18, 0x10// will be used for inc
	MOV er1, R20
	LDI R18, 0x00
	CLR R19
	CLR R21
	CLR R22
	CLR R23
	CLR R24
	OUT DDRBa, R17 //port b set to output
	OUT PINBa, R18			//no lights
	OUT PORTBa, R18			//no lights on
	OUT DDRCa, R18			// portC set to input
	OUT PORTCa, R17			// pull ups enabled
	POP R18
	POP R17
 RET	


Delay:
	PUSH R16			; Save R16 and 17 as we're going to use them
	PUSH R17			; as loop counters
	PUSH R0			; we'll also use R0 as a zero value
	CLR R0
	CLR R16			; Init inner counter
	CLR R17			; and outer counter
L1: 
	DEC R16         ; Counts down from 0 to FF to 0
	CPSE R16, R0    ; equal to zero?
	RJMP L1			; If not, do it again
	CLR R16			; reinit inner counter
L2: 
	DEC R17
    CPSE R17, R0    ; Is it zero yet?
    RJMP L1			; back to inner counter

	POP R0          ; Done, clean up and return
	POP R17
	POP R16
    RET

Tble: //table of ascii. However, first 10 numbers refer to the key pressed. 
	.DB  40, 17, 33, 65, 18, 34, 66, 20, 36, 68, 18, 24, 129, 65, 33, 17
	//   0 ,  1 ,2,  3 ,  4 , 5 , 6,  7 , 8 , 9 , #,  * , A ,  B , C , D
	//		00010001
.exit  
