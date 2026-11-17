-- YataiDON-HSS child override of PyTaikoGreen/Scripts/background/background.lua:
-- byte-copy of the parent plus the ArcadeGauge overlay (3 hooks, marked below).
local DonBG               = require("background/bg_objects/donbg")
local BGNormal            = require("background/bg_objects/bg_normal")
local BGFever             = require("background/bg_objects/bg_fever")
local Fever               = require("background/bg_objects/fever")
local Footer              = require("background/bg_objects/footer")
local Dancer              = require("background/bg_objects/dancer")
local Ending              = require("background/bg_objects/ending")
local RankBadge           = require("background/bg_objects/rank_badge")
local RendaController     = require("background/bg_objects/renda")
local ChibiController     = require("background/bg_objects/chibi")
local ArcadeGauge         = require("background/bg_objects/arcade_gauge") -- child-only
local EnsoSkip            = require("background/bg_objects/enso_skip")     -- child-only
local BGAnim              = require("background/bg_objects/bg_anim")
local RendaClip           = require("background/bg_objects/renda_clip")
local PACKS               = require("background/bg_data/collab_packs")

-- A cabinet collab pack (bg_data/collab_packs.lua) for this #SCENEPRESET, when every part
-- it names was exported; nil sends the preset down the collab-script path.
local function module_exists(name)
    local ok, data = pcall(require, name)
    return ok and type(data) == "table"
end

local function pack_for(scene_preset)
    local p = scene_preset and PACKS[scene_preset]
    if not p then return nil end
    for _, band in ipairs(p.donbg) do
        if not module_exists("background/bg_data/donbg_anim/" .. band) then return nil end
    end
    if not (BGAnim.available(p.normal) and BGAnim.available(p.fever)) then return nil end
    if p.dancer_movie then
        if not BGAnim.available(p.dancer_movie) then return nil end
    elseif not module_exists("background/dancer_data/" .. p.dancer) then
        return nil
    end
    if p.dai and p.dai ~= "footer0" and not BGAnim.available(p.dai) then return nil end
    if not RendaClip.available(p.renda) then return nil end
    if not module_exists("background/bg_data/fever_anim/f_" .. p.crowd) then return nil end
    return p
end

-- whole-troupe dancer movie (i7, A3): every member is always on stage, replayed on the beat
local MovieTroupe = {}
MovieTroupe.__index = MovieTroupe
function MovieTroupe.new(name)
    local anim = BGAnim.new(name, "background")
    if not anim then return nil end
    anim:set_beat(40)
    return setmetatable({ anim = anim }, MovieTroupe)
end
function MovieTroupe:update(current_ms, bpm) self.anim:update(current_ms, bpm) end
function MovieTroupe:draw() self.anim:draw(1.0) end
function MovieTroupe:set_dancer_count(n) end
function MovieTroupe:destroy() self.anim:destroy() end

-- the stand under a collab troupe, drawn where the default footer band is
local DaiAnim = {}
DaiAnim.__index = DaiAnim
function DaiAnim.new(name)
    if name == "footer0" then return Footer.new("background", 0) end
    local anim = name and BGAnim.new(name, "background")
    if not anim then return Footer.new("background", -1) end
    return setmetatable({ anim = anim }, DaiAnim)
end
function DaiAnim:draw() self.anim:draw(1.0) end
function DaiAnim:destroy() self.anim:destroy() end


