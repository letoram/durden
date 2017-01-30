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
["caret_home"] = "HOME",
["caret_end"]  = "END",
["caret_left"] = "LEFT",
["caret_right"] = "RIGHT",
["caret_delete"] = "DELETE",
["caret_erase"] = "BACKSPACE"
};

--
-- keys match SYMTABLE(symtable.lua) symbols, with the prefix:
-- m1_ for meta1
-- m2_ for meta2
-- m1_m2_ for meta1+meta2
--
-- The output resolves to an entry in GLOBAL_FUNCTIONS (fglobal.lua) or
-- to a menu path. The GLOBAL_FUNCTIONS approach is slated for deprecation.
--
local tbl = {};
tbl["m1_RETURN"] = "spawn_terminal";
tbl["m1_d"] = "!open/target";
tbl["m1_c"] = "!display/cycle";
tbl["m1_g"] = "global_actions";
tbl["m1_h"] = "target_actions";
tbl["m1_RIGHT"] = "step_right";
tbl["m1_UP"] = "step_up";
tbl["m1_LEFT"] = "step_left";
tbl["m1_DOWN"] = "step_down";
tbl["m1_m2_d"] = "destroy";
tbl["m1_v"] = "clipboard_paste";
tbl["m1_m2_LEFT"] = "shrink_h";
tbl["m1_m2_RIGHT"] = "grow_h";
tbl["m1_m2_UP"] = "shrink_v";
tbl["m1_m2_DOWN"] = "grow_v";
tbl["m1_m2_h"] = "swap_left";
tbl["m1_m2_j"] = "swap_up";
tbl["m1_m2_k"] = "swap_down";
tbl["m1_m2_l"] = "swap_right";
tbl["m1_m2_TAB"] = "tiletog";
tbl["m1_t"] = "tab";
tbl["m1_m2_t"] = "vtab";
tbl["m1_r"] = "fullscreen";
tbl["m1_m2_y"] = "float";
tbl["m1_m"] = "mergecollapse";
tbl["m2_LEFT"] = "move_nx";
tbl["m2_RIGHT"] = "move_px";
tbl["m2_UP"] = "move_ny";
tbl["m2_DOWN"] = "move_py";
tbl["m1_1"] = "switch_ws1";
tbl["m1_2"] = "switch_ws2";
tbl["m1_3"] = "switch_ws3";
tbl["m1_4"] = "switch_ws4";
tbl["m1_5"] = "switch_ws5";
tbl["m1_6"] = "switch_ws6";
tbl["m1_7"] = "switch_ws7";
tbl["m1_8"] = "switch_ws8";
tbl["m1_9"] = "switch_ws9";
tbl["m1_0"] = "switch_ws10";
tbl["m1_m2_r"] = "rename_space";
tbl["m1_m2_1"] = "assign_ws1";
tbl["m1_m2_2"] = "assign_ws2";
tbl["m1_m2_3"] = "assign_ws3";
tbl["m1_m2_4"] = "assign_ws4";
tbl["m1_m2_5"] = "assign_ws5";
tbl["m1_m2_6"] = "assign_ws6";
tbl["m1_m2_7"] = "assign_ws7";
tbl["m1_m2_8"] = "assign_ws8";
tbl["m1_m2_9"] = "assign_ws9";
tbl["m1_m2_0"] = "assign_ws10";

return tbl;
