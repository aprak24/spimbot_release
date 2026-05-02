### syscall constants
PRINT_STRING            = 4
PRINT_CHAR              = 11
PRINT_INT               = 1

### MMIO addrs
ANGLE                   = 0xffff0014
ANGLE_CONTROL           = 0xffff0018
VELOCITY                = 0xffff0010

REQUEST_PUZZLE          = 0xffff00d0
AVAIL_PUZZLES           = 0xffff00b4
SUBMIT_SOLUTION         = 0xffff00d4
CURRENT_PUZZLE          = 0xffff00b8

BOT_X                   = 0xffff0020
BOT_Y                   = 0xffff0024
OTHER_X                 = 0xffff00a0
OTHER_Y                 = 0xffff00a4

NUM_CARROTS             = 0xffff0040
NUM_BUNNIES_CARRIED     = 0xffff0050

SEARCH_BUNNIES          = 0xffff0054
CATCH_BUNNY             = 0xffff0058
PUT_BUNNIES_IN_PLAYPEN  = 0xffff005c

PLAYPEN_LOCATION        = 0xffff0044
LOCK_PLAYPEN			= 0xffff0048
UNLOCK_PLAYPEN			= 0xffff004c
PLAYPEN_OTHER_LOCATION	= 0xffff00dc

SCORES_REQUEST          = 0xffff1018

TIMER                   = 0xffff001c

BONK_INT_MASK           = 0x1000      ## Bonk
BONK_ACK                = 0xffff0060  ## Bonk
TIMER_INT_MASK          = 0x8000      ## Timer
TIMER_ACK               = 0xffff006c  ## Timer
REQUEST_PUZZLE_INT_MASK = 0x800       ## Puzzle
REQUEST_PUZZLE_ACK		= 0xffff00e4  ## Puzzle
BUNNY_MOVE_INT_MASK     = 0x400       ## Bunny Move
BUNNY_MOVE_ACK          = 0xffff00e8  ## Bunny Move
EX_CARRY_LIMIT_INT_MASK = 0x4000      ## Exceeding Carry Limit
EX_CARRY_LIMIT_ACK      = 0xffff002c  ## Exceeding Carry Limit
PLAYPEN_UNLOCK_INT_MASK = 0x2000      ## Playpen Unlock
PLAYPEN_UNLOCK_ACK      = 0xffff0028  ## Playpen Unlock

MMIO_STATUS             = 0xffff204c

.data

# If you want, you can use the following to detect if a bonk has happened.
has_bonked: .byte 0
.align 2 # to make sure that the next item starts at address div by 4 (may want to add this in other places)

## Allocated all data necessary
puzzle: .space 268
solution: .space 256
puzzle_received: .byte 0
bunny_moved: .byte 0
playpen_unlocked: .byte 0
.align 2
num_puzzles_requested: .word 0
.align 2
bunnies_info: .space 484

.text
main:
    # enable interrupts
    li      $t4     1
    or      $t4     $t4     TIMER_INT_MASK
    or      $t4,    $t4,    BONK_INT_MASK             # enable bonk interrupt
    or      $t4,    $t4,    REQUEST_PUZZLE_INT_MASK   # enable puzzle interrupt
    or      $t4,    $t4,    BUNNY_MOVE_INT_MASK 
    or      $t4,    $t4,    PLAYPEN_UNLOCK_INT_MASK
    or      $t4,    $t4,    1 # global enable
    mtc0    $t4     $12

    li $t1, 0
    sw $t1, ANGLE
    li $t1, 1
    sw $t1, ANGLE_CONTROL
    li $t2, 0
    sw $t2, VELOCITY

    # YOUR CODE GOES HERE!!!!!!
    sub $sp, $sp, 24
    sw $ra, 0($sp)
    sw $s0, 4($sp)          # puzzle_num
    sw $s1, 8($sp)          # flag
    sw $s2, 12($sp)         # iteration counter
    sw $s3, 16($sp)
    sw $s4, 20($sp)

    # int puzzle_num = request_puzzle();
    jal request_puzzle
    move $s0, $v0
    move $a0, $s0
    jal solve_puzzle

        # Part 1 Code
    
    # Initialize Flag
    li $s1, 0
    # Start Counter at 0
    li $s2, 0

