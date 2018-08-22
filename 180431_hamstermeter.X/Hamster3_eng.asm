;------------------------------------------------
;
; Hamster speedometer 3
;
; Hardware on 16 MHz extern pll4, PIC18F26K22
;
; Hardware : port A	A0 = Backlight		O
;			A1 = Serviceled		O
;			A2 = Toggle		O
;			A3 = LCD E		O
;			A4 = LCD RW		O
;			A5 = LCD D/I		O
;			A6 = Xtal
;			A7 = Xtal
;
;            port B	B0 = Status upper	I
;			B1 = Status lower       I
;			B2 = PWM output		O
;			C3 = Rotary pulse       I
;			C4 = Rotary pulse       I
;			B5 = Rotary switch 	I
;			B6 =
;			B7 =
;
;            port C	C0 = LCD Data 0 	O
;			C1 = LCD Data 1 	O
;			C2 = LCD Data 2 	O
;			C3 = LCD Data 3 	O
;			C4 = LCD Data 4 	O
;			C5 = LCD Data 5 	O
;			C6 = LCD Data 6 	O
;			C7 = LCD Data 7 	O
;
;
; W.Tak april 2018
;
;------------------------------------------------

#INCLUDE  	<P18F26K22.INC>

	CONFIG FOSC=HSMP,PLLCFG=ON	;16 MHz extern, PLL to 64 MHz
       	CONFIG FCMEN=OFF,IESO=OFF	;No fail-safe monitor, no switch over
	CONFIG PWRTEN=ON,BOREN=OFF	;Power-up timer, no brown_out
	CONFIG MCLRE=EXTMCLR,PBADEN=OFF	;Reset enable, B poort digital
        CONFIG LVP=OFF			;No low voltage programming
        CONFIG WDTEN=OFF 		;Watchdog off

DELAY_H_1	EQU	0X14		;Delay in 0.5 msec. loop
DELAY_L_1	EQU	0X83            ;0B3B bij 16 MHz; 1483 at 64 MHz

DELAY_H_10	EQU	0XDC            ;Delay in 5 msec. loop
DELAY_L_10	EQU	0X78            ;3778 at 16 MHz

INT_VAL_H	EQU	0X9E		;Preset 50 msec.9E57
INT_VAL_L       EQU	0X57

EE_LOCS		EQU	0X88		;Nr. EEPROM locations in use

DIAM_HIGH	EQU	0X23		;Upperlimit diameter wheel
DIAM_LOW	EQU     0X0C            ;Underlimit diameter wheel

#DEFINE I_TOG		LATA,2		;Toggle in interrupt
#DEFINE BACKL		LATA,0		;Backlight
#DEFINE	SERV_LED	LATA,1		;Service LED

#DEFINE PU		PORTB,0		;Sensors
#DEFINE PL		PORTB,1

#DEFINE DS2		PORTB,3 	;Rotary encoder
#DEFINE DS1		PORTB,4
#DEFINE ROT_SW		PORTB,5		;Push button on rotary

#DEFINE LCD_RS		LATA,5		;Instruction or data LCD
#DEFINE LCD_RW		LATA,4          ;Read/write LCD
#DEFINE LCD_E		LATA,3          ;Enable LCD

#DEFINE I_OR_D		FLAGS,0 	;LCD flags
#DEFINE LCD_COPY	FLAGS,1
#DEFINE LCD_ERA		FLAGS,2
#DEFINE LCD_TO		FLAGS,3
#DEFINE DS_CU		FLAGS,4		;Rotary flags
#DEFINE DS_CD		FLAGS,5
#DEFINE DS_CHANGED	FLAGS,6

#DEFINE BL		FLAGS2,0	;Backlight off/on
#DEFINE BL_M		FLAGS2,1        ;Backlight during measurement off/on
#DEFINE DAY_OVERFLOW	FLAGS2,2  	;1 after 23:59 measuringtime
#DEFINE	INTT		FLAGS2,3	;Interrupt timer routine set

#define dump_data	latc,3
#define dump_clock	latc,4

;Start declaration of variables

	CBLOCK 0X0

        	FLAGS
		FLAGS2
		WREG_LOC
		STATUS_LOC
		FSR0H_LOC
		FRS0L_LOC

		GEN_CNT
		LOOP_CNT
		LOOP_CNT2
		TEMP
		TEMP1
		TEMP_H
		TEMP_L

                DELAY_LOC		;Nr. delays in delay routines
		DELAY_TYPE		;1 or 2 for 0.5, 5 of 25 msec.
		DELAY_H                 ;Timers in delay routines
		DELAY_L
		CNT_DELAY_H
		CNT_DELAY_L
		MAIN_DELAY
		DTS_TIMER		;Timer for 5 usec loop

                LCD_DATA		;Databyte in LCD_WRITE
		LCD_POS			;Own counter actual LCD position

		LCD_BUF:0X2A		;Sequence:
					;Byte 1 = Number of databytes
					;Byte 2 = Startposition (1-based)
					;Byte 3..42 = Data

		LCD_CNT_H		;Busy flag
		LCD_CNT_L

		SW_STAT			;Status rotary encoder
		TRANS			;Transitionbyte RE
		SW_CNT_U		;Delay RE
		SW_CNT_D
		SW_DELAY		;Delay

		DELAY_CNT               ;Delay pushbutton

		EE_IN  			;Byte from EEPROM
		EE_CNT			;Count EE bytes

		PWM_VAL			;Value (0 .. 15) for PWM

		DIAM			;Diameter in cm's
		POS_DIAM		;Position on LCD for diameter
		O1			;Half radius
		O2                      ;Other half radius
		O_NUMBER		;In use by INC_DIST
		WN_U			;Wheelnumber (radius x 36000) in 3 bytes
		WN_H
		WN_L

		DIST_UU 		;Total distance in cm
		DIST_U
		DIST_H
		DIST_L

		DIST_MIN_H              ;Distance in a minutes
		DIST_MIN_L

		TO_SEC_CNT		;Counts to 1 second (in 1/20 sec.)
		TO_MIN_CNT              ;Counts to 1 minute (per sec)
		TO_HR_CNT               ;Counts to 1 hour (per min)
		HR_CNT                  ;Counts the hours

		TMR0U			;Upper byte counter 0

		INT_DIV			;Delay counter interrupt

		NUMBER_U                ;Variables in divide routine
		NUMBER_H
		NUMBER_L
		DIVISOR_H
		DIVISOR_L
		REMAINDER_H
		REMAINDER_L

		D_0 			;Number to be calculated
		D_1                     ;D0 is lowest digit
		D_2
		D_3
		D_4
		D_5
		D_6
		D_7
		D_8
		D_9

		H_0 			;Result
		H_1                     ;H0 is lowest byte
		H_2
		H_3
		H_4
		H_5			;High byte

		H_0L			;Hexnumbers divided in nibbles
		H_0H
		H_1L
		H_1H
		H_2L
		H_2H
		H_3L
		H_3H
		
		MUL_9                   ;Add factor
                MUL_8
                MUL_7
                MUL_6
		MUL_5
		MUL_4
                MUL_3
                MUL_2
                MUL_1
                MUL_0

		SPEED_H			;Measures speed
		SPEED_L

		TS_H			;Topspeed
		TS_L

		MEAS_NR			;Number measuringresult

		SU_CNT			;Start-up counter

		dd_0
		dd_1
		dd_2
		dd_3
                dd_4
		dd_5
		dd_6
		dd_7
		dd_8
		dd_9
		dd_10
		dd_11
		dd_12
		dd_13
		dd_14
		dd_15

		dd_nr

	  ENDC

;Start program area

	ORG 0X00

		GOTO	MAIN		;Reset Vector
	

	ORG 0X18

		GOTO	INT_TIME        ;Timerinterrupt
		

	
;Teksten

	ORG 0X200
	
WELC_TXT:	DB	0X20,0X01
		DATA	"Hamster         "
		DATA	"Run-O-Meter     "

START_M_TXT:	DB	0X10,0X01
		DATA	"Start measuring "

ADJ_TXT:	DB	0X08,0X01
		DATA	"Controls"

MEAS_TXT:	DB      0X0C,0X01
		DATA	"Measurements"

SET_BL_TXT:	DB	0X10,0X01
		DATA	"Switch backlight"

BL_ON_TXT:	DB	0X0C,0X01
		DATA	"Backlight on"

BL_OFF_TXT:	DB	0X0D,0X01
		DATA	"Backlight off"

EE_EMPTY_TXT:	DB	0X20,0X01
		DATA	"EEPROM is empty "
		DATA	"Defaults used   "

DIAM_TXT:	DB	0X20,0X01
		DATA	"Wheel diameter: "
		DATA	"          cm    "

BL_RUNA_TXT:    DB	0X20,0X01
		DATA	"Measurement     "
		DATA	"Backlight on    "

BL_RUNU_TXT:    DB	0X20,0X01
		DATA	"Measurement     "
		DATA	"Backlight off   "

M_RUNS_TXT:	DB      0X10,0X01
		DATA	"Measurement on  "

M_STOP_TXT:	DB      0X10,0X01
		DATA	"Measurement off "

RES_SHOW_TXT:	DB      0X0C,0X01
		DB	"Show results"

RES_ERA_TXT:	DB      0X10,0X01
		DB	"Erase results   "

ERASED_TXT:	DB      0X06,0X01
		DB	"Erased"

STATUS_TXT:	DB	0X10,0X01
		DATA	"Sensor status   "

STU_ON_TXT:	DB	0X3,0X11
		DATA	"On "

STU_OFF_TXT:	DB	0X03,0X11
		DATA	"Off"

STL_ON_TXT:	DB	0X03,0X18
		DATA	"On "

STL_OFF_TXT:	DB	0X03,0X18
		DATA	"Off"

	ORG 0X400

;Tables

PWM_TABLE:	DB	0X00,0X06
                DB	0X01,0X0C
                DB	0X02,0X12
                DB	0X03,0X18

                DB	0X04,0X1E
                DB	0X05,0X24
                DB	0X06,0X2A
                DB	0X07,0X30

                DB	0X08,0X36
                DB	0X09,0X3C
                DB	0X0A,0X42
		DB	0X0B,0X48

                DB	0X0C,0X4E
                DB	0X0D,0X54
                DB	0X0E,0X5A
                DB	0X0F,0X60
                
RES_TBL:	DATA	"M00 00:00 00.00 "
                DATA	"Total  000000 m "

EMPTY_TBL:	DATA	"Empty           "
		DATA	"                "

	ORG 0X500

TIME_TBL:	DB	0X30,0X30,0X30,0X31,0X30,0X32,0X30,0X33,0X30,0X34
		DB	0X30,0X35,0X30,0X36,0X30,0X37,0X30,0X38,0X30,0X39
                DB	0X31,0X30,0X31,0X31,0X31,0X32,0X31,0X33,0X31,0X34
		DB	0X31,0X35,0X31,0X36,0X31,0X37,0X31,0X38,0X31,0X39
		DB	0X32,0X30,0X32,0X31,0X32,0X32,0X32,0X33,0X32,0X34
		DB	0X32,0X35,0X32,0X36,0X32,0X37,0X32,0X38,0X32,0X39
		DB	0X33,0X30,0X33,0X31,0X33,0X32,0X33,0X33,0X33,0X34
		DB	0X33,0X35,0X33,0X36,0X33,0X37,0X33,0X38,0X33,0X39
		DB	0X34,0X30,0X34,0X31,0X34,0X32,0X34,0X33,0X34,0X34
		DB	0X34,0X35,0X34,0X36,0X34,0X37,0X34,0X38,0X34,0X39
		DB	0X35,0X30,0X35,0X31,0X35,0X32,0X35,0X33,0X35,0X34
		DB	0X35,0X35,0X35,0X36,0X35,0X37,0X35,0X38,0X35,0X39
		DB	0X36,0X30,0X36,0X31,0X36,0X32,0X36,0X33,0X36,0X34
		DB	0X36,0X35,0X36,0X36,0X36,0X37,0X36,0X38,0X36,0X39
		DB	0X37,0X30,0X37,0X31,0X37,0X32,0X37,0X33,0X37,0X34
		DB	0X37,0X35,0X37,0X36,0X37,0X37,0X37,0X38,0X37,0X39
		DB	0X38,0X30,0X38,0X31,0X38,0X32,0X38,0X33,0X38,0X34
		DB	0X38,0X35,0X38,0X36,0X38,0X37,0X38,0X38,0X38,0X39
		DB	0X39,0X30,0X39,0X31,0X39,0X32,0X39,0X33,0X39,0X34
		DB	0X39,0X35,0X39,0X36,0X39,0X37,0X39,0X38,0X39,0X39

	ORG 0X600

EE_DEF_TBL:	DB	0X55,0X0F,0XC0,0X00,0X00,0X00,0X00,0X00
		DB	0X00,0X00,0X00,0X00,0X00,0X00,0X00,0X00


