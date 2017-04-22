---- -*- Mode: Lua; -*- 
----
---- submodule-test.lua
----
---- (c) 2017, Jamie A. Jennings
----

m = require("submodule")
assert(package.loaded.submodule)

-- Contents of the submodule module look ok

assert(type(m.new)=="function")
assert(type(m.import)=="function")
assert(type(m.eval)=="function")
assert(type(m.current_module)=="function")

ok, value = pcall(m.current_module)
assert(ok)
assert(value==nil)

-- New module with no paths configured to load code from the filesystem

p1 = m.new("p1")
assert(type(p1)=="table")
assert(tostring(p1):find("module"))
assert(tostring(p1):find("p1"))

-- Three functions and a table, and the package table has a package.loaded table
assert(type(p1.env.current_module)=="function")
assert(type(p1.env.import)=="function")
assert(type(p1.env.package)=="table")
assert(type(p1.env.package.loaded)=="table")
assert(type(p1.env.require)=="function")
assert(p1.env.m==nil)

-- The parent of p1 is the current environment
assert(p1.parent_env==_ENV)

-- There is nothing else in the p1 module
i = 0; for k,v in pairs(p1.env) do i=i+1; end
assert(i==4, "there are " .. tostring(i) .. " entries in the initial environment")

-- The env in p1 inherits from a copy of _G
assert(p1.env.print==print)

-- Test for isolation: new binding in p1 does not introduce a binding in current env
foo = nil
m.eval("foo = 1", p1)
assert(foo==nil)				    -- no effect on this environment
assert(p1.env.foo and p1.env.foo==1)		    -- but foo defined in p1

x = m.eval("return foo", p1)
assert(x==1)

-- The env in p1 extends a copy of _G, but does not contain a copy of _G
p1.env.print = 88
assert(p1.env.print==88)
assert(print~=88)
assert(_G.print~=88)
assert(_ENV.print~=88)

-- Require works as expected inside p1:
--  (1) It uses the contents of _G.package to load a module
--  (2) The module is available in _G.package.loaded
--  (3) The module is ALSO available in the package.loaded of p1

package.loaded.ls = nil
ls = nil

-- (1) p1 has no search path, so for this to work, it must use _G.package
m.eval('ls = require("list")', p1)
assert(type(p1.env.ls)=="table")
assert(type(p1.env.ls.cons)=="function")

-- (2)
assert(package.loaded.list)
assert(type(package.loaded.list.cons)=="function")

-- (3)
assert(p1.env.package.loaded.list)
assert(type(p1.env.package.loaded.list.cons)=="function")

-- Again confirming isolation, ensure that the 'm' defined here is not also in p1
ok, result = pcall(m.eval, 'return m', p1)
assert(ok)
assert(result==nil)				    -- m not defined in p1
ok, result = pcall(m.eval, 'tc = m.import("recordtype")', p1)
assert(not ok)					    -- m not defined in p1

-- Reset, in case the current env has termcolor loaded
termcolor = nil
tc = nil
package.loaded.termcolor = nil

-- The submodule 'import' function is inserted into new modules.  The p1 module has no import
-- paths, though, so 'import' cannot find "termcolor".
ok, msg = pcall(m.eval, 'return import("termcolor")', p1)
assert(not ok)
assert(msg:find("not found"))

require("termcolor")
assert(package.loaded.termcolor)
ok, result = pcall(m.eval, 'return import("termcolor")', p1)
assert(ok)
assert(result==package.loaded.termcolor)

assert(p1.env.tc==nil)
ok, result = pcall(m.eval, 'tc = import("termcolor")', p1)
assert(ok)
assert(result==nil)
assert(p1.env.tc==package.loaded.termcolor)
assert(not tc)					    -- no effects on current env

-- The module p1 can load 'submodule' and use it to define its own submodules...
m.eval('mod = require("submodule")', p1)
assert(type(p1.env.mod)=="table")
assert(p1.env.mod==m)

m.eval('p = mod.new("p1_1")', p1)
m.eval('mod.eval("require(\"termcolor\")", p)', p1)
p1_1 = m.eval('return p', p1)
m.eval('assert(package.loaded.termcolor)', p1_1)

