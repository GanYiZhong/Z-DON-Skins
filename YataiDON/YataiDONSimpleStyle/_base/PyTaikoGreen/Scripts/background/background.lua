local DonBG               = require("background/bg_objects/donbg")
local BGNormal            = require("background/bg_objects/bg_normal")
local BGFever             = require("background/bg_objects/bg_fever")
local Fever               = require("background/bg_objects/fever")
local Footer              = require("background/bg_objects/footer")
local Dancer              = require("background/bg_objects/dancer")
local RendaController     = require("background/bg_objects/renda")
local ChibiController     = require("background/bg_objects/chibi")

local PracticeBackground  = require("background/bg_collabs/practice")
local TutorialBackground  = require("background/bg_collabs/tutorial")
local A3Background        = require("background/bg_collabs/a3")
local AnimalBackground    = require("background/bg_collabs/animal")
local ButtoBackground     = require("background/bg_collabs/buttoburst")
local DanBackground       = require("background/bg_collabs/dan")
local DQ10Background      = require("background/bg_collabs/dq10")
local GbBackground    = require("background/bg_collabs/gb")
local GmtBackground   = require("background/bg_collabs/gmt")
local GumiBackground  = require("background/bg_collabs/gumi")
local I7id7Background = require("background/bg_collabs/i7id7")
local I7natsuBackground = require("background/bg_collabs/i7natsu")
local I7revBackground = require("background/bg_collabs/i7rev")
local I7triBackground = require("background/bg_collabs/i7tri")
local IaBackground    = require("background/bg_collabs/ia")
local KobayashiBackground = require("background/bg_collabs/kobayashi")
local KumamonBackground = require("background/bg_collabs/kumamon")
local LoveliveBackground = require("background/bg_collabs/lovelive")
local MarioBackground = require("background/bg_collabs/mario")
local Mh3GBackground  = require("background/bg_collabs/mh3G")
local Mh3rdBackground = require("background/bg_collabs/mh3rd")
local MikuBackground  = require("background/bg_collabs/miku")
local MomocloBackground = require("background/bg_collabs/momoclo")
local PzdBackground   = require("background/bg_collabs/pzd")
local TohoBackground  = require("background/bg_collabs/toho")
local TonkatsudjBackground = require("background/bg_collabs/tonkatsudj")
local ToukenBackground = require("background/bg_collabs/touken")
local YmckBackground  = require("background/bg_collabs/ymck")
local YokaiBackground = require("background/bg_collabs/yokai")
local YokaiHatsukoiBackground = require("background/bg_collabs/yokai_hatsukoi")
local YokaiMatsuriBackground = require("background/bg_collabs/yokai_matsuri")
local YokaiTokorotenBackground = require("background/bg_collabs/yokai_tokoroten")
local YokaiYougotaBackground = require("background/bg_collabs/yokai_yougota")
local FunassyiBackground  = require("background/bg_collabs/funassyi")
local ImasBackground      = require("background/bg_collabs/imas")
local ImasSidemBackground = require("background/bg_collabs/imas_sidem")
local OshiriBackground    = require("background/bg_collabs/oshiri")
local WaiwaiBackground    = require("background/bg_collabs/waiwai")

