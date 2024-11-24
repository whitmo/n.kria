--[[
   WHAT GOES IN THIS FILE:
   - everything related to pressing buttons on grid
]]--
local mu = require 'musicutil'
local tab = require 'tabutil'

local gkeys = {}

function gkeys:from_ctx(ctx)
   self.ctx = ctx
   self.data = ctx.data
   self.kbuf = ctx.kbuf
   self.defaults = ctx.defaults
   self.pattern_longpress_clock = function (x) ctx:pattern_longpress_clock(x) end
   self.meta = ctx.meta
   return self
end

function gkeys:post(msg)
   self.ctx:post(msg)
end

function gkeys:time_overlay(x,y,z,_)
   if z == 1 then
      local msg
      local data = self.data
      if x < 5 and y > 4 then -- glyph 1
	 self.data:delta_global_val('note_div_sync',1)
	 msg = 'note division sync '..(data:get_global_val('note_div_sync') == 1 and 'on' or 'off')
      elseif x > 7 and x < 10 and y > 6 then -- glyph 2
	 data:delta_global_val('div_cue',1)
	 msg = 'division cueing '..(data:get_global_val('div_cue') == 1 and 'on' or 'off')
      elseif x == 13 and y == 6 then -- glyph 3 track key
	 data:set_global_val('div_sync', data:get_global_val('div_sync') == 2 and 1 or 2)
	 msg = 'division sync ' .. (data:get_global_val('div_sync') == 2 and 'track' or 'off')
      elseif x > 12 and y == 8 then -- glyph 3 all keys
	 data:set_global_val('div_sync', data:get_global_val('div_sync') == 3 and 1 or 3)
	 msg = 'division sync ' .. (data:get_global_val('div_sync') == 3 and 'all' or 'off')
      elseif y == 5 and (x == 7 or x == 10) then -- coarse time adjustment
	 data:delta_global_val('clock_tempo',(x == 7 and -8 or 8))
	 msg = 'tempo '..(x == 7 and '-' or '+')..'8bpm'
      elseif y == 5 and x > 7 and x < 10 then -- fine time adjustment
	 data:delta_global_val('clock_tempo',(x == 8 and -1 or 1))
	 msg = 'tempo '..(x == 8 and '-' or '+')..'1bpm'
      elseif y == 2 then
	 data:set_global_val('global_clock_div',x)
	 msg = 'global clock divisor: ' .. self.defaults.division_names[data:get_global_val('global_clock_div')]
      end
      self:post(msg)
   end
end

function gkeys:config_overlay(x,y,_,_)
   local data = self.data
   if x > 2 and x < 7 and y > 2 and y < 7 then -- left glyph
      data:delta_global_val('note_sync',1)
      self:post('note sync '..(data:get_global_val('note_sync') == 1 and 'on' or 'off'))
   elseif x == 11 and y == 4 then -- glyph 2 track key
      data:set_global_val('loop_sync', data:get_global_val('loop_sync') == 2 and 1 or 2)
      self:post('loop sync ' .. (data:get_global_val('loop_sync') == 2 and 'track' or 'off'))
   elseif x > 10 and x < 15 and y == 6 then -- glyph 3 all keys
      data:set_global_val('loop_sync', data:get_global_val('loop_sync') == 3 and 1 or 3)
      self:post('loop sync ' .. (data:get_global_val('loop_sync') == 3 and 'all' or 'off'))
   end
end

function gkeys:track_select(x,_,z,_)
   self.ctx.last_touched_track = x
   local data = self.ctx.data
   local kbuf = self.kbuf
   local mod_key = data:get_mod_key()
   if z == 1 then
      if mod_key  == 'loop' then
	 data:delta_track_val(x,'mute',1)
	 self:post('t'..x..' '..((data:get_track_val(x,'mute') == 1) and 'mute' or 'unmute'))
      elseif mod_key == 'time' then
	 data:set_active_track(x)
	 self.ctx.just_pressed_track = true
      else
	 data:set_active_track(x) end
   elseif z == 0 then
      if not (kbuf[1][8] or kbuf[2][8] or kbuf[3][8] or kbuf[4][8]) then
	 self.ctx.just_pressed_track = false
      end
   end
