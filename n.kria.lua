-- n.Kria                        :-)
-- v0.2 @zbs @sixolet
--
-- native norns kria
-- original design by @tehn
--
--     \/ controls below \/
-- [[-----------------------------]]
-- k1: shift key
-- k2: reset all tracks
-- k1+k2: time config (legacy)
-- k3: play/stop
-- k1+k3: options (legacy)
--
-- e1: bpm
-- e1+k1: swing
-- e2: stretch
-- e3: push
--
-- hold a track/page and...
-- - k2: copy
-- - k3: paste
-- - k2+k3: cut
-- [[-----------------------------]]


--[[
WHAT GOES IN THIS FILE:
- includes
- all coroutines
- basic functions

]]--

globals = include('lib/globals')
screen_graphics = include('lib/screen_graphics')
grid_graphics = include('lib/grid_graphics')
Prms = include('lib/prms')
Onboard = include('lib/onboard')
gkeys = include('lib/gkeys')
meta = include('lib/meta')
data = include('lib/data_functions')
transport = include('lib/transport')
hs = include('lib/dualdelay')
nb = include("lib/nb/lib/nb")
mu = require 'musicutil'

-- hardware
g = grid.connect()
m = midi.connect()

-- matrix
local status, matrix = pcall(require, 'matrix/lib/matrix')
if not status then matrix = nil end

function init()
	globals:add()
	nb.voice_count = 4
	nb:init()
	Prms:add()
	hs.init()
	data.pattern = ap()
	track_clipboard = meta:get_track_copy(0)
	page_clipboards = meta:get_track_copy(0)
	add_modulation_sources()
	init_kbuf()
	init_value_buffer()
	coros.visual_ticker = clock.run(visual_ticker)
	coros.step_ticker = clock.run(step_ticker)
	coros.intro = clock.run(intro)
	last_touched_track = at()
	last_touched_page = get_page_name()
	print('n.kria launched successfully')
end


-- basic functions
function init_value_buffer()
	for t=1,NUM_TRACKS do
		table.insert(value_buffer,{})
		for k,v in pairs(pages_with_steps) do
			--print('adding',v,'to value buffer')
			value_buffer[t][v] = 0
		end
	end
end

function init_kbuf()
	for x=1,16 do
		table.insert(kbuf,{})
		for y=1,8 do kbuf[x][y] = false end
	end
end

function intro()
	post('n.Kria')
	clock.sleep(0.1)
	params:bang()
	clock.sleep(2)
	post('by @zbs')
	clock.sleep(2)
	post('based on kria by @tehn')
	clock.sleep(2)
	post('see splash for controls')
end

function pattern_longpress_clock(x)
	clock.sleep(0.5)
	if kbuf[x][1] then
		meta:save_pattern_into_slot(x)
		just_saved_pattern = true
	end
end

function menu_clock(n)
	blink.menu[n] = true
	clock.sleep(1/4)
	blink.menu[n] = false
end

function key(n,d) Onboard:key(n,d) end
function enc(n,d) Onboard:enc(n,d) end
function g.key(x,y,z) gkeys:key(x,y,z) end

function clock.transport.start() params:set('playing',1); post('play') end
function clock.transport.stop() params:set('playing',0); post('stop') end

function post(str) post_buffer = str end

function add_modulation_sources()
	if matrix == nil then return end
	for i=1,NUM_TRACKS do
		-- The final pitch
		matrix:add_bipolar("pitch_t"..i, "track "..i.." final cv")
		-- The raw note, unaffected by transpose or anything
		-- matrix:add_unipolar("note_t"..i, "track "..i.." note")

		for _,v in ipairs(matrix_sources) do
			matrix:add_unipolar(v..'_t'..i, 'track '..i..' '..v)
		end
	end
end

