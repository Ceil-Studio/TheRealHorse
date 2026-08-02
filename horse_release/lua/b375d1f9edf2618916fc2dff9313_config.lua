ceilhorse = ceilhorse or {}

ceilhorse.ID = "b375d1f9edf2618916fc2dff9313"
ceilhorse.horsemdl = "models/senior/horse/horse.mdl"
ceilhorse.speedsetup = 1

ceilhorse.defaulthealth = 150

--NE PAS TOUCHER

local HORSE_SPEEDS = {
    [-1] = -50,
    [0] = 0,
    [1] = 50,
    [2] = 100,
    [3] = 200,
    [4] = 300
}

hook.Add("StartCommand", ceilhorse.ID, function(ply, cmd)
    if not ply:IsHorse() then return end

    cmd:SetSideMove(0)
    cmd:RemoveKey(IN_DUCK)

    local currentGear = ply:GetGear()


    if currentGear == 4 and ply:GetHorseStamina() <= 0 then
        ply:SetGear(3)
        currentGear = 3
        ply.HorseLastGearChange = CurTime()
    end

    ply.m_bWasForwardDown = ply.m_bWasForwardDown or false
    ply.m_bWasBackDown = ply.m_bWasBackDown or false

    local isForwardDown = cmd:KeyDown(IN_FORWARD)
    local isBackDown = cmd:KeyDown(IN_BACK)

    if isForwardDown and not ply.m_bWasForwardDown then
        local newGear = math.min(currentGear + 1, 4)

        if newGear == 4 and ply:GetHorseStamina() <= 0 then
            newGear = 3
        end

        ply:SetGear(newGear)
        ply.HorseLastGearChange = CurTime()
    elseif isBackDown and not ply.m_bWasBackDown then
        local newGear = math.max(currentGear - 1, -1)
        ply:SetGear(newGear)
        ply.HorseLastGearChange = CurTime()
    end

    ply.m_bWasForwardDown = isForwardDown
    ply.m_bWasBackDown = isBackDown

    currentGear = ply:GetGear()
    local targetSpeed = HORSE_SPEEDS[currentGear] * ceilhorse.speedsetup

    if currentGear == 0 then
        cmd:RemoveKey(IN_JUMP)
    end

    local isAltDown = cmd:KeyDown(IN_WALK)

    if isAltDown then
        if not ply.HorseFreelookYaw then
            ply.HorseFreelookYaw = cmd:GetViewAngles().y
        end
    else
        ply.HorseFreelookYaw = nil
    end

    if currentGear ~= 0 then
        if isAltDown and ply.HorseFreelookYaw then
            local viewYaw = cmd:GetViewAngles().y
            local diff = math.rad(ply.HorseFreelookYaw - viewYaw)

            cmd:SetForwardMove(math.cos(diff) * targetSpeed)
            cmd:SetSideMove(math.sin(diff) * -targetSpeed)
        else
            cmd:SetForwardMove(targetSpeed)
            cmd:SetSideMove(0)
        end

        if currentGear > 0 then
            cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_SPEED))
        end
    else
        cmd:SetForwardMove(0)
        cmd:SetSideMove(0)
    end
end)

hook.Add("FinishMove", ceilhorse.ID, function(ply, mv)
    if not ply:IsHorse() then return end

    local gear = ply:GetGear()

    if gear ~= 0 then
        ply.HorseLastGearChange = ply.HorseLastGearChange or 0

        if CurTime() > ply.HorseLastGearChange + 0.5 then
            local actualVel = mv:GetVelocity():Length2D()
            local targetSpeed = math.abs(HORSE_SPEEDS[gear]) * ceilhorse.speedsetup

            if ply:IsOnGround() and actualVel < (targetSpeed * 0.15) then
                ply:SetGear(0)
            end
        end
    end
end)

hook.Add("CalcMainActivity", ceilhorse.ID, function(ply, velocity)
    if ply:IsHorse() then
        local seq = -1
        local gear = ply:GetGear()

        if not ply:IsOnGround() and gear ~= 0 then
            seq = ply:LookupSequence("jump")
        elseif gear == -1 then
            seq = ply:LookupSequence("walk_inv")
        elseif gear == 1 then
            seq = ply:LookupSequence("walk")
        elseif gear == 2 then
            seq = ply:LookupSequence("trot")
        elseif gear == 3 then
            seq = ply:LookupSequence("canter")
        elseif gear == 4 then
            seq = ply:LookupSequence("gallop")
        else
            seq = ply:LookupSequence("idle")
        end

        if seq ~= -1 then
            return ACT_HL2MP_IDLE, seq
        end
    end
end)