EE_DA_TBL:      DB	0X00,0X00,0X00,0X00,0X00,0X00,0X00,0X00
                DB	0X00,0X00,0X00,0X00,0X00,0X00,0X00,0X00
                DB	0X00,0X00,0X00,0X00,0X00,0X00,0X00,0X00
                DB	0X00,0X00,0X00,0X00,0X00,0X00,0X00,0X00
                DB	0X00,0X00,0X00,0X00,0X00,0X00,0X00,0X00
                DB	0X00,0X00,0X00,0X00,0X00,0X00,0X00,0X00
                DB	0X00,0X00,0X00,0X00,0X00,0X00,0X00,0X00
                DB	0X00,0X00,0X00,0X00,0X00,0X00,0X00,0X00
                DB	0X00,0X00,0X00,0X00,0X00,0X00,0X00,0X00
                DB	0X00,0X00,0X00,0X00,0X00,0X00,0X00,0X00
                DB	0X00,0X00,0X00,0X00,0X00,0X00,0X00,0X00
                DB	0X00,0X00,0X00,0X00,0X00,0X00,0X00,0X00
                DB	0X00,0X00,0X00,0X00,0X00,0X00,0X00,0X00
                DB	0X00,0X00,0X00,0X00,0X00,0X00,0X00,0X00
                DB	0X00,0X00,0X00,0X00,0X00,0X00,0X00,0X00

;ee_da_tbl:      db	0x00,0x0a,0x00,0x10,0x08,0x06,0x00,0x64;  00:10,010506,01,00
;                db	0x00,0x3b,0x00,0x20,0x10,0x16,0x00,0xc7;  00:59,021012,01,99
;                db	0x01,0x05,0x00,0x30,0x17,0x26,0x00,0xff;  01:05,031516,02,55
;                db	0x05,0x0a,0x00,0x40,0x21,0x36,0x01,0x2d;  05:10,042028,03,01
;                db	0x06,0x0f,0x00,0x50,0x30,0x46,0x01,0x90;  06:15,052552,04,00
;                db	0x09,0x16,0x00,0x60,0x44,0x56,0x01,0xf9;  09:22,063089,05,05
;                db	0x0a,0x1a,0x00,0x70,0x55,0x67,0x02,0xa4;  10:26,073618,06,76
;                db	0x0b,0x20,0x00,0x80,0x80,0x73,0x03,0x16;  11:32,084214,07,90
;                db	0x0c,0x25,0x00,0x90,0x99,0x88,0x03,0x78;  12:37,094764,08,88
;                db	0x0f,0x2a,0x00,0xa0,0xa0,0x98,0x03,0xd4;  15,42,105268,09,80
;                db	0x10,0x2c,0x00,0xb0,0xa9,0xa9,0x04,0x20;  16:44,115777,10,56
;                db	0x11,0x30,0x01,0xc0,0xbb,0xaa,0x04,0x55;  17:48,294081,11,09
;                db	0x13,0x35,0x01,0xff,0xff,0xff,0x04,0xbe;  19:53,335544,12,14
;                db	0x15,0x3a,0x02,0xe0,0x00,0xa0,0x05,0x35;  21:58,482346,13,33
;                db	0x17,0x3b,0x03,0x00,0x00,0x00,0x05,0xdb;  23:59,503316,14,99

	ORG	0X700
	
HEX_TABLE:	DB	0X00,0X30,0X30,0X00
		DB      0X01,0X30,0X31,0X00
                DB      0X02,0X30,0X32,0X00
                DB      0X03,0X30,0X33,0X00
                DB      0X04,0X30,0X34,0X00
                DB	0X05,0X30,0X35,0X00
		DB      0X06,0X30,0X36,0X00
                DB      0X07,0X30,0X37,0X00
                DB      0X08,0X30,0X38,0X00
                DB      0X09,0X30,0X39,0X00

                DB	0X10,0X31,0X30,0X00
		DB      0X11,0X31,0X31,0X00
                DB      0X12,0X31,0X32,0X00
                DB      0X13,0X31,0X33,0X00
                DB      0X14,0X31,0X34,0X00
                DB	0X15,0X31,0X35,0X00
		DB      0X16,0X31,0X36,0X00
                DB      0X17,0X31,0X37,0X00
                DB      0X18,0X31,0X38,0X00
                DB      0X19,0X31,0X39,0X00

                DB	0X20,0X32,0X30,0X00
		DB      0X21,0X32,0X31,0X00
                DB      0X22,0X32,0X32,0X00
                DB      0X23,0X32,0X33,0X00
                DB      0X24,0X32,0X34,0X00
                DB	0X25,0X32,0X35,0X00
		DB      0X26,0X32,0X36,0X00
                DB      0X27,0X32,0X37,0X00
                DB      0X28,0X32,0X38,0X00
                DB      0X29,0X32,0X39,0X00

                DB	0X30,0X33,0X30,0X00
		DB      0X31,0X33,0X31,0X00
                DB      0X32,0X33,0X32,0X00
                DB      0X33,0X33,0X33,0X00
                DB      0X34,0X33,0X34,0X00
                DB	0X35,0X33,0X35,0X00
		DB      0X36,0X33,0X36,0X00
                DB      0X37,0X33,0X37,0X00
                DB      0X38,0X33,0X38,0X00
                DB      0X39,0X33,0X39,0X00

                DB	0X40,0X34,0X30,0X00
		DB      0X41,0X34,0X31,0X00
                DB      0X42,0X34,0X32,0X00
                DB      0X43,0X34,0X33,0X00
                DB      0X44,0X34,0X34,0X00
                DB	0X45,0X34,0X35,0X00
		DB      0X46,0X34,0X36,0X00
                DB      0X47,0X34,0X37,0X00
                DB      0X48,0X34,0X38,0X00
                DB      0X49,0X34,0X39,0X00

                DB	0X50,0X35,0X30,0X00
		DB      0X51,0X35,0X31,0X00
                DB      0X52,0X35,0X32,0X00
                DB      0X53,0X35,0X33,0X00
                DB      0X54,0X35,0X34,0X00
                DB	0X55,0X35,0X35,0X00
		DB      0X56,0X35,0X36,0X00
                DB      0X57,0X35,0X37,0X00
                DB      0X58,0X35,0X38,0X00
                DB      0X59,0X35,0X39,0X00

                DB	0X60,0X36,0X30,0X00
		DB      0X61,0X36,0X31,0X00
                DB      0X62,0X36,0X32,0X00
                DB      0X63,0X36,0X33,0X00
                DB      0X64,0X36,0X34,0X00
                DB	0X65,0X36,0X35,0X00
		DB      0X66,0X36,0X36,0X00
                DB      0X67,0X36,0X37,0X00
                DB      0X68,0X36,0X38,0X00
                DB      0X69,0X36,0X39,0X00

                DB	0X70,0X37,0X30,0X00
		DB      0X71,0X37,0X31,0X00
                DB      0X72,0X37,0X32,0X00
                DB      0X73,0X37,0X33,0X00
                DB      0X74,0X37,0X34,0X00
                DB	0X75,0X37,0X35,0X00
		DB      0X76,0X37,0X36,0X00
                DB      0X77,0X37,0X37,0X00
                DB      0X78,0X37,0X38,0X00
                DB      0X79,0X37,0X39,0X00

                DB	0X80,0X38,0X30,0X00
		DB      0X81,0X38,0X31,0X00
                DB      0X82,0X38,0X32,0X00
                DB      0X83,0X38,0X33,0X00
                DB      0X84,0X38,0X34,0X00
                DB	0X85,0X38,0X35,0X00
		DB      0X86,0X38,0X36,0X00
                DB      0X87,0X38,0X37,0X00
                DB      0X88,0X38,0X38,0X00
                DB      0X89,0X38,0X39,0X00

                DB	0X90,0X39,0X30,0X00
		DB      0X91,0X39,0X31,0X00
                DB      0X92,0X39,0X32,0X00
                DB      0X93,0X39,0X33,0X00
                DB      0X94,0X39,0X34,0X00
                DB	0X95,0X39,0X35,0X00
		DB      0X96,0X39,0X36,0X00
                DB      0X97,0X39,0X37,0X00
                DB      0X98,0X39,0X38,0X00
                DB      0X99,0X39,0X39,0X00
                
        ORG 0X900
        
WHEEL_TABLE:	;	DIAM, O1, O2, WN_U, WN_H, WN_L

		DB	0X0C,0X13,0X13,0X14,0XDF,0XC0,0X00,0X00,0X00,0X00
		DB	0X0D,0X14,0X15,0X16,0X85,0XA0,0X00,0X00,0X00,0X00
		DB	0X0E,0X16,0X16,0X18,0X2B,0X80,0X00,0X00,0X00,0X00
		DB	0X0F,0X17,0X18,0X19,0XD1,0X60,0X00,0X00,0X00,0X00
		DB	0X10,0X19,0X19,0X1B,0X77,0X40,0X00,0X00,0X00,0X00
                DB	0X11,0X1A,0X1B,0X1D,0X1D,0X20,0X00,0X00,0X00,0X00
                DB	0X12,0X1C,0X1D,0X1F,0X4F,0XA0,0X00,0X00,0X00,0X00
                DB	0X13,0X1E,0X1E,0X20,0XF5,0X80,0X00,0X00,0X00,0X00
                DB	0X14,0X1F,0X20,0X22,0X9B,0X60,0X00,0X00,0X00,0X00
                DB	0X15,0X21,0X21,0X24,0X41,0X40,0X00,0X00,0X00,0X00
                DB	0X16,0X22,0X23,0X25,0XE7,0X20,0X00,0X00,0X00,0X00
                DB	0X17,0X24,0X24,0X27,0X8D,0X00,0X00,0X00,0X00,0X00
                DB	0X18,0X25,0X26,0X29,0X32,0XE0,0X00,0X00,0X00,0X00
                DB	0X19,0X27,0X27,0X2A,0XD8,0XC0,0X00,0X00,0X00,0X00
                DB	0X1A,0X29,0X29,0X2D,0X0B,0X40,0X00,0X00,0X00,0X00
                DB	0X1B,0X2A,0X2B,0X2E,0XB1,0X20,0X00,0X00,0X00,0X00
                DB	0X1C,0X2C,0X2C,0X30,0X57,0X00,0X00,0X00,0X00,0X00
                DB	0X1D,0X2D,0X2E,0X31,0XFC,0XE0,0X00,0X00,0X00,0X00
                DB	0X1E,0X2F,0X2F,0X33,0XA2,0XC0,0X00,0X00,0X00,0X00
                DB	0X1F,0X30,0X31,0X35,0X48,0XA0,0X00,0X00,0X00,0X00
                DB	0X20,0X32,0X32,0X36,0XEE,0X80,0X00,0X00,0X00,0X00
                DB	0X21,0X34,0X34,0X39,0X21,0X00,0X00,0X00,0X00,0X00
                DB	0X22,0X35,0X36,0X3A,0XC6,0XE0,0X00,0X00,0X00,0X00
                DB	0X23,0X37,0X37,0X3C,0X6C,0XC0,0X00,0X00,0X00,0X00
                
        ORG 0XA00
                
HTD_TABLE:	DB      0X00,0X00,0X00,0X00,0X00,0X00,0X00,0X00,0X00,0X01
                DB      0X00,0X00,0X00,0X00,0X00,0X00,0X00,0X00,0X01,0X06
                DB      0X00,0X00,0X00,0X00,0X00,0X00,0X00,0X02,0X05,0X06
                DB      0X00,0X00,0X00,0X00,0X00,0X00,0X04,0X00,0X09,0X06

                DB      0X00,0X00,0X00,0X00,0X00,0X06,0X05,0X05,0X03,0X06
                DB      0X00,0X00,0X00,0X01,0X00,0X04,0X08,0X05,0X07,0X06
                DB      0X00,0X00,0X01,0X06,0X07,0X07,0X07,0X02,0X01,0X06
                DB      0X00,0X02,0X06,0X08,0X04,0X03,0X05,0X04,0X05,0X06

;----------------------------------------------
;
;Interrupt routines
;
;----------------------------------------------

;------------------------------------
;INT_TIME = Low priority interrupt af
;------------------------------------