local COLLABS             = {
    PRACTICE   = { PracticeBackground.new, nil, 1 },
    TUTORIAL   = { TutorialBackground.new, nil, 1 },
    A3         = { A3Background.new, "background/collab/a3", 4 },
    ANIMAL     = { AnimalBackground.new, "background/collab/animal", 5 },
    BUTTOBURST = { ButtoBackground.new, "background/collab/buttoburst", 4 },
    DAN        = { DanBackground.new, "background/collab/dan", 1 },
    DQ10       = { DQ10Background.new, "background/collab/dq10", 5 },
    GB    = { GbBackground.new, "background/collab/gb", 5 },
    GMT   = { GmtBackground.new, "background/collab/gmt", 5 },
    GUMI  = { GumiBackground.new, "background/collab/gumi", 5 },
    I7ID7 = { I7id7Background.new, "background/collab/i7id7", 5 },
    I7NATSU = { I7natsuBackground.new, "background/collab/i7natsu", 5 },
    I7REV = { I7revBackground.new, "background/collab/i7rev", 5 },
    I7TRI = { I7triBackground.new, "background/collab/i7tri", 5 },
    IA    = { IaBackground.new, "background/collab/ia", 5 },
    KOBAYASHI = { KobayashiBackground.new, "background/collab/kobayashi", 5 },
    KUMAMON = { KumamonBackground.new, "background/collab/kumamon", 5 },
    LOVELIVE = { LoveliveBackground.new, "background/collab/lovelive", 5 },
    MARIO = { MarioBackground.new, "background/collab/mario", 5 },
    MH3G  = { Mh3GBackground.new, "background/collab/mh3G", 5 },
    MH3RD = { Mh3rdBackground.new, "background/collab/mh3rd", 5 },
    MIKU  = { MikuBackground.new, "background/collab/miku", 5 },
    MOMOCLO = { MomocloBackground.new, "background/collab/momoclo", 5 },
    PZD   = { PzdBackground.new, "background/collab/pzd", 5 },
    TOHO  = { TohoBackground.new, "background/collab/toho", 5 },
    TONKATSUDJ = { TonkatsudjBackground.new, "background/collab/tonkatsudj", 1 },
    TOUKEN = { ToukenBackground.new, "background/collab/touken", 5 },
    YMCK  = { YmckBackground.new, "background/collab/ymck", 5 },
    YOKAI = { YokaiBackground.new, "background/collab/yokai", 5 },
    YOKAI_HATSUKOI = { YokaiHatsukoiBackground.new, "background/collab/yokai_hatsukoi", 5 },
    YOKAI_MATSURI = { YokaiMatsuriBackground.new, "background/collab/yokai_matsuri", 5 },
    YOKAI_TOKOROTEN = { YokaiTokorotenBackground.new, "background/collab/yokai_tokoroten", 5 },
    YOKAI_YOUGOTA = { YokaiYougotaBackground.new, "background/collab/yokai_yougota", 5 },
    FUNASSYI   = { FunassyiBackground.new, "background/collab/funassyi", 5 },
    IMAS       = { ImasBackground.new, "background/collab/imas", 5 },
    IMAS_CG    = { ImasBackground.new, "background/collab/imas_cg", 3 },
    IMAS_ML    = { ImasBackground.new, "background/collab/imas_ml", 3 },
    IMAS_SIDEM = { ImasSidemBackground.new, "background/collab/imas_sidem", 3 },
    OSHIRI     = { OshiriBackground.new, "background/collab/oshiri", 5 },

    WAIWAI_TAIKO   = { WaiwaiBackground.pack("taiko"), shared = true },
    WAIWAI_A3      = { WaiwaiBackground.pack("a3"), shared = true },
    WAIWAI_I7ID7   = { WaiwaiBackground.pack("i7id7"), shared = true },
    WAIWAI_I7TRI   = { WaiwaiBackground.pack("i7tri"), shared = true },
    WAIWAI_I7REV   = { WaiwaiBackground.pack("i7rev"), shared = true },
    WAIWAI_I7NATSU = { WaiwaiBackground.pack("i7natsu"), shared = true },
}

Background                = {}
Background.__index        = Background

function Background.new(player_num, bpm, scene_preset)
    local self        = setmetatable({}, Background)

    self.player_num   = player_num
    self.bpm          = bpm
    self.scene_preset = scene_preset
    self.is_2p        = (player_num == 3) -- PlayerNum::TWO_PLAYER

    local entry = scene_preset and COLLABS[scene_preset]
    if not entry and scene_preset and scene_preset:find("^WAIWAI_") then
        entry = COLLABS.WAIWAI_TAIKO
    end
    if entry then
        local ctor, path, max_dancers = entry[1], entry[2], entry[3]
        -- Collabs lay out a full-screen 1P stage. In 2P each player gets their own collab
        -- built from the top-band art, and only the bands are drawn, like standard 2P.
        local split = self.is_2p and not entry.shared
        local seat = split and 1 or player_num
        local function make()
            if path then return ctor(seat, bpm, path, max_dancers) end
            return ctor(seat, bpm)
        end
        self.collab = make()
        if split then
            self.collab_2    = make()
            self.p2_y_offset = 536 * tex.get_screen_scale()
        end
    else
        -- Standard (non-collab) case
        local max_dancers = 5
        self.max_dancers  = max_dancers

        if self.is_2p then
            local donbg_index = math.random(1, 6)
            self.donbg_1      = DonBG.create(1, "background", donbg_index)
            self.donbg_2      = DonBG.create(2, "background", donbg_index)
            self.p2_y_offset  = 536 * tex.get_screen_scale()
            self.is_clear_1   = false
            self.is_clear_2   = false
        else
            self.donbg     = DonBG.create(player_num, "background")
            self.bg_normal = BGNormal.create(math.random(0, 4), "background")
            self.bg_fever  = BGFever.create(math.random(0, 3), "background")
            self.fever     = Fever.create(math.random(0, 3), bpm, "background")
            self.dancer    = Dancer.create(math.random(0, 20), bpm, "background", max_dancers)
            self.footer    = Footer.new("background", math.random(0, 2))
        end

        self.renda          = RendaController.new("background", math.random(0, 2))
        self.chibi          = ChibiController.new(bpm, "background")
        self.is_clear       = false
        self.is_rainbow     = false
        self.last_milestone = 1
    end

    return self
