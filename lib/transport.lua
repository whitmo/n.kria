local tab = require 'tabutil'
local mu = require 'musicutil'

local Transport = {}


function Transport:init(ctx, data, defaults) -- @@ explode or create special .init_via_ctx function
   self.data = data
   self.ctx = ctx
   self.defaults = defaults
   self.meta = self.ctx.meta
   self.NUM_TRACKS = self.defaults.NUM_TRACKS
   return self
end

function Transport:from_ctx(ctx)
   self:init(ctx, ctx.data, ctx.defaults)
   return self
end

function Transport:current_val(track, page)
   return self.ctx.value_buffer[track][page]
end

function Transport:note_clock(track)
   local data = self.data
   local ctx = self.ctx
   local player = data:get_player(track)
   local slide_or_modulate = self:current_val(track,'slide') -- to match stock kria times
   local velocity = self:current_val(track,'velocity')
   local divider = data:get_page_val(track,'trig','divisor')
   local subdivision = self:current_val(track,'retrig')
   local gate_len = self:current_val(track,'gate')
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
	    for _,v in pairs(self.defaults.trigger_clock_pages) do
	       self:advance_page(track,v)
	    end
	 end
	 local description = player:describe()
	 self.meta:update_last_notes()
	 local note = description.style == 'kit' and ctx.last_notes_raw[track] or ctx.last_notes[track]
	 player:play_note(note, (velocity-1)/6, duration/subdivision)

	 if ctx.matrix ~= nil then
	    ctx.matrix:set("pitch_t"..track, (note - 36)/(127-36))
	    ctx.matrix:set('trig_t'..track,1)
	    ctx.matrix:set('trig_t'..track,0)
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
	 ctx.screen_graphics:add_history(track, note_str, clock.get_beats())
      end
      clock.sleep(clock.get_beat_sec()*divider/(4*subdivision))
   end
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
   for t=1, self.NUM_TRACKS do
      self:reset_track(t)
   end
   self.ctx.pulse_indicator = 1
   self.data:set_global_val('pattern_quant_pos',1)
   self.data:set_global_val('ms_duration_pos',1)
   self.defaults.swing_this_step = false
   self.ctx:post('reset all')
end

function Transport:reset_track(t)
   for _,v in ipairs(self.defaults.combined_page_list) do
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

      for t=1, self.NUM_TRACKS do
	 if self.data:get_track_val(t,'param_clock') == 0 then
	    self:advance_track(t)
	 end
      end
   end
end

function Transport:advance_pattern_page()
   -- @@ move to data functions
   local data = self.data
   data:delta_global_val('pattern_quant_pos',1)

   if data:get_global_val('pattern_quant_pos') <= self.data:get_global_val('pattern_quant') then return end

   data:set_global_val('pattern_quant_pos',1)
   if data:get_global_val('cued_pattern') ~= 0 then
      data:set_global_val('active_pattern',data:get_global_val('cued_pattern'))
      data:set_global_val('cued_pattern',0)
      self.ctx:post('pattern '..data:ap()..' active')
   end

   if self.data:get_global_val('ms_active') == 0 then return end

   self.data:delta_global_val('ms_duration_pos',1)
   if self.data:get_global_val('ms_duration_pos') > data:get_global_val('ms_duration_'..data:get_global_val('ms_pos'))
   then
      data:set_global_val('ms_duration_pos',1)
      data:delta_global_val('ms_pos',1)
      if data:get_global_val('ms_pos') > data:get_global_val('ms_last')
	 or data:get_global_val('ms_pos') < data:get_global_val('ms_first') then
	 data:set_global_val('ms_pos',1)
      end
   end
   data:set_global_val('active_pattern', data:get_global_val('ms_pattern_'..data:get_global_val('ms_pos')))
end

