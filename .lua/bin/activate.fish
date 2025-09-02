if functions -q deactivate-lua
    deactivate-lua
end

function deactivate-lua
    if test -x '/mnt/e/LOVE/Oink/.lua/bin/lua'
        eval ('/mnt/e/LOVE/Oink/.lua/bin/lua' '/mnt/e/LOVE/Oink/.lua/bin/get_deactivated_path.lua' --fish)
    end

    functions -e deactivate-lua
end

set -gx PATH '/mnt/e/LOVE/Oink/.lua/bin' $PATH
