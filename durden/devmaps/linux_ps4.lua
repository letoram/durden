-- the device maps are somewhat simpler than keymaps in that we do not support
-- n- states (press a then dash and merge into..) or state modifiers [btn1+btn2]
-- but only a translation [SLOT(1), SUBID(4)] into something like PLAYER1_UP

local remap_tbl = {};
remap_tbl[65251] = "START";
remap_tbl[65248] = "SELECT";
remap_tbl[66] = "UP";
remap_tbl[67] = "DOWN";
remap_tbl[64] = "LEFT";
remap_tbl[65] = "RIGHT";
remap_tbl[16] = "BUTTON1";
remap_tbl[19] = "BUTTON2";
remap_tbl[18] = "BUTTON3";
remap_tbl[17] = "BUTTON4";
remap_tbl[20] = "BUTTON5";
remap_tbl[21] = "BUTTON6";
remap_tbl[26] = "BUTTON7";
remap_tbl[27] = "BUTTON8";
remap_tbl[28] = "BUTTON9";
remap_tbl[22] = "BUTTON10";
remap_tbl[23] = "BUTTON11";
remap_tbl[0] = "1";
remap_tbl[1] = "2";
remap_tbl[2] = "3";
remap_tbl[5] = "4";
remap_tbl[3] = "5";
remap_tbl[4] = "6";

return "Sony Computer Entertainment Wireless Controller", "linux",
function(subid)
	return remap_tbl[subid] and remap_tbl[subid] or "BUTTON" .. tostring(subid);
end,
-- returns two arguments, label and sample scale factor
function(subid)
	return "AXIS" .. tostring(subid+1), 1; -- maybe expose range and zones here
end,
{}, -- blacklist buttons
{} -- blacklist analog
