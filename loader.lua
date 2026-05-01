-- Optimized Loader (Stable + Fast)

local URL = "https://raw.githubusercontent.com/Netshh/askr-hub/main/loader.lua"

-- cache biar nggak fetch ulang
if not _G.AskrCache then
    local success, result

    for i = 1, 3 do
        success, result = pcall(function()
            return game:HttpGet(URL)
        end)

        if success and result and #result > 0 then
            _G.AskrCache = result
            break
        end

        task.wait(1)
    end
end

-- cek hasil
if _G.AskrCache then
    local runSuccess, err = pcall(function()
        loadstring(_G.AskrCache)()
    end)

    if not runSuccess then
        warn("Error saat run script: ", err)
    end
else
    warn("Gagal load script setelah 3x percobaan")
end
