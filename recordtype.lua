---- -*- Mode: Lua; -*- 
----
---- recordtype.lua   (a 2017 reimplementation of recordtype.lua)
----
---- Inspired by the define-record Scheme macro by Jonathan Rees, and the Art of the Meta-Object
---- Protocol.  Records are simple objects, and the recordtype module is sort of prototype-based.
----
---- (c) 2009, 2010, 2015, 2017 Jamie A. Jennings

--[[

DESCRIPTION:

A record has a fixed set of string keys that can hold any value; new keys cannot be added.
Records are implemented using Lua tables, and specified using a prototype, which is a table
containing all of the valid keys and their default values.  E.g.

    NIL = recordtype.NIL
    bintree = recordtype.new("BinaryTree", {value="anonymous", left=NIL, right=NIL})

The table argument to recordtype.new() is a prototype.  It declares all of the keys for the new
record type, and it establishes their default values.  Because a key with a nil value in a Lua
table is indistinguishable from a missing key, a record prototype cannot contain nil values.  The
value recordtype.NIL is provided for use in prototypes, and causes nil to be the default value.

Record types, like bintree, support the following operations:
    bintree.new()           create a new instance with default values
    bintree.new(template)   create a new instance with values from template and defaults
    bintree.is(obj)         returns true if obj was created via bintree.new()

    Access values using regular Lua table accessors, e.g. obj.x and obj["x"] return the value of
    key "x" in the record stored in the variable obj.  AN EXCEPTION IS RAISED when the key, x, is
    not one of the fixed pre-defined keys for obj.

    Set values using regular Lua table mechanisms, e.g. obj.x=9 and obj["x"]=9 both set the value
    of key "x" to 9 in the record stored in the variable obj.  AN EXCEPTION IS RAISED when the
    key, x, is not one of the fixed pre-defined keys for obj.

E.g.
    > b = bintree.new()
    > b.value
    anonymous
    > b
    <BinaryTree 0x7fd18542a3e0>
    > bintree.is(b)
    true
    > recordtype.is(bintree)
    true
    > recordtype.is(b)
    false
    > b.val
    stdin:1: recordtype: invalid key 'val' for type BinaryTree
    stack traceback: [snip]

The default object factory, invoked with bintree.new(), takes an optional template as an
argument.  The template is used to initialize keys to values other than their defaults.

    > b1 = bintree.new{value="The Root Node"}
    > b1.value
    The Root Node
    > b1.left
    nil
    > 

It is often more clear and convenient to specify a custom interface for creating new
records.  For example, a 3-argument creator for binary trees, like new(value, left, right).

The recordtype.new() function takes an optional third argument which is a custom object creator.
When bintree.new(...) is called, your function is called with one additional argument, the parent
object.  Calling parent.factory(t) is the equivalent of 'super()' in other OO systems. Here, t is
an optional template holding any desired non-default initial values.

   bintree2 = recordtype.new("BinaryTree", {value=NIL, left=NIL, right=NIL},
			     function(parent, val, l, r)
				-- validation of val, l, r can happen here
				return parent.factory{value=val, left=l, right=r}
			     end )
   new = bintree2.new

   b2 = new("Root", 
	    new("Root->Left",
		nil,
		new("Root->Left->Right")))


The regular Lua 'pairs' function will iterate over the fields of a record, e.g.
			      
    > for k,v in pairs(b2) do print(k,v) end
    left	<BinaryTree 0x7fd18541f240>
    value	Root
    > 

Finally, there are some functions defined in recordtype that may be useful.  These functions can
be applied to any Lua object, and non-nil values will be returned for objects created by the
recordtype module.

    recordtype.parent(obj)    -- return the parent object (the unique "type") for obj
    recordtype.typename(obj)  -- return the pretty type name for obj

E.g.
    > recordtype.typename(b)
    BinaryTree
    > recordtype.typename(bintree)
    recordtype
    > recordtype.typename(recordtype)
    recordtype root
    > recordtype.parent(b)
    <recordtype 0x7fd1854345d0>
    > recordtype.parent(b) == bintree
    true
    > recordtype.parent(bintree)
    <recordtype root 0x7fd185606270>
    > recordtype.parent(bintree) == recordtype
    true
    > recordtype.parent(recordtype)
    <recordtype root 0x7fd185606270>
    > recordtype.parent(recordtype) == recordtype
    true
    >     


OBJECTIVES:

(1) Without records, a typo in a table key results in retreiving a nil value or setting the wrong
key.  Such errors cause bugs to appear far from the site of the typo.

(2) When debugging, a table looks like a table, e.g. "table: 0x7fb008603440".  It is useful to
know unambiguously what this table is supposed to be, e.g. "<BinaryTree 0x7fd185431450>".

(3) Using plain tables instead of records, it is easy to forget to initialize all the keys, or to
miss a key due to a typo.  Records ensure this cannot happen.

LIMITATIONS:

* The Lua 'next' function will iterate over an entire object, exposing the internal
  representation. Use 'pairs'. 

* As is commonly the case, using rawset and rawget will also break the abstraction.


--]]