function Transport:advance_track(t)
   local data = self.data
   local pages_to_advance = (data:get_track_val(t, 'trigger_clock') == 1)
      and {'trig','retrig'}
      or self.defaults.pages_with_steps
   local note_will_fire = false
   for k,v in pairs(pages_to_advance) do
      -- print('attempting to advance page',v)
      data:delta_page_val(t,v,'counter',1)
      if data:get_page_val(t,v,'counter') > data:get_page_val(t,v,'divisor') then
	 data:set_page_val(t,v,'counter',1)
	 if type(data.tracks[t][v].temp_loop_first) == 'number' then
	    if self:advance_page(t,v, false, true) then note_will_fire = true end
	    self:advance_page(t, v, true, false)
	    -- print(t, v, "fake", data:get_pos(t, v), "real", data:get_page_val(t,v,'pos'))
	 else
	    if self:advance_page(t,v, true, true) then note_will_fire = true end
	 end
      end
   end
   if note_will_fire then clock.run(function (track) self:note_clock(track) end, t) end
end

Transport.modal_page_handlers = {
    forward = function (tp, old, real, first, _, t, p)
      local new = old + 1
      if tp.data:out_of_bounds(t,p,new, real) then
	 return first, true
      end
         return new, false
    end,
    reverse = function (tp, old, real, _, last, t, p)
      local new = old - 1
      if tp.data:out_of_bounds(t,p,new, real) then
	 return last, true
      end
      return new, false
    end,
    triangle = function (tp, old, real, first, last, t, p)
       local delta = tp.data:get_page_val(t,p,'pipo_dir') == 1 and 1 or -1
       local new = old + delta
       if tp.data:out_of_bounds(t,p,new, real) then
	  if new > last then
	     new = util.clamp(last-1,first,last)
	     tp.data:set_page_val(t,p,'pipo_dir',0)
	  elseif new < first then
	     new = util.clamp(first+1,first,last)
	     tp.data:set_page_val(t,p,'pipo_dir',1)
	  end
	  return new, true
       end
       return new, false
    end,
    drunk = function (_, old, _, first, last, _, _)
       local delta
       local new = nil
       if new == first then delta = 1
       elseif new == last then delta = -1
       else delta = math.random() > 0.5 and 1 or -1
       end
       new = old + delta
       if new > last then
	  new = last
       elseif new < first then
	  new = first
       end
       -- ^ have to do it this way vs out_of_bounds() because
       -- we want to get to the closest boundary, not necessarily first or last step in loop.
       return new, false
    end,
    random = function (_, _, _, first, last, _, _, _)
       local new  = util.round(math.random(first, last))
       return new, false
    end
}

function Transport:advance_page(t,p,real,playing) -- track,page
   local ctx = self.ctx
   local old_pos = real and self.data:get_page_val(t,p,'pos') or self.data:get_pos(t, p)
   local first = real and self.data:get_page_val(t,p,'loop_first') or self.data:get_loop_first(t, p)
   local last = real and self.data:get_page_val(t,p,'loop_last') or self.data:get_loop_last(t, p)
   local mode = self.defaults.play_modes[self.data:get_track_val(t,'play_mode')]
   local new_pos
   local resetting

   new_pos, resetting = self.modal_page_handlers[mode](self, old_pos, real, first, last, t, p)

   if resetting and playing and self.data:get_page_val(t,p,'cued_divisor') ~= 0 then
      self.data:set_page_val(t,p,'divisor',self.data:get_page_val(t,p,'cued_divisor'))
      self.data:set_page_val(t,p,'cued_divisor',0)
   end

   if real then
      self.data:set_page_val(t,p,'pos',new_pos)
   else
      self.data.tracks[t][p].temp_pos = new_pos
   end

   local prob_map = self.ctx.defaults.prob_map
   if playing and math.random(0,99) < prob_map[self.data:get_step_val(t,p,self.data:get_pos(t,p), 'prob')] then
      if ctx.matrix and tab.contains(ctx.defaults.matrix_sources, p) then
	 ctx.matrix:set(p..'_t'..t, (self.data:get_step_val(t,p,self.data:get_pos(t,p))-1)/6)
      end
      if self.data:get_track_val(t,'mute') == 0 then
	 ctx.value_buffer[t][p] = self.data:get_step_val(t,p,self.data:get_pos(t,p))
	 if p == 'trig' and self:current_val(t,'trig') == 1 then
	    return true
	 end
      end
   end
end


return Transport
