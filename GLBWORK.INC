;================================================================
; global vars
;================================================================

	extern medium start_work
	extern medium stopper ; keeps main loop spinning until vblank (byte)
	extern medium joypad ;joypad bitmask (byte)
	extern medium joylast ;last frame's joypad bitmask (byte)
	extern medium joyedge ;what buttons were pressed this frame (byte)
	extern medium hint_cnt ;how many times horizontal interrupt has fired (byte)
	extern medium frame_cnt ; counts number of frames (word)
	extern medium sprite_mirror ;mirror of sprite memory (256 bytes)
	
	extern medium scroll_x ;scroll x pos (word)
	extern medium scroll_y ;scroll y pos (word)
	
	extern medium player_x ;player x pos (long)
	extern medium player_y ;player y pos (long)
	extern medium player_dx ;long
	extern medium player_dy ;long
;================================================================

