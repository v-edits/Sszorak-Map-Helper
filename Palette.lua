local ADDON, NS = ...

-- The input half: the room drawn as its eight sectors, north up, with the six
-- live ones wearing whatever marker you put there. You click the sector you
-- can SEE the thing in and the addon records the marker opposite it, which is
-- the one you actually have to call out.

local RING = 62 -- how far the sectors sit from the middle, px
local BTN = 34
local DOT = 14 -- the dead north and south sectors
local CANVAS = RING * 2 + BTN + 10

local palette
local slots = {} -- sector -> button
local pairsLine

local function offsetFor(sector)
    local i = NS.SectorIndex(sector)
    if not i then
        return 0, 0
    end
    -- clockwise from north, so the list order and the screen agree
    local theta = math.rad((i - 1) * 45)
    return RING * math.sin(theta), RING * math.cos(theta)
end

local function assignMenu(owner, sector)
    if InCombatLockdown() then
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(sector .. " sector shows")
        for _, mark in ipairs(NS.PALETTE) do
            root:CreateButton(NS.MarkIcon(mark, 16) .. " " .. NS.MarkName(mark), function()
                NS.SetMarkAt(sector, mark)
            end)
        end
        -- the dead pair, and only the dead pair, can be emptied back to its
        -- bare letter. The other six always have to name something.
        if NS.DEAD[sector] then
            root:CreateDivider()
            root:CreateButton("Clear marker", function()
                NS.ClearMarkAt(sector)
            end)
        end
    end)
end

