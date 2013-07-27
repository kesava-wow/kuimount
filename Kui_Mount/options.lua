--[[
	Kui Mount
	Kesava-Auchindoun
]]
local addon,ns = ...
local category = 'Kui Mount'

do
	local blacklistBox, preferedBox, useHybridCheck, blacklistSpecificCheck, supressErrorsCheck, whitelistSpecificCheck

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
			blacklistBox:ClearFocus()
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

	local function SetValues()
		local blacklist = KuiMountCharacter.blacklistHere and
	          KuiMountCharacter.blacklist or KuiMountSaved.blacklist
		
		local whitelist = KuiMountCharacter.whitelistHere and
		      KuiMountCharacter.whitelist or KuiMountSaved.whitelist

		local text, name, _
		for name, _ in pairs(blacklist) do
			text = (text and text..'\n'..name or name)
		end
		
		blacklistBox:SetText(text or '')

		text = nil
		for name, _ in pairs(whitelist) do
			text = (text and text..'\n'..name or name)
		end
		
		preferedBox:SetText(text or '')

		useHybridCheck:SetChecked(KuiMountSaved.useHybrid)
		supressErrorsCheck:SetChecked(KuiMountSaved.supressErrors)

		blacklistSpecificCheck:SetChecked(KuiMountCharacter.blacklistHere)
		whitelistSpecificCheck:SetChecked(KuiMountCharacter.whitelistHere)
	end

	------------------------------------------------- Create options elements --
	-- Use hybrid mounts as ground mounts checkbox -----------------------------
	useHybridCheck = CreateCheckBox('useHybrid', 'Use hybrid mounts as ground mounts.')
	useHybridCheck:SetPoint('TOPLEFT', 16, -16)
	
	-- Supress spellbook errors checkbox ---------------------------------------
	supressErrorsCheck = CreateCheckBox('supressErrors', 'Supress spellbook errors.')
	supressErrorsCheck:SetPoint('TOPLEFT', 332, -16)

	-- Blacklist ---------------------------------------------------------------
	local blacklistTitle = opt:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
	blacklistTitle:SetText('Blacklist')
	blacklistTitle:SetPoint('TOPLEFT', useHybridCheck, 'BOTTOMLEFT', 0, -14)

	blacklistSpecificCheck = CreateCheckBox('blacklistHere', 'Character specific', false, SetValues)
	blacklistSpecificCheck:SetPoint('LEFT', blacklistTitle, 'RIGHT', 5, 0)
	
	blacklistBox = CreateEditBox('KuiMountBlacklistBox', 250, 380)
	blacklistBox.Scroll:SetPoint('TOPLEFT', blacklistTitle, 'BOTTOMLEFT', 0, -16)
	
	-- Prefered ----------------------------------------------------------------
	local preferedTitle = opt:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
	preferedTitle:SetText('Whitelist')
	preferedTitle:SetPoint('TOPLEFT', useHybridCheck, 'BOTTOMLEFT', 316, -14)

	whitelistSpecificCheck = CreateCheckBox('whitelistHere', 'Character specific', false, SetValues)
	whitelistSpecificCheck:SetPoint('LEFT', preferedTitle, 'RIGHT', 5, 0)

	preferedBox = CreateEditBox('KuiMountPreferedBox', 250, 380)
	preferedBox.Scroll:SetPoint('TOPLEFT', preferedTitle, 'BOTTOMLEFT', 0, -16)

	-- Blacklist/whitelist help text -------------------------------------------
	local blacklistHelp = opt:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
	blacklistHelp:SetText('Type the names of mounts in the blacklist or whitelist. Each mount must be on its own line. When you close the window the lists will be verified and entries may move around. Class or faction specific mounts will generate errors unless you are currently playing that class or faction - to supress these errors, check the "Supress spellbook errors" option.')
	blacklistHelp:SetPoint('TOPLEFT', blacklistBox.Scroll, 'BOTTOMLEFT', 0, -10)
	blacklistHelp:SetHeight(80)
	blacklistHelp:SetWidth(600)
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

		local env
		local text = { strsplit('\n', self:GetText()) }
		local invalid = {}
		local entries = {}

		if self:GetName() == 'KuiMountBlacklistBox' then
			env = KuiMountCharacter.blacklistHere and
	              KuiMountCharacter.blacklist or KuiMountSaved.blacklist
		else
			env = KuiMountCharacter.whitelistHere and
		          KuiMountCharacter.whitelist or KuiMountSaved.whitelist
		end

		local k,name,_
		for k, name in ipairs(text) do
			if name ~= '' then
				local rname
				if ns.mountlist[strlower(name)] then
					rname = ns.mountlist[strlower(name)][1]
				end
				
				entries[rname or name] = true
				env[rname or name] = true

				if not rname then
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
			print('|cff9900ffKui_Mount:|r |cffff3333The following mounts were not found in your spellbook:|r '..table.concat(invalid, ', '))
		end
	end

	opt:SetScript('OnShow', OnOptionsShow)

	blacklistBox:SetScript('OnEscapePressed', OnEscapePressed)
	blacklistBox:SetScript('OnEditFocusLost', OnEditFocusLost)
	
	preferedBox:SetScript('OnEscapePressed', OnEscapePressed)
	preferedBox:SetScript('OnEditFocusLost', OnEditFocusLost)

	InterfaceOptions_AddCategory(opt)
end

--------------------------------------------------------------- Slash command --
SLASH_KUIMOUNT1 = '/kuimount'
SLASH_KUIMOUNT2 = '/mount'

function SlashCmdList.KUIMOUNT(msg)
	if msg ~= '' then
		InterfaceOptionsFrame_OpenToCategory(category)
	else
		ns.Mount()
	end
end