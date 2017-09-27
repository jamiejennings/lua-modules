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

function thread.current()
   return co.running()
end

-- thread.pcall: apply f to args until it returns or yields
-- like pcall, return a success code in front of return values
function thread.pcall(f, ...)
   local t = co.create(f)
   return co.resume(t, ...)
end

thread.resume = co.resume

local function thread_error(msg, ...)
   error(table.concat({msg, "Values:", ...}, "\n"), 3)
end

function thread.yield(...)
   if co.isyieldable() then
      co.yield(...)
   else
      thread_error("Cannot yield from main thread", ...)
   end
end

---------------------------------------------------------------------------------------------------
-- Basic exceptions
---------------------------------------------------------------------------------------------------

local exception_tag = {__tostring = function(obj) return "<exception>" end}
local function make_exception(...)
   return setmetatable({...}, exception_tag)
end
local function is_exception(obj)
   return (getmetatable(obj) == exception_tag)
end

thread.exception = {new = make_exception,
		    is = is_exception }

function thread.raise(...)
   if coroutine.isyieldable() then
      coroutine.yield(make_exception(...))
   else
      thread_error("Uncaught exception", ...)
   end
end

function thread.throw(...)
   if coroutine.isyieldable() then
      coroutine.yield(...)
   else
      thread_error("Uncaught throw", ...)
   end
end

---------------------------------------------------------------------------------------------------
-- Thread-local storage
---------------------------------------------------------------------------------------------------

-- Thread-local variables are stored on a per-thread basis in a weak table.  When the thread is
-- collected, that thread's vars will be collected on the next gc.
-- 
-- Names are restricted to strings for now, to encourage usage such as:
--    thread.env.count = 0
--    print(thread.env.count)

local function get(threadvars, name)
   local locals = rawget(threadvars, (thread.current()))
   return locals and locals[name]
end

local function set(threadvars, name, value)
   if type(name)~="string" then
      thread_error("thread variable name not a string: " .. tostring(name))
   end
   local t = thread.current()
   local locals = rawget(threadvars, t)
   if not locals then
      locals = {}
      rawset(threadvars, t, locals)
   end
   locals[name] = value
end

thread.env = setmetatable({}, {__mode="k", __index=get, __newindex=set})

return thread
