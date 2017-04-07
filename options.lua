-- Kui Mount
-- By Kesava at curse.com
-- All rights reserved
local addon,ns = ...
local category = 'Kui |cff9966ffMount|r'

local function GetActiveList()
    return KuiMountCharacter.ActiveSet == 'Char' and
           KuiMountCharacter.list or
           KuiMountSaved.Sets[KuiMountCharacter.ActiveSet]
end
ns.GetActiveList = GetActiveList

do
    local preferedBox, useHybridCheck, supressErrorsCheck

    --------------------------------------- Create interface options category --
    local opt = CreateFrame("Frame", "KuiMountConfig", InterfaceOptionsFramePanelContainer)
    opt:Hide()
    opt.name = category

    --------------------------------------------------------------- Functions --

    -- helper for creating scrollable edit boxes
    local function CreateEditBox(name, width, height)
        local box = CreateFrame('EditBox', name, opt)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        --box:EnableMouse(false)
        box:SetFontObject(ChatFontNormal)
        box:SetSize(width, height)
        box:Show()

        local scroll = CreateFrame('ScrollFrame', name..'Scroll', opt, 'UIPanelScrollFrameTemplate')
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

    local function ActivateSet(name)
        if not _G['KuiMountSet'..name..'Button'] then return end
        if name ~= 'Char' and not KuiMountSaved.Sets[name] then return end
        if name == 'Char' and not KuiMountCharacter.list then return end

        local buttons,_
        for _,button in pairs({
            'KuiMountSetCharButton',
            'KuiMountSetThreeButton',
            'KuiMountSetTwoButton',
            'KuiMountSetOneButton',
        }) do
            _G[button]:Enable()
        end

        _G['KuiMountSet'..name..'Button']:Disable()
        KuiMountCharacter.ActiveSet = name

        -- load the active set list into the text area
        local list = GetActiveList()
        local text,name,_
        for name,_ in pairs(list) do
            text = (text and text..'\n'..name or name)
        end

        preferedBox:SetText(text or '')
    end

    local function SetValues()
        ActivateSet(KuiMountCharacter.ActiveSet or 'One')

        useHybridCheck:SetChecked(KuiMountSaved.useHybrid)
        supressErrorsCheck:SetChecked(KuiMountSaved.supressErrors)
    end

    ------------------------------------------------- Create options elements --
    -- Use hybrid mounts as ground mounts checkbox -----------------------------
    useHybridCheck = CreateCheckBox('useHybrid', 'Use hybrid mounts as ground mounts')
    useHybridCheck:SetPoint('TOPLEFT', 16, -16)

    -- Supress spellbook errors checkbox ---------------------------------------
    supressErrorsCheck = CreateCheckBox('supressErrors', 'Supress spellbook errors')
    supressErrorsCheck:SetPoint('TOPLEFT', 332, -16)

    -- Prefered ----------------------------------------------------------------
    local preferedTitle = opt:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
    preferedTitle:SetText('Whitelist')
    preferedTitle:SetPoint('TOPLEFT', useHybridCheck, 'BOTTOMLEFT', 10, -10)

    preferedBox = CreateEditBox('KuiMountPreferedBox', 550, 380)
    preferedBox.Scroll:SetPoint('TOPLEFT', preferedTitle, 'BOTTOMLEFT', 0, -16)

    -- set buttons
    local SetChar = CreateFrame('Button', 'KuiMountSetCharButton', opt, 'UIPanelButtonTemplate')
    SetChar:SetPoint('BOTTOMRIGHT', preferedBox, 'TOPRIGHT', 25, 13)
    SetChar:SetText('Char')

    local SetThree = CreateFrame('Button', 'KuiMountSetThreeButton', opt, 'UIPanelButtonTemplate')
    SetThree:SetPoint('RIGHT', SetChar, 'LEFT')
    SetThree:SetText('Three')

    local SetTwo = CreateFrame('Button', 'KuiMountSetTwoButton', opt, 'UIPanelButtonTemplate')
    SetTwo:SetPoint('RIGHT', SetThree, 'LEFT')
    SetTwo:SetText('Two')

    local SetOne = CreateFrame('Button', 'KuiMountSetOneButton', opt, 'UIPanelButtonTemplate')
    SetOne:SetPoint('RIGHT', SetTwo, 'LEFT')
    SetOne:SetText('One')

    local SetsText = opt:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
    SetsText:SetText('Stored sets')
    SetsText:SetPoint('RIGHT', SetOne, 'LEFT', -5, 0)

    local SetsTooltipFrame = CreateFrame('Frame', nil, opt)
    SetsTooltipFrame:SetAllPoints(SetsText)
    SetsTooltipFrame:EnableMouse(true)

    SetsTooltipFrame:SetScript('OnEnter', function(self)
        -- tooltip for sets
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        GameTooltip:SetWidth(200)
        GameTooltip:AddLine('Stored sets')
        GameTooltip:AddLine('Sets One, Two and Three are saved account-wide, but which set is currently active is saved per-character. The Char set is character specific.', 1, 1, 1, true)
        GameTooltip:Show()
    end)
    SetsTooltipFrame:SetScript('OnLeave', function(self)
        GameTooltip:Hide()
    end)

    -- Blacklist/whitelist help text -------------------------------------------
    local blacklistHelp = opt:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
    blacklistHelp:SetText('Type the names of mounts into the set list. Each mount must be on its own line. When you close the window the lists will be verified and entries may move around. Class or faction specific mounts will generate errors unless you are currently playing that class or faction - to supress these errors, check the "Supress spellbook errors" option.')
    blacklistHelp:SetPoint('TOPLEFT', preferedBox.Scroll, 'BOTTOMLEFT', 0, -15)
    blacklistHelp:SetHeight(80)
    blacklistHelp:SetWidth(550)
    blacklistHelp:SetWordWrap(true)
    blacklistHelp:SetJustifyH('LEFT')
    blacklistHelp:SetJustifyV('TOP')

    --------------------------------------------------------- Script handlers --
    local function OnOptionsShow()
        SetValues()
    end

    local function OnEscapePressed(self)
        self:ClearFocus()
    end

    local function OnEditFocusLost(self)
        ns.GetMounts()

        local text = { strsplit('\n', self:GetText()) }
        local invalid = {}
        local entries = {}

        -- get the active list
        local env = GetActiveList()

        local k,name,_
        for k, name in ipairs(text) do
            if name ~= '' then
                local rname
                local mount_id = ns.mountlist[strlower(name)]

                if mount_id then
                    -- the player does actually have this mount
                    if type(mount_id) == 'table' then
                        -- its a spell mount, rather than a companion
                        rname = mount_id[1]
                    else
                        rname = C_MountJournal.GetMountInfoByID(ns.MOUNT_IDS[mount_id])
                    end
                end

                -- if the mount can't be found, just store it verbatim
                entries[rname or name] = true
                env[rname or name] = true

                if not rname then
                    -- (and warn the player about it)
                    tinsert(invalid, name)
                end
            end
        end

        for name, _ in pairs(env) do
            -- check for removed mounts
            if not entries[name] then
                env[name] = nil
            end
        end

        if not KuiMountSaved.supressErrors and #invalid > 0 then
            -- print invalid mounts
            print(category..': |cffff3333The following mounts were not found in your spellbook:|r '..table.concat(invalid, ', '))
        end
    end

    local function OnSetButtonClicked(button)
        preferedBox:ClearFocus()
        ActivateSet(button:GetText())
    end

    opt:SetScript('OnShow', OnOptionsShow)

    preferedBox:SetScript('OnEscapePressed', OnEscapePressed)
    preferedBox:SetScript('OnEditFocusLost', OnEditFocusLost)

    SetChar:SetScript('OnClick', OnSetButtonClicked)
    SetOne:SetScript('OnClick', OnSetButtonClicked)
    SetTwo:SetScript('OnClick', OnSetButtonClicked)
    SetThree:SetScript('OnClick', OnSetButtonClicked)

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

    if msg == '' then
        print(category..': |cffff3333You need to update your mount macro!|r Change the |cffaaaaaa/mount|r line to |cffaaaaaa/click KuiMountSecureButton')
    end
end
