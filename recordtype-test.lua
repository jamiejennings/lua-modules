---- -*- Mode: Lua; -*- 
----
---- test functions for recordtype.lua
----
---- (c) 2009, 2015, 2017 Jamie A. Jennings

recordtype = require("recordtype")

assert (recordtype.is(recordtype))

-- These are applicable to all objects made by recordtype:
assert (recordtype.typename and type(recordtype.typename)=="function")
assert (recordtype.id and type(recordtype.id)=="function")
assert (recordtype.parent and type(recordtype.parent)=="function")
assert (recordtype.tostring and type(recordtype.tostring)=="function")
assert (recordtype.NIL)

-- Sanity checks that should pass for all objects made by recordtype:
function object_test(obj)
   assert (type(obj)=="table")
   assert (tonumber(tostring(obj):match("(0x%x*)")))
   assert (recordtype.typename(obj))
   assert (recordtype.id(obj))
   assert (recordtype.parent(obj))
   assert (type(recordtype.id(obj))=="string")
   assert (tostring(obj):match(recordtype.id(obj)))
   assert (tonumber(recordtype.id(obj):match("(0x%x+)")))
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
recordtype_test(window)
assert (recordtype.typename(window) == "recordtype")
assert (recordtype.is(window))          

w1 = window.new()

object_test(w1)
assert (window.is(w1))
assert (not recordtype.is(w1))
assert (recordtype.typename(w1) == "window")
assert (tostring(w1):sub(1,11)=="<window: 0x")
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

door = recordtype.new("Door", {color="black", handed="left", lock=recordtype.NIL})
recordtype_test(door)
assert (recordtype.typename(door) == "recordtype")

d1 = door.new()

assert (door.is(d1))
assert (recordtype.typename(d1) == "Door")

assert (not recordtype.is(d1))
assert (not window.is(d1))
assert (not door.is(w1))

assert (d1.handed == "left")
assert (d1.color == "black")
assert (d1.lock == nil)

d1.color = "red"
d1.lock = "bolt"

assert (d1.handed == "left")
assert (d1.color == "red")
assert (d1.lock == "bolt")

d1.color = nil
assert (d1.color == nil)

d2=door.new({handed="right"})
assert (d2.handed == "right")

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
   index, value = next(w1, index)
   -- skip the internal implementation slots, which have non-string keys
   if type(index)=="string" then
      if validate_w1(index, value) then count = count + 1; end
   end
until index==nil

-- 3 calls return values, and validate_w1 returns true for those
assert (count == 3)

count = 0
for k,v in pairs(w1) do
   if validate_w1(k,v) then count = count + 1; end
end
assert (count == 3)

-- FROM THE DOCUMENTATION:
NIL = recordtype.NIL
bintree = recordtype.new("BinaryTree", {value="anonymous", left=NIL, right=NIL})
b1 = bintree.new()
assert(b1.value=="anonymous")
b1 = bintree.new{value=NIL}
assert(b1.value==nil)
b1.value = 555
assert(b1.value==555)
b1.value = nil
assert(b1.value==nil)
-- NIL is meant (and needed) only for templates, not for regular assignment statements
b1.value = NIL
assert(b1.value==NIL)

b = bintree.new{value="the root node"}
assert (recordtype.is(bintree))
assert (bintree.is(b))
assert (b.value == "the root node")
assert ((b.left == b.right) and (b.left == nil))

b.left = bintree.new{value="root->left", right=bintree.new{value="root->left->right"}}
assert (b.right == nil)   			    -- no change
assert (b.left.value == "root->left")   	    -- new node
assert (b.left.right.value == "root->left->right")   
assert (b.left.left == nil)

function walk(tree, nodelist)
   nodelist = nodelist or {}
   if tree then
      walk(tree.left, nodelist)
      table.insert(nodelist, tree.value)
      walk(tree.right, nodelist)
   end
   return nodelist
end

ls = walk(b)
assert (ls[1]=="root->left")
assert (ls[2]=="root->left->right")
assert (ls[3]=="the root node")

bintree3 = recordtype.new("BinaryTree3",
			  {value=NIL, left=NIL, right=NIL},
			  function(val, l, r)
			     -- validation of val, l, r can happen here
			     return bintree3.factory{value=val, left=l, right=r}
			  end,
			  function(self) 
			     return recordtype.typename(self) .. "/" .. recordtype.id(self)
			  end)

new = bintree3.new
b3 = new("Root",
	 new("Root->Left",
	     nil,
	     new("Root->Left->Right")))

assert(tostring(b3):match("^BinaryTree3/0x"))
assert(recordtype.tostring(b3):match("^<BinaryTree3: 0x"))
ls = walk(b3)
assert (ls[1]=="Root->Left")
assert (ls[2]=="Root->Left->Right")
assert (ls[3]=="Root")


---------------------------------------------------------------------------------------------------
-- More with custom initializers
---------------------------------------------------------------------------------------------------




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
