local function global_valid01_uri(str)
	return true;
end

-- Stub for now
local toplevel = {
	{
		name = "open",
		label = "Open",
		kind = "string",
		validator = global_valid01_uri,
		handler = function(ctx, value)
			warning("launch missing");
		end
	},
	{
		name = "workspace",
		label = "Workspace",
		kind = "action",
		handler = function(ctx, value)
			warning("spawn workspace menu");
		end
	},
	{
		name = "display",
		label = "Display",
		kind = "action",
		handler = function(ctx, value)
			warning("spawn display menu");
		end
	},
	{
		name = "audio",
		label = "Audio",
		kind = "action",
		handler = function(ctx, value)
			warning("spawn audio menu");
		end
	},
	{
		name = "input",
		label = "Input",
		kind = "action",
		handler = function(ctx, value)
			warning("spawn input menu");
		end
	},
	{
		name = "system",
		label = "System",
		kind = "action",
		handler = function(ctx, value)
			warning("spawn system menu");
		end
	},
};

return {
	init = shared_init,
	bindings = {},
	actions = toplevel,
	settings = {},
};
