---- -*- Mode: Lua; -*- 
----
---- test functions for recordtype.lua
----
---- (c) 2009, 2015, 2017 Jamie A. Jennings

recordtype = require("recordtype")

-- These are applicable to all objects made by recordtype:
assert (recordtype.typename and type(recordtype.typename)=="function")
assert (recordtype.id and type(recordtype.id)=="function")
assert (recordtype.parent and type(recordtype.parent)=="function")
assert (recordtype.NIL)

-- Sanity checks that should pass for all objects made by recordtype:
function object_test(obj)
   assert (type(obj)=="table")
   assert (tonumber(tostring(obj):match("(0x%x*)")))
   assert (recordtype.typename(obj))
   assert (recordtype.id(obj))
   assert (recordtype.parent(obj))
   assert (tonumber(recordtype.id(obj):match("(0x%x*)")))
end

-- Sanity checks that should pass for all recordtypes, including recordtype itself
function recordtype_test(rt_obj)
   object_test(rt_obj)
   assert (rt_obj.new and type(rt_obj.new)=="function")
   assert (rt_obj.is and type(rt_obj.is)=="function")
   assert (rt_obj.factory and type(rt_obj.factory)=="function")
end

recordtype_test(recordtype)
assert (recordtype.typename(recordtype) == "recordtype root")

window = recordtype.new("window", {width=100, height=400, color="red"})
recordtype_object_test(window)
assert (recordtype.typename(window) == "recordtype")
assert (recordtype.is(window))          

w1 = window.new()

object_test(w1)
assert (window.is(w1))
assert (not recordtype.is(w1))
assert (recordtype.typename(w1) == "window")
assert (tostring(w1):sub(1,10)=="<window 0x")
assert (tostring(w1):sub(-1)==">")

assert (w1.width == 100)
assert (w1.height == 400)
assert (w1.color == "red")

w1.color="blue"
assert (w1.color == "blue")

w1.width = nil
assert (w1.width==nil)
w1.width = 99
assert (w1.width==99)

ok, msg = pcall(function() print(w1.foo); end)
assert (not ok)
assert (msg:find("invalid key"))

ok, msg = pcall(function() w1.foo=123; end)
assert (not ok)
assert (msg:find("invalid key"))

ok, val = pcall(recordtype.id)			    -- no argument ==> error
assert  (ok and val==nil)
ok, val = pcall(recordtype.id, {})		    -- argument not recordtype object ==> error
assert (ok and val==nil)
ok, val = pcall(recordtype.id, w1)		    -- argument not recordtype instance ==> error
assert (ok and tonumber(val))

assert (tonumber(recordtype.id(window)))
assert (tonumber(recordtype.id(w1)))
assert (recordtype.id(window) ~= recordtype.id(w1))

function validate_w1(k, v)
   if k=="color" then assert(v=="blue"); return true
   elseif k=="width" then assert(v==99); return true
   elseif k=="height" then assert(v==400); return true
   elseif k==nil then return false
   else error("Field error!")
   end
end

count = 0
index = nil
repeat
   index, value = window.next_field(w1, index)
   if validate_w1(index, value) then count = count + 1; end
until index==nil

-- 3 calls return values, and validate_w1 returns true for those
assert (count == 3)

count = 0
for k,v in window.fields(w1) do
   if validate_w1(k,v) then count = count + 1; end
end
assert (count == 3)

--[==[

window.create_function = function(cw, c) local w=cw(); w.color=c; return w; end

w2 = window("magenta")
assert (window.is(w2))
assert (w2.color == "magenta")
assert (w2.width == 100)			    -- default value
w2.width = nil
assert (w2.width == nil)
w2.width = 678
assert (w2.width == 678)


door = recordtype.define({color="black", handed="left"}, "door")
assert (type(door)=="table")

d1 = door()

assert (door.is(d1))
assert (door.type() == "door")
assert (recordtype.type(d1) == "door")

assert (window.is(d1) == false)
assert (door.is(w1) == false)

assert (d1.handed == "left")

d2=door({handed="right"})
assert (d2.handed == "right")

door.print = 
   function(self) 
      print("Door record:\ncolor="..self.color.."\nhanded="..self.handed.."\n")
      return 12345
   end

assert (door.print(d2) == 12345)

assert (w1 ~= d1)

d4=d2

assert (d2 == d4)

window.set_slot_function = 
   function(set_slot, self, slot, value)
      if slot=="width" or slot=="height" then 
	 if (value < 1) or (value > 500) then 
	    error("value out of range") 
	 end
      end
      set_slot(self, slot, value)
   end

local test = function() w1.width=333 end
st, err = pcall(test)

assert (st)			-- test expected to succeed
assert (w1.width == 333)

-- this is how we set slot values in this version of recordtype
local test = function() w1.width=999999 end
st, err = pcall(test)

assert (st)
assert (w1.width == 999999)

-- colour is not a valid slot name, so this should generate an error:
local test = function() d1.colour = "canadian red" end
st, err = pcall(test)

assert (not st)			-- test expected to fail

local test = function() return d1.height end
st, err = pcall(test)

assert (not st)			-- test expected to fail


assert (type(window.print)=="function")

st, err = pcall(window.print)
assert (not st)			-- print needs an arg

assert (recordtype.type(w2) == "window")

window.create_function =
   function(cw, kind)
      if (kind==nil) then return cw() -- default
      elseif (kind=='big') then return cw({width=500, height=500})
      elseif (kind=='small') then return cw({width=10, height=20})
      else error("valid args are nil, big, small")
      end
   end

w3 = window()
assert(w3.height==400)		-- default value

w4 = window("big")
assert(w4.height==500)

w5 = window("small")
assert(w5.height==20)

st, err = pcall(window.create, {color="red"})
assert (not st)			-- expected to fail 

original_string_w1 = tostring(w1)
window.tostring_function = function (wts, self) return wts(self).."BAR" end
assert (tostring(w1) == original_string_w1 .. "BAR")

-- each instance is unique, so they should NOT be equal:
assert (window() ~= window())

-- slot names must be strings
st, err = pcall(recordtype.define, {100, 400, "red"}, "window")
assert (not st)			-- expected to fail

--]==]


print("End of tests")
