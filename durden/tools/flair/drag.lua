local effects = {};
local cloth = system_load("tools/flair/cloth.lua")();
if (cloth) then
	table.insert(effects, cloth);
end

return effects;
