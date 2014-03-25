/*
Ardu plot - plot arduino (serial) telemetry.
This processing sketch plots ASCII-encoded data from the serial port.

Format:
lines should begin with a 1 character command, followed by tab-delimited data

commands:
"d": data.  tab-delimited numbers, in column order.  floating point or integer.
     all column data must be on one line
     "d   1   2.5   3.6319982   0"
"n": names. (optional) tab-delimited strings, in column order, e.g.:
     all names must be on one line
     note: re-send any range & pair data every time names are sent
     "n   time   rate   bx   by"        ('n\tax\tay\tbx\tby')
"r": set range.  (optional) tab-delimited triplets: name min max
     requires columns to be named
     include only the columns to be set to limited range
     all columns not set will be auto-ranged
     multiple column ranges can be listed on the same line
     or with separate "r" commands on separate lines
     "r   bx   -5   5   by   -5   5"
"p": 2d pairs.  tab-delimited pairs of x/y names to bind for 2-d plots.
     requires columns to be named
     multiple pairs can be listed on the same line
     or with separate "p" commands on separate lines
     "p   bx   by"
*/

import processing.serial.*;

Serial myPort = null;        // The serial port

//----------------------------------------------------------------------
public class Column {
  String name;
  float[] data;
  float x0, x1, y0, y1;
  boolean doAutoRange;

  public Column() {
    name = "";

    data = new float[width];

    x0 = 0;
    x1 = width;
    y0 = Float.POSITIVE_INFINITY;
    y1 = Float.NEGATIVE_INFINITY;

    doAutoRange = true;
  }
}

//----------------------------------------------------------------------
public class Graph {
  Column[] columns;

  //----------------------------------------
  public Graph() {
    columns = new Column[0];
  }

  //----------------------------------------
  // reset number of columns to n
  void resetColumns(int n) {
    columns = new Column[n];
    for (int i = 0; i < n; i++) {
      columns[i] = new Column();
    }
  }
  
  //----------------------------------------
  void parseNames(String[] names) {
    if (names.length != columns.length) {
      resetColumns(names.length);
    }
    
    for (int i = 0; i < names.length; i++) {
      columns[i].name = names[i];
    }
  }

  //----------------------------------------
  void parseData(String[] stringData) {
    if (stringData.length != columns.length) {
      resetColumns(stringData.length);
    }

    for (int column = 0; column < columns.length; column++) {
      Column c = columns[column];
      
      // shift data over by one, make room for a new datum
      System.arraycopy(c.data, 1, c.data, 0, width-1);

      float n = 0;
      try {
        n = Float.parseFloat(stringData[column]);
      } catch (Exception e) {
      }
      c.data[width-1] = n;
      if (c.doAutoRange) {
        if (n < c.y0) c.y0 = n;
        if (n > c.y1) c.y1 = n;
      }
    }
  }
  
  //----------------------------------------
  void parseRange(String[] ranges) {
    if ((ranges.length % 3) != 0) {
      println("RANGE: bad format");
      return;
    }
    for (int i = 0; i < ranges.length; i += 3) {
      boolean rangeSet = false;
      for (int c = 0; c < columns.length; c++) {
        if (ranges[i].equals(columns[c].name)) {
          try {
            columns[c].y0 = Float.parseFloat(ranges[i+1]);
            columns[c].y1 = Float.parseFloat(ranges[i+2]);
          } catch (Exception e) {
          }
          rangeSet = true;
          columns[c].doAutoRange = false;
          println(String.format("range: set '%s' to %s..%s", ranges[i], ranges[i+1], ranges[i+2]));
          break;
        }
      }
      if (!rangeSet) {
        println(String.format("range: couldn't find a column named '%s'", ranges[i]));
      }
    }
  }

  //----------------------------------------
  void draw() {
    noSmooth();
    textAlign(LEFT);

    if (columns.length < 1) return;
    
    float dY = height / columns.length;
    float px, py;
    float nx, ny;

    for (int column = 0; column < columns.length; column++) 
    {
      Column c = columns[column];
      float dY0 = dY*column;
      float dY1 = dY*(column+1);
      
      // draw some background blocks to distinguish columns
      if (column % 2 == 1) {
        fill(255,255,255,32);
        noStroke();
        rect(0, dY0, width, dY);
      }
      
      // display the column name
      fill(200);
      text(c.name, 10, dY1);

      // plot the data
      stroke(255);
      noFill();
      px = 0;
      py = map(c.data[0], c.y0, c.y1, dY0, dY1);
      for (int i = 1; i < width; i++)
      {
        nx = i;
        ny = map(c.data[i], c.y0, c.y1, dY0, dY1);
        line(px, py, nx, ny);
        px = nx;
        py = ny;
      }
    }
  }
}

Graph graph = new Graph();

//----------------------------------------------------------------------
void setup () {
  // set the window size:
  size(848, 636);        

  // List all the available serial ports
  println(Serial.list());
  // I know that the first port in the serial list on my mac
  // is always my  Arduino, so I open Serial.list()[0].
  // Open whatever port is the one you're using.
  
  for (String port : Serial.list())
  {
    println(port);
    if (port.toLowerCase().contains("tty.usbmodem"))
    {
      print("Got it!\n");
      myPort = new Serial(this, port, 115200);
      break;
    }
  }
  println("");
  
  if (myPort == null) {
    println("I have failed to initialize a serial port.  Bailing out.");
    System.exit(0);
  }
  
  // don't generate a serialEvent() unless you get a newline character:
  myPort.bufferUntil('\n');
  // set inital background:
  background(0);
  print("READY\n");
}


//----------------------------------------------------------------------
void draw () {  
  // new data happens in the serialEvent()

  background(0);
  graph.draw();
}


//----------------------------------------------------------------------
void serialEvent (Serial myPort) {
  // get the ASCII string:
  String inString;
  try {
    inString = myPort.readStringUntil('\n');
    if (inString == null) return;
  } catch (Exception e) {
    // do nothing on error
    return;
  }

  // trim whitespace:
  inString = trim(inString);
  
  // split on tabs
  if (!inString.contains("\t")) return;
  String[] tokens = inString.split("\t");
  if (tokens.length < 1) return;

  int datalen = tokens.length - 1;
  String[] stringData = new String[datalen];
  System.arraycopy(tokens, 1, stringData, 0, datalen);

  char cmd = tokens[0].charAt(0);
  
  switch(cmd) {
    case 'n':
      graph.parseNames(stringData);
      println(String.format("Got NAMES: %s", inString));
      break;
    case 'd':
      graph.parseData(stringData);
      break;
    case 'r':
      graph.parseRange(stringData);
      break;
    default:
      println(String.format("unknown command %s", tokens[0]));
      return;
  }
  
  redraw();
}
