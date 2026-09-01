local ADDON, NS = ...

-- Sharing the board with the rest of the raid.
--
-- No comms library on purpose. The entire payload is a handful of digits,
-- nowhere near the 255 byte cap on a single addon message, so the chunking and
-- serialisation a library exists to provide would buy nothing and cost four
-- embedded libraries in an addon that currently has none.
--
-- Every message carries the COMPLETE state rather than an operation. There is
-- no "undo" or "clear" on the wire, only the set as it now stands. That makes
-- each message idempotent: a duplicate changes nothing, and a dropped one is
-- repaired by the next one instead of leaving that raider permanently a step
-- out from everyone else.

local PREFIX = "SSZMAP" -- addon message prefixes cap at 16 characters
local PROTOCOL = 1 -- only bumped if the wire format itself changes

--#region wire format

-- All eight sectors in NS.SECTORS order, one digit each: "38456712". Both ends
-- walk the same table to get the same order, so the two cannot disagree about
-- which digit belongs to which sector.
--
-- North and south travel whether or not the receiver draws them. Sending only
-- the live sectors would make the message length depend on a personal display
-- setting, so a sender with the poles switched on and a receiver with them off
-- would disagree about what every digit meant.
local function encodeLayout()
    local out = {}
    for _, sector in ipairs(NS.SECTORS) do
        -- 0 is an empty sector, which only north and south can be
        out[#out + 1] = NS.MarkAt(sector) or 0
    end
    return table.concat(out)
end

local function decodeLayout(body)
    if #body ~= #NS.SECTORS then
        return nil
    end
    local out = {}
    for i, sector in ipairs(NS.SECTORS) do
        local mark = tonumber(body:sub(i, i))
        -- eight digits, each a real marker or an empty dead sector, or the
        -- whole thing is rejected. This is untrusted input off the wire, not
        -- our own saved config.
        if not mark or mark < 0 or mark > 8 then
            return nil
        end
        if mark == 0 then
            if not NS.DEAD[sector] then
                return nil
            end
        else
            out[sector] = mark
        end
    end
    return out
end

-- The recorded set, in call order: "462". An empty string is a legitimate
-- message and means the set is now empty, which is how clear and the last undo
-- travel.
local function encodeCalls()
    return table.concat(NS.Calls())
end

local function decodeCalls(body)
    if #body > NS.PLACEMENTS then
        return nil
    end
    local out = {}
    for i = 1, #body do
        local mark = tonumber(body:sub(i, i))
        if not mark or mark < 1 or mark > 8 then
            return nil
        end
        out[i] = mark
    end
    return out
end

--#endregion

--#region sending

-- A group formed through the group finder is not reachable on "RAID", which is
-- the usual way this breaks for pug raids and never for guild ones.
local function groupChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    elseif IsInRaid() then
        return "RAID"
    elseif IsInGroup() then
        return "PARTY"
    end
end

local function lead(unit)
    return UnitIsGroupLeader(unit) or UnitIsGroupAssistant(unit)
end

-- Where anything is allowed to go out, or nil with the reason, so the button
-- can say why it did nothing instead of failing quietly.
local function outbound()
    if not SszorakMapHelperDB.share then
        return nil, "sharing is switched off in the options"
    end
    local chan = groupChannel()
    if not chan then
        return nil, "you are not in a group"
    end
    if not lead("player") then
        return nil, "only the raid leader and assists can send"
    end
    return chan
end

local function send(kind, body)
    local chan = outbound()
    if chan then
        C_ChatInfo.SendAddonMessage(PREFIX, ("%d|%s|%s"):format(PROTOCOL, kind, body), chan)
    end
    return chan
end

-- Called by Core whenever the recorded set changes, for any reason at all:
-- a click, an undo, the Clear button, or the timer clearing it after the amp.
-- Everything funnels through one place so no path can forget to send.
function NS.Broadcast()
    send("P", encodeCalls())
end

-- The layout is pushed by hand, never automatically. Someone who has set up a
-- custom marker config has a reason for it, and replacing it silently the
-- moment they join a raid would be a genuinely nasty surprise.
function NS.PushLayout()
    local chan, why = outbound()
    if not chan then
        return NS.Print("layout not sent - " .. why)
    end
    send("L", encodeLayout())
    NS.Print("marker layout sent to the group")
end

--#endregion

--#region receiving

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_ADDON")

f:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        -- Until this is registered the event never fires at all, silently, so
        -- it has to happen for everyone rather than only for senders.
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        return
    end

    local prefix, text, _, sender = ...
    if prefix ~= PREFIX or not sender then
        return
    end
    -- your own sends come back to you like anyone else's
    if UnitIsUnit("player", sender) then
        return
    end
    if not lead(sender) then
        return
    end

    local kind, body = text:match("^%d+|(%a)|(.*)$")
    if kind == "P" then
        local incoming = decodeCalls(body)
        if incoming then
            NS.SetCalls(incoming)
        end
    elseif kind == "L" then
        local incoming = decodeLayout(body)
        if incoming then
            SszorakMapHelperDB.layout = incoming
            NS.Refresh()
            NS.Print(("%s set the marker layout - Reset markers in /sszmap puts yours back"):format(sender))
        end
    end
end)

--#endregion
