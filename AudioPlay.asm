#############################################################################################################################
## Written by Dylan Taylor
## MIPS Audio Player and Composer - Reads in data in a proprietary format and plays it back as audio.
## MARS does not support channels, which makes "true" MIDI playback (nearly) impossible and very slow at best.
## This program is degisned to play a simplified version of MIDI with only a single 'channel' that dynamically
## switches between instruments per each note. In MIDI, each channel is assigned an instrument, and each note 
## is turned on and off by NOTE_ON and NOTE_OFF commands. There is no duration specified in the midi file.
##
## note: when inputting data, make sure that backspaces on paths are escaped. for example, C:\test.txt --> C:\\test.txt
##
###### Proprietary File Format Description
## This program is designed to play a proprietary format file designed by me to be easy to parse.
## This format was designed _specifically_ for usage with this program since it's compact and much less complicated than midi                   
##
## The first line of the file is a word that contains the number of notes in the file. This must be a positiven integer value.
##
## Each note is described by several attributes, "note descriptors". A pipe symbol ('|') acts as a delimiter for each below,
## but in the actual file these are stored as adjacent words and read into data memory. We don't need to check for new lines
## or delimiters because we know exactly how long the file is based on the number of notes, and we know how to parse the values.
## These tell the computer how and when to play the note and must be listed in the order below. All are positive integers.
##
## Pitch|Duration|Velocity|Instrument
#############################################################################################################################
# relevant links and what-not
# http://www.youtube.com/watch?v=SNwjUWKP18c --  song of storms on youtube
###


.data
	stack_begin: .word   0 : 200
	stack_end:
	welcome:	.asciiz "Basic MARS audio player, written by Dylan Taylor.\n"
	invalid:	.asciiz "Sorry, unable to open file. Please try again.\n"
	reading:	.asciiz "Reading file into data memory, please wait... \n\n"
	filePrompt:	.asciiz "\nEnter Filename (full path is required): "
	file:		.asciiz "P:\\cmpen351\\storms.txt" #User input file name goes here
	buffer: 	.space 102400 #And here we store our notes. 100kb max.
	select:		.asciiz "Enter 1 to play an exsting song, 2 to create a new one, 3 for a short demo: "
	another: 	.asciiz "Enter another note (0=No/1=Yes)? "
	pitch_prompt:	.asciiz "Enter the pitch of the note (0-127): "
	dur_prompt:	.asciiz "Enter the duration of the note (>0): "
	inst_prompt:	.asciiz "Enter which instrument should play this note (0-127): "
	vel_prompt:	.asciiz	"Enter the velocity (\"volume\") of the note: "
	fname_prompt:	.asciiz	"What would you like to save this tune as? "
	enjoy:		.asciiz "Sit back, relax, and enjoy the song :-)\n"
	demo_inst:	.asciiz "What instrument would you like to use? "
	writing:	.asciiz "Please wait while the notes are written to the file... "
	#limitation of 200 notes
	mode: .word 0
	numNotes: .word 0
	#these were going to be used for simultaneous notes. this feature was axed in order to turn the project in on time
#	note_start: .word 71,107,143,287,323,359
	#note_pitch: .word 64,64,64,64,64,64,64,62,64,64,64
#	note_start: .word 0:200
	note_duration: .word 0:200
	note_duration_demo: .word 280,280,1144,280,280,1144,1144,280,280,280,280,280,1144,568,568,280,280,1720,568,568,280,280,1720,280,280,1144,280,280,1144,1144,280,280,280,280,280,1144,568,568,280,280,1720,280,3440
	note_pitch: .word 0: 200
	# note that the last note is off. in the original sheet music it's a combination of an E and a G note
	note_pitch_demo: .word 62,65,74,62,65,74,76,77,76,77,76,72,69,69,62,65,67,69,69,62,65,67,64,62,65,74,62,65,74,76,77,76,77,76,72,69,69,62,65,67,69,69,64
	note_instrument_demo: .word 79
	note_velocity_demo: .word 100
	note_velocity: .word 0:200
	note_instrument: .word 0:200
	
.text

EntryPoint:
	#Greeting
	li $v0, 4
	la $a0, welcome
	syscall
ModePrompt:
	li $v0, 4
	la $a0, select
	syscall
	li $v0, 5
	syscall
	#make sure that the mode the user enters is valid
	move $s0, $v0
	blt $s0, 1, ModePrompt
	bgt $s0, 3, ModePrompt
PreJump:
	la $ra, PreJump
	beq, $s0, 3, Demonstration
	beq, $s0, 1, InputFilenameForRead
	beq, $s0, 2, InputFilenameForWrite
	
	j PlayNotes
	j Exit

## Only called in the case of an error reading the file
InvalidFile:
	#Invalid Message
	li $v0, 4
	la $a0, invalid
	syscall
