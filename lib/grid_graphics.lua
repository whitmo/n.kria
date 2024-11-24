--[[
   WHAT GOES IN THIS FILE:
   - everything related to how grid looks
]]--

local defaults = include("lib/defaults")
local tab = require "tabutil"
local HIGH, MED, LOW, OFF = defaults.HIGH, defaults.MED, defaults.LOW, defaults.OFF
local NUM_TRACKS = defaults.NUM_TRACKS

local Graphics = {
   handlers = {
      overlay = {
	 none = function(self) self:page_handlers() end,
	 time = function(self) self:config_1() end,
	 options = function(self) self:config_2() end,
	 -- patchers = function(self) self:patchers() end,
      },
      page = {
	 scale = function(self) self:extended_scale() end,
	 track_options = function(self) self:track_options() end,
	 pattern = function(self)
	    if self.data:get_global_val('ms_active') == 1 then
	       self:meta_sequence()
	    else
	       self:pattern()
	    end
	 end,
	 trig = function(self) self:trig() end,
	 retrig = function(self) self:retrig() end,
	 note = function(self) self:note() end,
	 transpose = function(self) self:transpose() end,
	 octave = function(self) self:octave() end,
	 slide = function(self) self:slide() end,
	 gate = function(self) self:gate() end,
	 velocity = function(self) self:velocity() end,
      },
      other = {
	 meta_sequence = function(self) self:meta_sequence() end,
	 time_mod = function(self) self:time() end,
	 prob_mod = function(self) self:prob() end,
      }

   },
   modkeys = {
      'loop',
      'time',
      'prob',
   }
}

function Graphics:new(ctx)
   tab.print({self, ctx})
end

function Graphics:page_handlers()
   local data = self.data

   local p = data:get_page_name()
   local mod = data:get_global_val('mod')
   local modkey = self.modkeys[mod]

   modkey = modkey and modkey .. '_mod' or false

   local ph = self.handlers.page[p]

   ph = ph and ph or self.handlers.other[modkey]

   local status, err
   if ph then
      status, err = pcall(
	 function() ph(self) end
      )
   else
      error("No page handler found for "..p .. " or " .. modkey)
   end

   if err then error(status, err) end

   self:tracks()
   self:pages()
   self:modifiers()

end


function Graphics:from_ctx(ctx)
   self:init(ctx, ctx.data, ctx.grid)
   return self
end

function Graphics:init(ctx, data, grid)
   self.data = data
   self.g = grid
   self.grid = grid
   self.ctx = ctx
end


function Graphics:render()
   local g = self.g
   if self.grid == nil then error('grid not connected') end
   local data = self.data
   local ctx = self.ctx

   ctx.waver_flipflop = not ctx.waver_flipflop
   if ctx.waver_flipflop then
      ctx.wavery_light = ctx.wavery_light + ctx.waver_dir
      if ctx.wavery_light > MED+1 then
	 ctx.waver_dir = -1
      elseif ctx.wavery_light < MED-1 then
	 ctx.waver_dir = 1
      end
   end

   g:all(0)

   -- \/\/ these are in order of precedence \/\/

   local overlay = data:get_overlay()

   local status, err
   local oh = self.handlers.overlay[overlay]

   if oh then
      status, err = pcall(
	 function() oh(self) end
      )
      if not err then return end
      error(status, err)
   end
   
   error("No overlay handler found for "..overlay)

   g:refresh()
end

function Graphics:trig()
   local data = self.data

   local l
   local playing = data:get_global_val('playing')
   local mod_key = data:get_mod_key()

   for t=1, NUM_TRACKS do
      for x=1,16 do
	 local this_trig_on = data:get_step_val(t,'trig',x) == 1
	 local oob = data:out_of_bounds(t,'trig',x)
	 if this_trig_on then
	    if oob then
	       l = MED
	    else
	       l = HIGH
	    end
	 else
	    if oob then
	       l = OFF
	    else
	       l = LOW
	    end
	 end

	 if x == data:get_pos(t,'trig')
	    and playing == 1 then
	    l = self.highlight(l)
	 end

	 if mod_key == 'loop' and not oob then
	    l = self.highlight(l)
	 end

	 self.g:led(x,t,l)
      end
   end
