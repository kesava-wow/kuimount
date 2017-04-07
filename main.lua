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

-- mount collection functions ##################################################
local collected_mounts_by_name = {}
local collected_mounts_by_spellid = {}
local known_spellid_mounts = {}
local num_mounts = 0
function ns:GetMounts()
    -- generate list of mounts by spell id => id, name => id
    wipe(collected_mounts_by_name)
    wipe(collected_mounts_by_spellid)
    num_mounts = 0

    for k,i in ipairs(C_MountJournal.GetMountIDs()) do
        local name,spellid,icon,active,usable,sourceType,isFavorite,
              isFactionSpecific,faction,isFiltered,isCollected,mountID =
              C_MountJournal.GetMountInfoByID(i)

        if isCollected then
            collected_mounts_by_name[strlower(name)] = mountID
            collected_mounts_by_spellid[spellid] = mountID
            num_mounts = num_mounts + 1
        end
    end

    -- add known non-companion mounts
    wipe(known_spellid_mounts)
    for _,id in pairs(spellIdMounts) do
        if IsSpellKnown(id) then
            local name = GetSpellInfo(id)
            known_spellid_mounts[strlower(name)] = id
            num_mounts = num_mounts + 1
        end
    end
end
function ns:GetMountID(name_or_spellid)
    return collected_mounts_by_spellid[name_or_spellid] or
           collected_mounts_by_name[name_or_spellid] or
           nil
end
function ns:GetNumKnownMounts()
    return num_mounts
end

-- saved variable functions ####################################################
function ns:GetActiveSet()
    return KuiMountCharacter.ActiveSet and
           KuiMountSaved.Sets[KuiMountCharacter.ActiveSet] or
           KuiMountSaved.Sets[1]
end
local function DefaultSet()
    return {
        {}, -- ground
        {}, -- flying
        {   -- aquatic
            [75207] = true,  -- sea pony
            [98718] = true,  -- sea pony 2.0
            [64731] = true,  -- sea turtle
            [223018] = true, -- fathom dweller
            [228919] = true, -- darkwater skate
            [214791] = true, -- brinedeep bottom-feeder
        },
        {   -- water walking
            [118089] = true, -- azure water strider
            [127271] = true, -- crimson water strider
        },
    }
end

-- mounting functions ##########################################################
local function Mount()
    if ns:GetNumKnownMounts() <= 0 then
        UIErrorsFrame:AddMessage('You don\'t have any mounts', 1,0,0)
        return
    end

    local active_set = ns:GetActiveSet()

    local list
    local isSwimZone = IsSwimming() and swimZones[GetZoneText()]
    local useAquatic = isSwimZone and IsShiftKeyDown()
    local useFlying = not useAquatic and
                      (not IsControlKeyDown() and IsFlyableArea()) and
                      (not nonFlyZones[GetZoneText()])
    local useWaterWalking = not useFlying and not useAquatic and
                            IsShiftKeyDown()

    -- now we know which list to use...
    local list = (useAquatic and active_set[3]) or
                 (useFlying and active_set[2]) or
                 (useWaterWalking and active_set[4]) or
                 active_set[1]

    -- make a list of all currently usable mounts
    -- (both in and out of the whitelist, so that we can fallback and ignore
    -- the whitelist if none were found)
    local usable_mounts, usable_mounts_wl = {},{}
    for name,mount_id in pairs(collected_mounts_by_name) do
        local _,spellid,_,_,usable = C_MountJournal.GetMountInfoByID(mount_id)
        if usable then
            tinsert(usable_mounts,spellid)

            if list[name] or list[spellid] then
                tinsert(usable_mounts_wl,spellid)
            end
        end
    end

    -- add spell id mounts
    for name,spellid in pairs(known_spellid_mounts) do
        if IsSpellKnown(spellid) and IsUsableSpell(spellid) then
            tinsert(usable_mounts,spellid)

            if list[name] or list[spellid] then
                tinsert(usable_mounts_wl,spellid)
            end
        end
    end

    if #usable_mounts_wl > 0 then
        -- use mount from whitelist
        usable_mounts = usable_mounts_wl
    end

    -- select random usable mount
    if #usable_mounts > 0 then
        local spell_name = GetSpellInfo(
            usable_mounts[math.random(1,#usable_mounts)]
        )

        SecureButton:SetAttribute('macrotext','/cast '..spell_name)
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
        ns:GetMounts()
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

        if KuiMountSaved.Sets and KuiMountSaved.Sets.One then
            -- backup old saved variables and reset
            KuiMountSaved.OLD_SET_ONE = KuiMountSaved.Sets.One
            KuiMountSaved.OLD_SET_TWO = KuiMountSaved.Sets.Two
            KuiMountSaved.OLD_SET_THREE = KuiMountSaved.Sets.Three

            if KuiMountCharacter and KuiMountCharacter.list then
                KuiMountCharacter.OLD_SET_CHAR = KuiMountCharacter.list
            end

            KuiMountSaved = {}
            KuiMountCharacter = {}
        end

        if not KuiMountSaved.Sets then
            KuiMountSaved.Sets = {
                DefaultSet()
            }
        end

        -- character specific (active set)
        if not KuiMountCharacter then
            KuiMountCharacter = {}
            KuiMountCharacter.ActiveSet = 1
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
