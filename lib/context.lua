-- Globals as a namespace

local tu = require 'tabutil'
local defaults = include('lib/defaults')

local Context = {
   phase = "include",
   coros = {},
   defaults = defaults,
}

local prms = include('lib/prms')
local grid_graphics = include('lib/grid_graphics')
local gkeys = include('lib/gkeys')
local screen_graphics = include('lib/screen_graphics')
local meta = include('lib/meta')
local transport = include('lib/transport')
local onboard = include('lib/onboard')
local data_func = include('lib/data_functions')

function Context:preinit()
   if not norns.state.context then
      norns.state.context = {}
   end

   if not norns.state.context.norkria then
      norns.state.context.norkria = self
   else
      -- make it a singleton
      -- don't reinit if we're already initialized
      return norns.state.context.norkria
   end

   local base_values = {
      matrix = self:matrix_maybe(),
      grid = nil,
      midi = nil,
      data = data_func,

      -- mutable state holders
      value_buffer = {},
      page_clipboards = {},
      track_clipboard = {},
      pattern_clipboard = {},
      ms_step_clipboard = {},
      last_notes = {0,0,0,0},
      last_notes_raw = {0,0,0,0},
      temp_scale = {-1,-1,-1,-1,-1,-1},

      blink = {
	 menu = {false,false,false,false,false}
      },

      last_touched_page = 'trig',
      last_touched_track = 1,
      last_touched_ms_step = 1,
      last_touched_pattern = 1,
      pulse_indicator = 1,
      global_clock_counter = 1,
      just_pressed_clipboard_key = false,
      just_saved_pattern = false,
      just_pressed_track = false,
      kbuf = self:init_kbuf(), -- key state buffer, true/false
      onboard_key_states = {false,false,false},
      loop_first = -1,
      loop_last = -1,
      wavery_light = defaults.MED,
      waver_dir = 1,
      waver_flipflop = true,

      -- objects and placeholders
      grid_metro = nil,
   }
   tu.update(self, base_values)
   return self
end

function Context:key(n, d)
   self.onboard:key(n, d)
end

function Context:enc(n, d)
   self.onboard:enc(n, d)
end

function Context:redraw()
   return self.screen_graphics:render()
end

function Context:init_dependencies()
   -- @@ loop
   self.data = self.data:from_ctx(self)  -- @@init order dep
   self.transport = transport:from_ctx(self)
   self.prms = prms:from_ctx(self)       -- ^^
   self.onboard = onboard:from_ctx(self)
   self.meta = meta:from_ctx(self)
   self.screen_graphics = screen_graphics:from_ctx(self)
   self.gkeys = gkeys:from_ctx(self)
   self.grid_graphics = grid_graphics:from_ctx(self)
end

function Context:init()
   self.midi = midi.connect()
   self.grid = grid.connect()

   self:init_dependencies()

   self.last_touched_track = self.data:at()
   self.last_touched_page = self.data:get_page_name()

   self:init_modulation_sources()
   self:init_value_buffer()

   self.track_clipboard = self.meta:get_track_copy(0)
   self.page_clipboards = self.meta:get_track_copy(0)

   local step_ticker = function() self:step_ticker() end

   self.coros.step_ticker = clock.run(step_ticker)

   self.coros.intro = clock.run(function () self:intro() end)
   self.phase = "initialized"
   return self
end

function Context:intro()
   self:post('nor.Kria', true)
   clock.sleep(0.1)
   params:bang()
   clock.sleep(2)
   self:post('rework by @whitmo', true)
   clock.sleep(2)
   self:post('based on kria by @tehn and n.kria by @zbs', true)
   clock.sleep(2)
   self:post('see splash for controls', true)
end

function Context:init_modulation_sources()
   if not self.matrix then
      return
   end
   local matrix_sources = self.defaults.matrix_sources
   local trig_sources = self.defaults.trig_sources

   for i=1, self.defaults.NUM_TRACKS do
      self.matrix:add_bipolar("pitch_t"..i, "track "..i.." final cv")
      for _,v in ipairs(matrix_sources) do
	 self.matrix:add_unipolar(v..'_t'..i, 'track '..i..' '..v)
      end

      self.matrix:add_binary('trig_t'..i, 'track '..i..' trig')
      table.insert(trig_sources,'trig_t'..i)
   end

   if util.file_exists('/home/we/dust/code/toolkit') then
      for i=1,4 do
	 table.insert(trig_sources,'rhythm_'..i)
      end
   end
end

function Context:init_value_buffer()
   for t=1, self.defaults.NUM_TRACKS do
      table.insert(self.value_buffer,{})
      for _,v in pairs(self.defaults.pages_with_steps) do
	 --print('adding',v,'to value buffer')
	 self.value_buffer[t][v] = 0
      end
   end
end

function Context:init_kbuf()
   self.kbuf = {}
   for x=1,16 do
      table.insert(self.kbuf ,{})
      for y=1,8 do self.kbuf[x][y] = false end
   end
   return self.kbuf
end

function Context:matrix_maybe()
   local status, matrix = pcall(require, 'matrix/lib/matrix')
   if not status then
      return nil
   end
   self.has_matrix = true
   return matrix
end

function Context:post(str, intro)
   -- second arg: send true if we shouldn't interrupt the intro sequence.
   -- basically don't worry about it
   self.post_buffer = str
   if not self.coros then
      self.coros = {}
   end
   if (not intro) and (self.coros.intro) then
      clock.cancel(self.coros.intro)
   end
end

function Context:pattern_longpress_clock(x)
   clock.sleep(0.5)
   if self.kbuf[x][1] then
      meta:save_pattern_into_slot(x)
      self.just_saved_pattern = true
   end
end

function Context:step_ticker()
   local data = self.data
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
	 self.transport:advance_all()
      end
   end
end

return Context:preinit()
