-- SimpleStyle v2 (module meta): shared helpers for the global overlays, transitions, dan select,
-- game over and retry. LOGICAL px (1920x1080). Textures: Graphics/global/ss_meta (scene, band, hint,
-- game_over, lamp). The wipe, window open and engine text are core's (UI.wipe / UI.wipe_in / UI.wipe_out /
-- UI.open_rect / UI.text / UI.draw_text).
local UI = require("global.ss_ui")
local D = UI.D
local M = { UI = UI }

local cache, cache_screen = {}, nil
local function T(name)
    local scr = tex.current_screen and tex.current_screen() or ""
    if scr ~= cache_screen then cache, cache_screen = {}, scr end
    local t = cache[name]
    if t == nil then
        t = tex.get_texture("global/ss_meta/" .. name) or false
        cache[name] = t
    end
    return t or nil
end
M.T = T

-- ---------------------------------------------------------------- overlay hide list
-- The global overlays (coin_overlay: status tile, 2P invite bubble, credit line) never cover content.
-- Static part: HIDE[screen] = { status = true, invite = true, credit = true }.
-- Dynamic part: a screen script that opens a board over an overlay's corner calls, every frame it is open,
--     SS_OVERLAY_HIDE = { ms = tex.get_current_ms(), status = true, invite = true }
-- (a plain global, so a module needs no require), or M.hide_overlays({ "status", "invite" }).
-- Keys: status (QR / card tile), invite (2P invite bubble), credit (free play line).
-- It holds for HOLD_MS (250) after the last raise, so the draw order between the screen and the overlay
-- and a slow frame do not matter. `ms` is optional (a flag without it is stamped when the overlay first
-- sees it); a flag raised on another screen, or one whose clock is ahead of now (the screen clock was
-- reset), is ignored, so a stale flag can never hide an overlay on the next screen.
M.HIDE = {
    -- dan select: the course board fills the screen; the invite has nothing to point at there
    DAN_SELECT = { invite = true },
    -- 2P song select: both plates and both cursors use the lower corners
    SONG_SELECT_2P = { invite = true },
}
local HOLD_MS = 250
local function cur_screen() return tex.current_screen and tex.current_screen() or "" end
function M.hide_overlays(keys)
    local h = { ms = tex.get_current_ms(), screen = cur_screen() }
    for _, k in ipairs(keys) do h[k] = true end
    SS_OVERLAY_HIDE = h
end
function M.overlay_hidden(screen, key)
    local s = M.HIDE[screen]
    if s and s[key] then return true end
    local h = SS_OVERLAY_HIDE
    if type(h) ~= "table" or not h[key] then return false end
    local now, scr = tex.get_current_ms(), cur_screen()
    if h.ms == nil then h.ms = now end
    if h.screen == nil then h.screen = scr end
    if h.screen ~= scr then return false end
    local age = now - h.ms
    return age >= 0 and age < HOLD_MS
end

-- ---------------------------------------------------------------- shutter wipe (polish_meta)
-- The house screen wipe: 16 vertical shutters (120 px, sky / cloud2 stripes) drop from the top in 3
-- hard steps (1/3, 2/3, full; 50 ms each), the columns starting in 3 groups from left to right, one step
-- apart. A moving shutter has a bottom bar (2U paper + 2U ink); closed, the screen is the plain striped sky. Out =
-- the same shutters rolling back up in the same left-to-right order (the scene underneath is revealed
-- as a sweep). 5 steps = 250 ms either way. Alpha 1 only.
local SH_N, SH_W, SH_GROUPS = 16, 120, 3
M.SHUTTER_STEPS = 5
M.SHUTTER_MS = M.SHUTTER_STEPS * 50
local function shutter_cols(fill_of)
    local H = tex.get_screen_height()
    local U = D.U
    for i = 0, SH_N - 1 do
        local k = fill_of(math.floor(i * SH_GROUPS / SH_N))     -- 0..3 thirds
        if k > 0 then
            local x = i * SH_W
            local col = (i % 2 == 0) and D.P.sky or D.P.cloud2
            if k >= 3 then
                UI.rect(x, 0, SH_W, H, col)
            else
                local h = UI.grid(H * k / 3)
                UI.rect(x, 0, SH_W, h, col)
                UI.rect(x, h - 3 * U, SH_W, 2 * U, D.P.paper)     -- the blind's bottom bar
                UI.rect(x, h - U, SH_W, 2 * U, D.P.ink)
            end
        end
    end