end




-- function Graphics:patchers()
-- 	local l;
-- 	l = (kbuf[2][6] or kbuf[1][7] or kbuf[2][7] or kbuf[2][8]) and HIGH or LOW
-- 	g:led(2,6,l); g:led(1,7,l); g:led(2,8,l)

-- 	l = (kbuf[15][6] or kbuf[16][7] or kbuf[15][7] or kbuf[15][8]) and HIGH or LOW
-- 	g:led(15,6,l); g:led(16,7,l); g:led(15,8,l)

-- 	for x=7,10 do g:led(x,7, LOW) end

-- 	if params:string('patcher') == 'advance triggers' then
-- 		self:advance_triggers_patcher()
-- 	end
-- end

-- function Graphics:advance_triggers_patcher()
-- 	for t=1,NUM_FULL_TRACKS do
-- 		g:led(1,t+1,matrix:get('trig_t'..t)==1 and HIGH or MED)
-- 	end

-- 	for k,v in ipairs(trig_sources) do
-- 		g:led(k+1,1,matrix:get(v)==1 and HIGH or MED)
-- 	end
-- end

function Graphics:config_1()
   local g = self.ctx.grid
   local kbuf = self.ctx.kbuf
   local data = self.data
   local l

   -- note div sync
   l = data:get_global_val('note_div_sync') == 1 and HIGH or MED
   for i=1,4 do g:led(i,5,l) end

   g:led(1,6,l)
   g:led(4,6,l)
   g:led(1,7,l)
   g:led(4,7,l)

   for i=1,4 do g:led(i,8,l) end

   -- div cue
   l = data:get_global_val('div_cue') == 1 and HIGH or MED

   g:led(8,7,l)
   g:led(9,7,l)
   g:led(8,8,l)
   g:led(9,8,l)

   -- div sync
   l = data:get_global_val('div_sync') == 2 and HIGH or MED
   g:led(13,6,l)
   l = data:get_global_val('div_sync') == 3 and HIGH or MED
   for i=1,4 do
      g:led(12+i,8,l)
   end

   -- timing inc/dec keysets
   g:led(7,5,HIGH)
   g:led(8,5,MED)
   g:led(9,5,MED)
   g:led(10,5,HIGH)

   -- arrows
   if kbuf[7][5] then
      g:led(7,4,HIGH)
      g:led(6,5,HIGH)
      g:led(7,6,HIGH)
   end
   if kbuf[8][5] then
      g:led(8,4,MED)
      g:led(8,6,MED)
   end
   if kbuf[9][5] then
      g:led(9,4,MED)
      g:led(9,6,MED)
   end
   if kbuf[10][5] then
      g:led(10,4,HIGH)
      g:led(11,5,HIGH)
      g:led(10,6,HIGH)
   end

   g:led(self.ctx.pulse_indicator,1,HIGH)

   self:time(data:get_global_val('clock_div'))

end

function Graphics:config_2()
   -- note sync
   local data, g = self.data, self.grid
   local l = data:get_global_val('note_sync') == 1 and HIGH or MED
   for i=1,4 do g:led(i+2,3,l) end
   g:led(3,4,l);g:led(6,4,l);g:led(3,5,l);g:led(6,5,l)
   for i=1,4 do g:led(i+2,6,l) end

   -- loop sync
   l = data:get_global_val('loop_sync') == 2 and HIGH or MED
   g:led(11,4,l)
   l = data:get_global_val('loop_sync') == 3 and HIGH or MED
   for i=1,4 do
      g:led(10+i,6,l)
   end
end

function Graphics:tracks()
   local l
   local at = self.data:at()

   for i=1,4 do
      l = i == at and HIGH or MED
      if self.data:get_track_val(i, 'mute') == 1 then
	 l = util.round(l/4)
      end
      self.g:led(i,8,l)
   end
end

function Graphics:pages()
   local data, ctx = self.data, self.ctx

   local p = data:get_global_val('page')
   local l
   for i=1,6 do
      -- l = (p == i) and HIGH or MED
      if p == i then
	 l = HIGH
	 if data:get_global_val('alt_page') == 1 then
	    l = ctx.wavery_light
	 end
      else
	 l = MED
      end
      local x = i + 5
      if i > 4 then
	 x = i + 10
      end
      self.g:led(x,8,l) -- bottom row
   end