InputFilenameForRead:
	#Play prompt sound (hardcoded), mostly just to test midi output.
	li $v0, 33		#
	li $a0, 60		# pitch
	li $a1, 64		# duration
	li $a2, 0		# channel
	li $a3, 50		# volume
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
cleanR:
	beq $t0, $t1, ReadFile
   	lb $t3, file($t0)
    	bne $t3, 0x0a, incrementCleanRLoop
    	sb $zero, file($t0)
incrementCleanRLoop:
    	addi $t0, $t0, 1
j cleanR

ReadFile: 
	# First, we open the file
	li $v0, 13	# syscall 13 - open file
	la $a0, file	# loads the address of file as argument
	li $a1, 0	# 0 = read, 1 = write
	li $a2, 0	# mode is ignored. why is this line necessary then? I don't know, I copied this from the help menu of MARS.
	syscall
	#At this point in time, $v0 will either contain a file descriptor or it will be <0 if there is an error.
	bltz $v0, InvalidFile #If there is an error, ask for a new file name
	move $s0, $v0   # otherwise, save the file descriptor to $s0
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
	#the file is (hopefully) open, and we have the file descriptor saved to $s0.
	li $v0, 14	# syscall 14 - read from the file
	move $a0, $s0	# copy the file descriptor to use as the argument
	la $a1, numNotes
	li $a2, 4
	syscall
	lw $t8 numNotes
	li $t9, 0 #keeps track of number of notes read
	la $t0, note_duration
	la $t1, note_pitch
	la $t2, note_velocity
	la $t3 note_instrument
ReadUntilEnd:
	addi $t9, $t9, 1
	#here is where we retrieve the values from the file and store them to data memory
	li $v0, 14 #syscall to read data from the file
	move $a0, $s0 #move the file descriptor to the first argument
	la $a1, 0($t0)#note_pitch
	li $a2, 4
	syscall
	li $v0, 14 #syscall to read data from the file
	move $a0, $s0 #move the file descriptor to the first argument
	la $a1, 0($t1)#note_duration
	li $a2, 4
	syscall
	li $v0, 14 #syscall to read data from the file
	move $a0, $s0 #move the file descriptor to the first argument
	la $a1, 0($t2)#note_velocity
	li $a2, 4
	syscall
	li $v0, 14 #syscall to read data from the file
	move $a0, $s0 #move the file descriptor to the first argument
	la $a1, 0($t3)#note_instrument
	li $a2, 4
	syscall
	addi $t0, $t0, 4
	addi $t1, $t1, 4
	addi $t2, $t2, 4
	addi $t3, $t3, 4
	blt $t9, $t8, ReadUntilEnd
	
	nop #break here for debugging; $v0 contains number of characters read.
	tlti $v0, 0 #if $v0 is -1 then something went horrible wrong.	
	#once we read in all the notes, it would only be logical to play the song.
	j PlayNotes
	
InputFilenameForWrite:
	#Play prompt sound (hardcoded), mostly just to test midi output.
	li $v0, 33		# synchronous midi
	li $a0, 60		# pitch
	li $a1, 250		# duration
	li $a2, 0		# channel
	li $a3, 50		# volume
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
cleanW:
	beq $t0, $t1, NoteEntry
   	lb $t3, file($t0)
    	bne $t3, 0x0a, incrementCleanWLoop
    	sb $zero, file($t0)
incrementCleanWLoop:
    	addi $t0, $t0, 1
j cleanW

NoteEntry:
	li $t0, 0 #keeps track of number of notes entered
	la $t2, note_pitch
	la $t3, note_duration
	la $t4, note_velocity
	la $t5, note_instrument
NoteEntryLoop:
	addi $t0, $t0, 1
	#prompt for pitch and have the user enter an integer value
	li $v0, 4
	la $a0, pitch_prompt
	syscall
	li $v0, 5
	syscall
	move $t1, $v0 #move the value to $t1
	sw $t1, 0($t2)
	#prompt for duration and have the user enter an integer value
	li $v0, 4
	la $a0, dur_prompt
	syscall
	li $v0, 5
	syscall
	move $t1, $v0 #move the value to $t1
	sw $t1, 0($t3)
	#prompt for velocity (volume) and have the user enter an integer value
	li $v0, 4
	la $a0, vel_prompt
	syscall
	li $v0, 5
	syscall
	move $t1, $v0 #move the value to $t1
	sw $t1, 0($t4)
	#prompt for instrument and have the user enter an integer value
	li $v0, 4
	la $a0, inst_prompt
	syscall
	li $v0, 5
	syscall
	move $t1, $v0 #move the value to $t1
	sw $t1, 0($t5)
	jal AnotherNote
	addi $t2, $t2, 4
	addi $t3, $t3, 4
	addi $t4, $t4, 4
	addi $t5, $t5, 4
	sw $t0, numNotes
	beq $v0, 1, NoteEntryLoop
	j WriteNotesToFile
	
AnotherNote:
	li $v0,4 
	la $a0, another
	syscall
	li $v0, 5
	syscall
	blt $v0, 0, AnotherNote
	bgt $v0, 1, AnotherNote
	jr $ra
	