INT_TIME:	MOVFF	WREG,WREG_LOC   ;Push W
		MOVFF	STATUS,STATUS_LOC;Push status

		BCF	T1CON,TMR1ON    ;Stop timer
		MOVLW	INT_VAL_H       ;Preset values for time
		MOVWF	TMR1H           ;between 2 interrupts
		MOVLW	INT_VAL_L
		MOVWF 	TMR1L
		BSF	T1CON,TMR1ON    ;Release timer 

		INCF	INT_DIV   	;Divide 4
		BTFSS	INT_DIV,2
		GOTO	OUT_INT
		CLRF	INT_DIV

		BTG	I_TOG           ;Toggle inicator
		BSF	INTT		;Flag the interrupt

		INCF	TO_SEC_CNT	;Increase to second
		MOVLW	0X14            ;20 periods per second
		CPFSEQ	TO_SEC_CNT      ;Reached
		GOTO	OUT_INT         ;Not yet
		
		CLRF	TO_SEC_CNT	;1/20 sec.counter reset
		INCF	TO_MIN_CNT      ;Increase to minut
		MOVLW	0X3C      	;60 sec. in a minut
		CPFSEQ	TO_MIN_CNT
		GOTO	OUT_INT         ;Not yet

		CLRF	TO_MIN_CNT	;Secondcounter reset
		INCF	TO_HR_CNT	;Increase hour
		MOVLW	0X3C            ;60 minuts in an hour
		CPFSEQ	TO_HR_CNT
		GOTO	OUT_INT         ;Not yet

		CLRF	TO_HR_CNT	;Reset minutcounter
		INCF	HR_CNT          ;Add 1 hour
		CPFSEQ	0X18            ;24 is maximum
		GOTO	OUT_INT         ;Not yet
		BSF	DAY_OVERFLOW    ;Out of time
		CLRF	HR_CNT          ;Hours back to zero

OUT_INT:	MOVFF	WREG_LOC,WREG
		MOVFF	STATUS,STATUS_LOC

		BCF	PIR1,TMR1IF	;Clear interrupt

		RETFIE
		

;-------------------------------------------------------------------------
;
;Timer routines
;
;-------------------------------------------------------------------------


;--------------------------------------------------------------
;DELAY = General delay routine
;		 Entry : DELAY_TYPE is 1 of 2 for 0.5 or 5 msec
;			 DELAY_LOC is number of delays
;--------------------------------------------------------------

DELAY:	 	MOVFF	DELAY_LOC,MAIN_DELAY

		MOVLW	0X01 		;DELAY_TYPE 1?
		CPFSEQ	DELAY_TYPE
		GOTO	CH_F_2
		GOTO	DELAY_1         ;Yes,so to DELAY_1

CH_F_2:         MOVLW	0X02            ;Perhaps 2?
		CPFSEQ	DELAY_TYPE
		GOTO    END_DELAY	;No idea
		GOTO	DELAY_10        ;Yes its 2

DELAY_1:        MOVLW	DELAY_H_1     	;Presets from EQU values
		MOVFF	WREG,DELAY_H    ;for delay 0.5 msec
		MOVLW	DELAY_L_1
		MOVFF	WREG,DELAY_L
		GOTO	DO_DELAY

DELAY_10:       MOVLW	DELAY_H_10     	;Presets from de EQU values
		MOVFF	WREG,DELAY_H    ;for delay 5 msec
		MOVLW	DELAY_L_10
		MOVFF	WREG,DELAY_L

DO_DELAY:       MOVFF	DELAY_H,CNT_DELAY_H
		MOVFF	DELAY_L,CNT_DELAY_L

SH_LOOP:	DECFSZ	CNT_DELAY_L,1   ;Inner loop
		GOTO	SH_LOOP

		MOVFF   DELAY_L,CNT_DELAY_L
		DECFSZ	CNT_DELAY_H     ;Outer loop
		GOTO	SH_LOOP

		MOVFF	DELAY_H,CNT_DELAY_H
		DECFSZ	MAIN_DELAY   	;Numbers
		GOTO	SH_LOOP

END_DELAY:	RETURN

;--------------------------------
;DTS = Timer for app. 1 usec
;      Entry: W has number delays
;--------------------------------

DTS:    	MOVFF	WREG,DTS_TIMER

DTS_LOOP:       NOP
		NOP
		NOP
		NOP
		
		NOP
		NOP
		NOP
		NOP
		
		NOP
		NOP
		NOP
		NOP

		DECFSZ	DTS_TIMER
		GOTO	DTS_LOOP

		RETURN
		
;------------------
;DT_1 = 1 sec. wait
;------------------

DT_1:		MOVLW	0X02
		MOVFF	WREG,DELAY_TYPE
		MOVLW	0XC4
		MOVFF	WREG,DELAY_LOC

		CALL	DELAY

		RETURN

;------------------
;DT_3 = 3 sec. wait
;------------------

DT_3:		MOVLW	0X02
		MOVFF	WREG,DELAY_TYPE
		MOVLW	0XC4
		MOVFF	WREG,DELAY_LOC
		
		CALL	DELAY
		CALL	DELAY
		CALL	DELAY
		
		RETURN


;------------------------------------------------------------------------
;
;LCD control
;
;------------------------------------------------------------------------
		
;-----------------------------------------------
;LCD = Fill the LCD display from LCD_BUF
;      Entry: LCD_COPY 0 = no TBLPTR move, 1 yes
;             LCD_ERA 1 = Erase first
;-----------------------------------------------

LCD:		BTFSC	LCD_ERA         ;Erase?
		CALL	LCD_ERASE

		BTFSS	LCD_COPY	;TBLPTR set?
		GOTO	DO_WRITE        ;No

		TBLRD*                  ;Yes, read number bytes
		MOVFF	TABLAT,LOOP_CNT
		INCF	LOOP_CNT	;Coyp 2 control bytes
		INCF	LOOP_CNT

		LFSR	0,LCD_BUF       ;Destination location

FILL_LCD_BUF:	TBLRD*+                 ;Read table
		MOVFF	TABLAT,POSTINC0 ;Write in LCD_BUF
		DECFSZ	LOOP_CNT        ;As often as required
		GOTO	FILL_LCD_BUF

DO_WRITE:	LFSR	0,LCD_BUF	;Point start LCD_BUF
		MOVFF	POSTINC0,LOOP_CNT;Number bytes in counter

		MOVFF   POSTINC0,LCD_POS;Start position LCD(one based)
		DECF	LCD_POS		;Zero based for LCD address

		MOVLW	0X0F		;Compare LCD position with 15
		CPFSGT	LCD_POS         ;Required position is greater
		GOTO	POS_CORRECT     ;Position  is on first line

		MOVLW	0X1F   		;Now compare with 31
		CPFSGT	LCD_POS         ;Too big, stop it
		GOTO	POS_ST_LINE2    ;Okay, start on line 2
		GOTO	END_LCD

POS_ST_LINE2:	MOVLW	0X10   		;Line 2 starts 40h
		SUBWF	LCD_POS         ;Counter back to 0
		BSF	LCD_POS,6	;Mark start 2nd line

POS_CORRECT:	BSF	LCD_POS,7       ;Mark start 1st line

		BCF	I_OR_D		;Write instruction
		MOVFF	LCD_POS,WREG	;Startposition
		CALL	LCD_WRITE
		BSF	I_OR_D		;From now write data

CHAR_LOOP:      MOVFF	POSTINC0,WREG	;Read a databyte
		CALL	LCD_WRITE       ;Write it

		INCF	LCD_POS         ;Increment position
		MOVLW	0X90            ;20?
		CPFSEQ	LCD_POS         ;Yes, action for line 2
		GOTO	NO_LINE2        ;No

		BCF	I_OR_D		;Write instruction
		MOVLW	0XC0		;Startposition line 2
		CALL	LCD_WRITE
		BSF	I_OR_D		;From now write data

NO_LINE2:       DECFSZ	LOOP_CNT	;Number reached?
		GOTO	CHAR_LOOP       ;No

END_LCD:        RETURN

;--------------------------------------------------
;LCD_WRITE = write to LCD 
;            Entry: I_OR_D 0 = instruction, 1 = data
;                   Data in WREG
;--------------------------------------------------

LCD_WRITE:      MOVFF	WREG,LATC

                BCF	LCD_RW		;Write

		BSF	LCD_RS		;Is it data?
		BTFSS	I_OR_D		;Yes
		BCF	LCD_RS          ;No, it is instruction

                MOVLW	0X03
		CALL	DTS

                BSF	LCD_E		;Make E pulse
		MOVLW	0X03
		CALL	DTS
		BCF	LCD_E

		BSF	LCD_RW 		;Readmode
		BSF	TRISC,7         ;Port D7 is input
		BCF	LCD_RS          ;Instruction

                MOVLW	0X02
		CALL	DTS

		CLRF	LCD_CNT_H
		CLRF	LCD_CNT_L

WAIT_FOR_BUSY:	BSF	LCD_E		;Make E pulse
		MOVLW	0X03
		CALL	DTS
		;BCF	LCD_E

		CALL	LCD_TO_CHECK
		BTFSC	LCD_TO		;Time_out?
		GOTO	LCD_ERROR

		BTFSC	PORTC,7 	;Read bit D7 (busy flag)
		
		GOTO	WAIT_FOR_BUSY   ;If no 0
		BCF	LCD_E
		BCF	TRISC,7         ;D7 back to output
		
		MOVLW	0X02
		CALL	DTS
		GOTO	END_LCD_W

LCD_ERROR:      BCF	TRISC,7         ;D7 back to output

WFE:		GOTO    WFE

END_LCD_W:	MOVLW	0X20
		CALL	DTS

		RETURN
		
;-----------------------------------------
;LCD_TO_CHECK = Time out check LCD routine
;-----------------------------------------

LCD_TO_CHECK:	BCF	LCD_TO

		INCF	LCD_CNT_L       ;Increment low counter
		MOVLW	0X00            ;Overflow?
		CPFSEQ	LCD_CNT_L       ;Yes
		GOTO	END_L_T_C       ;No

		INCF	LCD_CNT_H       ;Increment high counter
		MOVLW	0X10            ;Limit on 10H
		CPFSEQ	LCD_CNT_H       ;Problem?
		GOTO	END_L_T_C       ;No

		BSF	LCD_TO		;Problem

END_L_T_C:	RETURN

;---------------------------------
;LCD_INIT = Initialise LCD display
;---------------------------------

LCD_INIT:	MOVLW	0X02 		;Wait 50 msec
		MOVFF	WREG,DELAY_TYPE
		MOVLW	0X14
		MOVFF	WREG,DELAY_LOC
		CALL	DELAY

		BCF	LCD_RS 		;1st action goes direct
		BCF	LCD_RW

                CLRF	TRISC		;All output

		MOVLW	0X05
		CALL	DTS

		;Stap 1 init

		MOVLW	0X38		;Interface 8 bit
		MOVWF	LATC

                MOVLW	0X2		;Data stabilise 2 usec
		CALL	DTS

                BSF	LCD_E		;Make E pulse
		MOVLW	0X03
		CALL	DTS
		BCF	LCD_E

		;Stap 2 init

		MOVLW	0X05		;Wait more then 4.1 usec
		CALL	DTS

		;Stap 3 init

                MOVLW   0X38 		;Once more function set
		MOVWF	LATC

		MOVLW	0X02		;Data stabilise
		CALL	DTS

                BSF	LCD_E		;Make E pulse
		MOVLW	0X03
		CALL	DTS
		BCF	LCD_E

		;Stap 4 init

		MOVLW	0X80		;Wacht more then 100 usec
		CALL	DTS

		;Stap 5 init

		MOVLW   0X38 		;Function set
		MOVWF	LATC

                MOVLW	0X02		;Data stabilise
		CALL	DTS

                BSF	LCD_E		;Make E pulse
		MOVLW	0X03
		CALL	DTS
		BCF	LCD_E
		
		MOVLW	0X0A
		CALL	DTS
		
		;Init klaar

		BCF	I_OR_D
		
		MOVLW	0X38
		CALL	LCD_WRITE

		MOVLW	0X0C            ;Display on/off control
		CALL	LCD_WRITE

		MOVLW	0X01		;Display clear
		CALL	LCD_WRITE

                MOVLW	0X06 		;Mode set, inc. after write
		CALL	LCD_WRITE

                MOVLW	0X32 		;Wait 50 usec
		CALL	DTS

		bsf	SERV_LED

		RETURN

;----------------------
;LCD_ERASE = Erase LCD
;----------------------

LCD_ERASE:	BCF	I_OR_D

		MOVLW	0X01		;Display clear
		CALL	LCD_WRITE

		MOVLW	0X02            ;Wait 5 msec.
		MOVFF	WREG,DELAY_TYPE
		MOVLW	0X02
		MOVFF	WREG,DELAY_LOC
		CALL	DELAY

		RETURN

;-----------------------------------------------------
;
;Rotary encoder routines
;
;-----------------------------------------------------


;---------------------------------------
;PROC_DSS = Rotary encoder in safe mode
;           Entry : SW_DELAY  (1 = none)
;---------------------------------------

PROC_DSS:	CLRF	TRANS

                BSF	SW_STAT,4	;Suppose all 1's
		BSF	SW_STAT,5

		BTFSS   DS1             ;Copy entry bits to
		BCF	SW_STAT,4       ;bit 4 and 5 of SW_STAT
		BTFSS	DS2
		BCF	SW_STAT,5

		MOVLW	0XC0 		;Do not mask old bits
		ANDWF	SW_STAT,0
		MOVFF	WREG,TEMP       ;Push SW_STAT
		MOVLW	0X30            ;Do not mask new bits
		ANDWF	SW_STAT,0
		RLNCF	WREG            ;Two to left
		RLNCF	WREG
		SUBWF	TEMP,0          ;Compare with old SW_STAT
		BNZ	CH_DET          ;Not equal so action required
		GOTO	END_PROC_DSS    ;Equal

