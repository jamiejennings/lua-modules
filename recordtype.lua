---- -*- Mode: Lua; -*- 
----
---- recordtype.lua   (a 2017 reimplementation of recordtype.lua)
----
---- Inspired by the define-record Scheme macro by Jonathan Rees, and the Art of the Meta-Object
---- Protocol.  Records are simple objects, and the recordtype module is prototype-based.
----
---- (c) 2009, 2010, 2015, 2017 Jamie A. Jennings

-- DESCRIPTION:
--
-- A record is a Lua table that has the record_metatable.  A record has a fixed set of string keys
-- that can hold any value; new keys cannot be added.  This recordtype module provides:
--
-- Create new record types
--     rt = recordtype.NIL
--     bintree = recordtype.new("BinaryTree", {value=rt_nil, left=rt_nil, right=rt_nil})
-- 
-- New record types like bintree support the following operations:
--
--     b = bintree.new{value="the root node"}
-- 
-- The default object factory takes a template as an argument, e.g.
-- 
--     b = bintree.new{value="the root node"}
--
-- But often it is more clear and convenient to specify a custom interface for creating new
-- records.  For example, a 3-argument creator for binary trees like new(value, left, right).


-- Access values using regular Lua table accessors, e.g. obj.x and obj["x"] return the
-- value of key "x" in the record stored in the variable obj.
--
-- Set values using regular Lua table mechanisms, e.g. obj.x=9 and obj["x"]=9 both set the value
-- of key "x" to 9 in the record stored in the variable obj.
--
-- Iterate over the fields in a record using the regular Lua 'pairs' function.
--
-- ast.is(x) returns true when x is an instance of the record type stored in the variable ast.
--
-- ast.new(...) creates a new instance of the ast record type
--

--
-- recordtype.parent(...) 
-- recordtype.is(...) 
-- recordtype.typename(...) 
--


--
-- OBJECTIVES:
--
-- (1) Without records, a typo in a table key results in a nil value instead of an error.  The
-- nil value propagates until (possibly) an exception is raised far from the site of the typo.
--
-- (2) When debugging, a table looks like a table, e.g. "table: 0x7fb008603440".  It's useful to
-- know unambiguously what this table is supposed to be, e.g. "parser 0x7f8558f1c200"
--
-- (3) When creating an "object" using a table, it is easy to forget to initialize all the keys,
-- or to miss a key due to a typo.  Records ensure this cannot happen.
--
-- LIMITATIONS:
--
-- The Lua 'next' function will iterate over an entire object, exposing the internal representation.
-- As with other Lua "objects", rawset and rawget also break the abstraction.
-- 

---------------------------------------------------------------------------------------------------
-- 
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

local function make_setter(typename, proto)
   return function(self, key, value)
	     if rawget(proto, key) then rawset(self, key, value)
	     else err("invalid key '" .. tostring(key) .. "' for type " .. typename); end
	  end
end

local function make_getter(typename, proto)
   return function(self, key)
	     if rawget(proto, key) then return nil; end
	     err("invalid key '" .. tostring(key) .. "' for type " .. typename)
	  end
end

-- obj is an instance of parent iff the metatable of obj is the one  assigned to all children of parent 
local function make_is_instance_function(metatable)
   assert(type(metatable)=="table")
   return function(obj) return (getmetatable(obj)==metatable); end
end

-- It is not possible to declare a constant table in Lua in which a key has the value nil.  So, we
-- provide a stand-in value for users to put in prototype tables.  We automatically convert the
-- value to an actual stored nil.
local NIL = setmetatable({}, {__tostring = function (self) return("<recordtype NIL>"); end; })

---------------------------------------------------------------------------------------------------

-- Need a set of unique values known only to the recordtype implementation.  In Lua, an empty
-- table is a fresh object that is not = to any other object.

local ID = {}					    -- index of object unique id
local TYPENAME = {}				    -- index of object type name
local PARENT = {}				    -- index of parent object

---------------------------------------------------------------------------------------------------

local root = {}
local root_id = tostring(root):match("(0x%x*)")
local root_typename = "recordtype root"		    -- to visibly distinguish the root object

