-- SimpleStyle v2: GAME -> RESULT. The house shutter wipe (SSM.shutter, polish_meta): after a short
-- hold the sky shutters drop in 3 column groups (50 ms steps), then roll up over the card. While solid (the engine holds the transition until the
-- result screen is ready, ~1.5 s) the house scene shows a paper dialog with the gold title band
-- (16U, 1U ink rule, 36 px ink せいせき はっぴょう) opening in 3 frames, three dots stepping in, and
-- Momo / Hoshi (scene k) on the grass hopping on a hard 2-frame bob in opposite phase. Hard steps
-- only, no alpha. Same for 1P, 2P and dan results (one transition object per screen).
local SSM = require("global.ss_meta")
local UI = SSM.UI
local D = UI.D
local U = D.U

ResultTransition = {}
ResultTransition.__index = ResultTransition

local HOLD_MS, STEP = 600, 50
local DX, DY, DW, DH = 600, 330, 720, 210        -- dialog (ends y 540, above the cast's heads)
local BAND_H = 16 * U
local GROUND = 1032                               -- the scene's grass line (ss_meta/scene)
local MOMO_X, HOSHI_X = 780, 1140
local BOB_MS = 200                                -- 2-frame bob: down / up every 200 ms
local DOT_MS = 300

function ResultTransition.new(player_num)
    local self = setmetatable({}, ResultTransition)
    self.player_num = player_num
    self.t0 = nil
    self.now = 0
    self.level = 0
    self.solid_ms = nil
    self.started = false
    UI.reset()
    self.momo = UI.Mascot.new({ role = "scene", beat = false })
    self.hoshi = UI.Mascot.new({ role = "scene", beat = false, buddy = true })
    self.title = UI.text_key("result_title", 36)
    self.dot = UI.text_key("dot", 36)
    return self
end

function ResultTransition:start()
    self.t0 = nil
    self.level = 0
    self.solid_ms = nil
    self.started = true
end

function ResultTransition:update(current_ms)
    if not self.started then return end
    if not self.t0 then self.t0 = current_ms end
    self.now = current_ms
    self.level = UI.wipe_in(current_ms - self.t0 - HOLD_MS - STEP, STEP)   -- 4 once the shutters are closed (200 ms)
    if self.level >= 4 and not self.solid_ms then self.solid_ms = current_ms end
    self.momo:update(current_ms)
    self.hoshi:update(current_ms)
end

function ResultTransition:is_finished()
    return self.started and self.level >= 4
end

function ResultTransition:draw_card()
    local e = self.now - self.solid_ms
    local scene = SSM.T("scene")
    if scene then tex.draw_texture(scene, { x = 0, y = 0 }) else UI.rect(0, 0, 1920, 1080, D.P.sky) end
    -- the cast: hard 2-frame bob (1 sprite px), opposite phase, cheer frame on the up step
    local up = math.floor(e / BOB_MS) % 2 == 1
    local k = D.MASCOT.k.scene
    self.momo:draw(MOMO_X, GROUND - (up and k or 0), { still = true, expr = up and "cheer" or "idle" })
    self.hoshi:draw(HOSHI_X, GROUND - (up and 0 or k),
                    { still = true, expr = up and "idle" or "cheer", mirror = true })
    -- the dialog: 3-frame window open, then band + title + stepping dots
    local x, y, w, h, full = UI.open_rect(DX, DY, DW, DH, e - SSM.SHUTTER_MS + 50)
    if not x then SSM.shutter(e, "out"); return end
    local ix, iy, iw, ih = UI.chrome.dialog(x, y, w, h)
    if not full then SSM.shutter(e, "out"); return end
    UI.rect(ix, iy, iw, BAND_H, D.P.focus)
    UI.rect(ix, iy + BAND_H, iw, U, D.P.ink)
    UI.draw_text(self.title, 960, iy + BAND_H / 2, "c")
    local n = math.floor((e - SSM.SHUTTER_MS - 100) / DOT_MS) % 4
    if n < 0 then n = 0 end
    local cy = math.floor((iy + BAND_H + U + iy + ih) / 2)
    for i = 1, 3 do
        if i <= n then UI.draw_text(self.dot, 960 + (i - 2) * 48, cy, "c") end
    end
end

function ResultTransition:draw()
    if self.solid_ms then
        self:draw_card()
        return
    end
    -- the house shutters drop over the game (polish_meta: was the checker dither)
    if self.t0 then SSM.shutter(self.now - self.t0 - HOLD_MS, "in") end
end

return ResultTransition