end

function gkeys:page_select(x,_,z,_)
   if z==1 then
      return
   end

   if z==0 then
      if self.ctx.onboard:page_key_held() ~= 0 then
	 return
      elseif self.ctx.just_pressed_clipboard_key then
	 self.ctx.just_pressed_clipboard_key = false
	 return
      end
   end
   local data = self.ctx.data
   local page_map = self.defaults.page_map

   if page_map[x] == data:get_global_val('page') then -- if double-pressing...
      if tab.contains({6,7,8,9},x) then
	 data:delta_global_val('alt_page',1)
      end
   else
      data:set_global_val('page',page_map[x])
      data:set_global_val('alt_page',0)
   end

   local display_page_name = data:get_display_page_name()
   self:post(display_page_name)
   if display_page_name == 'pattern' and data:get_global_val('ms_active') then
      self:post('metasequence')
   end
end


function gkeys:resolve_mod_keys() -- intentionally prioritizes leftmost held mod key
   local mod_key_held = 0
   local kbuf = self.kbuf
   for i=1,3 do
      local on = kbuf[10+i][8]
      if on then
	 print(on)
	 mod_key_held = i
	 break
      end
   end

   self.data:set_global_val('mod', mod_key_held+1)

   if mod_key_held == 0 then
      self.ctx.loop_first = -1
      self.ctx.loop_last = -1
   end

   if not kbuf[12][8] then -- not the time mod page
      self.meta:clear_temp_loops()
   end
   if self.data:get_global_val('mod') ~= 1 then
      self:post(self.ctx.defaults.mod_names[self.data:get_global_val('mod')] .. ' mod')
   end
end

function gkeys:resolve_loop_keys(x,y,z,t)
   local kbuf = self.kbuf
   print("Z: " .. z)
   local page_name = self.data:get_page_name()
   if z == 1 then -- press
      print("RLOOP press " .. x .. "|" .. y)
      if self.ctx.loop_first == -1 then
	 if page_name == 'pattern' then
	    self.ctx.loop_first = x+((y-3)*16)
	 else
	    self.ctx.loop_first = x
	 end
      else
	 if page_name == 'pattern' then
	    self.ctx.loop_last = x+((y-3)*16)
	 else
	    self.ctx.loop_last = x
	 end
	 self.meta:edit_loop_extended(t,self.ctx.loop_first, self.ctx.loop_last, kbuf[12][8])
      end
   else -- release
      print("RLOOP release " .. x .. "|" .. y)
      if self.ctx.loop_last == -1 then
	 self.meta:edit_loop_extended(t, self.ctx.loop_first, self.ctx.loop_last, kbuf[12][8])
      else
	 for i=1,16 do
	    for j=1,7 do
	       if kbuf[i][j] then break end
	    end
	    if i == 16 then
	       self.ctx.loop_first = -1
	    end
	 end
      end
      for i=1,16 do
	 for j=1,7 do
	    if kbuf[i][j] then break end
	 end
	 if i == 16 then
	    self.ctx.loop_first = -1
	    self.ctx.loop_last = -1
	 end
      end
   end
end


function gkeys:time_mod_extended(x,y,z,_)
   if z == 0 then return end

   local data = self.data
   local active_track = data:at()
   if y == 2 then
      self.meta:edit_divisor(active_track, data:get_page_name(),x)
   end

   if x < 5 and y > 4 and y < 8 then
      local n = x+((y-5)*4)
      if self.ctx.just_pressed_track then
	 data:set_track_val(active_track,'loop_group',n)
	 self:post('t'..active_track..' loop: g'..n)
      else
	 data:set_page_val(active_track, data:get_page_name(),'loop_group',n)
	 self:post(data:get_page_name()..' loop: g'..n)
      end
   elseif x > 5 and x < 9 and y > 4 and y < 8 then
      if self.just_pressed_track then
	 data:set_track_val(active_track,'loop_group',0)
	 self:post('t'..active_track..' loop: g0')
      else
	 data:set_page_val(active_track,data:get_page_name(),'loop_group',0)
	 self:post(data:get_page_name()..' loop: g0')
      end
   elseif x > 11 and y > 2 and y < 6 then
      local n = (x-12)+((y-3)*4)
      if self.ctx.just_pressed_track then
	 data:set_track_val(active_track,'div_group',n)
	 self:post('t'..active_track..' div: g'..n)
      else
	 data:set_page_val(active_track,data:get_page_name(),'div_group',n)
	 self:post(data:get_page_name()..' div: g'..n)
      end
   elseif x > 8 and x < 12 and y > 2 and y < 6 then
      if self.ctx.just_pressed_track then
	 data:set_track_val(active_track,'div_group',0)
	 self:post('t'..active_track..' div: g0')
      else
	 data:set_page_val(active_track,data:get_page_name(),'div_group',0)
	 self:post(data:get_page_name()..' div: g0')
      end
   end