CH_DET:         BTFSC	SW_STAT,4
		BSF	TRANS,0
                BTFSC	SW_STAT,6
		BSF	TRANS,1
		BTFSC	SW_STAT,5
		BSF	TRANS,2
		BTFSC	SW_STAT,7
		BSF	TRANS,3

ANA_STAT:	MOVLW	0X03     	;We must have status
		ANDWF   SW_STAT,0
		MOVFF	WREG,TEMP       ;Now in TEMP

		MOVLW	0X00            ;Jump to 1 of 3 statusroutines
		SUBWF	TEMP,0
		BZ	DO_STAT_0

		MOVLW	0X01
		SUBWF	TEMP,0
		BZ	DO_STAT_1

		MOVLW	0X02
		SUBWF	TEMP,0
		BZ	DO_STAT_2

		GOTO	END_PROC_DSS	;Should never happen

DO_STAT_0:      MOVLW	0X01            ;TRANS values 01H en 0DH means a step
		SUBWF	TRANS,0
		BNZ     DO_T13          ;Step not valid
		GOTO	DO_DIR          ;Valid;status = 1

DO_T13:         MOVLW	0X0D
		SUBWF	TRANS,0
		BNZ	END_S0          ;Not valid, stop it

DO_DIR:		BSF	SW_STAT,0       ;Status = 1
		BCF	SW_STAT,1

END_S0:		GOTO	END_PROC_DSS

DO_STAT_1:      MOVLW	0X02		;02H and 0EH means not valid
		SUBWF	TRANS,0
		BNZ	DO_T14          ;Test 0EH
		GOTO	DO_MST0         ;Was 02H so status back

DO_T14:		MOVLW	0X0E
		SUBWF	TRANS,0
		BNZ	DO_T7           ;Values are valid

DO_MST0:	BCF	SW_STAT,0       ;Status back to 0
		BCF	SW_STAT,1
		GOTO	END_PROC_DSS

DO_T7:		MOVLW	0X07		;07H is correct
		SUBWF	TRANS,0
		BNZ	DO_T11          ;But is another
		GOTO	DO_ST2

DO_T11:		MOVLW	0X0B       	;0BH is also valid
		SUBWF	TRANS,0
		BNZ	END_PROC_DSS    ;No result

DO_ST2:		BCF	SW_STAT,0    	;Status to 2
		BSF	SW_STAT,1
		GOTO	END_PROC_DSS

DO_STAT_2:      MOVLW	0X07		;07H makes status back to 1
		SUBWF	TRANS,0
		BNZ	DO_T11A		;No 07H
		GOTO	DO_MST1

DO_T11A:	MOVLW	0X0B 		;0BH is also wrong
		SUBWF	TRANS,0
		BNZ	DO_T2

DO_MST1:	BSF	SW_STAT,0	;Status back to 1
		BCF	SW_STAT,1
		GOTO	END_PROC_DSS

DO_T2:		MOVLW	0X02		;02H is correct
		SUBWF	TRANS,0
		BNZ	DO_T14A
		GOTO 	DO_CNT

DO_T14A:	MOVLW	0X0E        	;0EH also
		SUBWF	TRANS,0
		BNZ	END_PROC_DSS

DO_CNT:		BCF	SW_STAT,0	;Next time is status 0
		BCF	SW_STAT,1

		BTFSC	SW_STAT,7	;Test directionbit
		GOTO	DO_UP1          ;1 is increment

		INCF	SW_CNT_D   	;Increment down counter
		MOVFF	SW_DELAY,WREG   ;Compare with delay
		CPFSEQ	SW_CNT_D        ;Equal
		GOTO	END_PROC_DSS    ;Not equal
		CLRF	SW_CNT_D
		BCF	DS_CU      	;Flag down
		BSF	DS_CD
		BSF	DS_CHANGED
		GOTO	END_PROC_DSS

DO_UP1:         INCF	SW_CNT_U   	;Increment up counter
		MOVFF	SW_DELAY,WREG   ;Compare with delay
		CPFSEQ	SW_CNT_U        ;Equal
		GOTO	END_PROC_DSS    ;Not equal
		CLRF	SW_CNT_U
		BSF	DS_CU      	;Flag down
		BCF	DS_CD
		BSF	DS_CHANGED

END_PROC_DSS:	BSF	SW_STAT,6	;Update bit 6 and 7
		BSF	SW_STAT,7

		BTFSS	SW_STAT,4       ;Bit 6 comes from bit 4
		BCF	SW_STAT,6

		BTFSS	SW_STAT,5       ;Bit 7 comes from bit 5
		BCF	SW_STAT,7

		RETURN
		
;------------
;BOUNCE_DELAY
;------------

BOUNCE_DELAY:	MOVLW	0X02
		MOVFF	WREG,DELAY_TYPE
		MOVLW	0X32		;250 msec.
		MOVFF	WREG,DELAY_LOC

		CALL	DELAY

		RETURN
		
;-----------------------------------------
;
;EEPROM routines
;
;-----------------------------------------

;EEPROM content :
;
;byte 0 = 55H
;byte 1 = diameter wheel
;byte 2 = status backlight bit 8 = backlight on/off
;                          bit 7 = backlight on/off during measurement
;
;Storage every measurement, block 1
;
;byte 10h = time hours
;byte 11h = time minutes
;byte 12h = distance in cm uu byte
;byte 13h = distance in cm u byte
;byte 14h = distance in cm h byte
;byte 15h = distance in cm l byte
;byte 16h = topspeed H byte
;byte 17h = topspeed L byte
;
;byte 18h = start block 2
;byte 20h = start block 3
;byte 28h = start block 4
;byte 30h = start block 5
;byte 38h = start block 6
;byte 40h = start block 7
;byte 48h = start block 8
;byte 50h = start block 9
;byte 58h = start block 10
;byte 60h = start block 11
;byte 68h = start block 12
;byte 70h = start block 13
;byte 78h = start block 14
;byte 80h = start block 15
;

;----------------------------------
;EE_WRITE = Write EEPROM
;           Entry: EEADR and EEDATA
;----------------------------------

EE_WRITE:	CLRF	EEADRH		;Only low byte

		BCF	PIR2,EEIF 	;Clear EEPROM interrupt

		BCF	EECON1,EEPGD	;EEPROM enabled
		BCF	EECON1,CFGS	;Select EEPROM (no conf. reg.)
		BSF	EECON1,WREN	;Enable write

		MOVLW	0X55		;Fixed sequence
		MOVWF	EECON2
		MOVLW	0XAA
		MOVWF	EECON2

		BSF	EECON1,WR       ;Set write bit

W_F_E2:         BTFSS	PIR2,EEIF       ;Wait till EEPROM interrupts
		GOTO	W_F_E2

		BCF	PIR2,EEIF       ;Clear EEPROM interrupt

		BCF	EECON1,WREN
		CLRF	EEDATA

             	RETURN

;--------------------------------------
;EE_READ = Read one EEPROM location
;          Entry: Address in EEADR
;          Exit : Read data in EE_IN
;--------------------------------------

EE_READ:	BCF	EECON1,EEPGD	;EEPROM enabled
		BCF	EECON1,CFGS	;Select EEPROM (no conf. reg.)
		BSF	EECON1,RD       ;Set READ flag

		NOP
		NOP

W_READ:		BTFSC	EECON1,RD
		GOTO	W_READ

		MOVFF	EEDATA,EE_IN    ;Store in EE_IN

END_EE_RD:	RETURN

;---------------------------------------------------------------
;EE_INIT = Check if EEPROM, is empty. If so, write defaults
;---------------------------------------------------------------

EE_INIT:	MOVLW	0X00    	;Data?
		MOVFF	WREG,EEADR
		CALL	EE_READ

		MOVLW	0X55
		CPFSEQ	EE_IN
		GOTO	EE_FIRST        ;No
		GOTO	EE_GET          ;Yes

EE_FIRST:	BSF	BACKL

		MOVLW	HIGH EE_EMPTY_TXT
		MOVWF	TBLPTRH
                MOVLW	LOW EE_EMPTY_TXT
		MOVWF	TBLPTRL
		BSF	LCD_COPY        ;From a table
		BSF	LCD_ERA         ;Erase first
		CALL	LCD

		MOVLW	HIGH EE_DEF_TBL	;Table with defaults
		MOVFF	WREG,TBLPTRH
		MOVLW	LOW EE_DEF_TBL
		MOVFF	WREG,TBLPTRL

		CLRF	EEADR           ;Start address 0

		MOVLW	EE_LOCS         ;Number bytes to write
		MOVFF	WREG,GEN_CNT

WR_EE:		TBLRD*+                 ;Read data
		MOVFF	TABLAT,EEDATA   ;EEPROM content
		CALL	EE_WRITE        ;Writing
		INCF	EEADR

		DECFSZ	GEN_CNT         ;Count nr. write actions
		GOTO	WR_EE

		CALL	DT_3

EE_GET:         MOVLW	0X01
		MOVFF	WREG,EEADR
		CALL	EE_READ
		MOVFF	EE_IN,DIAM

		CALL	DIAM_TO_O	;Get wheel data
		
		MOVLW	0X02
		MOVFF	WREG,EEADR
		CALL	EE_READ
		MOVFF	EE_IN,TEMP
		BCF	BL
		BCF	BL_M
		BTFSC	TEMP,7
		BSF	BL
		BTFSC	TEMP,6
		BSF	BL_M

		BCF	BACKL
		BTFSC	BL
		BSF	BACKL

		RETURN
		
;------------------------------
;EE_ERASE = Erase 15 datablocks
;------------------------------

EE_ERASE:	MOVLW	HIGH EE_DA_TBL	;From table
		MOVFF	WREG,TBLPTRH
		MOVLW	LOW EE_DA_TBL
		MOVFF	WREG,TBLPTRL

		MOVLW	0X78 		;120 locations
		MOVFF	WREG,GEN_CNT

		MOVLW	0X10      	;Start first block
		MOVFF	WREG,EEADR

EE_E_LOOP:	TBLRD*+     		;Read table
		MOVFF	TABLAT,EEDATA

		CALL	EE_WRITE        ;Write

		INCF	EEADR

		DECFSZ	GEN_CNT
		GOTO	EE_E_LOOP
		
		RETURN
		
;------------------------------------------------------------------
;EE_SHIFT = Shift 15 datablocks 1 to the right, block 15 disappears
;           Then write block 1 with latest values
;------------------------------------------------------------------

EE_SHIFT:       MOVLW	0X80 		;Destination
		MOVFF	WREG,TEMP
		
		MOVLW	0X78  		;Source
		MOVFF	WREG,TEMP1
		
		CALL	DO_EE_SH 	;Block 15
		
                MOVLW	0X78 		;Destination
		MOVFF	WREG,TEMP

		MOVLW	0X70  		;Source
		MOVFF	WREG,TEMP1

		CALL	DO_EE_SH        ;Block 14
		
		MOVLW	0X70 		;Destination
		MOVFF	WREG,TEMP

		MOVLW	0X68  		;Source
		MOVFF	WREG,TEMP1

		CALL	DO_EE_SH        ;Block 13
		
		MOVLW	0X68 		;Destination
		MOVFF	WREG,TEMP

		MOVLW	0X60  		;Source
		MOVFF	WREG,TEMP1

		CALL	DO_EE_SH        ;Block 12

                MOVLW	0X60 		;Destination
		MOVFF	WREG,TEMP

		MOVLW	0X58  		;Source
		MOVFF	WREG,TEMP1

		CALL	DO_EE_SH        ;Block 11

		MOVLW	0X58 		;Destination
		MOVFF	WREG,TEMP

		MOVLW	0X50  		;Source
		MOVFF	WREG,TEMP1

		CALL	DO_EE_SH        ;Block 10
		
		MOVLW	0X50 		;Destination
		MOVFF	WREG,TEMP

		MOVLW	0X48  		;Source
		MOVFF	WREG,TEMP1

		CALL	DO_EE_SH        ;Block 9
		
		MOVLW	0X48 		;Destination
		MOVFF	WREG,TEMP

		MOVLW	0X40  		;Source
		MOVFF	WREG,TEMP1

		CALL	DO_EE_SH        ;Block 8
		
		MOVLW	0X40 		;Destination
		MOVFF	WREG,TEMP

		MOVLW	0X38  		;Source
		MOVFF	WREG,TEMP1

		CALL	DO_EE_SH        ;Block 7
		
		MOVLW	0X38 		;Destination
		MOVFF	WREG,TEMP

		MOVLW	0X30  		;Source
		MOVFF	WREG,TEMP1

		CALL	DO_EE_SH        ;Block 6
		
		MOVLW	0X30 		;Destination
		MOVFF	WREG,TEMP

		MOVLW	0X28  		;Source
		MOVFF	WREG,TEMP1

		CALL	DO_EE_SH        ;Block 5
		
		MOVLW	0X28 		;Destination
		MOVFF	WREG,TEMP

		MOVLW	0X20  		;Source
		MOVFF	WREG,TEMP1

		CALL	DO_EE_SH        ;Block 4
		
		MOVLW	0X20 		;Destination
		MOVFF	WREG,TEMP

		MOVLW	0X18  		;Source
		MOVFF	WREG,TEMP1

		CALL	DO_EE_SH        ;Block 3

		MOVLW	0X18 		;Destination
		MOVFF	WREG,TEMP

		MOVLW	0X10  		;Source
		MOVFF	WREG,TEMP1

		CALL	DO_EE_SH        ;Block 2
		
		MOVLW	0X10  		;Now write new block with latest data
		MOVFF	WREG,EEADR
		MOVFF	HR_CNT,EEDATA
		CALL	EE_WRITE
		
                MOVLW	0X11
		MOVFF	WREG,EEADR
		MOVFF	TO_HR_CNT,EEDATA
		CALL	EE_WRITE
		
                MOVLW	0X12
		MOVFF	WREG,EEADR
		MOVFF	DIST_UU,EEDATA
		CALL	EE_WRITE
		
		MOVLW	0X13
		MOVFF	WREG,EEADR
		MOVFF	DIST_U,EEDATA
		CALL	EE_WRITE

		MOVLW	0X14
		MOVFF	WREG,EEADR
		MOVFF	DIST_H,EEDATA
		CALL	EE_WRITE

		MOVLW	0X15
		MOVFF	WREG,EEADR
		MOVFF	DIST_L,EEDATA
		CALL	EE_WRITE
		
                MOVLW	0X16
		MOVFF	WREG,EEADR
		MOVFF	TS_H,EEDATA
		CALL	EE_WRITE

		MOVLW	0X17
		MOVFF	WREG,EEADR
		MOVFF	TS_L,EEDATA
		CALL	EE_WRITE

		RETURN
		
