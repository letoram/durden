return {
-- background, can't be swapped in and at the end of the viewport
"layers/add=bg",
"layers/layer_bg/settings/depth=99.0",
"layers/layer_bg/settings/radius=99.0",
"layers/layer_bg/settings/fixed=true",
"layers/layer_bg/settings/ignore=true",
"layers/layer_bg/add_model/sphere=bg",
"layers/layer_bg/models/bg/source=park.png",

-- allow a temporary override of the source using the 360bg connpoint
"layers/layer_bg/models/bg/connpoint/temporary=360bg",

-- an interactive foreground layer with a transparent terminal
"layers/add=fg",
"layers/layer_fg/terminal=bgalpha=128",

-- and a hidden model that only gets activated on client connect/disconnect and uses side by side
--"layers/layer_fg/add_model/rectangle=sbsvid",
--"layers/layer_fg/models/sbsvid/connpoint/reveal=sbsvid",
--"layers/layer_fg/models/sbsvid/stereoscopic=sbs"
};
