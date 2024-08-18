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

local mu = require 'musicutil'
local tu = require 'tabutil'
local tab = tu

local defaults = include('lib/defaults')
local ctx = include("lib/context")

ctx:preinit(defaults)

local screen_graphics = include('lib/screen_graphics')
local meta = include('lib/meta')
local transport = include('lib/transport')
local hs = include('lib/dualdelay')
local nb = include("lib/nb/lib/nb")

function init()
   ctx:init()

   function ctx.grid.key(x,y,z) ctx.gkeys:key(x,y,z) end

   nb.voice_count = 4
   nb:init()

   hs.init()

   print('norkria launched successfully')
end

function redraw() ctx.screen_graphics:render() end

function key(n,d) ctx:key(n,d) end
function enc(n,d) ctx:enc(n,d) end

function clock.transport.start()
   ctx.data:set_global_val('playing', 1)
   ctx:post('play')
end

function clock.transport.stop()
   ctx.data:global_set_val('playing', 0)
   ctx:post('stop')
end

function cleanup()
   Data = nil
   norns.state.context.nkria = nil
end