# Check if there was an unlock pen interrupt, if there was go lock the playpen before catching a bunny
check_unlocked:
    addi $s2, $s2, 1
    # if counter is at 5, go and unlock the opponents playpen
    li $t0, 15
    blt $s2, $t0, skip_unlock_opponent

    # set unlock flag
    li $s1, 3
    # load opponent playpen location
    lw $t4, PLAYPEN_OTHER_LOCATION($0)
    srl $t2, $t4, 16
    andi $t3, $t4, 0xFFFF
    j while_x


skip_unlock_opponent:
    # Check interrupt true
    lb $t0, playpen_unlocked
    beq $t0, 0, puzzle_solver
    # Store playpen loc
    lw $t4, PLAYPEN_LOCATION($0)
    srl $t2, $t4, 16
    andi $t3, $t4, 0xFFFF

    # add a flag to tell our loop we are locking the playpen
    li $s1, 2
    # travel to playpen
    j while_x

lock_playpen:
    # when at playpen lock the playpen and drop off any potential bunnies we have
    sw $0, LOCK_PLAYPEN($0)
    sb $0, playpen_unlocked
    lw $t6, NUM_BUNNIES_CARRIED($0)
    sw $t6, PUT_BUNNIES_IN_PLAYPEN($0)
    li $s1, 0
    j puzzle_solver

unlock_playpen:
    sw $0, UNLOCK_PLAYPEN($0)
    li $s1, 0
    li $s2, 0
puzzle_solver:
# Check if we have carrots, if we don't acknowledge a puzzle interrupt and solve the puzzle
    lw $t0, NUM_CARROTS($0)
    li $t1, 1
    bgt $t0, $t1, catch_bunnies

    jal request_puzzle
    move $s0, $v0
    move $a0, $s0
    jal solve_puzzle


catch_bunnies:
    #### Load Address of bunnies_info memory into a register
    la $t0, bunnies_info
    #### Write address to SEARCH BUNNIES memory I/O
    sw $t0, SEARCH_BUNNIES($0)
    addi $t1, $t0, 4
    lb $t2, bunny_moved
    beq $t2, $0, find_good_bunny
    la $t0, bunnies_info
    #### Write address to SEARCH BUNNIES memory I/O
    sw $t0, SEARCH_BUNNIES($0)
    addi $t1, $t0, 4
    sb $0, bunny_moved
    # While the bunny at address t1 is going to hop within 100,000 cycles, add 16
find_good_bunny:
    lw $t2, 12($t1)         # Stores cycles until next hop
    li $t3, 100000
    bgt $t2, $t3, bunny_found
    addi $t1, $t1, 16
    j find_good_bunny
bunny_found:

    # Load bunny x-coord -> $t2
    # Load bunny y-coord -> $t3
    # Load bunny weight -> $t4
    lw $t2, 0($t1)
    lw $t3, 4($t1)

    # Move SPIMbot #
while_x:
    li $t4, 0
    sw $t4, ANGLE($0)
    li $t4, 1
    sw $t4, ANGLE_CONTROL($0)
    lw $t4, BOT_X($0)
    beq $t4, $t2, end_while_x

    # absolute distance
    sub $t5, $t4, $t2
    bge $t5, $0, endabs
    sub $t5, $0, $t5
endabs:
    li $t6, 10
    ble $t5, $t6, end_max_vel
    li $t5, 10
end_max_vel:
    bgt $t2, $t4, move_right
    
move_left:
    sub $t5, $0, $t5
    sw $t5, VELOCITY($0)
    j while_x
move_right:
    sw $t5, VELOCITY($0)
    j while_x
end_while_x:
    sw $0, VELOCITY($0)
    li $t4, 90
    sw $t4, ANGLE($0)
    li $t4, 1
    sw $t4, ANGLE_CONTROL($0)
