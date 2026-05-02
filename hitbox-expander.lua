-- Settings
_G.HitboxSize = 15
_G.AttackDistance = 15
_G.HitboxEnabled = true
_G.AutoAttack = true

local lp = game:GetService("Players").LocalPlayer
local vu = game:GetService("VirtualUser")

task.spawn(function()
    while task.wait(0.1) do
        if _G.HitboxEnabled then
            for _, v in pairs(game:GetService("Players"):GetPlayers()) do
                if v ~= lp and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                    local hrp = v.Character.HumanoidRootPart
                    local myHrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
                    
                    if myHrp then
                        local distance = (myHrp.Position - hrp.Position).Magnitude
                        
                        -- SET HITBOX (Transparan tapi membesar)
                        hrp.Size = Vector3.new(_G.HitboxSize, _G.HitboxSize, _G.HitboxSize)
                        hrp.Transparency = 1 -- Kotak tengahnya gak kelihatan
                        hrp.CanCollide = false
                        
                        -- BUAT EFEK TEPI (SelectionBox/Outline)
                        local selection = hrp:FindFirstChild("HitboxEdge")
                        if not selection then
                            selection = Instance.new("SelectionBox")
                            selection.Name = "HitboxEdge"
                            selection.Parent = hrp
                            selection.Adornee = hrp
                            selection.LineThickness = 0.05 -- Ketebalan garis tepi
                        end

                        -- Logika Jarak & Warna Tepi
                        if distance <= _G.AttackDistance then
                            selection.Color3 = Color3.fromRGB(255, 0, 0) -- MERAH (Dekat)
                            if _G.AutoAttack then
                                vu:CaptureController()
                                vu:Button1Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                            end
                        else
                            selection.Color3 = Color3.fromRGB(0, 255, 0) -- HIJAU (Jauh)
                        end
                    end
                end
            end
        end
    end
end)

print("Hitbox Edge Expander Loaded!")
