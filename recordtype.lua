---- -*- Mode: Lua; -*- 
----
---- recordtype.lua   (a 2017 reimplementation of recordtype.lua)
----
---- Inspired by the define-record Scheme macro by Jonathan Rees, and the Art of the Meta-Object
---- Protocol.  Records are simple objects, and the recordtype module is prototype-based.
----
---- (c) 2009, 2010, 2015, 2017 Jamie A. Jennings

---- A record is a Lua table that has the record_metatable.  A record has a fixed set of keys that
---- can hold any value; new keys cannot be added.  This recordtype module provides:
----
---- asdlk asdkla dkalkd asdk
---- akdlak dakslda sdkaslkdl sklasd ksld
----
---- Objectives:
----
---- (1) Without records, a typo in a table key results in a nil value instead of an error.  The
---- nil value propagates until (possibly) an exception is raised far from the site of the typo.
----
---- (2) When debugging, a table looks like a table, e.g. "table: 0x7fb008603440".  It's useful to
---- know unambiguously what this table is supposed to be, e.g. "parser 0x7f8558f1c200"
----
---- (3) When creating an "object" using a table, it is easy to forget to initialize all the keys,
---- or to miss a key due to a typo.  Records ensure this cannot happen.
----

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
local luatype = assert( type )
local pcall = assert( pcall )

local recordtype = {}

recordtype.ABOUT= 
{
    author= "Jamie A. Jennings",
    description= "Provides records implemented as tables with a fixed set of keys",
    license= "MIT/X11",
    copyright= "Copyright (c) 2009, 2010, 2015, 2017 Jamie A. Jennings",
    version= "2.0",
    lua_version= "5.3"
}

local recordtype_mark = {}			    -- marks all objects created here
local UID = 0
local TYPENAME = -1
local MARK = -2

local function make_setter(proto)
   return function(self, key, value)
	     if rawget(proto, key) then
		rawset(self, key, value)
	     else
		error("Invalid key '" .. tostring(key) .. "' for recordtype type " .. self[TYPENAME], 2)
	     end
	  end
end

local function no_new_keys(self, key, value)
   error("Invalid key '" .. tostring(key) .. "' for recordtype type " .. self[TYPENAME], 2)
end

local function make_getter(proto)
   return function(self, key)
	     if rawget(proto, key) then return nil; end
	     error("Invalid key '" .. tostring(key) .. "' for recordtype type " .. self[TYPENAME], 2)
	  end
end

local function invalid_key(self, key)
   error("Invalid key '" .. tostring(key) .. "' for recordtype type " .. self[TYPENAME], 2)
end

local function record_tostring(self)
   if self[TYPENAME] then
      return "<" .. self[TYPENAME] .. " " .. self[UID] .. ">"
   else
      return "<recordtype>"
   end
end

-- Return true if obj is a recordtype type (not a recordtype)
local function make_is_instance_function(metatable)
   assert(type(metatable)=="table")
   return function(obj) return (getmetatable(obj)==metatable); end
end

local function make_new_record_function(rtype)
   return function(template)
	     template = template or {}
	     local proto = rtype.prototype
	     local new = {}
	     for k,v in pairs(template) do
		if not proto[k] then invalid_key(rtype, k); end
		if v~=recordtype.NIL then new[k] = v; end
	     end
	     for k,v in pairs(proto) do
		if (not new[k]) and rawget(template, k)~=recordtype.NIL then
		   new[k] = v
		end
	     end -- for
	     new[UID] = tostring(new):match("(0x.*)") or "id/error"
	     new[TYPENAME] = rtype.instance_type
	     new[MARK] = recordtype_mark
	     return setmetatable(new, rtype.instance_metatable)
	  end
end

local recordtype_metatable = { __newindex = read_only_table_error;
			       __index = {};
			       __tostring = record_tostring; }

local function read_only_table_error(...) error("read-only table", 2); end

-- It is not possible to declare a constant table in Lua in which a key has the value nil.  So, we
-- provide a stand-in value for users to put in prototype tables.  We automatically convert the
-- value to an actual stored nil.
recordtype.NIL =
   setmetatable({}, {__tostring = function (self) return("<recordtype nil>"); end; })

-- Define a new type of record
function recordtype.new(typename, prototype, tostring_function, init_function)
   return new_recordtype_init(typename, prototype, tostring_function)
end

function new_recordtype_init(typename, prototype, tostring_function)
   if type(typename)~="string" then
      error("recordtype: typename not a string: " .. tostring(typename), 2)
   end
   if type(prototype)~="table" then
      error("recordtype: prototype not a table: " .. tostring(prototype), 2)
   end
   for k,v in pairs(prototype) do
      if type(k)~="string" then error("recordtype: key not a string: " .. tostring(k), 2); end
   end
   -- prevent adding new keys after definition, i.e. after we return the new recordtype object
   setmetatable(prototype,
		{__newindex = function(...) error("cannot add new record keys to prototype", 2); end})
   local record_metatable = { __newindex = read_only_table_error;
			      __tostring = record_tostring; }
   local rectype = {type = function(...) return "recordtype"; end;
		    instance_type = typename;
		    prototype = prototype;
		    tostring = tostring_function or false;
		    instance_metatable = { __newindex = make_setter(prototype);
					   __index = make_getter(prototype);
					   __tostring = tostring_function or record_tostring; } }
   rectype.is = make_is_instance_function(rectype.instance_metatable);
   rectype.new = make_new_record_function(rectype)
   rectype[UID] = tostring(rectype):match("(0x.*)") or "id/error"
   rectype[TYPENAME] = "recordtype " .. typename;
   rectype[MARK] = recordtype_mark
   record_metatable.__index = rectype
   -- return a read-only version of the table, in order to prevent accidental changes
   return setmetatable({}, record_metatable)