end

function Graphics:modifiers()
   local l;

   for i=1,3 do
      l = self.data:get_global_val('mod')-1 == i and HIGH or MED
      self.g:led(10+i,8,l)
   end
end

function Graphics:time(D)
   local l
   local data = self.data
   local ctx = self.ctx

   local active_track = data:at()

   local d = D or data:get_page_val(active_track, data:get_page_name(),'divisor')
   local amount = util.round(HIGH/d)
   local g = self.g
   for x=1,16 do
      if x > d then
	 l = LOW
      elseif x == d then
	 l = HIGH
      else
	 l = amount*x
      end
      g:led(x,2,l)
   end

   g:led(data:get_page_val(active_track,data:get_page_name(),'counter'),1,MED)

   for i=1, ctx.defaults.NUM_SYNC_GROUPS do
      local x1 = ((i-1)%4)+1
      local y1 = util.round_up(i/4)+4

      local l1, l2

      local x2 = x1 + 12
      local y2 = y1 - 2

      if ctx.just_pressed_track then
	 l1 = data:get_track_val(active_track,'loop_group')==i and HIGH or LOW
	 l2 = data:get_track_val(active_track,'div_group')==i and HIGH or LOW
      else
	 l1 = data:get_page_val(active_track,data:get_page_name(),'loop_group')==i and HIGH or LOW
	 l2 = data:get_page_val(active_track,data:get_page_name(),'div_group')==i and HIGH or LOW
      end
      g:led(x1,y1,l1)
      g:led(x2,y2,l2)
   end

   local l1, l2

   if ctx.just_pressed_track then
      l1 = data:get_track_val(active_track,'loop_group')==0 and HIGH or LOW
      l2 = data:get_track_val(active_track,'div_group')==0 and HIGH or LOW
   else
      l1 = data:get_page_val(active_track,data:get_page_name(),'loop_group')==0 and HIGH or LOW
      l2 = data:get_page_val(active_track,data:get_page_name(),'div_group')==0 and HIGH or LOW
   end

   g:led(7,5,l1)
   g:led(6,6,l1)
   g:led(8,6,l1)
   g:led(7,7,l1)

   g:led(10,3,l2)
   g:led(9,4,l2)
   g:led(11,4,l2)
   g:led(10,5,l2)
end

function Graphics:prob()
   local data = self.data
   local active_track = data:at()
   local g = self.g
   for x=1,16 do
      local d = data:get_step_val(active_track,data:get_page_name(),x,'prob')
      g:led(x,6,LOW)
      g:led(x,7-d,HIGH)
      g:led(x,1,data:get_pos(active_track,data:get_page_name()) == x and MED or LOW)
   end
end

function Graphics:track_options()
   local ctx = self.ctx
   for t=1,NUM_TRACKS do
      for k,v in ipairs(ctx.track_options) do
	 local x = (t*3) + ctx.track_options_xes[k]
	 local y = k
	 local l = self.data:get_track_val(t,v) == 1 and HIGH or MED
	 self.g:led(x,y,l)
      end
   end
end

