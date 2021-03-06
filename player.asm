;*****************************************
;	Scroll functions 
;*****************************************
	$MAXIMUM
	module player

;  ---------------------------------
;	EXTERNAL LOOK UP
;  ---------------------------------
	extern medium player_mode ;if player is on ground, in air, etc (byte)
	extern medium player_frame ;byte
	extern medium player_timer ;keeps track of # of frames between animation frames (byte)
;  ---------------------------------
;   EXTERNAL DEFINITION
;  ---------------------------------
	public player_init
	public player_move
	public get_sensor

;  ---------------------------------
;	INCLUDE
;  ---------------------------------
	$include "k1head.inc"
	$include "system.inc"
	$include "graphics.inc"
	$include "glbwork.inc"
	$include "scroll.inc"
	
SPRITE_X equ 72
SPRITE_Y equ 80
PLAYER_WIDTH equ 16
PLAYER_HEIGHT equ 16
TSENSOR_HEIGHT equ 4
BSENSOR_HEIGHT equ 12
PLAYER_ACCEL equ 0x8000
MAX_SPEED equ 0x38000
MODE_GROUND equ 0
MODE_AIR equ 1

GRAVITY equ 0xa000
JUMP_GRAVITY equ 0x7000
MAX_GRAVITY equ 0x70000

STAND_FRAME equ 0
START_WALK_FRAME equ 1
END_WALK_FRAME equ 7
JUMP_FRAME equ 7
WALK_TIMER equ 3

;-------------------------------------------------------
PROG section code large
;-------------------------------------------------------
	
;-------------------------------------------------------
; player_init: initialize player sprite
;-------------------------------------------------------	
player_init:
	ldw wa,0
	ldb (player_mode),a	
	ldw qwa,SPRITE_X
	ldl (player_x),xwa
	
	ldw qwa,SPRITE_Y
	ldl (player_y),xwa
	
	;---copy guy sprite---
	lda xiy,guy
	lda xix,CHR_VRAM+tiles_end-tiles+hills_end-hills
	ldl xbc,16*4 ;16 rows * 4 bytes per row
	ldir (xix+),(xiy+)
	;---copy guy palette---
	lda xiy,guy_pal
	lda xix,SPRITE_CRAM
	ldl xbc,guy_pal_end-guy_pal ;should be a ldw but needs to be an ldl
guy_pal_copy:                   ;to appease the assembler
	ldw wa,(xiy+)
	ldw (xix+),wa
	djnz bc,guy_pal_copy

	;upper left
	ldb (sprite_mirror),304 & 0xff ;first byte of tile number
	ldb (sprite_mirror+1),0y00011001 ;attributes and tile # upper bit
	ldb (sprite_mirror+2),SPRITE_X ;x position
	ldb (sprite_mirror+3),SPRITE_Y ;y position
	ldb (SPR_PALCODE),0 ;palette number
	;upper right
	ldb (sprite_mirror+4),305 & 0xff
	ldb (sprite_mirror+5),0y00011111 ;turn on h/v chain
	ldb (sprite_mirror+6),8 ;offset 8 px from prev sprite on x axis
	ldb (sprite_mirror+7),0
	ldb (SPR_PALCODE+1),0
	;lower left
	ldb (sprite_mirror+8),306 & 0xff
	ldb (sprite_mirror+9),0y00011111 ;turn on h/v chain
	ldb (sprite_mirror+10),248 ;offset -8 px from prev sprite on x axis
	ldb (sprite_mirror+11),8 ;offset 8 px on y axis
	ldb (SPR_PALCODE+2),0		
	;lower right
	ldb (sprite_mirror+12),307 & 0xff
	ldb (sprite_mirror+13),0y00011111 ;turn on h/v chain
	ldb (sprite_mirror+14),8 ;offset 8 px from prev sprite on x axis
	ldb (sprite_mirror+15),0 ;offset 0 px on y axis
	ldb (SPR_PALCODE+3),0
	ret

;-------------------------------------------------------
; player_move: handle player movement
;-------------------------------------------------------
player_move:
	;---horizontal movement---
	ldb a,(joypad)
	ldl xbc,(player_dx)
	bit BIT_LEFT,a
	j z,not_left
	cpl xbc,-MAX_SPEED
	j mi,not_left
	subl xbc,PLAYER_ACCEL