end

function recordtype.type(obj)
   if type(obj)=="table" and obj[MARK]==recordtype_mark then
      return obj[TYPENAME]
   else
      error("recordtype: argument not a recordtype object: " .. tostring(obj), 2)
   end
end
		     
recordtype.is = make_is_instance_function(recordtype_metatable)

return recordtype

--[[  OLD DOC:

-----------------------------------------------------------------------------
Usage
-----------------------------------------------------------------------------

  A record is a table with a fixed set of keys.  Only those keys can be set,
  and keys can be neither added or deleted.  N.B. No key can have a nil
  value!  Use recordtype.unspecified if you like, or any other value.

  The important function in this module is 'define', which is used to define a
  'recordtype' object with functions to create and work with instances of that
  type.

  To define a record type, you supply a prototype and a pretty name (any
  string).  The prototype is a table whose keys are the slots you want in
  records of this type, and whose values are the default values.
  E.g.
     > window = recordtype.define({width=100, height=400, color="red"}, "window")
     > door = recordtype.define({color="red", handed="left"}, "door")

  Instances are created by calling <recordtype>(...), which can be called
  either with no arguments or a table containing the slots that you wish to
  set.
  E.g.
     > w1=window()
     > print(w1.color, w1.width, w1.height)
     red        100     400
     > w3=window({color="cyan"})
     > print(w3.color, w3.width, w3.height)
     cyan	100	400
     > 

  Important note: When a table is supplied, that table is turned into the
  recordtype instance by setting its metatable.

  Slots are accessed and set using normal Lua table access techniques, i.e.
     > w1.color
     red
     > w1.color="green"
     > w1.color
     green

  You can check if a thing is a record of type <recordtype> by using the
  'is' function in <recordtype>. 
  E.g.
     > =window.is(w1)
     true

  You can obtain the pretty name for the type of a <recordtype> itself or of
  an instance using the type function from the recordtype module.  E.g.

     > =recordtype.type(window)
     window
     > =recordtype.type(w1)
     window
     > 

  You can print the contents of an instance using the convenience function <recordtype.print>,
  which is customizable.

     > window.print(w1)
     color	blue
     width	100
     height	400
     > 

  Lastly, you can often treat an instance like any other table, e.g.

     > for k,v in pairs(w1) do print(k,v) end
     color	blue
     width	100
     height	400
     > 
     > json.encode(w1)
     {"color":"blue","width":100,"height":400}
     > 

-----------------------------------------------------------------------------
Customization:
-----------------------------------------------------------------------------

  The following aspects of record types can be customized:
     <recordtype>.create_function for creating a record instance
     <recordtype>.tostring for converting an instace to a string (tostring)
     <recordtype>.print for printing the contents (slots) of a record

  In the case of creating an instance and converting an instance to a string,
  the custom function you supply will be called with the actual creator and
  the actual tostring function as the first argument.

-----------------------------------------------------------------------------
Details:
-----------------------------------------------------------------------------

  recordtype :== { 

      define(prototype, pretty_type_name, optional_creator) --> <recordtype>
	  --> defines a new <recordtype>, which is a table.  prototype defines
          --> the valid slots and provides default values for them.

      type(thing) --> <string> | nil
	  --> returns the pretty_type_name if thing is a <recordtype> or an
          --> <instance> of any <recordtype>.  otherwise, returns nil.
  }

  <recordtype> :== {  

       <recordtype>() --> <instance>
	   --> creates a new record instance with default values that were
	   --> provided in the prototype when <recordtype> was defined

       <recordtype>(initial_values_table) --> <instance>
	   --> turns initial_values_table into a new record instance, adding
	   --> default values for any missing slots

       <recordtype>.is(thing) --> <boolean>
	   --> predicate returns true if thing is a record of <recordtype>

       <recordtype>.type() --> <string>
	  --> returns the pretty name for the type of <recordtype>

       <recordtype>.tostring_function(instance_tostring, self)
           --> instance_tostring(self) returns a string describing self.  Your
           --> function must also return a string value.

       <recordtype>.create_function(create_instance, ...)
           --> create_instance(...) is used to actually create an instance.
           --> Your custom create_function can do whatever else it wants, but
           --> it must call create_instance in order to get a new instance.
           --> The new instance must be the return value from your function.

       <recordtype>.print(self)
	   --> Prints the data in self as follows:
           -->       for k,v in pairs(self) do print(k,v) end
           --> You can set <recordtype>.print to another function.
  }

]]--


---------------------------------------------------------------------------------------------------
-- To do:

-- Turn recordtype.new into a prototype-based function that calls make_new_record_function.

-- Add a method called 'pairs' that returns an iterator over the keys.

-- Keep a list of defined type names, and print a warning when redefining an
-- existing type name.

-- Consider supporting a weak population of instances for each type.

---------------------------------------------------------------------------------------------------
