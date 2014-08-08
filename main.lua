--[[
	Kui Mount
	Kesava-Auchindoun
]]
local addon, ns = ...
local select, strfind, strlower, tonumber, tinsert
	= select, strfind, strlower, tonumber, tinsert
local professions, i, x
local SecureButton

local swimZones = {
	['Vashj\'ir'] = true,
	['Ruins of Vashj\'ir'] = true,
	['Abyssal Depths'] = true,
	['Kelp\'thar Forest'] = true,
	['Shimmering Expanse'] = true,
	['Damplight Chamber'] = true,
	['Beth\'mora Ridge'] = true,
}

-- these mounts don't specify that they can fly in their tooltip
local extraHybrid = {
	[121837] = true, -- jade panther
	[120043] = true, -- jeweled onyx panther
	[121838] = true, -- ruby panther
	[121836] = true, -- sapphire panther
	[121839] = true, -- sunstone panther
}

-- these mounts aren't companions
-- (travel/ghost wolf won't actually work in combat without some more code
-- modification but they're here for when it's ready)
local spellIdMounts = {
	783,   -- travel form
	1066,  -- aquatic form
	2645,  -- ghost wolf
	33943, -- flight form
	40120, -- swift ''
	87840, -- running wild
}

local CLOUD_SERPENT_SKILL_ID = 130487

ns.f = CreateFrame('Frame', KuiMountFrame)

------------------------------------------------------------------- functions --

ns.nummounts, ns.mountlist = 0, {}
ns.GetMounts = function()
	if GetNumCompanions('mount') ~= ns.nummounts then
		-- repopulate the mount list
		ns.nummounts = GetNumCompanions('mount')
		ns.mountlist = {}
		
		local i
		for i = 1, ns.nummounts do
			local _, mountname, spellid = GetCompanionInfo('mount', i) 
			ns.mountlist[strlower(mountname)] = { mountname, spellid }
		end
	end

	-- add non-companion mounts
	for _,id in pairs(spellIdMounts) do
		if IsSpellKnown(id) then
			local name = GetSpellInfo(id)
			ns.mountlist[strlower(name)] = { name, id }
		end
	end
end

local function MeetsProfessionRequirement(description)
	-- detect profession requirements
	-- even though IsUsableSpell returned true. siiiiigh
	local usable = true
	local pdesc = select(3, strfind(description, '(requires.-skill.-%.)'))
	
	if pdesc then
		-- find the profession skill level required
		local skill = tonumber(select(3, strfind(pdesc, '(%d+)')))
		local prof
		
		-- and, more annoyingly, name
		if strfind(pdesc, 'engineering') then
			prof = 'engineering'
		elseif strfind(pdesc, 'tailoring') then
			prof = 'tailoring'
		end
		
		if not professions then
			professions = { GetProfessions() }
			
			for x = 1,2 do
				if professions[x] then
					local pname, _, pskill = GetProfessionInfo(professions[x])
					professions[strlower(pname)] = pskill
				end
			end
		end
		
		-- and finally test if we can actually use the mount
		if not professions[prof] or professions[prof] < skill then
			usable = false
		end
	end
	
	return usable
end

local function MeetsCloudSerpentRequirement(name)
	-- this is to workaround a bug where if you stand in water, IsUsableSpell
	-- returns true with cloud serpents even if you don't have the relevant
	-- skill. It works as normal when not standing in water.
	if name:match(' Cloud Serpent$') then
		return IsSpellKnown(CLOUD_SERPENT_SKILL_ID)
	else
		return true
	end
end

