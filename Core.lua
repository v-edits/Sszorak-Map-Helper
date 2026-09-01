local ADDON, NS = ...

NS.VERSION = "0.2.0"

-- Sszorak, Venomous Abyss. The id and the difficulty numbers are the game's
-- own: 14 Normal, 15 Heroic, 16 Mythic. LFR (17) is deliberately not here.
NS.ENCOUNTER_ID = 3420
NS.DIFFICULTIES = { [14] = "Normal", [15] = "Heroic", [16] = "Mythic" }

-- The Venomous Abyss, and Sszorak himself. Target detection keys off the npc id
-- rather than the name because names are localised - the Korean client calls
-- him 스조라크 - so matching on a name would only ever work for some players.
NS.INSTANCE_ID = 3004
NS.NPC_ID = 257347

NS.MARK_TEX = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_%d"
NS.MARK_NAMES = {
    [1] = "Star",
    [2] = "Circle",
    [3] = "Diamond",
    [4] = "Triangle",
    [5] = "Moon",
    [6] = "Square",
    [7] = "Cross",
    [8] = "Skull",
}

-- Every raid marker, not just the six the default layout uses. Six sectors and
-- eight markers means two sit unused, which is the player's business: plenty of
-- raids call Moon or Skull and there is no reason to make them rename their
-- own callouts to suit this addon.
NS.PALETTE = { 1, 2, 3, 4, 5, 6, 7, 8 }

-- How far back anything the call does not need is pushed. One number for both
-- windows so the palette and the readout cannot drift apart.
NS.FADE = 0.08

-- Eight sectors, listed clockwise from north, which is the whole trick: the
-- sector opposite any sector is four steps around the ring, so the pairing
-- falls out of the order and never has to be written down separately.
-- North and south are the dead pair and never hold a marker.
NS.SECTORS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }

-- North and south are the dead pair: nothing spawns there. They still carry a
-- marker by default because most raids do mark all eight, but unlike the other
-- six theirs can be cleared away, which puts the plain letter back. There is no
-- setting for that - whether the marker is there IS the setting.
NS.DEAD = { N = true, S = true }

-- A sector takes part only while it is showing a marker, which is always true
-- for the six and up to the player for the dead pair.
function NS.SectorLive(sector)
    return NS.MarkAt(sector) ~= nil
end

local SECTOR_AT = {}
for i, s in ipairs(NS.SECTORS) do
    SECTOR_AT[s] = i
end

function NS.SectorIndex(sector)
    return SECTOR_AT[sector]
end

function NS.Opposite(sector)
    local i = SECTOR_AT[sector]
    return i and NS.SECTORS[(i + 3) % 8 + 1] or nil
end

-- Star opposite Triangle, Circle opposite Cross, Diamond opposite Square.
-- Right-click any sector on the palette to rearrange it.
-- Matches NSRT's default marker map for this fight, so a raid running both
-- sees the same markers in the same places without configuring either.
-- That includes Diamond on north and Square on south, which can be cleared
-- away per sector if a raid would rather see the bare letters there.
local DEFAULT_LAYOUT = { N = 3, NE = 8, E = 4, SE = 5, S = 6, SW = 7, W = 1, NW = 2 }

local function copyLayout(src)
    local out = {}
    for k, v in pairs(src) do
        out[k] = v
    end
    return out
end

-- A layout only has to name a real marker for every live sector. It is NOT
-- checked for duplicates on purpose: if someone wants the same marker twice
-- that is their call, and throwing their config away over it would be a far
-- worse surprise than the duplicate.
local function layoutValid(layout)
    if type(layout) ~= "table" then
        return false
    end
    for _, sector in ipairs(NS.SECTORS) do
        local mark = layout[sector]
        if mark == nil then
            -- only the dead pair is allowed to be empty
            if not NS.DEAD[sector] then
                return false
            end
        elseif type(mark) ~= "number" or mark < 1 or mark > 8 then
            return false
        end
    end
    return true
end

