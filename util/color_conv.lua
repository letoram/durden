-- This is a simple stand-alone script for converting json export output
-- from https://terminal.sexy into color-schemes that can be used as part
-- of target/video/color/schemes and global/settings/visual/colors/...

local json = dofile('./json.lua')

if not arg[1] or not arg[2] then
	error("use: color-in.json color-out.lua")
end

file = io.open(arg[1])

local inp = file:read("*all")
local res = json.decode(inp)

local rt =
{
	"{}, -- primary",
	"{}, -- secondary",
	"{}, -- background",
	"{}, -- text",
	"{}, -- cursor",
	"{}, -- alt-cursor",
	"{}, -- highlight",
	"{}, -- label",
	"{}, -- warning",
	"{}, -- error",
	"{}, -- alert",
  "{}, -- reference",
	"{}, -- inactive",
	"{}, -- ui"
}

local term_i = 15
local function getcol(v)
	local r = string.sub(v, 2, 3)
	local g = string.sub(v, 4, 5)
	local b = string.sub(v, 6, 7)
	return {
		tonumber(r, 16),
		tonumber(g, 16),
		tonumber(b, 16)
	}
end

-- 1..16 + foreground and background
for k,v in pairs(res.color) do
	local col = getcol(v)
	table.insert(rt, string.format("{%d, %d, %d},", col[1], col[2], col[3]))
end

if res.foreground then
	local col = getcol(res.foreground)
	table.insert(rt, string.format("{%d, %d, %d},", col[1], col[2], col[3]))
	rt[1] = rt[#rt]

	if res.background then
		local col2 = getcol(res.background)
		table.insert(rt, string.format("{%d, %d, %d},", col2[1], col2[2], col2[3]))
		rt[3] = rt[#rt]
		rt[4] = string.format("{%d, %d, %d, %d, %d, %d},",
			col[1], col[2], col2[3], col2[1], col2[2], col2[3])
	end
end

if res.cursor then
	local col = getcol(res.cursor)
	rt[5] = string.format("{%d, %d, %d},", col[1], col[2], col[3])
	rt[6] = string.format("{%d, %d, %d},", 255 - col[1], 255 - col[2], 255 - col[3])
else
	rt[5] = rt[1]
end

-- auto-assign into labeled slots is worse, some base assumptions might be possible,
-- e.g. error tends to be terminal
--
-- 'red', warning terminal 'yellow', inactive 'dark-grey' and sanity check against
-- fg/bg values. but might as well do this somewhere else
--
-- label (8), warning (9), error (10), alert (11),  ref (12), inactive (13), ui (14)
--
local out = io.output(arg[2])

if res.name then
	out:write("-- scheme: " .. res.name .. "\n")
end

if res.author then
	out:write("-- by: " .. res.author .. "\n")
end

out:write("return {\n")

for _,v in ipairs(rt) do
	out:write(v .. "\n")
end

out:write("}")
out:close()
