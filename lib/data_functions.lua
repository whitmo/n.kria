--[[
WHAT GOES IN THIS FILE:
   - wrappers for interacting w params sporting long annoying names
   - @@ combine with prms.lua?
]]
--
local defaults = include("lib/defaults")
local defs = defaults
local tab = require "tabutil"

local pattern_page_attrs = {
   loop_first = true,
   loop_last = true,
   divisor = true,
}

local Data = {}

-- @@ Magic, necessary?
local global_meta = {
   __index = function(_, key)
      if params[key] then
	 return function(self, id, ...)
	    -- do the params part
	    local new_id = 'global_' .. id
	    local f = params[key]
	    f(params, new_id, ...)
	    local p = params:lookup_param(new_id)
	    self[id] = p
	 end
      end
      return nil
   end
}

local scale_meta = {
   __index = function(_, key)
      if params[key] then
	 return function(self, degree, ...)
	    -- do the params part
	    local new_id = 'global_scale_' .. self.slot .. '_deg_' .. degree
	    local f = params[key]
	    f(params, new_id, ...)
	    local p = params:lookup_param(new_id)
	    self[degree] = p
	 end
      end
      return nil
   end
}

local track_meta = {
   __index = function(_, key)
      if params[key] then
	 return function(self, id, ...)
	    -- do the params part
	    local new_id = id .. '_t' .. self.idx
	    local f = params[key]
	    f(params, new_id, ...)
	    local p = params:lookup_param(new_id)
	    -- print(new_id)
	    self[id] = p
	 end
      end
      return nil
   end
}

local page_meta = {
   __index = function(_, key)
      if params[key] == nil then return nil end
      return function(self, id, ...)
	 -- do the params part
	 local new_id = id .. '_' .. self.id .. '_t' .. self.track
	 local f = params[key]
	 f(params, new_id, ...)
	 local p = params:lookup_param(new_id)
	 self[id] = p
      end
   end
}

setmetatable(Data, global_meta)

Data.pattern = nil

function Data:init(ctx)
   -- Two layers — one for data that's stored per-pattern, and one
   -- that's just tracks, for non-pattern data.
   self.patterns = {}
   self.tracks = {}
   self.post = ctx.post
   self.ctx = ctx

   for t = 1, defs.NUM_TRACKS do
      local trk = { idx = t }
      setmetatable(trk, track_meta)
      for _, v in ipairs(defs.pages_with_steps) do
	 local page = { track = t, id = v }
	 setmetatable(page, page_meta)
	 trk[v] = page
      end
      self.tracks[t] = trk
   end

   self.scales = {}
   for slot = 1, 16 do
      local scale = { slot = slot }
      setmetatable(scale, scale_meta)
      self.scales[slot] = scale
   end
   return self
end

function Data:from_ctx(ctx)
   self:init(ctx)
   return self
end

-- GET
function Data:get_global_val(name)
   return self[name]:get()
end

function Data:get_track_val(track, name)
   return self.tracks[track][name]:get()
end

function Data:get_page_val(track, page, name)
   local args = {track=track,page=page,name=name}
   if tab.contains(args, nil) then
      error("MISSING page val arg: \n" .. tab.print(args))
   end

   if pattern_page_attrs[name] then
      local default = self.ctx.defaults.pattern_page_info[name].default
      local pt = self.patterns[self.pattern]
      if pt == nil then return default end
      local tr = pt[track]
      if tr == nil then return default end
      local pg = tr[page]
      if pg == nil then return default end
      local result = pg[name]
      if result == nil then return default end
      return result
   else
      local pp = self.tracks[track][page]
      if type(pp) ~= 'table' then
	 print("track is", track, "page is", page)
      end
      local param = pp[name]
      if type(param) ~= 'table' then
	 print("page is", page, param)
      end
      return param:get()
   end
end

function Data:get_loop_first(track, page)
   local temp = self.tracks[track][page].temp_loop_first
   if type(temp) == 'number' then return temp end
   return self:get_page_val(track, page, 'loop_first')
end

function Data:get_loop_last(track, page)
   local temp = self.tracks[track][page].temp_loop_last
   if type(temp) == 'number' then return temp end
   return self:get_page_val(track, page, 'loop_last')
end

function Data:get_scale_degree(slot, degree)
   -- print("id", self.scales[slot][degree].id)
   return self.scales[slot][degree]:get()
end

function Data:set_scale_degree(slot, degree, value)
   self.scales[slot][degree]:set(value)
end

function Data:get_pos(track, page)
   local temp = self.tracks[track][page].temp_pos
   if type(temp) == 'number' then return temp end
   return self:get_page_val(track, page, 'pos')
end

function Data:get_player(track)
   return self.tracks[track].player:get_player()
end

function Data:get_step_val(track, page, step, thing)
   local default
   if thing == nil or thing == 'step' then
      thing = 'step'
      default = defaults.page_defaults[page].default
   elseif thing == 'prob' then
      default = 4
   elseif thing == 'subtrig' then
      default = 1
   end
   -- if default == nil then
   -- 	tab.print(page_defaults)
   -- 	tab.print(page_defaults[page])
   -- 	print(page_defaults[page].default)
   -- end
   assert(default ~= nil, string.format("bad default %s %s %s", thing, page, default))
   local pat = self.patterns[self.pattern]
   if pat == nil then return default end
   local tr = pat[track]
   if tr == nil then return default end
   local pg = tr[page]
   if pg == nil then return default end
   -- if type(pg) ~= 'table' then
   -- 	print("page is", page, pg)
   -- end
   local st = pg[step]
   if st == nil then return default end
   local val = st[thing]
   if val == nil then return default end
   return val
