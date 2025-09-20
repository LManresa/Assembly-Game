.data

    x_P:	.word   1				# initial x for P
    y_P:	.word	1				# initial y for P
    map: 	.byte 	35,35,35,35,35,35,35,10   	# "#######\n"
            	.byte 	35,32,82,32,32,32,35,10   	# "#PR   #\n"	-> (1,1)&(1,2) 
            	.byte 	35,32,32,32,32,32,35,10   	# "#     #\n"
            	.byte 	35,32,32,32,32,32,35,10   	# "#     #\n"
            	.byte 	35,32,32,32,32,32,35,10   	# "#     #\n"
            	.byte 	35,32,32,32,32,32,35,10   	# "#    E#\n"  	-> (5,5)
            	.byte 	35,35,35,35,35,35,35,10   	# "#######\n"
            	.byte 	0
    score:      .word   0                		# score variable (starting at 0)
    score_string: 
    		.asciiz "Score: " 		  	# score string
    x_R:    	.word 2               			# initial x for R
    y_R:    	.word 1               			# initial y for R
    prev_x_R:   .word 2    				# initial = x_R
    prev_y_R:   .word 1    				# initial = y_R
    game_over_string: 
    		.asciiz "\nGAME OVER\n"  	  	# game over string
    directives:
    		.asciiz "WASD to move. Q to quit.\n"  	# directives string
    final_score_string: 
    		.asciiz "\nYour final score is "
    x_E:    	.word 5               			# initial x for E
    y_E:    	.word 5               			# initial y for E

.text

    j main

main:

    li $t3, 0xFFFF000C     				# $t3 -> display MMIO

game_loop:

    # clear the screen = ascii 12 (Columbia.edu, 2025)
    li $t9, 0xFFFF000C					# $t9 -> display MMIO
    li $t1, 12
    sb $t1, 0($t9)

    jal print_score        				# print score
    
    li $t3, 0xFFFF000C     				# reload display MMIO
    la $a0, map            				# load map
    jal print_game         				# print map + P + E
    
    jal print_directives				# print directives

    li $t0, 0xffff0000     				# $t0 -> keyboard control register

check_for_input:

    lw $t1, 0($t0)					# check if key pressed
    beqz $t1, check_for_input   			# if $t1 == 0: continue to loop until key pressed
    lw $t2, 4($t0)         				# if $t1 == 1: get ascii of key pressed

    # check correct input for P movement
    beq $t2, 'w', move_up
    beq $t2, 's', move_down
    beq $t2, 'a', move_left
    beq $t2, 'd', move_right
    beq $t2, 'q', exit

    j game_loop

#======================================================================================================#
# score section

print_score:

    subu $sp, $sp, 8					# stack space -> $ra, $a0
    sw $ra, 0($sp)					# save ra
    sw $a0, 4($sp)					# save $a0

    # Print "Score: "
    la $a0, score_string				# load string from data.
    li $t9, 0xFFFF000C     				# $t9 -> display MMIO
    
print_score_str_loop:

    lb $t1, 0($a0)         				# load char
    beqz $t1, print_score_value				# if char == "\0": exit
    sb $t1, 0($t9)					# output char
    addi $a0, $a0, 1    				# next char
       
    j print_score_str_loop

print_score_value:

    # int(score) to ascii
    lw $t2, score
    li $t4, 10             				# $t4 = 10 for base 10
    li $t5, 0              				# digit count

convert_digit_to_ascii_loop:

    divu $t2, $t4      					# $t2 /= 10
    mfhi $t3               				# reste
    mflo $t2               				# quotient
    addi $t3, $t3, 48      				# -> ascii
    subu $sp, $sp, 1       				# digit on stack
    sb $t3, 0($sp)
    addi $t5, $t5, 1       				# count += 1
    bnez $t2, convert_digit_to_ascii_loop 		# if quotient == 0: break

print_converted_digits_loop:

    # pop + print from stack
    lb $t3, 0($sp)
    addu $sp, $sp, 1
    li $t9, 0xFFFF000C     				# load display MMIO
    sb $t3, 0($t9)         				# output digit
    addi $t5, $t5, -1      				# count -= 1
    bnez $t5, print_converted_digits_loop

    # newline after score
    li $t9, 0xFFFF000C 
    li $t3, 10     					# 10 -> newline        
    sb $t3, 0($t9)

    # restore registers used
    lw $ra, 0($sp)
    lw $a0, 4($sp)
    addu $sp, $sp, 8
    
    jr $ra
    
