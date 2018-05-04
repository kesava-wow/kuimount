-- Kui Mount
-- By Kesava at curse.com
-- All rights reserved
local addon, ns = ...
local select, strfind, strlower, tonumber, tinsert
    = select, strfind, strlower, tonumber, tinsert
local _,i,x
local SecureButton
local previousMountUsed

-- XXX add bindings for:
--   - use aquatic
--   - use water walking

-- zones that aren't flyable despite being flagged as such
-- (converted to name in ADDON_LOADED)
-- XXX GetCurrentMapAreaID(), GetMapNameByID()
-- TODO 80 zone ID's changed
local nonFlyZones = {}
local nonFlyZones_by_id = {
    737, -- the maelstrom
    1022, -- helheim
    1035, -- skyhold
    1044, -- the wandering isle
    1050, -- dreadscar rift
    1052, -- mardum, the shattered abyss
    1078, -- niskara
}

-- mounts which aren't companions (i.e. aren't in the pet journal interface)
local spellIdMounts = {
    783,   -- travel form
    2645,  -- ghost wolf
    87840, -- running wild
}

ns.f = CreateFrame('Frame', KuiMountFrame)

-- flying skill spell IDs
local FLYING_EXPERT = 34090
local FLYING_ARTISAN = 34091
local FLYING_MASTER = 90265

-- list ID enums
ns.LIST_GROUND = 1
ns.LIST_FLY = 2
ns.LIST_AQUATIC = 3
ns.LIST_WATERWALK = 4

-- mount collection functions ##################################################
local collected_mounts_by_name = {}
local known_spellid_mounts = {}
function ns:GetMounts()
    -- generate list of mounts by name => id
    -- used to convert names to IDs as there is no API for this
    wipe(collected_mounts_by_name)

    for k,i in ipairs(C_MountJournal.GetMountIDs()) do
        local name,_,_,_,_,_,_,_,_,_,isCollected,mountID =
              C_MountJournal.GetMountInfoByID(i)

        if isCollected then
            collected_mounts_by_name[strlower(name)] = mountID
        end
    end

    -- add known non-companion mounts
    wipe(known_spellid_mounts)
    for _,id in pairs(spellIdMounts) do
        if IsSpellKnown(id) then
            local name = GetSpellInfo(id)
            known_spellid_mounts[strlower(name)] = id
        end
    end
end
function ns:GetMountID(name)
    return collected_mounts_by_name[strlower(name)] or
           nil
end

-- saved variable functions ####################################################
function ns:GetActiveSet()
    return KuiMountCharacter.ActiveSet and
           KuiMountSaved.Sets[KuiMountCharacter.ActiveSet] or
           KuiMountSaved.Sets['default']
