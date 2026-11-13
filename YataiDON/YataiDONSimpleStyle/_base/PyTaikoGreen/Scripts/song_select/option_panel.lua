local SKIN_S = tex.get_screen_scale()
local SKIN = {
    modifier_offset = { y = 50 * SKIN_S },
    modifier_offset_2 = { x = 92 * SKIN_S, y = 110 * SKIN_S },
    modifier_text = { x = 330 * SKIN_S, y = 823 * SKIN_S, font_size = math.floor(30 * SKIN_S) },
    neiro_counter_margin = { x = 20 * SKIN_S },
    neiro_counter_x_offset = { x = 60 * SKIN_S },
    neiro_text = { x = 235 * SKIN_S, y = 1000 * SKIN_S, font_size = math.floor(50 * SKIN_S) },
    option_p2 = { x = 800 * SKIN_S },
    option_text_in = { x = 100 * SKIN_S },
}
-- Default 演奏オプション (modifier) and 音色 (neiro) panels. The engine's ModifierSelector /
-- NeiroSelector keep the state (input, audio, animations); this draws them.
--
-- Not a SongSelect class: SongSelectScript installs draw_option_panel from here when the skin's
-- own SongSelect does not define one, so every skin gets this look unless it draws the panel itself
-- (a skin's draw_option_panel can return false to fall back to this one). The dan select screen
-- also calls draw_modifier directly.

local M = {}

local WHITE, BLACK = { 255, 255, 255, 255 }, { 0, 0, 0, 255 }

local function sprite(subset, name)
    return tex.get_texture("song_select/" .. subset .. "/" .. name)
end

local function make_text(str, font_size, thickness)
    return text.create_raw_text(str, font_size, WHITE, BLACK, false, thickness, 2.0)
end

-- per player and panel: the texts that slide when a value changes (see the engine's
-- ModifierSelector::start_text_animation), rebuilt whenever a new selector opens
local states = {}

local function panel_state(kind, player_num, change, init)
    local key = kind .. player_num
    local st = states[key]
    if not st or st.id ~= change.id then
        st = { id = change.id, seq = change.seq }
        init(st)
        states[key] = st
    end
    return st
end

local ICON = {
    auto    = "mod_auto",
    speed   = "mod_baisaku",
    display = "mod_doron",
    inverse = "mod_abekobe",
    random  = "mod_kimagure",
}

-- primary fades with `fade` and slides by `move`; secondary comes in from the opposite side
local function draw_animated(primary, secondary, x, y, animate, change)
    if animate and change.active then
        primary:draw({ x = x + change.move * change.dir, y = y, fade = change.fade })
        secondary:draw({ x = (change.dir * -SKIN.option_text_in.x) + x + change.move * change.dir,
                         y = y, fade = 1.0 - change.fade })
    else
        primary:draw({ x = x, y = y })
    end
end

-- how far past the top the panel leaves (the character rides along with it)
function M.slide_out()
    return -370 * SKIN_S
end

function M.draw_modifier(sel)
    local rows   = sel:rows()
    local change = sel:change()
    local p      = sel:player_num()
    local cur    = sel:index()
    local font   = SKIN.modifier_text.font_size
    local function mk(s) return make_text(s, font, 3.5) end

    local st = panel_state("mod", p, change, function(s)
        local function label(k) return tex.skin_text(k) end
        local function row_value(name)
            for _, r in ipairs(rows) do if r.name == name then return r.value end end
            return ""
        end
        s.prim = {
            ["true"] = mk(label("modifier_text_true")), ["false"] = mk(label("modifier_text_false")),
            speed = mk(row_value("speed")), kimagure = mk(label("modifier_text_kimagure")),
            detarame = mk(label("modifier_text_detarame")), neiro = mk(row_value("neiro")),
        }
        s.sec = {
            ["true"] = mk(label("modifier_text_true")), ["false"] = mk(label("modifier_text_false")),
            speed = mk(row_value("speed")), kimagure = mk(label("modifier_text_kimagure")),
            detarame = mk(label("modifier_text_detarame")), neiro = mk(row_value("neiro")),
        }
        s.names = {}
    end)

    if st.seq ~= change.seq then
        st.seq = change.seq
        local row = rows[cur]
        if row then
            local k
            if row.name == "speed" or row.name == "neiro" then
                k = row.name
            elseif row.name == "random" then
                if row.state == 1 then k = "kimagure" elseif row.state == 2 then k = "detarame" end
            else
                k = (row.state == 1) and "true" or "false"
            end
            if k then
                st.sec[k]  = st.prim[k]
                st.prim[k] = mk(row.value)
            end
        end
    end

    local x      = (p - 1) * SKIN.option_p2.x
    local move_y = sel:offset()
    local pitch  = SKIN.modifier_offset.y
    local txt    = SKIN.modifier_text
    local o2     = SKIN.modifier_offset_2
    local n      = #rows

    tex.draw_texture(sprite("modifier", "top"),            { x = x, y = move_y })
    tex.draw_texture(sprite("modifier", p .. "p"),         { x = x, y = move_y })
    tex.draw_texture(sprite("modifier", "bottom"),         { x = x, y = move_y + n * pitch })

    for i = 1, n do
        local row     = rows[i]
        local row_y   = move_y + (i - 1) * pitch
        local current = (i == cur)

        tex.draw_texture(sprite("modifier", "background"), { x = x, y = row_y })
        tex.draw_texture(sprite("modifier", current and "mod_bg_highlight" or "mod_bg"), { x = x, y = row_y })
        tex.draw_texture(sprite("modifier", "mod_box"),    { x = x, y = row_y })

        local name = st.names[row.label]
        if not name then
            name = mk(row.label)
            st.names[row.label] = name
        end
        name:draw({ x = o2.x + x, y = txt.y + row_y })

        local text_y = txt.y + row_y
        local function value_text(prim, sec)
            draw_animated(prim, sec, txt.x - prim.width / 2.0 + x, text_y, current, change)
        end

        if row.name == "speed" then
            value_text(st.prim.speed, st.sec.speed)
            local spd = row.state
            if     spd >= 40 then tex.draw_texture(sprite("modifier", "mod_yonbai"), { x = x, y = row_y })
            elseif spd >= 30 then tex.draw_texture(sprite("modifier", "mod_sanbai"), { x = x, y = row_y })
            elseif spd >  10 then tex.draw_texture(sprite("modifier", ICON.speed),   { x = x, y = row_y }) end
        elseif row.name == "neiro" then
            value_text(st.prim.neiro, st.sec.neiro)
        elseif row.name == "random" then
            if row.state == 1 then
                value_text(st.prim.kimagure, st.sec.kimagure)
                tex.draw_texture(sprite("modifier", ICON.random), { x = x, y = row_y })
            elseif row.state == 2 then
                value_text(st.prim.detarame, st.sec.detarame)
                tex.draw_texture(sprite("modifier", "mod_detarame"), { x = x, y = row_y })
            else
                value_text(st.prim["false"], st.sec["false"])
            end
        else
            local on = (row.state == 1)
            if on and ICON[row.name] then
                tex.draw_texture(sprite("modifier", ICON[row.name]), { x = x, y = row_y })
            end
            value_text(on and st.prim["true"] or st.prim["false"], on and st.sec["true"] or st.sec["false"])
        end

        if current then
            tex.draw_texture(sprite("modifier", "blue_arrow"),
                { x = x - change.arrow_move, y = row_y, fade = change.arrow_fade })
            tex.draw_texture(sprite("modifier", "blue_arrow"),
                { mirror = "horizontal", x = x + o2.y + change.arrow_move, y = row_y, fade = change.arrow_fade })
        end
    end
end

function M.draw_neiro(sel)
    local names  = sel:names()
    local idx    = sel:index()
    local change = sel:change()
    local p      = sel:player_num()
    local txt    = SKIN.neiro_text
    local in_x   = SKIN.option_text_in.x
    local function mk(s) return make_text(s, txt.font_size, 5.0) end

    local st = panel_state("neiro", p, change, function(s)
        s.text, s.text_2 = mk(names[idx] or ""), mk(names[idx] or "")
    end)
    if st.seq ~= change.seq then
        st.seq = change.seq
        st.text   = st.text_2
        st.text_2 = mk(names[idx] or "")
    end

    local x   = (p - 1) * SKIN.option_p2.x
    local y   = sel:offset()
    local dir = change.dir
    local mv  = change.move

    tex.draw_texture(sprite("neiro", "background"), { x = x, y = y })
    tex.draw_texture(sprite("neiro", p .. "p"),     { x = x, y = y })
    tex.draw_texture(sprite("neiro", "divisor"),    { x = x, y = y })
    tex.draw_texture(sprite("neiro", "music_note"), { x = x + mv * dir, y = y, fade = change.fade })
    tex.draw_texture(sprite("neiro", "music_note"),
        { x = x + (dir * -in_x) + mv * dir, y = y, fade = 1.0 - change.fade })
    tex.draw_texture(sprite("neiro", "blue_arrow"), { x = x - change.arrow_move, y = y, fade = change.arrow_fade })
    tex.draw_texture(sprite("neiro", "blue_arrow"),
        { mirror = "horizontal", x = x + in_x * 2 + change.arrow_move, y = y, fade = change.arrow_fade })

    local margin = SKIN.neiro_counter_margin.x
    local counter = tostring(idx)
    local total_width = #counter * margin
    for i = 1, #counter do
        local digit = counter:byte(i) - 48
        tex.draw_texture(sprite("neiro", "counter"),
            { frame = digit, x = x - total_width / 2 + (i - 1) * margin, y = y })
    end
    counter = tostring(#names)
    total_width = #counter * margin
    for i = 1, #counter do
        local digit = counter:byte(i) - 48
        tex.draw_texture(sprite("neiro", "counter"),
            { frame = digit, x = x - total_width / 2 + (i - 1) * margin + SKIN.neiro_counter_x_offset.x, y = y })
    end

    st.text:draw({ x = x + txt.x - st.text.width / 2.0 + mv * dir, y = y + txt.y, fade = change.fade })
    st.text_2:draw({ x = x + (dir * -in_x) + txt.x - st.text_2.width / 2.0 + mv * dir,
                     y = y + txt.y, fade = 1.0 - change.fade })
end

-- Installed as SongSelect:draw_option_panel. kind: 1 = modifier, 2 = the standalone neiro panel.
function M.draw_option_panel(_self, player, kind)
    if kind == 1 then
        local sel = player:modifier_panel()
        if sel then M.draw_modifier(sel) end
    else
        local sel = player:neiro_panel()
        if sel then M.draw_neiro(sel) end
    end
end

return M
