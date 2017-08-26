-- -*- Mode: Lua; -*-                                                                             
--
-- thread-test.lua
--
-- © Jamie A. Jennings
-- LICENSE: MIT License (https://opensource.org/licenses/mit-license.html)
-- AUTHOR: Jamie A. Jennings


thread = require "thread"

x = thread.current()
assert(x)
assert(thread.is(x))
assert(not thread.is(true))
assert(not thread.is("hi"))
assert(not thread.is(thread))

function maybe_error(val)
   if val == nil then
      return true
   else
      error("value is a " .. type(val))
   end
end

-- Catches lua errors like pcall does
function like_pcall()
   local funcs = {pcall, thread.pcall}
   for _,f in ipairs(funcs) do
      ok, val = f(maybe_error)
      assert(ok)
      assert(val==true)

      ok, val = f(maybe_error, {1})
      assert(not ok)
      assert((type(val)=="string") and val:find("value is"))
   end
end

like_pcall()

-- Beyond pcall/error, catches exceptions as well

function throws_error_object(val)
   if val == nil then
      return true
   else
      thread.raise("value given", val, type(val))
      error("SHOULD NEVER GET HERE")
   end
end

ok, val = thread.pcall(throws_error_object)
assert(ok)					    -- no lua errors
assert(not thread.exception.is(val))
assert(val==true)

val = 55
ok, val1, val2 = thread.pcall(throws_error_object, val)
assert(ok)					    -- no lua errors
assert(thread.exception.is(val1))
assert(val2==nil)
assert(type(val1)=="table")
assert(val1[1] and (type(val1[1])=="string"))
assert(val1[2] and (val1[2]==val))
assert(val1[3] and (type(val1[3])=="string") and (val1[3]==type(val)))

function returns_or_throws(val)
   if val == nil then
      return "value given", val, type(val)
   else
      thread.throw("value given", val, type(val))
      error("SHOULD NEVER GET HERE")
   end
end

ok, val1, val2, val3 = thread.pcall(returns_or_throws)
assert(ok)					    -- no lua errors
assert(not thread.exception.is(val1))
assert(val1=="value given")
assert(val2==nil)
assert(val3=="nil")

val = 996
ok, val1, val2, val3 = thread.pcall(returns_or_throws, val)
assert(ok)					    -- no lua errors
assert(not thread.exception.is(val1))
assert(val1=="value given")
assert(val2==val)
assert(val3==type(val))

function returns_or_yields(val)
   if val == nil then
      return "value given", val, type(val)
   else
      thread.yield("value given", val, type(val))
      error("SHOULD NEVER GET HERE")
   end
end

ok, val1, val2, val3 = thread.pcall(returns_or_yields)
assert(ok)					    -- no lua errors
assert(not thread.exception.is(val1))
assert(val1=="value given")
assert(val2==nil)
assert(val3=="nil")

val = 996
ok, val1, val2, val3 = thread.pcall(returns_or_yields, val)
assert(ok)					    -- no lua errors
assert(not thread.exception.is(val1))
assert(val1=="value given")
assert(val2==val)
assert(val3==type(val))


-- Thread-local storage

assert(thread.env)
thread.env.x = 1
assert(thread.env.x==1)

ok, val = thread.pcall(function() return thread.env.x end)
assert(ok)
assert(val==nil)
assert(thread.env.x==1)

ok, val = thread.pcall(function() thread.env.x = 12345; return "foo" end)
assert(ok)
assert(val=="foo")
assert(thread.env.x==1)

ok, val = thread.pcall(function() thread.env.x = 12345; return thread.env.x end)
assert(ok)
assert(val==12345)
assert(thread.env.x==1)

