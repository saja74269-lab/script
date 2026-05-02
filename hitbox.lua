-- Settings
_G.HitboxSize = 15
_G.AttackDistance = 15
_G.HitboxEnabled = true
_G.AutoAttack = true

local lp = game:GetService("Players").LocalPlayer
local vu = game:GetService("VirtualUser")

-- Fungsi utama biar selalu nge-detect
task.spawn(function()
    while task.wait(0.1) do -- Cek setiap 0.1 detik (super responsif)
        if _G.HitboxEnabled then
            for _, v in pairs(game:GetService("Players"):GetPlayers()) do
                -- Cek apakah player valid, bukan kita sendiri, dan punya karakter hidup
                if v ~= lp and v.Character and v.Character:FindFirstChild("HumanoidRootPart") and v.Character:FindFirstChild("Humanoid") then
                    local hrp = v.Character.HumanoidRootPart
                    local hum = v.Character.Humanoid
                    
                    if hum.Health > 0 then -- Hanya aktif kalau musuh masih hidup
                        local myHrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
                        
                        if myHrp then
                            local distance = (myHrp.Position - hrp.Position).Magnitude
                            
                            -- PAKSA Hitbox muncul terus (Auto-Detect)
                            hrp.Size = Vector3.new(_G.HitboxSize, _G.HitboxSize, _G.HitboxSize)
                            hrp.Transparency = 0.7
                            hrp.CanCollide = false
                            hrp.Material = "Neon"

                            -- Logika Warna & Attack
                            if distance <= _G.AttackDistance then
                                hrp.BrickColor = BrickColor.new("Bright red")
                                if _G.AutoAttack then
                                    vu:CaptureController()
                                    vu:Button1Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                                end
                            else
                                hrp.BrickColor = BrickColor.new("Bright green")
                            end
                        end
                    end
                end
            end
        end
    end
end)

print("Hitbox Auto-Detect Aktif!")