;DO_EE_SH = routine EE_SHIFT
;-------------------------------

DO_EE_SH:	MOVLW	0X08         	;8 bytes
		MOVFF	WREG,LOOP_CNT
		
EESH_LOOP:	MOVFF	TEMP1,EEADR	;Read source
		CALL	EE_READ         ;Now in EE_IN
		MOVFF	TEMP,EEADR      ;Destination
		MOVFF	EE_IN,EEDATA    ;Get byte
		CALL	EE_WRITE        ;Write

		INCF	TEMP1		;Increase source
		INCF	TEMP            ;Increase destination
		DECFSZ	LOOP_CNT        ;8 times
		GOTO	EESH_LOOP

		RETURN
		
;---------------------------------------------
;
;Control routines
;
;---------------------------------------------

W_START:	BTFSC	ROT_SW
		GOTO	W_START

		CALL	BOUNCE_DELAY
		CALL	BOUNCE_DELAY

W_START2:	BTFSS	ROT_SW
		GOTO	W_START2
		
		CALL	BOUNCE_DELAY

		RETURN
		
;------------------------
;MAIN_LOOP = Control loop
;------------------------

;SIT1 = Start a measurement
;SIT2 = Adjustments
;SIT3 = Measurements
;SIT4 = Backlight on/off

MAIN_LOOP:	MOVLW	0X01
		MOVFF	WREG,SW_DELAY
		
		CALL	BOUNCE_DELAY
		CALL	BOUNCE_DELAY

;
;Situation 1
;

SIT1:		CALL	BOUNCE_DELAY

		MOVLW	HIGH START_M_TXT;Starttext
		MOVWF	TBLPTRH
                MOVLW	LOW START_M_TXT
		MOVWF	TBLPTRL
		BSF	LCD_COPY        ;From table
		BSF	LCD_ERA         ;Erase first
		CALL	LCD

WFR1:           CALL	PROC_DSS	;Read RE

		BTFSS	ROT_SW          ;Pushed?
		GOTO	PRESSED1        ;Yes

		BTFSS   DS_CHANGED      ;Turned?
		GOTO	WFR1            ;No

		BCF	DS_CHANGED
		BTFSS	DS_CU
		GOTO	SIT4
		GOTO	SIT2
		
PRESSED1:       CALL	BOUNCE_DELAY

WFSP1:		BTFSS	ROT_SW
		GOTO	WFSP1
		
		CALL	BOUNCE_DELAY
		
		GOTO	MEAS_CYCLE

;
;Situation 2
;

SIT2:		CALL	BOUNCE_DELAY

		MOVLW	HIGH ADJ_TXT	;Adjust text
		MOVWF	TBLPTRH
                MOVLW	LOW ADJ_TXT
		MOVWF	TBLPTRL
		BSF	LCD_COPY        ;From table
		BSF	LCD_ERA         ;Erase first
		CALL	LCD

WFR2:           CALL	PROC_DSS	;Read RE

		BTFSS	ROT_SW          ;Pushed?
		GOTO	PRESSED2        ;Yes

		BTFSS   DS_CHANGED      ;Turned?
		GOTO	WFR2            ;No

		BCF	DS_CHANGED
		BTFSS	DS_CU
		GOTO	SIT1
		GOTO	SIT3
		
PRESSED2:       CALL	BOUNCE_DELAY

WFSP2:		BTFSS	ROT_SW
		GOTO	WFSP2
		
		CALL	BOUNCE_DELAY

		MOVLW	HIGH DIAM_TXT	;Diameter text
		MOVWF	TBLPTRH
                MOVLW	LOW DIAM_TXT
		MOVWF	TBLPTRL
		BSF	LCD_COPY        ;From table
		BSF	LCD_ERA         ;Erase first
		CALL	LCD

		MOVLW	0X18
		MOVFF	WREG,POS_DIAM
		CALL	DISP_DIAM

WFR21:          CALL	PROC_DSS	;Read RE

		BTFSS	ROT_SW          ;Pushed?
		GOTO	PRESSED21       ;Yes

		BTFSS   DS_CHANGED      ;Turned?
		GOTO	WFR21           ;No

		BCF	DS_CHANGED
		BTFSS	DS_CU
		GOTO	DIAM_DOWN
		GOTO	DIAM_UP

DIAM_DOWN:      MOVLW	DIAM_LOW 	;Test under limit
		CPFSEQ	DIAM
		GOTO    DIAM_MINUS      ;Not too small
		GOTO    WFR21           ;Too small

DIAM_MINUS:	DECF	DIAM 		;Decrease
		GOTO	SHOW_DIAM

DIAM_UP:        MOVLW	DIAM_HIGH	;Test upper limit
		CPFSEQ	DIAM
		GOTO    DIAM_PLUS       ;Too big
		GOTO    WFR21           ;Not too big

DIAM_PLUS:	INCF	DIAM 		;Increase

SHOW_DIAM:	MOVLW	0X18
		MOVFF	WREG,POS_DIAM
		CALL	DISP_DIAM
		GOTO	WFR21

PRESSED21:      CALL	BOUNCE_DELAY

WFSP21:		BTFSS	ROT_SW
		GOTO	WFSP21
		
		CALL	BOUNCE_DELAY

		MOVLW	0X01
		MOVFF	WREG,EEADR
		MOVFF	DIAM,EEDATA
		CALL	EE_WRITE
		
		CALL	DIAM_TO_O
		
BL_M_CH:	BTFSS	BL_M
		GOTO	BL_M_ON

BL_M_OFF:       MOVLW	HIGH BL_RUNA_TXT;Backlight on text
		MOVWF	TBLPTRH
                MOVLW	LOW BL_RUNA_TXT
		MOVWF	TBLPTRL
		BSF	LCD_COPY        ;From table
		BSF	LCD_ERA         ;Erase first
		CALL	LCD
		GOTO    WFR22

BL_M_ON:        MOVLW	HIGH BL_RUNU_TXT;Backlight off text
		MOVWF	TBLPTRH
                MOVLW	LOW BL_RUNU_TXT
		MOVWF	TBLPTRL
		BSF	LCD_COPY        ;From table
		BSF	LCD_ERA         ;Erase first
		CALL	LCD

WFR22:          CALL	PROC_DSS	;Read RE

		BTFSS	ROT_SW          ;Pushed?
		GOTO	PRESSED22       ;Yes

		BTFSS   DS_CHANGED      ;Turned?
		GOTO	WFR22           ;No

		BCF	DS_CHANGED
		BTFSS	DS_CU
		GOTO	BLM_ON
		GOTO	BLM_OFF

BLM_ON:		BSF	BL_M       	;Switch on
		GOTO	BL_M_CH

BLM_OFF:	BCF	BL_M            ;Switch off
		GOTO	BL_M_CH

PRESSED22:      CALL	BOUNCE_DELAY   	;Value selected

		MOVLW	0X02
		MOVFF	WREG,EEADR
		CALL	EE_READ         ;EEPROM byte 2 is BL
		MOVFF	EE_IN,TEMP

		BCF	TEMP,6          ;Bit 6 is during measurement
		BTFSC	BL_M
		BSF	TEMP,6

		MOVLW	0X02
		MOVFF	WREG,EEADR
		MOVFF	TEMP,EEDATA
		CALL	EE_WRITE

                MOVLW	HIGH STATUS_TXT ;Status sensors text
		MOVWF	TBLPTRH
                MOVLW	LOW STATUS_TXT
		MOVWF	TBLPTRL
		BSF	LCD_COPY        ;From table
		BSF	LCD_ERA         ;Erase first
		CALL	LCD

WFR23:          BTFSC	PU
		GOTO    PU_OFF
		GOTO	PU_ON

PU_OFF:		MOVLW	HIGH STU_OFF_TXT;Upper sensor off text
		MOVWF	TBLPTRH
                MOVLW	LOW STU_OFF_TXT
		MOVWF	TBLPTRL
		BSF	LCD_COPY        ;From table
		BCF	LCD_ERA         ;Do not erase
		CALL	LCD
		GOTO	CH_PL

PU_ON:          MOVLW	HIGH STU_ON_TXT;Upper sensor on text
		MOVWF	TBLPTRH
                MOVLW	LOW STU_ON_TXT
		MOVWF	TBLPTRL
		BSF	LCD_COPY        ;From table
		BCF	LCD_ERA         ;Do not erase
		CALL	LCD

CH_PL:          BTFSC	PL
		GOTO    PL_OFF
		GOTO	PL_ON

PL_OFF:		MOVLW	HIGH STL_OFF_TXT;Lower sensor off text
		MOVWF	TBLPTRH
                MOVLW	LOW STL_OFF_TXT
		MOVWF	TBLPTRL
		BSF	LCD_COPY        ;From table
		BCF	LCD_ERA         ;Do not erase
		CALL	LCD
		GOTO	CONT_S23

PL_ON:          MOVLW	HIGH STL_ON_TXT;Lower sensor on text
		MOVWF	TBLPTRH
                MOVLW	LOW STL_ON_TXT
		MOVWF	TBLPTRL
		BSF	LCD_COPY        ;From table
		BCF	LCD_ERA         ;Do not erase
		CALL	LCD

CONT_S23:       CALL	PROC_DSS	;Read RE

		BTFSS	ROT_SW          ;Pushed?
		GOTO	PRESSED23       ;Yes
		GOTO	WFR23

PRESSED23:	GOTO	SIT2


;DISP_DIAM = extra routine for situation 21
;            Entry: POS_DIAM (position on LCD)
;---------------------------------------------

DISP_DIAM:	MOVLW	HIGH HEX_TABLE	;Convert decimal
		MOVFF	WREG,TBLPTRH
		MOVLW	LOW HEX_TABLE
		MOVFF	WREG,TBLPTRL

		MOVLW	0X04		;Tabel steps 4
		MULWF	DIAM

		BCF	STATUS,C        ;Adjust TBLPTR
		MOVFF	PRODL,WREG
		ADDWF	TBLPTRL
		MOVFF	PRODH,WREG
		ADDWFC	TBLPTRH

		LFSR	0,LCD_BUF	;Write 2 bytes
		MOVLW	0X02
		MOVFF	WREG,POSTINC0
		MOVFF	POS_DIAM,WREG   ;From position POS_DIAM
		MOVFF	WREG,POSTINC0

		TBLRD*+
		TBLRD*+
		MOVFF	TABLAT,POSTINC0
		TBLRD*+
		MOVFF	TABLAT,POSTINC0

                BCF	LCD_COPY        ;From table
		BCF	LCD_ERA         ;Erase first
		CALL	LCD

		RETURN

;
;Situation 3
;

SIT3:		CALL	BOUNCE_DELAY

		MOVLW	HIGH MEAS_TXT	;Measurement text
		MOVWF	TBLPTRH
                MOVLW	LOW MEAS_TXT
		MOVWF	TBLPTRL
		BSF	LCD_COPY        ;From table
		BSF	LCD_ERA         ;Erase first
		CALL	LCD

WFR3:           CALL	PROC_DSS	;Read RE

		BTFSS	ROT_SW          ;Pushed?
		GOTO	PRESSED3        ;Yes

		BTFSS   DS_CHANGED      ;Turned?
		GOTO	WFR3            ;No

		BCF	DS_CHANGED
		BTFSS	DS_CU
		GOTO	SIT2
		GOTO	SIT4

