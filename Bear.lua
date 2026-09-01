local ADDON, NS = ...

-- A bear, rolling. Nothing here touches the fight.
--
-- The game cannot read a gif or a webp and has no animated texture type, so
-- the animation is a sprite sheet: 24 frames laid out in an 8x3 grid on one
-- 512x256 tga, and a ticker that walks SetTexCoord across the cells at the
-- source's own 10 fps. The sheet is padded to a power of two, which is why
-- the bottom quarter of it is empty.

local TEX = ("Interface\\AddOns\\%s\\Media\\RollingBear.tga"):format(ADDON)
local SHEET_W, SHEET_H = 512, 256
local CELL, COLS, FRAMES = 64, 8, 24
local RATE = 0.1     -- seconds per frame, matching the source
local LOOPS = 2      -- brief is the whole joke
local SIZE = 192     -- on-screen size, upscaled from the 64px cells

local frame, tex, ticker, shown

local function build()
    frame = CreateFrame("Frame", "SszorakMapHelperBear", UIParent)
    frame:SetSize(SIZE, SIZE)
    frame:SetPoint("CENTER", 0, 120)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:EnableMouse(false)  -- never in the way of a click, even mid-pull
    frame:Hide()

    tex = frame:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture(TEX)
end

-- cell n (zero based) as texture coordinates on the padded sheet
local function setFrame(n)
    local col, row = n % COLS, math.floor(n / COLS)
    tex:SetTexCoord(
        col * CELL / SHEET_W, (col + 1) * CELL / SHEET_W,
        row * CELL / SHEET_H, (row + 1) * CELL / SHEET_H)
end

local function stop()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
    shown = false
end

function NS.Bear()
    if not frame then
        build()
    end
    -- a second press restarts the roll rather than stacking another ticker,
    -- and has to call off any fade already in flight or the restarted bear
    -- would keep fading out under it
    stop()
    UIFrameFadeRemoveFrame(frame)

    local n = 0
    setFrame(0)
    frame:SetAlpha(1)
    frame:Show()
    shown = true

    ticker = C_Timer.NewTicker(RATE, function()
        n = n + 1
        if n >= FRAMES * LOOPS then
            stop()
            UIFrameFadeOut(frame, 0.4, 1, 0)
            C_Timer.After(0.4, function()
                if not shown then  -- unless it has been started again since
                    frame:Hide()
                end
            end)
            return
        end
        setFrame(n % FRAMES)
    end)
end
