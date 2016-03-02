--
-- example of keymaps that symtable.lua can load and handle,
-- (template.lua as a name is reserved and will be ignored
-- unless a higher debuglevel is set.
--
-- this format does not support hybrid tables (i.e. merging
-- hierarchical keymaps like linux would support.
--

--
-- this test map, "just" implements one diacretic,
-- one modifier dependent triacretic sequence and one
-- normal sdl symbol remapping.
--
--  A + B will yield (1), z
--  A + shift-B + C will yield (2), x that requires a flush
--  which when flush will return y.
--

local restbl = {
	dctind = {},
	dctbl = {

	},

-- platform_flt will provide some dscription string for the current
-- input platform (use API_ENGINE_BUILD global), only return true
-- if the table works
	platform_flt = function(tbl, str)
		return string.match(str, "sdl") ~= nil;
	end,

-- return the modified iotbl and a number indicating additional
-- states to flush with the same table, use like:
-- local a, b = tbl:map_translate(iotbl);
-- if (a) -> deal with output (or output is buffered) OR
-- if (b > 1) then
--  run tbl:flush();
-- end
	map_translate = function(tbl, iotbl)
		if (not iotbl.translated or not iotbl.active) then
			return iotbl, 0;
		end

	end,

	flush = function(tbl, iotbl)
		return nil;
	end,

-- empty arg, reset internal states and return table specific indicator
-- state arg then return current state and replace with tbl, this is
-- used for wm to retain state when window focus changes.
	state_rst = function(tbl, state)
		return tbl.dctind;
	end,
};

return restbl;
