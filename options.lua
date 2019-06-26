-- luacheck:globals MountJournal
-- Kui Mount
-- By Kesava at curse.com
-- All rights reserved
local _,ns = ...
local category = 'Kui |cff9966ffMount|r'
local pcdd = LibStub('SomeoneElsesConfig-Dropdown')
local kui = LibStub('Kui-1.0')

local opt = CreateFrame("Frame", "KuiMountConfig", InterfaceOptionsFramePanelContainer)
opt:Hide()
opt.name = category
InterfaceOptions_AddCategory(opt)

local pairs,tsort,tinsert = pairs,table.sort,tinsert

local S_CHECKBOX_ON = 856
local S_CHECKBOX_OFF = 857
local S_MENU_OPEN = 850
local S_MENU_CLOSE = 851

-- element functions ###########################################################
local function SetEditBoxToList(editbox,list)
    local text
    for t in pairs(list) do
        t = GetSpellInfo(t) or t
        text = text and text..t..'\n' or t..'\n'
    end
    editbox:SetText(text or '')
end
local function SetValues()
    -- update mount journal interface elements
    if ns.MountJournalHooked then
        MountJournal:KuiMountUpdateDisplay()
    end

    -- update options interface elements
    if not opt.initialised then return end

    opt.dd_set:initialize()

    local set = ns:GetActiveSet()
    SetEditBoxToList(opt.edit_ground,set[1])
    SetEditBoxToList(opt.edit_flying,set[2])
    SetEditBoxToList(opt.edit_aquatic,set[3])
    SetEditBoxToList(opt.edit_waterw,set[4])
end
local function ActivateSet(set_id)
    if not set_id or not KuiMountSaved.Sets[set_id] then return end
    KuiMountCharacter.ActiveSet = set_id
    SetValues()
end

-- element scripts #############################################################
local function OnEscapePressed(self)
    self:ClearFocus()
end
local function OnEditFocusLost(self)
    if not self.env_id then return end

    local new_list = { strsplit('\n', self:GetText()) }
    local set = ns:GetActiveSet()
    local list = {}

    for _,name in ipairs(new_list) do
        if name and name ~= '' then
            if tonumber(name) then
                -- add to list as given spell id
                list[tonumber(name)] = true
            else
                -- convert name to spell id
                local id,spellid = ns:GetMountID(name)
                if id then
                    spellid = select(2,C_MountJournal.GetMountInfoByID(id))
                end

                list[spellid or strlower(name)] = true
            end
        end
    end

    set[self.env_id] = list

    -- push new list to saved variable
    if not KuiMountCharacter.ActiveSet then
        KuiMountCharacter.ActiveSet = 'default'
    end
    KuiMountSaved.Sets[KuiMountCharacter.ActiveSet] = set

    SetValues()

    -- update mount journal checkboxes
    if ns.MountJournalHooked then
        MountJournal:KuiMountUpdateDisplay()
    end
end

