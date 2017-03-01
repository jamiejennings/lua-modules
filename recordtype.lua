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
local lua_tostring = assert( tostring )
local print = assert( print )
local lua_type = assert( type )
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
local NIL = setmetatable({}, {__tostring = function (self) return("<recordtype nil>"); end; })

---------------------------------------------------------------------------------------------------

-- Need a set of unique values known only to the recordtype implementation.  In Lua, an empty
-- table is a fresh object that is not = to any other object.

local MARK = {}					    -- marks all objects created here
local ID = {}					    -- index of object unique id
local TYPENAME = {}				    -- index of object type name
local PARENT = {}				    -- index of parent object

---------------------------------------------------------------------------------------------------

local root = {}
local root_id = lua_tostring(root):match("(0x%x*)")
local root_typename = "recordtype root"

-- The tostring function looks up the typename so that we can !@#
local function make_instance_metatable(typename, proto)
   return { __newindex = make_setter(typename, proto);
	    __index = make_getter(typename, proto);
	    __tostring = function(self) return "<" .. rawget(self,TYPENAME) .. " " .. rawget(self,ID) .. ">"
			 end
	 }
end

local function object_factory(parent, typename, proto)
   if type(typename)~="string" then err("typename not a string: " .. tostring(typename)); end
   for k,v in pairs(proto) do
      if type(k)~="string" then err("prototype key not a string: " .. tostring(k)); end
   end
   setmetatable(proto, {__newindex = function(...) err("cannot add new keys to prototype"); end})
   local metatable = make_instance_metatable(typename, proto)
   local function creator(template)
      template = template or {}
      local new = {}
      local idstring = lua_tostring(new):match("(0x%x*)") or "id/error"
      for k,v in pairs(template) do
	 if proto[k]==nil then
	    err("invalid key '" .. tostring(k) .. "' for type " .. typename)
	 end
	 if v~=NIL then new[k] = v; end
      end
      for k,v in pairs(proto) do
	 if (not new[k]) and rawget(template, k)~=NIL then new[k] = v; end
      end
      new[MARK] = MARK
      new[ID] = idstring
      new[TYPENAME] = typename
      new[PARENT] = parent
      return setmetatable(new, metatable)
   end
   return creator, metatable
end

local recordtype_prototype = {typename = NIL,
			      id = NIL,
			      new = NIL,
			      is = NIL,
			      metatable = NIL,
			      factory = NIL,
			   }
local root_prototype = {}
for k,v in pairs(recordtype_prototype) do root_prototype[k] = v; end
   
function new_recordtype(parent, typename, prototype, init_function)
   if type(typename)~="string" then err("typename not a string: " .. tostring(typename)); end
   prototype = prototype or {}
   for k,v in pairs(prototype) do
      if type(k)~="string" then err("prototype key not a string: " .. tostring(k)); end
   end
   setmetatable(prototype, {__newindex = function(...) err("cannot add new keys to prototype"); end})
   init_function = init_function or function(parent) return parent.factory(); end
   local rt = parent.factory(recordtype_prototype)
--   local rt_typename = rawget(rt,TYPENAME)
--   rt.typename = function(...) return rt_typename; end
   local rt_idstring = rawget(rt,ID)
   rt.id = function(self) return rt_idstring; end
   rt.factory, rt.metatable = object_factory(parent, typename, prototype)
   rt.is = make_is_instance_function(rt.metatable)
   rt.new = function(...) return init_function(rt, ...); end
   return rt
end

-- The primordial object has itself as a parent.
local initial_obj = {}
initial_obj[PARENT] = initial_obj
initial_obj.factory, initial_obj.metatable = object_factory(initial_obj, root_typename, root_prototype)
initial_obj = new_recordtype(initial_obj, "recordtype", root_prototype)

-- initial_obj now has all the properties of recordtype, including the typename "recordtype".
-- but we want to visibly distinguish the initial object for clarity while debugging.
rawset(initial_obj, TYPENAME, root_typename)

initial_obj.new = function(typename, prototype, init_function)
		     return new_recordtype(initial_obj, typename, prototype, init_function)
		  end
setmetatable(initial_obj, initial_obj.metatable)

return initial_obj




