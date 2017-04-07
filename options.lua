-- Kui Mount
-- By Kesava at curse.com
-- All rights reserved
local addon,ns = ...
local category = 'Kui |cff9966ffMount|r'

do
    local preferedBox, useHybridCheck, supressErrorsCheck

    --------------------------------------- Create interface options category --
    local opt = CreateFrame("Frame", "KuiMountConfig", InterfaceOptionsFramePanelContainer)
    opt:Hide()
    opt.name = category

    -- element helpers #########################################################
    local function CreateEditBox(name, width, height)
        local box = CreateFrame('EditBox', name..'EditBox', opt)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        --box:EnableMouse(false)
        box:SetFontObject(ChatFontNormal)
        box:SetSize(width, height)
        box:Show()

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

    ------------------------------------------------- Create options elements --
    -- ground mounts edit box ##################################################
    local edit_ground = CreateEditBox('KuiMountGround',154,400)
    edit_ground.env_id = 1
    edit_ground.Scroll:SetPoint('TOPLEFT',30,-60)

    local edit_flying = CreateEditBox('KuiMountFlying',154,400)
    edit_flying.env_id = 2
    edit_flying.Scroll:SetPoint('TOPLEFT',edit_ground.Scroll,'TOPRIGHT',40,0)

    local edit_aquatic = CreateEditBox('KuiMountAquatic',154,175)
    edit_aquatic.env_id = 3
    edit_aquatic.Scroll:SetPoint('TOPLEFT',edit_flying.Scroll,'TOPRIGHT',40,0)

    local edit_waterw = CreateEditBox('KuiMountWaterWalking',154,175)
    edit_waterw.env_id = 4
    edit_waterw.Scroll:SetPoint('TOPLEFT',edit_aquatic.Scroll,'BOTTOMLEFT',0,-50)

    -- titles ##################################################################
    local title_ground = opt:CreateFontString(nil,'ARTWORK','GameFontNormalLarge')
    title_ground:SetPoint('BOTTOM',edit_ground.Backdrop,'TOP',0,5)
    title_ground:SetText('Ground')

    local title_flying = opt:CreateFontString(nil,'ARTWORK','GameFontNormalLarge')
    title_flying:SetPoint('BOTTOM',edit_flying.Backdrop,'TOP',0,5)
    title_flying:SetText('Flying')

    local title_aquatic = opt:CreateFontString(nil,'ARTWORK','GameFontNormalLarge')
    title_aquatic:SetPoint('BOTTOM',edit_aquatic.Backdrop,'TOP',0,5)
    title_aquatic:SetText('Aquatic')

    local title_waterw = opt:CreateFontString(nil,'ARTWORK','GameFontNormalLarge')
    title_waterw:SetPoint('BOTTOM',edit_waterw.Backdrop,'TOP',0,5)
    title_waterw:SetText('Water Walking')

    -- help text ###############################################################
    local help_text = opt:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
    help_text:SetText('Type the names of mounts into the set list. Each mount must be on its own line. When you close the window the lists will be verified and entries may move around. Class or faction specific mounts will generate errors unless you are currently playing that class or faction - to supress these errors, check the "Supress spellbook errors" option.')
    help_text:SetPoint('BOTTOM',0,0)
    help_text:SetHeight(80)
    help_text:SetWidth(550)
    help_text:SetWordWrap(true)
    help_text:SetJustifyH('LEFT')
    help_text:SetJustifyV('TOP')

    -- functions ###############################################################
    local function SetEditBoxToList(editbox,list)
        local text
        for t,_ in pairs(list) do
            text = text and text..t..'\n' or t..'\n'
        end
        editbox:SetText(text or '')
    end

    local function ActivateSet(set_id)
        if not set_id or not KuiMountSaved.Sets[set_id] then return end

        KuiMountCharacter.ActiveSet = set_id

        local set = ns:GetActiveSet()
        SetEditBoxToList(edit_ground,set[1])
        SetEditBoxToList(edit_flying,set[2])
        SetEditBoxToList(edit_aquatic,set[3])
        SetEditBoxToList(edit_waterw,set[4])
    end
    local function SetValues()
        -- set interface state
        ActivateSet(KuiMountCharacter.ActiveSet or 1)
    end

    -- scripts #################################################################
    local function OnOptionsShow()
        SetValues()
    end

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
            KuiMountCharacter.ActiveSet = 1
        end
        KuiMountSaved.Sets[KuiMountCharacter.ActiveSet] = set
    end

    local function OnSetButtonClicked(button)
        preferedBox:ClearFocus()
        ActivateSet(button:GetText())
    end

    edit_ground:SetScript('OnEscapePressed',OnEscapePressed)
    edit_ground:SetScript('OnEditFocusLost',OnEditFocusLost)
    edit_flying:SetScript('OnEscapePressed',OnEscapePressed)
    edit_flying:SetScript('OnEditFocusLost',OnEditFocusLost)
    edit_aquatic:SetScript('OnEscapePressed',OnEscapePressed)
    edit_aquatic:SetScript('OnEditFocusLost',OnEditFocusLost)
    edit_waterw:SetScript('OnEscapePressed',OnEscapePressed)
    edit_waterw:SetScript('OnEditFocusLost',OnEditFocusLost)

    opt:SetScript('OnShow', OnOptionsShow)

    InterfaceOptions_AddCategory(opt)
end

--------------------------------------------------------------- Slash command --
SLASH_KUIMOUNT1 = '/kuimount'
SLASH_KUIMOUNT2 = '/mount'

function SlashCmdList.KUIMOUNT(msg)
    if msg == 'debug' then
        ns.debug = not ns.debug
        return
    end

    InterfaceOptionsFrame_OpenToCategory(category)
    InterfaceOptionsFrame_OpenToCategory(category)
end