end

function gkeys:prob_mod(x,y,z,_)
   local data = self.data
   if z == 1 and y > 2 and y < 7 then
      data:set_step_val(data:at(), data:get_page_name(), x, 7-y, 'prob')
      self:post('odds: '.. self.defaults.prob_map[7-y] .. '%')
   end
end

function gkeys:extended_scale(x,y,z,_)
   local kbuf = self.kbuf
   local data = self.data
   if x < 3 and z == 1 then -- scale select
      local n = y + (x-1) * 8
      data:set_global_val('scale_num',n)
      self:post('selected scale '..n)
   elseif x > 3 and z == 1 then -- scale editor
      if y == 7 then
	 data:set_global_val('root_note',x-4)
	 self:post('root note: '..mu.note_num_to_name(data:get_global_val('root_note')))
	 self.meta:make_scale()
	 return
      end
      local scale_degree = data:get_scale_degree(data:get_global_val('scale_num'), 8-y)
      if  	(kbuf[scale_degree+4][y])
	 and (self.ctx.temp_scale[7-y] ~= x-4)
	 and (scale_degree ~= x-4)
      then
	 self.ctx.temp_scale[7-y] = x-4
	 self:post('live-adjust '..7-y..': '..self.ctx.temp_scale[7-y])
      else
	 data:set_scale_degree(data:get_global_val('scale_num'), 8-y, x-4)
	 self.ctx.temp_scale[7-y] = -1
	 self:post('scale stride, degree '..8-y..': '..x-4)
      end
      self.meta:make_scale()
   end
end

function gkeys:track_options(x,y,z,t)
   if z == 1 then
      local data = self.ctx.data
      local active_track = data:at()
      local track_options = self.defaults.track_options
      data:set_active_track(util.clamp(util.round_up((x-2)/3),1,4))
      data:delta_track_val(active_track,track_options[y],1)
      self:post('track '
		..active_track..' '
		..track_options[y]..' '
		..(data:get_track_val(active_track, track_options[y])==1 and 'on' or 'off'))
   end
end

function gkeys:pattern_overlay(x,y,z,_)
   local kbuf = self.kbuf
   local data = self.ctx.data
   local coros = self.ctx.coros
   if y == 1 then
      if z == 1 then
	 self.ctx.last_touched_pattern = x
	 if coros.pattern_longpress then
	    clock.cancel(coros.pattern_longpress)
	 end
	 coros.pattern_longpress = clock.run(
	    self.pattern_longpress_clock,
	    self.ctx.last_touched_pattern)
      elseif z == 0 and (not self.ctx.just_saved_pattern) then
	 self.meta:switch_to_pattern(x)
	 self.ctx.just_saved_pattern = false
      elseif z == 0 then
	 self.ctx.just_saved_pattern = false
      end
   elseif y == 2 and z == 1 then
      data:set_global_val('pattern_quant',x)
      self:post('cue clock: '..x)
   elseif y == 7 and z == 1 and kbuf[16][8] then
      data:set_global_val('ms_active',1)
      self:post('meta-sequence on')
   end
end