while_y:
    lw $t4, BOT_Y($0)
    beq $t4, $t3, end_while_y
    # absolute distance
    sub $t5, $t4, $t3
    bge $t5, $0, endabs2
    sub $t5, $0, $t5
endabs2:
    li $t6, 10
    ble $t5, $t6, end_max_vel2
    li $t5, 10
end_max_vel2:
    bgt $t3, $t4, move_down
move_up:
    sub $t5, $0, $t5
    sw $t5, VELOCITY($0)
    j while_y
move_down:
    sw $t5, VELOCITY($0)
    j while_y
end_while_y:
    sw $0, VELOCITY($0)
    beq $s1, 1, drop_bunny
    beq $s1, 2, lock_playpen
    beq $s1, 3, unlock_playpen
    sw $0, CATCH_BUNNY($0)
    lw $t4, NUM_BUNNIES_CARRIED($0)
    li $t5, 3
    blt $t4, $t5, skip_drop
# Drop off Bunny at playpen
    # Playpen x-loc -> $t2
    # Playpen y-loc -> $t3
    lw $t4, PLAYPEN_LOCATION($0)
    srl $t2, $t4, 16
    andi $t3, $t4, 0xFFFF
    # Flag that we are dropping off a bunny
    li $s1, 1

    li $t4, 0
    sw $t4, ANGLE
    li $t4, 1
    sw $t4, ANGLE_CONTROL
    j while_x
drop_bunny:
    lw $t6, NUM_BUNNIES_CARRIED($0)
    sw $t6, PUT_BUNNIES_IN_PLAYPEN($0)
    li $s1, 0
skip_drop:
    addi $t1, $t1, 16
    j check_unlocked

# Once done, enter an infinite loop so that your bot can be graded by QtSpimbot once 10,000,000 cycles have elapsed
loop:
        j       loop

request_puzzle:
    sb $0, puzzle_received
    la $t3, puzzle
    sw $t3, REQUEST_PUZZLE($0)

    lw $v0, num_puzzles_requested
    lw $t3, num_puzzles_requested
    addi $t3, $t3, 1
    sw $t3, num_puzzles_requested
while:
    lb $t4, puzzle_received
    bne $t4, $0, endwhile
    j while
endwhile:
    jr $ra

solve_puzzle:
    sub $sp, $sp, 12
    sw $ra, 0($sp)
    sw $s0, 4($sp)          # a0
    sw $s1, 8($sp)          # got_sol
    move $s0, $a0
    # zero_board(puzzle.num_rows, puzzle.num_cols, &solution);
    la $t3, puzzle
    lw $a0, 0($t3)          #num_rows
    lw $a1, 4($t3)          #num_cols
    la $a2, solution
    jal zero_board

    # bool got_sol = solve(&puzzle, &solution, 0, 0);
    la $a0, puzzle
    la $a1, solution
    li $a2, 0
    li $a3, 0
    jal solve
    move $s1, $v0           # Store boolean

    sw $s0, CURRENT_PUZZLE($0)
    la $t3, solution
    sw $t3, SUBMIT_SOLUTION($0)

    # Check if Correct
    li $t3, 0
    lw $t4, MMIO_STATUS($0)
    beq $t4, $0, correct_done
    li $t3, 1
correct_done:
    and $v0, $s1, $t3

    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    add $sp, $sp, 12

    jr $ra

# ======================== kernel code ================================
.kdata
chunkIH:    .space 40
non_intrpt_str:    .asciiz "Non-interrupt exception\n"
unhandled_str:    .asciiz "Unhandled interrupt type\n"
.ktext 0x80000180
interrupt_handler:
.set noat
    move    $k1, $at        # Save $at
                            # NOTE: Don't touch $k1 or else you destroy $at!
