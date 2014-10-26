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
	[783] = true, -- travel form, post 6.0
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
	87840, -- running wild
	165962, -- flight form
}

ns.f = CreateFrame('Frame', KuiMountFrame)

------------------------------------------------------------------- functions --
ns.mountlist,ns.nummounts = {},0
ns.GetMounts = function()
	ns.mountlist = {}
	ns.nummounts = 0

	for i = 1,C_MountJournal.GetNumMounts() do
		local mountname,_,_,_,_,_,_,_,_,_,collected =
			C_MountJournal.GetMountInfo(i)

		if collected then
			ns.mountlist[strlower(mountname)] = i
			ns.nummounts = ns.nummounts + 1
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

local function Mount(legacy)
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
	   ns.mountlist['vashj\'ir seahorse'] and
	   not IsShiftKeyDown
	then -- use the seapony in vashj'ir
		local spellid = select(2,C_MountJournal.GetMountInfo(ns.mountlist['vashj\'ir seahorse']))
		tinsert(usable, spellid)
	elseif not useFlying
		   and IsShiftKeyDown
		   and ns.mountlist['azure water strider']
	then -- use the water strider
		local spellid = select(2,C_MountJournal.GetMountInfo(ns.mountlist['azure water strider']))
		tinsert(usable, spellid)
	else
		-- find all usable mounts
		local _, id
		for _, id in pairs(ns.mountlist) do
			local name,spellid,is_usable

			if type(id) == 'table' then
				-- parse non-companion mounts
				name,spellid = unpack(id)
				is_usable = IsUsableSpell(spellid)
			else
				name,spellid,_,_,is_usable,_,_,_,_,_,_ =
					C_MountJournal.GetMountInfo(id)
				is_usable = is_usable and IsUsableSpell(spellid)
			end

			if is_usable then
				local desc = strlower(GetSpellDescription(spellid))

				-- detect hybrid/flying mounts
				local hybrid, flying
				hybrid = extraHybrid[spellid] or
				         strfind(desc, 'mount changes') or
						 strfind(desc, 'capabilities of this')
				
				if not hybrid then
					flying = strfind(desc, 'flying') or strfind(desc, 'flight')
				end

				if (useFlying and (flying or hybrid)) or
					(not useFlying and (
				     (useHybrid and not flying) or
				     (not flying and not hybrid)
				    ))
				then
					tinsert(usable, spellid)
					--print('['..id..', '..(flying and 'fly' or '')..' '..(hybrid and 'hybrid' or '')..'] '..name)

					if whitelist[name] then
						tinsert(usablewl, spellid)
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
		-- TODO the combat lockdown event -might- -maybe- let me switch the
		-- actions to combat mode without firing errors
		return
	end

	-- blank the macro so that we don't get 2 uierrors if no mount is usable
	SecureButton:SetAttribute('macrotext', '')
	Mount()
end

-- events ----------------------------------------------------------------------
ns.f:SetScript('OnEvent', function(self, event, ...)
	if event == 'PLAYER_ENTERING_WORLD' or event == 'COMPANION_LEARNED' then
		-- update mount list upon learning new mounts or zoning
		ns.GetMounts()
	elseif event == 'ADDON_LOADED' then
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
ns.f:RegisterEvent('COMPANION_LEARNED')
ns.f:RegisterEvent('PLAYER_ENTERING_WORLD')

ns.Mount = Mount

-- globals for key binding support
BINDING_HEADER_KUIMOUNT_HEADER = 'Kui Mount'
setglobal("BINDING_NAME_CLICK KuiMountSecureButton:LeftButton", "Mount")
KuiMountMount = Mount