---------------------------------------------------------------------------------------------------
-- Cache globals for code that might run under sandboxing 
--
local assert= assert
local string= string
local pairs= assert( pairs )
local error= assert( error )
local getmetatable= assert( getmetatable )
local setmetatable= assert( setmetatable )
local rawget= assert( rawget )
local rawset= assert( rawset )
local tostring = assert( tostring )
local print = assert( print )
local type = assert( type )
local pcall = assert( pcall )

local ABOUT= 
{
    author= "Jamie A. Jennings",
    description= "Provides records implemented as tables with a fixed set of keys",
    license= "MIT/X11",
    copyright= "Copyright (c) 2009, 2010, 2015, 2017 Jamie A. Jennings",
    version= "2.0",
    lua_version= "5.3"
}

local function err(str)
   error("recordtype: " .. str, 3)
end

-- All instances derived from a parent have the same metatable
local function make_is_instance_function(metatable)
   assert(type(metatable)=="table")
   return function(obj) return (getmetatable(obj)==metatable); end
end

local function index(self, key)
   local mt = getmetatable(self)
   if mt.proto[key] then return nil;
   else err("invalid key '" .. tostring(key) .. "' for type " .. mt.typename); end
end

local function newindex(self, key, value)
   local mt = getmetatable(self)
   if mt.proto[key] then rawset(self, key, value)
   else err("invalid key '" .. tostring(key) .. "' for type " .. mt.typename); end
end

-- We need a unique value known only to the recordtype implementation.  In Lua, an empty
-- table is a fresh object that is not == to any other object.
local ID = {}					    -- index of object unique id

local function compute_id_string(self)
   if type(self)~="table" then return nil; end
   local id_object = rawget(self, ID)
   if not id_object then return nil; end
   return tostring(id_object):match("(0x%x+)") or "id/error"
end

local function instance_tostring(self)
   local mt = getmetatable(self)
   return "<" .. mt.typename .. ": " .. compute_id_string(self) .. ">"
end

-- It is not possible to declare a constant table in Lua in which a key has the value nil.  So, we
-- provide a stand-in value for users to put in prototype tables.  We automatically convert the
-- value to an actual stored nil.

local NIL = setmetatable({}, {__tostring = function (self) return("<recordtype NIL>"); end; })

local root = {}					    -- the primordial object
local root_id = 0
local root_typename = "recordtype root"		    -- to visually distinguish the root object

local function field_next(self, optional_key)
   local key = optional_key
   repeat key = next(self, key) until key==nil or type(key)=="string"
   if key~=nil then return key, rawget(self, key)
   else return nil; end
end

local function field_pairs(self)
   return field_next, self, nil
end

local function make_instance_metatable(parent, typename, proto)
   return { __index=index,
	    __newindex=newindex,
	    __tostring=instance_tostring,
	    __pairs=field_pairs,
	    parent = parent,
	    typename = typename,
	    proto = proto }