PRESSED3:       CALL	BOUNCE_DELAY

SIT31:          MOVLW	HIGH RES_SHOW_TXT;Show results text
		MOVWF	TBLPTRH
                MOVLW	LOW RES_SHOW_TXT
		MOVWF	TBLPTRL
		BSF	LCD_COPY        ;From table
		BSF	LCD_ERA         ;Erase first
		CALL	LCD

WFR31:          CALL	PROC_DSS	;Read RE

		BTFSS	ROT_SW          ;Pushed?
		GOTO	PRESSED31       ;Yes

		BTFSS   DS_CHANGED      ;Turned?
		GOTO	WFR31           ;No

		BCF	DS_CHANGED
		BTFSS	DS_CU
		GOTO	SIT32
		GOTO	SIT32

PRESSED31:      CALL	BOUNCE_DELAY
		MOVLW	0X01         	;Prepare first result
		MOVFF	WREG,MEAS_NR

SIT311:         CALL	MEAS_RESULT

WFR311:         CALL	PROC_DSS	;Read RE

		BTFSS	ROT_SW          ;Pushed?
		GOTO	SIT3	        ;Yes

		BTFSS   DS_CHANGED      ;Turned?
		GOTO	WFR311          ;No

		BCF	DS_CHANGED
		BTFSS	DS_CU
		GOTO	SIT311D
		GOTO	SIT311U

SIT311U:	INCF	MEAS_NR 	;Increase result
		MOVLW	0X10            ;But not > 15
		CPFSEQ	MEAS_NR
		GOTO	SIT311
		MOVLW	0X01
		MOVFF	WREG,MEAS_NR
		GOTO	SIT311

SIT311D:        DECF	MEAS_NR		;Decrease result
		MOVLW	0X00            ;But not < 0
		CPFSEQ	MEAS_NR
		GOTO	SIT311
		MOVLW	0X0F
		MOVFF	WREG,MEAS_NR
		GOTO	SIT311

SIT32:          MOVLW	HIGH RES_ERA_TXT;Erase results text
		MOVWF	TBLPTRH
                MOVLW	LOW RES_ERA_TXT
		MOVWF	TBLPTRL
		BSF	LCD_COPY        ;From table
		BSF	LCD_ERA         ;Erase first
		CALL	LCD

WFR32:          CALL	PROC_DSS	;Read RE

		BTFSS	ROT_SW          ;Pushed?
		GOTO	PRESSED32       ;Yes

		BTFSS   DS_CHANGED      ;Turned?
		GOTO	WFR32           ;No

		BCF	DS_CHANGED
		BTFSS	DS_CU
		GOTO	SIT31
		GOTO	SIT31

PRESSED32:      CALL	EE_ERASE

                MOVLW	HIGH ERASED_TXT;Erase result text
		MOVWF	TBLPTRH
                MOVLW	LOW ERASED_TXT
		MOVWF	TBLPTRL
		BSF	LCD_COPY        ;From table
		BSF	LCD_ERA         ;Erase first
		CALL	LCD

		CALL	DT_3

		GOTO	SIT3

;
;Situation 4
;

SIT4:		CALL	BOUNCE_DELAY

                MOVLW	HIGH SET_BL_TXT	;Switch backlight text
		MOVWF	TBLPTRH
                MOVLW	LOW SET_BL_TXT
		MOVWF	TBLPTRL
		BSF	LCD_COPY        ;From table
		BSF	LCD_ERA         ;Erase first
		CALL	LCD
		GOTO	WFR4

WFR4:		CALL	PROC_DSS	;Read RE

		BTFSS	ROT_SW          ;Pushed?
		GOTO	PRESSED4        ;Yes

		BTFSS   DS_CHANGED      ;Turned?
		GOTO	WFR4            ;No

		BCF	DS_CHANGED
		BTFSS	DS_CU
		GOTO	SIT3
		GOTO	SIT1
		
PRESSED4:	CALL	BOUNCE_DELAY

		BTFSS	BACKL
		GOTO	T_BL_OFF

T_BL_ON:        MOVLW	HIGH BL_ON_TXT	;Backlight on text
		MOVWF	TBLPTRH
                MOVLW	LOW BL_ON_TXT
		MOVWF	TBLPTRL
		BSF	LCD_COPY        ;From table
		BSF	LCD_ERA         ;Erase first
		CALL	LCD
		GOTO	WFR41

T_BL_OFF:       MOVLW	HIGH BL_OFF_TXT	;Backlight off text
		MOVWF	TBLPTRH
                MOVLW	LOW BL_OFF_TXT
		MOVWF	TBLPTRL
		BSF	LCD_COPY        ;From table
		BSF	LCD_ERA         ;Erase first
		CALL	LCD

WFR41           CALL	PROC_DSS	;Read RE

		BTFSS	ROT_SW          ;Pushed?
		GOTO	END_SIT4        ;Yes

		BTFSS   DS_CHANGED      ;Turned?
		GOTO	WFR41           ;No

		BCF	DS_CHANGED
		BTFSS	DS_CU
		GOTO    SBL_ON
		GOTO    SBL_OFF

SBL_ON:		BSF	BACKL
		GOTO	PRESSED4

SBL_OFF:	BCF	BACKL
		GOTO	PRESSED4

END_SIT4:       MOVLW	0X02
		MOVFF	WREG,EEADR
		CALL	EE_READ
		MOVFF	EE_IN,TEMP
		
		BCF	TEMP,7
		BTFSC	BACKL
		BSF	TEMP,7

		MOVLW	0X02            ;Write TEMP to EEPROM
		MOVFF	WREG,EEADR
		MOVFF	TEMP,EEDATA
		CALL	EE_WRITE
		
		CALL	BOUNCE_DELAY
		
WFES4:		BTFSS	ROT_SW
		GOTO	WFES4
		
		CALL	BOUNCE_DELAY
		
		GOTO	SIT4

		RETURN

;--------------------------------------------
;
;General routines
;
;--------------------------------------------

;---------------------------------------
;SET_PWM = Set duty cycle from PWM to C2
;          Entry: PWM_VAL (00 .. 0F)
;---------------------------------------

SET_PWM:	MOVLW	0X0F   		;Check upper limit
		CPFSGT	PWM_VAL         ;Yes
		GOTO	S_PWM           ;No

		CLRF	PWM_VAL         ;Too big, make 0

S_PWM:		BCF	CCP1CON,DC1B1	;LSB's on 0
		BCF	CCP1CON,DC1B0

		MOVLW	HIGH PWM_TABLE  ;Table with values
		MOVFF	WREG,TBLPTRH
		MOVLW	LOW PWM_TABLE
		MOVFF	WREG,TBLPTRL

NEXT_STEP_PWM:	TBLRD*

		MOVFF	TABLAT,WREG
		CPFSEQ	PWM_VAL
		GOTO	NEXT_PWM
		GOTO	DO_PWM

NEXT_PWM:	BCF	STATUS,C
		MOVLW	0X02
		ADDWF	TBLPTRL
		GOTO	NEXT_STEP_PWM
		
DO_PWM:         TBLRD*+
		TBLRD*
		MOVFF	TABLAT,CCPR1L

		RETURN
		
;----------------------------------
;DIAM_TO_O = Read wheel data
;            Exit: O1,O2
;                  WN_U, WN_H, WN_L
;----------------------------------

DIAM_TO_O:	MOVLW	HIGH WHEEL_TABLE;Table with wheeldata
		MOVFF	WREG,TBLPTRH
		MOVLW	LOW WHEEL_TABLE
		MOVFF	WREG,TBLPTRL

DIO_LOOP:	TBLRD*+             	;Read diameter
		MOVFF	TABLAT,WREG     ;Compare with current
		CPFSEQ	DIAM            ;Equal
		GOTO	NEXT_DIO        ;Not equal

		TBLRD*+                 ;Read radius 1
		MOVFF	TABLAT,O1
		TBLRD*+                 ;Read radius 2
		MOVFF	TABLAT,O2
		TBLRD*+
		MOVFF	TABLAT,WN_U 	;Wheelnumber (radius x 36000)
                TBLRD*+
		MOVFF	TABLAT,WN_H
		TBLRD*+
		MOVFF	TABLAT,WN_L

		GOTO	END_DTO

NEXT_DIO:	BCF	STATUS,C
		MOVLW	0X09		;Tabel steps 10 (but 1 already counted)
		ADDWF	TBLPTRL
		BTFSC	STATUS,C
		INCF	TBLPTRH

		GOTO	DIO_LOOP

END_DTO:	RETURN

;-----------------------------------------------------------------------
;DIVIDE = Divide 24 bits with a 16 bit number
;         Entry: NUMBER_U, NUMBER_H, NUMBER_L = Number to be divided
;                DIVISOR_H,DIVISOR_L = Divider
;         Exit:  NUMBER_U, NUMBER_H, NUMBER_L = Result
;                REMAINDER_H, REMAINDER_L = Remainder
;-----------------------------------------------------------------------

DIVIDE:		CLRF	REMAINDER_H
		CLRF	REMAINDER_L
		MOVLW	0X18
		MOVFF	WREG,GEN_CNT

DIV_LOOP:	BCF	STATUS,C

		RLCF	NUMBER_L,W
		RLCF	NUMBER_H,F
		RLCF	NUMBER_U,F

		RLCF	REMAINDER_L,F
		RLCF	REMAINDER_H,F

		RLCF 	NUMBER_L,F

		MOVF	DIVISOR_L,W
		SUBWF	REMAINDER_L,F

		MOVF	DIVISOR_H,W
		BTFSS	STATUS,C
		INCFSZ	DIVISOR_H,W
		SUBWF	REMAINDER_H,F

		BTFSC	STATUS,C
		BSF	NUMBER_L,0
		BTFSC	NUMBER_L,0
		GOTO	IM_LOOP

		ADDWF	REMAINDER_H,F
		MOVF	DIVISOR_L,W
		ADDWF	REMAINDER_L,F

IM_LOOP:	DECFSZ	GEN_CNT,F
		GOTO	DIV_LOOP

		RETURN
		
;-----------------------------------------------------------------------
;SPEED = Calculate speed this turn, wheelnumber / (tmr0/100)
;        Exit: TS_x has overall topspeed
;-----------------------------------------------------------------------

SPEED:		BTFSC	SU_CNT,3	;Start up counter > 8 
		GOTO 	SP_CNT

		INCF	SU_CNT		;Increment start-up counter
		GOTO	END_SP  	;Delay measurement

SP_CNT:		MOVFF	TMR0U,NUMBER_U	;Counter to divisor
		MOVFF	TMR0H,NUMBER_H
		MOVFF	TMR0L,NUMBER_L

		CLRF	DIVISOR_H     	;Divide by 100
		MOVLW	0X64
		MOVFF	WREG,DIVISOR_L

		CALL	DIVIDE

		MOVFF	NUMBER_H,DIVISOR_H;Result is divisor
		MOVFF	NUMBER_L,DIVISOR_L

		MOVFF	WN_U,NUMBER_U	;Wheelnumber is divider
		MOVFF	WN_H,NUMBER_H
		MOVFF	WN_L,NUMBER_L

		CALL	DIVIDE

		MOVFF	NUMBER_H,SPEED_H;Save speed
		MOVFF	NUMBER_L,SPEED_L

		MOVLW	0X05   		;Upper limit
		CPFSGT	SPEED_H
		GOTO	C_HS
		GOTO	END_SP

C_HS:		MOVFF	SPEED_H,WREG	;Read speed to W
		CPFSGT	TS_H            ;Skip if top speed > speed
		GOTO 	TSH_EQ
		GOTO    END_SP

TSH_EQ:		MOVFF	SPEED_H,WREG	;Read top speed to W
		CPFSEQ	TS_H            ;Skip if top speed = speed
		GOTO	NEW_TOP         ;Speed > top speed; update

		MOVFF	SPEED_L,WREG	;Low digit speed to W
		CPFSGT	TS_L            ;Skip if top speed > speed
		GOTO	NEW_TOP
		GOTO    END_SP

NEW_TOP:	MOVFF	SPEED_H,TS_H	;Current speed = top speed
		MOVFF	SPEED_L,TS_L
		GOTO	END_SP

END_SP:		RETURN
		
;------------------------------------------------------
;HEX_TO_DEC = Convert hex number to decimal
;             Entry: H_x hexl (4 bytes, H_0 is lowest)
;             Exit : D_x decimal (D_0 is lowest)
;------------------------------------------------------

HEX_TO_DEC:	CLRF	D_0 		;Reset decimal result
                CLRF	D_1
                CLRF	D_2
                CLRF	D_3
                CLRF	D_4
                CLRF	D_5
                CLRF	D_6
                CLRF	D_7
                CLRF	D_8
                CLRF	D_9

		LFSR	0,H_0		;Points to hex input
		LFSR	1,H_0L		;Convert to nibbles

		MOVLW	0X04
		MOVFF	WREG,LOOP_CNT	;4 values