--[==[
-- TODO: trash these numeric indices
local TYPENAME = -1
local MARK = -2

local function read_only_table_error(...) error("read-only table", 2); end

local function recordtype_tostring(self)
   return "<" .. self.type() .. " " .. self.id() .. ">"
end

local function make_recordtype_id_function(kind)
   return function(self)
--             if kind.is(self) then return lua_tostring(self):match("(0x%x*)") or "id/err"
--             else err("argument not an instance of " .. kind.type()); end
	     if self==nil then return "::nil::"
	     else return lua_tostring(self):match("(0x%x*)") or "id/err"; end
	  end
end

local function make_object_creator(typename, proto)
   for k,v in pairs(proto) do
      if type(k)~="string" then err("prototype key not a string: " .. tostring(k)); end
   end
   -- prevent adding new keys after definition, i.e. after we return the new recordtype object
   setmetatable(proto, {__newindex = function(...) err("cannot add new record keys to prototype"); end})
   local metatable = { __newindex = make_setter(proto);
		       __index = make_getter(proto);
		       __tostring = function(self) return "<" .. self.type() .. " " .. self.id() .. ">"; end
		    }
   return function(template)
	     template = template or {}
	     local new = {}
	     for k,v in pairs(template) do
		if not proto[k] then
		   err("invalid key '" .. tostring(k) .. "' for type " .. typename)
		end
		if v~=NIL then new[k] = v; end
	     end
	     for k,v in pairs(proto) do
		if (not new[k]) and rawget(template, k)~=NIL then new[k] = v; end
	     end
	     new[TYPENAME] = typename
	     new[MARK] = recordtype_mark
	     return setmetatable(new, metatable)
	  end
end
   
local recordtype_prototype = 
   { type = function(self) return "recordtype"; end,
     id = function(self) return lua_tostring(self):match("(0x%x*)"); end,
     new = false,
     is = false,
     next_field = true,
     fields = false,
     instance_type = false,
     tostring = false }

local function make_field_next_function(prototype)
   return function(self, optional_key)
	     local key = next(prototype, optional_key)
	     if key~=nil then return key, self[key]
	     else return nil; end
	  end
end

local function make_field_pairs_function(prototype)
   local next_function = make_field_next_function(prototype)
   return function(self) return next_function, self, nil; end
end

local uninitialized_recordtype_creator = make_object_creator("recordtype", recordtype_prototype)

-- TODO: implement recordtype.readonly and maybe other wrappers to use when making a prototype?
-- e.g. {name=recordtype.readonly("anonymous")}

local function recordtype_creator(parent, typename, prototype, uninitialized_instance, init_function)
   print("At the dawn of time...")
   if type(typename)~="string" then err("typename not a string: " .. tostring(typename)); end
   if type(prototype)~="table" then err("prototype not a table: " .. tostring(prototype)); end

   return init_function(uninitialized_instance, typename, prototype, init_function)
end

function initialize_recordtype(rt, typename, prototype, init_function)
   rt.next_field = make_field_next_function(prototype)
   rt.fields = make_field_pairs_function(prototype)
   rt.instance_type = typename
   rt.is = make_is_instance_function(getmetatable(rt))
   local idstring = lua_tostring(getmetatable(rt)):match("(0x%x*)")
   rt.id = function(...) return idstring; end
   local instance_creator = make_object_creator(typename, prototype)
   rt.new = function(...) return init_function(instance_creator(), ...); end

--   function(instance_typename, instance_prototype)
--      return recordtype_creator(recordtype,
--                                instance_typename,
--                                instance_prototype,
--                                make_ob...)
--                    end

--   local new_instance = make_new_record_function(typename, prototype, instance_metatable)--, recordtype_init_function)
--   rectype.new = function(template)
--                    local new = new_instance(template)
--                    return new
--                 end

--   rectype[TYPENAME] = "recordtype " .. typename
--   rectype[MARK] = recordtype_mark
--   record_metatable.__index = rectype
--   -- return a read-only version of the table, in order to prevent accidental changes
--   return setmetatable({}, record_metatable)
--end

   return rt
end

local function init()
   local parent = setmetatable({}, {__index = {}})  -- dummy
   local initial_prototype = {}
   initial_prototype.foo = 7
   for k,v in pairs(recordtype_prototype) do initial_prototype[k] = v; end
   local initial_object = recordtype_creator(parent,
					     "ABC",
					     initial_prototype,
					     make_object_creator("RT", initial_prototype)(),
					     function(...) return ...; end)
   initialize_recordtype(initial_object, "RecordType", initial_prototype, recordtype_creator)
   initial_object.is = make_is_instance_function(getmetatable(initial_object))
   local idstring = lua_tostring(parent):match("(0x%x*)")
   initial_object.id = function(self) return idstring end
   return initial_object
end

return init()
   
---------------------------------------------------------------------------------------------------



function new(typename, prototype) 
   return recordtype_init_function(typename,
				   prototype,
				   recordtype_metatable,
				   record_tostring)
end







return recordtype






local function make_new_record_function(typename, proto, mt, init)
   return function(template)
	     template = template or {}
	     local new = {}
	     for k,v in pairs(template) do
		if not proto[k] then
		   error("Invalid key '" .. tostring(k) .. "' for recordtype " .. typename, 2)
		end
		if v~=recordtype.NIL then new[k] = v; end
	     end
	     for k,v in pairs(proto) do
		if (not new[k]) and rawget(template, k)~=recordtype.NIL then
		   new[k] = v
		end
	     end -- for
--	     if init then initialized_new = init(new); end
	     -- MAYBE do some checks here to make sure that user's init function didn't do
	     -- anything very bad?
--	     if initialized_new ~= new then error("ARGH AKSDLASKDL"); end

	     new[TYPENAME] = typename
	     new[MARK] = recordtype_mark
	     return setmetatable(new, mt)
	  end
end


-- Define a new type of record
--function recordtype.new   (typename, prototype, tostring_function)
--   return recordtype_init_function(typename, prototype, tostring_function)
--end

local recordtype_metatable = { __newindex = read_only_table_error;
			       __index = {};
			       __tostring = record_tostring; }



local id = tostring(recordtype):match("(0x%x*)") or "id/error"
recordtype.id = function(self)
--                   if recordtype.is(self) then return id
--                   else error("recordtype: argument not an instance of recordtype", 2)
--                   end
		   return id
		end

function recordtype.type(obj)
   if type(obj)=="table" and obj[MARK]==recordtype_mark then
      return obj[TYPENAME]
   else
      error("recordtype: argument not a recordtype object: " .. tostring(obj), 2)
   end
end
		     

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

--]==]


---------------------------------------------------------------------------------------------------
-- To do:

-- Turn recordtype.new into a prototype-based function that calls make_new_record_function.

-- Add a method called 'pairs' that returns an iterator over the keys.

-- Keep a list of defined type names, and print a warning when redefining an
-- existing type name.

-- Consider supporting a weak population of instances for each type.

---------------------------------------------------------------------------------------------------