end
-- t = ms since the wipe started; dir "in" (screen closes) or "out" (screen opens). Returns true once done.
function M.shutter(t, dir)
    if t == nil then return false end
    local s = math.floor(t / 50)
    if dir == "in" then
        if t < 0 then return false end
        shutter_cols(function(gi) return math.max(0, math.min(3, s - gi + 1)) end)
        return s >= M.SHUTTER_STEPS - 1
    end
    if t < 0 then shutter_cols(function() return 3 end); return false end
    shutter_cols(function(gi) return math.max(0, math.min(3, 3 - (s - gi + 1))) end)
    return s >= M.SHUTTER_STEPS - 1
end

-- ---------------------------------------------------------------- screen-entry wipe
-- The engine's screen fade (a translucent black rect over 500 ms) is cut to 1 ms in skin_config
-- (screen_fade_ms); this replaces it with the house wipe: the sky shutters rolling up (M.shutter, 250 ms).
-- Same screens as the engine's screen_fade_applies(): not into the game / result screens, not from
-- LOADING, not SONG_SELECT / ENTRY -> DAN_SELECT. Called by AllNetIcon:draw, which every screen draws.
local NO_WIPE_TO = { GAME = true, GAME_2P = true, GAME_DAN = true, GAME_PRACTICE = true, AI_GAME = true,
                     RESULT = true, RESULT_2P = true, DAN_RESULT = true, LOADING = true }
function M.screen_wipe()
    local scr = tex.current_screen and tex.current_screen() or ""
    local now = tex.get_current_ms()
    if scr ~= SS_WIPE_SCREEN then
        local from = SS_WIPE_SCREEN
        SS_WIPE_SCREEN = scr
        local skip = NO_WIPE_TO[scr] or from == nil or from == "LOADING"
            or (scr == "DAN_SELECT" and (from == "SONG_SELECT" or from == "ENTRY"))
        SS_WIPE_T0 = (not skip) and now or nil
    end
    if SS_WIPE_T0 then
        -- the shutters roll up over the new screen (polish_meta: was 3 checker-dither steps)
        if M.shutter(now - SS_WIPE_T0, "out") then SS_WIPE_T0 = nil end
    end
end

-- ---------------------------------------------------------------- dan select: Momo in the left column
local dan = { momo = nil, last_moved = nil, confirmed = false }
function M.dan_reset()
    UI.reset()
    dan.momo = UI.Mascot.new({ role = "menu", beat = false })
    dan.last_moved, dan.confirmed = nil, false
end
function M.dan_momo_draw()
    if not dan.momo then M.dan_reset() end
    local now = tex.get_current_ms()
    dan.momo:update(now)
    dan.momo:draw(180, 912)          -- feet on the grass line of dan_select/global/bg
end
function M.dan_momo_cursor(moved_ms)
    if not dan.momo then return end
    if moved_ms and moved_ms >= 0 and dan.last_moved and moved_ms < dan.last_moved then
        dan.momo:react("move")
    end
    dan.last_moved = moved_ms
end
function M.dan_momo_confirm(f)
    if not dan.momo then return end
    if f and f > 0 then
        if not dan.confirmed then dan.momo:react("decide") end
        dan.confirmed = true
    else
        dan.confirmed = false
    end
end