local function buildSector(canvas, sector)
    local ox, oy = offsetFor(sector)

    local btn = CreateFrame("Button", nil, canvas)
    btn:SetSize(BTN, BTN)
    btn:SetPoint("CENTER", canvas, "CENTER", ox, oy)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    btn.icon = icon

    btn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            assignMenu(self, sector)
            return
        end
        NS.Record(sector)
    end)

    btn:SetScript("OnEnter", function(self)
        local here = NS.MarkAt(sector)
        local opp = NS.Opposite(sector)
        local call = opp and NS.MarkAt(opp)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(("%s sector"):format(sector), 1, 1, 1)
        if here and call then
            GameTooltip:AddLine(("See %s %s here"):format(NS.MarkIcon(here, 14), NS.MarkName(here)), 0.8, 0.8, 0.8)
            GameTooltip:AddLine(("Click to call %s %s"):format(NS.MarkIcon(call, 14), NS.MarkName(call)), 0.4, 1, 0.5)
        end
        if not InCombatLockdown() then
            GameTooltip:AddLine(
                here and "Right-click to put a different marker here" or "Right-click to put a marker here",
                0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- The dead pair gets its plain letter built alongside the button rather
    -- than instead of it, so the option can be turned on and off without
    -- rebuilding the window: the refresh just swaps which one is showing.
    if NS.DEAD[sector] then
        local dot = btn:CreateTexture(nil, "ARTWORK")
        dot:SetSize(DOT, DOT)
        dot:SetPoint("CENTER")
        dot:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        dot:SetVertexColor(0.35, 0.35, 0.35, 0.7)
        local tag = btn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        tag:SetPoint("CENTER", dot, "CENTER", 0, 0)
        tag:SetText(sector)
        btn.dot, btn.tag = dot, tag
    end

    slots[sector] = btn
end

local function build()
    palette = CreateFrame("Frame", "SszorakMapHelperPalette", UIParent, "BackdropTemplate")
    palette:SetSize(CANVAS + 16, CANVAS + 82)
    palette:EnableMouse(true)
    NS.MakeMovable(palette, "palette", "CENTER", -260, 0)
    palette:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    palette:SetBackdropColor(0, 0, 0, 0.8)

    local title = palette:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    -- bounded left and right rather than centred on a single point, so a long
    -- caption cannot spill past the window edge. The right inset clears the padlock.
    title:SetPoint("TOPLEFT", 8, -8)
    title:SetPoint("TOPRIGHT", -22, -8)
    title:SetJustifyH("CENTER")
    title:SetText("Click where the tornadoes are")

    local canvas = CreateFrame("Frame", nil, palette)
    canvas:SetSize(CANVAS, CANVAS)
    canvas:SetPoint("TOP", 0, -26)

    -- the floor, so the sectors read as a room rather than eight loose icons
    local disc = canvas:CreateTexture(nil, "BACKGROUND")
    disc:SetSize(RING * 2 + BTN - 6, RING * 2 + BTN - 6)
    disc:SetPoint("CENTER")
    disc:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    disc:SetVertexColor(0.25, 0.45, 0.6, 0.22)

    -- the boss holds the middle, which is what makes opposite mean anything
    local boss = canvas:CreateTexture(nil, "ARTWORK")
    boss:SetSize(8, 8)
    boss:SetPoint("CENTER")
    boss:SetColorTexture(1, 0.35, 0.35, 0.9)

    for _, sector in ipairs(NS.SECTORS) do
        buildSector(canvas, sector)
    end

    pairsLine = palette:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pairsLine:SetPoint("TOP", canvas, "BOTTOM", 0, -2)
    pairsLine:SetTextColor(0.7, 0.7, 0.7)

    -- Clear is the one that gets hit in a hurry between sets, so it gets the
    -- room. Undo is the careful one and can stay small.
    local clear = CreateFrame("Button", nil, palette, "UIPanelButtonTemplate")
    clear:SetSize(104, 28)
    clear:SetPoint("BOTTOMRIGHT", -8, 8)
    clear:SetText("Clear")
    clear:SetScript("OnClick", NS.Clear)

    local undo = CreateFrame("Button", nil, palette, "UIPanelButtonTemplate")
    undo:SetSize(58, 28)
    undo:SetPoint("RIGHT", clear, "LEFT", -5, 0)
    undo:SetText("Undo")
    undo:SetScript("OnClick", NS.Undo)

    -- Hung under the window rather than inside it, the way the warning text
    -- hangs over the readout. Nothing has to resize when it comes and goes.
    local share = CreateFrame("Button", nil, palette, "UIPanelButtonTemplate")
    share:SetPoint("TOPLEFT", palette, "BOTTOMLEFT", 8, -4)
    share:SetPoint("TOPRIGHT", palette, "BOTTOMRIGHT", -8, -4)
    share:SetHeight(26)
    share:SetText("Share layout with raid")
    share:SetScript("OnClick", function()
        NS.PushLayout()
    end)
    share:Hide()
    palette.share = share

    NS.AttachLock(palette, "palette")
end

-- the three pairings spelled out, so the layout can be checked at a glance
-- instead of hovering all six sectors
local function pairsText()
    local shown, parts = {}, {}
    for _, sector in ipairs(NS.SECTORS) do
        local opp = NS.Opposite(sector)
        local here, there = NS.MarkAt(sector), opp and NS.MarkAt(opp)
        if here and there and not shown[sector] then
            shown[sector], shown[opp] = true, true
            parts[#parts + 1] = ("%s%s"):format(NS.MarkIcon(here, 13), NS.MarkIcon(there, 13))
        end
    end
    return table.concat(parts, "   ")
end

function NS.PaletteRefresh()
    local want = NS.Visible()
    if not palette then
        if not want then
            return
        end
        build()
    end
    palette:SetShown(want)
    if not want then
        return
    end
    palette:SetScale(NS.Scale("paletteScale"))
    palette.lock.Sync()
    -- Dimming the markers that are not called only helps once there is nothing
    -- left to click. Do it any earlier and it would hide the very sectors you
    -- still have to press to record the second and third placement.
    local called = NS.CalledMarks()
    local fade = SszorakMapHelperDB.fadeUnused and #NS.Calls() >= NS.PLACEMENTS
    for sector, btn in pairs(slots) do
        local mark = NS.MarkAt(sector)
        -- an empty sector shows its letter instead, which only the dead pair
        -- can ever be. It keeps the mouse either way so it can be given a
        -- marker back from the right-click menu.
        if btn.dot then
            btn.dot:SetShown(mark == nil)
            btn.tag:SetShown(mark == nil)
        end
        btn.icon:SetTexture(mark and NS.MARK_TEX:format(mark) or nil)
        -- faded rather than hidden, so the sector keeps its tooltip and comes
        -- straight back when the set is cleared
        btn.icon:SetAlpha(fade and not (mark and called[mark]) and NS.FADE or 1)
    end
    -- one press, offered only to someone who can actually send, and gone once
    -- the raid has the layout
    palette.share:SetShown(NS.LayoutShareable and NS.LayoutShareable() or false)
    pairsLine:SetText(pairsText())
end
