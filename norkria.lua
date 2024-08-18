-- norKria <<==>>
-- (norkria)
-- forked from the fabulous n.kria v0.22 @zbs @sixolet
-- and reworked guts by @whitmo
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


local defaults = include('lib/defaults')
local Prms = include('lib/prms')
local ctx = include("lib/context")

-- hardware
g = grid.connect()
m = midi.connect()

ctx:preinit(defaults)

local screen_graphics = include('lib/screen_graphics')


local Onboard = include('lib/onboard')
local gkeys = include('lib/gkeys')
local meta = include('lib/meta')

local transport = include('lib/transport')
local hs = include('lib/dualdelay')
local nb = include("lib/nb/lib/nb")
local mu = require 'musicutil'
local tu = require 'tabutil'
local tab = tu


function init()
   local ctx = ctx:init()

   nb.voice_count = 4
   nb:init()

   hs.init()

   print('norkria launched successfully')
end

function redraw() ctx.screen_graphics:render() end

function key(n,d) ctx:key(n,d) end
function enc(n,d) ctx:enc(n,d) end
function g.key(x,y,z) ctx.gkeys:key(x,y,z) end

function clock.transport.start() ctx.data:set_global_val('playing',1); ctx.post('play') end
function clock.transport.stop() ctx.data:global_set_val('playing',0); ctx.post('stop') end

function cleanup()
   Data = nil
   norns.state.context.nkria = nil
end

function menu_clock(n)
   blink.menu[n] = true
   clock.sleep(1/4)
   blink.menu[n] = false
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

function current_val(track, page)
   return ctx.defaults.value_buffer[track][page]
end