hook.Add("UpdateAnimation", ceilhorse.ID, function(ply, velocity, maxseqgroundspeed)
    if ply:IsHorse() then
        ply:SetPlaybackRate(1 * ceilhorse.speedsetup)

        if CLIENT then
            ply:SetPoseParameter("move_x", 0)
            ply:SetPoseParameter("move_y", 0)

            if not ply.HorseBoundsApplied then
                ply:SetRenderBounds(Vector(-500, -500, -500), Vector(500, 500, 500))
                ply.HorseBoundsApplied = true
            end

            local flexID = ply:GetFlexIDByName("blink")
            if flexID then
                ply.BlinkState = ply.BlinkState or 0
                ply.NextBlinkCheck = ply.NextBlinkCheck or 0
                ply.CurrentBlinkWeight = ply.CurrentBlinkWeight or 0

                ply.CurrentBlinkWeight = math.Approach(ply.CurrentBlinkWeight, ply.BlinkState, FrameTime() * 15)
                ply:SetFlexWeight(flexID, ply.CurrentBlinkWeight)

                if ply.CurrentBlinkWeight == 0 and CurTime() > ply.NextBlinkCheck then
                    if math.random(1, 100) <= 15 then
                        ply.BlinkState = 1
                    end
                    ply.NextBlinkCheck = CurTime() + math.Rand(0.5, 3.0)
                elseif ply.CurrentBlinkWeight == 1 then
                    ply.BlinkState = 0
                end
            end
        end
        return true
    else
        if CLIENT and ply.HorseBoundsApplied then
            ply:SetRenderBounds(Vector(-16, -16, 0), Vector(16, 16, 72))
            ply.HorseBoundsApplied = nil
        end
    end
end)

hook.Add("PrePlayerDraw", ceilhorse.ID, function(ply, flags)
    if not IsValid(ply) or not ply:IsHorse() then return end

    if CLIENT then
        if ply == LocalPlayer() then
            local gear = ply:GetGear() or 0
            local targetYaw = ply:GetAngles().y
            local isAltDown = (ply.HorseFreelookYaw ~= nil)

            if gear == 0 or isAltDown then
                if not ply.HorseWasStopped then
                    ply.HorseLockedYaw = ply.HorseFreelookYaw or ply:GetAngles().y
                    ply.HorseWasStopped = true
                end

                if ply.HorseLockedYaw then
                    targetYaw = ply.HorseLockedYaw
                end
            else
                ply.HorseWasStopped = false

                if ply.HorseLockedYaw then
                    local currentAng = ply:GetAngles()
                    local diff = math.abs(math.AngleDifference(ply.HorseLockedYaw, currentAng.y))

                    if diff > 2 then
                        local smoothedAng = LerpAngle(FrameTime() * 10, Angle(0, ply.HorseLockedYaw, 0), currentAng)
                        ply.HorseLockedYaw = smoothedAng.y
                        targetYaw = ply.HorseLockedYaw
                    else
                        ply.HorseLockedYaw = nil
                    end
                end
            end

            local pos = ply:GetPos()
            local tr = util.TraceHull({
                start = pos + Vector(0, 0, 24),
                endpos = pos - Vector(0, 0, 56),
                mins = Vector(-12, -12, 0),
                maxs = Vector(12, 12, 5),
                filter = ply,
                mask = {}
            })

            local finalAng = Angle(0, targetYaw, 0)

            ply.HorseSmoothNormal = ply.HorseSmoothNormal or Vector(0, 0, 1)
            if tr.Hit then
                ply.HorseSmoothNormal = LerpVector(FrameTime() * 8, ply.HorseSmoothNormal, tr.HitNormal):GetNormalized()
            else
                ply.HorseSmoothNormal = LerpVector(FrameTime() * 4, ply.HorseSmoothNormal, Vector(0, 0, 1)):GetNormalized()
            end

            local right = finalAng:Right()
            local fwd = ply.HorseSmoothNormal:Cross(right):GetNormalized()
            finalAng = Angle(fwd:Angle().p, targetYaw, 0)

            ply.HorseVisualAngle = ply.HorseVisualAngle or finalAng
            ply.HorseVisualAngle = LerpAngle(FrameTime() * 12, ply.HorseVisualAngle, finalAng)

            ply:InvalidateBoneCache()
            ply:SetRenderAngles(ply.HorseVisualAngle)
            ply:SetupBones()

            ply.HorseNextSync = ply.HorseNextSync or 0
            if CurTime() > ply.HorseNextSync then
                net.Start(ceilhorse.ID .. "_SyncAngle", true)
                net.WriteAngle(ply.HorseVisualAngle)
                net.SendToServer()
                ply.HorseNextSync = CurTime() + 0.033
            end
        else
            local replicatedAng = ply:GetHorseVisualAngle()
            if replicatedAng then
                ply.HorseInterpolatedAngle = ply.HorseInterpolatedAngle or replicatedAng
                ply.HorseInterpolatedAngle = LerpAngle(FrameTime() * 15, ply.HorseInterpolatedAngle, replicatedAng)

                ply:InvalidateBoneCache()
                ply:SetRenderAngles(ply.HorseInterpolatedAngle)
                ply:SetupBones()
            end
        end
    end
end)