DIV_INP:	MOVFF	POSTINC0,TEMP	;Read byte
		MOVFF	TEMP,GEN_CNT    ;and store it
		MOVLW	0X0F            ;Store low nibble
		ANDWF	TEMP
		MOVFF	TEMP,POSTINC1

		RRNCF	GEN_CNT         ;Rotate byte 4 x
                RRNCF	GEN_CNT
                RRNCF	GEN_CNT
                RRNCF	GEN_CNT
                MOVLW	0X0F            ;Isolate low nibble
		ANDWF	GEN_CNT
                MOVFF	GEN_CNT,POSTINC1

                DECFSZ	LOOP_CNT
                GOTO	DIV_INP

                MOVLW	HIGH HTD_TABLE	;Point to number to be increased
                MOVWF	TBLPTRH
                MOVLW	LOW HTD_TABLE
                MOVWF	TBLPTRL

                LFSR	0,H_0L		;Points to to 8 divided bytes

		MOVLW	0X08        	;8 times
		MOVFF	WREG,GEN_CNT

MUL_LOOPH2:     MOVLW	0X0A 		;10 bytes increment factor
                MOVFF	WREG,LOOP_CNT
                LFSR	1,MUL_9         ;Store in MUL variables

FILL_MUL2:      TBLRD*+
                MOVFF	TABLAT,POSTINC1
                DECFSZ	LOOP_CNT
                GOTO	FILL_MUL2

                MOVFF	POSTINC0,TEMP	;Number of increments
		MOVLW	0X00		;Or is that zero?
		CPFSEQ	TEMP
		GOTO	DO_MUL2		;No
		GOTO	CHECK_END2	;Yes

DO_MUL2:	MOVFF	TEMP,LOOP_CNT	;Number of increments

MUL_LOOPL2:	MOVLW	0X0A 		;10 x
		MOVFF	WREG,LOOP_CNT2

		LFSR	1,MUL_0
		LFSR	2,D_0

A_10_N		BCF	STATUS,C
		MOVFF	POSTDEC1,WREG   ;MUL variables back
		ADDWF   INDF2           ;Add to D_x

		MOVLW	0X09            ;Greater 9?
		CPFSGT	INDF2           ;
		GOTO	N_ST            ;No

		BSF	STATUS,C        ;Yes, correct
		MOVLW	0X0A            ;Subtract 10 for decimal correction
		SUBWF	INDF2           ;Subtract from D_x
		MOVFF	POSTINC2,WREG   ;Increase pointer because next
		INCF	INDF2           ;value needs carry
		GOTO	CH_N            ;Next step

N_ST:		MOVFF	POSTINC2,WREG   ;Increase pointer

CH_N:		DECFSZ	LOOP_CNT2       ;10 x
		GOTO	A_10_N

		DECFSZ	LOOP_CNT
		GOTO	MUL_LOOPL2

CHECK_END2:	DECFSZ	GEN_CNT  	;8 x handled?
		GOTO	MUL_LOOPH2      ;No

                RETURN

;---------------------------------------------------
;INC_DIST = Increment distances
;           Entry: O_NUMBER number to be incremented
;---------------------------------------------------

INC_DIST:	BCF	STATUS,C	;Increment for minuts
		MOVFF	O_NUMBER,WREG
		ADDWF	DIST_MIN_L
		BTFSC	STATUS,C
		INCF	DIST_MIN_H

		BCF	STATUS,C  	;Increment for distance
		MOVFF	O_NUMBER,WREG
		ADDWF	DIST_L
		BTFSS	STATUS,C
		GOTO	END_ID
		INCF	DIST_H
		BTFSS	STATUS,C
		GOTO    END_ID
		INCF	DIST_U
		BTFSS	STATUS,C
		GOTO    END_ID
		INCF	DIST_UU

END_ID: 	RETURN

;-------------------------------------------------------------
;MEAS_RESULT = Show results
;              Entry: MEAS_NR is desired measurement (1 .. 15)
;-------------------------------------------------------------

MEAS_RESULT:   	MOVLW	0X08      	;First position in EEPROM - 8
		MOVFF	WREG,EEADR
		MOVLW	0X08            ;Steps are 8
		MULWF	MEAS_NR
		MOVFF	PRODL,WREG
		BCF	STATUS,C
		ADDWF	EEADR           ;EEPROM correct

		CALL	EE_READ   	;Read data
		MOVFF	EE_IN,HR_CNT
		INCF	EEADR
		CALL	EE_READ
		MOVFF	EE_IN,TO_HR_CNT
		INCF	EEADR
		CALL	EE_READ
		MOVFF	EE_IN,DIST_UU
		INCF	EEADR
		CALL	EE_READ
		MOVFF	EE_IN,DIST_U
		INCF	EEADR
		CALL	EE_READ
		MOVFF	EE_IN,DIST_H
		INCF	EEADR
		CALL	EE_READ
		MOVFF	EE_IN,DIST_L
		INCF	EEADR
		CALL	EE_READ
		MOVFF	EE_IN,TS_H
		INCF	EEADR
		CALL	EE_READ
		MOVFF	EE_IN,TS_L

		MOVLW	HIGH RES_TBL	;Preset result
		MOVFF	WREG,TBLPTRH
		MOVLW	LOW RES_TBL
		MOVFF	WREG,TBLPTRL

                LFSR	0,LCD_BUF  	;Fill LCD buffer with all zero fields
                MOVLW	0X32
                MOVFF	WREG,POSTINC0
                MOVLW	0X01
                MOVFF	WREG,POSTINC0

                MOVLW	0X28          	;40 positions
                MOVFF	WREG,GEN_CNT

F_RES_LOOP:     TBLRD*+
                MOVFF	TABLAT,POSTINC0

                DECFSZ	GEN_CNT
                GOTO	F_RES_LOOP

                LFSR	0,LCD_BUF    	;Start table
                INCF	FSR0L           ;Skip number, position and 'M'
                INCF	FSR0L
                INCF	FSR0L

                MOVLW	HIGH TIME_TBL	;ASCII table
                MOVFF	WREG,TBLPTRH
                MOVLW	LOW TIME_TBL
                MOVFF	WREG,TBLPTRL

                MOVLW	0X02 		;Takes steps 2
                MULWF	MEAS_NR		;Number of measurement

                BCF	STATUS,C  	;Correct table
                MOVFF	PRODL,WREG
                ADDWF	TBLPTRL

                TBLRD*+                 ;Read and write 2 digits sequence
                MOVFF	TABLAT,POSTINC0
                TBLRD*+
                MOVFF	TABLAT,POSTINC0
                INCF	FSR0L		;Skip space

                MOVLW	0X00 		;In case 0 entry is empty
                CPFSEQ	HR_CNT          ;
                GOTO	NO_ET 		;Not empty
                MOVLW	0X00
                CPFSEQ	TO_HR_CNT
                GOTO	NO_ET

		MOVLW	HIGH EMPTY_TBL  ;Empty so fill LCD buffer with spaces
		MOVFF	WREG,TBLPTRH
		MOVLW	LOW EMPTY_TBL
		MOVFF	WREG,TBLPTRL

		MOVLW	0X24  		;36
		MOVFF	WREG,GEN_CNT

EM_LOOP:	TBLRD*+                 ;Empty entry
		MOVFF	TABLAT,POSTINC0
		DECFSZ	GEN_CNT         ;Fill it
		GOTO	EM_LOOP

		GOTO	BL_DISP         ;Ready

NO_ET:          MOVLW	HIGH TIME_TBL	;Display hours
                MOVFF	WREG,TBLPTRH
                MOVLW	LOW TIME_TBL
                MOVFF	WREG,TBLPTRL

                MOVLW	0X02    	;Takes steps 2
                MULWF	HR_CNT

                BCF	STATUS,C
                MOVFF	PRODL,WREG
                ADDWF	TBLPTRL

                TBLRD*+      		;Read and display hours
                MOVFF	TABLAT,POSTINC0
                TBLRD*+
                MOVFF	TABLAT,POSTINC0

                INCF	FSR0L

                MOVLW	HIGH TIME_TBL	;ASCII conversion minutes
                MOVFF	WREG,TBLPTRH
                MOVLW	LOW TIME_TBL
                MOVFF	WREG,TBLPTRL

                MOVLW	0X02   		;Boring
                MULWF	TO_HR_CNT

                BCF	STATUS,C
                MOVFF	PRODL,WREG
                ADDWF	TBLPTRL

                TBLRD*+                 ;Write minutes
                MOVFF	TABLAT,POSTINC0
                TBLRD*+
                MOVFF	TABLAT,POSTINC0

                MOVFF	FSR0H,FSR0H_LOC ;Save content LCD buffer pointer
                MOVFF	FSR0L,FRS0L_LOC

		MOVFF	TS_L,H_0  	;Top speed to decimal
                MOVFF	TS_H,H_1
                CLRF	H_2
                CLRF	H_3
                CALL	HEX_TO_DEC

                MOVFF	FSR0H_LOC,FSR0H	;Pointer back
                MOVFF	FRS0L_LOC,FSR0L

                BSF	D_0,4		;Make ASCII
                BSF	D_0,5
                BSF	D_1,4
                BSF	D_1,5
                BSF	D_2,4
                BSF	D_2,5
                BSF	D_3,4
                BSF	D_3,5
                
                INCF	FSR0L		;Skip space
		MOVFF	D_3,POSTINC0    ;Write hours
                MOVFF	D_2,POSTINC0

		INCF	FSR0L           ;Skip double point
		MOVFF	D_1,POSTINC0    ;Write minuts
                MOVFF	D_0,POSTINC0

                MOVFF	FSR0H,FSR0H_LOC ;Now the distance, so first
                MOVFF	FSR0L,FRS0L_LOC ;save pointer again

		MOVFF	DIST_L,H_0  	;Totale distance in hex
                MOVFF	DIST_H,H_1
                MOVFF	DIST_U,H_2
                MOVFF	DIST_UU,H_3
                CALL	HEX_TO_DEC

                MOVFF	FSR0H_LOC,FSR0H ;Pointer back
                MOVFF	FRS0L_LOC,FSR0L

		BCF	STATUS,C	;Go to start distance
		MOVLW	0X08
		ADDWF	FSR0L

                BSF	D_2,4		;Make ASCII
                BSF	D_2,5
                BSF	D_3,4
                BSF	D_3,5
                BSF	D_4,4
                BSF	D_4,5
                BSF	D_5,4
                BSF	D_5,5
                BSF	D_6,4
                BSF	D_6,5
                BSF	D_7,4
                BSF	D_7,5

                MOVFF	D_7,POSTINC0 	;Display distance
                MOVFF	D_6,POSTINC0
                MOVFF	D_5,POSTINC0
                MOVFF	D_4,POSTINC0
                MOVFF	D_3,POSTINC0
                MOVFF	D_2,POSTINC0

BL_DISP:	BCF	LCD_COPY        ;Direct
		BSF	LCD_ERA         ;Erase first
		CALL	LCD

		RETURN

;--------------------------------------------
;SHOW_ALIVE = Blink service LED (processor running)
;--------------------------------------------

SHOW_ALIVE:     MOVLW	0X08		;8 x flash
		MOVWF	GEN_CNT

		MOVLW	0X02            ;Type 5 msec
		MOVWF	DELAY_TYPE
		MOVLW	0X05            ;7 x = 35 msec
		MOVWF	DELAY_LOC

ALIVE_LOOP:	BSF	SERV_LED        ;On
		CALL	DELAY
		BCF	SERV_LED        ;Off
		CALL	DELAY

		DECFSZ	GEN_CNT         ;till empty
		GOTO	ALIVE_LOOP

		BCF	SERV_LED

		MOVLW	HIGH WELC_TXT
		MOVWF	TBLPTRH
                MOVLW	LOW WELC_TXT
		MOVWF	TBLPTRL
		BSF	LCD_COPY        ;From table
		BSF	LCD_ERA         ;Erase first
		CALL	LCD

		RETURN

;-----------------------------------------------------
;do_dump = requires special hardware
;-----------------------------------------------------

do_dump:	bcf	SSPCON1,SSPEN

		bcf	TRISC,3
		bcf	TRISC,4
		bcf	latc,3
		bcf	latc,4

		movlw	0x00
		call	send_dump

		movlw	0xaa
		call	send_dump

                movlw	0x01
                call	dts

                movlw	0x55
		btfsc	dd_nr,0x07
		movlw	0x5a
		call	send_dump

		movlw	0x7f
		andwf	dd_nr
		movff	dd_nr,loop_cnt
		movff	dd_nr,wreg
		call	send_dump

		lfsr	2,dd_0

bytes_to_dump:	movff	postinc2,wreg
		call	send_dump

		decfsz  loop_cnt
		goto	bytes_to_dump

		bsf	TRISC,3
		bsf	TRISC,4
		bsf	latc,3
		bsf	latc,4

		bsf	sspcon1,sspen

		movlw	0x0a
		call	dts

		return

