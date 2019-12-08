meta_guard_reset(true)

-- normally, add would query for a bind, don't want that to happen
dispatch_bindtarget("/target/window/destroy");
dispatch_symbol("/global/settings/titlebar/buttons/left/add=icon_destroy");

dispatch_bindtarget("/target/window/minimize");
dispatch_symbol("/global/settings/titlebar/buttons/left/add_float=icon_minimize");

dispatch_bindtarget("/target/window/move_resize/maximize");
dispatch_symbol("/global/settings/titlebar/buttons/left/add_float=icon_maximize");

-- terminal icon with a popup that also allows access to other menus
dispatch_bindtarget("/global/open/terminal");
dispatch_symbol("/global/settings/statusbar/buttons/left/add=icon_cli");

dispatch_bindtarget("/global/tools/popup/menu=/menus/cli_icon");
dispatch_symbol("/global/settings/statusbar/buttons/left/extend/alternate_click/1");