end

-- SET
function Data:set_global_val(name, new_val)
   self[name]:set(new_val)
end

function Data:set_track_val(track, name, new_val)
   self.tracks[track][name]:set(new_val)
end

function Data:set_page_val(track, page, name, new_val)
   if pattern_page_attrs[name] then
      local info = self.ctx.defaults.pattern_page_info[name]
      local vv = util.clamp(new_val, info.min, info.max)
      self:ensure(track, page, 1)
      self.patterns[self.pattern][track][page][name] = vv
   else
      self.tracks[track][page][name]:set(new_val)
   end
end

function Data:_step_set_helper(track, page, step, thing, value)
   self.patterns[self.pattern][track][page][step][thing] = value
end

function Data:ensure(track, page, step)
   if self.patterns[self.pattern] == nil then
      self.patterns[self.pattern] = {}
   end
   if self.patterns[self.pattern][track] == nil then
      self.patterns[self.pattern][track] = {}
   end
   if self.patterns[self.pattern][track][page] == nil then
      self.patterns[self.pattern][track][page] = {}
   end
   if self.patterns[self.pattern][track][page][step] == nil then
      self.patterns[self.pattern][track][page][step] = {}
   end
end

function Data:set_step_val(track, page, step, new_val, thing)
   local vv = new_val
   if thing == nil then
      thing = 'step'
      local max, min = defaults.page_defaults[page].max,
	 defaults.page_defaults[page].min
      if (max == nil) or (min == nil) then
	 print("BAD PAGE", page)
      end
      if page == 'trig' then
	 vv = util.wrap(new_val, min, max)
      else
	 vv = util.clamp(new_val, min, max)
      end
   elseif thing == 'prob' then
      vv = util.clamp(new_val, 1, 4)
   elseif thing == 'subtrig' then
      vv = util.clamp(new_val, 1, 31)
   end
   local win = pcall(self._step_set_helper, self, track, page, step, thing, vv)
   if not win then
      self:ensure(track, page, step)
      self.patterns[self.pattern][track][page][step][thing] = vv
   end
end

-- DELTA
function Data:delta_global_val(name, d)
   self[name]:delta(d)
end

function Data:delta_track_val(track, name, d)
   self.tracks[track][name]:delta(d)
end

function Data:delta_page_val(track, page, name, d)
   if pattern_page_attrs[name] then
      local info = self.ctx.defaults.pattern_page_info[name]
      local default = info.default
      local val = self.patterns[self.pattern][track][page][name] or default
      val = util.clamp(val + d, info.min, info.max)
      self.patterns[self.pattern][track][page][name] = val
   else
      return self.tracks[track][page][name]:delta(d)
   end
end

function Data:delta_step_val(track, page, step, d, thing)
   if thing == nil then thing = 'step' end
   local info = self.ctx.defaults.page_defaults[page]
   local val = self:get_step_val(track, page, step, thing)
   val = val + d
   if page == 'trig' and thing == 'step' then
      val = util.wrap(val, info.min, info.max)
   else
      val = util.clamp(val, info.min, info.max)
   end
   self:set_step_val(track, page, step, val, thing)
end

function Data:get_subtrig(track, step, subtrig)
   local st = self:get_step_val(track, 'retrig', step, 'subtrig')
   return bit32.extract(st, subtrig - 1)
end

function Data:set_subtrig(track, step, subtrig, one_or_zero)
   local st = self:get_step_val(track, 'retrig', step, 'subtrig')
   st = bit32.replace(st, one_or_zero, subtrig - 1)
   self:set_step_val(track, 'retrig', step, st, 'subtrig')
end

function Data:set_overlay(name)
   local num = tab.key(self.ctx.defaults.overlay_names, name)
   num = util.clamp(num, 1, 4)
   self:set_global_val('overlay', num)
   self:post('overlay: ' .. self:get_overlay())
end

function Data:get_overlay()
   return defs.overlay_names[self:get_global_val('overlay')]
end

-- move globals to data
function Data:get_page_name(page, alt)
   local r
   page = page and page or self:get_global_val('page')
   alt = alt and alt or (self:get_global_val('alt_page') == 1)
   r = alt and defs.alt_page_names[page] or defs.page_names[page]
   return r
end

function Data:set_active_track(n)
   -- @@ F&R
   self:set_global_val('active_track',n)
   self:post('track ' .. n)
end

function Data:at()
   -- @@ F&R
   return self:get_global_val('active_track')
end

function Data:ap() -- get active pattern
   -- @@ F&R
   return self:get_global_val('active_pattern')
end

function Data:get_display_page_name()
   local p = self:get_page_name()
   if p == "slide" then
      local description = self:get_player(self:at()):describe()
      if not description.supports_slew then
	 p = description.modulate_description
      end
   end
   return p
end

function Data:out_of_bounds(track,p,value, real)
   -- returns true if value is out of bounds on page p, track
   -- @@ F&R
   if real then
      return (value < self:get_page_val(track,p,'loop_first'))
	 or (value > self:get_page_val(track,p,'loop_last'))
   end

   return (value < self:get_loop_first(track,p))
      or (value > self:get_loop_last(track,p))
end

function Data:get_mod_key()
   return defs.mod_names[self:get_global_val('mod')]
end


return Data
