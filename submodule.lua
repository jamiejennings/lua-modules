---- -*- Mode: Lua; -*- 
----
---- submodule.lua    Custom module system, esp. for modules within modules
----
---- (c) 2017, Jamie A. Jennings
----

-- Each module is loaded into its own environment, and that environment contains a copy of all the
-- functions in _G at the time when this code ('submodule') loads.
-- 
-- Code loaded into a module can use Lua's package system ('require', 'package.*') as well as a
-- new function called 'import'.
-- 
-- The import function searches in pre-specified places for luac, lua, and shared object files to
-- load.  First, package.loaded is consulted.  Then the parent's package.loaded.  Then the
-- specified places in the filesystem.
-- 
-- Anything loaded using import is visible in the current module and to children of the module,
-- i.e. submodules.

local m = {}

local _G = _G
local loadlib = package.loadlib
local loadfile = _G.loadfile
local load = _G.load

local copy_of_G = {}
for k,v in pairs(_G) do if type(v)~="table" then copy_of_G[k]=v; end; end

local function load_bt(name, env, _, mtype, prefix, ext)
   print("In load_bt: ", name, mtype, prefix, ext)
   return loadfile(prefix .. "/" .. name .. ext, mtype, env)
end

local function load_so(name, env, _, mtype, prefix, ext)
   return loadlib(prefix .. "/" .. name .. ext, "luaopen_" .. name)
end

-- To disable an entry, either remove it or set its prefix to nil
local default_try_table = {
   {type="local", prefix=true, ext=nil, load=function(name, env) return env.package.loaded[name]; end},
   {type="parent", prefix=true, ext=nil, load=function(name, env, parent_env) return parent_env.package.loaded[name]; end},
   {type="b", prefix="luac_prefix", ext=".luac", load=load_bt},
   {type="t", prefix="lua_prefix", ext=".lua", load=load_bt},
   {type="so", prefix="so_prefix", ext=".so", load=load_so}
}
	      
local function copy(t)
   local new = {}
   for k,v in pairs(t) do
      if type(v)=="table" then new[k] = copy(v)
      else new[k] = v; end
   end
   return new
end

function m.current_module()
   return nil
end

local function search(name, in_module)
   local thing, msg
   local env = in_module and in_module.env or _ENV
   local parent_env = in_module.parent_env
   for i, try in ipairs(in_module.try) do
      print("search:", i, try.prefix, try.type, try.ext, try.load)
      if try.prefix then
	 thing, msg = try.load(name, env, parent_env, try.type, try.prefix, try.ext)
	 if type(thing)=="table" then return thing;
	 elseif type(thing)=="function" then return thing(); end
      end
   end
   return nil, "not found"
end

local function make_importer(default_module)
   return function(name, in_module)
	     in_module = in_module or default_module
	     if not in_module then error("can only import into a module"); end
	     local module, msg = search(name, in_module)
	     if not module then return nil, msg; end
	     assert(type(module)=="table")
	     in_module.env.package.loaded[name] = module
	     return module
	  end
end

m.import = make_importer(nil)
   
function m.eval(str, module)
   if type(module)~="table" then error("second arg not a module: ".. tostring(module)); end
   if type(str)~="string" then error("first arg not a string: " .. tostring(str)); end
   local thunk, msg = load(str, "=module.eval", "t", module.env)
   if not thunk then return nil, msg; end
   return thunk()
end

local function make_require(in_module)
   return function(name)
	     local loaded = in_module.env.package.loaded[name]
	     if loaded then return loaded
	     else return require(name)
	     end
	  end
end

local function initial_environment(for_module)
   local localenv = setmetatable({}, {__index=copy_of_G})
   local localpackage = {}
   for k,v in pairs(package) do
      if type(v)=="table" then
	 localpackage[k] = setmetatable({}, {__index=v})
      else
	 localpackage[k] = v
      end
   end
   localenv.package = localpackage
   localenv.require = make_require(for_module)
   return localenv
end

local function empty_module(name)
   return setmetatable({name=name},
		       {__tostring=function() return "<module " .. tostring(name) .. ">"; end})
end

function m.new(name, luac_prefix, lua_prefix, so_prefix)
   local parent_env = _ENV
   local module = empty_module(name)
   local env = initial_environment(module)
   local try_table = {}
   for i,try in ipairs(default_try_table) do
      try_table[i] = copy(try)
      if try_table[i].prefix=="luac_prefix" then try_table[i].prefix=luac_prefix;
      elseif try_table[i].prefix=="lua_prefix" then try_table[i].prefix=lua_prefix;
      elseif try_table[i].prefix=="so_prefix" then try_table[i].prefix=so_prefix;
      end
   end
   env.current_module = function() return module; end
   env.import = make_importer(module)
   module.env = env
   module.parent_env = parent_env
   module.try = try_table
   return module
end

return m