-- a collab's script by its module, required the first time a song uses it (requiring all 37 when
-- background.lua loaded took 250-300 ms of the first game load)
local COLLABS             = {
    PRACTICE   = { "background/bg_collabs/practice", nil, 1 },
    TUTORIAL   = { "background/bg_collabs/tutorial", nil, 1 },
    A3         = { "background/bg_collabs/a3", "background/collab/a3", 4 },
    ANIMAL     = { "background/bg_collabs/animal", "background/collab/animal", 5 },
    BUTTOBURST = { "background/bg_collabs/buttoburst", "background/collab/buttoburst", 4 },
    DAN        = { "background/bg_collabs/dan", "background/collab/dan", 1 },
    FUNASSYI   = { "background/bg_collabs/funassyi", "background/collab/funassyi", 5 },
    IMAS       = { "background/bg_collabs/imas", "background/collab/imas", 5 },
    IMAS_CG    = { "background/bg_collabs/imas", "background/collab/imas_cg", 3 },
    IMAS_ML    = { "background/bg_collabs/imas", "background/collab/imas_ml", 3 },
    IMAS_SIDEM = { "background/bg_collabs/imas_sidem", "background/collab/imas_sidem", 3 },
    OSHIRI     = { "background/bg_collabs/oshiri", "background/collab/oshiri", 5 },
    DQ10       = { "background/bg_collabs/dq10", "background/collab/dq10", 5 },
    GB    = { "background/bg_collabs/gb", "background/collab/gb", 5 },
    GMT   = { "background/bg_collabs/gmt", "background/collab/gmt", 5 },
    GUMI  = { "background/bg_collabs/gumi", "background/collab/gumi", 5 },
    I7ID7 = { "background/bg_collabs/i7id7", "background/collab/i7id7", 5 },
    I7NATSU = { "background/bg_collabs/i7natsu", "background/collab/i7natsu", 5 },
    I7REV = { "background/bg_collabs/i7rev", "background/collab/i7rev", 5 },
    I7TRI = { "background/bg_collabs/i7tri", "background/collab/i7tri", 5 },
    IA    = { "background/bg_collabs/ia", "background/collab/ia", 5 },
    KOBAYASHI = { "background/bg_collabs/kobayashi", "background/collab/kobayashi", 5 },
    KUMAMON = { "background/bg_collabs/kumamon", "background/collab/kumamon", 5 },
    LOVELIVE = { "background/bg_collabs/lovelive", "background/collab/lovelive", 5 },
    MARIO = { "background/bg_collabs/mario", "background/collab/mario", 5 },
    MH3G  = { "background/bg_collabs/mh3G", "background/collab/mh3G", 5 },
    MH3RD = { "background/bg_collabs/mh3rd", "background/collab/mh3rd", 5 },
    MIKU  = { "background/bg_collabs/miku", "background/collab/miku", 5 },
    MOMOCLO = { "background/bg_collabs/momoclo", "background/collab/momoclo", 5 },
    PZD   = { "background/bg_collabs/pzd", "background/collab/pzd", 5 },
    TOHO  = { "background/bg_collabs/toho", "background/collab/toho", 5 },
    TONKATSUDJ = { "background/bg_collabs/tonkatsudj", "background/collab/tonkatsudj", 1 },
    TOUKEN = { "background/bg_collabs/touken", "background/collab/touken", 5 },
    YMCK  = { "background/bg_collabs/ymck", "background/collab/ymck", 5 },
    YOKAI = { "background/bg_collabs/yokai", "background/collab/yokai", 5 },
    YOKAI_HATSUKOI = { "background/bg_collabs/yokai_hatsukoi", "background/collab/yokai_hatsukoi", 5 },
    YOKAI_MATSURI = { "background/bg_collabs/yokai_matsuri", "background/collab/yokai_matsuri", 5 },
    YOKAI_TOKOROTEN = { "background/bg_collabs/yokai_tokoroten", "background/collab/yokai_tokoroten", 5 },
    YOKAI_YOUGOTA = { "background/bg_collabs/yokai_yougota", "background/collab/yokai_yougota", 5 },
}

Background                = {}
Background.__index        = Background

