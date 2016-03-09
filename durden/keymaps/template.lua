--
-- example of keymaps that symtable.lua should be able to load / handle
-- (template.lua as a name is reserved and will be ignored unless a
-- higher debuglevel is set.
--
-- this format does not support hybrid tables (i.e. merging
-- hierarchical keymaps like linux would support.
--
-- expected:
-- name (identifier, match filename.lua without the extension)
-- dctbl = (n- sequences, array of 'meta_subid' where
--           the last element is utf-8)
--
-- platform_flt, return true or false if the map applies to the
--               current API_ENGINE_BUILD or not
--
-- map[modifiers][subid] = utf-8 sequence.
-- where modifiers correspond to doing
--  * concat(decode_modifiers(iotbl.modifers), '_')
--
-- except for modifiers == 0 that gets mapped to 'plain'.
--
--

local restbl = {
	dctind = {},
	dctbl = {},
	map = {
		plain = {
		}
	},

-- platform_flt will provide some dscription string for the current
-- input platform (use API_ENGINE_BUILD global), only return true
-- if the table works
	platform_flt = function(tbl, str)
		return string.match(str, "sdl") ~= nil;
	end
};

if (DEBUGLEVEL > 1) then
	restbl.name = "template";
end

return restbl;
