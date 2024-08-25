--[[
WHAT GOES IN THIS FILE:
- everything related to how the screen looks
]]--
local defaults = include("lib/defaults")
local HIGH, MED, LOW, OFF = defaults.HIGH, defaults.MED, defaults.LOW, defaults.OFF
local track_options = defaults.track_options
local track_options_xes = defaults.track_options_xes
local config_desc = defaults.config_desc


local mu = require 'musicutil'
local Graphics = {
   history = {}, -- keys are unique. values are like {track: 1, note: "A", beats: 234}
   data = {}
}

local tab = require 'tabutil'
local s = screen

function Graphics:init(ctx, data, meta)
   self.ctx = ctx
   self.data = data
   self.meta = meta
end

function Graphics:from_ctx(ctx)
   self:init(ctx, ctx.data, ctx.meta)
   return self
end

function Graphics:render()
   s.clear()
   self:post()
   self:note_history()
   self:right_windows()
   self:scale()

   local overlay = self.data:get_overlay()
   if overlay == 'time' then
      self:description_window()
   elseif overlay == 'options' then
      self:description_window()
      self:config_descriptions()
   end

   s.update()
end

function Graphics:track_options()
   local active_track = self.data:at()
   for k,v in ipairs(track_options) do
      local l = self.data:get_track_val(active_track,v) == 1 and HIGH or LOW
      local x = (track_options_xes[k]==1) and 86 or 78
      local y = ((k-1)*7)+2

      s.level(l)
      s.move(s.text_extents(string.upper(v))+5,y+3)
      s.line_width(2)
      s.line(x,y+3)
      s.stroke()

      s.line_width(1)
      s.rect(x,y,6,6)
      s.fill()

      s.level(MED)
      s.move(2,y+5)
      s.text(string.upper(v))

   end
   s.level(LOW)
   s.text_rotate(120,2,'OVERRIDES',90)
   s.text_rotate(112,2,'GLOBAL',90)
   s.text_rotate(104,2,'SETTINGS',90)
end

function Graphics:add_history(track, note, beats)
	local key = note..track..beats
	self.history[key] = {
		note=note,
		track=track,
		beats=beats,
	}
end

function Graphics:note_history()
   local now = clock.get_beats()
   s.aa(1)
   for k, hist in pairs(self.history) do
      local ago = (now - hist.beats)
      if ago > 5 then
	 self.history[k] = nil
      else
	 s.level(HIGH)
	 s.move((hist.track*19)-1, 54 - (54/4.0)*ago)
	 s.text(hist.note)
      end
   end
   s.aa(0)
end

function Graphics:scale()
   s.level(MED)
   s.rect(0,0,14,53)
   s.fill()
   s.level(LOW)
   s.rect(1,1,13,52)
   s.stroke()

   s.level(1)
   local root = 0
   if self.data then
      root = self.data:get_global_val('root_note')
   end
   local scale = self.meta:make_scale()
   for i=1,7 do
      s.move(2, 7*i+1)
      s.text(mu.note_num_to_name(scale[(8-i) + root]))
   end
end

function Graphics:config_descriptions()
   local line_1 = 'n.kria is in extended mode'
   local line_2 = 'use time mod page instead'

   s.move(64,40)
   s.level(OFF)
   s.text_center(string.upper(line_1))
   s.move(64,48)
   s.text_center(string.upper(line_2))

end

function Graphics:right_windows()
   local left_border = 92
   local height = 10
   local ctx = self.ctx
   local names = {
      'BPM'
      ,	'SWING'
      ,	'STRETCH'
      ,	'PUSH'
   }

   local blink = ctx.blink

   for k,v in ipairs(names) do
      s.level(blink.menu[k] and MED or LOW)
      s.rect(left_border,(height*k)+1,128-left_border,-height)
      s.fill()

      s.level(blink.menu[k] and OFF or MED)
      s.move(125,(height*k)-2)
      local str = ''
      if v == 'BPM' then
	 str = blink.menu[k] and
	    util.round(params:get('clock_tempo')) or 'BPM'
      elseif v == 'SWING' then
	 str = blink.menu[k] and self.data:get_global_val('swing')..'%' or 'SWING'
      elseif v == 'STRETCH' then
	 str = blink.menu[k] and self.data:get_global_val('stretch') or 'STRETCH'
      elseif v == 'PUSH' then
	 str = blink.menu[k] and self.data:get_global_val('push') or 'PUSH'
      end
      s.text_right(str)
   end

   s.level(MED)
   local h = height*#names

   s.rect(left_border,1,128-left_border,h)
   s.stroke()
end

function Graphics.description_window()
   s.level(HIGH)
   s.rect(0,52,128,-20)
   s.fill()
   s.level(LOW)
   s.rect(1,53,127,-21)
   s.stroke()
end

function Graphics:post()
   s.level(HIGH)
   s.rect(0,64,128,-10)
   s.fill()
   s.move(1,62)
   s.level(0)
   s.text('\u{0bb}')
   s.move(8,62)
   s.text(string.upper(self.ctx.post_buffer))
end

return Graphics
