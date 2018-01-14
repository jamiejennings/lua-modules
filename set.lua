-- -*- Mode: Lua; -*-                                                                             
--
-- set.lua   Simple sets
--
-- © Copyright Jamie A. Jennings 2017, 2018.
-- LICENSE: MIT License (https://opensource.org/licenses/mit-license.html)
-- AUTHOR: Jamie A. Jennings

local set = {}

local set_metatable =
   { __tostring = function(s)
		     return "<set " .. tostring(s):sub(8) .. ">"
		  end
  }
   
function set.is(obj)
   return getmetatable(obj) == set_metatable
end

-- optional_equality_function
--    defaults to lua's ==
--    if present, is a function of two elements returning a true value if they are equal
-- optional_value_function
--    defaults to the identity function
--    if present, is a function that extracts the value from an element, where the value can be
--    compared to the value of another element to determine if they are equal
function set.new(optional_value_function, optional_equality_function)
   local value = optional_value_function
   local eq = optional_equality_function
   -- Avoiding higher order functions and lookups here (for efficiency)
   if value then
      if eq then
	 eq_function = function(e1, e2) return eq(value(e1), value(e2)); end
      else
	 eq_function = function(e1, e2) return value(e1) == value(e2); end
      end
   else
      if eq then
	 eq_function = function(e1, e2) return eq(e1, e2); end
      else
	 eq_function = function(e1, e2)
			  return (rawget(s.elements, elt) and true) or false
		       end
      end
   end
   local emptyset =
      { elements = {},
	eq = eq_function,
	value = value,
	simple = (value == nil) and (eq == nil),
	mapped = (value ~= nil) and (eq == nil),
     }
   return setmetatable(emptyset, set_metatable)
end

function set.insert(s, elt)
   if s.simple then
      s.elements[elt] = true
   elseif s.mapped then
      s.elements[s.value(elt)] = elt
   else
      -- fall back to linear time insert
      local eq = s.eq
      for e in set.elements(s) do
	 if eq(e, elt) then return e; end
      end
      table.insert(s.elements, elt)
   end
end

function set.delete(s, elt)
   if s.simple then
      s.elements[elt] = nil
   elseif s.mapped then
      s.elements[s.value(elt)] = nil
   else
      -- fall back to linear time delete
      local eq = s.eq
      for i, e in ipairs(s.elements) do
	 if eq(e, elt) then
	    table.remove(s.elements, i)
	    return
	 end
      end
   end
end

function set.contains(s, elt)
   if s.simple then
      return rawget(s.elements, elt)
   elseif s.mapped then
      return rawget(s.elements, s.value(elt))
   else
      -- fall back to linear search
      local eq = s.eq
      for e in set.elements(s) do
	 if eq(e, elt) then return e; end
      end
      return nil
   end
end

function set.size(s)
   local size = 0
   local elements = s.elements
   local e = next(elements)
   while e do
      size = size + 1;
      e = next(elements, e)
   end
   return size
end
   
function set.empty(s)
   return (set.size(s) == 0)
end

function set.elements(s)
   if s.simple then
      return pairs(s.elements)
   else
      local i = 0
      local next_function =
	 function(list)
	    i = i + 1
	    return list[i]
	 end
      return next_function, s.elements, 0
   end
end

function set.choose(s, n)
   local elts = set.new()
   for e in set.elements(s) do
      if n > 0 then
	 set.insert(elts, e)
	 n = n - 1
      else
	 break
      end
   end
   if n > 0 then error("insufficient elements in set"); end
   for e in set.elements(elts) do
      set.delete(s, e)
   end
   return elts
end

function set.union(s1, s2)
   local u = set.new()
   for e in set.elements(s1) do set.insert(u, e); end
   for e in set.elements(s2) do set.insert(u, e); end
   return u
end

function set.intersection(s1, s2)
   local i = set.new()
   for e in set.elements(s1) do
      if set.contains(s2, e) then
	 set.insert(i, e)
      end
   end
   return i
end

-- s1 - s2
function set.difference(s1, s2)
   local d = set.new()
   for e in set.elements(s1) do
      if not set.contains(s2, e) then
	 set.insert(d, e)
      end
   end
   return d
end

-- limitation: the fn can only return one value.
function set.map(fn, s)
   local results = set.new()
   for e in set.elements(s) do
      set.insert(results, (fn(e)))
   end
   return results
end

-- limitation: the fn can only return one value.
-- returns a new set
function set.filter(fn, s, ...)
   local results = set.new()
   for e in set.elements(s) do
      if fn(e) then set.insert(results, e); end
   end
   return results
end

function set.foreach(fn, s)
   for e in set.elements(s) do
      fn(e)
   end
end

return set