function NS.ResetLayout()
    SszorakMapHelperDB.layout = copyLayout(DEFAULT_LAYOUT)
    NS.Refresh()
end

function NS.Layout()
    return SszorakMapHelperDB.layout
end

function NS.MarkAt(sector)
    return SszorakMapHelperDB.layout[sector]
end

-- What you pick is what goes there, and nothing else moves. Setting the same
-- marker twice is allowed: a config that rearranges itself under you to enforce
-- a rule is more annoying than the mistake it is preventing, and the board shows
-- the pairings plainly enough for a duplicate to be spotted.
function NS.SetMarkAt(sector, mark)
    SszorakMapHelperDB.layout[sector] = mark
    NS.Refresh()
end

-- Only the dead pair can be emptied. Clearing one of the six would leave the
-- sector opposite it with nothing to call, which is a way to quietly break the
-- addon rather than a setting anyone wants.
function NS.ClearMarkAt(sector)
    if not NS.DEAD[sector] then
        return
    end
    SszorakMapHelperDB.layout[sector] = nil
    NS.Refresh()
end

--#region Visibility

-- The windows belong to one pull of one boss. They also come up when he is
-- targeted, which is when markers get placed, and whenever the settings panel
-- is open. Everywhere else they are gone.
local active = false
local targeting = false

function NS.Active()
    return active
end

-- Session only, deliberately. It tracks whether the settings panel is open,
-- and persisting that would mean logging in to windows nobody asked for, with
-- the control that used to turn them off no longer on the panel.
local positioning = false

function NS.Positioning()
    return positioning
end

function NS.SetPositioning(on)
    positioning = on and true or false
    NS.Refresh()
end

function NS.Visible()
    return active or targeting or NS.Positioning()
end

-- Creature guids read Creature-0-server-instance-zone-NPCID-spawn, so the sixth
-- field is the one that identifies him. A player or pet guid is shaped
-- differently and simply fails the number check.
local function targetingBoss()
    local guid = UnitGUID("target")
    if not guid then
        return false
    end
    return tonumber((select(6, strsplit("-", guid)))) == NS.NPC_ID
end

--#endregion

--#region Placements

local calls = {}

function NS.Calls()
    return calls
end

-- Everything that changes the recorded set goes through here rather than
-- calling Refresh directly, so the sync layer has exactly one place to listen
-- and no path - click, undo, clear, or the timer after the amp - can forget to
-- tell the rest of the raid.
function NS.CallsChanged()
    NS.Refresh()
    if NS.Broadcast then
        NS.Broadcast()
    end
end

-- Replaces the set wholesale, which is how a shared set arrives: the message
-- carries the whole thing, so there is nothing to merge. It refreshes without
-- broadcasting, or two addons would sit echoing each other forever.
function NS.SetCalls(list)
    wipe(calls)
    for i = 1, #list do
        calls[i] = list[i]
    end
    NS.Refresh()
end

-- The marks in the current set, as a lookup. A marker placed on two sectors
-- lights both of them, which is the honest answer: the layout allows
-- duplicates, so the addon cannot know which of the two was meant.
function NS.CalledMarks()
    local set = {}
    for _, mark in ipairs(calls) do
        set[mark] = true
    end
    return set
end

-- The fight calls for three placements on every difficulty, so this is a
-- constant rather than a setting.
NS.PLACEMENTS = 3