#===============================================================================================#
# player movements section

move_up:

    subu $sp, $sp, 12    				# stack space -> $ra, $s0, $s1
    sw $ra, 0($sp)       				# save $ra
    sw $s0, 4($sp)       				# save $s0 -> y_P
    sw $s1, 8($sp)       				# save $s1 -> x_P

    lw $s0, y_P          				# $s0 = y_P
    addi $s0, $s0, -1    				# y -= 1
    blt $s0, 0, game_over_cleanup 			# check boundaries
    
    lw $s1, x_P		 				# $s1 = x_P
    
    # pass parameters via $a0/$a1
    move $a0, $s1        				# $a0 = current x
    move $a1, $s0        				# $a1 = new y
    
    # if collision -> GAME OVER
    jal check_collision
    beqz $v0, game_over_cleanup
    
    sw $s0, y_P          				# save new y_P
    
    # check if new P pos == current E pos
    lw $t0, x_P
    lw $t1, y_P 
    lw $t2, x_E
    lw $t3, y_E

    beq $t0, $t2, check_y_P_E
    
    j no_P_E_collision

move_down:
    
    subu $sp, $sp, 12
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    
    lw $s0, y_P						# $s0 = y_P
    addi $s0, $s0, 1					# y += 1
    bge $s0, 6, game_over_cleanup
    
    lw $s1, x_P
    
    move $a0, $s1
    move $a1, $s0
    jal check_collision
    
    beqz $v0, game_over_cleanup
    
    sw $s0, y_P						# save new y_P to memory
    
    lw $t0, x_P
    lw $t1, y_P 
    lw $t2, x_E
    lw $t3, y_E

    beq $t0, $t2, check_y_P_E
    
    j no_P_E_collision

move_left:

    subu $sp, $sp, 12
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    
    lw $s0, x_P						# $s0 = x_P
    addi $s0, $s0, -1					# x -= 1
    blt $s0, 0, game_over_cleanup
    
    lw $s1, y_P						# $s1 = current y_P
    
    move $a0, $s0 					# $s0 = new x
    move $a1, $s1 					# $s1 = current y
    jal check_collision
    
    beqz $v0, game_over_cleanup
    
    sw $s0, x_P
    
    lw $t0, x_P
    lw $t1, y_P 
    lw $t2, x_E
    lw $t3, y_E

    beq $t0, $t2, check_y_P_E
    
    j no_P_E_collision

move_right:

    subu $sp, $sp, 12
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    
    lw $s0, x_P						# $s0 = x_P
    addi $s0, $s0, 1					# x += 1
    bge $s0, 6, game_over_cleanup
    
    lw $s1, y_P 					# $s1 = current y_P
    
    move $a0, $s0 					# $a0 = new x_P
    move $a1, $s1 					# $a1 = current y_P
    jal check_collision

    beqz $v0, game_over_cleanup
    
    sw $s0, x_P
    
    lw $t0, x_P
    lw $t1, y_P 
    lw $t2, x_E
    lw $t3, y_E

    beq $t0, $t2, check_y_P_E
    
    j no_P_E_collision

check_y_P_E:

    beq $t1, $t3, game_over_cleanup

no_P_E_collision:

    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    addiu $sp, $sp, 12

    jal check_R
    jal move_E

    j game_loop

game_over_cleanup: 					# edge case: fail path -> GAME OVER

    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    addiu $sp, $sp, 12
    
    j game_over

#======================================================================================#
# print map + P + E section     

print_game:

    lb $t1, 0($a0)					# load map char
    beqz $t1, print_end					# end = "\0"
    
    # current pos offset
    la $t4, map
    sub $t5, $a0, $t4

    # check if current pos == P
    lw $t6, y_P
    lw $t7, x_P
    li $t8, 8
    mul $t6, $t6, $t8        				# y_P *= 8
    add $t6, $t6, $t7					# y_P += x_P
    beq $t5, $t6, print_P

    # check if current pos == E
    lw $t0, y_E
    lw $t2, x_E
    mul $t0, $t0, $t8        				# y_E *= 8
    add $t0, $t0, $t2					# y_E += x_E
    beq $t5, $t0, print_E

    sb $t1, 0($t3)           				# print map char
    addi $a0, $a0, 1
    
    j print_game

