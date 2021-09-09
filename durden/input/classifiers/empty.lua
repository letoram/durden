-- local idevice_log, idevice_fmt = suppl_add_logfn("idevice");
-- local touchm_evlog = function(msg)
-- idevice_log("submodule=touch:classifier=empty:" .. msg);
-- end

return
{
empty = {
	init = function(...)
	end,
	label = "Empty",
	description = "Classifier will silently discard all inputs",
	sample = function() end,
	tick = function() end,
	gestures = {},
	menu = nil
}}
