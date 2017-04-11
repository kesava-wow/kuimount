-- Kui Mount
-- By Kesava at curse.com
-- All rights reserved
local addon, ns = ...
local select, strfind, strlower, tonumber, tinsert
    = select, strfind, strlower, tonumber, tinsert
local _,i,x
local SecureButton

-- TODO use zone IDs or something
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

-- list ID enums
ns.LIST_GROUND = 1
ns.LIST_FLY = 2
ns.LIST_AQUATIC = 3
ns.LIST_WATERWALK = 4

-- mount collection functions ##################################################
local collected_mounts_by_name = {}
local known_spellid_mounts = {}
local num_mounts = 0
function ns:GetMounts()
    -- generate list of mounts by name => id
    wipe(collected_mounts_by_name)
    num_mounts = 0

    for k,i in ipairs(C_MountJournal.GetMountIDs()) do
        local name,_,_,_,_,_,_,_,_,_,isCollected,mountID =
              C_MountJournal.GetMountInfoByID(i)

        if isCollected then
            collected_mounts_by_name[strlower(name)] = mountID
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
function ns:GetMountID(name)
    return collected_mounts_by_name[name] or
           nil
end
function ns:GetNumKnownMounts()
    return num_mounts
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

local function IsInActiveList(list_id,name)
    return ns:GetActiveSet()[list_id][name] and true or nil
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

-- mount journal button functions ##############################################
local function MountJournalItemUpdateButtons(item)
    if not item then return end

    item.KuiMountGround:Hide()
    item.KuiMountFlying:Hide()

    local name = item.name and item.name:GetText()
    if name then
        name = strlower(name)
    else
        return
    end

    local mount_id = collected_mounts_by_name[name]
    if mount_id then
        if IsInActiveList(ns.LIST_GROUND,name) then
            item.KuiMountGround:SetChecked(true)
        else
            item.KuiMountGround:SetChecked(false)
        end
        item.KuiMountGround:Show()

        local mountType = select(5,C_MountJournal.GetMountInfoExtraByID(mount_id))
        if mountType == 248 or mountType == 247 then
            -- flying mount; show flying check box
            if IsInActiveList(ns.LIST_FLY,name) then
                item.KuiMountFlying:SetChecked(true)
            else
                item.KuiMountFlying:SetChecked(false)
            end
            item.KuiMountFlying:Show()
        end
    end
end

local function MountJournalUpdateButtons()
    for i=1,12 do
        MountJournalItemUpdateButtons(_G['MountJournalListScrollFrameButton'..i])
    end
end

local function MountJournalButtonOnClick(self,button)
    -- highlight parent
    self:GetParent():Click()

    local name = self:GetParent().name:GetText()
    if not name then return end

    name = strlower(name)
    if collected_mounts_by_name[name] then
        local set = ns:GetActiveSet()

        if (self.env == ns.LIST_GROUND and IsInActiveList(ns.LIST_GROUND,name)) or
           (self.env == ns.LIST_FLY and IsInActiveList(ns.LIST_FLY,name))
        then
            set[self.env][name] = nil
        else
            set[self.env][name] = true
        end

        -- push to saved var
        KuiMountSaved.Sets[KuiMountCharacter.ActiveSet] = set
    end

    MountJournalItemUpdateButtons(self:GetParent())
end


local mount_journal_hooked
local function HookMountJournal()
    if mount_journal_hooked then return end
    mount_journal_hooked = true

    if not MountJournal or not MountJournalListScrollFrameButton1 then
        error('MountJournal was expected, is nil')
        return
    end

    for i=1,12 do
        local item = _G['MountJournalListScrollFrameButton'..i]

        local btn_gnd = CreateFrame('CheckButton',nil,item,'OptionsBaseCheckButtonTemplate')
        btn_gnd.env = ns.LIST_GROUND
        btn_gnd:SetPoint('TOPRIGHT',-1,-1)
        btn_gnd:SetScript('OnClick',MountJournalButtonOnClick)

        btn_gnd.label = btn_gnd:CreateFontString(nil,'ARTWORK','GameFontHighlightSmall')
        btn_gnd.label:SetAlpha(.7)
        btn_gnd.label:SetText('Gnd')
        btn_gnd.label:SetPoint('RIGHT',btn_gnd,'LEFT')

        local btn_fly = CreateFrame('CheckButton',nil,item,'OptionsBaseCheckButtonTemplate')
        btn_fly.env = ns.LIST_FLY
        btn_fly:SetPoint('BOTTOMRIGHT',-1,1)
        btn_fly:SetScript('OnClick',MountJournalButtonOnClick)

        btn_fly.label = btn_fly:CreateFontString(nil,'ARTWORK','GameFontHighlightSmall')
        btn_fly.label:SetAlpha(.7)
        btn_fly.label:SetText('Fly')
        btn_fly.label:SetPoint('RIGHT',btn_fly,'LEFT')

        item.KuiMountGround = btn_gnd
        item.KuiMountFlying = btn_fly
    end

    MountJournal:HookScript('OnShow',MountJournalUpdateButtons)
    MountJournalListScrollFrame:HookScript('OnVerticalScroll',MountJournalUpdateButtons)
    MountJournalListScrollFrame:HookScript('OnMouseWheel',MountJournalUpdateButtons)
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
            HookMountJournal()
            return
        elseif ... ~= addon then return end

        if MountJournal then
            -- Blizzard_Collections is already loaded
            HookMountJournal()
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
KuiMountMount = Mount
