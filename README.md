![](https://dl.dropboxusercontent.com/u/364079/arduplot-screenshot.png)

## Ardu plot - plot arduino (serial) telemetry.
This processing sketch plots ASCII-encoded data from the serial port.

### Format:
lines should begin with a 1 character command, followed by tab-delimited data

### serial commands:

####"d": data.
    tab-delimited numbers, in column order.  floating point or integer.
    all column data must be on one line
    "d   1   2.5   3.6319982   0"

####"n": names. (optional)
    tab-delimited strings, in column order, e.g.:
    all names must be on one line
    note: re-send any range & pair data every time names are sent
    "n   time   rate   bx   by"        ('n\tax\tay\tbx\tby')

####"r": set range.  (optional)
    tab-delimited triplets: name min max
    requires columns to be named
    include only the columns to be set to limited range
    all columns not set will be auto-ranged
    multiple column ranges can be listed on the same line
    or with separate "r" commands on separate lines
    "r   bx   -5   5   by   -5   5"

####"p": 2d pairs.  (optional)
    tab-delimited pairs of x/y names to bind for 2-d plots.
    requires columns to be named
    multiple pairs can be listed on the same line
    or with separate "p" commands on separate lines
    "p   bx   by"

### keyboard commands:
    "r": print ranges.
    "p": toggle pairs.
    "n": toggle names.
    "b": toggle background bars.
    ESC: quit.


### TODO:
- add port/baud selection UI on startup, that would be rad
