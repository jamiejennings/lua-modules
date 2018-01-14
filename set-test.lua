-- -*- Mode: Lua; -*-                                                                             
--
-- set-test.lua
--
-- © Copyright Jamie A. Jennings 2017, 2018.
-- LICENSE: MIT License (https://opensource.org/licenses/mit-license.html)
-- AUTHOR: Jamie A. Jennings

set = require("set")

s1 = set.new()
s2 = set.new()
assert(set.size(s1) == 0)
assert(set.empty(s1))
assert(set.size(s2) == 0)
assert(set.empty(s2))
assert(s1 ~= s2)

set.insert(s1, "a")
assert(set.size(s1) == 1)
assert(not set.empty(s1))
assert(set.contains(s1, "a"))
assert(set.size(s2) == 0)
assert(not set.contains(s2, "a"))

ok, ss = pcall(set.choose, s1, 0)
assert(ok)
assert(set.size(ss) == 0)

ok, ss = pcall(set.choose, s1, 1)
assert(ok)
assert(set.size(ss) == 1)
assert(set.contains(ss, "a"))
assert(set.size(s1) == 0)
assert(not set.contains(s1, "a"))

ok, ss = pcall(set.choose, s1, 1)
assert(not ok)
assert(type(ss) == "string")			    -- error message
assert(ss:find("insufficient"))

set.insert(s1, "b")
set.insert(s1, "a")

set.insert(s2, "b")

assert(set.size(s1) == 2)
assert(not set.empty(s1))
assert(set.size(s2) == 1)
assert(not set.empty(s2))

both = set.intersection(s1, s2)
assert(set.size(both) == 1)
assert(set.contains(both, "b"))
assert(not set.contains(both, "a"))

both = set.intersection(s1, s1)
assert(set.size(both) == 2)
assert(set.contains(both, "a"))
assert(set.contains(both, "b"))

either = set.union(s1, s2)
assert(set.size(either) == 2)
assert(set.contains(either, "a"))
assert(set.contains(either, "b"))

either = set.union(s1, s1)
assert(set.size(either) == 2)
assert(set.contains(either, "a"))
assert(set.contains(either, "b"))

diff = set.difference(s1, s2)
assert(set.size(diff) == 1)
assert(set.contains(diff, "a"))
assert(not set.contains(diff, "b"))

assert(set.size(s1) == 2)
assert(set.size(s2) == 1)

diff = set.difference(s1, s1)
assert(set.size(diff) == 0)


assert(set.size(either)==2)
uu = set.map(function(str) return str .. "?"; end, either)
for e in set.elements(uu) do
   assert(e:sub(2,2)=="?")
end
assert(set.size(uu) == set.size(either))

res = {}
set.foreach(function(e) table.insert(res, e); end, uu)
assert(#res == 2)
assert((res[1] == "a?") or (res[2] == "a?"))
assert((res[1] == "b?") or (res[2] == "b?"))
assert(res[1] ~= res[2])
assert((res[1] ~= "a") and (res[2] ~= "b"))

f1 = set.filter(function(v) return v=="a"; end, s1)
assert(set.size(f1)==1)
assert(set.contains(f1, "a"))
assert(not set.contains(f1, "b"))

f2 = set.filter(function(v) return v=="x"; end, s1)
assert(set.size(f2)==0)
assert(not set.contains(f2, "a"))
assert(not set.contains(f2, "b"))
assert(not set.contains(f2, "x"))

eq = function(i, j) if (i*j) > 0 then return true; else return false; end; end

sign = set.new(nil, eq)
for _, v in ipairs({4, 5, -2, 6, -7}) do
   set.insert(sign, v)
end

assert(set.size(sign)==2)
assert(set.contains(sign, 4))
assert(set.contains(sign, -2))

sign_function = function(x) if x > 0 then return 1; else return -1; end; end
sign2 = set.new(sign_function)
for _, v in ipairs({4, 5, -2, 6, -7}) do
   set.insert(sign2, v)
end

assert(set.size(sign2)==2)
assert(set.contains(sign2, 4))
assert(set.contains(sign2, -2))

eq_funny = function(i, j) return i==1 and j==1; end
sign3 = set.new(sign_function, eq)
for _, v in ipairs({4, 5, -2, 6, -7}) do
   set.insert(sign3, v)
end

assert(set.size(sign3) == 2)
assert(set.contains(sign3, 4))
assert(set.contains(sign3, -2))