function Graphics:meta_sequence()
   local ctx = self.ctx
   local data = self.data
   local g = self.g
   local l
   for x=1,16 do -- pattern bank
      if x == data:get_global_val('ms_pattern_'..data:get_global_val('ms_cursor')) then
	 l = HIGH
      elseif x == ctx.last_touched_pattern and ctx.just_saved_pattern then
	 l = ctx.wavery_light
      else
	 l = LOW
      end
      g:led(x,1,l)
   end

   for x=1,16 do -- cue clock
      l = OFF
      if x == data:get_global_val('pattern_quant_pos') then
	 l = HIGH
      elseif x == data:get_global_val('pattern_quant') then
	 l = MED
      elseif x < data:get_global_val('pattern_quant') then
	 l = LOW
      end
      g:led(x,2,l)
   end

   l = OFF
   for x=1,16 do -- duration
      if x == data:get_global_val('ms_duration_pos') then
	 l = HIGH
      elseif x == data:get_global_val('ms_duration_'..data:get_global_val('ms_cursor')) then
	 l = MED
      elseif x < data:get_global_val('ms_duration_'..data:get_global_val('ms_cursor')) then
	 l = LOW
      end
      g:led(x,7,l)
   end

   for x=1,16 do
      for y=1,4 do
	 local n = x+((y-1)*16)
	 l = OFF
	 local oob = not ((n>=data:get_global_val('ms_first')) and (n<=data:get_global_val('ms_last')))
	 if n == data:get_global_val('ms_cursor') then
	    l = HIGH
	 elseif n == data:get_global_val('ms_pos') then
	    -- l = data:get_global_val('playing') == 1 and wavery_light or MED
	    l = MED
	 elseif not oob then
	    l = LOW
	    if data:get_mod_key() == 'loop' then l = self.highlight(l) end
	 end
	 g:led(x,y+2,l)
      end
   end
end

function Graphics:pattern()
   local data, ctx = self.data, self.ctx
   local l
   local g = self.g
   for x=1,16 do -- pattern bank
      if x == data:get_global_val('active_pattern') then
	 l = HIGH
      elseif x == data:get_global_val('cued_pattern') then
	 l = ctx.wavery_light
      elseif x == ctx.last_touched_pattern and ctx.just_saved_pattern then
	 l = ctx.wavery_light
      else
	 l = LOW
      end
      g:led(x,1,l)
   end

   for x=1,16 do -- cue clock
      l = OFF
      if x == data:get_global_val('pattern_quant_pos') then
	 l = HIGH
      elseif x == data:get_global_val('pattern_quant') then
	 l = MED
      elseif x < data:get_global_val('pattern_quant') then
	 l = LOW
      end
      g:led(x,2,l)
   end
end

function Graphics:retrig()
   local data = self.data
   local active_track = data:at()
   local kbuf = self.ctx.kbuf
   local g = self.g
   local playing = data:get_global_val('playing') == 1

   for x=1,16 do
      for y=1,7 do
	 local l = OFF
	 local oob = data:out_of_bounds(active_track,'retrig',x)
	 if y == 1 or y == 7 then
	    l = kbuf[x][y] and HIGH or LOW
	    if data:get_pos(active_track,'retrig') == x and playing then
	       l = self.highlight(l)
	    end
	 else
	    if data:get_step_val(active_track,'retrig',x) >= 7-y then
	       if data:get_subtrig(active_track,x,7-y)==1 then
		  l = oob and MED or HIGH
	       else
		  l = oob and LOW or MED
	       end
	    end
	    if data:get_global_val('mod') == 2 and not data:out_of_bounds(active_track,'retrig',x) then
	       l = self.highlight(l)
	    end
	 end
	 g:led(x,y,l)
      end
   end
end

function Graphics:note()
   local l
   local data = self.data
   local active_track = data:at()
   local playing = data:get_global_val('playing') == 1
   local mod_key = data:get_mod_key()

   for x=1,16 do
      local d = data:get_step_val(active_track,'note',x)
      if x == data:get_pos(active_track,'note') and playing then
	 l = LOW
      else
	 l = OFF
      end
      for y=1,7 do
	 local ly = l
	 if y == d then
	    ly = data:out_of_bounds(active_track,'note',x) and LOW or HIGH
	    if data:get_global_val('note_sync') == 1 and data:get_step_val(active_track,'trig',x) == 0 then
	       ly = data:out_of_bounds(active_track,'note',x) and self.dim(LOW) or LOW
	    end
	 end
	 if mod_key == 'loop' and not data:out_of_bounds(active_track,'note',x) then
	    ly = self.highlight(ly)
	 end
	 self.g:led(x,8-y,ly)
      end
   end
end