function note_clock(track)
	local player = params:lookup_param("voice_t"..track):get_player()
	local slide_or_modulate = current_val(track,'slide') -- to match stock kria times
	local velocity = current_val(track,'velocity')
	local divider = data:get_page_val(track,'trig','divisor')
	local subdivision = current_val(track,'retrig')
	local gate_len = current_val(track,'gate')
	local gate_multiplier = data:get_track_val(track,'gate_shift')
	local duration = util.clamp(gate_len-1, 0, 4)/16
	if gate_len == 1 or gate_len == 6 then
		duration = duration + 0.02 -- this turns the longest notes into ties, and the shortest into blips, at mult of 1
	else
		duration = duration - 0.02
	end
	duration = duration * gate_multiplier
	-- print('repeating note '..subdivision..' times')
	for i=1,subdivision do
		if data:get_subtrig(track,data:get_page_val(track,'retrig','pos'),i)==1 then
			if data:get_track_val(track,'trigger_clock') == 1 then
				for _,v in pairs(trigger_clock_pages) do transport:advance_page(track,v) end
			end
			local description = player:describe()
			meta:update_last_notes()
			local note = description.style == 'kit' and last_notes_raw[track] or last_notes[track]
			-- print('playing note '..note)
			player:play_note(note, (velocity-1)/6, duration/subdivision)

			if matrix ~= nil then matrix:set("pitch_t"..track, (note - 36)/(127-36)) end
			local note_str
			if description.style == 'kit' then
				note_str = ''
				for x=0,note,3 do
					note_str = ' ' .. note_str
				end

				note_str = note_str..note
			else
				note_str = mu.note_num_to_name(note, true)
			end
			if description.supports_slew then
				local slide_amt = util.linlin(1,7,1,120,slide_or_modulate) -- to match stock kria times
				player:set_slew(slide_amt/1000)
			else
				local num = util.linlin(1,7,0,1,slide_or_modulate)
				player:modulate(num)
			end
			screen_graphics:add_history(track, note_str, clock.get_beats())
		end
		clock.sleep(clock.get_beat_sec()*divider/(4*subdivision))
	end
end

function step_ticker()
	while true do
		clock.sync(1/4)
		if params:get('swing_this_step') == 1 then
			params:set('swing_this_step',0)
			local amt = (clock.get_beat_sec()/4)*((params:get('swing')-50)/100)
			clock.sleep(amt)
		else
			params:set('swing_this_step',1)
		end
		if params:get('playing') == 1 then
			transport:advance_all()
		end
	end
end

function visual_ticker()
	while true do
		clock.sleep(1/30)
		redraw()
		wavery_light = wavery_light + waver_dir
		if wavery_light > MED + 2 then
			waver_dir = -1
		elseif wavery_light < MED - 2 then
			waver_dir = 1
		end
		grid_graphics:render()
	end
end

function redraw()
	screen_graphics:render()
end

function at() -- get active track
	return params:get('active_track')
end

function ap() -- get active pattern
	return params:get('active_pattern')
end

function out_of_bounds(track,p,value)
	-- returns true if value is out of bounds on page p, track
	return 	(value < data:get_page_val(track,p,'loop_first'))
	or 		(value > data:get_page_val(track,p,'loop_last'))
end

function get_page_name(page,alt)
	local page = page and page or params:get('page')
	local alt = alt and alt or (params:get('alt_page') == 1)
	return alt and alt_page_names[page] or page_names[page]
end

function get_display_page_name()
	local p = get_page_name()
	if p == "slide" then
		local description = params:lookup_param("voice_t"..at()):get_player():describe()
		if not description.supports_slew then
			p = description.modulate_description
		end
	end
	return p
end

function current_val(track,page)
	return value_buffer[track][page]
end

function get_mod_key()
	return mod_names[params:get('mod')]
end

function get_overlay()
	return overlay_names[params:get('overlay')]
end

function set_overlay(n)
	params:set('overlay',tab.key(overlay_names,n))
	post('overlay: '..get_overlay())
end

function track_key_held()
	if kbuf[1][8] or kbuf[2][8] or kbuf[3][8] or kbuf [4][8] then
		return last_touched_track
	else
		return 0
	end
end

function page_key_held()
	if kbuf[6][8] or kbuf[7][8] or kbuf[8][8] or kbuf[9][8] then
		return last_touched_page
	else
		return 0
	end
end

function highlight(l)
	return util.clamp(l+2,0,15)
end

function dim(l) -- level number
	local o
	if l == LOW then
		o = 1
	elseif l == MED then
		o = 3
	elseif l == HIGH then
		o = 9
	else
		o = l - 1
	end

	return util.clamp(o,0,15)
end