.set at
    la      $k0, chunkIH
    sw      $a0, 0($k0)        # Get some free registers
    sw      $v0, 4($k0)        # by storing them to a global variable
    sw      $t0, 8($k0)
    sw      $t1, 12($k0)
    sw      $t2, 16($k0)
    sw      $t3, 20($k0)
    sw      $t4, 24($k0)
    sw      $t5, 28($k0)

    # Save coprocessor1 registers!
    # If you don't do this and you decide to use division or multiplication
    #   in your main code, and interrupt handler code, you get WEIRD bugs.
    mfhi    $t0
    sw      $t0, 32($k0)
    mflo    $t0
    sw      $t0, 36($k0)

    mfc0    $k0, $13                # Get Cause register
    srl     $a0, $k0, 2
    and     $a0, $a0, 0xf           # ExcCode field
    bne     $a0, 0, non_intrpt


interrupt_dispatch:                 # Interrupt:
    mfc0    $k0, $13                # Get Cause register, again
    beq     $k0, 0, done            # handled all outstanding interrupts

    and     $a0, $k0, BONK_INT_MASK     # is there a bonk interrupt?
    bne     $a0, 0, bonk_interrupt

    and     $a0, $k0, TIMER_INT_MASK    # is there a timer interrupt?
    bne     $a0, 0, timer_interrupt

    and     $a0 $k0 REQUEST_PUZZLE_INT_MASK
    bne     $a0 0 request_puzzle_interrupt

    and     $a0, $k0, BUNNY_MOVE_INT_MASK
    bne     $a0, 0, bunny_move_interrupt

    and     $a0, $k0, PLAYPEN_UNLOCK_INT_MASK
    bne     $a0, 0, playpen_unlock_interrupt

    li      $v0, PRINT_STRING       # Unhandled interrupt types
    la      $a0, unhandled_str
    syscall
    j       done

bonk_interrupt:
    sw      $0, BONK_ACK
    #Fill in your bonk handler code here
    j       interrupt_dispatch      # see if other interrupts are waiting

timer_interrupt:
    sw      $0, TIMER_ACK
    #Fill in your timer interrupt code here
    j       interrupt_dispatch      # see if other interrupts are waiting

request_puzzle_interrupt:
    sw      $0, REQUEST_PUZZLE_ACK
    #Fill in your request puzzle interrupt code here
    li      $t1, 1
    sb      $t1, puzzle_received
    j       interrupt_dispatch      # see if other interrupts are waiting

bunny_move_interrupt:
    sw      $0, BUNNY_MOVE_ACK
    li      $t1, 1
    sb      $t1, bunny_moved
    j       interrupt_dispatch

playpen_unlock_interrupt:
    sw      $0, PLAYPEN_UNLOCK_ACK
    li      $t1, 1
    sb      $t1, playpen_unlocked
    j       interrupt_dispatch

non_intrpt:                         # was some non-interrupt
    li      $v0, PRINT_STRING
    la      $a0, non_intrpt_str
    syscall                         # print out an error message
    # fall through to done

done:
    la      $k0, chunkIH

    # Restore coprocessor1 registers!
    # If you don't do this and you decide to use division or multiplication
    #   in your main code, and interrupt handler code, you get WEIRD bugs.
    lw      $t0, 32($k0)
    mthi    $t0
    lw      $t0, 36($k0)
    mtlo    $t0

    lw      $a0, 0($k0)             # Restore saved registers
    lw      $v0, 4($k0)
    lw      $t0, 8($k0)
    lw      $t1, 12($k0)
    lw      $t2, 16($k0)
    lw      $t3, 20($k0)
    lw      $t4, 24($k0)
    lw      $t5, 28($k0)

.set noat
    move    $at, $k1        # Restore $at
.set at
    eret

## Provided code from Labs 6 and 7  + is_solved
.text

zero_board:
    li      $t0, 0              # row = 0

row_loop:
    bge     $t0, $a0, zero_done      # if row >= num_rows, exit
    li      $t1, 0              # col = 0