end
local function DefaultSet()
    return {
        {}, -- ground
        {}, -- flying
        {   -- aquatic
            [783] = true, -- travel form
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
function ns:NewSet(id)
    -- create or reset given set id
    if not id then return end
    KuiMountSaved.Sets[id] = DefaultSet()
end
function ns:IsInActiveList(list_id,key)
    if type(key) == 'string' then key = strlower(key) end
    return self:GetActiveSet()[list_id][key] and true or nil
end

-- mounting functions ##########################################################
local function CanFly()
    return IsFlyableArea() and not nonFlyZones[GetZoneText()] and (
               IsSpellKnown(FLYING_MASTER) or
               IsSpellKnown(FLYING_ARTISAN) or
               IsSpellKnown(FLYING_EXPERT))
end
local function Mount()
    local active_set = ns:GetActiveSet()

    local list
    local useAquatic = IsSwimming() and IsAltKeyDown()
    local useFlying = not useAquatic and not IsControlKeyDown() and CanFly()
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
        local spellid,_,_,usable =
            select(2,C_MountJournal.GetMountInfoByID(mount_id))
        local mountType =
            select(5,C_MountJournal.GetMountInfoExtraByID(mount_id))

        if  usable and IsUsableSpell(spellid) and (
            (useFlying and (mountType == 248 or mountType == 247)) or
            not useFlying)
        then
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

    if ns.debug then
        print('compacted '..#usable_mounts..' to '..#usable_mounts_wl)
    end

    -- select random usable mount
    if #usable_mounts > 0 then
        local spell_name = GetSpellInfo(
            usable_mounts[math.random(1,#usable_mounts)]
        )

        if ns.debug then
            print('selected: '..spell_name)
            print(IsUsableSpell(spell_name))
        end

        SecureButton:SetAttribute('macrotext','/cast '..spell_name)
        previousMountUsed = spell_name
    else
        UIErrorsFrame:AddMessage('Couldn\'t find a usable mount', 1,0,0)
    end
end

-- secure button handlers ------------------------------------------------------
local function ButtonPreClick(self,button)
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

    if button == 'UsePrevious' and previousMountUsed then
        -- use previously selected mount (make no changes)
        return
    else
        -- blank the macro so that we don't get 2 uierrors if no mount is usable
        SecureButton:SetAttribute('macrotext', '')
        Mount()
    end
end

-- events ----------------------------------------------------------------------
local RESET_WARN
ns.f:SetScript('OnEvent', function(self, event, ...)
    if event == 'PLAYER_ENTERING_WORLD' or event == 'COMPANION_LEARNED' then
        -- update mount list upon learning new mounts or zoning
        ns:GetMounts()
    elseif event == 'PLAYER_LOGIN' then
        if RESET_WARN then
            print('|cff9966ffKui Mount|r has been updated and reset. Your previous sets have been backed up and can be viewed by running:|n/mount dump-old')
        end
    elseif event == 'ADDON_LOADED' then
        if ... == 'Blizzard_Collections' then
            ns:HookMountJournal()
            return
        elseif ... ~= addon then return end

        if MountJournal then
            -- Blizzard_Collections is already loaded
            ns:HookMountJournal()
        end

        -- convert map IDs to names
        for _,id in ipairs(nonFlyZones_by_id) do
            if tonumber(id) and C_Map.GetMapInfo(id) then
                nonFlyZones[C_Map.GetMapInfo(id).name] = true
            end
        end

        SecureButton = CreateFrame("Button", 'KuiMountSecureButton', UIParent, "SecureActionButtonTemplate, ActionButtonTemplate")
        SecureButton:SetAttribute('type','macro')
        SecureButton:SetScript('PreClick', ButtonPreClick)

        -- initialise saved variables
        -- acount wide
        if not KuiMountSaved then
            KuiMountSaved = {}
        end

        -- backup legacy variables and reset
        if  KuiMountSaved.Sets and KuiMountSaved.Sets.One and
            type(KuiMountSaved.Sets.One[4]) ~= 'table'
        then
            KuiMountSaved.OLD_SET_ONE = KuiMountSaved.Sets.One
            KuiMountSaved.OLD_SET_TWO = KuiMountSaved.Sets.Two
            KuiMountSaved.OLD_SET_THREE = KuiMountSaved.Sets.Three
            KuiMountSaved.Sets = nil

            RESET_WARN = true
        end
        if KuiMountCharacter and KuiMountCharacter.list then
            KuiMountCharacter.OLD_SET_CHAR = KuiMountCharacter.list
            KuiMountCharacter.list = nil

            RESET_WARN = true
        end

        -- create default set list
        if not KuiMountSaved.Sets then
            KuiMountSaved.Sets = {
                ['default'] = DefaultSet()
            }
        end

        -- character specific
        if not KuiMountCharacter then
            KuiMountCharacter = {}
        end

        -- verify ActiveSet
        if not KuiMountCharacter.ActiveSet or
           not KuiMountSaved.Sets[KuiMountCharacter.ActiveSet]
        then
            KuiMountCharacter.ActiveSet = 'default'
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
setglobal("BINDING_NAME_CLICK KuiMountSecureButton:UsePrevious", "Mount previous")
KuiMountMount = Mount
