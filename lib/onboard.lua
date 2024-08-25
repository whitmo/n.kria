--[[
WHAT GOES IN THIS FILE:
- everything related to onboard keys and encoders
]]--


local tab = require 'tabutil'

local Onboard = {}

function Onboard:init(ctx, data)
   self.ctx = ctx
   self.data = data
   return self
end

function Onboard:from_ctx(ctx)
   self:init(ctx, ctx.data)
   return self
end

function Onboard:menu_clock(n)
   self.ctx.blink.menu[n] = true
   clock.sleep(1/4)
   self.ctx.blink.menu[n] = false
end

function Onboard:enc(n,d)
   local data, ctx = self.data, self.ctx

   local menu_clock = function(t) self:menu_clock(t) end
   if n == 1 then
      if ctx.onboard_key_states[1] then
	 if ctx.coros.shift_e1 then clock.cancel(ctx.coros.shift_e1) end
	 ctx.coros.shift_e1 = clock.run(menu_clock,2)
	 data:delta_global_val('swing',d)
	 ctx:post('swing: ' .. data:get_global_val('swing'))
      else
	 if ctx.coros.e1 then clock.cancel(ctx.coros.e1) end
	 ctx.coros.e1 = clock.run(menu_clock,1)
	 params:delta('clock_tempo',d)
	 ctx:post('tempo: ' .. util.round(params:get('clock_tempo')))
      end
   elseif n == 2 then
      if script_mode == 'extended' then
	 if ctx.coros.e2 then clock.cancel(ctx.coros.e2) end
	 ctx.coros.e2 = clock.run(menu_clock,3)
	 if ctx.onboard_key_states[1] then
	    if d > 0 then
	       data:set_global_val('stretch',data:get_global_val('stretch')<0 and 0 or 64)
	    else
	       data:set_global_val('stretch',data:get_global_val('stretch')>0 and 0 or -64)
	    end
	 else
	    data:delta_global_val('stretch',d)
	 end
	 ctx:post('stretch: ' .. data:get_global_val('stretch'))
      end
   elseif n == 3 then
      if script_mode == 'extended' then
	 if ctx.coros.e3 then
	    clock.cancel(ctx.coros.e3)
	 end
	 ctx.coros.e3 = clock.run(menu_clock,4)
	 if ctx.onboard_key_states[1] then
	    if d > 0 then
	       data:set_global_val('push',data:get_global_val('push')<0 and 0 or 64)
	    else
	       data:set_global_val('push',data:get_global_val('push')>0 and 0 or -64)
	    end
	 else
	    data:delta_global_val('push',d)
	 end
	 ctx:post('push: '.. data:get_global_val('push'))
      end
   end
end

function Onboard:track_key_held()
   local kbuf = self.ctx.kbuf
   if kbuf[1][8] or kbuf[2][8] or kbuf[3][8] or kbuf[4][8] then
      return self.ctx.last_touched_track
   else
      return 0
   end
end

function Onboard:page_key_held()
   local kbuf = self.ctx.kbuf
   if kbuf[6][8] or kbuf[7][8] or kbuf[8][8] or kbuf[9][8] then
      return self.ctx.last_touched_page
   else
      return 0
   end
end

function Onboard:key(n,d)
   local data, ctx = self.data, self.ctx
   ctx.onboard_key_states[n] = (d==1)
   if d == 1 and n ~= 1 then
      if tab.contains({'options','time'}, data:get_overlay()) then
	 data:set_overlay('none')
      elseif ctx.onboard_key_states[2] and ctx.onboard_key_states[3] then
	 self:both_pressed()
      elseif ctx.onboard_key_states[1] then
	 data:set_overlay((n==2) and 'time' or 'options')
      elseif (not ctx.onboard_key_states[1]) and (self:track_key_held()==0 and self:page_key_held()==0) then
	 if n==2 then
	    ctx.transport:reset_all()
	 elseif n==3 then
	    ctx.transport:play_pause()
	 end
      elseif (not ctx.onboard_key_states[1]) and (self:track_key_held()~=0) then
	 ctx.just_pressed_clipboard_key = true
	 if n==2 then
	    ctx.track_clipboard = ctx.meta:get_track_copy(ctx.last_touched_track)
	    ctx:post('copied track '..ctx.last_touched_track)
	 elseif n==3 then
	    ctx.meta:paste_onto_track(ctx.last_touched_track, ctx.track_clipboard)
	    ctx:post('pasted track '..ctx.last_touched_track)
	 end
      elseif (not ctx.onboard_key_states[1]) and (self:page_key_held()~=0) then
	 ctx.just_pressed_clipboard_key = true
	 local active_track = data:at()
	 local p = data:get_page_name(ctx.last_touched_page)
	 if n==2 then
	    ctx.page_clipboards[p] = ctx.meta:get_page_copy(ctx.last_touched_track,p)
	    ctx:post('copied page: t'..active_track..' '..p)
	 elseif n==3 then
	    ctx.meta:paste_onto_page(active_track,p,ctx.page_clipboards[p])
	    ctx:post('pasted page: t'..active_track..' '..p)
	 end
      end
   end
end

function Onboard:both_pressed()
   local ctx = self.ctx
   local data = self.data
   if self:track_key_held() == 0 and self:page_key_held() == 0 then
      ctx:post('hold track/page to cut')
      return
   end

   if self:track_key_held() ~= 0 then
      ctx.track_clipboard = ctx.meta:get_track_copy(ctx.last_touched_track)
      ctx.meta:paste_onto_track(ctx.last_touched_track, ctx.meta:get_track_copy(0))
      ctx:post('cut track '.. ctx.last_touched_track)
   elseif self:page_key_held() ~= 0 then
      local active_track = data:at()
      local p = data:get_page_name(ctx.last_touched_page)
      ctx.page_clipboards[p] = ctx.meta:get_page_copy(ctx.last_touched_track,p)
      ctx.meta:paste_onto_page(active_track, p, ctx.meta:get_track_copy(0)[p])
      ctx:post('cut page: t'..active_track..' '..p)
   end
   ctx.just_pressed_clipboard_key = true
end

return Onboard