end

local function object_factory(parent, typename, proto)
   if type(typename)~="string" then err("typename not a string: " .. tostring(typename)); end
   for k,v in pairs(proto) do
      if type(k)~="string" then err("prototype key not a string: " .. tostring(k)); end
   end
   local metatable = make_instance_metatable(parent, typename, proto)
   local proto_len = 0
   for k,v in pairs(proto) do proto_len = proto_len + 1; end
   local function creator(data)
      data = data or {}
      local data_len = 0
      local nils
      for k,v in pairs(data) do
	 data_len = data_len + 1
	 if rawget(proto, k)==nil then
	    err("invalid key '" .. tostring(k) .. "' for type " .. typename)
	 end
	 if v==NIL then if not nils then nils = {}; end; table.insert(nils, k); end
      end -- for
      if data_len < proto_len then
	 for k,v in pairs(proto) do
	    if rawget(data, k)==nil and v~=NIL then rawset(data, k, v); end
	 end
      end
      if nils then for _,k in ipairs(nils) do rawset(data, k, nil); end; end
      data[ID] = {}				    -- a unique object
      return setmetatable(data, metatable)
   end -- function creator
   return creator, metatable
end

-- All recordtypes, which are created by recordtype.new(...), have these keys:
local recordtype_prototype = {new = NIL,
			      is = NIL,
			      factory = NIL }

-- The primordial object has these additional keys:
local root_prototype = {typename = NIL,
			id = NIL,
			parent = NIL,
			NIL = NIL,
		        ABOUT = ABOUT }

for k,v in pairs(recordtype_prototype) do root_prototype[k] = v; end
   
local function copy(tbl)
   local new = {}
   for k,v in pairs(tbl) do new[k] = v; end
   return new
end

local function new_recordtype(parent, typename, prototype, init_function)
   if type(typename)~="string" then err("typename not a string: " .. tostring(typename)); end
   prototype = prototype or {}
   for k,v in pairs(prototype) do
      if type(k)~="string" then err("prototype key not a string: " .. tostring(k)); end
   end
   init_function = init_function or function(parent, ...) return parent.factory(...); end
   local rt = parent.factory(copy(recordtype_prototype))
   local metatable
   rt.factory, metatable = object_factory(rt, typename, prototype)
   rt.is = make_is_instance_function(metatable)
   rt.new = function(...) return init_function(rt, ...); end
   return rt
end

-- The primordial object has itself as a parent.  Consequently, it is awkward to create.  However,
-- we only have to do this once.

--rawset(root, ID, root_id)		    -- needed for parent() to work
local root_factory, root_metatable = object_factory(root, root_typename, root_prototype)
root = {factory = root_factory}
--setmetatable(root, {typename = root_typename, next_id=1000})

local rp2 = {}
for k,v in pairs(root_prototype) do if k~=ID then rp2[k]=v; end; end
root = new_recordtype(root, "recordtype", rp2)
--root[ID] = root_id
--setmetatable(root, root_metatable) -- make recordtype.is(recordtype) be true

--rawset(root, ID, root_id)		    -- yes, this needs to be set again
--rawset(root, PARENT, root)

-- The primordial object has a new() function that creates new record types
function root.new(typename, prototype, init_function)
   return new_recordtype(root, typename, prototype, init_function)
end

local function attribute_getter(attribute)
   return function(obj)
	     if type(obj)=="table" then
		local mt = getmetatable(obj)
		if mt then return mt[attribute]; end
	     end
	  end
end

root.typename = attribute_getter("typename")
root.parent = attribute_getter("parent")
root.id = compute_id_string
root.NIL = NIL

return root


---------------------------------------------------------------------------------------------------
-- To do:

-- Maybe keep a list of defined type names, and print a warning when redefining an existing type
-- name.  This can happen during development and it is not easily observed.

-- Consider supporting a weak population of instances for each type.

---------------------------------------------------------------------------------------------------