not_left:
	bit BIT_RIGHT,a
	j z,not_right
	cpl xbc,MAX_SPEED
	j pl,not_right
	addl xbc,PLAYER_ACCEL
not_right:
	;if we're not pressing left or right, decelerate
	ldb a,(joypad)
	andb a,JOY_LEFT | JOY_RIGHT
	j nz,no_decel
	cpl xbc,0
	j z,no_decel ;if player_dx is 0, don't have to decelerate
	j pl,decel_right
	j mi,decel_left
decel_right:
	subl xbc,PLAYER_ACCEL
	;if value goes under 0, make it 0
	cpl xbc,0
	j pl,no_decel
	ldl xbc,0
	j no_decel
decel_left:
	addl xbc,PLAYER_ACCEL
	;if value goes over 0, make it 0
	cpl xbc,0
	j mi,no_decel
	ldl xbc,0
no_decel:	
	ldl xwa,(player_x)
	ldl (player_dx),xbc
	addl xwa,xbc
	ldl (player_x),xwa
	
	;---horizontal collision detection---
	;top left
	ldw wa,(player_x+2)
	ldw bc,(player_y+2)
	addw bc,TSENSOR_HEIGHT
	cal get_height
	cpb a,16
	j z,hcollision_left
	;bottom left
	ldw wa,(player_x+2)
	ldw bc,(player_y+2)
	addw bc,BSENSOR_HEIGHT
	cal get_height
	cpb a,16
	j z,hcollision_left
	;top right
	ldw wa,(player_x+2)
	addw wa,PLAYER_WIDTH-1
	ldw bc,(player_y+2)
	addw bc,TSENSOR_HEIGHT
	cal get_height
	cpb a,16
	j z,hcollision_right
	;bottom right
	ldw wa,(player_x+2)
	addw wa,PLAYER_WIDTH-1
	ldw bc,(player_y+2)
	addw bc,BSENSOR_HEIGHT
	cal get_height
	cpb a,16
	j z,hcollision_right
	j done_hcollision
hcollision_left:
	;reset dx and subpixel position
	ldl xwa,0
	ldl (player_dx),xwa
	ldl xwa,(player_x)
	andl xwa,0xfff80000 ;reset to start of tile you're colliding with
	addl xwa,0x80000 ;eject into next tile
	ldl (player_x),xwa
	j done_hcollision
hcollision_right:
	;reset dx and subpixel position
	ldl xwa,0
	ldl (player_dx),xwa
	ldl xwa,(player_x)
	andl xwa,0xfff80000 ;reset to start of tile you're colliding with
	ldw wa,0xffff ;subpixel portion- almost into next tile
	ldl (player_x),xwa
done_hcollision:

	;---jumping and falling---
	; ldb a,(joyedge)
	bit BIT_B,(joyedge)
	j z,not_start_jump
	ldb a,(player_mode)
	cpb a,MODE_AIR ;don't start jumping if you press the button in air
	j z,not_start_jump
	ldl xwa,-0x80000
	ldl (player_dy),xwa
	ldb (player_mode),MODE_AIR
not_start_jump:
	;gravity
	ldb a,(player_mode)
	cpb a,MODE_AIR
	j nz,done_air
	ldl xwa,(player_dy)
	cpl xwa,MAX_GRAVITY
	j pl,done_add_gravity
	;if holding down the jump button, jump higher
	bit BIT_B,(joypad)
	j z,normal_add_gravity
	cpl xwa,0 ;don't use low gravity when falling
	j pl,normal_add_gravity
	addl xwa,JUMP_GRAVITY
	j done_add_gravity
normal_add_gravity:	
	addl xwa,GRAVITY
done_add_gravity:	
	ldl (player_dy),xwa
	ldl xbc,(player_y)
	addl xbc,xwa
	ldl (player_y),xbc
done_air:
	
	;---vertical collision detection---
	cpl xwa,0
	j pl,floor_collision
	j z,floor_collision
ceiling_collision:
	;top left
	ldw wa,(player_x+2)
	ldw bc,(player_y+2)
	cal get_height
	andb a,a
	j nz,ceil_rebound
	;top right
	ldw wa,(player_x+2)
	addw wa,PLAYER_WIDTH-1
	ldw bc,(player_y+2)
	cal get_height
	andb a,a
	j z,done_vcollision