hook.Add("PlayerFootstep", ceilhorse.ID, function(ply, pos, foot, sound, volume, rf)
    if ply:IsHorse() then
        return true
    end
end)

hook.Add("EntityNetworkedVarChanged", ceilhorse.ID, function(ply, name, old, new)
    if name == (ceilhorse.ID .. "IsHorse") and IsValid(ply) and ply:IsPlayer() then
        if new == true then
            ply:SetWalkSpeed(550 * ceilhorse.speedsetup)
            ply:SetRunSpeed(550 * ceilhorse.speedsetup)
            ply:SetMaxSpeed(550 * ceilhorse.speedsetup)
            ply:SetJumpPower(300)
            ply:SetViewOffset(Vector(0, 0, 70))
            ply:SetViewOffsetDucked(Vector(0, 0, 50))
            ply:SetHull(Vector(-20, -20, 0), Vector(20, 20, 70))
            ply:SetHullDuck(Vector(-20, -20, 0), Vector(20, 20, 50))
        else
            ply:SetWalkSpeed(ply:GetNW2Float("PreHorseWalkSpeed", 200))
            ply:SetRunSpeed(ply:GetNW2Float("PreHorseRunSpeed", 400))
            ply:SetMaxSpeed(ply:GetNW2Float("PreHorseMaxSpeed", 400))
            ply:SetJumpPower(ply:GetNW2Float("PreHorseJumpPower", 200))
            ply:SetViewOffset(ply:GetNW2Vector("PreHorseViewOffset", Vector(0,0,64)))
            ply:SetViewOffsetDucked(ply:GetNW2Vector("PreHorseViewOffsetDucked", Vector(0,0,28)))

            local minHull = ply:GetNW2Vector("PreHorseHullMin", Vector(-16,-16,0))
            local maxHull = ply:GetNW2Vector("PreHorseHullMax", Vector(16,16,72))
            ply:SetHull(minHull, maxHull)
            ply:SetHullDuck(minHull, Vector(maxHull.x, maxHull.y, 36))
        end
    end
end)


local function GetPlayerGroundSurfaceData(ply)
    if not IsValid(ply) then return nil end

    local pos = ply:GetPos()

    local tr = util.TraceLine({
        start = pos,
        endpos = pos - Vector(0, 0, 50),
        filter = ply,
        mask = MASK_PLAYERSOLID
    })

    if not tr.Hit or not tr.SurfaceProps then
        return nil
    end

    local surfaceData = util.GetSurfaceData(tr.SurfaceProps)
    local surfaceName = util.GetSurfacePropName(tr.SurfaceProps)

    return surfaceData, surfaceName, tr.HitTexture
end

hook.Add( "EntityEmitSound", ceilhorse.ID, function( t )

    local target = t.Entity

    if target:IsPlayer() and target:IsHorse() then
        local ply = target
        local data, name, texture = GetPlayerGroundSurfaceData(ply)
        if data then

--             print("---------Sound Properties-----------")
            local soundlist = sound.GetProperties( data.stepLeftSound )

             local newsound = soundlist.sound[math.random(#soundlist.sound)]

            t.SoundName = newsound


            t.Pitch = 60
            t.Volume = t.Volume*0.3

            return true
        else
            return false
        end
    end

end)

ceilhorse.meta = FindMetaTable("Player")

function ceilhorse.meta:SetHorse(bool)
    self:SetNW2Bool(ceilhorse.ID .. "IsHorse", bool)
end

function ceilhorse.meta:IsHorse()
    return self:GetNW2Bool(ceilhorse.ID .. "IsHorse")
end

function ceilhorse.meta:SetGear(int)
    self:SetNW2Int(ceilhorse.ID .. "Gear", int)
end

function ceilhorse.meta:GetGear()
    return self:GetNW2Int(ceilhorse.ID .. "Gear")
end

function ceilhorse.meta:SetHorseVisualAngle(ang)
    self:SetNW2Angle(ceilhorse.ID .. "VisualAngle", ang)
end

function ceilhorse.meta:GetHorseVisualAngle()
    return self:GetNW2Angle(ceilhorse.ID .. "VisualAngle", self:GetAngles())
end

function ceilhorse.meta:SetHorseStamina(float)
    self:SetNW2Float("HorseStamina", float)
end

function ceilhorse.meta:GetHorseStamina()
    return self:GetNW2Float("HorseStamina")
end
