local ADDON, NS = ...

-- A small settings window, opened with /sszmap. The top half is the everyday
-- stuff: where the windows sit, how big they are and whether they are pinned
-- down. The advanced section folds away underneath it, because wording and
-- timings are things you set once and then forget about.

local WIDTH = 330
local BASE_H = 376
local ADV_H = 310

local panel
local advanced -- container for the folded section
local advToggle
local rows = {} -- every widget that has a Sync, refreshed together

local function addCheck(parent, label, y, get, set, tip)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb:SetPoint("TOPLEFT", 12, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    fs:SetText(label)
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
    end)
    if tip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, 1, 1, 1, 1, true)
            GameTooltip:AddLine(tip, 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    rows[#rows + 1] = {
        Sync = function()
            cb:SetChecked(get() and true or false)
        end,
    }
end

-- a label on the left and a minus/value/plus cluster on the right. Steppers
-- rather than sliders: there are only a handful of useful values and a
-- stepper cannot be nudged half a percent by a shaky drag
local function addStepper(parent, label, y, get, step, fmt)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", 16, y - 5)
    fs:SetText(label)

    local plus = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    plus:SetSize(26, 22)
    plus:SetPoint("TOPRIGHT", -12, y)
    plus:SetText("+")
    plus:SetScript("OnClick", function()
        step(1)
    end)

    local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    value:SetPoint("RIGHT", plus, "LEFT", -8, 0)
    value:SetWidth(54)
    value:SetJustifyH("CENTER")

    local minus = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    minus:SetSize(26, 22)
    minus:SetPoint("RIGHT", value, "LEFT", -8, 0)
    minus:SetText("-")
    minus:SetScript("OnClick", function()
        step(-1)
    end)

    rows[#rows + 1] = {
        Sync = function()
            value:SetText(fmt(get()))
        end,
    }
end

-- Typed settings commit on enter or on clicking away, and escape puts the box
-- back to what is actually stored rather than leaving a half-typed edit on
-- screen pretending to be the setting.
local function addEdit(parent, label, y, get, set)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", 16, y - 4)
    fs:SetText(label)

    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(150, 20)
    eb:SetPoint("TOPRIGHT", -14, y)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(40)
    eb:SetScript("OnEnterPressed", function(self)
        set(self:GetText())
        self:ClearFocus()
    end)
    eb:SetScript("OnEditFocusLost", function(self)
        set(self:GetText())
    end)
    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        NS.OptionsRefresh()
    end)

    rows[#rows + 1] = {
        Sync = function()
            -- never yank the text out from under someone mid-type
            if not eb:HasFocus() then
                eb:SetText(get() or "")
                eb:SetCursorPosition(0)
            end
        end,
    }
end

local function scaleStepper(parent, label, y, key)
    addStepper(parent, label, y, function()
        return NS.Scale(key)
    end, function(dir)
        NS.SetScale(key, NS.Scale(key) + dir * 0.05)
    end, function(v)
        return ("%d%%"):format(math.floor(v * 100 + 0.5))
    end)
end

local function applyAdvanced()
    local open = SszorakMapHelperDB.advancedOpen and true or false
    advanced:SetShown(open)
    advToggle:SetText(open and "Advanced options    -" or "Advanced options    +")
    panel:SetHeight(BASE_H + (open and ADV_H or 0))
end

