Display
=======

These device configurations files are simply lua scripts that will be
scanned once upon startup. They are used for initial configuration of
devices where autodetection is wrong or you may want special treatment
in regards to window manager, synchronization or density.

The scripts are expected to return a table with the following fields:

(obligatory)
 name (string) = 'identifier' : used for scripting / logging reference
 ident (string) = 'pattern' : name can be found in global/display/displays and
                              is the first part followed by / and then the
															serial.

the following optional fields will be used when found:
 wm (string) = 'ignore'    : specify how the display should be treated,
                             currently accepted values:
														 ignore - never use this display
														 tiler - tiling window manager (default)

                             will be expanded later to support displays dedicated
														 for media output, VR compositing, etc.

 ppcm (number) : specify pixels per centimers
 width (number) : try to pick a mode that match this width
 height (number) : try to pick a mode that match this height

