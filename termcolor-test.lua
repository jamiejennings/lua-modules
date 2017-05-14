-- -*- Mode: Lua; -*-                                                                             
--
-- termcolor-test.lua
--
-- © Copyright Jamie A. Jennings 2017.
-- LICENSE: MIT License (https://opensource.org/licenses/mit-license.html)
-- AUTHOR: Jamie A. Jennings

-- The functions themselves are so trivial that we don't test them here.  (They are merely string
-- concatenation.)  Instead, we test the presence/absence of the right set of functions.

tc = require "termcolor"

colors = { "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white", "default" }
attributes = { "reverse", "bold", "blink", "underline" }
reset_all = "none"

assert(tc.start, "Missing the set of 'start' functions for colors and attributes")
assert(tc.bg, "Missing the set of background functions for colors")
assert(tc.start.bg, "Missing the set of 'start' functions for background colors")

assert(tc.stop, "Missing the set of 'stop' functions for colors and attributes")
assert(tc.stop.bg, "Missing the set of 'stop' functions for colors and attributes")

for _, color in ipairs(colors) do
   assert(tc[color], "Missing the 'wrap' function for color: " .. color)
   assert(tc.start[color], "Missing the 'start' function for color: " .. color)
   assert(tc.stop[color], "Missing the 'start' function for color: " .. color)
   assert(tc.bg[color], "Missing the background function for color: " .. color)
   assert(tc.start.bg[color], "Missing the background 'start' function for color: " .. color)
   assert(tc.stop.bg[color], "Missing the background 'stop' function for color: " .. color)
end

assert(type(tc.start.none)=="function", "Missing the start.none() function")
assert(not rawget(tc.stop, "none"), "A stop.none() function was found, but should not exist")
assert(not rawget(tc.bg, "none"), "A bg.none() function was found, but should not exist")
assert(not rawget(tc.start.bg, "none"), "A start.bg.none() function was found, but should not exist")
assert(not rawget(tc.stop.bg, "none"), "A stop.bg.none() function was found, but should not exist")

for _, attr in ipairs(attributes) do
   assert(tc[attr], "Missing the 'wrap' function for attribute: " .. attr)
   assert(tc.start[attr], "Missing the 'start' function for attribute: " .. attr)
   assert(tc.stop[attr], "Missing the 'stop' function for attribute: " .. attr)
end

-- Check that using a non-existant color or attribute throws an error
assert(not (pcall(get, tc, "foo")), "Attempting to 'wrap' with a non-existant fg color/attribute failed to throw an error")
assert(not (pcall(get, tc.start, "foo")), "Attempting to 'start' a non-existant fg color/attribute failed to throw an error")
assert(not (pcall(get, tc.stop, "foo")), "Attempting to 'stop' a non-existant fg color/attribute failed to throw an error")
assert(not (pcall(get, tc.bg, "foo")), "Attempting to use a non-existant bg color/attribute failed to throw an error")
assert(not (pcall(get, tc.start.bg, "foo")), "Attempting to 'start' a non-existant bg color/attribute failed to throw an error")
assert(not (pcall(get, tc.stop.bg, "foo")), "Attempting to 'stop' a non-existant bg color/attribute failed to throw an error")

print "Done."