function Graphics:transpose() -- identical to above, might want to fold them together
   local l
   local data = self.data
   local active_track = data:at()
   local playing = data:get_global_val('playing') == 1

   for x=1,16 do
      local d = data:get_step_val(active_track,'transpose',x)
      if x == data:get_pos(active_track,'transpose') and playing then
	 l = LOW
      else
	 l = OFF
      end
      for y=1,7 do
	 local ly = l
	 if y == d then
	    ly = data:out_of_bounds(active_track,'transpose',x) and LOW or HIGH
	 end
	 if data:get_mod_key() == 'loop' and not data:out_of_bounds(active_track,'transpose',x) then
	    ly = self.highlight(ly)
	 end
	 self.g:led(x,8-y,ly)
      end
   end
end

function Graphics:octave()
   local data = self.data
   local active_track = data:at()
   local g = self.g

   for i=1,8 do
      g:led(i,1,data:get_track_val(active_track,'octave_shift')==i and HIGH or MED)
   end

   local playing = data:get_global_val('playing') == 1
   for x=1,16 do
      local d = data:get_step_val(active_track,'octave',x)
      local oob = data:out_of_bounds(active_track,'octave',x)
      for i=1,6 do
	 local l = OFF
	 if oob then
	    if i == d then
	       l = MED
	    else
	       l = OFF
	    end
	 else
	    if i < d then
	       l = LOW
	    elseif i == d then
	       l = HIGH
	    elseif i > d then
	       l = OFF
	    end
	 end
	 if data:get_mod_key() == 'loop' and (not oob) then
	    l = self.highlight(l)
	 end
	 if x == data:get_pos(active_track,'octave') and playing then
	    l = self.highlight(l)
	 end
	 g:led(x,8-i,l)
      end
   end
end

function Graphics:slide()
   local data = self.data
   local active_track = data:at()
   local playing = data:get_global_val('playing') == 1

   for x=1,16 do
      local l = OFF
      local d = data:get_step_val(active_track,'slide',x)
      local oob = data:out_of_bounds(active_track,'slide',x)
      local l_accum = 0
      local l_delta = util.round(HIGH/d)
      for y=1,7 do
	 if y > d then
	    l = OFF
	 elseif y == d then
	    if oob then
	       l = MED
	    else
	       l = HIGH
	    end
	 elseif y < d then
	    if oob then
	       l = LOW
	    else
	       l_accum = l_accum + l_delta
	       l = l_accum
	    end
	 end
	 if data:get_mod_key() == 'loop' and not oob then
	    l = self.highlight(l)
	 end
	 if x == data:get_pos(active_track,'slide') and playing then
	    l = self.highlight(l)
	 end
	 self.g:led(x,8-y,l)
      end
   end
end

function Graphics:gate()
   local data = self.data
   local s = data:get_track_val(data:at(),'gate_shift')
   local g = self.g

   for i=1,s do
      local l = LOW
      if i == s then
	 l = HIGH
      elseif i > s then
	 l = OFF
      end
      g:led(i,1,l)
   end

   for x=1,16 do
      local l = OFF
      local d = data:get_step_val(data:at(),'gate',x)
      local oob = data:out_of_bounds(data:at(),'gate',x)
      local l_accum = 0
      local l_delta = util.round(HIGH/d)
      for y=1,6 do
	 if y > d then
	    l = OFF
	 elseif y == d then
	    if oob then
	       l = MED
	    else
	       l = HIGH
	    end
	 elseif y < d then
	    if oob then
	       l = LOW
	    else
	       l_accum = l_accum + l_delta
	       l = l_accum
	    end
	 end
	 if data:get_mod_key() == 'loop' and not oob then
	    l = self.highlight(l)
	 end
	 if x == data:get_pos(data:at(),'gate') and data:get_global_val('playing') == 1 then
	    l = self.highlight(l)
	 end
	 g:led(x,1+y,l)
      end
   end
end