print_P:

    li $t1, 'P'						# load char "P"
    sb $t1, 0($t3)					# store char at MMIO address
    addi $a0, $a0, 1					# next char
    
    j print_game

print_E:

    li $t1, 'E'						# load char "E"
    sb $t1, 0($t3)					# store char at MMIO address
    addi $a0, $a0, 1					# next char
    
    j print_game

print_end:

    jr $ra


#==================================================================================#
# collision with walls check section

check_collision:

    # inputs -> $a0 = x, $a1 = y
    la $t6, map
    li $t7, 8
    mul $t8, $a1, $t7    				# $t8 = y * 8
    add $t8, $t8, $a0    				# $t8 += x
    add $t9, $t6, $t8					# map address
    lb $t9, 0($t9)
    li $v0, 1
    beq $t9, 35, impossible  				# wall check
    
    jr $ra

impossible:

    li $v0, 0						# 0 = impossible
    
    jr $ra

#==================================================================================================#
# R section

check_R:

    # check if P pos != R pos
    la $t6, map
    li $t7, 8						# bc row = 8
    lw $t4, y_P
    lw $t5, x_P
    
    # calculate map memory offset for P pos
    mul $t8, $t4, $t7					# $t8 (y offset) = y_P * 8
    add $t8, $t8, $t5					# $t8 += x
    add $t9, $t6, $t8					# $t9 (absolute address) = map + offset
    
    # check map at P pos
    lb $t0, 0($t9)
    bne $t0, 82, no_R					# if != R: go to no R

    # update score
    lw $t1, score
    addi $t1, $t1, 5
    sw $t1, score
    
    # check win condition
    li $t3, 100
    bge $t1, $t3, game_over 				# if score >= 100: GAME OVER

    # remove R from map
    li $t2, 32
    sb $t2, 0($t9)

generate_new_R:

    addiu $sp, $sp, -12
    sw $ra, 0($sp)					# ra
    sw $s0, 4($sp)					# $s0 = x
    sw $s1, 8($sp)					# $s1 = y

generate_new_loop:

    # rand y(1-5)
    li $a1, 5
    li $v0, 42
    syscall
    addi $s1, $a0, 1  					# $s1 = y (converted to 1-based)

    # rand x(1-5)
    li $a1, 5
    li $v0, 42
    syscall
    addi $s0, $a0, 1  					# $s0 = x (converted to 1-based)

    # walls check
    move $a0, $s0
    move $a1, $s1
    jal check_collision
    beqz $v0, generate_new_loop  			# if wall: regenerate

    # E position check
    lw $t0, x_E
    lw $t1, y_E
    beq $s0, $t0, check_y_E
    
    j check_prev_R

check_y_E:

    beq $s1, $t1, generate_new_loop  			# if E: regenerate

check_prev_R:

    lw $t2, prev_x_R
    lw $t3, prev_y_R
    beq $s0, $t2, check_prev_y_R
    
    j check_P

check_prev_y_R:

    beq $s1, $t3, generate_new_loop  			# if prev R: regenerate

check_P:

    lw $t4, x_P
    lw $t5, y_P
    beq $s0, $t4, check_y_P
    
    j valid_position

check_y_P:

    beq $s1, $t5, generate_new_loop  			# if P: regenerate

valid_position:

    # update R's position
    sw $s0, x_R
    sw $s1, y_R
    sw $s0, prev_x_R
    sw $s1, prev_y_R

    # place R on map at (x_R, y_R)
    la $t6, map
    li $t7, 8
    
    # calculate offset using row-major form (Eubank & Kupresanin, 2012)
    mul $t8, $s1, $t7					# $t8 (row offset) = y_R * 8
    add $t8, $t8, $s0					# $t8 += x_R 
    add $t9, $t6, $t8					# $t9 (absolute address) = map + $t8
    
    li $t0, 82  					# R
    sb $t0, 0($t9)					# store R at map address

    # restore registers
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    addiu $sp, $sp, 12
    
    jr $ra
    
