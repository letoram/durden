-- the device maps are somewhat simpler than keymaps in that we do not support
-- n- states (press a then dash and merge into..) or state modifiers [btn1+btn2]
-- but only a translation [SLOT(1), SUBID(4)] into something like PLAYER1_UP

local remap_tbl = {};
remap_tbl[27] = "START";
remap_tbl[26] = "SELECT";
remap_tbl[66] = "UP";
remap_tbl[67] = "DOWN";
remap_tbl[64] = "LEFT";
remap_tbl[65] = "RIGHT";
remap_tbl[19] = "BUTTON1";
remap_tbl[20] = "BUTTON2";
remap_tbl[17] = "BUTTON3";
remap_tbl[16] = "BUTTON4";
remap_tbl[22] = "BUTTON5";
remap_tbl[23] = "BUTTON6";
remap_tbl[29] = "BUTTON7";
remap_tbl[30] = "BUTTON8";
remap_tbl[28] = "BUTTON9";

-- axis
remap_tbl[0] = "1";
remap_tbl[1] = "2";
remap_tbl[2] = "5";
remap_tbl[3] = "3";
remap_tbl[4] = "4";
remap_tbl[5] = "6";

return "Microsoft X-Box 360 pad", "linux",
function(subid)
	return remap_tbl[subid] and remap_tbl[subid] or "BUTTON" .. tostring(subid);
end,
-- returns two arguments, label and sample scale factor
function(subid)
	return "AXIS" .. remap_tbl[subid] and remap_tbl[subid] or tostring(subid);
end