;send_dump
;------------------------------------

send_dump:	movff	wreg,temp

		bsf	dump_data
		btfss	temp,7
		bcf	dump_data
		movlw	0x01
		call	dts
		bsf	dump_clock
		movlw	0x01
		call	dts
		bcf	dump_clock

                bsf	dump_data
		btfss	temp,6
		bcf	dump_data
		movlw	0x01
		call	dts
		bsf	dump_clock
		movlw	0x01
		call	dts
		bcf	dump_clock

		bsf	dump_data
		btfss	temp,5
		bcf	dump_data
		movlw	0x01
		call	dts
		bsf	dump_clock
		movlw	0x01
		call	dts
		bcf	dump_clock

		bsf	dump_data
		btfss	temp,4
		bcf	dump_data
		movlw	0x01
		call	dts
		bsf	dump_clock
		movlw	0x01
		call	dts
		bcf	dump_clock

		bsf	dump_data
		btfss	temp,3
		bcf	dump_data
		movlw	0x01
		call	dts
		bsf	dump_clock
		movlw	0x01
		call	dts
		bcf	dump_clock

		bsf	dump_data
		btfss	temp,2
		bcf	dump_data
		movlw	0x01
		call	dts
		bsf	dump_clock
		movlw	0x01
		call	dts
		bcf	dump_clock

		bsf	dump_data
		btfss	temp,1
		bcf	dump_data
		movlw	0x01
		call	dts
		bsf	dump_clock
		movlw	0x01
		call	dts
		bcf	dump_clock

		bsf	dump_data
		btfss	temp,0
		bcf	dump_data
		movlw	0x01
		call	dts
		bsf	dump_clock
		movlw	0x01
		call	dts
		bcf	dump_clock
                movlw	0x01
		call	dts

		return

;--------------------------------------------
;INIT = Initialise controller and variables
;--------------------------------------------

INIT:           BSF	RCON,IPEN 	;Interrupt priority

		BCF	INTCON,GIE 	;No interrupts
		BCF	INTCON,PEIE

		MOVLW	0X00 		;Oscillator external
		MOVWF	OSCCON

                MOVLW	0X00
		MOVFF	WREG,ANSELA	;All digital
		MOVFF	WREG,ANSELB
		MOVFF	WREG,ANSELC

		BCF	TRISA,1		;Interrupt toggle
		BCF	TRISA,0		;Backlight
		BCF	TRISA,2         ;ServiceLED

		BCF	TRISA,3		;LCD control
                BCF	TRISA,4
                BCF	TRISA,5

		BSF	TRISB,0		;Reflection
		BSF	TRISB,1
		BCF	TRISB,2		;PWM Output

		BSF	TRISB,3		;Rotary
                BSF	TRISB,4
                BSF	TRISB,5

		CLRF	TRISC		;LCD data

		BSF	BACKL           ;Backlight
		BCF	SERV_LED        ;ServiceLED

		CLRF	FLAGS
		CLRF	FLAGS2
		CLRF	WREG_LOC

		CLRF	GEN_CNT
		CLRF	LOOP_CNT
		CLRF	LOOP_CNT2
		CLRF	TEMP

		CLRF	DELAY_LOC
		CLRF	DELAY_TYPE
		CLRF	DELAY_H
		CLRF	DELAY_L
		CLRF	CNT_DELAY_H
		CLRF	CNT_DELAY_L
		CLRF	MAIN_DELAY
		CLRF	DTS_TIMER

		CLRF	LCD_DATA
                CLRF	LCD_POS

                LFSR	0,LCD_BUF
		MOVLW	0X2A
		MOVFF	WREG,LOOP_CNT
ERA_FIELDSI1:	CLRF	POSTINC0
		DECFSZ	LOOP_CNT
		GOTO	ERA_FIELDSI1

		CLRF	LCD_CNT_H
		CLRF	LCD_CNT_L
		
		CLRF	SW_STAT
		CLRF	TRANS
		CLRF	SW_CNT_U
		CLRF	SW_CNT_D
		CLRF	SW_DELAY
		
		CLRF	DELAY_CNT

		CLRF	EE_IN
		CLRF	EE_CNT
		
		CLRF	PWM_VAL
		
		CLRF	DIAM
		CLRF	POS_DIAM
		CLRF	O1
		CLRF	O2
		CLRF	O_NUMBER

		CLRF	DIST_UU
		CLRF	DIST_U
		CLRF	DIST_H
		CLRF	DIST_L
		
		CLRF	DIST_MIN_H
		CLRF	DIST_MIN_L

		CLRF	TO_SEC_CNT
		CLRF	TO_MIN_CNT
		CLRF	TO_HR_CNT
		CLRF	HR_CNT
		
		CLRF	TMR0U

		CLRF	INT_DIV
		
		CLRF	NUMBER_U
		CLRF	NUMBER_H
		CLRF	NUMBER_L
		CLRF	DIVISOR_H
		CLRF	DIVISOR_L
		CLRF	REMAINDER_H
		CLRF	REMAINDER_L
		
		CLRF	D_0
		CLRF	D_1
		CLRF	D_2
		CLRF	D_3
		CLRF	D_4
		CLRF	D_5
		CLRF	D_6
		CLRF	D_7
		CLRF	D_8
		CLRF	D_9
		
		CLRF	H_0
		CLRF	H_1
		CLRF	H_2
		CLRF	H_3
		CLRF	H_4
		CLRF	H_5
		
		CLRF	H_0L
		CLRF	H_0H
		CLRF	H_1L
		CLRF	H_1H
		CLRF	H_2L
		CLRF	H_2H
		CLRF	H_3L
		CLRF	H_3H
		
		CLRF	MUL_9
                CLRF	MUL_8
                CLRF	MUL_7
                CLRF	MUL_6
		CLRF	MUL_5
		CLRF	MUL_4
                CLRF	MUL_3
                CLRF	MUL_2
                CLRF	MUL_1
                CLRF	MUL_0

                CLRF	SPEED_H
                CLRF	SPEED_L

                CLRF	TS_H
                CLRF	TS_L
                
                CLRF	MEAS_NR

                CLRF	SU_CNT
		
		MOVLW	0X03           ;Timer 0 off, predivide 16
		MOVFF	WREG,T0CON

		MOVLW	0X31		;Timer 1 on, predivide 8
		MOVFF 	WREG,T1CON
		BCF	T1GCON,TMR1GE	;No gate control
		BSF	PIE1,TMR1IE	;Enable timer 1 interrupt
		BCF	IPR1,TMR1IP	;Timer 1 interrupt low priority
		BCF	PIR1,TMR1IF	;Reset interruptflag

                BCF	EECON1,EEPGD	;Prepare EEPROM
		BCF     EECON1,CFGS

		BCF	CCPTMRS0,C1TSEL1;PWM mode
		BCF	CCPTMRS0,C1TSEL0
                MOVLW	0X0C
		MOVFF	WREG,CCP1CON
		MOVLW	0X02         	;B2 is PWM
		MOVFF	WREG,PSTR1CON
		MOVLW	0X05
		MOVFF	WREG,T2CON
		MOVLW	0X68 		;38 KHz
		MOVFF	WREG,PR2

		MOVLW	0X08   		;Duty cycle 50%
		MOVFF	WREG,PWM_VAL
		CALL	SET_PWM

		RETURN

;---------------------
;Start hoofdprogramma
;---------------------

MAIN:  		CALL	INIT 		;Initialise

		CALL	DT_1

		CALL	LCD_INIT	;LCD starts

		CALL	SHOW_ALIVE	;Show

		CALL	DT_1

                CALL	EE_INIT

                CALL	SHOW_ALIVE

		CALL	W_START		;Wait first pushbutton

                GOTO	MAIN_LOOP	;Go to mainscreen

MEAS_CYCLE:     CALL	BOUNCE_DELAY

		MOVLW	HIGH M_RUNS_TXT	;Measurement runs text
		MOVWF	TBLPTRH
                MOVLW	LOW M_RUNS_TXT
		MOVWF	TBLPTRL
		BSF	LCD_COPY        ;From table
		BSF	LCD_ERA         ;Erase first
		CALL	LCD

		BCF	BACKL 		;Backlight control
		BTFSC	BL_M
		BSF	BACKL

                CLRF	TO_SEC_CNT	;Measurement start position
		CLRF	TO_MIN_CNT
		CLRF	TO_HR_CNT
		CLRF	HR_CNT
		BCF	DAY_OVERFLOW

		CLRF	DIST_UU		;Distance in cm
		CLRF	DIST_U
		CLRF	DIST_H
		CLRF	DIST_L

		CLRF	DIST_MIN_H 	;Distance per minute
		CLRF	DIST_MIN_L

		CLRF	TS_H		;Topspeed
		CLRF	TS_L
		CLRF	SPEED_H
		CLRF	SPEED_L

		CLRF	TMR0U		;Erase timer topspeed
		CLRF	TMR0H
		CLRF	TMR0L
		BCF	T0CON,TMR0ON    ;Timer stopped

WFU_START:	BTFSC	PL 		;Wait initial lower pulse
		GOTO	WFU_START

WFU:		BTFSC	PU 		;Wait start
		GOTO	WFU

                CLRF	SU_CNT          ;Reset startup

		BSF	INTCON,GIE 	;Interrupts are allowed
		BSF	INTCON,PEIE

MEAS_LOOP:	BTG	SERV_LED	;Show cyclus

		BTFSC	T0CON,TMR0ON	;Topspeed timer halted?
		CALL	SPEED		;No, so calculate topspeed

		MOVFF	O1,O_NUMBER
		CALL	INC_DIST	;Update distances

                CLRF	TMR0U           ;Erase times topspeed
		CLRF	TMR0H
		CLRF	TMR0L
		BSF	T0CON,TMR0ON    ;Timer on

WFL_LOOP:	BTFSS	ROT_SW  	;Pushed to stop?
		GOTO	END_MEAS        ;Yes
		BTFSC	DAY_OVERFLOW	;Overflow 24 hrs?
		GOTO	END_MEAS        ;Yes

		BTFSC	INTCON,TMR0IF	;Topspeed counter overflowed?
		GOTO	TMRU_UP1        ;Yes
		GOTO    NO_TMRU1        ;No

TMRU_UP1:	BTFSS	T0CON,TMR0ON	;Counter already stopped?
		GOTO	NO_TMRU1        ;Yes
		INCF	TMR0U  		;Increment upperbyte
		BCF	INTCON,TMR0IF   ;Erase flag 
		BTFSC	TMR0U,6         ;Not over 4000h
                BCF     T0CON,TMR0ON	;Stop topspeed counter

NO_TMRU1:	BTFSC	PL      	;Wait lower pulse
		GOTO	WFL_LOOP

		MOVFF	O2,O_NUMBER
		CALL	INC_DIST	;Lower pulse detected, update distances

WFU_LOOP:	BTFSS	ROT_SW          ;Pushed to stop?
		GOTO	END_MEAS        ;Yes
                BTFSC	DAY_OVERFLOW	;Over 24 hrs?
		GOTO	END_MEAS        ;Yes

		BTFSC	INTCON,TMR0IF	;Topspeed counter overflowed?
		GOTO	TMRU_UP2        ;Yes
		GOTO    NO_TMRU2        ;No

TMRU_UP2:	BTFSS	T0CON,TMR0ON	;Counter already stopped?
		GOTO	NO_TMRU2        ;Yes
		INCF	TMR0U  		;Increment upperbyte
		BCF	INTCON,TMR0IF	;Erase flag
		BTFSC	TMR0U,6         ;Not over 4000h
                BCF     T0CON,TMR0ON	;Stop topspeed counter

NO_TMRU2:	BTFSC	PU              ;Wait pulse upper sensor
		GOTO	WFU_LOOP

		GOTO	MEAS_LOOP

END_MEAS:       BCF	INTCON,GIE 	;No interrupts
		BCF	INTCON,PEIE

		CALL	BOUNCE_DELAY

		MOVLW	0X00   		;Time 00:00 will not be written in EEPROM
		CPFSEQ	HR_CNT
		GOTO	WR_EESH
		MOVLW	0X00
		CPFSEQ	TO_HR_CNT
		GOTO    WR_EESH
		GOTO	CH_BL

WR_EESH:	CALL	EE_SHIFT	;Update EEPROM

CH_BL:		BCF	BACKL
		BTFSC	BL
		BSF	BACKL

                MOVLW	HIGH M_STOP_TXT	;Measurement stopped text
		MOVWF	TBLPTRH
                MOVLW	LOW M_STOP_TXT
		MOVWF	TBLPTRL
		BSF	LCD_COPY        ;From table
		BSF	LCD_ERA         ;Erase first
		CALL	LCD

	        CALL	DT_3

		MOVLW	0X01
		MOVFF	WREG,MEAS_NR
		
		CALL	MEAS_RESULT

WFRE:		BTFSC	ROT_SW
		GOTO	WFRE
		
		CALL    BOUNCE_DELAY
		
		GOTO	MAIN_LOOP


		END