local function Mount(legacy)
	-- Collect usable mounts ---------------------------------------------------
	ns.GetMounts()
	if ns.nummounts <= 0 then
		UIErrorsFrame:AddMessage('You don\'t have any mounts', 1,0,0)
		return
	end
	
	local whitelist = ns.GetActiveList()
	local useHybrid = KuiMountSaved.useHybrid
	
	local usable, usablewl = {}, {}
	local IsAltKeyDown, IsControlKeyDown, IsShiftKeyDown, IsFlyableArea
		= IsAltKeyDown(), IsControlKeyDown(), IsShiftKeyDown(), IsFlyableArea()

	local useFlying, isSwimZone =
		not IsControlKeyDown and IsFlyableArea,
		IsSwimming() and swimZones[GetZoneText()]		

	if isSwimZone and
	   ns.mountlist['abyssal seahorse'] and
	   not IsShiftKeyDown
	then -- use the seapony in vashj'ir
		tinsert(usable, ns.mountlist['abyssal seahorse'][2])
	elseif not useFlying
		   and IsShiftKeyDown
		   and ns.mountlist['azure water strider']
	then -- use the water strider
		tinsert(usable, ns.mountlist['azure water strider'][2])
	else
		professions = nil -- search professions once per call

		-- find all usable mounts
		local _, mount
		for _, mount in pairs(ns.mountlist) do
			local name, id = unpack(mount)
			local desc = strlower(GetSpellDescription(id))

			if IsUsableSpell(id) and
			   MeetsProfessionRequirement(desc) and
			   MeetsCloudSerpentRequirement(name)
			then
				-- detect hybrid/flying mounts
				local hybrid, flying
				hybrid = extraHybrid[id] or
				         strfind(desc, 'mount changes') or
						 strfind(desc, 'capabilities of this mount')
				
				if not hybrid then
					flying = strfind(desc, 'flying') or strfind(desc, 'flight')
				end

				if (useFlying and (flying or hybrid)) or
					(not useFlying and (
				     (useHybrid and not flying) or
				     (not flying and not hybrid)
				    ))
				then
					tinsert(usable, id)
					--print('['..id..', '..(flying and 'fly' or '')..' '..(hybrid and 'hybrid' or '')..'] '..name)

					if whitelist[name] then
						tinsert(usablewl, id)
					end
				end
			end
		end
	end

	if #usablewl > 0 then
		-- use mount from whitelist
		usable = usablewl
	end

	-- Select usable mount -----------------------------------------------------
	if #usable > 0 then
		local name = GetSpellInfo(usable[math.random(1, #usable)])
		if legacy then
			CastSpellByName(name)
		else
			SecureButton:SetAttribute('macrotext', '/cast '..name)
		end
	else
		UIErrorsFrame:AddMessage('Couldn\'t find a usable mount', 1,0,0)
	end
end

-- secure button handlers ------------------------------------------------------
local function ButtonPreClick(self)
	if UnitInVehicle('player') then 
		VehicleExit()
		return
	end
	if IsMounted('player') then
		Dismount()
		return
	end

	if InCombatLockdown() then
		-- TODO a second button could handle combat actions i.e. ghost wolf
		return
	end

	-- blank the macro so that we don't get 2 uierrors if no mount is usable
	SecureButton:SetAttribute('macrotext', '')
	Mount()
end

-- events ----------------------------------------------------------------------
ns.f:SetScript('OnEvent', function(self, event, ...)
	if event == 'ADDON_LOADED' then
		if ... ~= addon then return end

		SecureButton = CreateFrame("Button", 'KuiMountSecureButton', UIParent, "SecureActionButtonTemplate, ActionButtonTemplate")
		SecureButton:SetAttribute('type','macro')
		SecureButton:SetScript('PreClick', ButtonPreClick)

		-- initialise saved variables
		-- acount wide
		if not KuiMountSaved then
			KuiMountSaved = {}
		end

		if not KuiMountSaved.Sets then
			KuiMountSaved.Sets = {
				['One'] = KuiMountSaved.whitelist or {},
				['Two'] = KuiMountSaved.blacklist or {},
				['Three'] = {}
			}
		end

		if KuiMountSaved.useHybrid == nil then
			KuiMountSaved.useHybrid = true
		end

		-- character specific
		if not KuiMountCharacter then
			KuiMountCharacter = {}
		end

		if not KuiMountCharacter.ActiveSet then
			KuiMountCharacter.ActiveSet = 'One'
		end

		if not KuiMountCharacter.list then
			KuiMountCharacter.list = KuiMountCharacter.whitelist or {}
		end
	end
end)
ns.f:RegisterEvent('ADDON_LOADED')

ns.Mount = Mount

-- globals for key binding support
BINDING_HEADER_KUIMOUNT_HEADER = 'Kui Mount'
setglobal("BINDING_NAME_CLICK KuiMountSecureButton:LeftButton", "Mount")
KuiMountMount = Mount
