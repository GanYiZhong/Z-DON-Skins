local anim = require("anim/sampler")
local UI = require("global.ss_ui")   -- SimpleStyle: UI.solid
local CLIP = anim.safe("anim/dani_intro")

local M = {}

local SCREEN_W, SCREEN_H = 1920, 1080
local DOOR_W = 1200      -- door panel local width (main__shape5)
local KANJI  = 400       -- each kanji cell is 400x400 (main__shape7/9/11/13)

local SCRIM_SRC = { x = 1200, y = 800, width = 64, height = 64 }

local CELLS = {
    { track = "#7@4",  sx = 1200, sy = 0   },  -- 段
    { track = "#9@5",  sx = 1600, sy = 0   },  -- 位
    { track = "#11@6", sx = 1200, sy = 400 },  -- 道
    { track = "#13@7", sx = 1600, sy = 400 },  -- 場
}

local CLOSE_POSE  = 62       -- shut doors, scrim already eased to 0.5
local STAMP_FROM  = 62       -- the arcade's scrim has just settled to 0.5
local STAMP_TO    = 182      -- all four landed, before the fade
local OPEN_FROM   = 182      -- kanji fade (182-185), doors part (187-200),
local OPEN_TO     = 262      -- scrim clears (203), bg push-in + `out` fade

local MS_PER_FRAME = 1000.0 / 60.0

local CLOSE_MS = 300.0
local STAMP_MS = (STAMP_TO - STAMP_FROM) * MS_PER_FRAME   -- 120 frames = 2000 ms
local OPEN_MS  = (OPEN_TO - OPEN_FROM)   * MS_PER_FRAME   -- 80 frames  = 1333 ms

local DURATION_MS = 2300.0
local function duration_ms() return DURATION_MS end

local FB_SCRIM = 0.5   -- #1@3's settled alpha (f62..193 in the arcade data)

local function clamp01(v) return math.max(0.0, math.min(1.0, v)) end

local function clip() return CLIP end

local _id, _id_tried
local function tex_id()
    if not _id_tried then
        _id_tried = true
        _id = tex.get_texture("song_select/dan_transition/background")
    end
    return _id
end

local _bg, _bg_tried
local function bg_id()
    if not _bg_tried then
        _bg_tried = true
        _bg = tex.get_texture("dan_select/global/bg")
    end
    return _bg
end

local function fallback_door()
    return -240, 960, DOOR_W, 0, FB_SCRIM
end

local function fallback_kanji(i, shown)
    if not shown or shown <= 0 then return nil end
    return 1.0, 1.0   -- scale 1, alpha 1 — the landed pose, nothing finer is recoverable
end

local function fire_sfx()
    if M.sfx_done then return end
    if audio and audio.play_sound then audio.play_sound("dan_intro", "sound") end
    M.sfx_done = true
end

local function phases()
    local d = duration_ms()
    local move = CLOSE_MS + STAMP_MS
    local k = (d >= move) and 1.0 or (d / move)      -- compress only if we must
    local c = CLOSE_MS * k
    local st = STAMP_MS * k
    return c / d, (c + st) / d
end

-- u (0..1 across our transition) -> arcade frame.
local function frame_of(u)
    local close_u, stamp_u = phases()
    if u <= close_u then
        return CLOSE_POSE
    elseif u <= stamp_u then
        local v = (u - close_u) / (stamp_u - close_u)
        return STAMP_FROM + (STAMP_TO - STAMP_FROM) * v
    end
    return STAMP_TO                                  -- parked: doors shut, kanji up
end

