/*
Ardu plot - plot arduino (serial) telemetry.
This processing sketch plots ASCII-encoded data from the serial port.

Format:
lines should begin with a 1 character command, followed by tab-delimited data

serial commands:
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
     
     
keyboard commands:
"r": print ranges.
"p": toggle pairs.
ESC: quit.


TODO:
- add port/baud selection UI on startup, that would be rad
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
  ArrayList<Integer> pairs;
  boolean drawPairs;

  //----------------------------------------
  public Graph() {
    columns = new Column[0];
    pairs   = new ArrayList<Integer>();
    drawPairs = true;
  }

  //----------------------------------------
  // reset number of columns to n
  void resetColumns(int n) {
    columns = new Column[n];
    for (int i = 0; i < n; i++) {
      columns[i] = new Column();
    }

    pairs.clear();
  }
  
  //----------------------------------------
  void parseNames(String[] names) {
    resetColumns(names.length);
    
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
        // exceptions in parseFloat() lead to Serial failure
      }
      c.data[width-1] = n;
      if (c.doAutoRange) {
        if (n < c.y0) c.y0 = n;
        if (n > c.y1) c.y1 = n;
      }
    }
  }
  
  //----------------------------------------
  void parseRanges(String[] ranges) {
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
            // exceptions in parseFloat() lead to Serial failure
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
  void parsePairs(String[] i_pairs) {
    if ((i_pairs.length % 2) != 0) {
      println("PAIRS: bad format");
      return;
    }
    
    int p0 = -1;
    int p1 = -1;
    
    for (int i = 0; i < i_pairs.length; i += 2) {
      boolean pairSet = false;
      
      for (int c = 0; c < columns.length; c++) {
        if (i_pairs[i  ].equals(columns[c].name)) p0 = c;
        if (i_pairs[i+1].equals(columns[c].name)) p1 = c;
      }
              
      if (p0 >= 0 && p1 >= 0) {
        pairSet = true;
        pairs.add(p0);
        pairs.add(p1);
        println(String.format("pair (2d): %s and %s", i_pairs[i], i_pairs[i+1]));
      }

      if (!pairSet) {
        println(String.format("pair (2d): couldn't find a sequential pair '%s, %s'", 
          i_pairs[i], i_pairs[i+1]));
      }
    }
  }

  //----------------------------------------
  void printRange() {
    for (int c = 0; c < columns.length; c++) {
      println(String.format("range for column  %d (\"%s\"): %f..%f",
        c, columns[c].name, columns[c].y0, columns[c].y1));
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
      fill(32, 220, 32);
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
    
    // draw pairs
    if (drawPairs) {
      float pdY = 2 * dY; // how big to make our 2d pair boxes
      // where to draw our 2d pair boxes
      float pY = 10;
      float pX = 100;

      for (int pi = 0; pi < pairs.size(); pi+=2, pY += pdY + dY/2) {
        Column c0 = columns[pairs.get(pi).intValue()];
        Column c1 = columns[pairs.get(pi+1).intValue()];
        
        float x = pX + map(c0.data[width-1], c0.y0, c0.y1, 0, pdY);
        float y = pY + map(c1.data[width-1], c1.y0, c1.y1, 0, pdY);


        stroke(64, 64, 64, 255);
        fill(0, 0, 0, 128+64);
        rect(pX, pY, pdY, pdY);

        noStroke();
        ellipseMode(CENTER);
        fill(230, 128, 32);
        ellipse(x, y, 6, 6);
        
        // display the pair name
        text(String.format("%s v %s", c0.name, c1.name), pX + 10, pY + 10);
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
    
  for (String port : Serial.list())
  {
    println(port);
    // auto-connect to the usb "serial" port
    // (I'm assuming there's only one -- TODO: make this a choice) 
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
void keyPressed() {
  switch(key) {
    case 'r':
      graph.printRange();
      break;
      
    case 'p':
      graph.drawPairs = !graph.drawPairs;
      break;
  }
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
      graph.parseRanges(stringData);
      break;
    case 'p':
      graph.parsePairs(stringData);
      break;
    default:
      println(String.format("unknown command %s", tokens[0]));
      return;
  }
  
  redraw();
}