-- ---------------------------------------------------------------- dynamic text over textures
-- No words are baked into this module's textures (SCREEN_GUIDE_V2 §11): a texture keeps its chrome and its
-- words are drawn as engine text in the player's language right after the texture is drawn, whichever
-- script draws it (Nijiiro's dan select draws ours through its own helpers).
--   local set = M.label_set({ { "dan_select/box/clear_mark", "box", "clear_mark", fn }, ... })
--   M.with_labels(set, fn, ...)   runs fn(...) with tex.draw_texture hooked: after a draw of a listed
--                                 texture, entry.fn(x, y, params) runs with (x, y) = its drawn top-left
--                                 (texture.json x / y for params.index, + params.x / params.y).
-- Handles compare with == (not as table keys); they are resolved again on every screen change.
-- Nested calls reuse the outer hook. Hidden draws (fade snapped to 0) get no text.
function M.label_set(spec) return { spec = spec, scr = nil, ids = nil, active = false } end

local function resolve_set(set)
    local scr = cur_screen()
    if set.scr == scr and set.ids then return set.ids end
    local ids = {}
    for _, e in ipairs(set.spec) do
        local id = tex.get_texture(e[1])
        if id then
            local info = tex.get_texture_info(e[2], e[3])
            ids[#ids + 1] = { id = id, fn = e[4], xs = (info and info.x) or {}, ys = (info and info.y) or {} }
        end
    end
    set.scr, set.ids = scr, ids
    return ids
end
function M.reset_labels(set) set.scr, set.ids = nil, nil end

local unpack_ = table.unpack or unpack
function M.with_labels(set, fn, ...)
    if set.active then return fn(...) end
    local ids = resolve_set(set)
    if #ids == 0 then return fn(...) end
    local draw = tex.draw_texture
    tex.draw_texture = function(id, p)
        draw(id, p)
        for i = 1, #ids do
            local e = ids[i]
            if e.id == id then
                p = p or {}
                if UI.solid(p.fade) == 1 then
                    local k = (p.index or 0) + 1
                    e.fn((e.xs[k] or e.xs[1] or 0) + (p.x or 0), (e.ys[k] or e.ys[1] or 0) + (p.y or 0), p)
                end
                break
            end
        end
    end
    set.active = true
    local r = table.pack(pcall(fn, ...))
    set.active = false
    tex.draw_texture = draw
    if not r[1] then error(r[2], 0) end
    return unpack_(r, 2, r.n)
end

-- the first of `sizes` (role sizes) at which a string fits `w`, as an OutlinedText (the last size if none)
function M.fit(str, w, sizes, style)
    local t
    for _, sz in ipairs(sizes) do
        t = UI.text(str, sz, style)
        if UI.text_width(str, sz, style) <= w then return t end
    end
    return t
end
function M.fit_key(key, w, sizes, style) return M.fit(UI.t(key) or key, w, sizes, style) end

-- chrome.plate in Lua (header plate: paper, 1U ink border + shadow, 18U accent cell, 1U divider, 36 px ink
-- text) with its outer top-left at (x, y), sized to the measured text (chrome.plate_width). Returns w.
function M.plate(x, y, key, accent)
    local U = D.U
    local str = UI.t(key) or key
    local tw = UI.text_width(str, 36)
    local w = math.ceil((18 * U + U + 3 * U + tw + 4 * U + U) / U) * U
    local ix, iy, iw, ih = UI.frame(x, y, w, 18 * U)
    UI.rect(ix, iy, 17 * U, ih, accent or D.P.p1)          -- icon cell (PLATE_ICON_W - 1U)
    UI.rect(ix + 17 * U, iy, U, ih, D.P.ink)
    UI.draw_text(UI.text(str, 36), ix + 21 * U, iy + ih / 2, "l")
    return w
end

-- dan names by rank index (ss/strings.py keys)
M.EMBLEM_KEYS = { "dan_shokyu", "dan_kyu_10", "dan_kyu_9", "dan_kyu_8", "dan_kyu_7", "dan_kyu_6", "dan_kyu_5",
    "dan_kyu_4", "dan_kyu_3", "dan_kyu_2", "dan_kyu_1", "dan_shodan", "dan_2", "dan_3", "dan_4", "dan_5", "dan_6",
    "dan_7", "dan_8", "dan_9", "dan_10", "dan_kuroto", "dan_meijin", "dan_chojin", "dan_tatsujin" }   -- nameplate dan_emblem frames

return M