function Graphics:velocity(D)
   local ctx, data = self.ctx, self.data
   local active_track = data:at()

   local d = D or data:get_page_val(active_track, data:get_page_name(),'divisor')
   local amount = util.round(HIGH/d)
   local g = self.g
   local l
   for x=1,16 do
      if x > d then
	 l = LOW
      elseif x == d then
	 l = HIGH
      else
	 l = amount*x
      end
      g:led(x,2,l)
   end

   g:led(data:get_page_val(active_track,data:get_page_name(),'counter'),1,MED)

   for i=1, ctx.defaults.NUM_SYNC_GROUPS do
      local x1 = ((i-1)%4)+1
      local y1 = util.round_up(i/4)+4

      local l1, l2

      local x2 = x1 + 12
      local y2 = y1 - 2

      if ctx.just_pressed_track then
	 l1 = data:get_track_val(active_track,'loop_group')==i and HIGH or LOW
	 l2 = data:get_track_val(active_track,'div_group')==i and HIGH or LOW
      else
	 l1 = data:get_page_val(active_track,data:get_page_name(),'loop_group')==i and HIGH or LOW
	 l2 = data:get_page_val(active_track,data:get_page_name(),'div_group')==i and HIGH or LOW
      end
      g:led(x1,y1,l1)
      g:led(x2,y2,l2)
   end

   local l1, l2

   if ctx.just_pressed_track then
      l1 = data:get_track_val(active_track,'loop_group')==0 and HIGH or LOW
      l2 = data:get_track_val(active_track,'div_group')==0 and HIGH or LOW
   else
      l1 = data:get_page_val(active_track,data:get_page_name(),'loop_group')==0 and HIGH or LOW
      l2 = data:get_page_val(active_track,data:get_page_name(),'div_group')==0 and HIGH or LOW
   end

   g:led(7,5,l1)
   g:led(6,6,l1)
   g:led(8,6,l1)
   g:led(7,7,l1)

   g:led(10,3,l2)
   g:led(9,4,l2)
   g:led(11,4,l2)
   g:led(10,5,l2)
end

function Graphics:prob()
   local data = self.data
   local active_track = data:at()
   local g = self.g
   for x=1,16 do
      local d = data:get_step_val(active_track,data:get_page_name(),x,'prob')
      g:led(x,6,LOW)
      g:led(x,7-d,HIGH)
      g:led(x,1,data:get_pos(active_track,data:get_page_name()) == x and MED or LOW)
   end
end

function Graphics:extended_scale()
   local data = self.data
   local g = self.g
   for i=1,16 do -- scale select
      local x = (i > 8) and 2 or 1
      local l = (data:get_global_val('scale_num') == i) and HIGH or MED
      g:led(x, ((i-1) % 8)+1, l)
   end

   for i=2,7 do -- scale editor
      g:led(4,8-i,LOW)
      local d = data:get_scale_degree(data:get_global_val('scale_num'), i)
      g:led(4+d,8-i,HIGH)
      if self.ctx.temp_scale[i-1] ~= -1 then g:led(self.ctx.temp_scale[i-1]+4,8-i,MED) end
   end
   g:led(4,7,LOW)
   g:led(4+util.clamp(data:get_global_val('root_note'),0,7),7,HIGH)
end

function Graphics:track_options()
   for t=1, NUM_TRACKS do
      for k,v in ipairs(self.ctx.track_options) do
	 local x = (t*3) + self.ctx.track_options_xes[k]
	 local y = k
	 local l = self.data:get_track_val(t,v) == 1 and HIGH or MED
	 self.g:led(x,y,l)
      end
   end
end

function Graphics:meta_sequence()
   local data = self.data
   for x=1,16 do
      local l = OFF
      local d = data:get_step_val(data:at(),'velocity',x)
      local oob = data:out_of_bounds(data:at(),'velocity',x)
      local l_accum = 0
      local l_delta = util.round(HIGH/d)
      for y=1,7 do
	 if y > d then
	    l = OFF
	 elseif y == d then
	    if oob then
	       l = MED
	    else
	       l = HIGH
	    end
	 elseif y < d then
	    if oob then
	       l = LOW
	    else
	       l_accum = l_accum + l_delta
	       l = l_accum
	    end
	 end
	 if data:get_mod_key() == 'loop' and not oob then
	    l = self.highlight(l)
	 end
	 if x == data:get_pos(data:at(),'velocity') and data:get_global_val('playing') == 1 then
	    l = self.highlight(l)
	 end
	 self.g:led(x,8-y,l)
      end
   end
end

function Graphics.highlight(l)
   return util.clamp(l+2,0,15)
end

function Graphics.dim(l) -- level number
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

return Graphics