-- The one piece of real logic in the addon: you click the sector you can see
-- the thing in, and what gets recorded is the marker sitting opposite it.
function NS.Record(sector)
    if not NS.SectorLive(sector) then
        return
    end
    local opp = NS.Opposite(sector)
    local mark = opp and SszorakMapHelperDB.layout[opp]
    if not mark then
        return
    end
    if #calls >= NS.PLACEMENTS then
        NS.Print(("all %d placements are recorded - Clear to start over"):format(NS.PLACEMENTS))
        return
    end
    calls[#calls + 1] = mark
    NS.CallsChanged()
end

function NS.Undo()
    if #calls == 0 then
        return
    end
    calls[#calls] = nil
    NS.CallsChanged()
end

function NS.Clear()
    if #calls == 0 then
        return
    end
    wipe(calls)
    NS.CallsChanged()
end

--#endregion

function NS.MarkIcon(mark, size)
    return ("|T" .. NS.MARK_TEX .. ":%d|t"):format(mark, size or 16)
end

function NS.MarkName(mark)
    return NS.MARK_NAMES[mark] or "?"
end

function NS.Print(msg)
    print("|cff66ddaaSszorak|r: " .. msg)
end

function NS.Refresh()
    if NS.PaletteRefresh then
        NS.PaletteRefresh()
    end
    if NS.CallsRefresh then
        NS.CallsRefresh()
    end
    if NS.OptionsRefresh then
        NS.OptionsRefresh()
    end
    -- one place decides what the addon is listening to, and it is the same
    -- place that decides what is on screen
    if NS.SyncEvents then
        NS.SyncEvents()
    end
end

--#region Locks

-- Each window carries its own padlock, so the readout can be nailed down while
-- the palette is still being nudged. Locking only ever stops a window being
-- dragged; the sectors stay clickable either way.
function NS.IsLocked(key)
    return (SszorakMapHelperDB.locks and SszorakMapHelperDB.locks[key]) and true or false
end

function NS.SetLocked(key, v)
    SszorakMapHelperDB.locks = SszorakMapHelperDB.locks or {}
    SszorakMapHelperDB.locks[key] = v and true or nil
    NS.Refresh()
end

function NS.ToggleLock(key)
    NS.SetLocked(key, not NS.IsLocked(key))
end

function NS.AllLocked()
    return NS.IsLocked("palette") and NS.IsLocked("board")
end

function NS.SetAllLocked(v)
    NS.SetLocked("palette", v)
    NS.SetLocked("board", v)
end

-- Blizzard's own padlock. Solid means locked, faded and greyed means loose,
-- so one texture carries both states without shipping art.
local LOCK_TEX = "Interface\\PetBattles\\PetBattle-LockIcon"

function NS.AttachLock(frame, key)
    local btn = CreateFrame("Button", nil, frame)
    btn:SetSize(14, 14)
    btn:SetPoint("TOPRIGHT", -5, -5)
    local tex = btn:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetTexture(LOCK_TEX)

    local function paint(hover)
        local locked = NS.IsLocked(key)
        tex:SetDesaturated(not locked)
        tex:SetAlpha(hover and 1 or (locked and 0.9 or 0.35))
    end

    btn:SetScript("OnClick", function()
        NS.ToggleLock(key)
        paint(true)
    end)
    btn:SetScript("OnEnter", function(self)
        paint(true)
        local locked = NS.IsLocked(key)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(locked and "Locked" or "Unlocked", 1, 1, 1)
        GameTooltip:AddLine(
            locked and "Click to unlock, then drag this window" or "Click to lock this window in place",
            0.8, 0.8, 0.8, true
        )
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        paint(false)
        GameTooltip:Hide()
    end)

    -- no dragging happens in a fight anyway, so the padlock steps aside rather
    -- than sit there as one more thing to catch a click
    btn.Sync = function()
        btn:SetShown(not InCombatLockdown())
        paint(false)
    end
    btn.Sync()
    frame.lock = btn
    return btn
end

--#endregion

--#region Encounter schedule

-- The winds ride on Damage Amp, so that is what the set clears against. These
-- are the times NorthernSkyRaidTools measured, in seconds from ENCOUNTER_START,
-- per difficulty. Its own winds display hides 20s after each amp, and if NSRT
-- clears there then that is when the mechanic is done with.
NS.AMP_TIMES = {
    [14] = { 125, 277.1, 429.2 },
    [15] = { 111.1, 249.3, 387.5 },
    [16] = { 100, 227.1, 354.2 },
}
-- The offsets around each amp, in seconds. A value only reaches saved
-- variables once someone changes it, so anyone who leaves a default alone still
-- picks up a corrected one later rather than being frozen on today's guess.
NS.TIMER_DEFAULTS = {
    remindAtPull = 5,
    middleLead = 5,
    resolveAfter = 20,
    remindAfterClear = 5,
}
NS.TIMER_ORDER = { "remindAtPull", "middleLead", "resolveAfter", "remindAfterClear" }
-- Named for the mechanic each one belongs to, so the panel, the note under it
-- and the changelog all say "amp" for the same thing.
NS.TIMER_LABELS = {
    remindAtPull = "Tornado warning after pull",
    middleLead = "Amp warning lead",
    resolveAfter = "Clear set after amp",
    remindAfterClear = "Tornado warning after clear",
}

function NS.Timer(key)
    local v = SszorakMapHelperDB.timers and SszorakMapHelperDB.timers[key]
    return v or NS.TIMER_DEFAULTS[key]
end

function NS.SetTimer(key, v)
    if NS.TIMER_DEFAULTS[key] == nil then
        return
    end
    v = math.floor(tonumber(v) or -1)
    if v < 0 or v > 120 then
        return
    end
    SszorakMapHelperDB.timers = SszorakMapHelperDB.timers or {}
    SszorakMapHelperDB.timers[key] = (v ~= NS.TIMER_DEFAULTS[key]) and v or nil
    NS.Refresh()
end

-- There is only ever one thing worth saying at a time, so the line above the
-- placements is a single slot with a name in it rather than two labels taking
-- turns to hide each other.
local PROMPT_COLORS = {
    tornadoes = { 1, 0.15, 0.15 },
    middle = { 1, 0.75, 0.1 },
}
NS.PROMPT_DEFAULT_TEXT = {
    tornadoes = "LOOK FOR TORNADOES",
    middle = "RUN TO MIDDLE",
}
NS.PROMPT_ORDER = { "tornadoes", "middle" }
NS.PROMPT_LABELS = { tornadoes = "Tornado warning", middle = "Damage Amp warning" }

function NS.PromptText(key)
    local custom = SszorakMapHelperDB.promptText and SszorakMapHelperDB.promptText[key]
    return (custom and custom ~= "") and custom or NS.PROMPT_DEFAULT_TEXT[key]
end

-- Blank, or the same as the default, is stored as nothing at all. That is what
-- makes clearing the box a reset rather than a way to end up with no text.
function NS.SetPromptText(key, text)
    if NS.PROMPT_DEFAULT_TEXT[key] == nil then
        return
    end
    text = strtrim(text or "")
    SszorakMapHelperDB.promptText = SszorakMapHelperDB.promptText or {}
    SszorakMapHelperDB.promptText[key] = (text ~= "" and text ~= NS.PROMPT_DEFAULT_TEXT[key]) and text or nil
    NS.Refresh()
end

function NS.ResetAdvanced()
    SszorakMapHelperDB.promptText = nil
    SszorakMapHelperDB.timers = nil
    SszorakMapHelperDB.hidePrompt = false
    NS.Refresh()
end

local prompt -- key into PROMPT_COLORS, or nil for nothing to say
local timers = {}

-- What the line should read, or nothing. Looking for tornadoes stops being
-- true the moment all three are in, so a full set takes the prompt away
-- without anything having to time that. Being called to the middle is true
-- regardless of what you have clicked, so it outranks it.
function NS.Prompt()
    if SszorakMapHelperDB.hidePrompt then
        return nil
    end
    -- while placing the windows it shows one, so it can be positioned.
    -- Dev preview: add `and not NS.previewing` here to re-enable it.
    local key = prompt
    if NS.Positioning() then
        key = "tornadoes"
    elseif key == "tornadoes" and #calls >= NS.PLACEMENTS then
        key = nil
    end
    if not key then
        return nil
    end
    return { text = NS.PromptText(key), color = PROMPT_COLORS[key] }
end

local function setPrompt(key)
    prompt = key
    NS.Refresh()
end

local function stopSchedule()
    for _, t in ipairs(timers) do
        t:Cancel()
    end
    wipe(timers)
    prompt = nil
end

-- Timers exist only between ENCOUNTER_START and ENCOUNTER_END, so the addon is
-- still doing nothing at all outside a pull.
local function startSchedule(difficulty)
    stopSchedule()
    local function at(delay, fn)
        timers[#timers + 1] = C_Timer.NewTimer(delay, fn)
    end
    at(NS.Timer("remindAtPull"), function()
        setPrompt("tornadoes")
    end)
    local clearAt = NS.Timer("resolveAfter")
    for _, amp in ipairs(NS.AMP_TIMES[difficulty] or {}) do
        at(math.max(0, amp - NS.Timer("middleLead")), function()
            setPrompt("middle")
        end)
        at(amp + clearAt, function()
            wipe(calls)
            setPrompt(nil)
            if NS.Broadcast then
                -- the clear time is editable in the advanced panel, so raiders
                -- can have different values set and cannot be relied on to
                -- clear themselves at the same moment
                NS.Broadcast()
            end
        end)
        at(amp + clearAt + NS.Timer("remindAfterClear"), function()
            setPrompt("tornadoes")
        end)
    end
end

--#endregion

--#region Dev preview
-- DEV ONLY, and currently commented out. To bring it back:
--   1. delete the --[[ and ]] lines below
--   2. uncomment the "preview" branch in the slash handler
--   3. put `and not NS.previewing` back in NS.Prompt
-- All three are marked "Dev preview".
--
-- /sszmap preview steps through the states one press at a time, so each one can
-- be sat on and looked at, and the last press puts everything back.

--[[
NS.previewing = false
local previewWasPositioning
local previewAt = 0

-- false is the deliberate blank between messages, nil is the end of the cycle
local PREVIEW_CYCLE = { "tornadoes", "middle", false }

function NS.PreviewPrompts()
    if not NS.previewing then
        NS.previewing = true
        previewWasPositioning = NS.Positioning()
        NS.SetPositioning(true)
        previewAt = 0
    end
    previewAt = previewAt + 1
    local step = PREVIEW_CYCLE[previewAt]
    if step == nil then
        NS.previewing = false
        setPrompt(nil)
        NS.SetPositioning(previewWasPositioning)
        NS.Print("preview off, windows back as they were")
        return
    end
    setPrompt(step or nil)
    NS.Print(
        ("preview %d/%d: %s"):format(
            previewAt,
            #PREVIEW_CYCLE + 1,
            step and NS.PromptText(step) or "the gap, no text - press again to finish"
        )
    )
end
]]

--#endregion

--#region Window plumbing

NS.frames = {} -- pos key -> frame, so a rescale can re-anchor what it grew

-- which window each scale setting drives
local SCALE_POS = { paletteScale = "palette", callsScale = "board" }

local function reanchor(key)
    local frame = NS.frames[key]
    local pos = SszorakMapHelperDB.pos and SszorakMapHelperDB.pos[key]
    if not frame or not pos or not pos.point then
        return
    end
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
end

function NS.Scale(key)
    return SszorakMapHelperDB[key] or 1
end

function NS.SetScale(key, v)
    v = math.floor((tonumber(v) or 1) * 100 + 0.5) / 100
    if v < 0.6 or v > 2 then
        return
    end
    local old = SszorakMapHelperDB[key] or 1
    if old == v then
        return
    end
    SszorakMapHelperDB[key] = v
    -- A frame's own anchor offsets are measured in its scaled space, so
    -- growing one walks it across the screen as a side effect. Undoing that
    -- on the stored offsets by the same factor makes it grow where it sits.
    local posKey = SCALE_POS[key]
    local pos = posKey and SszorakMapHelperDB.pos and SszorakMapHelperDB.pos[posKey]
    if pos then
        pos.x = (pos.x or 0) * old / v
        pos.y = (pos.y or 0) * old / v
    end
    NS.Refresh()
    if posKey then
        reanchor(posKey)
    end
end

function NS.ResetPositions()
    SszorakMapHelperDB.pos = nil
    NS.Print("window positions cleared - they land back in the middle after a /reload")
end

-- Shared drag plumbing. Both windows move out of combat and sit still in it,
-- so nothing can be shoved off course by a stray click mid-pull.
function NS.MakeMovable(frame, key, point, x, y)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    NS.frames[key] = frame
    SszorakMapHelperDB.pos = SszorakMapHelperDB.pos or {}
    -- A window that has never been dragged still needs a stored position, or
    -- the first rescale has nothing to correct and drifts it anyway.
    local pos = SszorakMapHelperDB.pos[key]
    if not (pos and pos.point) then
        pos = { point = point or "CENTER", relPoint = point or "CENTER", x = x or 0, y = y or 0 }
        SszorakMapHelperDB.pos[key] = pos
    end
    frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    frame:SetScript("OnDragStart", function(f)
        if InCombatLockdown() or NS.IsLocked(key) then
            return
        end
        f:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local p, _, rp, px, py = f:GetPoint(1)
        SszorakMapHelperDB.pos = SszorakMapHelperDB.pos or {}
        SszorakMapHelperDB.pos[key] = { point = p, relPoint = rp, x = px, y = py }
    end)
end

--#endregion

--#region Events

local DEFAULTS = {
    hidePrompt = false,
    -- on by default, but it only does anything for a leader or an assist, so
    -- an ordinary raider running with it set has nothing happen either way
    share = true,
    fadeUnused = true,
    advancedOpen = false,
    paletteScale = 1,
    callsScale = 1,
}

-- At rest the addon listens to two events, both of which only fire when a boss
-- encounter begins or ends. Everything else is registered only while a window
-- is actually on screen, so outside the pull there is nothing to wake up: no
-- OnUpdate, no timers, no hooks, and nothing listening to ordinary combat.
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("ENCOUNTER_START")
f:RegisterEvent("ENCOUNTER_END")
f:RegisterEvent("PLAYER_ENTERING_WORLD")

-- The regen edges only matter while something is drawn: they flip the readout
-- to click-through and take the padlocks away. Left registered they would wake
-- the addon on every mob pulled anywhere in the world, for nothing.
local inRaid = false

-- PLAYER_TARGET_CHANGED fires on every target swap in the game, so it is only
-- worth hearing inside the one raid it means anything in.
local function syncZone()
    local _, _, _, _, _, _, _, instanceID = GetInstanceInfo()
    local here = instanceID == NS.INSTANCE_ID
    if here == inRaid then
        return
    end
    inRaid = here
    if here then
        f:RegisterEvent("PLAYER_TARGET_CHANGED")
    else
        f:UnregisterEvent("PLAYER_TARGET_CHANGED")
        if targeting then
            targeting = false
            NS.Refresh()
        end
    end
end

local regenOn = false

function NS.SyncEvents()
    local want = NS.Visible()
    if want == regenOn then
        return
    end
    regenOn = want
    if want then
        f:RegisterEvent("PLAYER_REGEN_DISABLED")
        f:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        f:UnregisterEvent("PLAYER_REGEN_DISABLED")
        f:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
end

f:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= ADDON then
            return
        end
        SszorakMapHelperDB = SszorakMapHelperDB or {}
        for k, v in pairs(DEFAULTS) do
            if SszorakMapHelperDB[k] == nil then
                SszorakMapHelperDB[k] = v
            end
        end
        if type(SszorakMapHelperDB.layout) == "table" then
            for _, sector in ipairs(NS.SECTORS) do
                if not NS.DEAD[sector] and SszorakMapHelperDB.layout[sector] == nil then
                    SszorakMapHelperDB.layout[sector] = DEFAULT_LAYOUT[sector]
                end
            end
        end
        if not layoutValid(SszorakMapHelperDB.layout) then
            SszorakMapHelperDB.layout = copyLayout(DEFAULT_LAYOUT)
        end
        -- settings that earlier versions saved and this one no longer has
        for _, dead in ipairs({ "maxCalls", "shown", "positioning", "poleMarkers", "hideUnused" }) do
            SszorakMapHelperDB[dead] = nil
        end
        -- locking used to be one flag for both windows and is now one per
        -- window, so an old saved boolean is carried across rather than lost
        if SszorakMapHelperDB.locks == nil then
            local was = SszorakMapHelperDB.locked and true or nil
            SszorakMapHelperDB.locks = { palette = was, board = was }
        end
        SszorakMapHelperDB.locked = nil
        -- fires once per addon in the load order, and ours has now had its
        -- turn, so stop hearing about everyone else's
        f:UnregisterEvent("ADDON_LOADED")
        -- A fresh install deliberately puts nothing on screen, which without a
        -- word is indistinguishable from an addon that failed to install. One
        -- chat line, once ever, fixes that without taking over the screen.
        -- Registered only while the greeting is owed and dropped as soon as it
        -- is said, so a returning user never carries the cost.
        if not SszorakMapHelperDB.greeted then
            f:RegisterEvent("PLAYER_LOGIN")
        end
        -- the windows build themselves on their first refresh, so nothing
        -- here has to run in a particular file order
        NS.Refresh()
    elseif event == "PLAYER_LOGIN" then
        f:UnregisterEvent("PLAYER_LOGIN")
        SszorakMapHelperDB.greeted = true
        NS.Print("loaded. The windows only appear during a Sszorak pull - type /sszmap to place them first.")
    elseif event == "PLAYER_ENTERING_WORLD" then
        syncZone()
    elseif event == "PLAYER_TARGET_CHANGED" then
        local was = targeting
        targeting = targetingBoss()
        if targeting ~= was then
            NS.Refresh()
        end
    elseif event == "ENCOUNTER_START" then
        local id, _, difficulty = ...
        if id ~= NS.ENCOUNTER_ID or not NS.DIFFICULTIES[difficulty] then
            return
        end
        active = true
        wipe(calls)
        startSchedule(difficulty)
        NS.Refresh()
    elseif event == "ENCOUNTER_END" then
        local id = ...
        if id ~= NS.ENCOUNTER_ID then
            return
        end
        active = false
        wipe(calls)
        stopSchedule()
        NS.Refresh()
    else
        -- combat edges: the readout stops taking the mouse, the palette keeps it
        NS.Refresh()
    end
end)

--#endregion

SLASH_SSZORAKHELPER1 = "/sszmap"
SLASH_SSZORAKHELPER2 = "/ssz"
SLASH_SSZORAKHELPER3 = "/ao"
SLASH_SSZORAKHELPER4 = "/sszorak"
SlashCmdList["SSZORAKHELPER"] = function(msg)
    local cmd = (msg or ""):match("^(%S*)")
    cmd = cmd:lower()
    if cmd == "" or cmd == "options" or cmd == "opt" then
        NS.ToggleOptions()
    elseif cmd == "clear" then
        wipe(calls)
        NS.CallsChanged()
        NS.Print("placements cleared")
    elseif cmd == "undo" then
        NS.Undo()
    elseif cmd == "place" then
        NS.SetPositioning(not NS.Positioning())
        NS.Print("positioning mode " .. (NS.Positioning() and "ON - drag the windows where you want them" or "OFF"))
    -- Dev preview:
    -- elseif cmd == "preview" then
    --     NS.PreviewPrompts()
    elseif cmd == "lock" then
        local v = not NS.AllLocked()
        NS.SetAllLocked(v)
        NS.Print("both windows " .. (v and "locked" or "unlocked"))
    elseif cmd == "bagbagbag" then
        NS.Bear()
    elseif cmd == "reset" then
        NS.ResetPositions()
        NS.ResetLayout()
    else
        NS.Print("commands:")
        print("  /sszmap           - open the options")
        print("  /sszmap place     - show the windows anywhere so they can be dragged")
        print("  /sszmap lock      - stop the windows being dragged")
        print("  /sszmap clear     - drop the recorded placements")
        print("  /sszmap reset     - default layout and window positions")
    end
end