function gkeys:meta_sequence(x,y,z,_)
   local kbuf = self.kbuf
   local coros = self.ctx.coros
   local data = self.ctx.data
   if y == 1 then
      if z == 1 then
	 self.ctx.last_touched_pattern = x
	 if coros.pattern_longpress then clock.cancel(coros.pattern_longpress) end
	 coros.pattern_longpress = clock.run(self.pattern_longpress_clock,self.ctx.last_touched_pattern)
      elseif z == 0 and (not self.ctx.just_saved_pattern) then
	 data:set_global_val('ms_pattern_'..data:get_global_val('ms_cursor'),x)
	 self:post('meta step '
		   ..data:get_global_val('ms_cursor')
		   ..' pattern: '
		   ..data:get_global_val('ms_pattern_'..data:get_global_val('ms_cursor')))
	 self.ctx.just_saved_pattern = false
      elseif z == 0 then
	 self.ctx.just_saved_pattern = false
      end
   elseif y == 2 and z == 1 then
      data:set_global_val('pattern_quant',x)
      self:post('cue clock: '..x)
   elseif y > 2 and y < 7 and z == 1 then
      data:set_global_val('ms_cursor',x+((y-3)*16))
      self.ctx.last_touched_ms_step = x+((y-3)*16)
      self:post('meta-sequence cursor: '..data:get_global_val('ms_cursor'))
   elseif y == 7 and z == 1 and not kbuf[16][8] then
      data:set_global_val('ms_duration_'..data:get_global_val('ms_cursor'),x)
      self:post('meta step '
		..data:get_global_val('ms_cursor')
		..' duration: '..data:get_global_val('ms_duration_'..data:get_global_val('ms_cursor')))
   elseif y == 7 and z == 1 and kbuf[16][8] then
      data:set_global_val('ms_active',0)
      self:post('meta-sequence off')
   end
end

function gkeys.none(_,_,_,_,_)
   print("page NOOP")
end
function gkeys.trig_page(self, x,_,_,t)
   self.data:delta_step_val(t,'trig',x,1)
   local msg = 'trig '..x..' '.. (self.data:get_step_val(t,'trig',x) == 1 and 'on' or 'off')
   self:post(msg)
end

function gkeys.retrig_page(self, x,y,_,t)
   if y == 1 or y == 7 then
      self.meta:delta_subtrig_count(t,x,(y==1 and 1 or -1))
   else
      if 7-y > self.data:get_step_val(t,'retrig',x) then
	 self.data:set_step_val(t,'retrig',x,7-y)
      end
      self.meta:toggle_subtrig(t,x,7-y)
      self:post('subtrig '..7-y..' '..(self.data:get_subtrig(t,x,7-y)==1 and 'on' or 'off'))
   end
end

function gkeys.note_page(self, x,y,_,t)
   local data = self.data
   if  data:get_step_val(t,'note',x) == 8-y and data:get_global_val('note_sync') == 1 then
      data:delta_step_val(t,'trig',x,1)
      self:post('note & trig '..x..': '..8-y)
   else
      data:set_step_val(t, 'note', x, 8-y)
      local n = mu.note_num_to_name(
	 self.meta:make_scale()[(8-y) + data:get_global_val('root_note')]
      )
      self:post('note '..x..': '..8-y.. ' ['..n..']')
   end
end

function gkeys.transpose_page(self, x,y,_,t)
   self.data:set_step_val(t,'transpose',x,8-y)
   self:post('transpose '..x..': '..8-y)
end

function gkeys.octave_page(self, x,y,_,t)
   if y > 1 and y < 8 then
      self.data:set_step_val(t,'octave',x,8-y)
      self:post('octave '..x..': '..8-y)
   elseif y == 1 and x < 9 then
      self.data:set_track_val(t,'octave_shift',x)
      self:post('t'..t..' octave shift: '..x-1)
   end
end

function gkeys.slide_page(self, x,y,_,t)
   self.data:set_step_val(t,'slide',x,8-y)
   local player = params:lookup_param("voice_t"..t):get_player()
   local description = player:describe()
   if description.supports_slew then
      self:post('slide '..x..': '..8-y)
   else
      self:post(description.modulate_description .. ' ' .. x .. ": "..8-y)
   end
end

function gkeys.gate_page(self, x,y,_,t)
   if y > 1 and y < 8 then
      self.data:set_step_val(t,'gate',x,(-1)+y)
      self:post('gate duration '..x..': '..(-1)+y)
   elseif y == 1 then
      self.data:set_track_val(t,'gate_shift',x)
      self:post('t'..self.data:at()..' duration multiplier: '..x)
   end