function Background.new(player_num, bpm, scene_preset)
    local self        = setmetatable({}, Background)

    self.player_num   = player_num
    self.bpm          = bpm
    self.scene_preset = scene_preset
    self.is_2p        = (player_num == 3) -- PlayerNum::TWO_PLAYER

    -- child-only: arcade soul-gauge overlay, drawn in draw_fore (in front of the HUD)
    self.arcade_gauge = ArcadeGauge.new()

    -- child-only: 演奏スキップ countdown card / dim / banner.
    self.enso_skip = EnsoSkip.new()
    _G.g_active_enso_skip = self.enso_skip

    -- a cabinet collab pack replaces the collab script (and works in 2P too)
    local pack = pack_for(scene_preset)
    self.pack = pack
    local entry = (not pack) and (not self.is_2p) and scene_preset and COLLABS[scene_preset] or nil
    if entry then
        local ctor, path, max_dancers = require(entry[1]).new, entry[2], entry[3]
        if path then
            self.collab = ctor(player_num, bpm, path, max_dancers)
        else
            self.collab = ctor(player_num, bpm)
        end
    else
        -- Standard (non-collab) case
        local max_dancers = 5
        self.max_dancers  = max_dancers

        if self.is_2p then
            if pack then
                self.donbg_1  = DonBG.create_named(1, "background", pack.donbg[1])
                self.donbg_2  = DonBG.create_named(2, "background", pack.donbg[2])
            else
                local donbg_index = math.random(1, 6)
                self.donbg_1  = DonBG.create(1, "background", donbg_index)
                self.donbg_2  = DonBG.create(2, "background", donbg_index)
            end
            self.p2_y_offset  = 804
            self.is_clear_1   = false
            self.is_clear_2   = false
        elseif pack then
            self.donbg     = DonBG.create_named(player_num, "background", pack.donbg[player_num == 2 and 2 or 1])
            self.bg_normal = BGNormal.create_named(pack.normal, "background")
            self.bg_fever  = BGFever.create_named(pack.fever, "background")
            self.fever     = Fever.Anim.new(pack.crowd, bpm, "background")
            if pack.dancer_movie then
                self.dancer = MovieTroupe.new(pack.dancer_movie)
            else
                self.dancer = Dancer.ArcadeDancerGroup.new(pack.dancer, bpm, nil, "background")
            end
            self.footer    = DaiAnim.new(pack.dai)
        else
            self.donbg     = DonBG.create(player_num, "background")
            self.bg_normal = BGNormal.create(math.random(0, 4), "background")
            self.bg_fever  = BGFever.create(math.random(0, 3), "background")
            self.fever     = Fever.create(math.random(0, Fever.variant_count("background") - 1), bpm, "background")
            self.dancer    = Dancer.create(math.random(0, 20), bpm, "background", max_dancers)
            self.footer    = Footer.new("background", math.random(0, 2))
        end

        if pack then
            self.renda      = RendaClip.new("background", pack.renda)
            if self.is_2p then
                self.renda_2 = RendaClip.new("background", pack.renda, self.p2_y_offset)
            end
        else
            local renda_index = math.random(0, 2)
            self.renda      = RendaController.new("background", renda_index)
            if self.is_2p then
                self.renda_2 = RendaController.new("background", renda_index, self.p2_y_offset)
            end
        end
        self.chibi          = ChibiController.new(bpm, "background")
        self.is_clear       = false
        self.is_rainbow     = false
        self.clear_progress = nil
    end

    return self
end

