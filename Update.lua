local addonName, ns = ...

-- A newer version out? Each copy tells others which version it is, in an addon
-- message never seen in chat:
--   the guild, at login;
--   the group, at login and on joining one (a dungeon finder group in its own chat);
--   Battle.net friends playing WoW Forever in this region, at login.
-- Hearing a newer one opens News.Newer, once a session. Hearing an older one, it
-- answers on that channel a moment later, or to that friend once a session.
--
-- Nothing goes out in a fight or a chat lockdown (boss fights, keystones, PvP). A
-- held message goes once the fight ends or the lockdown lifts.
-- Forever answers true to AreOutgoingAddonChatMessagesRestricted on its live realms,
-- and guild and group addon messages still carry there, so that answer holds nothing
-- back. The send's own result says what happened: a lockdown (11) or a throttle (3, 8)
-- holds the message for later.
-- Custom channels are never used: Forever's servers refuse addon messages on them.
-- A secret payload is never read. With the "Newer Version Notice" switch off,
-- nothing is sent or heard.

local Update = {}
ns.Update = Update

Update.PREFIX = "EZ-CDM"
Update.GAP = 60
Update.FRIENDS_MAX = 10

local function on() return ns.Settings.Get("updateCheck") ~= false end

-- ---------------------------------------------------------------------
-- Versions
-- ---------------------------------------------------------------------