-- The prefix settings are used to load code from only restricted places

f = io.open("/tmp/mod4p2.lua", "w")
--f:write('ll = require("list"); a = ll.list("a", "b", "c"); print(a); return {"hello"}; \n')
f:write('print("hello, this is some temporary lua code"); return {"hello"}; \n')
f:close()

-- Reset, to clean up from prior tests
os.execute("rm -f /tmp/mod4p2.luac")

p2 = m.new("p2", "/", "/tmp")			    -- only luac path given
ok, msg = pcall(m.import, "mod4p2", p2)
assert(not ok)					    -- mod4p2.luac is missing
assert(msg:find("not found"))

p3 = m.new("p3", "/", nil, "/tmp")
ok, result = m.import("mod4p2", p3)
assert(ok)
assert(not result)
assert(type(p3.env.package.loaded.mod4p2)=="table")
assert(p3.env.package.loaded.mod4p2[1]=="hello")

os.execute("/usr/local/bin/luac -o /tmp/mod4p2.luac /tmp/mod4p2.lua")

ok, result = m.import("mod4p2", p2)		    -- now mod4p2.luac exists
assert(ok)
assert(type(p2.env.package.loaded.mod4p2)=="table")
assert(p2.env.package.loaded.mod4p2[1]=="hello")

p4 = m.new("p4", "/", nil, nil, "/tmp")
os.execute("cp /usr/local/lib/lua/5.3/lpeg.so /tmp/")

ok = pcall(m.import, "lpeg", p1)		    -- p1 has no import paths configured
assert(not ok)
ok = pcall(m.import, "lpeg", p2)		    -- p2 has no ".so" path
assert(not ok)
ok = pcall(m.import, "lpeg", p3)		    -- p3 has no ".so" path
assert(not ok)

-- This will work
result = m.import("lpeg", p4)			    -- p4 has ".so" path configured
assert(result)
assert(type(result)=="table")			    -- import returns the package, like require
assert(type(p4.env.package.loaded.lpeg)=="table")
assert(type(p4.env.package.loaded.lpeg.P)=="function")
assert(result==p4.env.package.loaded.lpeg)

-- Verify that lpeg is not loaded anywhere else
assert(not package.loaded.lpeg)
assert(not p1.env.package.loaded.lpeg)
assert(not p1_1.env.package.loaded.lpeg)
assert(not p3.env.package.loaded.lpeg)
assert(not p3.env.package.loaded.lpeg)

-- Check that the configuration can be a path, not just a single prefix
p5 = m.new("p5", "/", nil, "foo;/tmp/foobar;/tmp", nil)
ok, result = m.import("mod4p2", p5)		    -- /tmp/mod4p2.luac exists
assert(ok)
assert(type(p5.env.package.loaded.mod4p2)=="table")
assert(p5.env.package.loaded.mod4p2[1]=="hello")

-- Check the new root_path configuration option
px = m.new("px", "/", nil, "tmp")			    -- only lua path given
ok, msg = pcall(m.import, "mod4p2", px)
assert(ok)

py = m.new("py", "", nil, "/tmp")			    -- empty string for root path
ok, msg = pcall(m.import, "mod4p2", py)
assert(ok)

pz = m.new("pz", nil, nil, "/tmp")			    -- nil for root path
ok, msg = pcall(m.import, "mod4p2", pz)
assert(ok)

pzz = m.new("pz", "adsklasdk asdlka d", nil, "/tmp")	    -- root path not used
ok, msg = pcall(m.import, "mod4p2", pzz)
assert(ok)


-- Check that _G and arg are defined
pzz_G = m.eval("return _G", pzz)
assert(pzz_G)
pzz_arg = m.eval("return arg", pzz)
assert(pzz_arg)
pzz_G_arg = m.eval("return _G.arg", pzz)
assert(pzz_G_arg)
assert(pzz_arg==pzz_G_arg)

-- We can import stuff from a submodule, which may be useful for debugging or during an
-- interactive Lua programming session