no_R:

    jr $ra

#=================================================================================================#
# enemy movement logic section

move_E:
    
    subu $sp, $sp, 24       				# 6 saved
    sw $ra, 0($sp)					# ra
    sw $s0, 4($sp)					# x_P
    sw $s1, 8($sp)					# y_P
    sw $s2, 12($sp)					# x_E
    sw $s3, 16($sp)					# y_E
    sw $s4, 20($sp)					# random num

    # 70% random movement OR 30% chase
    li $a1, 10            				# range 0-9
    li $v0, 42           				# syscall 42 = random integer
    syscall
    move $s4, $a0        				# save random

    # load P + E pos
    lw $s0, x_P
    lw $s1, y_P
    lw $s2, x_E
    lw $s3, y_E

    blt $s4, 7, rand_move 				# if <7: do random

normal_move:
    
    sub $t0, $s0, $s2    				# delta_x = x_P - x_E
    sub $t1, $s1, $s3    				# delta_y = y_P - y_E
    
    # absolute values of delta x + y
    abs $t2, $t0
    abs $t3, $t1
    
    bge $t2, $t3, move_horizontal			# if x >= y
    
    j move_vertical					# else

move_horizontal:

    beqz $t0, move_vertical  				# if delta_x == 0: try vertical
    bltz $t0, move_E_left				# if P left
    bgtz $t0, move_E_right				# if P right

move_vertical:

    beqz $t1, move_E_end  				# if delta_y == 0: exit
    bltz $t1, move_E_up					# if P up
    bgtz $t1, move_E_down				# if P down

move_E_up:

    addi $s3, $s3, -1					# decrease y == up
    move $a0, $s2					# current x
    move $a1, $s3					# new y
    jal check_E_collision
    beqz $v0, move_vertical_failed
    sw $s3, y_E						# update y
    
    j check_P_collision

move_E_down:

    addi $s3, $s3, 1					# increase y == downm
    move $a0, $s2
    move $a1, $s3
    jal check_E_collision
    beqz $v0, move_vertical_failed
    sw $s3, y_E
    
    j check_P_collision

move_E_left:

    addi $s2, $s2, -1					# decrease x == left
    move $a0, $s2
    move $a1, $s3
    jal check_E_collision
    beqz $v0, move_horizontal_failed
    sw $s2, x_E
    
    j check_P_collision

move_E_right:

    addi $s2, $s2, 1					# increase x == right
    move $a0, $s2
    move $a1, $s3
    jal check_E_collision
    beqz $v0, move_horizontal_failed
    sw $s2, x_E
    
    j check_P_collision

move_horizontal_failed:

    j move_vertical

move_vertical_failed:

    j move_horizontal

#=====================================================================================================#
# random movement logic for E section

rand_move:

    # random move: 0 = up, 1 = down, 2 = left, 3 = right
    li $a1, 4            				# 0-3
    li $v0, 42						# rand
    syscall

    # 25% chance for each direction
    beq $a0, 0, rand_up					
    beq $a0, 1, rand_down
    beq $a0, 2, rand_left
    beq $a0, 3, rand_right

rand_up:

    addi $s3, $s3, -1					# y_E -= 1
    move $a0, $s2					# x_E -> $s2
    move $a1, $s3					# new y_E -> $s3
    jal check_E_collision
    beqz $v0, rand_impossible				# if $v0 == 0: impossible
    sw $s3, y_E						# else: update y_E
    
    j check_P_collision

rand_down:

    addi $s3, $s3, 1     
    move $a0, $s2
    move $a1, $s3
    jal check_E_collision
    beqz $v0, rand_impossible
    sw $s3, y_E
    
    j check_P_collision

rand_left:

    addi $s2, $s2, -1
    move $a0, $s2
    move $a1, $s3
    jal check_E_collision
    beqz $v0, rand_impossible
    sw $s2, x_E
    
    j check_P_collision

rand_right:

    addi $s2, $s2, 1
    move $a0, $s2
    move $a1, $s3
    jal check_E_collision
    beqz $v0, rand_impossible
    sw $s2, x_E
    
    j check_P_collision

rand_impossible:

    j normal_move

move_E_end:

    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    lw $s4, 20($sp)
    addiu $sp, $sp, 24
    
    jr $ra