end

-- In 2P each player's hits, gauge and miss streak drive their own collab band.
function Background:collab_for(player_num)
    return player_num == 2 and self.collab_2 or self.collab
end

-- a miss streak darkens the donbg band (each player's own band in 2P); collabs that have a
-- miss set of their own (tonkatsudj) take it with handle_miss_streak
function Background:handle_miss_streak(player_num, on)
    local d
    if self.collab then
        local collab = self:collab_for(player_num)
        if collab.handle_miss_streak then return collab:handle_miss_streak(player_num, on) end
        d = collab.donbg
    else
        d = self.is_2p and (player_num == 2 and self.donbg_2 or self.donbg_1) or self.donbg
    end
    if d then d:set_dark(on) end
end

function Background:update(current_ms, bpm)
    self.bpm = bpm
    if self.collab then
        self.collab:update(current_ms, bpm)
        if self.collab_2 then self.collab_2:update(current_ms, bpm) end
    else
        if self.is_2p then
            self.donbg_1:update(current_ms, bpm)
            self.donbg_2:update(current_ms, bpm)
        else
            self.donbg:update(current_ms, bpm)
            self.bg_normal:update(current_ms)
            self.bg_fever:update(current_ms)
            self.fever:update(current_ms, bpm)
            self.dancer:update(current_ms, bpm)
        end
        self.renda:update(current_ms)
        self.chibi:update(current_ms, bpm)
    end
end

function Background:handle_good(player_num)
    if self.collab then
        self:collab_for(player_num):handle_good(player_num)
    else
        self.chibi:add_chibi(player_num, false)
    end
end

function Background:handle_ok(player_num)
    if self.collab then
        self:collab_for(player_num):handle_ok(player_num)
    else
        self.chibi:add_chibi(player_num, false)
    end
end

function Background:handle_bad(player_num)
    if self.collab then
        self:collab_for(player_num):handle_bad(player_num)
    else
        self.chibi:add_chibi(player_num, true)
    end
end

function Background:handle_drumroll(player_num)
    if self.collab then
        self:collab_for(player_num):handle_drumroll(player_num)
    else
        self.renda:add_renda()
    end
end

function Background:handle_balloon(player_num)
    if self.collab then
        self:collab_for(player_num):handle_balloon(player_num)
    else
        self.renda:add_renda()
    end
end

function Background:handle_gauge(player_num, progress, is_clear, is_rainbow)
    if self.collab then
        self:collab_for(player_num):handle_gauge(player_num, progress, is_clear, is_rainbow)
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
        if is_rainbow and not self.is_rainbow then self.fever:start() end
        if not is_rainbow and self.is_rainbow then self.fever:stop() end
        self.is_clear   = is_clear
        self.is_rainbow = is_rainbow

        local md        = self.max_dancers
        local current_milestone
        if is_clear then
            current_milestone = md
        else
            current_milestone = math.min(md - 1, math.floor(progress * md))
        end
        if current_milestone > self.last_milestone then
            for _ = 1, current_milestone - self.last_milestone do self.dancer:add_dancer() end
            self.last_milestone = current_milestone
        elseif current_milestone < self.last_milestone then
            for _ = 1, self.last_milestone - current_milestone do self.dancer:leave_dancer() end
            self.last_milestone = current_milestone
        end
    end
end

function Background:draw_back()
    if require("global.ai_battle").draw_game_bg() then return end   -- Z-DON AI battle: Green's ghost arena
    if self.collab_2 then
        self.collab.donbg:draw(0)
        self.collab_2.donbg:draw(self.p2_y_offset)
    elseif self.collab then
        self.collab:draw_back()
    else
        if not self.is_2p then
            if self.is_clear then
                if not self.bg_fever.transitioned then
                    self.bg_normal:draw()
                    self.bg_fever:draw()
                else
                    self.bg_fever:draw()
                end
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
        if not self.is_2p then
            self.dancer:draw()
            self.footer:draw()
            self.fever:draw()
        end
        self.chibi:draw()
    end
end

function Background:draw_fore()
    if self.collab and not self.collab_2 then
        self.collab:draw_fore()
    end
end

function Background:destroy()
    if self.collab then
        self.collab:destroy()
        if self.collab_2 then self.collab_2:destroy() end
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
        self.chibi:destroy()
    end
end