local function field_next(self, optional_key)
   local key = optional_key
   repeat
      key = next(self, key)
   until key==nil or type(key)=="string"
   if key~=nil then return key, rawget(self, key)
   else return nil; end
end

local function field_pairs(self)
   return field_next, self, nil
end

local function make_instance_metatable(typename, proto)
   return { __newindex = make_setter(typename, proto),
	    __index = make_getter(typename, proto),
	    __tostring = function(self) return "<" .. tostring(rawget(self,TYPENAME)) .. " " .. tostring(rawget(self,ID)) .. ">"
			 end,
	    __pairs = field_pairs }
end

local function object_factory(parent, typename, proto)
   if type(typename)~="string" then err("typename not a string: " .. tostring(typename)); end
   for k,v in pairs(proto) do
      if type(k)~="string" then err("prototype key not a string: " .. tostring(k)); end
   end
   local metatable = make_instance_metatable(typename, proto)
   local function creator(template)
      template = template or {}
      local new = {}
      local idstring = tostring(new):match("(0x%x*)") or "id/error"
      for k,v in pairs(template) do
	 if proto[k]==nil then err("invalid key '" .. tostring(k) .. "' for type " .. typename); end
	 new[k] = v
      end
      for k,v in pairs(proto) do
	 if (not new[k]) and rawget(proto, k)~=NIL then new[k] = v; end
      end
      new[ID] = idstring
      new[TYPENAME] = typename
      new[PARENT] = parent
      return setmetatable(new, metatable)
   end
   return creator, metatable
end

local recordtype_prototype = {new = NIL,
			      is = NIL,
			      factory = NIL }

local root_prototype = {typename = NIL,
			id = NIL,
			parent = NIL,
			NIL = NIL }

for k,v in pairs(recordtype_prototype) do root_prototype[k] = v; end
   
function new_recordtype(parent, typename, prototype, init_function)
   if type(typename)~="string" then err("typename not a string: " .. tostring(typename)); end
   prototype = prototype or {}
   for k,v in pairs(prototype) do
      if type(k)~="string" then err("prototype key not a string: " .. tostring(k)); end
   end
   init_function = init_function or function(parent, template) return parent.factory(template); end
   local rt = parent.factory(recordtype_prototype)
   local metatable
   rt.factory, metatable = object_factory(rt, typename, prototype)
   rt.is = make_is_instance_function(metatable)
   rt.new = function(template) return init_function(rt, template); end
   return rt
end

-- The primordial object has itself as a parent.
local initial_obj = {}
rawset(initial_obj, TYPENAME, root_typename)	    -- needed for parent() to work
rawset(initial_obj, ID, root_id)		    -- needed for parent() to work
initial_obj.factory, initial_obj_metatable = object_factory(initial_obj, root_typename, root_prototype)
setmetatable(initial_obj, initial_obj_metatable) -- make recordtype.is(recordtype) be true
initial_obj = new_recordtype(initial_obj, "recordtype", root_prototype)
rawset(initial_obj, ID, root_id)		    -- yes, this needs to be set again

-- The primordial object has a new() function that creates new record types
function initial_obj.new(typename, prototype, init_function)
   return new_recordtype(initial_obj, typename, prototype, init_function)
end

function attribute_getter(attribute)
   return function(obj)
	     if type(obj)~="table" then return nil
	     else return obj[attribute]; end
	  end
end

initial_obj.typename = attribute_getter(TYPENAME)
initial_obj.id = attribute_getter(ID)
initial_obj.parent = attribute_getter(PARENT)
initial_obj.NIL = NIL

return initial_obj



---------------------------------------------------------------------------------------------------
-- To do:

-- DONE Turn recordtype.new into a prototype-based function that calls make_new_record_function.

-- DONE Ensure that 'pairs' iterates over the keys and not the internal slots.

-- Keep a list of defined type names, and print a warning when redefining an
-- existing type name.

-- Consider supporting a weak population of instances for each type.

---------------------------------------------------------------------------------------------------
