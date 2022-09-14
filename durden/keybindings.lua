--
-- Default Keybindings
--
-- These are >static defaults< meaning that they can be overridden at runtime
-- and by the custg_ custk_ k/v pairs in the appl database config
--

--
-- System keys are special in that they are checked for collisions when
-- binding, hence should be kept to an absolute minimum. They are used for
-- durden- UI components specific interaction.
--
SYSTEM_KEYS = {
["meta_1"] = "MENU",
["meta_2"] = "RSHIFT",
["accept"] = "RETURN",
["cancel"] = "ESCAPE",
["next"] = "UP",
["previous"] = "DOWN",
["home"] = "HOME",
["end"]  = "END",
["left"] = "LEFT",
["right"] = "RIGHT",
["delete"] = "DELETE",
["erase"] = "BACKSPACE"
};

--
-- keys match SYMTABLE(symtable.lua) symbols, with the prefix:
-- m1_ for meta1
-- m2_ for meta2
-- m1_m2_ for meta1+meta2
--
-- Multiple paths can also be bound, with $ as start symbol and linefeed
-- as separator, for instance:
-- $/global/open/terminal\n/global/open/terminal
--
-- would spawn two terminals
--
local tbl = {};
tbl["m1_RETURN"] = "/global/open/terminal";
tbl["m1_m2_RETURN"] = "/global/open/lash";
tbl["m1_d"] = "/global/open/target";
tbl["m1_c"] = "/global/display/cycle";
tbl["m1_g"] = "/global";
tbl["m1_h"] = "/target";
tbl["m1_?"] = "/global/input/bind";
tbl["m1_mouse1_3"] = "/target/clipboard/paste";
tbl["m1_RIGHT"] = "/target/window/select/right";
tbl["m1_UP"] = "/target/window/select/up";
tbl["m1_LEFT"] = "/target/window/select/left";
tbl["m1_DOWN"] = "/target/window/select/down";
tbl["m1_m2_d"] = "/target/window/destroy";
tbl["m1_v"] = "/target/clipboard/paste";
tbl["m1_m2_LEFT"] = "/target/window/move_resize/resize_h=-0.1";
tbl["m1_m2_RIGHT"] = "/target/window/move_resize/resize_h=0.1";
tbl["m1_m2_UP"] = "/target/window/move_resize/resize_v=-0.1";
tbl["m1_m2_DOWN"] = "/target/window/move_resize/resize_v=0.1";
tbl["m2_h"] = "/target/window/swap/left";
tbl["m2_j"] = "/target/window/swap/up";
tbl["m2_k"] = "/target/window/swap/down";
tbl["m2_l"] = "/target/window/swap/right";
tbl["m1_m2_TAB"] = "/global/workspace/layout/tile_toggle";
tbl["m1_t"] = "/global/workspace/layout/tab";
tbl["m1_m2_t"] = "/global/workspace/layout/vtab";
tbl["m1_TAB"] = "/global/workspace/select/next";
tbl["m1_r"] = "/target/window/move_resize/fullscreen";
tbl["m1_m"] = "/target/window/swap/merge_collapse";
tbl["m2_LEFT"] = "/target/window/move_resize/rel_fx=-0.05";
tbl["m2_RIGHT"] = "/target/window/move_resize/rel_fx=0.05";
tbl["m2_UP"] = "/target/window/move_resize/rel_fy=-0.05";
tbl["m2_DOWN"] = "/target/window/move_resize/rel_fy=0.05";
tbl["m1_1"] = "/global/workspace/switch/switch_1";
tbl["m1_2"] = "/global/workspace/switch/switch_2";
tbl["m1_3"] = "/global/workspace/switch/switch_3";
tbl["m1_4"] = "/global/workspace/switch/switch_4";
tbl["m1_5"] = "/global/workspace/switch/switch_5";
tbl["m1_6"] = "/global/workspace/switch/switch_6";
tbl["m1_7"] = "/global/workspace/switch/switch_7";
tbl["m1_8"] = "/global/workspace/switch/switch_8";
tbl["m1_9"] = "/global/workspace/switch/switch_9";
tbl["m1_0"] = "/global/workspace/switch/switch_10";
tbl["m1_m2_r"] = "/global/workspace/rename";
tbl["m1_m2_1"] = "/target/window/reassign/reassign_1";
tbl["m1_m2_2"] = "/target/window/reassign/reassign_2";
tbl["m1_m2_3"] = "/target/window/reassign/reassign_3";
tbl["m1_m2_4"] = "/target/window/reassign/reassign_4";
tbl["m1_m2_5"] = "/target/window/reassign/reassign_5";
tbl["m1_m2_6"] = "/target/window/reassign/reassign_6";
tbl["m1_m2_7"] = "/target/window/reassign/reassign_7";
tbl["m1_m2_8"] = "/target/window/reassign/reassign_8";
tbl["m1_m2_9"] = "/target/window/reassign/reassign_9";
tbl["m1_m2_10"] = "/target/window/reassign/reassign_10";

return tbl;
