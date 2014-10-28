![](https://dl.dropboxusercontent.com/u/364079/arduplot-screenshot.png)

## Ardu plot - plot arduino (serial) telemetry.
This processing sketch plots ASCII-encoded data from the serial port.

### Format:
lines should begin with a 1 character command, followed by whitespace-delimited data

Only the "d" (data) command is required, so for a quick start, just print "d" followed by some numbers from your Arduino, separated by spaces.

### serial commands:

####"d": data.
    numbers, float or int.
    all data must be on one line
    example: "d 1 2.5 3.6319982 0"

####"n": names. (optional)
    strings, in data order
    all names must be on one line
    note: re-send any range & pair data every time names are sent
    example: "n time rate bx by"

####"r": set range.  (optional)
    name min max
    requires columns to be named
    include only the columns to be set to fixed range
    all data not set to a fixed range with this command will be auto-ranged
    multiple column ranges can be listed on the same line
    or with separate "r" commands on separate lines
    example: "r bx -5 5 by -5 5"

####"p": 2d pairs.  (optional)
    pairs of x/y names to bind for 2-d plots.
    requires columns to be named
    multiple pairs can be listed on the same line
    or with separate "p" commands on separate lines
    example: "p bx by"

####"c": colors.  (optional)
     rgb triplets (0-255)
     requires columns to be named
     multiple colors can be listed on the same line
     or with separate "c" commands on separate lines
     example: "c bx 255 0 0 by 0 255 0"

### keyboard commands:
    "r": print ranges.
    "p": toggle pairs.
    "n": toggle names.
    "b": toggle background bars.
    "a": toggle auto-ranging. (can be used to reset ranges)
    ESC: quit.

