	Page	55,80
	Title	Sample program for Soft-ICE tutorial

CODE	Segment Public	'Code'
CODE	Ends

DATA	Segment Public	'Data'

public pad,char,answer,space_msg,no_space_msg

pad		db 12H dup(0)
char		db 0
answer		db 0
space_msg	db 'The Character is a SPACE',0DH,0AH,'$'
no_space_msg	db 'The Character is NOT a SPACE',0DH,0AH,'$'
DATA	Ends

STACK	Segment Stack	'Stack'

	Dw	128 Dup (?)		;Program stack

STACK	Ends

CODE	Segment Public	'Code'

	Assume	CS:CODE,DS:DATA,ES:Nothing,SS:STACK

public start,main_loop,no_space,get_key,is_space?,not_space,hang_example

start:

; Set up segments

	mov	ax,DATA 		;ax = DATA segment
	mov	es,ax			;es = DATA segment
	mov	ds,ax			;ds = DATA segment

; Main Program Loop

main_loop:

	call	get_key 		;call Jake's get key routine
	call	is_space?		;call Jake's is_space routine
	cmp	answer,0		;was it a space?
	je	no_space		;no - go print not a space message

; Its a space, display the space message

	mov	ah,9			;ah = DOS display string function
	mov	dx,offset space_msg	;dx -> space message
	int	21H			;call DOS
	jmp	main_loop		;jump back to the main loop

; Its not a space, display the no space message

no_space:
	mov	ah,9			;ah = DOS display string function
	mov	dx,offset no_space_msg	;dx -> not a space message
	int	21H			;call DOS
	jmp	main_loop		;jump back to the main loop

; Get Key Routine

get_key 	proc
	mov	ah,8			;ah = DOS get key function
	int	21H			;call DOS
	mov	char,al 		;store byte in variable char
	ret				;return from this routine
get_key 	endp

; Check to see if the character is a space

is_space?	proc
	cmp	char,20H		;is the character a space?
	jne	not_space		;no - go do funny business
	mov	answer,1		;yes - return 1 in variable answer
	ret				;return from this routine
not_space:
assume cs:data				;required to produce bizzar bug
	mov	cs:answer,0		;return 0 in variable answer
assume cs:code
	ret				;return from this routine
is_space?	endp

; The following routine is an infinite loop with interrupts disabled

hang_example:
	cli				;disable interrupts
	jmp	$			;infinite loop

	mov	ax,4c00h		;ax = DOS exit command
	int	21h			;call MSDOS

CODE	Ends
	End	start
