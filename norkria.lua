-- n.Kria                        :-)
-- v0.22 @zbs @sixolet
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

local globals = include('lib/globals')

local screen_graphics = include('lib/screen_graphics')
local grid_graphics = include('lib/grid_graphics')
local Prms = include('lib/prms')
local Onboard = include('lib/onboard')
local gkeys = include('lib/gkeys')
local meta = include('lib/meta')
local data = include('lib/data_functions')
local transport = include('lib/transport')
local hs = include('lib/dualdelay')
local nb = include("lib/nb/lib/nb")
local mu = require 'musicutil'
local tu = require 'tabutil'
local tab = tu

-- hardware
g = grid.connect()
m = midi.connect()

-- add to ctx
local ctx = globals.context
ctx.grid = g
ctx.midi = m
ctx.data = data

-- matrix
-- move to ctx
matrix_status, matrix = pcall(require, 'matrix/lib/matrix')
if not matrix_status then matrix = nil end


function init()
   nb.voice_count = 4
   nb:init()
   Prms:add(data)
   transport:init(data, ctx)
   hs.init()

   track_clipboard = meta:get_track_copy(0)
   page_clipboards = meta:get_track_copy(0)

   if matrix then
      add_modulation_sources()
   end

   init_kbuf()

   init_value_buffer()

   visual_metro = metro.init(update_visuals,1/15,-1)
   visual_metro:start()

   grid_graphics:init(data, ctx.grid)

   local function grid_render() grid_graphics:render() end
   grid_metro = metro.init(grid_render, 1/60, -1)
   grid_metro:start()

   coros.step_ticker = clock.run(step_ticker)
   coros.intro = clock.run(intro)

   last_touched_track = data:at()
   ctx.last_touched_page = data:get_page_name()

   print('n.kria launched successfully')
end


-- basic functions

function update_visuals()
	redraw()
end

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
      table.insert(ctx.kbuf,{})
      for y=1,8 do ctx.kbuf[x][y] = false end
   end
end

function intro()
   ctx.post('n.Kria', true)
   clock.sleep(0.1)
   params:bang()
   clock.sleep(2)
   ctx.post('by @zbs', true)
   clock.sleep(2)
   ctx.post('based on kria by @tehn', true)
   clock.sleep(2)
   ctx.post('see splash for controls', true)
end

function pattern_longpress_clock(x)
   clock.sleep(0.5)
   if ctx.kbuf[x][1] then
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

function clock.transport.start() data:set_global_val('playing',1); ctx.post('play') end
function clock.transport.stop() data:global_set_val('playing',0); ctx.post('stop') end

-- function post(str,intro)
--    -- second arg: send true if we shouldn't interrupt the intro sequence.
--    -- basically don't worry about it
--    post_buffer = str
--    if (not intro) and (coros.intro) then
--       clock.cancel(coros.intro)
--    end
-- end

function add_modulation_sources()
   for i=1,NUM_TRACKS do
      matrix:add_bipolar("pitch_t"..i, "track "..i.." final cv")
      for _,v in ipairs(matrix_sources) do
	 matrix:add_unipolar(v..'_t'..i, 'track '..i..' '..v)
      end

      matrix:add_binary('trig_t'..i, 'track '..i..' trig')
      table.insert(trig_sources,'trig_t'..i)
   end

   if util.file_exists('/home/we/dust/code/toolkit') then
      for i=1,4 do
	 table.insert(trig_sources,'rhythm_'..i)
      end
   end
end

function note_clock(track)
	local player = data:get_player(track)
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
		if data:get_subtrig(track,data:get_pos(track,'retrig'),i)==1 then
			if data:get_track_val(track,'trigger_clock') == 1 then
				for _,v in pairs(trigger_clock_pages) do transport:advance_page(track,v) end
			end
			local description = player:describe()
			meta:update_last_notes()
			local note = description.style == 'kit' and last_notes_raw[track] or last_notes[track]
			player:play_note(note, (velocity-1)/6, duration/subdivision)

			if matrix ~= nil then
				matrix:set("pitch_t"..track, (note - 36)/(127-36))
				matrix:set('trig_t'..track,1)
				matrix:set('trig_t'..track,0)
			end

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
		if data:get_global_val('swing_this_step') == 1 then
			data:set_global_val('swing_this_step',0)
			local amt = (clock.get_beat_sec()/4)*((data:get_global_val('swing')-50)/100)
			clock.sleep(amt)
		else
			data:set_global_val('swing_this_step',1)
		end
		if data:get_global_val('playing') == 1 then
			transport:advance_all()
		end
	end
end

function redraw() screen_graphics:render() end

function current_val(track, page)
   return ctx.defaults.value_buffer[track][page]
end

function cleanup()
   Data = nil
   norns.state.context.nkria = nil
end