-- the measured amp times, shown rather than made editable: nine numbers across
-- three difficulties is a spreadsheet, not a settings row
local function ampLine()
    local short = { [14] = "N", [15] = "H", [16] = "M" }
    local parts = {}
    for _, diff in ipairs({ 14, 15, 16 }) do
        local times = NS.AMP_TIMES[diff]
        if times then
            local nums = {}
            for i, v in ipairs(times) do
                nums[i] = tostring(math.floor(v + 0.5))
            end
            parts[#parts + 1] = short[diff] .. " " .. table.concat(nums, "/")
        end
    end
    return table.concat(parts, "    ")
end

local function buildAdvanced(p)
    local y = -4

    for _, key in ipairs(NS.PROMPT_ORDER) do
        addEdit(p, NS.PROMPT_LABELS[key], y, function()
            return NS.PromptText(key)
        end, function(v)
            NS.SetPromptText(key, v)
        end)
        y = y - 28
    end
    y = y - 6

    addCheck(p, "Hide warning text", y, function()
        return SszorakMapHelperDB.hidePrompt
    end, function(v)
        SszorakMapHelperDB.hidePrompt = v
        NS.Refresh()
    end, "Stops both warnings appearing at all. The placements still clear on schedule.")
    y = y - 34

    local tlabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tlabel:SetPoint("TOPLEFT", 16, y)
    tlabel:SetText("Timings, in seconds")
    y = y - 22

    for _, key in ipairs(NS.TIMER_ORDER) do
        addStepper(p, NS.TIMER_LABELS[key], y, function()
            return NS.Timer(key)
        end, function(dir)
            NS.SetTimer(key, NS.Timer(key) + dir)
        end, function(v)
            return ("%ds"):format(v)
        end)
        y = y - 26
    end
    y = y - 8

    local note = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", 16, y)
    note:SetPoint("TOPRIGHT", -16, y)
    note:SetJustifyH("LEFT")
    note:SetText(
        "Damage Amp lands at " .. ampLine() .. ". Everything above is measured from those, and they are not editable here."
    )
    y = y - 40

    local reset = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    reset:SetSize(150, 22)
    reset:SetPoint("TOPLEFT", 14, y)
    reset:SetText("Reset advanced")
    reset:SetScript("OnClick", NS.ResetAdvanced)
end

local function build()
    panel = CreateFrame("Frame", "SszorakMapHelperOptions", UIParent, "BackdropTemplate")
    panel:SetSize(WIDTH, BASE_H)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:SetBackdropColor(0, 0, 0, 0.92)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Sszorak Map Helper")

    local sub = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("TOP", title, "BOTTOM", 0, -2)
    sub:SetText("Normal, Heroic and Mythic only")

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    local y = -52

    addCheck(panel, "Lock both windows in place", y, NS.AllLocked, NS.SetAllLocked,
        "Stops both windows being dragged. Each window also has its own padlock in its top right corner. The sectors stay clickable either way.")
    y = y - 36

    addCheck(panel, "Share the set with the raid", y, function()
        return SszorakMapHelperDB.share
    end, function(v)
        SszorakMapHelperDB.share = v
    end, "Sends what you record to everyone else running this addon, so they see the calls without being told. Only works if you are the raid leader or an assist. Turn it off if someone else is calling.")
    y = y - 36

    addCheck(panel, "Fade the markers you do not need", y, function()
        return SszorakMapHelperDB.fadeUnused
    end, function(v)
        SszorakMapHelperDB.fadeUnused = v
        NS.Refresh()
    end, "Once all three placements are recorded, everything except the three you are running to fades back. It waits for the full set so it can never hide a sector you still have to click. Right-click north or south to give them a marker, or clear it again.")
    y = y - 40

    scaleStepper(panel, "Palette size", y, "paletteScale")
    y = y - 30
    scaleStepper(panel, "Placements size", y, "callsScale")
    y = y - 40

    local clear = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    clear:SetSize(96, 24)
    clear:SetPoint("TOPLEFT", 14, y)
    clear:SetText("Clear set")
    clear:SetScript("OnClick", NS.Clear)

    local resetPos = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetPos:SetSize(102, 24)
    resetPos:SetPoint("LEFT", clear, "RIGHT", 6, 0)
    resetPos:SetText("Reset places")
    resetPos:SetScript("OnClick", NS.ResetPositions)

    local resetLayout = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetLayout:SetSize(96, 24)
    resetLayout:SetPoint("LEFT", resetPos, "RIGHT", 6, 0)
    resetLayout:SetText("Reset markers")
    resetLayout:SetScript("OnClick", NS.ResetLayout)
    y = y - 38

    local pushLayout = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    pushLayout:SetSize(WIDTH - 28, 24)
    pushLayout:SetPoint("TOPLEFT", 14, y)
    pushLayout:SetText("Send my markers to the raid")
    pushLayout:SetScript("OnClick", NS.PushLayout)
    pushLayout:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Send my markers to the raid", 1, 1, 1, 1, true)
        GameTooltip:AddLine(
            "Puts your marker layout on everyone else's map so the shared calls mean the same thing on their screen as on yours."
                .. " Never sent automatically - nobody's config changes unless you press this.",
            0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    pushLayout:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    y = y - 36

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 16, y)
    hint:SetPoint("TOPRIGHT", -16, y)
    hint:SetJustifyH("LEFT")
    hint:SetText(
        "The windows are up while this panel is open so you can place them."
            .. " Right-click a sector to change which marker sits there - nothing gets moved for you."
    )
    y = y - 34

    advToggle = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    advToggle:SetSize(WIDTH - 28, 22)
    advToggle:SetPoint("TOPLEFT", 14, y)
    advToggle:SetScript("OnClick", function()
        SszorakMapHelperDB.advancedOpen = not SszorakMapHelperDB.advancedOpen
        applyAdvanced()
    end)
    y = y - 26

    -- Everything folded away lives on its own frame, so opening and closing is
    -- one Show and one height, not a pile of widgets each remembering itself.
    advanced = CreateFrame("Frame", nil, panel)
    advanced:SetPoint("TOPLEFT", 0, y)
    advanced:SetPoint("TOPRIGHT", 0, y)
    advanced:SetHeight(ADV_H)
    buildAdvanced(advanced)

    applyAdvanced()
    tinsert(UISpecialFrames, "SszorakMapHelperOptions")
    -- hidden first, then hooked: a frame starts out shown, so hooking before
    -- this would fire OnHide once while merely building the thing
    panel:Hide()

    -- The windows come up with the settings and go away with them. Hooking the
    -- frame's own show and hide catches every route in and out - the close
    -- button, escape through UISpecialFrames, and /sszmap toggling it - rather
    -- than each of them having to remember to do it.
    panel:SetScript("OnShow", function()
        NS.SetPositioning(true)
    end)
    panel:SetScript("OnHide", function()
        NS.SetPositioning(false)
    end)
end

function NS.OpenOptions()
    if not panel then
        build()
    end
    panel:Show()
    NS.OptionsRefresh()
end

function NS.ToggleOptions()
    if panel and panel:IsShown() then
        panel:Hide()
        return
    end
    NS.OpenOptions()
end

-- An entry in Blizzard's own AddOns settings list, so the addon can be found
-- where people go looking for addon settings instead of only through a slash
-- command they have to already know. It is a signpost with one button rather
-- than a second copy of the options: keeping one panel means there is no way
-- for two versions of the same setting to disagree.
local function registerBlizzardEntry()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
        return
    end
    local stub = CreateFrame("Frame")
    stub.name = "Sszorak Map Helper"

    local title = stub:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Sszorak Map Helper")

    local desc = stub:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetPoint("RIGHT", stub, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText("The settings open in their own movable window, so you can see the addon while you change it.")

    local btn = CreateFrame("Button", nil, stub, "UIPanelButtonTemplate")
    btn:SetSize(220, 26)
    btn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -14)
    btn:SetText("Open the options")
    btn:SetScript("OnClick", function()
        -- Blizzard's settings window would sit on top of ours, so step it aside
        if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then
            HideUIPanel(SettingsPanel)
        end
        NS.OpenOptions()
    end)

    local hint = stub:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -10)
    hint:SetText("Or type /sszmap")

    Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(stub, stub.name))
end

function NS.OptionsRefresh()
    if not panel or not panel:IsShown() then
        return
    end
    for _, row in ipairs(rows) do
        row.Sync()
    end
end

registerBlizzardEntry()