local function draw_frame(f, op)
    local id = tex_id()
    if not id then return false end
    local c = clip()
    op = (op == nil) and 1.0 or clamp01(op)
    if op <= 0 then return true end

    local btx, bty, bsx, _, ba = c:at("#3@0", f)
    if btx and ba and ba > 0 then
        local bid = bg_id()
        if bid then
            local w, h = SCREEN_W * (bsx or 1), SCREEN_H * (bsx or 1)
            tex.draw_texture(bid, {
                x = (btx or 960) - w * 0.5, y = (bty or 540) - h * 0.5,
                x2 = w - SCREEN_W, y2 = h - SCREEN_H, fade = UI.solid(ba * op),
            })
        end
    end

    -- doors
    local lx, rx, dw, dtop, scrim
    local rtx, rty, rsx = c:at("#5@1", f)
    local ltx, _,   lsx = c:at("#5@2", f)
    if rtx and ltx then
        dw   = DOOR_W * math.abs(rsx)
        rx   = rtx
        lx   = ltx + DOOR_W * lsx
        dtop = rty - SCREEN_H * 0.5
        scrim = c:get("#1@3", f, "a") or FB_SCRIM
    else
        lx, rx, dw, dtop, scrim = fallback_door()
    end

    -- left door = the same panel mirrored (a negative src width is raylib's flip)
    tex.draw_texture(id, { src = { x = 0, y = 0, width = -DOOR_W, height = SCREEN_H },
                           x = lx, y = dtop, x2 = dw, y2 = SCREEN_H, fade = UI.solid(op) })
    tex.draw_texture(id, { src = { x = 0, y = 0, width = DOOR_W, height = SCREEN_H },
                           x = rx, y = dtop, x2 = dw, y2 = SCREEN_H, fade = UI.solid(op) })

    -- the full-screen black at depth 3: above both doors, below all four kanji
    if scrim and scrim > 0 then
        tex.draw_texture(id, { src = SCRIM_SRC,
                               x = 0, y = 0, x2 = SCREEN_W, y2 = SCREEN_H,
                               fade = scrim * op })
    end

    -- kanji
    for i = 1, #CELLS do
        local cell = CELLS[i]
        local cx, cy, s, a
        local tx, ty, sx, _, al = c:at(cell.track, f)
        -- glyph tracks start at their placed frame, so gate explicitly
        local first = c:has(cell.track) and c.tracks[cell.track][1][1] or nil
        if tx and first and f >= first then
            cx, cy, s, a = tx, ty, sx, al
        elseif not tx then
            local fs, fa = fallback_kanji(i, (f >= STAMP_TO) and 1 or 0)
            if fs then
                cx = (i == 1 or i == 3) and 455 or 1420
                cy = (i <= 2) and 255 or 765
                s, a = fs, fa
            end
        end
        if cx and a and a > 0 then
            local w = KANJI * math.max(1, math.floor(s + 0.5))   -- SimpleStyle: integer stamp scale
            tex.draw_texture(id, {
                src = { x = cell.sx, y = cell.sy, width = KANJI, height = KANJI },
                x   = math.floor(cx - w * 0.5),
                y   = math.floor(cy - w * 0.5),
                x2  = w, y2 = w, fade = UI.solid(a * op),
            })
        end
    end
    return true
end

M.armed      = false
M.engine_u   = nil
M.has_draw_top = false
M.t0         = nil
M.armed_open = false
M.open_t0    = nil
M.sfx_done   = false

function M.arm(active)
    M.armed = active and true or false
    if not M.armed then
        M.t0 = nil            -- let the fallback clock restart cleanly next time
    end
end

function M.set_progress(p)
    M.has_draw_top = true
    if p and p >= 0 then
        M.engine_u = p
    else
        M.engine_u = nil
        M.armed_open = false
        M.open_t0    = nil
    end
end

function M.progress()
    if M.has_draw_top then
        -- the engine supplies real progress every frame; nil/negative = not running
        if M.engine_u and M.engine_u >= 0 then return clamp01(M.engine_u) end
        return nil
    end
    -- fallback: no draw_top on this engine build, self-clock off arm()
    if not M.armed then return nil end
    local now = tex.get_current_ms()
    if not M.t0 then M.t0 = now end
    local d = duration_ms()
    local u = (now - M.t0) / d
    if u >= 1.0 then return nil end
    return u
end

local function off_screen()
    local scr = tex.current_screen and tex.current_screen() or nil
    if scr == nil or scr == "SONG_SELECT" or scr == "DAN_SELECT" then return false end
    M.engine_u   = nil
    M.armed      = false
    M.armed_open = false
    M.open_t0    = nil
    M.t0         = nil
    M.open_held  = false
    return true
end

function M.draw()
    if off_screen() then return false end
    local u = M.progress()
    if not u then return false end

    fire_sfx(u)

    local close_u = phases()
    local f = frame_of(u)
    if not draw_frame(f, (u <= close_u) and (u / close_u) or nil) then return false end

    if not M.armed_open then
        M.armed_open = true
        M.open_t0    = nil
    end
    M._drawn_ms  = tex.get_current_ms()
    return true
end

-- true iff M.draw() already painted this exact engine frame
function M.drawn_this_frame()
    return M._drawn_ms ~= nil and M._drawn_ms == tex.get_current_ms()
end

local INTRO_FROM = 5         -- clip label `in`

local REVEAL_F = OPEN_FROM   -- 182

function M.draw_open()
    if off_screen() then __hss_dan_intro = nil; return false end
    local req = __hss_dan_intro
    if req ~= nil then
        __hss_dan_intro = nil
        if req == "full" and not M.armed_open then
            M.armed_open = true
            M.open_t0    = nil
            M.open_held  = false
            M.open_from  = INTRO_FROM
            fire_sfx()
        elseif req == "open" then
            M.open_from = OPEN_FROM
        end
    end
    if not M.armed_open then return false end
    local now  = tex.get_current_ms()
    if not M.open_t0 then M.open_t0 = now end
    local from = M.open_from or OPEN_FROM
    local f    = from + (now - M.open_t0) / MS_PER_FRAME

    local ready = (__hss_dan_ready ~= false)
    if not ready then
        if f > REVEAL_F then
            f = REVEAL_F
            M.open_held = true
        end
    elseif M.open_held then
        M.open_held = false
        M.open_t0   = now - (REVEAL_F - from) * MS_PER_FRAME
        f           = REVEAL_F
    end
    M.open_f = f

    if f >= OPEN_TO then
        M.armed_open = false
        M.open_t0    = nil
        M.open_held  = false
        M.open_from  = nil
        M.sfx_done   = false
        M.engine_u   = nil
        M.t0         = nil
        return false
    end
    return draw_frame(f, nil)
end

return M
