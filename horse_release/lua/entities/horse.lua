AddCSLuaFile()

DEFINE_BASECLASS( "base_anim" )

ENT.PrintName = "Horse"
ENT.Author = "CeiLciuZ"
ENT.Information = "Realistic horse"
ENT.Category = "RealHorse"
ENT.AutomaticFrameAdvance = true

ENT.Editable = false
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

if SERVER then
    function ENT:Initialize()
        self:SetModel(ceilhorse.horsemdl)

        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetMass(350)
            phys:Wake()
        end
        self:Activate()
        self:StartMotionController()

        self:SetMaxHealth(ceilhorse.defaulthealth)
        self:SetHealth(ceilhorse.defaulthealth)

        self:ResetSequence("idleA")
        self.NextCanUse = CurTime() + 0.5
    end

    function ENT:OnTakeDamage(dmginfo)
        if self:GetNW2Bool("IsDeadHorse", false) then return end

        self:SetHealth(self:Health() - dmginfo:GetDamage())

        if self:Health() <= 0 then
            self.IsDeadHorse = true
            self:SetNW2Bool("IsDeadHorse", true)
            self:SetHealth(0)
            self:StopMotionController()

            self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

            local currentPos = self:GetPos()
            local currentAng = self:GetAngles()
            local spawnPos = currentPos
            local spawnAng = Angle(0, currentAng.y, 0)

            local tr = util.TraceHull({
                start = currentPos,
                endpos = currentPos - Vector(0, 0, 10000),
                mins = Vector(-20, -20, 0),
                maxs = Vector(20, 20, 70),
                filter = self,
                mask = {}
            })

            if tr.Hit then
                spawnPos = tr.HitPos
                local right = spawnAng:Right()
                local fwd = tr.HitNormal:Cross(right):GetNormalized()
                spawnAng = Angle(fwd:Angle().p, currentAng.y, 0)
            end

            self:SetPos(spawnPos)
            self:SetAngles(spawnAng)

            local phys = self:GetPhysicsObject()
            if IsValid(phys) then
                phys:EnableMotion(false)
            end

            local seq = self:LookupSequence("death")
            if seq == -1 then seq = self:LookupSequence("die") end
            if seq ~= -1 then
                self:ResetSequence(seq)
                self:SetPlaybackRate(1)
                self:SetCycle(0)
            end
        end
    end
end

function ENT:PhysicsSimulate(phys, deltatime)
    if not SERVER then return SIM_NOTHING end
    if not IsValid(phys) then return SIM_NOTHING end
    if self:GetNW2Bool("IsDeadHorse", false) then return SIM_NOTHING end

    local currentAng = self:GetAngles()
    local targetAng = Angle(0, currentAng.y, 0)

    local shadowParams = {
        secondstotime   = 0.01,
        pos             = phys:GetPos(),
        angle           = targetAng,
        maxangular      = 5000,
        maxangulardamp  = 10000,
        maxspeed        = 0,
        maxspeeddamp    = 0,
        deltatime       = deltatime
    }

    phys:ComputeShadowControl(shadowParams)

    return SIM_GLOBAL_ACCELERATION
end

function ENT:OnRemove()
    if SERVER then
        self:StopMotionController()
    end
end