col_loop:
    bge     $t1, $a1, next_row_zero  # if col >= num_cols, next row

    # Calculate index: row * num_cols + col
    mul     $t2, $t0, $a1       # t2 = row * num_cols
    add     $t2, $t2, $t1       # t2 = row * num_cols + col
    add     $t3, $a2, $t2       # t3 = &solution[row * num_cols + col]
    sb      $zero, 0($t3)       # solution[index] = 0

    addi    $t1, $t1, 1         # col++
    j       col_loop

next_row_zero:
    addi    $t0, $t0, 1         # row++
    j       row_loop

zero_done:
    jr      $ra

#########################################

board_done:
    li      $t0, 0

row_loop_board_done:
    bge     $t0, $a0, all_zero
    li      $t1, 0

col_loop_board_done:
    bge     $t1, $a1, next_row

    mul     $t2, $t0, $a1
    add     $t2, $t2, $t1
    add     $t3, $a2, $t2

    lbu     $t4, 0($t3)
    bne     $t4, $0, found_nonzero

    addi    $t1, $t1, 1
    j       col_loop_board_done

next_row:
    addi    $t0, $t0, 1
    j       row_loop_board_done

found_nonzero:
    li      $v0, 0
    jr      $ra

all_zero:
    li      $v0, 1
    jr      $ra

#########################################

toggle_light:
    # t0=num_rows, t1=num_cols, t2=num_colors
    lw      $t0, 0($a2)
    lw      $t1, 4($a2)
    lw      $t2, 8($a2)

    # t3 = &board[0]
    addi    $t3, $a2, 12

# addr = board_base + (row*num_cols + col)
# val = (lbu(addr) + action_num) % num_colors
# sb(val, addr)

    ######## center: (row, col)
    mul     $t4, $a0, $t1
    add     $t4, $t4, $a1
    add     $t5, $t3, $t4

    lbu     $t6, 0($t5)
    add     $t6, $t6, $a3
    rem     $t6, $t6, $t2
    sb      $t6, 0($t5)

    ######## if (row > 0) : up (row-1, col)
    slt     $t8, $zero, $a0          # t8 = (0 < row)
    beq     $t8, $zero, SKIP_UP

    addi    $t9, $a0, -1
    mul     $t4, $t9, $t1
    add     $t4, $t4, $a1
    add     $t5, $t3, $t4

    lbu     $t6, 0($t5)
    add     $t6, $t6, $a3
    rem     $t6, $t6, $t2
    sb      $t6, 0($t5)

SKIP_UP:
    ######## if (col > 0) : left (row, col-1)
    slt     $t8, $zero, $a1          # t8 = (0 < col)
    beq     $t8, $zero, SKIP_LEFT

    addi    $t9, $a1, -1
    mul     $t4, $a0, $t1
    add     $t4, $t4, $t9
    add     $t5, $t3, $t4

    lbu     $t6, 0($t5)
    add     $t6, $t6, $a3
    rem     $t6, $t6, $t2
    sb      $t6, 0($t5)
SKIP_LEFT:
    ######## if (row < num_rows - 1) : down (row+1, col)
    addi    $t9, $t0, -1             # t9 = num_rows - 1
    slt     $t8, $a0, $t9            # t8 = (row < num_rows-1)
    beq     $t8, $zero, SKIP_DOWN

    addi    $t9, $a0, 1
    mul     $t4, $t9, $t1
    add     $t4, $t4, $a1
    add     $t5, $t3, $t4

    lbu     $t6, 0($t5)
    add     $t6, $t6, $a3
    rem     $t6, $t6, $t2
    sb      $t6, 0($t5)
SKIP_DOWN:
    ######## if (col < num_cols - 1) : right (row, col+1)
    addi    $t9, $t1, -1             # t9 = num_cols - 1
    slt     $t8, $a1, $t9            # t8 = (col < num_cols-1)
    beq     $t8, $zero, DONE

    addi    $t9, $a1, 1
    mul     $t4, $a0, $t1
    add     $t4, $t4, $t9
    add     $t5, $t3, $t4

    lbu     $t6, 0($t5)
    add     $t6, $t6, $a3
    rem     $t6, $t6, $t2
    sb      $t6, 0($t5)

