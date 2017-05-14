-- -*- Mode: Lua; -*-                                                                             
--
-- thread.lua    misc coroutine/thread utilities
--
-- © Copyright Jamie A. Jennings
-- LICENSE: MIT License (https://opensource.org/licenses/mit-license.html)
-- AUTHOR: Jamie A. Jennings


local thread = {}

local co = require("coroutine")

function thread.is(obj)
   return type(obj)=="thread"
end

-- apply f to args until it returns or yields
-- like pcall, return a success code in front of return values
function thread.call(f, ...)
   local t = co.create(f)
   return co.resume(t, ...)
end

function thread.current()
   return co.running()
end

function thread.yield(...)
   if co.isyieldable() then
      co.yield(...)
   else
      return ...
   end
end

-- Thread-local variables are stored on a per-thread basis in a weak table.  When the thread is
-- collected, that thread's vars will be collected on the next gc.
-- 
-- Names are restricted to strings for now, to encourage usage such as:
--    thread.vars.count = 0
--    print(thread.vars.count)

local function get(threadvars, name)
   local locals = rawget(threadvars, (thread.current()))
   return locals and locals[name]
end

local function set(threadvars, name, value)
   if type(name)~="string" then
      error("thread variable name not a string: " .. tostring(name))
   end
   local t = thread.current()
   local locals = rawget(threadvars, t)
   if not locals then
      locals = {}
      rawset(threadvars, t, locals)
   end
   locals[name] = value
end

thread.vars = setmetatable({}, {__mode="k", __index=get, __newindex=set})

return thread
