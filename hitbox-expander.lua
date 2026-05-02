-- Settings
_G.HitboxSize = 20 -- Gue gedein dikit biar makin gampang kena
_G.AttackDistance = 12 -- Jarak pas buat mukul (jangan kejauhan biar gak error)
_G.HitboxEnabled = true
_G.AutoAttack = true

local lp = game:GetService("Players").LocalPlayer
local vu = game:GetService("VirtualUser")

task.spawn(function()
    while task.wait(0.1) do
        if _G.HitboxEnabled then
            for _, v in pairs(game:GetService("Players"):GetPlayers()) do
                if v ~= lp and v.Character and v.Character:FindFirstChild("HumanoidRootPart") and v.Character:FindFirstChild("Humanoid") then
                    local hrp = v.Character.HumanoidRootPart
                    local hum = v.Character.Humanoid
                    local myHrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
                    
                    if myHrp and hum.Health > 0 then
                        local distance = (myHrp.Position - hrp.Position).Magnitude
                        
                        -- Ukuran Hitbox
                        hrp.Size = Vector3.new(_G.HitboxSize, _G.HitboxSize, _G.HitboxSize)
                        hrp.Transparency = 0.8 -- Dibuat agak kelihatan biar lo tau targetnya
                        hrp.CanCollide = false
                        
                        -- Outline Tepi
                        local selection = hrp:FindFirstChild("HitboxEdge") or Instance.new("SelectionBox", hrp)
                        selection.Name = "HitboxEdge"
                        selection.Adornee = hrp
                        selection.LineThickness = 0.08

                        -- Logika Jarak
                        if distance <= _G.AttackDistance then
                            selection.Color3 = Color3.fromRGB(255, 0, 0) -- MERAH
                            
                            -- FORCE ATTACK: Bikin sistem mikir kita nempel sama musuh
                            if _G.AutoAttack then
                                -- Simulasi klik lebih cepat
                                vu:Button1Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                                task.wait(0.05)
                                vu:Button1Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                            end
                        else
                            selection.Color3 = Color3.fromRGB(0, 255, 0) -- HIJAU
                        end
                    end
                end
            end
        end
    end
end)
