--
-- populate res with key = true entries where key corresponds to a valid
-- function or target / menu path that should be accesible for binding via the
-- status-bar %{A format or through the control pipe channel.
--
-- for value path binding e.g. #path/to/somewhere=val, strip the =val part as
-- it is the path that will be evaluated, the normal validator for the path
-- will still be applied for [val]
--
local res = {
	input_lock_on = true,
	input_lock_off = true,
	input_lock_toggle = true
};

return res;
