local ADDON, NS = ...

-- A small settings window, opened with /sszmap. Everything in here is the
-- quiet-moment kind of setting: where the windows sit, how big they are and
-- whether they are pinned down. Nothing in it needs touching mid-pull.

local WIDTH = 330
local panel
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

local function scaleStepper(parent, label, y, key)
    addStepper(parent, label, y, function()
        return NS.Scale(key)
    end, function(dir)
        NS.SetScale(key, NS.Scale(key) + dir * 0.05)
    end, function(v)
        return ("%d%%"):format(math.floor(v * 100 + 0.5))
    end)
end

local function build()
    panel = CreateFrame("Frame", "SszorakMapHelperOptions", UIParent, "BackdropTemplate")
    panel:SetSize(WIDTH, 292)
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

    addCheck(panel, "Show the windows now", y, NS.Positioning, NS.SetPositioning,
        "The palette and the placements only appear during a Sszorak pull. Tick this to bring them up anywhere so you can drag them into place, then untick it.")
    y = y - 30

    addCheck(panel, "Lock both windows in place", y, NS.AllLocked, NS.SetAllLocked,
        "Stops both windows being dragged. Each window also has its own padlock in its top right corner. The sectors stay clickable either way.")
    y = y - 36

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

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 16, y)
    hint:SetPoint("TOPRIGHT", -16, y)
    hint:SetJustifyH("LEFT")
    hint:SetText(
        "Right-click a sector on the palette to change which marker sits there."
            .. " Set them up however your raid calls them - nothing gets moved for you."
    )

    tinsert(UISpecialFrames, "SszorakMapHelperOptions")
    panel:Hide()
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