-- config element helpers ######################################################
local function CreateEditBox(name, width, height, parent)
    local box = CreateFrame('EditBox', name..'EditBox', parent or opt)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal)
    box:SetSize(width, height)
    box:Show()

    box:SetScript('OnEscapePressed',OnEscapePressed)
    box:SetScript('OnEditFocusLost',OnEditFocusLost)

    local scroll = CreateFrame('ScrollFrame', name..'ScrollFrame', parent or opt, 'UIPanelScrollFrameTemplate')
    scroll:SetSize(width, height)
    scroll:SetScrollChild(box)

    scroll:SetScript('OnMouseDown', function(self)
        self:GetScrollChild():SetFocus()
    end)

    local bg = CreateFrame('Frame', nil, parent or opt)
    bg:SetBackdrop({
        bgFile = 'Interface\\ChatFrame\\ChatFrameBackground',
        edgeFile = 'Interface\\Tooltips\\UI-Tooltip-border',
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    bg:SetBackdropColor(.1, .1 , .1, .3)
    bg:SetBackdropBorderColor(.5, .5, .5)
    bg:SetPoint('TOPLEFT', scroll, -10, 10)
    bg:SetPoint('BOTTOMRIGHT', scroll, 30, -10)

    box.Scroll = scroll
    box.Backdrop = bg

    return box
end

-- new set popup ##############################################################
-- shares code from Kui_Nameplates_Core_Config/helpers.lua:CreatePopup et al
local CreateNewSetPopUp
do
    local function PopupOnShow(self)
        self.editbox:SetText('')
        self.editbox:SetFocus()
        PlaySound(S_MENU_OPEN)
    end
    local function PopupOnHide(self)
        PlaySound(S_MENU_CLOSE)
    end
    local function PopupOnKeyUp(self,kc)
        if kc == 'ENTER' then
            self.Okay:Click()
        elseif kc == 'ESCAPE' then
            self.Cancel:Click()
        end
    end
    local function OkayButtonOnClick(self)
        ns:NewSet(self:GetParent().editbox:GetText())
        ActivateSet(self:GetParent().editbox:GetText())

        self:GetParent():Hide()
    end
    local function CancelButtonOnClick(self)
        self:GetParent():Hide()
        SetValues()
    end
    function CreateNewSetPopUp(parent)
        local popup = CreateFrame('Frame',nil,parent)
        popup:SetBackdrop({
            bgFile='interface/dialogframe/ui-dialogbox-background',
            edgeFile='interface/dialogframe/ui-dialogbox-border',
            edgeSize=32,
            tile=true,
            tileSize=32,
            insets = {
                top=12,right=12,bottom=11,left=11
            }
        })
        popup:SetPoint('CENTER')
        popup:SetFrameStrata('DIALOG')
        popup:EnableMouse(true)
        popup:SetSize(400,150)
        popup:Hide()

        popup:SetScript('OnKeyUp',PopupOnKeyUp)
        popup:SetScript('OnShow',PopupOnShow)
        popup:SetScript('OnHide',PopupOnHide)

        local label = popup:CreateFontString(nil,'ARTWORK','GameFontNormal')
        label:SetText('Enter set name')
        label:SetPoint('CENTER',0,20)

        local text = CreateFrame('EditBox',nil,popup,'InputBoxTemplate')
        text:SetAutoFocus(false)
        text:EnableMouse(true)
        text:SetMaxLetters(50)
        text:SetPoint('CENTER')
        text:SetSize(150,30)

        local okay = CreateFrame('Button',nil,popup,'UIPanelButtonTemplate')
        okay:SetText('OK')
        okay:SetSize(90,22)
        okay:SetPoint('BOTTOM',-45,20)

        local cancel = CreateFrame('Button',nil,popup,'UIPanelButtonTemplate')
        cancel:SetText('Cancel')
        cancel:SetSize(90,22)
        cancel:SetPoint('BOTTOM',45,20)

        popup.label = label
        popup.editbox = text
        popup.Okay = okay
        popup.Cancel = cancel

        text:SetScript('OnEnterPressed',OkayButtonOnClick)
        text:SetScript('OnEscapePressed',CancelButtonOnClick)
        okay:SetScript('OnClick',OkayButtonOnClick)
        cancel:SetScript('OnClick',CancelButtonOnClick)

        parent.KuiMountPopup = popup

        parent:HookScript('OnHide',function(self)
            self.KuiMountPopup:Hide()
        end)
    end
end
-- profile dropdown ############################################################
local CreateProfileDropDown
do
    local function ProfileDropDownInitialize(dd)
        local list = {}

        -- new set button
        tinsert(list,{
            text = 'New set...',
            value = 'new_set'
        })

        -- buttons for each existing set in alphabetical order
        local set_indexed = {}
        for k in pairs(KuiMountSaved.Sets) do
            tinsert(set_indexed,k)
        end
        tsort(set_indexed,function(a,b)
            return strlower(a) < strlower(b)
        end)

        for _,set_name in ipairs(set_indexed) do
            tinsert(list,{
                text = set_name,
                selected = KuiMountCharacter.ActiveSet == set_name
            })
        end

        dd:SetList(list)
        dd:SetValue(KuiMountCharacter.ActiveSet)
    end
    local function ProfileDropDownOnChanged(dd,value,text)
        if value and value == 'new_set' then
            -- woo make a new set
            dd:GetParent().KuiMountPopup:Show()
            return
        else
            ActivateSet(text)
        end
    end

    function CreateProfileDropDown(parent)
        local dd = pcdd:New(parent,'Set')
        dd.labelText:Hide()
        dd:SetFrameStrata('TOOLTIP')
        dd:SetHeight(20)

        dd.initialize = ProfileDropDownInitialize
        dd.OnValueChanged = ProfileDropDownOnChanged

        dd:HookScript('OnShow',dd.initialize)

        return dd
    end
end
-- delete set button ###########################################################
local CreateSetDeleteButton
do
    local function SetDeleteButtonOnClick(self)
        -- collapse dropdowns when deleting
        if opt.initialised and opt.dd_set.list then
            opt.dd_set.list:Hide()
        end

        if ns.MountJournalHooked and
           MountJournal.KuiMountSetDropDown.list
        then
            MountJournal.KuiMountSetDropDown.list:Hide()
        end

        -- delete the current set & switch to default
        KuiMountSaved.Sets[KuiMountCharacter.ActiveSet] = nil
        ActivateSet('default')
    end

    function CreateSetDeleteButton(parent)
        local b = CreateFrame('Button',nil,parent,'UIPanelButtonTemplate')
        b:HookScript('OnClick',SetDeleteButtonOnClick)
        return b
    end
end
-- mount journal hooking #######################################################
do
    local function MountJournalItemUpdateButtons(item)
        if not item then return end

        item.KuiMountGround:Hide()
        item.KuiMountFlying:Hide()

        local spellid = item.spellID
        if not spellid then return end

        local name = item.name:GetText()
        if not name then return end

        -- because for some reason the button doesn't just have the id in it.
        local mount_id = ns:GetMountID(name)
        if mount_id then
            if ns:IsInActiveList(ns.LIST_GROUND,spellid) or
               ns:IsInActiveList(ns.LIST_GROUND,name)
            then
                item.KuiMountGround:SetChecked(true)
            else
                item.KuiMountGround:SetChecked(false)
            end
            item.KuiMountGround:Show()

            local mountType = select(5,C_MountJournal.GetMountInfoExtraByID(mount_id))
            if mountType == 248 or mountType == 247 then
                -- flying mount; show flying check box
                if ns:IsInActiveList(ns.LIST_FLY,spellid) or
                   ns:IsInActiveList(ns.LIST_FLY,name)
                then
                    item.KuiMountFlying:SetChecked(true)
                else
                    item.KuiMountFlying:SetChecked(false)
                end
                item.KuiMountFlying:Show()
            end
        end
    end
    local function MountJournalUpdateDisplay()
        if not MountJournal:IsShown() then return end

        MountJournal.KuiMountSetDropDown:initialize()

        for i=1,12 do
            MountJournalItemUpdateButtons(_G['MountJournalListScrollFrameButton'..i])
        end
    end
    local function MountJournalButtonOnClick(self)
        if self:GetChecked() then
            PlaySound(S_CHECKBOX_ON)
        else
            PlaySound(S_CHECKBOX_OFF)
        end

        local spellid = self:GetParent().spellID
        if not spellid then return end

        local name = self:GetParent().name:GetText()
        if not name then return end

        -- highlight parent
        self:GetParent():Click()

        if ns:GetMountID(name) then
            local set = ns:GetActiveSet()

            if (self.env == ns.LIST_GROUND and ns:IsInActiveList(ns.LIST_GROUND,spellid)) or
               (self.env == ns.LIST_FLY and ns:IsInActiveList(ns.LIST_FLY,spellid))
            then
                set[self.env][spellid] = nil
            else
                set[self.env][spellid] = true
            end

            if opt.initialised and opt:IsShown() then
                -- also update visible lists in opt
                if self.env == ns.LIST_GROUND then
                    SetEditBoxToList(opt.edit_ground,set[self.env])
                else
                    SetEditBoxToList(opt.edit_flying,set[self.env])
                end
            end

            -- push to saved var
            KuiMountSaved.Sets[KuiMountCharacter.ActiveSet] = set
        end

        MountJournalItemUpdateButtons(self:GetParent())
    end
    local function MountJournalCreateListItemCheckboxes(item)
        if not item then return end

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

    function ns:HookMountJournal()
        --luacheck:globals MountJournalListScrollFrame MountJournalListScrollFrameButton1
        assert(MountJournal)
        assert(MountJournalListScrollFrameButton1)

        if self.MountJournalHooked then return end
        self.MountJournalHooked = true

        -- create checkboxes on list items
        for i=1,12 do
            MountJournalCreateListItemCheckboxes(
                _G['MountJournalListScrollFrameButton'..i]
            )
        end

        -- set dropdown
        MountJournal.KuiMountSetDropDown = CreateProfileDropDown(MountJournal)
        MountJournal.KuiMountSetDropDown:SetPoint('TOP',0,-37)

        -- new set popup
        CreateNewSetPopUp(MountJournal)

        -- set delete button
        local button_delete = CreateSetDeleteButton(MountJournal)
        button_delete:SetPoint('BOTTOMRIGHT',-3,2)
        button_delete:SetSize(80,25)
        button_delete:SetText('Delete set')

        -- open legacy interface button
        local button_legacy = CreateFrame('Button',nil,MountJournal,'UIPanelButtonTemplate')
        button_legacy:SetPoint('RIGHT',button_delete,'LEFT')
        button_legacy:SetSize(90,25)
        button_legacy:SetText('Kui Mount')
        button_legacy:HookScript('OnClick',function(self)
            SlashCmdList.KUIMOUNT()
        end)

        MountJournal:HookScript('OnShow',MountJournalUpdateDisplay)
        MountJournalListScrollFrame:HookScript('OnVerticalScroll',MountJournalUpdateDisplay)
        MountJournalListScrollFrame:HookScript('OnMouseWheel',MountJournalUpdateDisplay)

        MountJournal.KuiMountUpdateDisplay = MountJournalUpdateDisplay

        -- update upon searching/filtering
        hooksecurefunc("MountJournal_UpdateMountDisplay",MountJournalUpdateDisplay)
    end
end
-- populate config page ########################################################
function opt:Populate()
    -- ground mounts edit box ##################################################
    local edit_ground = CreateEditBox('KuiMountGround',154,400)
    edit_ground.env_id = 1
    edit_ground.Scroll:SetPoint('TOPLEFT',30,-85)

    local edit_flying = CreateEditBox('KuiMountFlying',154,400)
    edit_flying.env_id = 2
    edit_flying.Scroll:SetPoint('TOPLEFT',edit_ground.Scroll,'TOPRIGHT',40,0)

    local edit_aquatic = CreateEditBox('KuiMountAquatic',154,175)
    edit_aquatic.env_id = 3
    edit_aquatic.Scroll:SetPoint('TOPLEFT',edit_flying.Scroll,'TOPRIGHT',40,0)

    local edit_waterw = CreateEditBox('KuiMountWaterWalking',154,175)
    edit_waterw.env_id = 4
    edit_waterw.Scroll:SetPoint('TOPLEFT',edit_aquatic.Scroll,'BOTTOMLEFT',0,-50)

    self.edit_ground = edit_ground
    self.edit_flying = edit_flying
    self.edit_aquatic = edit_aquatic
    self.edit_waterw = edit_waterw

    -- titles ##################################################################
    local title_ground = self:CreateFontString(nil,'ARTWORK','GameFontNormalLarge')
    title_ground:SetPoint('BOTTOM',edit_ground.Backdrop,'TOP',0,5)
    title_ground:SetText('Ground')

    local title_flying = self:CreateFontString(nil,'ARTWORK','GameFontNormalLarge')
    title_flying:SetPoint('BOTTOM',edit_flying.Backdrop,'TOP',0,5)
    title_flying:SetText('Flying')

    local title_aquatic = self:CreateFontString(nil,'ARTWORK','GameFontNormalLarge')
    title_aquatic:SetPoint('BOTTOM',edit_aquatic.Backdrop,'TOP',0,5)
    title_aquatic:SetText('Aquatic')

    local title_waterw = self:CreateFontString(nil,'ARTWORK','GameFontNormalLarge')
    title_waterw:SetPoint('BOTTOM',edit_waterw.Backdrop,'TOP',0,5)
    title_waterw:SetText('Water Walking')

    -- help text ###############################################################
    local help_text = self:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
    help_text:SetText('Type the |cffffff88names|r or |cffffff88spell IDs|r of mounts into the relevant list and press |cffffff88Escape|r. Each mount must be on its own line. The name of the list doesn\'t matter; if you want to use a flying mount as a ground mount, put it in the |cffffff88Ground|r list.')
    help_text:SetPoint('BOTTOM',0,0)
    help_text:SetHeight(60)
    help_text:SetWidth(550)
    help_text:SetWordWrap(true)
    help_text:SetJustifyH('LEFT')
    help_text:SetJustifyV('TOP')

    -- delete set button #######################################################
    local button_delete = CreateSetDeleteButton(opt)
    button_delete:SetPoint('TOPRIGHT',-10,-10)
    button_delete:SetSize(80,25)
    button_delete:SetText('Delete set')

    -- set dropdown ############################################################
    self.dd_set = CreateProfileDropDown(opt)
    self.dd_set:SetPoint('TOPLEFT',10,-20)

    -- new set popup ###########################################################
    CreateNewSetPopUp(self)

    self.initialised = true
end
function opt:PopulateWrapper()
    if not opt.initialised then
        if InCombatLockdown() then
            print('Kui Mount: Not opening uninitialised UI during combat.')
            return
        end
        if not KuiMountSaved then
            print('Kui Mount: Didn\'t load correctly.')
            return
        end

        opt:Populate()
    end
end
opt:SetScript('OnShow',function(self)
    self:PopulateWrapper()

    if opt.initialised then
        SetValues()
    end
end)

--------------------------------------------------------------- Slash command --
_G['SLASH_KUIMOUNT1'] = '/kuimount'
_G['SLASH_KUIMOUNT2'] = '/mount'

local function DumpOldSet(name,set)
    if not set then return end
    local m = '|cffffff88'..name..'|r|n'

    local i = 0
    for k in pairs(set) do
        i = i + 1
        m = m..k..'|n'
    end

    if i == 0 then
        m=  m..'No data|n'
    end

    return m
end
function SlashCmdList.KUIMOUNT(msg)
    if msg == 'debug' then
        ns.debug = not ns.debug
        return
    elseif msg == 'dump-old' then
        local d = kui:DebugPopup()
        d:AddText(DumpOldSet('One',KuiMountSaved.OLD_SET_ONE))
        d:AddText(DumpOldSet('Two',KuiMountSaved.OLD_SET_TWO))
        d:AddText(DumpOldSet('Three',KuiMountSaved.OLD_SET_THREE))
        d:AddText(DumpOldSet('Char',KuiMountCharacter.OLD_SET_CHAR))
        d:Show()
        return
    end

    opt:PopulateWrapper()

    if opt.initialised or not InCombatLockdown() then
        InterfaceOptionsFrame_OpenToCategory(category)
        InterfaceOptionsFrame_OpenToCategory(category)
    end
end
