--
-- This file can be added to run custom commands at startup,
-- and more advanced such commands in particular as the others can
-- be defined interactively through the autostart tool.
--
-- helpful commands:
--
-- timer_add_idle(name (text), value (seconds), once (bool), enterfn, exitfn)
-- timer_add_periodic(name, delay, once (bool), commandfn)
--

-- run user defined autostart items
dispatch_symbol("/global/settings/tools/autostart/run");
