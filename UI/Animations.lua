--[[
    GoldLedger: UI_Animations.lua
    Animation helpers: fade, slide, chart bar grow
]]

local ADDON_NAME, ns = ...

local Anim = {}

-------------------------------------------------------------------------------
-- FadeIn: frame fades from 0 to target alpha
-------------------------------------------------------------------------------
function Anim.FadeIn(frame, duration, delay, targetAlpha)
    if not frame then return end
    duration = duration or 0.25
    delay = delay or 0
    targetAlpha = targetAlpha or 1

    frame:SetAlpha(0)

    local ag = frame._glFadeIn
    if not ag then
        ag = frame:CreateAnimationGroup()
        local a = ag:CreateAnimation("Alpha")
        a:SetFromAlpha(0)
        a:SetToAlpha(1)
        ag._alpha = a
        ag:SetScript("OnFinished", function()
            frame:SetAlpha(ag._targetAlpha or 1)
        end)
        frame._glFadeIn = ag
    end

    ag:Stop()
    ag._targetAlpha = targetAlpha
    ag._alpha:SetFromAlpha(0)
    ag._alpha:SetToAlpha(targetAlpha)
    ag._alpha:SetDuration(duration)
    ag._alpha:SetStartDelay(delay)
    ag._alpha:SetSmoothing("OUT")
    ag:Play()
end

-------------------------------------------------------------------------------
-- SlideIn: frame slides down from offset and fades in simultaneously
-------------------------------------------------------------------------------
function Anim.SlideIn(frame, duration, delay, offsetY)
    if not frame then return end
    duration = duration or 0.3
    delay = delay or 0
    offsetY = offsetY or 20

    frame:SetAlpha(0)

    local ag = frame._glSlideIn
    if not ag then
        ag = frame:CreateAnimationGroup()

        local move = ag:CreateAnimation("Translation")
        ag._move = move

        local fade = ag:CreateAnimation("Alpha")
        ag._fade = fade

        ag:SetScript("OnPlay", function()
            frame:SetAlpha(0)
        end)
        ag:SetScript("OnFinished", function()
            frame:SetAlpha(1)
        end)

        frame._glSlideIn = ag
    end

    ag:Stop()

    ag._move:SetOffset(0, -offsetY)
    ag._move:SetDuration(duration)
    ag._move:SetStartDelay(delay)
    ag._move:SetSmoothing("OUT")

    ag._fade:SetFromAlpha(0)
    ag._fade:SetToAlpha(1)
    ag._fade:SetDuration(duration)
    ag._fade:SetStartDelay(delay)
    ag._fade:SetSmoothing("OUT")

    frame:SetAlpha(0)
    ag:Play()
end

-------------------------------------------------------------------------------
-- Bar grow animation system
-- Uses a single ticker frame to animate texture heights
-------------------------------------------------------------------------------
local barGrowEntries = {}
local barGrowTicker

local function BarGrowOnUpdate(self, dt)
    local allDone = true
    for i = #barGrowEntries, 1, -1 do
        local e = barGrowEntries[i]
        e.elapsed = e.elapsed + dt
        if e.elapsed < 0 then
            e.texture:SetHeight(0.1)
            allDone = false
        else
            local progress = math.min(e.elapsed / e.duration, 1)
            -- ease out quad
            local eased = 1 - (1 - progress) * (1 - progress)
            e.texture:SetHeight(math.max(0.1, e.targetHeight * eased))
            if progress >= 1 then
                e.texture:SetHeight(e.targetHeight)
                table.remove(barGrowEntries, i)
            else
                allDone = false
            end
        end
    end
    if allDone then
        self:Hide()
    end
end

-------------------------------------------------------------------------------
-- GrowBar: texture grows from 0 height to target height (for chart bars)
-------------------------------------------------------------------------------
function Anim.GrowBar(texture, targetHeight, duration, delay)
    if not texture or targetHeight <= 0 then return end
    duration = duration or 0.4
    delay = delay or 0

    texture:SetHeight(0.1)

    -- remove any existing entry for this texture
    for i = #barGrowEntries, 1, -1 do
        if barGrowEntries[i].texture == texture then
            table.remove(barGrowEntries, i)
        end
    end

    barGrowEntries[#barGrowEntries + 1] = {
        texture = texture,
        targetHeight = targetHeight,
        duration = duration,
        elapsed = -delay,
    }

    -- lazy-create ticker frame
    if not barGrowTicker then
        barGrowTicker = CreateFrame("Frame")
        barGrowTicker:SetScript("OnUpdate", BarGrowOnUpdate)
    end
    barGrowTicker:Show()
end

-------------------------------------------------------------------------------
-- ClearBarAnimations: cancel all pending bar grow animations
-------------------------------------------------------------------------------
function Anim.ClearBarAnimations()
    wipe(barGrowEntries)
    if barGrowTicker then
        barGrowTicker:Hide()
    end
end

-------------------------------------------------------------------------------
-- Export
-------------------------------------------------------------------------------
ns.UI_Animations = Anim