ceil_rebound:
	ldl xwa,0
	ldl (player_dy),xwa
	ldl xwa,(player_y)
	andl xwa,0xfff00000 ;top of tile you're in
	addw qwa,0x10 ;move to bottom
	ldl (player_y),xwa
	j done_vcollision

floor_collision:	
	;left foot
	ldw wa,(player_x+2)
	; addw wa,4
	ldw bc,(player_y+2)
	addw bc,PLAYER_HEIGHT
	cal get_sensor
	pushb a
	;right foot
	ldw wa,(player_x+2)
	addw wa,PLAYER_WIDTH-1
	ldw bc,(player_y+2)
	addw bc,PLAYER_HEIGHT
	cal get_sensor ;right sensor height in a
	popb b ;left sensor height in b
	cpb b,a
	j mi,left_higher
	ldb a,b
left_higher:
	cpb a,0xf0 ;value returned if no floor found
	j nz,on_ground
	ldb (player_mode),MODE_AIR
	j done_vcollision
on_ground:
	ldw bc,(player_y+2)
	ldw de,bc ;player_y in de for later "if in air" comparison
	addw bc,PLAYER_HEIGHT ;foot pos in bc
	andw bc,0xfff0 ;place feet at bottom of block
	addw bc,16
	extsw wa
	subw bc,wa
	subw bc,PLAYER_HEIGHT ;foot pos to regular pos
	cpb (player_mode),MODE_AIR
	j nz,normal_ground
	;when in air, compare original and transformed y positions. if original moves character
	;0 or more pixels upwards, then do it. otherwise don't mess with y position
	cpw de,bc
	j mi,done_vcollision
	ldb (player_mode),MODE_GROUND
normal_ground:	
	ldw (player_y+2),bc
	j done_vcollision
	
	
done_vcollision:
	
	ldw wa,(player_x+2) ;move pixel portion of x coord into wa
	subw wa,SPRITE_X
	j pl,right_checkx
	;when scroll pos is less than 0, set scroll pos to 0 and instead move sprite
	ldb a,(player_x+2)
	ldb (sprite_mirror+2),a
	ldw wa,0
	j done_sprx
right_checkx:
	cpw wa,512-160 ;map is 64x64 8x8 tiles, ngpc is 160x152
	j mi,normal_x
	ldw wa,(player_x+2)
	subw wa,512-160
	ldb (sprite_mirror+2),a
	ldw wa,512-160
	j done_sprx
normal_x:	
	ldb (sprite_mirror+2),SPRITE_X
done_sprx:	
	ldw bc,(player_y+2)
	subw bc,SPRITE_Y
	j pl,down_checky
	ldb c,(player_y+2)
	ldb (sprite_mirror+3),c
	ldw bc,0
	j done_spry
down_checky:
	cpw bc,512-152 ;map is 64x64 8x8 tiles, ngpc is 160x152
	j mi,normal_y
	ldw bc,(player_y+2)
	subw bc,512-152
	ldb (sprite_mirror+3),c
	ldw bc,512-152
	j done_spry
normal_y:
	ldb (sprite_mirror+3),SPRITE_Y
done_spry:
	cal scroll_set
	
	;---set player's animation frame---
	ldb a,(player_mode)
	cpb a,MODE_AIR
	j ne,no_air_frame
	ldb (player_frame),JUMP_FRAME
	ldw (player_timer),0
	j done_set_frame
no_air_frame:

	ldw wa,(player_dx+2)
	andw wa,wa
	j ne,no_stand_frame
	ldb (player_frame),STAND_FRAME
	ldb (player_timer),0
	j done_set_frame
no_stand_frame:

	ldb a,(player_timer)
	andb a,a
	j eq,change_frame
	dec 1,a
	ldb (player_timer),a
	j done_set_frame
change_frame:
	ldb (player_timer),WALK_TIMER
	ldb a,(player_frame)
	inc 1,a
	ldb (player_frame),a
	cpb a,END_WALK_FRAME
	j c,done_set_frame
	ldb (player_frame),START_WALK_FRAME
