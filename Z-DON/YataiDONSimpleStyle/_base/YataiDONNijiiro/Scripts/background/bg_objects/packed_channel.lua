-- A channel of an exported cabinet movie (bg_data/bg_anim, bg_data/donbg_anim) at loop frame i
-- (1-based). A channel is a number (constant), a table with one value per frame, or a packed
-- table {base, step, width, digits}: value = base + step * n, n being frame i's `width` chars of
-- `digits` in base 92 (printable ASCII without '"' and '\'). The packed form compiles several
-- times faster than a table of numbers and takes a fraction of the memory.
-- Written by scratchpad/arcade_collab/pack_channels.py.
local byte = string.byte

local DIGIT = {}
do
    local d = 0
    for c = 33, 126 do
        if c ~= 34 and c ~= 92 then
            DIGIT[c] = d
            d = d + 1
        end
    end
end

return function(v, i)
    if type(v) == "number" then return v end
    local s = v[4]
    if type(s) ~= "string" then return v[i] end   -- a plain table: one value per frame
    local w = v[3]
    local p = (i - 1) * w
    local n = DIGIT[byte(s, p + 1)]
    for k = p + 2, p + w do n = n * 92 + DIGIT[byte(s, k)] end
    return v[1] + v[2] * n
end
