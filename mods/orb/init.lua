-- a fake lil' OS

orb = {}

-- utils

orb.utils = {
   split = function(str,div)
      if(div=='') then return {str} end
      local pos,res = 0,{}
      for st,sp in function() return string.find(str,div,pos,true) end do
         local str = string.sub(str,pos,st-1)
         if(str ~= "") then table.insert(res,str) end
         pos = sp + 1
      end
      table.insert(res,string.sub(str,pos))
      return res
   end,
}

if(minetest) then
   orb.utils.mod_dir = minetest.get_modpath("orb")
else
   orb.utils.mod_dir = debug.getinfo(1,"S").source:sub(2, -3)
end

-- filesystem

orb.fs = {
   empty = function()
      return {_user = "root", _group = "root", _permissions = 755}
   end,

   mkdir = function(f, path, parent)
      first, rest = path:match("(/[^/]+)/(.*)")
      if(first) then
         orb.fs.mkdir(f[first:gsub("^/", "" )], rest, f)
      else
         parent = parent or {_user = "root", _group = "root",
                             _permissions = 493} -- 755 in decimal
         f[path:gsub("/", "")] = {
            _user = parent._user,
            _group = parent._group,
            _permissions = parent._permissions,
         }
      end
   end,

   dirname = function(path)
      local t = orb.utils.split(path, "/")
      local basename = t[#t]
      table.remove(t, #t)
      return table.concat(t, "/"), basename
   end,

   seed = function(f, users)
      for _,d in pairs({"/etc", "/home", "/tmp", "/bin"}) do
         orb.fs.mkdir(f, d)
      end
      orb.fs.find_dir(f, "/tmp")["_permissions"] = 511 -- 777 in decimal
      for _,u in pairs(users) do
         local home = "/home/" .. u
         orb.fs.mkdir(f, home)
         orb.fs.find_dir(f, home)["_user"] = u
         orb.fs.find_dir(f, home)["_group"] = u
      end
      for content_path, path in pairs({ls = "/bin/ls"}) do
         local dir, base = orb.fs.dirname(path)
         local resource_path = orb.utils.split(orb.utils.mod_dir, "/")
         table.remove(resource_path, #resource_path)
         local path = "/" .. table.concat(resource_path, "/") ..
            "/resources/" .. content_path
         local file = io.open(path, "r")
         orb.fs.find_dir(f, dir)[base] = file:read("*all")
         file:close()
      end
      return f
   end,

   find_dir = function(f, path)
      if(path == "/") then return f end
      path = path:gsub("/$", "")
      path_segments = orb.utils.split(path, "/")
      final = table.remove(path_segments, #path_segments)
      for _,p in pairs(path_segments) do
         f = f[p]
      end
      return f[final]
   end
}

-- shell

orb.shell = {
   new_env = function()
      return {PATH = "/bin"}
   end,

   exec = function(f, env, command, path)
      args = orb.utils.split(command, " ")
      executable_name = table.remove(args, 1)
      for _,d in pairs(orb.utils.split(env.PATH, ":")) do
         executable = orb.fs.find_dir(f, d)[executable_name]
         if(executable) then
            local chunk = assert(loadstring(executable))
            -- TODO: sandbox with this:
            -- setfenv(chunk, process_env)
            return chunk(f, env, args)
         end
      end
      print(executable_name .. " not found.")
   end
}

f1 = orb.fs.seed(orb.fs.empty(), {"technomancy", "buddy_berg", "zacherson"})
orb.fs.find_dir(f1, "/")
orb.shell.exec(f1, orb.shell.new_env(), "ls /home")
orb.shell.exec(f1, orb.shell.new_env(), "ls /bin")
orb.shell.exec(f1, orb.shell.new_env(), "ls /")