#===============================================================================================#
# enemy collision section

check_E_collision:

    # $a0 = x, $a1 = y
    la $t4, map
    li $t5, 8
    mul $t6, $a1, $t5    				# $t6 = y * 8
    add $t6, $t6, $a0    				# $t6 = $t6 + x
    add $t7, $t4, $t6					# calculate map address
    lb $t8, 0($t7)
    li $v0, 1
    beq $t8, 35, impossible_move  			# #
    beq $t8, 82, impossible_move  			# R
    
    jr $ra

impossible_move:

    li $v0, 0
    jr $ra

check_P_collision:

    lw $t0, x_P
    lw $t1, y_P
    lw $t2, x_E
    lw $t3, y_E
    beq $t0, $t2, check_y
    
    j move_E_end

check_y:

    beq $t1, $t3, game_over
    
    j move_E_end

#===========================================================================================#
# print directives section

print_directives:

    la $a0, directives    				# load directives string
    li $t9, 0xFFFF000C					# display MMIO
    
print_directives_loop:

    lb $t1, 0($a0)          				# load char
    beqz $t1, print_directives_exit
    sb $t1, 0($t9)          				# print char
    addi $a0, $a0, 1        				# next char
    
    j print_directives_loop
    
print_directives_exit:

    jr $ra
    
#===================================================================================#
# GAME OVER section

game_over:

    # clear screen
    li $t9, 0xFFFF000C
    li $t1, 12						# 12 = clear screen
    sb $t1, 0($t9)

    # GAME OVER
    la $a0, game_over_string
    li $t9, 0xFFFF000C

#========================================================================================#
# print final score
    
print_game_over_message_loop:

    lb $t1, 0($a0)					# load char
    beqz $t1, print_final_score_string			# if char == "\0": exit
    sb $t1, 0($t9)					# display char
    addi $a0, $a0, 1					# next char address
    
    j print_game_over_message_loop

print_final_score_string:

    # "Your final score is "
    la $a0, final_score_string				# load string
    li $t9, 0xFFFF000C
    
print_score_string_loop:

    lb $t1, 0($a0)					# load char
    beqz $t1, convert_and_print_score			# if char == "\0": exit
    sb $t1, 0($t9)					# display char
    addi $a0, $a0, 1					# next char address
    
    j print_score_string_loop

convert_and_print_score:

    # convertion + print score
    lw $t2, score					# load score value
    li $t4, 10						# /10 -> decimal convertion
    li $t5, 0						# count
    
convert_score_to_ascii_loop:

    divu $t2, $t4					# score /= 10
    mfhi $t3						# reste = current digit
    mflo $t2						# quotient = remaining number
    addi $t3, $t3, 48					# -> ascii
    subu $sp, $sp, 4					# push digit to stack
    sb $t3, 0($sp)					# store ascii char on stack
    addi $t5, $t5, 1					# count += 1
    bnez $t2, convert_score_to_ascii_loop		# while quotient > 0: continue
    
    # edge case -> score=0
    bnez $t5, print_score_digits_loop  			# skip if digits already exist
    li $t3, 48                        			# ascii '0'
    addu $sp, $sp, 4
    sb $t3, 0($sp)
    addi $t5, $zero, 1                			# count = 1

print_score_digits_loop:

    lb $t3, 0($sp)					# load digit from stack
    addu $sp, $sp, 4					# stack pointer += 1
    li $t9, 0xFFFF000C
    sb $t3, 0($t9)					# display digit
    addi $t5, $t5, -1					# count -= 1
    bnez $t5, print_score_digits_loop			# while $t5 != 0: continue
    
    j exit

#================================================================================#
# finish game

exit:

    li $v0, 10 						# 10 -> program exit
    syscall
    
#==================================================================================#
# references

# [1] Columbia.edu. (2025). The US ASCII Character Set. [online] Available at: https://www.columbia.edu/kermit/ascii.html [Accessed 15 Mar. 2025].

# [2] Eubank, R.L. and Kupresanin, A. (2012). Statistical Computing in C++ and R. Boca Raton: CRC Press. [online] Available at: https://www.osti.gov/servlets/purl/1239231 [Accessed 15 Mar. 2025].
