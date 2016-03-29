-- the device maps are somewhat simpler than keymaps in that we do not support
-- n- states (press a then dash and merge into..) or state modifiers [btn1+btn2]
-- but only a translation [SLOT(1), SUBID(4)] into something like PLAYER1_UP

local remap_tbl = {};
remap_tbl[27] = "START";
remap_tbl[26] = "SELECT";
remap_tbl[67] = "UP";
remap_tbl[66] = "DOWN";
remap_tbl[64] = "LEFT";
remap_tbl[65] = "RIGHT";
remap_tbl[16] = "BUTTON1";
remap_tbl[17] = "BUTTON2";
remap_tbl[20] = "BUTTON3";
remap_tbl[19] = "BUTTON4";
remap_tbl[22] = "BUTTON5";
remap_tbl[67] = "BUTTON6";
remap_tbl[66] = "BUTTON7";
remap_tbl[28] = "BUTTON8";
remap_tbl[3] = "1";
remap_tbl[2] = "2";
remap_tbl[5] = "3";

return "RedOctane Guitar Hero X-plorer", "linux",
function(subid)
	return remap_tbl[subid] and remap_tbl[subid] or "BUTTON" .. tostring(subid);
end,
-- returns two arguments, label and sample scale factor
function(subid)
	return "AXIS" .. tostring(subid+1), 1;
end
