local tu = require 'tabutil'

local Transport = {}

function Transport:init(ctx, data, defaults) -- @@ explode or create special .init_via_ctx function
   self.data = data
   self.ctx = ctx
   self.defaults = defaults
   self.NUM_TRACKS = self.defaults.NUM_TRACKS
   return self
end

function Transport:from_ctx(ctx)
   self:init(ctx, ctx.data, ctx.defaults)
   return self
end

function Transport:play_pause()
   self.data:delta_global_val('playing', 1)
   self.ctx:post(
      (self.data:get_global_val('playing') == 1)
      and
      'play' or 'pause'
   )
end

function Transport:reset_all()
   for t=1, self.self.NUM_TRACKS do
      self:reset_track(t)
   end
   self.ctx.pulse_indicator = 1
   self.data:set_global_val('pattern_quant_pos',1)
   self.data:set_global_val('ms_duration_pos',1)
   self.defaults.swing_this_step = false
   self.ctx:post('reset all')
end

function Transport:reset_track(t)
   for k,v in ipairs(self.defaults.combined_page_list) do
      if v == 'scale' or v == 'patterns' then break end
      self:reset_page(t,v)
   end
   self.ctx:post('reset track '..t)
end

function Transport:reset_page(t,p)
   self.data:set_page_val(t, p, 'pos',
			  self.data:get_page_val(t,p,'loop_last'))
   self.data:set_page_val(t,p,'counter',
			  self.data:get_page_val(t,p,'divisor'))
end

function Transport:advance_all()
   local ctx = self.ctx
   ctx.global_clock_counter = ctx.global_clock_counter + 1

   if ctx.global_clock_counter > self.data:get_global_val('clock_div') then
      ctx.global_clock_counter = 1
      ctx.pulse_indicator = ctx.pulse_indicator + 1
      if ctx.pulse_indicator > 16 then ctx.pulse_indicator = 1 end

      self:advance_pattern_page()

      for t=1, self.self.NUM_TRACKS do
	 if self.data:get_track_val(t,'param_clock') == 0 then
	    self:advance_track(t)
	 end
      end
   end
end

function Transport:advance_pattern_page()
   self.data:delta_global_val('pattern_quant_pos',1)

   if self.data:get_global_val('pattern_quant_pos') <= self.data:get_global_val('pattern_quant') then return end

   self.data:set_global_val('pattern_quant_pos',1)
   if self.data:get_global_val('cued_pattern') ~= 0 then
      self.data:set_global_val('active_pattern',self.data:get_global_val('cued_pattern'))
      self.data:set_global_val('cued_pattern',0)
      self.ctx:post('pattern '..ap()..' active')
   end

   if self.data:get_global_val('ms_active') == 0 then return end

   self.data:delta_global_val('ms_duration_pos',1)
   if self.data:get_global_val('ms_duration_pos') > self.data:get_global_val('ms_duration_'..self.data:get_global_val('ms_pos')) then
      self.data:set_global_val('ms_duration_pos',1)
      self.data:delta_global_val('ms_pos',1)
      if self.data:get_global_val('ms_pos') > self.data:get_global_val('ms_last') or self.data:get_global_val('ms_pos') < self.data:get_global_val('ms_first') then
	 self.data:set_global_val('ms_pos',1)
      end
   end

   self.data:set_global_val('active_pattern',self.data:get_global_val('ms_pattern_'..self.data:get_global_val('ms_pos')))
end

function Transport:advance_track(t)
   local pages_to_advance = (self.data:get_track_val(t,'trigger_clock') == 1) and {'trig','retrig'} or pages_with_steps
   local note_will_fire = false
   for k,v in pairs(pages_to_advance) do
      -- print('attempting to advance page',v)
      self.data:delta_page_val(t,v,'counter',1)
      if self.data:get_page_val(t,v,'counter') > self.data:get_page_val(t,v,'divisor') then
	 self.data:set_page_val(t,v,'counter',1)
	 if type(self.data.tracks[t][v].temp_loop_first) == 'number' then
	    if self:advance_page(t,v, false, true) then note_will_fire = true end
	    self:advance_page(t, v, true, false)
	    -- print(t, v, "fake", self.data:get_pos(t, v), "real", self.data:get_page_val(t,v,'pos'))
	 else
	    if self:advance_page(t,v, true, true) then note_will_fire = true end
	 end
      end
   end
   if note_will_fire then clock.run(note_clock,t) end
end

function Transport:advance_page(t,p,real,playing) -- track,page
   local old_pos = real and self.data:get_page_val(t,p,'pos') or self.data:get_pos(t, p)
   local first = real and self.data:get_page_val(t,p,'loop_first') or self.data:get_loop_first(t, p)
   local last = real and self.data:get_page_val(t,p,'loop_last') or self.data:get_loop_last(t, p)
   local mode = self.defaults.play_modes[self.data:get_track_val(t,'play_mode')]
   local new_pos;
   local resetting = false

   if mode == 'forward' then
      new_pos = old_pos + 1
      if self.data:out_of_bounds(t,p,new_pos, real) then
	 new_pos = first
	 resetting = true
      end
   elseif mode == 'reverse' then
      new_pos = old_pos - 1
      if self.data:out_of_bounds(t,p,new_pos, real) then
	 new_pos = last
	 resetting = true
      end
   elseif mode == 'triangle' then
      local delta = self.data:get_page_val(t,p,'pipo_dir') == 1 and 1 or -1
      new_pos = old_pos + delta
      if self.data:out_of_bounds(t,p,new_pos, real) then
	 if new_pos > last then
	    new_pos = util.clamp(last-1,first,last)
	    self.data:set_page_val(t,p,'pipo_dir',0)
	 elseif new_pos < first then
	    new_pos = util.clamp(first+1,first,last)
	    self.data:set_page_val(t,p,'pipo_dir',1)
	 end
	 resetting = true
      end
   elseif mode == 'drunk' then
      local delta
      if new_pos == first then delta = 1
      elseif new_pos == last then delta = -1
      else delta = math.random() > 0.5 and 1 or -1
      end
      new_pos = old_pos + delta
      if new_pos > last then
	 new_pos = last
      elseif new_pos < first then
	 new_pos = first
      end
      -- ^ have to do it this way vs out_of_bounds() because we want to get to the closest boundary, not necessarily first or last step in loop.

   elseif mode == 'random' then
      new_pos = util.round(math.random(first,last))
   end

   if resetting and playing and self.data:get_page_val(t,p,'cued_divisor') ~= 0 then
      self.data:set_page_val(t,p,'divisor',self.data:get_page_val(t,p,'cued_divisor'))
      self.data:set_page_val(t,p,'cued_divisor',0)
   end

   if real then
      self.data:set_page_val(t,p,'pos',new_pos)
   else
      self.data.tracks[t][p].temp_pos = new_pos
   end

   if playing and math.random(0,99) < prob_map[self.data:get_step_val(t,p,self.data:get_pos(t,p), 'prob')] then
      if matrix and tab.contains(matrix_sources,p) then
	 matrix:set(p..'_t'..t, (self.data:get_step_val(t,p,self.data:get_pos(t,p))-1)/6)
      end
      if self.data:get_track_val(t,'mute') == 0 then
	 value_buffer[t][p] = self.data:get_step_val(t,p,self.data:get_pos(t,p))
	 if p == 'trig' and current_val(t,'trig') == 1 then
	    return true
	 end
      end
   end
end


return Transport
