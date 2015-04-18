#############################################################################################################################
## Written by Dylan Taylor
## MIPS Audio Player - Reads in data in a proprietary format and plays it back as audio.
## This program is designed to run with a custom version of MARS with MIDI support called MARS++.
## MARS does not support channels, which makes MIDI playback (nearly) impossible and very slow at best.
## MARS++ can be found at http://www.mediafire.com/?k55db37153a2zcg. It was modified by Karn Bianco and Dominic Bodman.
##
###### Proprietary File Format Description
## This program is designed to play a proprietary format file designed by me to be easy to parse and human readable.
## This format was designed _specifically_ for usage with this program since it's compact and much less complicated than midi
##
## The first line of the file is the song descriptor. The song descriptor may be no more than 260 characters long.
## This would typically be something like “How to Save a Life by The Fray”. 
## 
## A Unix-style line ending (“\n”), a simple character return, acts as a delimiter for each note. 
##
## Each note is described by several attributes, “note descriptors”. A pipe symbol ('|') acts as a delimiter for each.
## These tell the computer how and when to play the note and must be listed in the order below. All are positive integers.
##
## Start_Time|Channel|Pitch|Duration|Velocity|Instrument
#############################################################################################################################

.data
	stack_begin: .word   0 : 200
	stack_end:
	welcome:	.asciiz "Basic MARS audio player, written by Dylan Taylor.\n"
	invalid:	.asciiz "Sorry, unable to open file. Please try again.\n"
	reading:	.asciiz "Reading file into data memory, please wait... "
	filePrompt:	.asciiz "\nEnter Filename: "
	file:		.asciiz "" #User input file name goes here
	buffer: 	.space 102400 #And here we store our notes. 100kb max.

.text

EntryPoint:
	#Greeting
	li $v0, 4
	la $a0, welcome
	syscall
	jal InputFilename
	j Exit

## Only called in the case of an error reading the file
InvalidFile:
	#Invalid Message
	li $v0, 4
	la $a0, invalid
	syscall
InputFilename:
	#Play prompt sound (hardcoded)
	li $v0, 31		# load the value 38 into register $v0 which is the op code for MIDI Note Play
	li $a0, 60		# pitch
	li $a1, 96		# duration
	li $a2, 0		# channel
	li $a3, 100		# volume
	syscall
	li $a0, 59		# pitch
	syscall
	li $a0, 61		# pitch
	syscall
	# Display prompt for file name
	li $v0, 4
	la $a0, filePrompt
	syscall
	# Read in the file name
	li $v0, 8
	la $a0, file
	li $a1, 260
	syscall
	# Clean up the file name (strip out new line garbage)
   	li $t0, 0  #counter
   	li $t1, 260 #maximum number of characters in NTFS filename is 255.
clean:
	beq $t0, $t1, ReadFile
   	lb $t3, file($t0)
    	bne $t3, 0x0a, incrementCleanLoop
    	sb $zero, file($t0)
incrementCleanLoop:
    	addi $t0, $t0, 1
j clean

ReadFile: 
	# First, we open the file
	li $v0, 13	# syscall 13 - open file
	la $a0, file	# loads the address of file as argument
	li $a1, 0	# 0 = read, 1 = write
	li $a2, 0	# mode is ignored. why is this line necessary then? I don't know, I copied this from the help menu of MARS.
	syscall
	#At this point in time, $v0 will either contain a file descriptor or it will be <0 if there is an error.
	bltz $v0, InvalidFile #If there is an error, ask for a new file name
	#Valid Sound
	li $v0, 31		# load the value 38 into register $v0 which is the op code for MIDI Note Play
	li $a0, 123		# pitch
	li $a1, 800		# duration
	li $a2, 0		# channel
	li $a3, 120		# volume
	syscall
	li $v0, 4
	la $a0, reading
	syscall
	move $s0, $v0   # otherwise, save the file descriptor to $s0
	#the file is (hopefully) open, and we have the file descriptor saved to $s0.
	li $v0, 14	# syscall 14 - read from the file
	move $a0, $s0	# copy the file descriptor to use as the argument
	la $a1, buffer	# load the address of our buffer
	li $a2, 99999  # maximum buffer length (in bytes)
	syscall
	nop #break here for debugging; $v0 contains number of characters read.

#SetChannelInstrument:
#	li $v0, 38		
#	li $a1, 2		
#	syscall
#	jr $ra

PlayNote:
	li $v0, 31		
	li $a0, 61		# pitch
	li $a1, 10		# duration
	li $a2, 1		# channel
	li $a3, 127		# volume
	syscall
	jr $ra


Exit:
	#once we're done with the file, close it
	li $v0, 16	#syscall 16 - close file
	move $a0, $s0	# copy the file descriptor to use as the argument
	syscall
	#exit gracefully
	li $v0, 10	#syscall 10 - exit 
	syscall
