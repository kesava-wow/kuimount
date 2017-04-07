-- Kui Mount
-- By Kesava at curse.com
-- All rights reserved
local addon, ns = ...
local select, strfind, strlower, tonumber, tinsert
    = select, strfind, strlower, tonumber, tinsert
local _,i,x
local SecureButton

local MOUNT_IDS

local swimZones = {
    ['Vashj\'ir'] = true,
    ['Ruins of Vashj\'ir'] = true,
    ['Abyssal Depths'] = true,
    ['Kelp\'thar Forest'] = true,
    ['Shimmering Expanse'] = true,
    ['Damplight Chamber'] = true,
    ['Beth\'mora Ridge'] = true,
}

-- zones that aren't flyable despite being flagged as such
local nonFlyZones = {
    ['The Wandering Isle'] = true,
    ['Helheim'] = true,
    ['Skyhold'] = true,
    ['Niskara'] = true,
    ['Dreadscar Rift'] = true,
    ['The Maelstrom'] = true,
}

-- spell id mounts which don't specify they can fly in their tooltip
local extraHybrid = {
    [783] = true, -- travel form, post 6.0
}

-- these mounts aren't companions
-- (travel/ghost wolf won't actually work in combat without some more code
-- modification but they're here for when it's ready)
-- when indoors, spells which can be used indoors will be fallen back on
local spellIdMounts = {
    768,   -- cat form
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
            C_MountJournal.GetMountInfoByID(MOUNT_IDS[i])

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

    local useFlying = (not IsControlKeyDown() and IsFlyableArea()) and
                      (not nonFlyZones[GetZoneText()])

    local isSwimZone = IsSwimming() and swimZones[GetZoneText()]

    if isSwimZone and
       ns.mountlist['vashj\'ir seahorse'] and
       not IsShiftKeyDown()
    then -- use the seapony in vashj'ir
        local spellid = select(2,C_MountJournal.GetMountInfoByID(MOUNT_IDS[ns.mountlist['vashj\'ir seahorse']]))
        tinsert(usable, spellid)
    elseif not useFlying
           and IsShiftKeyDown()
           and ns.mountlist['azure water strider']
    then -- use the water strider
        local spellid = select(2,C_MountJournal.GetMountInfoByID(MOUNT_IDS[ns.mountlist['azure water strider']]))
        tinsert(usable, spellid)
    else
        -- find all usable mounts
        local _, id
        for _, id in pairs(ns.mountlist) do
            local name,spellid,is_usable
            local flying

            if type(id) == 'table' then
                -- parse non-companion mounts
                name,spellid = unpack(id)
                is_usable = IsUsableSpell(spellid)
                local desc = GetSpellDescription(spellid)

                if strfind(desc, 'flying') or strfind(desc, 'flight') then
                    -- flying or hybrid
                    flying = true
                end

                if extraHybrid[spellid] then
                    -- override capabilities detected by description
                    flying = true
                end
            else
                name,spellid,_,_,is_usable,_,_,_,_,_,_ =
                    C_MountJournal.GetMountInfoByID(MOUNT_IDS[id])
                is_usable = is_usable and IsUsableSpell(spellid)

                local mounttype = select(5,C_MountJournal.GetMountInfoExtraByID(MOUNT_IDS[id]))
                if mounttype == 248 or mounttype == 247 then
                    flying = true
                end
            end

            if is_usable then
                if  (useFlying and flying) or
                    (not useFlying and (useHybrid or not flying))
                then
                    tinsert(usable, spellid)
                    --print('['..id..', '..(flying and 'fly' or '')..' '..name)

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
    elseif event == 'PLAYER_LOGIN' then
        MOUNT_IDS = C_MountJournal.GetMountIDs()
        ns.MOUNT_IDS = MOUNT_IDS
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
ns.f:RegisterEvent('PLAYER_LOGIN')
ns.f:RegisterEvent('COMPANION_LEARNED')
ns.f:RegisterEvent('PLAYER_ENTERING_WORLD')

ns.Mount = Mount

-- globals for key binding support
BINDING_HEADER_KUIMOUNT_HEADER = 'Kui Mount'
setglobal("BINDING_NAME_CLICK KuiMountSecureButton:LeftButton", "Mount")
KuiMountMount = Mount
