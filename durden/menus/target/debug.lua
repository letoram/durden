local function query_tracetag()
	local bar = tiler_lbar(active_display(), function(ctx,msg,done,set)
		if (done and active_display().selected) then
			image_tracetag(active_display().selected.canvas, msg);
		end
		return {};
	end);
	bar:set_label("tracetag (wnd.canvas):");
end

return {
	{
		name = "query_tracetag",
		label = "Tracetag",
		kind = "action",
		handler = query_tracetag
	}
};
