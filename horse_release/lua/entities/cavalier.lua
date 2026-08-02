AddCSLuaFile()

DEFINE_BASECLASS( "base_anim" )

ENT.PrintName = "Cavalier Leurre"
ENT.Author = "CeiLciuZ"
ENT.Category = "RealHorse"
ENT.AutomaticFrameAdvance = true

ENT.Editable = false
ENT.Spawnable = false
ENT.AdminOnly = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

function ENT:Initialize()
	self:SetModel( "models/senior/horse/cavalier.mdl" )

	local seq = self:LookupSequence("entry")
	if seq == -1 then seq = 0 end
	self:ResetSequence(seq)
	self:SetPlaybackRate(1)
	self:SetCycle(0)

	if SERVER then
		self:SetSolid(SOLID_NONE)
		self:SetMoveType(MOVETYPE_NONE)
	end

	if CLIENT then
		self.cavalier = ClientsideModel("models/player/breen.mdl")
		self.cavalier:SetParent(self)
		self.cavalier:AddEffects(EF_BONEMERGE)
		self.cavalier:SetNoDraw(true)

		self:SetRenderBounds(Vector(-500, -500, -500), Vector(500, 500, 500))
		self.cavalier:SetRenderBounds(Vector(-500, -500, -500), Vector(500, 500, 500))
	end
end

function ENT:OnRemove()
	if CLIENT then
		if IsValid(self.cavalier) then
			self.cavalier:Remove()
			self.cavalier = nil
		end
	end
end

function ENT:Think()
	if SERVER then
		if not IsValid(self:GetParent()) then
			self:Remove()
		end
	end

	if CLIENT then
		self:FrameAdvance(FrameTime())
	end

	self:NextThink( CurTime() )
	return true
end

if SERVER then return end

function ENT:Draw()
	local parent = self:GetParent()
	if not IsValid(parent) or not parent:IsPlayer() then return end

	parent:SetupBones()

	local attachID = parent:LookupAttachment("seat")
	if attachID and attachID > 0 then
		local attachData = parent:GetAttachment(attachID)
		if attachData then
			local offsetPos = Vector(0, -5, -58)
			local offsetAng = Angle(0, 90, 0)
			local finalPos, finalAng = LocalToWorld(offsetPos, offsetAng, attachData.Pos, attachData.Ang)

			self:SetRenderOrigin(finalPos)
			self:SetRenderAngles(finalAng)
		end
	end

	self:SetupBones()

	local isLocalAndFirstPerson = (parent == LocalPlayer() and ceilhorse.HorseFirstPerson)

	if not isLocalAndFirstPerson then
		self:DrawModel()
	end

	if IsValid(self.cavalier) then
		local targetModel = parent:GetNW2String("PreHorseModel", "models/player/breen.mdl")
		if targetModel == ceilhorse.horsemdl or targetModel == "" then
			targetModel = "models/player/breen.mdl"
		end

		if self.cavalier:GetModel() ~= targetModel then
			self.cavalier:SetModel(targetModel)
		end

        -- Restitution des skins et des bodygroups sur le leurre client-side
        local pSkin = parent:GetNW2Int("PreHorseSkin", 0)
        if self.cavalier:GetSkin() ~= pSkin then
            self.cavalier:SetSkin(pSkin)
        end

        local bgStr = parent:GetNW2String("PreHorseBodyGroups", "")
        if bgStr ~= "" then
            local bgs = string.Explode(";", bgStr)
            for i, v in ipairs(bgs) do
                local bgID = i - 1
                local bgVal = tonumber(v) or 0
                if self.cavalier:GetBodygroup(bgID) ~= bgVal then
                    self.cavalier:SetBodygroup(bgID, bgVal)
                end
            end
        end

		local goodcolor = parent:GetPlayerColor()
		self.cavalier.GetPlayerColor = function() return goodcolor end

		if not isLocalAndFirstPerson then
			self.cavalier:DrawModel()
			if !IsValid(self.cavalier:GetParent()) then
				self.cavalier:SetParent(self)
			end
		end
	end
end
