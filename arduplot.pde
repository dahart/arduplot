/*
Ardu plot - plot arduino (serial) telemetry.

This program takes ASCII-encoded strings from the serial port,
and plots them using Processing.

Format:
lines should begin with a 1 character command, followed by tab-delimited data

commands:
"n": names. tab-delimited strings, in column order, e.g.:
     all names must be on one line
     note: re-send any range & pair data every time names are sent
     "n   time   rate   bx   by"        ('n\tax\tay\tbx\tby')
"r": set range.  tab-delimited triplets: name min max
     include only the columns to be set to limited range
     all columns not set will be auto-ranged
     multiple column ranges can be listed on the same line
     or with separate "r" commands on separate lines
     "r   bx   -5   5   by   -5   5"
"p": 2d pairs.  tab-delimited pairs of x/y names to bind for 2-d plots.
     multiple pairs can be listed on the same line
     or with separate "p" commands on separate lines
     "p   bx   by"
"d": data.  tab-delimited numbers, in column order.  floating point or integer.
     all column data must be on one line
     "d   1   2.5   3.6319982   0"
*/

import processing.serial.*;

Serial myPort = null;        // The serial port
int xPos = 1;         // horizontal position of the graph

//----------------------------------------------------------------------
public class Column {
  String name;
  float[] data;
  float x0, x1, y0, y1;
  boolean doAutoRange;

  public Column(String iname) {
    name = iname;

    data = new float[width];
    for (int i = 0; i < width; i++) data[i] = 0.0;

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
  void parseNames(String[] names) {
    if (names.length != columns.length) {
      columns = new Column[names.length];
      for (int i = 0; i < names.length; i++) {
        columns[i] = new Column(names[i]);
      }
    }
  }

  //----------------------------------------
  void parseData(String[] stringData) {
    if (stringData.length != columns.length) return;

    for (int column = 0; column < columns.length; column++) {
      Column c = columns[column];
      
      // shift data over by one, make room for a new datum
      System.arraycopy(c.data, 1, c.data, 0, width-1);

      float n = Float.parseFloat(stringData[column]);
      c.data[width-1] = n;
      if (c.doAutoRange) {
        if (n < c.y0) c.y0 = n;
        if (n > c.y1) c.y1 = n;
      }
    }
  }

  //----------------------------------------
  void draw() {
    stroke(255);

    if (columns.length < 1) return;
    
    print(String.format("height: %d", height));
    print(String.format("N: %d", columns.length));
    float dY = height / columns.length;
    print(String.format("dY: %f", dY));

    for (int column = 0; column < columns.length; column++) {
      Column c = columns[column];
      for (int i = 1; i < width; i++)
      {
        float x0 = i-1;
        float x1 = i;
        float y0 = map(c.data[i-1], c.y0, c.y1, dY*column, dY*(column+1));
        float y1 = map(c.data[i  ], c.y0, c.y1, dY*column, dY*(column+1));
        line(x0, y0, x1, y1);
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
  String inString = "";
  try {
    inString = myPort.readStringUntil('\n');
  } catch (Exception e) {
    // do nothing on error
    return;
  }

  if (inString == null) return;
  
  // trim whitespace:
  inString = trim(inString);
  
  // split on tabs
  String[] tokens = inString.split("\t");
  if (tokens.length < 1) return;

  int datalen = tokens.length - 1;
  String[] stringData = new String[datalen];
  System.arraycopy(tokens, 1, stringData, 0, datalen);

  char cmd = tokens[0].charAt(0);
  
  switch(cmd) {
    case 'n':
      graph.parseNames(stringData);
      break;
    case 'd':
      graph.parseData(stringData);
      break;
    default:
      println(String.format("unknown command %s", tokens[0]));
      return;
  }
  
  redraw();
}
