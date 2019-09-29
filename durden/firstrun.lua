meta_guard_reset(true)

-- normally, add would query for a bind, don't want that to happen
dispatch_bindtarget("/target/window/destroy");
dispatch_symbol("/global/settings/titlebar/buttons/left/add=icon_destroy");

dispatch_bindtarget("/target/window/hide");
dispatch_symbol("/global/settings/titlebar/buttons/left/add_float=icon_minimize");

dispatch_bindtarget("/target/window/move_resize/maximize");
dispatch_symbol("/global/settings/titlebar/buttons/left/add_float=icon_maximize");
