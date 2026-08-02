include("b375d1f9edf2618916fc2dff9313_config.lua")

local smoothFOV = 70
local smoothCamPos = nil
local lastToggleTime = 0

ceilhorse.HorseFirstPerson = false

hook.Add("CreateMove", ceilhorse.ID, function(cmd)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    if ply:IsHorse() then
        local isAltDown = input.IsButtonDown(KEY_LALT)
        if isAltDown then
            cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_WALK))
        end

        local currentView = cmd:GetViewAngles()

        if ply.HorseLastView then
            if not isAltDown then
                local gear = ply:GetGear() or 0

                local maxTurnRate = 600

                local maxDelta = maxTurnRate * FrameTime()
                local diffY = math.AngleDifference(currentView.y, ply.HorseLastView.y)

                if math.abs(diffY) > maxDelta then
                    currentView.y = ply.HorseLastView.y + math.Clamp(diffY, -maxDelta, maxDelta)
                    currentView:Normalize()
                    cmd:SetViewAngles(currentView)
                end
            end
        end


        ply.HorseLastView = cmd:GetViewAngles()
    else

        if ply.HorseLastView then
            ply.HorseLastView = nil
        end
    end
end)

hook.Add("PlayerButtonDown", ceilhorse.ID, function(ply, button)
    if ply == LocalPlayer() and ply:IsHorse() then
        if button == KEY_LCONTROL or button == KEY_RCONTROL then
            if CurTime() < lastToggleTime then return end
            lastToggleTime = CurTime() + 0.5
            ceilhorse.HorseFirstPerson = not ceilhorse.HorseFirstPerson
        end
    end
end)

hook.Add("CalcView", ceilhorse.ID, function(ply, pos, angles, fov)
    if ply:IsHorse() then
        local gear = ply:GetGear() or 0
        local targetFOV = fov + (gear * 6)
        smoothFOV = Lerp(FrameTime() * 8, smoothFOV, targetFOV)

        if ceilhorse.HorseFirstPerson then
            local decoy = ply:GetNW2Entity("HorseDecoy")
            local headPos = pos + Vector(0, 0, 64)

            if IsValid(decoy) and IsValid(decoy.cavalier) then
                decoy:SetupBones()
                decoy.cavalier:SetupBones()

                local headBone = decoy.cavalier:LookupBone("ValveBiped.Bip01_Head1")
                if headBone and headBone >= 0 then
                    local boneMatrix = decoy.cavalier:GetBoneMatrix(headBone)
                    if boneMatrix then
                        headPos = boneMatrix:GetTranslation()
                    end
                end
            end

            local targetFirstPersonPos = headPos + angles:Forward() * 4


            ply.HorseSmoothFPPos = ply.HorseSmoothFPPos or targetFirstPersonPos
            ply.HorseSmoothFPPos = LerpVector(FrameTime() * 15, ply.HorseSmoothFPPos, targetFirstPersonPos)

            return {
                origin = ply.HorseSmoothFPPos,
                angles = angles,
                fov = smoothFOV,
                drawviewer = true
            }
        end


        local camDist = 160
        local camUpOffset = 40
        local camRightOffset = 0


        ply.HorseSmoothAng = ply.HorseSmoothAng or angles
        ply.HorseSmoothAng = LerpAngle(FrameTime() * 12, ply.HorseSmoothAng, angles)

        local targetPos = pos - (ply.HorseSmoothAng:Forward() * camDist) + (ply.HorseSmoothAng:Up() * camUpOffset) + (ply.HorseSmoothAng:Right() * camRightOffset)

        if not smoothCamPos then
            smoothCamPos = targetPos
        end


        smoothCamPos = LerpVector(FrameTime() * 12, smoothCamPos, targetPos)

        local tr = util.TraceHull({
            start = pos,
            endpos = smoothCamPos,
            mins = Vector(-12, -12, -12),
            maxs = Vector(12, 12, 12),
            filter = ply,
            mask = {}
        })


        return {
            origin = tr.HitPos,
            angles = ply.HorseSmoothAng,
            fov = smoothFOV,
            drawviewer = true
        }
    else
        -- Purge des variables lors de la descente
        smoothCamPos = nil
        if ply.HorseSmoothAng then ply.HorseSmoothAng = nil end
        if ply.HorseSmoothFPPos then ply.HorseSmoothFPPos = nil end
    end
end)

surface.CreateFont("CeilHorseHUD_Text", {
    font = "Roboto",
    size = 18,
    weight = 500,
    antialias = true,
})

local GEAR_NAMES = {
    [-1] = "RECUL",
    [0]  = "ARRÊT",
    [1]  = "PAS",
    [2]  = "TROT",
    [3]  = "PETIT GALOP",
    [4]  = "GRAND GALOP"
}

local smoothHealth = 100
local smoothStamina = 100

hook.Add("HUDPaint", ceilhorse.ID .. "_HUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:IsHorse() then return end

    local scrW, scrH = ScrW(), ScrH()

    local padding = 40
    local barW = 200
    local barH = 4
    local startX = scrW - barW - padding
    local startY = scrH - padding - 40

    local hp = ply:Health()
    local maxHp = ply:GetMaxHealth()
    local gear = ply:GetGear() or 0
    local stamina = ply:GetNW2Float("HorseStamina", 100)
    local maxStamina = 100

    smoothHealth = Lerp(FrameTime() * 8, smoothHealth, hp)
    smoothStamina = Lerp(FrameTime() * 8, smoothStamina, stamina)

    local gearName = GEAR_NAMES[gear] or ""
    draw.SimpleText(gearName, "CeilHorseHUD_Text", startX + barW, startY - 15, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)

    draw.RoundedBox(2, startX, startY, barW, barH, Color(0, 0, 0, 150))
    draw.RoundedBox(2, startX, startY + 12, barW, barH, Color(0, 0, 0, 150))

    local hpWidth = math.Clamp((smoothHealth / maxHp) * barW, 0, barW)
    if hpWidth > 0 then
        draw.RoundedBox(2, startX, startY, hpWidth, barH, Color(220, 50, 50, 255))
    end

    local stamWidth = math.Clamp((smoothStamina / maxStamina) * barW, 0, barW)
    if stamWidth > 0 then
        draw.RoundedBox(2, startX, startY + 12, stamWidth, barH, Color(50, 150, 220, 255))
    end
end)

hook.Add("HUDShouldDraw", ceilhorse.ID .. "_HideDefault", function(name)
    local ply = LocalPlayer()
    if IsValid(ply) and ply:IsHorse() then
        if name == "CHudHealth" or name == "CHudBattery" then
            return false
        end
    end
end)