-- "1.6.11" (a tag's "v1.6.11" too) as { 1, 6, 11 }; nil for anything else.
local function parts(v)
    if type(v) ~= "string" then return nil end
    local a, b, c = v:match("^v?(%d+)%.(%d+)%.(%d+)$")
    if a then return { tonumber(a), tonumber(b), tonumber(c) } end
end

-- Whether version a is newer than b. False when either isn't a version.
function Update.Newer(a, b)
    local x, y = parts(a), parts(b)
    if not (x and y) then return false end
    for i = 1, 3 do
        if x[i] ~= y[i] then return x[i] > y[i] end
    end
    return false
end

local mine = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version")
mine = parts(mine) and (mine:gsub("^v", "")) or nil

-- This copy's version, or nil for a copy without one.
function Update.Version() return mine end

local function plain(...)
    local secret = _G.issecretvalue
    if not secret then return true end
    for i = 1, select("#", ...) do
        if secret((select(i, ...))) then return false end
    end
    return true
end

-- ---------------------------------------------------------------------
-- Sending
-- ---------------------------------------------------------------------

local LATER = { [3] = true, [8] = true, [11] = true }

local function blocked()
    if InCombatLockdown() then return true end
    local Chat = C_ChatInfo
    return Chat and Chat.InChatMessagingLockdown and Chat.InChatMessagingLockdown() == true or false
end

local sentAt, held = {}, {}
local toldFriend, heldFriend = {}, {}

-- Tells one channel this copy's version, at most once a minute.
function Update.Say(channel)
    if not (channel and mine) or not on() then return end
    if blocked() then
        held[channel] = true
        return
    end
    local now = GetTime()
    if sentAt[channel] and now - sentAt[channel] < Update.GAP then return end
    if LATER[C_ChatInfo.SendAddonMessage(Update.PREFIX, "V:" .. mine, channel)] then
        held[channel] = true
        return
    end
    sentAt[channel] = now
end

-- Tells one Battle.net friend's game, once a session.
function Update.TellFriend(id)
    if not (id and mine) or not on() or toldFriend[id] then return end
    if blocked() then
        heldFriend[id] = true
        return
    end
    if LATER[C_BattleNet.SendGameData(id, Update.PREFIX, "V:" .. mine)] then
        heldFriend[id] = true
        return
    end
    toldFriend[id] = true
end

-- The game accounts of Battle.net friends playing WoW Forever in this region now,
-- at most FRIENDS_MAX.
function Update.Friends()
    local out = {}
    local BN = C_BattleNet
    if not (BN and BN.GetFriendNumGameAccounts and BN.GetFriendGameAccountInfo and BN.SendGameData) then return out end
    if type(BNGetNumFriends) ~= "function" then return out end
    if type(BNFeaturesEnabledAndConnected) == "function" and not BNFeaturesEnabledAndConnected() then return out end
    for friend = 1, BNGetNumFriends() or 0 do
        for game = 1, BN.GetFriendNumGameAccounts(friend) or 0 do
            local info = BN.GetFriendGameAccountInfo(friend, game)
            if info and plain(info.gameAccountID, info.isOnline, info.clientProgram, info.wowProjectID,
                    info.isInCurrentRegion)
                and info.isOnline and info.isInCurrentRegion and info.clientProgram == BNET_CLIENT_WOW
                and info.wowProjectID == WOW_PROJECT_ID then
                out[#out + 1] = info.gameAccountID
                break
            end
        end
        if #out >= Update.FRIENDS_MAX then break end
    end
    return out
end

function Update.TellFriends()
    if not on() then return end
    for _, id in ipairs(Update.Friends()) do Update.TellFriend(id) end
end

-- The group's channel: a raid, a party, or a dungeon finder group's own chat.
function Update.GroupChannel()
    local inst, home = LE_PARTY_CATEGORY_INSTANCE, LE_PARTY_CATEGORY_HOME
    if IsInRaid() then
        return (inst and IsInRaid(inst) and not IsInRaid(home)) and "INSTANCE_CHAT" or "RAID"
    end
    if IsInGroup() then
        return (inst and IsInGroup(inst) and not IsInGroup(home)) and "INSTANCE_CHAT" or "PARTY"
    end
end

-- Sends what a fight or a lockdown held.
local function release()
    if blocked() then return end
    for channel in pairs(held) do
        held[channel] = nil
        Update.Say(channel)
    end
    for id in pairs(heldFriend) do
        heldFriend[id] = nil
        Update.TellFriend(id)
    end
end

-- ---------------------------------------------------------------------
-- Hearing
-- ---------------------------------------------------------------------

local ANSWER = { GUILD = true, PARTY = true, RAID = true, INSTANCE_CHAT = true }
local answeredFriend = {}

-- The version in a message of ours, or nil.
local function heardVersion(prefix, text)
    if prefix ~= Update.PREFIX or type(text) ~= "string" or not mine or not on() then return nil end
    return text:match("^V:(%d+%.%d+%.%d+)$")
end

-- A moment later, so a whole guild or group doesn't answer at once.
local function soon(fn) C_Timer.After(1 + math.random() * 4, fn) end

-- One addon message heard (CHAT_MSG_ADDON's prefix, text, channel, sender).
function Update.Heard(prefix, text, channel)
    if not plain(prefix, text, channel) then return end
    local v = heardVersion(prefix, text)
    if not v then return end
    if Update.Newer(v, mine) then
        ns.News.Newer(v)
    elseif Update.Newer(mine, v) and ANSWER[channel] then
        soon(function() Update.Say(channel) end)
    end
end

-- One message from a Battle.net friend's game (BN_CHAT_MSG_ADDON's prefix, text,
-- channel, sender's game account).
function Update.HeardFriend(prefix, text, _, id)
    if not plain(prefix, text, id) then return end
    local v = heardVersion(prefix, text)
    if not v then return end
    if Update.Newer(v, mine) then
        ns.News.Newer(v)
    elseif Update.Newer(mine, v) and id and not answeredFriend[id] then
        answeredFriend[id] = true
        toldFriend[id] = nil
        soon(function() Update.TellFriend(id) end)
    end
end

-- ---------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------

local grouped = false
local f = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
    "ADDON_RESTRICTION_STATE_CHANGED", "CHAT_MSG_ADDON", "BN_CHAT_MSG_ADDON" }) do
    f:RegisterEvent(event)
end
f:SetScript("OnEvent", function(_, event, a, b, c, d)
    if event == "CHAT_MSG_ADDON" then
        Update.Heard(a, b, c, d)
    elseif event == "BN_CHAT_MSG_ADDON" then
        Update.HeardFriend(a, b, c, d)
    elseif event == "PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(Update.PREFIX)
        end
        C_Timer.After(15, function()
            if IsInGuild and IsInGuild() then Update.Say("GUILD") end
            Update.Say(Update.GroupChannel())
            Update.TellFriends()
        end)
    elseif event == "GROUP_ROSTER_UPDATE" then
        local now = Update.GroupChannel() ~= nil
        if now and not grouped then C_Timer.After(3, function() Update.Say(Update.GroupChannel()) end) end
        grouped = now
    else
        release()
    end
end)
