KinotakeIndicator = {}
KinotakeIndicator.__index = KinotakeIndicator

local S = tex.get_screen_scale()
local DIR = "global/kinotake_indicator"
local ENTRY_DX, ENTRY_DY = -507, -560.65 -- "entry" layout (top centre) from the "attract" one (bottom right)
local PILL_X, PILL_Y = 1214, 594.65      -- VS pill centre (attract)
local SPARKLES = { [0] = { { -10.25, -16.55 }, { -50.7, 9.1 } }, [1] = { { 15, -15.55 }, { 49.55, 9.1 } } }
local PULSE_MS = 667

-- mode: "attract" | "entry"
function KinotakeIndicator.new(mode)
    local self = setmetatable({}, KinotakeIndicator)
    self.dx, self.dy = 0, 0
    if mode == "entry" then self.dx, self.dy = ENTRY_DX, ENTRY_DY end
    self.tex = {}
    for _, key in ipairs({ "panel", "vs_even", "vs_kinoko", "vs_takenoko", "sparkle", "assist" }) do
        local id = tex.get_texture(DIR .. "/" .. key) -- loads the folder, so before the info lookup
        local info = tex.get_texture_info(DIR:match("[^/]+$"), key) -- textures are keyed by their own folder
        self.tex[key] = { id = id, w = info and info.x2[1] or 0,
                          h = info and info.y2[1] or 0 }
    end
    self.leader = -1
    self.assist = -1
    self.now = 0
    return self
end

-- leader: 0 kinoko, 1 takenoko, -1 even; assist: badge frame (team * 4 + rate - 2) or -1
function KinotakeIndicator:set(leader, assist)
    self.leader, self.assist = leader, assist
end

function KinotakeIndicator:update(current_ms) self.now = current_ms end

function KinotakeIndicator:draw(fade)
    fade = fade or 1
    local tx = self.tex
    local dx, dy = self.dx * S, self.dy * S
    tex.draw_texture(tx.panel.id, { x = dx, y = dy, fade = fade })
    local pill = self.leader == 0 and tx.vs_kinoko or self.leader == 1 and tx.vs_takenoko or tx.vs_even
    tex.draw_texture(pill.id, { x = dx, y = dy, fade = fade })
    -- two sparkles on the leader's half breathe out of step (0.6 <-> 1)
    for i, p in ipairs(SPARKLES[self.leader] or {}) do
        local u = (self.now % PULSE_MS) / PULSE_MS
        local k = u < 0.5 and u * 2 or 2 - u * 2
        if i == 2 then k = 1 - k end
        local s = 0.6 + 0.4 * k
        local w, h = tx.sparkle.w * s, tx.sparkle.h * s
        tex.draw_texture(tx.sparkle.id, {
            x = (PILL_X + p[1] + self.dx) * S - w / 2, y = (PILL_Y + p[2] + self.dy) * S - h / 2,
            x2 = w - tx.sparkle.w, y2 = h - tx.sparkle.h, fade = fade,
        })
    end
    if self.assist >= 0 then tex.draw_texture(tx.assist.id, { x = dx, y = dy, frame = self.assist, fade = fade }) end
end
