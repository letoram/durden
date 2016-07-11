Game Device
============

These configuration files are lua scripts that are loaded/scanned once
on startup. They are expected to return an identity string, a platform
string two functions and two tables like this:

    return "My Game Device", "linux", function(subid)
		    return "BUTTON" .. tostring(subid);
	  end, function (subid)
		    return "AXIS" .. tostring(subid+5), 1;
		end,
		{7,8,9}, {1, 4, 7};

Where the string identifies the device (new devices are matched against
this string), the platform string specifies the input platform for where
this is valid (the mapping can change between OSes and input platforms),
the two functions are invoked to translate a subid to a valid BUTTONn
and AXISn stringl, and the two tables are blacklisted digital and analog
input subids to filter as early as possible.

Easiest way to find the IDs to use for remapping is to run the
tests/interactive/eventtest helper appl.
