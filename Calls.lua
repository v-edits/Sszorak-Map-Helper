local ADDON, NS = ...

-- The output half: the placements in call order, big enough to read without
-- looking away from the fight. It shows its numbered slots even while empty,
-- so the window can be dragged where you want it before a pull ever starts.

local LINE_H = 22
local TITLE_H = 20
local WIDTH = 168

local board
local lines = {}

local function build()
    board = CreateFrame("Frame", "SszorakMapHelperCalls", UIParent, "BackdropTemplate")
    board:SetSize(WIDTH, TITLE_H + LINE_H * NS.PLACEMENTS + 12)
    NS.MakeMovable(board, "board", "CENTER", 0, -60)
    board:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    board:SetBackdropColor(0, 0, 0, 0.75)

    local title = board:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -6)
    title:SetText("Placements")
    title:SetTextColor(0.7, 0.7, 0.7)
    board.title = title

    -- The one line the schedule speaks through. Parented to the board so it
    -- travels with it, and sat above rather than inside so it cannot shove the
    -- numbers around. Core decides what it says.
    local prompt = board:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    prompt:SetPoint("BOTTOM", board, "TOP", 0, 6)
    prompt:Hide()
    board.prompt = prompt

    NS.AttachLock(board, "board")
end

local function lineAt(i)
    if lines[i] then
        return lines[i]
    end
    local fs = board:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", board, "TOPLEFT", 12, -(TITLE_H + LINE_H * (i - 1) + 2))
    fs:SetJustifyH("LEFT")
    lines[i] = fs
    return fs
end

function NS.CallsRefresh()
    -- it rides with the palette: both belong to the pull, and both come back
    -- together in positioning mode so they can be placed against each other
    local want = NS.Visible()
    if not board then
        if not want then
            return
        end
        build()
    end
    board:SetShown(want)
    if not want then
        return
    end
    board:SetScale(NS.Scale("callsScale"))
    local p = NS.Prompt()
    board.prompt:SetShown(p ~= nil)
    if p then
        board.prompt:SetText(p.text)
        board.prompt:SetTextColor(unpack(p.color))
    end

    -- click-through once a fight is on, draggable the rest of the time
    local fighting = InCombatLockdown()
    board:EnableMouse(not fighting and not NS.IsLocked("board"))
    board.lock.Sync()

    local list = NS.Calls()
    for i = 1, NS.PLACEMENTS do
        local fs = lineAt(i)
        local mark = list[i]
        if mark then
            fs:SetText(("%d = %s %s"):format(i, NS.MarkIcon(mark, 18), NS.MarkName(mark)))
            fs:SetTextColor(1, 1, 1, 1)
        else
            fs:SetText(("%d ="):format(i))
            fs:SetTextColor(1, 1, 1, 0.3)
        end
        fs:Show()
    end
end
