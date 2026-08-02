AddCSLuaFile("b375d1f9edf2618916fc2dff9313_config.lua")
include("b375d1f9edf2618916fc2dff9313_config.lua")

--resource.AddWorkshop( "3770296572")

util.AddNetworkString(ceilhorse.ID .. "_ToggleView")
util.AddNetworkString(ceilhorse.ID .. "_SyncAngle")

net.Receive(ceilhorse.ID .. "_ToggleView", function(len, ply)
    if not IsValid(ply) or not ply:IsHorse() then return end
    local state = net.ReadBool()
    ply:SetNW2Bool(ceilhorse.ID .. "_FirstPerson", state)
end)

net.Receive(ceilhorse.ID .. "_SyncAngle", function(len, ply)
    if not IsValid(ply) or not ply:IsHorse() then return end
    local ang = net.ReadAngle()
    ply:SetHorseVisualAngle(ang)
end)

if SERVER then
    local function DismountPlayer(ply, isDead)
        if not IsValid(ply) or not ply:IsHorse() then return end

        local currentPos = ply:GetPos()
        local currentAng = ply:EyeAngles()
        local currentHorseHP = ply:Health()
        local currentHorseMaxHP = ply:GetMaxHealth()

        if IsValid(ply.CavalierLeurre) then
            ply.CavalierLeurre:Remove()
            ply.CavalierLeurre = nil
        end

        local horseEnt = ents.Create("horse")

        local spawnPos = currentPos
        local spawnAng = Angle(0, currentAng.y, 0)

        if isDead then
            local tr = util.TraceHull({
                start = currentPos,
                endpos = currentPos - Vector(0, 0, 10000),
                mins = Vector(-20, -20, 0),
                maxs = Vector(20, 20, 70),
                filter = ply,
                mask = {}
            })

            if tr.Hit then
                spawnPos = tr.HitPos

                local right = spawnAng:Right()
                local fwd = tr.HitNormal:Cross(right):GetNormalized()
                spawnAng = Angle(fwd:Angle().p, currentAng.y, 0)
            end
        end

        horseEnt:SetPos(spawnPos)
        horseEnt:SetAngles(spawnAng)
        horseEnt:Spawn()

        if isDead then
            horseEnt.IsDeadHorse = true
            horseEnt:SetNW2Bool("IsDeadHorse", true)
            horseEnt:SetHealth(0)
            horseEnt:StopMotionController()

            horseEnt:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

            local phys = horseEnt:GetPhysicsObject()
            if IsValid(phys) then
                phys:EnableMotion(false)
            end

            local seq = horseEnt:LookupSequence("death")
            if seq == -1 then seq = horseEnt:LookupSequence("die") end
            if seq ~= -1 then
                horseEnt:ResetSequence(seq)
            end
        else
            horseEnt:SetMaxHealth(currentHorseMaxHP)
            horseEnt:SetHealth(currentHorseHP)
        end

        ply:SetModel(ply.PreHorseModel or "models/player/kleiner.mdl")
        ply:SetNW2String("PreHorseModel", "")

        -- On remet la skin et les bodygroups sauvegardés sur le joueur (forcé après le changement de modèle)
        ply:SetSkin(ply:GetNW2Int("PreHorseSkin", 0))
        local bgStr = ply:GetNW2String("PreHorseBodyGroups", "")
        if bgStr ~= "" then
            local bgs = string.Explode(";", bgStr)
            for i, v in ipairs(bgs) do
                ply:SetBodygroup(i - 1, tonumber(v) or 0)
            end
        end
        ply:SetNW2String("PreHorseBodyGroups", "")

        ply:SetMaxHealth(ply:GetNW2Int("PreHorseMaxHealth", 100))
        ply:SetHealth(ply:GetNW2Int("PreHorseHealth", 100))
        ply:SetArmor(ply:GetNW2Int("PreHorseArmor", 0))

        if not isDead then
            local rightOffset = currentAng:Right() * 50

            local tr = util.TraceHull({
                start = currentPos,
                endpos = currentPos + rightOffset,
                mins = Vector(-16, -16, 0),
                maxs = Vector(16, 16, 72),
                filter = {ply, horseEnt},
                mask = {}
            })

            if not tr.Hit then
                ply:SetPos(currentPos + rightOffset)
            else
                ply:SetPos(currentPos + Vector(0,0,50))
            end
        end

        ply:SetGear(0)
        ply:SetHorse(false)

        if ply.PreHorseWeapons and istable(ply.PreHorseWeapons) then
            for _, data in ipairs(ply.PreHorseWeapons) do
                local wpn = ply:Give(data.class)
                if IsValid(wpn) then
                    ply:SetAmmo(data.clip1, wpn:GetPrimaryAmmoType())
                    wpn:SetClip1(data.clip1)
                    wpn:SetClip2(data.clip2)
                end
            end

            if ply.PreHorseActiveWep then
                ply:SelectWeapon(ply.PreHorseActiveWep)
            end
        end

        ply.PreHorseWeapons = nil
        ply.PreHorseActiveWep = nil

        return horseEnt
    end

    hook.Add("KeyPress", ceilhorse.ID, function(ply, key)
        if ply:IsHorse() and key == IN_USE and ply:Alive() then
            DismountPlayer(ply, false)
        end
    end)

    hook.Add("EntityTakeDamage", ceilhorse.ID, function(target, dmginfo)
        if target:IsPlayer() and target:IsHorse() then
            if target:Health() - dmginfo:GetDamage() <= 0 then
                dmginfo:SetDamage(0)
                DismountPlayer(target, true)
                return true
            end
        end
    end)

    hook.Add("DoPlayerDeath", ceilhorse.ID, function(ply, attacker, dmg)
        if ply:IsHorse() then
            DismountPlayer(ply, true)
        end
    end)

    hook.Add("PlayerDisconnected", ceilhorse.ID, function(ply)
        if ply:IsHorse() then
            DismountPlayer(ply, false)
        end
    end)

    hook.Add("PlayerTick", ceilhorse.ID .. "_Stamina", function(ply, mv)
        if not ply:IsHorse() then return end

        local gear = ply:GetGear()
        local stamina = ply:GetHorseStamina()
        local ft = engine.TickInterval()

        if gear == 4 then
            if stamina > 0 then
                ply:SetHorseStamina(math.max(0, stamina - (25 * ft)))
            end
        else
            if stamina < 100 then
                ply:SetHorseStamina(math.min(100, stamina + (15 * ft)))
            end
        end
    end)
end