WriteNotesToFile:
	li $v0, 4
	la $a0, writing
	syscall
	li $t9, -1 #number of notes written
	# First, we open the file
	li $v0, 13	# syscall 13 - open file
	la $a0, file	# loads the address of file as argument
	li $a1, 1	# 0 = read, 1 = write
	li $a2, 0	# mode is ignored. 
	syscall
	#$v0 will contain the file descriptor
	move $s0, $v0   # save the file descriptor to $s0
	la $t0, note_duration
	la $t1, note_pitch
	la $t2, note_velocity
	la $t3 note_instrument
	#write the number of notes to the file
	#addi $t1, $t1, 1 #increment loop counter
	li $v0, 15 #writes data to the file
	move $a0, $s0 #move the file descriptor to the first argument
	la $a1, numNotes
	li $a2, 4
	syscall
WriteNoteLoop:
	li $v0, 15 #writes data to the file
	move $a0, $s0 #move the file descriptor to the first argument
	la $a1, 0($t0)#note_pitch
	li $a2, 4
	syscall
	li $v0, 15 #writes data to the file
	move $a0, $s0 #move the file descriptor to the first argument
	la $a1, 0($t1)#note_duration
	li $a2, 4
	syscall
	li $v0, 15 #writes data to the file
	move $a0, $s0 #move the file descriptor to the first argument
	la $a1, 0($t2)#note_velocity
	li $a2, 4
	syscall
	li $v0, 15 #writes data to the file
	move $a0, $s0 #move the file descriptor to the first argument
	la $a1, 0($t3)#note_instrument
	li $a2, 4
	syscall
	#set up the addresses for reading of the next 4 bytes
	addi $t0, $t0, 4
	addi $t1, $t1, 4
	addi $t2, $t2, 4
	addi $t3, $t3, 4
	lw $t4, numNotes
	addi $t9, $t9, 1
	blt $t9, $t4, WriteNoteLoop
	#close the file
	li $v0, 16
	move $a0, $s0
	syscall
	j Exit
	
Demonstration:
	#This function plays a hard coded tune that I mapped out by hand. It's based on the Song of Storms from Legend of Zelda.
	li $t0, 44 #number of notes to read into data memory
	li $t1, 0 #how many we copied already
	sw $t0, numNotes #set the number of notes
	li $v0, 4
	la $a0, demo_inst
	syscall
	li $v0, 5
	syscall
	move $t0, $v0
DemonstrationLoop:
	#make the registers point to our sample data
	la $t2, note_duration_demo
	la $t3, note_pitch_demo
	mul $t4, $t1, 4 #word offset
	add $t2, $t2, $t4
	add $t3, $t3, $t4
	lw $t2, 0($t2)
	lw $t3, 0($t3)
	div $t2, $t2, 2 #halve note duration
	la $t5, note_duration
	la $t6, note_pitch
	la $t7, note_instrument
	la $t8, note_velocity
	add $t5, $t5, $t4
	add $t6, $t6, $t4
	add $t7, $t7, $t4
	add $t8, $t8, $t4	
	sw  $t2, 0($t5)
	sw  $t3, 0($t6)
#	li $t9, 79
	sw $t0, 0($t7)
	li $t9, 100
	sw $t9, 0($t8)
	addi $t1, $t1, 1
	blt $t1, $t0, DemonstrationLoop
	
	j PlayNotes
	
PlayNotes:
	#pring out the enjoy string
	li $v0, 4
	la $a0, enjoy
	syscall
	#start counter at -1
	li $t0, -1
	#load in number of notes to play
	lw $t2, numNotes
PlayNotesLoop:
	addi $t0, $t0, 1 #inc count
	mul $t1, $t0, 4 #adj for word size
	#set up base addresses
	la $a0, note_pitch
	la $a1, note_duration
	la $a2, note_instrument
	la $a3, note_velocity
	#get next note
	add $a0, $a0, $t1
	add $a1, $a1, $t1
	add $a2, $a2, $t1
	add $a3, $a3, $t1
	#load the words from the addresses
	lw $a0, 0($a0)
	lw $a1, 0($a1)
	lw $a2, 0($a2)
	lw $a3, 0($a3)
	#call the play piano note subroutine
	jal PlayPianoNote
	addi $t0, $t0, 0
	bge $t0, $t2, Exit
	j PlayNotesLoop
	
#Plays a piano note 
#Takes in pitch, duration, instrument, and velocity as a0-a3
PlayPianoNote:
	li $v0, 33 #synchronous midi playback syscall	
## comments here are for easy testing	
#	li $a0, 61		# pitch
#	li $a1, 10		# duration
#	li $a2, 79 		# instrument
#	li $a3, 100		# volume/velocity
	syscall
	jr $ra

Exit:
	#exit gracefully
	li $v0, 10	#syscall 10 - exit 
	syscall
