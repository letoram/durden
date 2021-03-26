-- entries marked foreground/background takes 6 values (fr, fg, fb, br, gb, bb)
-- tui clients will use first set, terminal clients second, entries with an empty
-- or nil table will retain whatever client default is

return {
 {0xa8, 0x99, 0x84}, -- primary (base color/foreground)
 {}, -- secondary (alternate base color)
 {0x28, 0x28, 0x28}, -- background
 {}, -- text (foreground+background)
 {}, -- cursor (normal state)
 {}, -- alt-cursor (scrollback/special state)
 {}, -- highlight selection, active-word (foreground+background)
 {}, -- label    : prompts, data labels (foreground+background)
 {}, -- warning  : alert user but non-fatal (foreground+background)
 {}, -- error    : alert user, requires action (foreground+background)
 {}, -- alert    : alert user, immediate input / action (foreground+background)
 {}, -- ref      : urls, file-paths, ... (foreground + background)
 {}, -- inactive : inaccessible element (foreground + background)
 {}, -- ui       : generic UI elements like menubar

-- terminal clients below --
 {0x28, 0x28, 0x28}, -- black
 {0xcc, 0x24, 0x1d}, -- red
 {0x98, 0x97, 0x1a}, -- green
 {0xd7, 0x99, 0x21}, -- yellow
 {0x45, 0x85, 0x88}, -- blue
 {0xb1, 0x62, 0x86}, -- magenta
 {0x68, 0x9d, 0x6a}, -- cyan
 {0xa8, 0x99, 0x84}, -- light-grey
 {0x92, 0x83, 0x74}, -- dark-grey
 {0xfb, 0x49, 0x34}, -- light-red
 {0xb8, 0xbb, 0x26}, -- light-green
 {0xfa, 0xbd, 0x2f}, -- light-yellow
 {0x83, 0xa5, 0x98}, -- light-blue
 {0xd3, 0x86, 0x9b}, -- light-magenta
 {0x8e, 0xc0, 0x7c}, -- light-cyan
 {0xeb, 0xdb, 0xb2}, -- white

 {0xa8, 0x99, 0x84}, -- foreground
 {0x28, 0x28, 0x28}, -- background
}
