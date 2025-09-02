which deactivate-lua >&/dev/null && deactivate-lua

alias deactivate-lua 'if ( -x '\''/mnt/e/LOVE/Oink/.lua/bin/lua'\'' ) then; setenv PATH `'\''/mnt/e/LOVE/Oink/.lua/bin/lua'\'' '\''/mnt/e/LOVE/Oink/.lua/bin/get_deactivated_path.lua'\''`; rehash; endif; unalias deactivate-lua'

setenv PATH '/mnt/e/LOVE/Oink/.lua/bin':"$PATH"
rehash
