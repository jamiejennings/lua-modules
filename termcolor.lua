---- -*- Mode: Lua; -*-                                                                           
----
---- termcolor.lua    Write text in color using ANSI escape sequences
----                  Reference: https://en.wikipedia.org/wiki/ANSI_escape_code
----
---- © Copyright Jamie A. Jennings 2016, 2017.
---- LICENSE: MIT License (https://opensource.org/licenses/mit-license.html)
---- AUTHOR: Jamie A. Jennings

-- Interface:
--
-- tc.red(str) returns str prepended with escape sequence for 'red' text,
--             and appended with escape sequence for default color text.
--             colors are black, red, green, yellow, blue, magenta, cyan, white, default.
--
-- tc.bg.red(str) as above, but sets background to 'red', then back to default
--
-- tc.reverse(str) as above, but for font atttribute 'reverse', then off.
--                 attributes are reverse, bold, blink, underline, none.
--
-- tc.start.red(str) like tc.red(str) but does not return to default color.
--                   to return to default color, use tc.stop.red(), which is
--                   the same as tc.start.default().
--
-- tc.stop.red(str) for all colors, this is the same as tc.start.default(str)
-- 
-- tc.start.bg.red(str) like tc.bg.red(str) but does not return background to default.
-- 
-- tc.start.reverse(str) like tc.reverse(str) but does not return to normal.
--                       to remove reverse, use tc.stop.reverse(), or to remove
--                       all attributes, tc.start.none()
--
-- tc.stop.reverse(str) prepends to str the sequence that turns off the attribute
-- 
-- Note: if str is nil, it will be treated as if it were the empty string.

local tc = {}

local function csi(rest)
   return "\027[" .. rest
end

-- Supported colors and font attributes

local fg = { black = csi("30m");		    -- foreground (text) colors
	     red = csi("31m");
	     green = csi("32m");
	     yellow = csi("33m");
	     blue = csi("34m");
	     magenta = csi("35m");
	     cyan = csi("36m");
	     white = csi("37m");
	     default = csi("39m");
	  }

local attr_on = { reverse = csi("7m");		    -- font attributes
                  bold = csi("1m");
		  blink = csi("5m");
		  underline = csi("4m");
		  none = csi("0m");		    -- removes all attributes
	       }

local attr_off = { reverse = csi("27m");
	           bold = csi("22m");
		   blink = csi("25m");
		   underline = csi("24m");
		}
	       
local bg = { black = csi("40m");		    -- background colors
             red = csi("41m");
	     green = csi("42m");
	     yellow = csi("43m");
	     blue = csi("44m");
	     magenta = csi("45m");
	     cyan = csi("46m");
	     white = csi("47m");
	     default = csi("49m");
}


local function emitter(start_code, end_code)
   return function(str)
	     str = str or ""
	     if start_code then str = start_code .. str; end
	     if end_code then str = str .. end_code; end
	     return str
	  end
end

-- tc.red()
for color, code in pairs(fg) do
   tc[color] = emitter(code, fg.default)
end

-- tc.start.red()
tc.start = {}
for color, code in pairs(fg) do
   tc.start[color] = emitter(code)
end

-- tc.bg.red()
-- tc.start.bg.red()
tc.bg = {}
tc.start.bg = {}
for color, code in pairs(bg) do
   tc.bg[color] = emitter(code, bg.default)
   tc.start.bg[color] = emitter(code)
end

-- tc.stop.red()
-- tc.stop.bg.red()
tc.stop = {}
tc.stop.bg = {}
local default_color_emitter = emitter(fg.default)
local default_bg_color_emitter = emitter(bg.default)
for color, code in pairs(fg) do
   tc.stop[color] = default_color_emitter
   tc.stop.bg[color] = default_bg_color_emitter
end

-- tc.reverse()
-- tc.start.reverse()
for attr, on_code in pairs(attr_on) do
   tc[attr] = emitter(on_code, attr_off[attr])
   tc.start[attr] = emitter(on_code)
   if attr~="none" then tc.stop[attr] = emitter(nil, attr_off[attr]); end
end

local function err(self, key)
   error("termcolor: no such color or attribute: " .. tostring(key))
end

setmetatable(tc, {__index = err})
setmetatable(tc.bg, {__index = err})
setmetatable(tc.start, {__index = err})
setmetatable(tc.stop, {__index = err})
setmetatable(tc.start.bg, {__index = err})
setmetatable(tc.stop.bg, {__index = err})
		  
return tc
