/*
Ardu plot - plot arduino (serial) telemetry.
This processing sketch plots ASCII-encoded data from the serial port.

Format:
lines should begin with a 1 character command, followed by whitespace-delimited data

serial commands:
"d": data - float or int
     all data must be on one line
     example: "d 1 2.5 3.6319982 0"
"n": names. (optional) 
     all names must be on one line
     note: re-send any range & pair data every time names are sent
     example: "n time rate bx by"
"r": set range.  (optional) name min max
     requires columns to be named
     include only the columns to be set to limited range
     all data not set to a fixed range with this command will be auto-ranged
     multiple column ranges can be listed on the same line
     or with separate "r" commands on separate lines
     example: "r bx -5 5 by -5 5"
"p": 2d pairs.  (optional) pairs of x/y names to bind for 2-d plots.
     requires columns to be named
     multiple pairs can be listed on the same line
     or with separate "p" commands on separate lines
     example: "p bx by"
"c": colors. rgb triplets (0-255)
     requires columns to be named
     multiple colors can be listed on the same line
     or with separate "c" commands on separate lines
     example: "c ax 255 0 0 bx 0 255 0"
     
     
keyboard commands:
"r": print ranges.
"p": toggle pairs.
"n": toggle names.
"b": toggle background bars.
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
  int r, g, b;

  public Column() {
    name = "";

    data = new float[width];

    x0 = 0;
    x1 = width;
    y0 = Float.POSITIVE_INFINITY;
    y1 = Float.NEGATIVE_INFINITY;
    
    r = 255;
    g = 255;
    b = 255;

    doAutoRange = true;
  }
}

//----------------------------------------------------------------------
public class Graph {
  Column[] columns;
  ArrayList<Integer> pairs;
  boolean drawPairs;
  boolean drawNames;
  boolean drawBGBars;

  //----------------------------------------
  public Graph() {
    columns = new Column[0];
    pairs   = new ArrayList<Integer>();
    drawPairs = true;
    drawNames = true;
    drawBGBars = true;
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
  void parseNames(String[] strData) {
    resetColumns(strData.length);
    
    for (int i = 0; i < strData.length; i++) {
      columns[i].name = strData[i];
    }
  }

  //----------------------------------------
  void parseData(String[] strData) {
    if (strData.length != columns.length) {
      resetColumns(strData.length);
    }

    for (int ci = 0; ci < columns.length; ci++) {
      Column c = columns[ci];
      
      // shift data over by one, make room for a new datum
      System.arraycopy(c.data, 1, c.data, 0, width-1);

      float n = 0;
      try {
        n = Float.parseFloat(strData[ci]);
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
  void parseRanges(String[] strData) {
    if ((strData.length % 3) != 0) {
      println("RANGE: bad format.  usage: 'r <name> <min> <max> ...'");
      return;
    }
    for (int i = 0; i < strData.length; i += 3) {
      boolean rangeSet = false;
      for (int ci = 0; ci < columns.length; ci++) {
        if (strData[i].equals(columns[ci].name)) {
          try {
            columns[ci].y0 = Float.parseFloat(strData[i+1]);
            columns[ci].y1 = Float.parseFloat(strData[i+2]);
          } catch (Exception e) {
            // exceptions in parseFloat() lead to Serial failure
            println(String.format("I had trouble understanding range values for '%s'", strData[i]));
          }
          rangeSet = true;
          columns[ci].doAutoRange = false;
          println(String.format("range: set '%s' to %s..%s", strData[i], columns[ci].y0, columns[ci].y1));
          break;
        }
      }
      if (!rangeSet) {
        println(String.format("range: couldn't find a column named '%s'", strData[i]));
      }
    }
  }

  //----------------------------------------
  void parsePairs(String[] strData) {
    if ((strData.length % 2) != 0) {
      println("PAIRS: bad format.  usage: 'p <name-x> <name-y> ...'");
      return;
    }
    
    int p0 = -1;
    int p1 = -1;
    
    for (int i = 0; i < strData.length; i += 2) {
      boolean pairSet = false;
      
      for (int c = 0; c < columns.length; c++) {
        if (strData[i  ].equals(columns[c].name)) p0 = c;
        if (strData[i+1].equals(columns[c].name)) p1 = c;
      }
              
      if (p0 >= 0 && p1 >= 0) {
        pairSet = true;
        pairs.add(p0);
        pairs.add(p1);
        println(String.format("pair (2d): %s and %s", strData[i], strData[i+1]));
      }

      if (!pairSet) {
        println(String.format("pair (2d): couldn't find a sequential pair '%s, %s'", 
          strData[i], strData[i+1]));
      }
    }
  }

  //----------------------------------------
  void parseColors(String[] strData) {
    if ((strData.length % 4) != 0) {
      println("COLORS: bad format - usage: 'c <name> <red> <green> <blue> ...'");
      return;
    }
    
    for (int i = 0; i < strData.length; i += 4) {
      for (int ci = 0; ci < columns.length; ci++) {
        if (strData[i].equals(columns[ci].name)) {
          try {
            columns[ci].r = int(Float.parseFloat(strData[i+1]));
            columns[ci].g = int(Float.parseFloat(strData[i+2]));
            columns[ci].b = int(Float.parseFloat(strData[i+3]));
          } catch (Exception e) {
            // exceptions in parseFloat() lead to Serial failure
            println(String.format("I had trouble understanding color values for '%s'", strData[i]));
          }
          println(String.format("color: set '%s' to (%s %s %s)", strData[i], columns[ci].r, columns[ci].g, columns[ci].b));
          
          break;
        }
      }
    }
  }
  
  //----------------------------------------
  void printRange() {
    for (int ci = 0; ci < columns.length; ci++) {
      println(String.format("range for column  %d (\"%s\"): %f..%f",
        ci, columns[ci].name, columns[ci].y0, columns[ci].y1));
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

    for (int ci = 0; ci < columns.length; ci++) {
      Column c = columns[ci];
      float dY0 = dY*ci;
      float dY1 = dY*(ci+1);
      
      // draw some background blocks to distinguish columns
      if (drawBGBars && ((ci % 2) == 1)) {
        fill(255,255,255,32);
        noStroke();
        rect(0, dY0, width, dY);
      }
      
      // display the column name
      if (drawNames) {
        fill(c.r, c.g, c.b);
        text(c.name, 10, dY1-10);
      }

      // plot the data
      stroke(c.r, c.g, c.b);
      noFill();
      px = 0;
      py = map(c.data[0], c.y0, c.y1, dY0, dY1);
      for (int i = 1; i < width; i++) {
        nx = i;
        ny = map(c.data[i], c.y0, c.y1, dY0, dY1);
        line(px, py, nx, ny);
        px = nx;
        py = ny;
      }
    }
    
    // draw pairs
    if (drawPairs && pairs.size() > 0) {
      int nPairs = pairs.size() / 2;

      // how big to make our 2d pair boxes
      float pdY = min(height / nPairs, 2 * dY);
      float space = (height - (nPairs * pdY)) / nPairs;

      // where to draw our 2d pair boxes.  distribute extra space evenly
      float pY = space/2;
      float pX = 100;

      for (int pi = 0; pi < pairs.size(); pi+=2, pY += pdY + space) {
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
        
        if (drawNames) {
          text(String.format("%s v %s", c0.name, c1.name), pX + 10, pY + 10);
        }
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
    
  for (String port : Serial.list()) {
    println(port);
    // auto-connect to the usb "serial" port
    // (I'm assuming there's only one -- TODO: make this a choice) 
    if (port.toLowerCase().contains("tty.usbmodem") || // mac
        port.toLowerCase().contains("com") // windows
    ) {
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
      
    case 'n':
      graph.drawNames = !graph.drawNames;
      break;
      
    case 'b':
      graph.drawBGBars = !graph.drawBGBars;
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
  
  // split on whitespace
  String[] tokens = inString.split("\\s+");
  if (tokens.length < 2) return;

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
    case 'c':
      graph.parseColors(stringData);
      break;
    default:
      println(String.format("unknown command %s", tokens[0]));
      return;
  }
  
  redraw();
}
