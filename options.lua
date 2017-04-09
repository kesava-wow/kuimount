-- Kui Mount
-- By Kesava at curse.com
-- All rights reserved
local addon,ns = ...
local category = 'Kui |cff9966ffMount|r'
local pcdd = LibStub('PhanxConfig-Dropdown')

local opt = CreateFrame("Frame", "KuiMountConfig", InterfaceOptionsFramePanelContainer)
opt:Hide()
opt.name = category
InterfaceOptions_AddCategory(opt)

-- element functions ###########################################################
local function SetEditBoxToList(editbox,list)
    local text
    for t,_ in pairs(list) do
        text = text and text..t..'\n' or t..'\n'
    end
    editbox:SetText(text or '')
end
local function SetValues()
    -- set interface state
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

    for k,name in ipairs(new_list) do
        if name ~= '' then
            list[strlower(name)] = true
            -- TODO verify & correct into name?
        end
    end

    set[self.env_id] = list

    -- push new list to saved variable
    if not KuiMountCharacter.ActiveSet then
        KuiMountCharacter.ActiveSet = 'default'
    end
    KuiMountSaved.Sets[KuiMountCharacter.ActiveSet] = set
end

-- config element helpers ######################################################
local function CreateEditBox(name, width, height)
    local box = CreateFrame('EditBox', name..'EditBox', opt)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal)
    box:SetSize(width, height)
    box:Show()

    box:SetScript('OnEscapePressed',OnEscapePressed)
    box:SetScript('OnEditFocusLost',OnEditFocusLost)

    local scroll = CreateFrame('ScrollFrame', name..'ScrollFrame', opt, 'UIPanelScrollFrameTemplate')
    scroll:SetSize(width, height)
    scroll:SetScrollChild(box)

    scroll:SetScript('OnMouseDown', function(self)
        self:GetScrollChild():SetFocus()
    end)

    local bg = CreateFrame('Frame', nil, opt)
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
local function CreateCheckBox(name, desc, accountWide, callback)
    local check = CreateFrame('CheckButton', 'KuiMount'..name..'Check', opt, 'OptionsBaseCheckButtonTemplate')

    check.env = name

    check:SetScript('OnClick', function(self)
        local env = (accountWide or accountWide == nil) and
                    KuiMountSaved or KuiMountCharacter

        -- prevent losing changes if the checkbox is clicked before focus
        -- is cleared from an editbox
        preferedBox:ClearFocus()

        if self:GetChecked() then
            PlaySound("igMainMenuOptionCheckBoxOn")
            env[self.env] = true
        else
            PlaySound("igMainMenuOptionCheckBoxOff")
            env[self.env] = false
        end

        if callback then
            callback(self)
        end
    end)

    check.desc = opt:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
    check.desc:SetText(desc)
    check.desc:SetPoint('LEFT', check, 'RIGHT')

    return check
end

-- new set popup ##############################################################
-- shares code from Kui_Nameplates_Core_Config/helpers.lua:CreatePopup et al
do
    local function PopupOnShow(self)
        self.editbox:SetText('')
        self.editbox:SetFocus()
        PlaySound("igMainMenuOpen")
    end
    local function PopupOnHide(self)
        PlaySound("igMainMenuClose")
    end
    local function PopupOnKeyUp(self,kc)
        if kc == 'ENTER' then
            self.Okay:Click()
        elseif kc == 'ESCAPE' then
            self.Cancel:Click()
        end
    end
    local function OkayButtonOnClick(self)
        ns:NewSet(opt.Popup.editbox:GetText())
        ActivateSet(opt.Popup.editbox:GetText())

        opt.Popup:Hide()
    end
    local function CancelButtonOnClick(self)
        opt.Popup:Hide()
        SetValues()
    end
    function opt:CreateNewSetPopUp()
        local popup = CreateFrame('Frame',nil,self)
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

        self.Popup = popup

        opt:HookScript('OnHide',function(self)
            self.Popup:Hide()
        end)
    end
end
-- populate config page ########################################################
function opt:Populate()
    -- set dropdown ############################################################
    local dd_set = pcdd:New(opt,'Set')
    dd_set:SetPoint('TOPLEFT',10,-20)
    dd_set:SetFrameStrata('TOOLTIP')
    dd_set:SetHeight(20)
    dd_set.labelText:Hide()

    function dd_set:initialize()
        local list = {}

        -- new set button
        tinsert(list,{
            text = 'New set',
            value = 'new_set'
        })

        -- buttons for each existing set
        for set_name,set in pairs(KuiMountSaved.Sets) do
            tinsert(list,{
                text = set_name,
                selected = KuiMountCharacter.ActiveSet == set_name
            })
        end

        self:SetList(list)
        self:SetValue(KuiMountCharacter.ActiveSet)
    end
    function dd_set:OnValueChanged(value,text)
        if value and value == 'new_set' then
            -- woo make a new set
            opt.Popup:Show()
            return
        else
            ActivateSet(text)
        end
    end

    dd_set:HookScript('OnShow',dd_set.initialize)

    self.dd_set = dd_set

    -- delete set button #######################################################
    local button_delete = CreateFrame('Button',nil,opt,'UIPanelButtonTemplate')
    button_delete:SetText('Delete set')
    button_delete:SetPoint('TOPRIGHT',-10,-10)
    button_delete:SetSize(100,25)

    button_delete:SetScript('OnClick',function(self)
        -- delete the current set & switch to default
        if opt.dd_set.list then
            opt.dd_set.list:Hide()
        end

        KuiMountSaved.Sets[KuiMountCharacter.ActiveSet] = nil
        ActivateSet('default')
    end)

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

    self:CreateNewSetPopUp()

    self.initialised = true
end
function opt:PopulateWrapper()
    if not opt.initialised then
        if InCombatLockdown() then
            print('Not opening uninitialised UI during combat.')
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
SLASH_KUIMOUNT1 = '/kuimount'
SLASH_KUIMOUNT2 = '/mount'

local function DumpOldSet(name,set)
    if not set then return end
    local t
    for k,v in pairs(set) do
        t = t and t..', '..k or '|cffffff88'..name..'|r: '..k
    end
    if t then
        print(t)
    else
        print('|cffffff88'..name..'|r: no data')
    end
end
function SlashCmdList.KUIMOUNT(msg)
    if msg == 'debug' then
        ns.debug = not ns.debug
        return
    elseif msg == 'dump-old' then
        DumpOldSet('One',KuiMountSaved.OLD_SET_ONE)
        DumpOldSet('Two',KuiMountSaved.OLD_SET_TWO)
        DumpOldSet('Three',KuiMountSaved.OLD_SET_THREE)
        DumpOldSet('Char',KuiMountCharacter.OLD_SET_CHAR)
        return
    end

    opt:PopulateWrapper()

    if opt.initialised or not InCombatLockdown() then
        InterfaceOptionsFrame_OpenToCategory(category)
        InterfaceOptionsFrame_OpenToCategory(category)
    end
end
