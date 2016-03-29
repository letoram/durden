-- the device maps are somewhat simpler than keymaps in that we do not support
-- n- states (press a then dash and merge into..) or state modifiers [btn1+btn2]
-- but only a translation [SLOT(1), SUBID(4)] into something like PLAYER1_UP

local remap_tbl = {};
remap_tbl[3] = "START";
remap_tbl[0] = "SELECT";
remap_tbl[4] = "UP";
remap_tbl[6] = "DOWN";
remap_tbl[7] = "LEFT";
remap_tbl[5] = "RIGHT";
remap_tbl[15] = "BUTTON1";
remap_tbl[12] = "BUTTON2";
remap_tbl[13] = "BUTTON3";
remap_tbl[14] = "BUTTON4";
remap_tbl[10] = "BUTTON5";
remap_tbl[11] = "BUTTON6";
remap_tbl[1] = "BUTTON7";
remap_tbl[2] = "BUTTON8";
remap_tbl[8] = "BUTTON9";
remap_tbl[9] = "BUTTON10";
remap_tbl[416] = "BUTTON11";

return "Sony PLAYSTATION(R)3 Controller", "linux",
function(subid)
	return remap_tbl[subid] and remap_tbl[subid] or "BUTTON" .. tostring(subid);
end,
-- returns two arguments, label and sample scale factor
function(subid)
	return "AXIS" .. tostring(subid+1), 1;
end
