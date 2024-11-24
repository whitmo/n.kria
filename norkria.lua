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
   - interface elements
   - context init
   - coroutines
   - any addition special norkria init (nb, hs)

]]--

local defaults = include('lib/defaults')
local ctx = include("lib/context")

-- @@ is this really necessary?
ctx:preinit(defaults)

local hs = include('lib/dualdelay')
local nb = include("lib/nb/lib/nb")

function init()
   ctx:init()

   function ctx.grid.key(x,y,z) ctx.gkeys:key(x,y,z) end

   nb.voice_count = 4
   nb:init()

   hs.init()

   ctx.visual_metro = metro.init(
      function()
	 ctx.screen_graphics:render()
      end, 1/16, -1)

   ctx.grid_metro = metro.init(
      function()
	 ctx.grid_graphics:render()
      end,
      1/60, -1
   )

   ctx.visual_metro:start()
   ctx.grid_metro:start()

   print('norkria launched successfully')
end

function redraw()
   ctx:redraw()
end

function key(n,d) ctx:key(n,d); redraw() end
function enc(n,d) ctx:enc(n,d); redraw() end

function clock.transport.start()
   ctx.data:set_global_val('playing', 1)
   ctx:post('play')
end

function clock.transport.stop()
   ctx.data:set_global_val('playing', 0)
   ctx:post('stop')
end

function cleanup()
   norns.state.context.nkria = nil
end