end

function gkeys.velocity_page(self, x,y,_,t)
   self.data:set_step_val(t,'velocity',x,8-y)
   self:post('velocity '..x..': '..8-y)
end

function gkeys:patchers(x,y,z,_)
   local data = self.data
   if z == 1 and x<4 and y>5 then
      data:delta_global_val('patcher',-1)
   elseif z == 1 and x>13 and y>5 then
      self.data:delta_global_val('patcher',1)
   elseif z == 1 and tab.contains({6,7,8,9,10,11},x) and y==7 then
      data:set_overlay('none')
   elseif self.defaults.patchers[data:get_global_val('patcher')] == 'advance triggers' then
      self:advance_triggers_patcher(x,y,z,_)
   end
end

function gkeys:advance_triggers_patcher(x,y,z,_)
   local trig_sources = self.defaults.trig_sources
   if x == 1 and tab.contains({2,3,4,5},y) then
      self.ctx:post('dest: advance t'..y-1)
   elseif z == 1 and y == 1 and x > 1 and x < #trig_sources+2 then
      self.ctx:post('source: '..trig_sources[x-1])
   end
end

function gkeys.scale_page(self, x,y,z,t)
   return self:extended_scale(x,y,z,t)
end

function gkeys.pattern_page(self, x,y,z,t)
   if self.data:get_global_val('ms_active') == 1 then
      self:meta_sequence(x,y,z,t)
   else
      self:pattern_overlay(x,y,z,t)
   end
end

gkeys.overlay_handlers = {
   time = function(self, x,y,z,t)
      self:time_overlay(x,y,z,t)
   end,
   options = function(self,x,y,z,t)
      if z == 1 then
	 self:config_overlay(x,y,z,t)
      end
   end,
   patchers = function(self, x,y,z,t)
      self:patchers(x,y,z,t)
   end,
   none = function(self, x,y,z,t)
      -- general handler
      local data = self.data
      local page_name = data:get_page_name()
      local mod_key = data:get_mod_key()

      if y == 8 then -- home row
	 return self:homerow_keys(x,y,z,t)
      end

      if not mod_key then
	 print(">>> " .. mod_key .. " <| page: " .. page_name)
      end

      if z == 1 then -- mods not held
	 return self[page_name..'_page'](self, x,y,z,t)
      end
      local handler = gkeys.mod_handlers[mod_key]
      if handler then
	 return handler(self, x,y,z,t)
      end
   end
}

gkeys.mod_handlers = {
   loop = function(self, x,y,z,t) self:resolve_loop_keys(x,y,z,t) end,
   time = function(self, x,y,z,t) self:time_mod_extended(x,y,z,t) end,
   prob = function(self, x,y,z,t) self:prob_mod(x,y,z,t) end,
   -- none = function(self, _,_,_,_) print("NO MOD") end,
}

function gkeys:homerow_keys(x,y,z,t)
   -- patchers -- @@ remove?
   if tab.contains({5,10,14}, x)
      and self.kbuf[5][8]
      and self.kbuf[10][8]
      and self.kbuf[14][8] then
      self.data:set_global_val('overlay', 4)
      self:post('patcher: '..self.defaults.patchers[self.data:get_global_val('patcher')])
      return
   end

   if tab.contains({1,2,3,4},x) then
      self:track_select(x,y,z,t)
   elseif tab.contains({6,7,8,9,15,16},x) then
      self:page_select(x,y,z,t)
   elseif tab.contains({11,12,13},x) then
      self:resolve_mod_keys()
   end
end

function gkeys:key(x,y,z)
   local kbuf = self.kbuf
   local data = self.ctx.data

   kbuf[x][y] = z == 1 and 1 or 0

   local t
   local NUM_TRACKS = self.ctx.defaults.NUM_TRACKS
   if data:get_page_name() == 'trig' and y <= NUM_TRACKS then
      t = y
   else
      t = data:at()
   end

   -- key processing dispatch tree
   gkeys.overlay_handlers[data:get_overlay()](self, x,y,z,t)
end


return gkeys
