-- -*- Mode: Lua; -*-                                                                             
--
-- test-test.lua
--
-- © Copyright Jamie A. Jennings 2017.
-- LICENSE: MIT License (https://opensource.org/licenses/mit-license.html)
-- AUTHOR: Jamie A. Jennings

-- DO NOT ADD LINES TO THIS FILE WITHOUT ADJUSTING THE LINE NUMBERS IN THE EXPECTED OUTPUT

-- Lua 5.3.2  Copyright (C) 1994-2015 Lua.org, PUC-Rio
-- > test = require "test"
-- > dofile "test-test.lua"

expected_output_with_color = [[
Entering @test-test.lua
This is an optional message for the start of testing.

First, some tests that we expect to pass ..
Tests expected to fail [31mX[39m[31mX[39m

** TOTAL: 4 tests attempted.
** 2 tests failed
[31mtest-test.lua:68 Tests expected to fail: : False means the test failed
[39m[31mtest-test.lua:69 Tests expected to fail: : Module 'test' not a function (which is the right answer)
[39m@test-test.lua	4	2	2	2	table: 0x7fcfcc40b3e0	
]]

expected_output_without_color = [[
This is an optional message for the start of testing.

First, some tests that we expect to pass ..
Tests expected to fail XX

** TOTAL: 4 tests attempted.
** 2 tests failed
test-test.lua:68 Tests expected to fail: : False means the test failed
test-test.lua:69 Tests expected to fail: : Module 'test' not a function (which is the right answer)
@test-test.lua	4	2	2	2	table: 0x7fcfcc40b3e0	
]]

expected_output = nil

local ok = pcall(require, "termcolor")
if ok then
   expected_output = expected_output_with_color
else
   expected_output = expected_output_without_color
end

io = require "io"
local tmpfile = io.tmpfile()
io.output(tmpfile)

test = require "test"

local check = test.check

test.start(nil, "This is an optional message for the start of testing.")

test.heading("First, some tests that we expect to pass")

check(type(test)=="table", "Module 'test' not a table")
check(1 and 2 and true and "Hi", "Random expression evaluates to a true value")

test.heading("Tests expected to fail")

check(false, "False means the test failed")
check(type(test)=="function", "Module 'test' not a function (which is the right answer)")

-- normally this is: return test.finish()
-- but we are going to test the test output after test.finish() runs.
local retvals = {test.finish()}

---------------------------------------------------------------------------------------------------
-- Test the output of the test of the test functions
---------------------------------------------------------------------------------------------------

for _, v in ipairs(retvals) do io.write(tostring(v), "\t"); end
io.write('\n')
io.flush(tmpfile)

io.output(io.stdout)
tmpfile:seek("set", 0)				    -- rewind
a = tmpfile:read("a")
tmpfile:close()

print(a)
assert(a:sub(-23,-15)=="table: 0x")
assert(expected_output:sub(-23,-15)=="table: 0x")

local function mismatch(str1, str2)
   local a_chars = {string.byte(str1, 1, #str1)}
   local exp_chars = {string.byte(str2, 1, #str2)}
   for i, c in ipairs(a_chars) do
      if c ~= exp_chars[i] then return i; end
   end
end

-- The table printed at the end will have a different unique id each time, so we strip it off.
if a:sub(1,-15)==expected_output:sub(1,-15) then
   print("PASSED: Output of test matched expectations")
else
   print("FAILED: Output of test did NOT match expectations")
   local i = mismatch(a, expected_output)
   print("Mismatch occurs at position " .. tostring(i))
   print("  actual output at the mismatch: " .. a:sub(i, i+40) .. "...")
   print("  expected output at the mismatch: " .. expected_output:sub(i, i+40) .. "...")
end