DONE:
    jr      $ra

#########################################

linearize:
    bne $a0 $0 not_base
    li $v0 0
    jr $ra

not_base:
    sub $sp $sp 4
    sw $ra 0($sp)
    li $t0 0

for:
    bge $t0 4 after_for
    mul $t3 $t0 4 # 4*i
    add $t3 $t3 4 # 4*i +4
    add $t2 $a0 $t3 #&node->data[i]
    lw $t4 0($t2)  # node->data[i]
    sw $t4 0($a1)  # *array = node->data[i];
    addi $a1 $a1 4 # array ++
    addi $t0 $t0 1 # i++

	j for

after_for:
    lw $a0 0($a0)
	jal linearize
	lw $ra 0($sp)
	add $sp $sp 4
	jr $ra

#########################################

solve:
# solve(LightsOuts* puzzle, unsigned char* solution, int row, int col)
# $a0 = puzzle, $a1 = solution, $a2 = row, $a3 = col
# Returns: $v0 = bool (0 or 1)

    # Save callee-saved registers
    sub     $sp, $sp, 36
    sw      $ra, 0($sp)
    sw      $s0, 4($sp)
    sw      $s1, 8($sp)
    sw      $s2, 12($sp)
    sw      $s3, 16($sp)
    sw      $s4, 20($sp)
    sw      $s5, 24($sp)
    sw      $s6, 28($sp)
    sw      $s7, 32($sp)

    # Save arguments to $s registers
    move    $s0, $a0        # $s0 = puzzle
    move    $s1, $a1        # $s1 = solution
    move    $s2, $a2        # $s2 = row
    move    $s3, $a3        # $s3 = col

    # Load struct fields
    lw      $s4, 0($s0)     # $s4 = num_rows = puzzle->num_rows
    lw      $s5, 4($s0)     # $s5 = num_cols = puzzle->num_cols
    lw      $s6, 8($s0)     # $s6 = num_colors = puzzle->num_colors

    # Calculate next_row = ((col == num_cols-1) ? row + 1 : row)
    sub     $t0, $s5, 1     # $t0 = num_cols - 1
    bne     $s3, $t0, solve_same_row
    add     $s7, $s2, 1     # next_row = row + 1
    j       solve_check_bounds
solve_same_row:
    move    $s7, $s2        # next_row = row

solve_check_bounds:
    # if (row >= num_rows || col >= num_cols)
    bge     $s2, $s4, solve_call_board_done
    bge     $s3, $s5, solve_call_board_done
    j       solve_check_row

solve_call_board_done:
    # return board_done(num_rows, num_cols, puzzle->board)
    move    $a0, $s4        # num_rows
    move    $a1, $s5        # num_cols
    add     $a2, $s0, 12    # puzzle->board (offset 12)
    jal     board_done
    j       solve_return

