-- icon set definition format
--
-- indexed by unique identifier, referenced with icon_ prefix
-- search path is prefixed icons/setname (same as lua file)
--
-- source to the synthesizers and builtin shaders are in icon.lua
--
-- 1. static image:
-- ["myicon"] = {
-- [24] = "myicon_24px.png",
-- [16] = "myicon_16px.png"
-- }
--
-- 2. postprocessed (custom color, SDFs, ...)
-- ["myicon"] = {
-- [24] = function()
--	return icon_synthesize_src("myicon_24px.png", 24,
--	   icon_colorize, {color = {"fff", 1.0, 0.0, 0.0}});
-- end
-- }
--
-- 3. synthesized
-- ["myicon"] = {
--   icon_unit_circle, {radius = {"f", 0.5}, color = {"fff", 1.0, 0.0, 0.0}})
--
--
return {
["terminal"] =
{
	[24] = {
		"terminal_24.png",
	}
}
};