done_set_frame:
	
	;set up sprite mirroring
	ldl xwa,(player_dx)
	cpl xwa,0
	j eq,done_mirror ;keep facing the direction you were
	j pl,moving_right
moving_left:
	;set tile numbers
	ldb (sprite_mirror),305 & 0xff ;first byte of tile number
	ldb (sprite_mirror+4),304 & 0xff ;first byte of tile number
	ldb (sprite_mirror+8),307 & 0xff ;first byte of tile number
	ldb (sprite_mirror+12),306 & 0xff ;first byte of tile number
	;set mirror bit
	orb (sprite_mirror+1),0x80
	orb (sprite_mirror+5),0x80
	orb (sprite_mirror+9),0x80
	orb (sprite_mirror+13),0x80
	j done_mirror
moving_right:
	;set tile numbers
	ldb (sprite_mirror),304 & 0xff ;first byte of tile number
	ldb (sprite_mirror+4),305 & 0xff ;first byte of tile number
	ldb (sprite_mirror+8),306 & 0xff ;first byte of tile number
	ldb (sprite_mirror+12),307 & 0xff ;first byte of tile number
	;clear mirror bit
	andb (sprite_mirror+1),0x7f
	andb (sprite_mirror+5),0x7f
	andb (sprite_mirror+9),0x7f
	andb (sprite_mirror+13),0x7f
done_mirror:	
	ret

;-------------------------------------------------------
; get_sensor: returns # of pixels needed to change height by
;-------------------------------------------------------
; wa: pixel x
; bc: pixel y
;-------------------------------------------------------
get_sensor:
	ldw qde,wa ;stash original values
	ldw qhl,bc
	cal get_height
	andb a,a
	j z,check_below ;if height is 0, check below block
	cpb a,16
	j z,check_above ;if height is 16, check above block
	j get_sensor_end ;otherwise just return
check_below:
	ldw wa,qde
	ldw bc,qhl
	addw bc,16 ;below tile
	cal get_height
	subb a,16 ;have to subtract 16 to counter the 16 we added
	j get_sensor_end
check_above:
	ldw wa,qde
	ldw bc,qhl
	subw bc,16 ;above tile
	cal get_height
	addb a,16 ;have to add 16 to counter the 16 we subtracted

get_sensor_end:
	ret

;-------------------------------------------------------
; get_height: returns height of given pixel in a
;-------------------------------------------------------
; wa: pixel x
; bc: pixel y
;-------------------------------------------------------	
get_height:
	ldb d,a
	andb d,0xf ;d has x position within tile
	cal scroll_get_tile
	ldw hl,wa
	andw hl,0x8000 ;isolate horizontal mirror bit
	j z,no_mirror
	ldb e,d ;if tile is mirrored, array index = 15 - array index
	ldb d,15
	subb d,e
no_mirror:
	;my bg tile image is 128 pixels wide so taking off that bit and shiftng
	;left 1 allows me to convert from 8x8 to 16x16
	andw wa,0x1ef
	srlw 1,wa
	lda xbc,block_types
	addw bc,wa
	ldl xwa,0
	ldb a,(xbc)
	slaw 4,wa ;each array entry is 16 bits
	addb a,d
	lda xbc,block_arrs
	addl xbc,xwa
	ldb a,(xbc)
	ret
	
;TODO refactor into separate source
block_arrs:
;empty block
TYPE_EMPTY equ 0
HeightEmpty:
	db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	
;full block
TYPE_FULL equ 1
HeightFull:
	db 16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16
	
;45 degree
TYPE_45 equ 2
Height45:
	db 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
	
;22.5 degree part 1
TYPE_2251 equ 3
Height2251:
	db 0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7
	
;22.5 degree part 2
TYPE_2252 equ 4
Height2252:
	db 8,8,9,9,10,10,11,11,12,12,13,13,14,14,15,15
	
;what angle each 16x16 block is
block_types:
	db TYPE_EMPTY,TYPE_FULL,TYPE_45,TYPE_2251,TYPE_2252,TYPE_FULL,TYPE_FULL,TYPE_FULL
	db TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL
	db TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL
	db TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL
	db TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL
	db TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL
	db TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL
	db TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL,TYPE_FULL
	
;-------------------------------------------------------
	end
;-------------------------------------------------------