solve_check_row:
    # if (row != 0)
    beq     $s2, $0, solve_first_row

    # Row != 0 case
    # int actions = (num_colors - puzzle->board[(row-1)*num_cols + col]) % num_colors
    sub     $t0, $s2, 1     # row - 1
    mul     $t0, $t0, $s5   # (row-1) * num_cols
    add     $t0, $t0, $s3   # (row-1)*num_cols + col
    add     $t1, $s0, 12    # puzzle->board
    add     $t1, $t1, $t0   # &puzzle->board[(row-1)*num_cols + col]
    lbu     $t2, 0($t1)     # puzzle->board[(row-1)*num_cols + col]
    sub     $t3, $s6, $t2   # num_colors - board[...]
    rem     $t3, $t3, $s6   # actions = ... % num_colors

    # Store actions in stack for later use
    sub     $sp, $sp, 4
    sw      $t3, 0($sp)     # save actions

    # solution[row*num_cols + col] = actions
    mul     $t0, $s2, $s5   # row * num_cols
    add     $t0, $t0, $s3   # row*num_cols + col
    add     $t1, $s1, $t0   # &solution[row*num_cols + col]
    sb      $t3, 0($t1)

    # toggle_light(row, col, puzzle, actions)
    move    $a0, $s2
    move    $a1, $s3
    move    $a2, $s0
    move    $a3, $t3
    jal     toggle_light

    # Prepare recursive call: solve(puzzle, solution, next_row, (col+1) % num_cols)
    add     $t0, $s3, 1     # col + 1
    rem     $t0, $t0, $s5   # (col + 1) % num_cols
    move    $a0, $s0
    move    $a1, $s1
    move    $a2, $s7
    move    $a3, $t0
    jal     solve

    # if (solve(...)) return true
    bne     $v0, $0, solve_row_return_true

    # solution[row*num_cols + col] = 0
    mul     $t0, $s2, $s5
    add     $t0, $t0, $s3
    add     $t1, $s1, $t0
    sb      $0, 0($t1)

    # Restore actions from stack
    lw      $t3, 0($sp)

    # toggle_light(row, col, puzzle, num_colors - actions)
    sub     $t4, $s6, $t3   # num_colors - actions
    move    $a0, $s2
    move    $a1, $s3
    move    $a2, $s0
    move    $a3, $t4
    jal     toggle_light

    # Clean up stack and return false
    add     $sp, $sp, 4
    li      $v0, 0
    j       solve_return

solve_row_return_true:
    add     $sp, $sp, 4     # clean up actions from stack
    li      $v0, 1
    j       solve_return

solve_first_row:
    # for(char actions = 0; actions < num_colors; actions++)
    li      $t6, 0          # actions = 0

    # Save actions counter in stack
    sub     $sp, $sp, 4

solve_loop:
    bge     $t6, $s6, solve_loop_end

    # Save actions to stack
    sw      $t6, 0($sp)

    # solution[row*num_cols + col] = actions
    mul     $t0, $s2, $s5   # row * num_cols
    add     $t0, $t0, $s3   # row*num_cols + col
    add     $t1, $s1, $t0   # &solution[row*num_cols + col]
    sb      $t6, 0($t1)

    # toggle_light(row, col, puzzle, actions)
    move    $a0, $s2
    move    $a1, $s3
    move    $a2, $s0
    move    $a3, $t6
    jal     toggle_light

    # Prepare recursive call: solve(puzzle, solution, next_row, (col+1) % num_cols)
    add     $t0, $s3, 1     # col + 1
    rem     $t0, $t0, $s5   # (col + 1) % num_cols
    move    $a0, $s0
    move    $a1, $s1
    move    $a2, $s7
    move    $a3, $t0
    jal     solve

    # if (solve(...)) return true
    bne     $v0, $0, solve_loop_return_true

    # Restore actions from stack
    lw      $t6, 0($sp)

    # toggle_light(row, col, puzzle, num_colors - actions)
    sub     $t4, $s6, $t6   # num_colors - actions
    move    $a0, $s2
    move    $a1, $s3
    move    $a2, $s0
    move    $a3, $t4
    jal     toggle_light

    # solution[row*num_cols + col] = 0
    mul     $t0, $s2, $s5
    add     $t0, $t0, $s3
    add     $t1, $s1, $t0
    sb      $0, 0($t1)

    # Restore actions and increment
    lw      $t6, 0($sp)
    add     $t6, $t6, 1
    j       solve_loop

solve_loop_return_true:
    add     $sp, $sp, 4     # clean up actions from stack
    li      $v0, 1
    j       solve_return

solve_loop_end:
    add     $sp, $sp, 4     # clean up actions from stack
    li      $v0, 0

solve_return:
    # Restore callee-saved registers
    lw      $ra, 0($sp)
    lw      $s0, 4($sp)
    lw      $s1, 8($sp)
    lw      $s2, 12($sp)
    lw      $s3, 16($sp)
    lw      $s4, 20($sp)
    lw      $s5, 24($sp)
    lw      $s6, 28($sp)
    lw      $s7, 32($sp)
    add     $sp, $sp, 36
    jr      $ra
