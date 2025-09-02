-- LuaRocks configuration

rocks_trees = {
   { name = "user", root = home .. "/.luarocks" };
   { name = "system", root = "/mnt/e/LOVE/Oink/.lua" };
}
lua_interpreter = "lua";
variables = {
   LUA_DIR = "/mnt/e/LOVE/Oink/.lua";
   LUA_BINDIR = "/mnt/e/LOVE/Oink/.lua/bin";
   UNZIP = "/usr/bin/unzip";
}