function ENT:Use(activator, caller)
    if self:GetNW2Bool("IsDeadHorse", false) then return end
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if activator:IsHorse() then return end
    if CurTime() < self.NextCanUse then return end

    local horsePos = self:GetPos()
    local horseAng = self:GetAngles()
    local phys = self:GetPhysicsObject()
    local horseVel = IsValid(phys) and phys:GetVelocity() or vector_origin

    local horseHP = self:Health()
    local horseMaxHP = self:GetMaxHealth()

    activator.PreHorseModel = activator:GetModel()
    activator:SetNW2String("PreHorseModel", activator:GetModel())

    -- Sauvegarde de la skin et des bodygroups du joueur
    activator:SetNW2Int("PreHorseSkin", activator:GetSkin())
    local bgs = {}
    for i = 0, activator:GetNumBodyGroups() - 1 do
        table.insert(bgs, activator:GetBodygroup(i))
    end
    activator:SetNW2String("PreHorseBodyGroups", table.concat(bgs, ";"))

    local hullMin, hullMax = activator:GetHull()

    activator:SetNW2Int("PreHorseHealth", activator:Health())
    activator:SetNW2Int("PreHorseMaxHealth", activator:GetMaxHealth())
    activator:SetNW2Int("PreHorseArmor", activator:Armor())

    activator:SetNW2Float("PreHorseWalkSpeed", activator:GetWalkSpeed())
    activator:SetNW2Float("PreHorseRunSpeed", activator:GetRunSpeed())
    activator:SetNW2Float("PreHorseMaxSpeed", activator:GetMaxSpeed())
    activator:SetNW2Float("PreHorseJumpPower", activator:GetJumpPower())
    activator:SetNW2Vector("PreHorseViewOffset", activator:GetViewOffset())
    activator:SetNW2Vector("PreHorseViewOffsetDucked", activator:GetViewOffsetDucked())
    activator:SetNW2Vector("PreHorseHullMin", hullMin)
    activator:SetNW2Vector("PreHorseHullMax", hullMax)

    activator.PreHorseWeapons = {}
    local activeWep = activator:GetActiveWeapon()
    if IsValid(activeWep) then
        activator.PreHorseActiveWep = activeWep:GetClass()
    end

    for _, wpn in ipairs(activator:GetWeapons()) do
        table.insert(activator.PreHorseWeapons, {
            class = wpn:GetClass(),
            clip1 = wpn:Clip1(),
            clip2 = wpn:Clip2()
        })
    end
    activator:StripWeapons()

    activator:SetModel(ceilhorse.horsemdl)
    activator:SetPos(horsePos)
    activator:SetAngles(Angle(0, horseAng.y, 0))
    activator:SetEyeAngles(Angle(horseAng.p, horseAng.y, 0))

    activator:SetMaxHealth(horseMaxHP)
    activator:SetHealth(horseHP)
    activator:SetArmor(0)

    local activatorPhys = activator:GetPhysicsObject()
    if IsValid(activatorPhys) then
        activatorPhys:SetVelocity(horseVel)
    end

    activator:SetPoseParameter("move_x", 0)
    activator:SetPoseParameter("move_y", 0)

    if SERVER then
        local cavalierEnt = ents.Create("cavalier")
        if IsValid(cavalierEnt) then
            cavalierEnt:SetPos(horsePos)
            cavalierEnt:SetAngles(horseAng)
            cavalierEnt:SetParent(activator)
            cavalierEnt:Spawn()

            cavalierEnt:Fire("SetParentAttachment", "seat", 0)

            activator.CavalierLeurre = cavalierEnt
            activator:SetNW2Entity("HorseDecoy", cavalierEnt)
        end
    end

    activator:SetGear(0)
    activator:SetHorseStamina(100)
    activator:SetHorse(true)

    self:Remove()
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()

        local flexID = self:GetFlexIDByName("blink")
        if not flexID then return end

        if not self:GetNW2Bool("IsDeadHorse") then
            self.BlinkState = self.BlinkState or 0
            self.NextBlinkCheck = self.NextBlinkCheck or 0

            local currentWeight = self:GetFlexWeight(flexID)
            local newWeight = math.Approach(currentWeight, self.BlinkState, FrameTime() * 12)
            self:SetFlexWeight(flexID, newWeight)

            if currentWeight == 0 and CurTime() > self.NextBlinkCheck then
                if math.random(1, 100) <= 15 then
                    self.BlinkState = 1
                end
                self.NextBlinkCheck = CurTime() + .5
            elseif currentWeight == 1 then
                self.BlinkState = 0
            end
        else
            self.BlinkState = self.BlinkState or 0
            self:SetFlexWeight(flexID, 1)
        end
    end
end
