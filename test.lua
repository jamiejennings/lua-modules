---- -*- Mode: Lua; -*-                                                                           
----
---- test.lua     functions for lightweight testing of lua code
----
---- © Copyright Jamie A. Jennings 2016, 2017.
---- LICENSE: MIT License (https://opensource.org/licenses/mit-license.html)
---- AUTHOR: Jamie A. Jennings

-- ---------------------------------------------------------------------------------------------------
-- A file of Lua code that performs tests can call the following functions, which label and track
-- the results:
--
-- test.start(filename, msg) Associate subsequent tests with filename, which defaults to the file
--                           that calls test.start().  Prints the optional msg argument.
--
-- test.heading(str)         Associate subsequent tests with a category called str
-- test.subheading(str)      Associate subsequent tests with a subcategory called str
--
-- return test.finish(msg)   Print a summary of which tests failed, and a count of tried/passed/failed
--                           and return the results in case the caller is tracking them (see below).
--                           Finally, print the optional msg argument.
--
-- ---------------------------------------------------------------------------------------------------
-- Some convenience functions are provided for running multiple files of tests:
--
-- test.dofile(file_name)    This is dofile(file_name), but it saves the results in test.results
--
-- test.print_grand_total()  Adds up the totals across all files, and prints the result
--
-- ---------------------------------------------------------------------------------------------------
-- Additional functions that are available:
-- 
-- test.reset()              Reset all counts and labels
-- test.current_filename()   Returns the filename that called this function
-- ---------------------------------------------------------------------------------------------------

local debug = require "debug"
local io = require "io"

local ok, tc = pcall(require, "termcolor")
if not ok then
   tc = setmetatable({}, {__index = function(self, key)
				       return function(x) return x; end
				    end })
end

local function color_write(color, ...)
   for _,v in ipairs({...}) do
      io.write(tc[color](v))
   end
end

local function red_write(...)
   local str = ""
   for _,v in ipairs({...}) do str = str .. tostring(v); end
   color_write("red", str)
end

local function green_write(...)
   local str = ""
   for _,v in ipairs({...}) do str = str .. tostring(v); end
   color_write("green", str)
end

test = {}

function test.current_filename()
   return (debug.getinfo(2).source)
end

local function caller_filename()
   return (debug.getinfo(3).source)
end

local test_filename, count, fail_count, heading_count, subheading_count, messages
local current_heading, current_subheading

local function setup()
   test_filename = nil
   count = 0
   fail_count = 0
   heading_count = 0
   subheading_count = 0
   messages = {}
   current_heading = "No heading"
   current_subheading = ""
end

function test.start(optional_filename, optional_msg)
   setup()
   test_filename = optional_filename or caller_filename()
   io.write("Entering ", test_filename, "\n");
   if optional_msg then io.write(optional_msg, "\n"); end
end

function test.check(thing, message, level)
   level = level or 0
   local context = debug.getinfo(2+level, 'lS')
   local line, src = context.currentline, context.short_src
   count = count + 1
   heading_count = heading_count + 1
   subheading_count = subheading_count + 1
   if not (thing) then
      red_write("X")
      table.insert(messages, {h=current_heading or "Heading unassigned",
			      sh=current_subheading or "",
			      shc=subheading_count,
			      hc=heading_count,
			      c=count,
			      l=line,
			      src=src,
			      m=message or ""})
      fail_count = fail_count + 1
   else
      io.write(".")
   end
end

function test.heading(label)
   heading_count = 0
   subheading_count = 0
   current_heading = label
   current_subheading = ""
   io.write("\n", label, " ")
end

function test.subheading(label)
   subheading_count = 0
   current_subheading = label
   io.write("\n\t", label, " ")
end

local function summarize(label, count, fail_count)
   label = label or "TOTAL"
   local total = "\n\n** " .. label .. ": " .. tostring(count) .. " tests attempted.\n"
   if fail_count == 0 then
      green_write(total)
      green_write("** All tests passed.\n")
   else
      io.write(total)
      io.write("** ", tostring(fail_count), " tests failed\n")
   end
end

function test.finish(optional_msg)
   summarize("TOTAL", count, fail_count)
   for _,v in ipairs(messages) do
      red_write(v.src, ":", v.l, " ", v.h, ": ", v.sh, ": ", v.m, "\n")
   end
   if optional_msg then io.write(optional_msg, "\n"); end
   -- return everything in case the caller wants to compute a grand total
   return test_filename, count, fail_count, heading_count, subheading_count, messages
end

---------------------------------------------------------------------------------------------------
-- Running multiple files of tests
---------------------------------------------------------------------------------------------------
test.results = {}

function test.dofile(fn)
   local doer, err = loadfile(fn)
   if not doer then error("test: error loading test file: " .. tostring(err)); end
   table.insert(test.results, {fn, doer()})
end		   
      
function test.reset()
   test.results = {}
   setup()
end

-- Example:
--   test.dofile(ROSIE_HOME .. "/test/api-test.lua")
--   test.dofile(ROSIE_HOME .. "/test/rpl-core-test.lua")
--   passed = test.print_grand_total(results)
--   if passed then ... 

function test.print_grand_total()
   local results = test.results
   local SHORTFILE, FULLFILE, COUNT, FAILCOUNT = 1, 2, 3, 4
   local count, failcount = 0, 0
   io.write('\n')
   for _,v in ipairs(results) do
      if #v<=2 then
	 io.write("File " .. v[1] .. " did not report results\n")
      else
	 count = count + v[COUNT]
	 failcount = failcount + v[FAILCOUNT]
      end
   end -- for
   summarize("GRAND TOTAL", count, failcount)
   return (failcount==0)
end

return test
