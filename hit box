-- Settings
_G.HitboxSize = 15 -- Ukuran kotak
_G.AttackDistance = 15 -- Jarak di mana kotak berubah jadi MERAH
_G.HitboxEnabled = true

task.spawn(function()
    while task.wait(0.1) do -- Cek lebih cepat biar warna ganti real-time
        if _G.HitboxEnabled then
            local lp = game:GetService("Players").LocalPlayer
            
            for _, v in pairs(game:GetService("Players"):GetPlayers()) do
                if v ~= lp and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                    local hrp = v.Character.HumanoidRootPart
                    local distance = (lp.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
                    
                    -- Atur Ukuran & Dasar
                    hrp.Size = Vector3.new(_G.HitboxSize, _G.HitboxSize, _G.HitboxSize)
                    hrp.Transparency = 0.6 -- Biar nggak nutupin pandangan banget
                    hrp.CanCollide = false
                    hrp.Material = "Neon"

                    -- Logika Warna Berdasarkan Jarak
                    if distance <= _G.AttackDistance then
                        hrp.BrickColor = BrickColor.new("Bright red") -- Dekat = MERAH
                    else
                        hrp.BrickColor = BrickColor.new("Bright green") -- Jauh = HIJAU
                    end
                end
            end
        end
    end
end)
