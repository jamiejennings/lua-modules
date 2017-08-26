-- -*- Mode: Lua; -*-                                                                             
--
-- strict.lua
--
-- © Copyright Jamie A. Jennings 2017.
-- LICENSE: MIT License (https://opensource.org/licenses/mit-license.html)
-- AUTHOR: Jamie A. Jennings

-- Based on the strict.lua released under the MIT license
-- http://www.lua.org/extras/5.2/strict.lua: 
    -- strict.lua
    -- checks uses of undeclared global variables
    -- All global variables must be 'declared' through a regular assignment
    -- (even assigning nil will do) in a main chunk before being used
    -- anywhere or assigned to inside a function.
    -- distributed under the Lua license: http://www.lua.org/license.html

-- Usage: require('strict')(_G)

local getinfo, error, rawset, rawget = debug.getinfo, error, rawset, rawget

local function make_strict(env)
   local mt = getmetatable(env)
   if mt == nil then
      mt = {}
      setmetatable(env, mt)
   end
   mt.__declared = {}

   local function what ()
      local d = getinfo(3, "S")
      return d and d.what or "C"
   end

   mt.__newindex =
      function (t, n, v)
	 if not mt.__declared[n] then
	    local w = what()
	    if w ~= "main" and w ~= "C" then
	       error("assign to undeclared variable '"..n.."'", 2)
	    end
	    mt.__declared[n] = true
	 end
	 rawset(t, n, v)
      end
  
   mt.__index =
      function (t, n)
	 if not mt.__declared[n] and what() ~= "C" then
	    error("variable '"..n.."' is not declared", 2)
	 end
	 return rawget(t, n)
      end
end

return make_strict
