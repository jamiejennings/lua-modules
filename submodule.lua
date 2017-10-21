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

package = require "package"
io = require "io"

local _G = assert(_G)
local loadlib = assert(package.loadlib)
local loadfile = assert(_G.loadfile)
local load = assert(_G.load)

local copy_of_G = {}
for k,v in pairs(_G) do if k~="_G" then copy_of_G[k]=v; end; end
copy_of_G._G = copy_of_G

local function make_path_searcher(loader, mtype, ext)
   local prefix_pattern = "([^;]+)"
   return function(root, path, name, env)
	     local attempts = {}
	     local next_prefix = path:gmatch(prefix_pattern)
	     name = name:sub(1, (name:find(".", 1, true) or 0) -1)
	     for prefix in next_prefix do
		local fullname = prefix .. "/" .. name .. ext
		if fullname:sub(1,1)~="/" then fullname = root .. "/" .. fullname; end
		local thing, msg = loader(fullname, name, env)
		if thing then return thing; end
		table.insert(attempts, msg)
	     end
	     return nil, table.concat(attempts, "\n")
	  end
end

local function attempt_msg(filename, msg, ...)
   return filename .. ' (' .. msg .. ') ' .. (table.concat({...}, '\n') or '')
end

load_b = make_path_searcher(function(fullname, name, env)
			       local thunk, msg = loadfile(fullname, "b", env)
			       if not thunk then
				  return nil, attempt_msg(fullname, msg)
			       end
			       return thunk, fullname
			    end,
			    "b",
			    ".luac")

load_t = make_path_searcher(function(fullname, name, env)
			       local f = io.open(fullname, "r")
			       if not f then
				  return nil, attempt_msg(fullname, "no such file")
			       end
			       f:close()
			       local thunk, msg = loadfile(fullname, "t", env)
			       if not thunk then
				  return nil, attempt_msg(fullname, msg)
			       end
			       return thunk, fullname
			    end,
			    "t",
			    ".lua")

load_so = make_path_searcher(function(fullname, name, env)
				name = (name:gsub("[.]", "_"))
				local libtable, msg, where = loadlib(fullname, "luaopen_" .. name)
				return libtable, libtable and fullname or attempt_msg(fullname, msg, where)
			     end,
			     "so",
			     ".so")

-- To disable an entry, either remove it or set its path to nil
local default_try_table = {
   {path=true, load=function(root, path, name, env)
		       return env.package.loaded[name], "package.loaded";
		    end},
   {path=true, load=function(root, path, name, env, parent_env)
		       return parent_env.package.loaded[name], "parent->package.loaded";
		    end},
   {path="luac_path", load=load_b},
   {path="lua_path", load=load_t},
   {path="so_path", load=load_so}
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
   local thing, attempts
   local paths_attempted = ""
   local env = in_module and in_module.env or _ENV
   local parent_env = in_module.parent_env
   for i, try in ipairs(in_module.try) do
      -- print("search:", i, try.path, try.load)
      if try.path then
	 thing, attempts = try.load(in_module.root, try.path, name, env, parent_env)
	 if type(thing)=="table" then return true, thing;
	 elseif type(thing)=="function" then return true, thing(); end
      paths_attempted = paths_attempted .. "\n" .. attempts
      end
   end
   return nil, nil, paths_attempted
end

local function make_importer(default_module)
   return function(name, in_module)
	     in_module = in_module or default_module
	     if not in_module then error("can only import into a module"); end
	     local found, module, msg = search(name, in_module)
	     if not found then error("module '" .. name .. "' not found in:" .. msg, 2); end
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

function m.new(name, root_path, luac_path, lua_path, so_path)
   root_path = root_path or ""
   local parent_env = _ENV
   local module = empty_module(name)
   local env = initial_environment(module)
   local try_table = {}
   for i,try in ipairs(default_try_table) do
      try_table[i] = copy(try)
      if try_table[i].path=="luac_path" then try_table[i].path=luac_path;
      elseif try_table[i].path=="lua_path" then try_table[i].path=lua_path;
      elseif try_table[i].path=="so_path" then try_table[i].path=so_path;
      end
   end
   env.current_module = function() return module; end
   env.import = make_importer(module)
   module.env = env
   module.parent_env = parent_env
   module.try = try_table
   module.root = root_path
   return module
end

return m