-- a miss streak darkens the donbg band (each player's own band in 2P)
function Background:handle_miss_streak(player_num, on)
    if self.collab then return end
    local d = self.is_2p and (player_num == 2 and self.donbg_2 or self.donbg_1) or self.donbg
    if d then d:set_dark(on) end
end

function Background:update(current_ms, bpm)
    self.bpm = bpm
    self.enso_skip:update(current_ms)
    if self.collab then
        self.collab:update(current_ms, bpm)
    else
        if self.is_2p then
            self.donbg_1:update(current_ms)
            self.donbg_2:update(current_ms)
        else
            self.donbg:update(current_ms)
            self.bg_normal:update(current_ms)
            self.bg_fever:update(current_ms)
            self.fever:update(current_ms, bpm)
            self.dancer:update(current_ms, bpm)
        end
        self.renda:update(current_ms)
        if self.renda_2 then self.renda_2:update(current_ms) end
        self.chibi:update(current_ms, bpm)
    end
end

function Background:handle_good(player_num)
    if self.collab then
        self.collab:handle_good(player_num)
    else
        self.chibi:add_chibi(player_num, false)
    end
end

function Background:handle_ok(player_num)
    if self.collab then
        self.collab:handle_ok(player_num)
    else
        self.chibi:add_chibi(player_num, false)
    end
end

function Background:handle_bad(player_num)
    if self.collab then
        self.collab:handle_bad(player_num)
    else
        self.chibi:add_chibi(player_num, true)
    end
end

function Background:handle_drumroll(player_num)
    if self.collab then
        self.collab:handle_drumroll(player_num)
    else
        if player_num == 2 and self.renda_2 then
            self.renda_2:add_renda()
        else
            self.renda:add_renda()
        end
    end
end

function Background:handle_balloon(player_num)
    if self.collab then
        self.collab:handle_balloon(player_num)
    end
end

function Background:handle_dan(player_num, state)
    if self.collab and self.collab.handle_dan then
        self.collab:handle_dan(player_num, state)
    end
end

function Background:handle_gauge(player_num, progress, is_clear, is_rainbow, clear_progress, flash)
    -- child-only
    self.arcade_gauge:handle_gauge(player_num, progress, is_clear, is_rainbow, clear_progress, flash)
    if self.collab then
        self.collab:handle_gauge(player_num, progress, is_clear, is_rainbow, clear_progress)
    elseif self.is_2p then
        -- Update each player's donbg clear state independently
        if player_num == 1 then
            self.donbg_1:set_clear(is_clear)
            self.is_clear_1 = is_clear
        elseif player_num == 2 then
            self.donbg_2:set_clear(is_clear)
            self.is_clear_2 = is_clear
        end
        self.is_clear = self.is_clear_1 or self.is_clear_2
        self.is_rainbow = is_rainbow
    else
        self.donbg:set_clear(is_clear)
        if is_clear and not self.is_clear then self.bg_fever:start() end
        if not is_clear and self.is_clear then self.bg_fever:stop() end
        if is_rainbow and not self.is_rainbow then self.fever:start() end
        if not is_rainbow and self.is_rainbow then self.fever:stop() end
        self.is_clear   = is_clear
        self.is_rainbow = is_rainbow

        self:handle_dancer_count(progress, is_clear, clear_progress)
    end
end

local GAUGE_MAX     = 87.0
local CLEAR_STARTS  = { 52, 60, 69 }          -- easy / normal / hard+oni
local CLEAR_DEFAULT = 69 / GAUGE_MAX          -- 0.79310

function Background:handle_dancer_count(progress, is_clear, clear_progress)
    if not self.dancer or not self.dancer.set_dancer_count then return end

    if clear_progress and clear_progress > 0 then
        self.clear_progress = clear_progress
    elseif is_clear and not self.clear_progress then
        -- The engine flips is_clear at gauge_length > clear_start - 1, so the
        -- progress at the flip is just under clear_start/87; pick the first
        -- threshold at or above it.
        local p = progress or 0
        for _, cs in ipairs(CLEAR_STARTS) do
            if p < cs / GAUGE_MAX + 0.0005 then
                self.clear_progress = cs / GAUGE_MAX
                break
            end
        end
        self.clear_progress = self.clear_progress or CLEAR_DEFAULT
    end

    local cp = self.clear_progress or CLEAR_DEFAULT
    local r  = (progress or 0) / cp
    local n  = math.floor(2 * r + 3)
    if n < 3 then n = 3 elseif n > 5 then n = 5 end
    -- a collab troupe starts with its lead alone and grows to the full troupe at the clear
    if self.pack then
        n = math.max(1, math.min(5, math.floor(4 * r + 1)))
    end
    -- is_clear flips one gauge unit early; honour it so the fifth dancer and the
    -- クリア state arrive on the same frame.
    if is_clear then n = 5 end
    self.dancer:set_dancer_count(n)
end

function Background:draw_back()
    if require("global.ai_battle").draw_game_bg() then return end   -- Z-DON AI battle: the cabinet's arena
    if self.collab then
        self.collab:draw_back()
    else
        if not self.is_2p then
            if self.bg_fever:is_visible() then
                if not self.bg_fever.transitioned then
                    self.bg_normal:draw()
                end
                self.bg_fever:draw()
            else
                self.bg_normal:draw()
            end
        end

        if self.is_2p then
            self.donbg_1:draw(0)
            self.donbg_2:draw(self.p2_y_offset)
        else
            self.donbg:draw()
        end

        self.renda:draw()
        if self.renda_2 then self.renda_2:draw() end
        if not self.is_2p then
            self.dancer:draw()
            -- footer (dai band) paints after the crowd so it rises from behind it.
            self.footer:draw()
            if self.fever:is_visible() then self.fever:draw() end
        end
        self.chibi:draw()
    end
end

-- child-only. The engine only calls this when the skin declares it
-- (Background::wants_skip), and it then suppresses its own skip_counter text.
function Background:handle_skip(player_num, state)
    self.enso_skip:handle(state)
end

-- Ending banner (engine hook): the cabinet clip for the result kind
-- ("clear" / "full_combo" / "donderful" / "fail") replaces the engine's drawing
-- when its exported data exists; otherwise the engine keeps drawing its own.
function Background:handle_ending(player_num, kind)
    self.endings = self.endings or {}
    if self.collab and self.collab.handle_ending then
        self.collab:handle_ending(player_num, kind)
    end
    if Ending.available(kind) then
        self.endings[player_num] = Ending.new(kind, player_num, "game")
    end
end

function Background:draw_ending(player_num)
    local e = self.endings and self.endings[player_num]
    if e then e:draw(tex.get_current_ms()) end
end

-- Running score (engine hook): the 粋 / 雅 / 極 plate at the player panel's top-left
-- appears as each rank line is crossed (information/score `scorerank_Np`).
function Background:handle_score(player_num, score)
    if self.collab and self.collab.handle_score then
        self.collab:handle_score(player_num, score)
    end
    if not RankBadge.available() then return end
    if player_num == 2 and tex.ai_active and tex.ai_active() then return end   -- the AI lane has no score rank
    self.rank_badges = self.rank_badges or {}
    local b = self.rank_badges[player_num]
    if not b then
        b = RankBadge.new(player_num, "game")
        self.rank_badges[player_num] = b
    end
    b:set_score(score, tex.get_current_ms())
end

-- child-only: repaint the arcade gauge for the lane whose engine gauge just drew.
function Background:draw_gauge(player_num)
    self.arcade_gauge:draw_one(player_num)
    if self.collab and self.collab.draw_gauge then
        self.collab:draw_gauge(player_num)
    end
end

function Background:draw_fore()
    if self.collab then
        self.collab:draw_fore()
    end
    if self.rank_badges then
        local now = tex.get_current_ms()
        for _, b in pairs(self.rank_badges) do b:draw(now) end
    end
    require("global.ai_battle").draw_game_fore()   -- Z-DON AI battle: the end cut-ins, over both lanes
end

function Background:destroy()
    if _G.g_active_enso_skip == self.enso_skip then
        _G.g_active_enso_skip = nil
    end
    if self.endings then
        for _, e in pairs(self.endings) do e:destroy() end
        self.endings = nil
    end
    if self.rank_badges then
        for _, b in pairs(self.rank_badges) do b:destroy() end
        self.rank_badges = nil
    end
    if self.collab then
        self.collab:destroy()
    else
        if self.is_2p then
            self.donbg_1:destroy()
            self.donbg_2:destroy()
        else
            self.donbg:destroy()
            self.bg_normal:destroy()
            self.bg_fever:destroy()
            self.fever:destroy()
            self.dancer:destroy()
            self.footer:destroy()
        end
        self.renda:destroy()
        -- renda_2 shares the same texture folder; unload_folder is dedup-keyed
        -- so the second destroy is a safe no-op.
        if self.renda_2 then self.renda_2:destroy() end
        self.chibi:destroy()
    end
end
