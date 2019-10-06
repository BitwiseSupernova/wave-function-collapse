

import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import java.util.TreeMap;
import java.util.Stack;

// Patterns will be square
int S = 3;
int CUT_SIZE = S-1;

// Helper names
int SOUTH=0, NORTH=1, WEST=2, EAST=3;

// Keep the program updating even with
//   a lot of stack usage
int MAX_ITERATIONS = 100;

PGraphics orig;
PGraphics output;

PatternLibrary archive;
Wave wave;

boolean running = true;
boolean keepRecording = true;
int saveCounter = 0;


class Pattern
{
  int[][] contents;
  
  Pattern(int[][] in)
  {
    contents = in;
  }
  
  public int hashCode()
  {
    int key = 0;
    for (int y=0; y<S; y++)
    {
      for (int x=0; x<S; x++)
      {
        int pix = contents[y][x];
        key = (31*key) + ((pix>>24) & 0xFF);
        key = (31*key) + ((pix>>8) & 0xFF);
        key = (31*key) + (pix & 0xFF);
      }
    }
    return key;
  }
  
  Pattern rotNxNinetyDeg(int reps)
  {
    int[][] rota = new int[S][S];
    float offset = (S-1) / 2.0;
    for (int y=0; y<S; y++)
    {
      for (int x=0; x<S; x++)
      {
        float nx = x - offset;
        float ny = y - offset;
        for (int i=0; i<reps; i++)
        {
          float tx = nx;
          nx = -ny;
          ny =  tx;
        }
        nx = nx + offset;
        ny = ny + offset;
        rota[y][x] = contents[(int)nx][(int)ny];
      }
    }
    return new Pattern(rota);
  }
  
  Pattern flipH()
  {
    int[][] f = new int[S][S];
    for (int y=0; y<S; y++)
    {
      for (int x=0; x<S; x++)
      {
        f[y][x] = contents[y][S-x-1];
      }
    }
    return new Pattern(f);
  }
  
  Pattern flipV()
  {
    int[][] f = new int[S][S];
    for (int y=0; y<S; y++)
    {
      for (int x=0; x<S; x++)
      {
        f[y][x] = contents[S-y-1][x];
      }
    }
    return new Pattern(f);
  }
  
  boolean canBeAbove(Pattern other) { return compareTopToBottom(contents, other.contents); }
  boolean canBeBelow(Pattern other) { return compareTopToBottom(other.contents, contents); }
  boolean canBeToTheRightOf(Pattern other) { return compareLeftToRight(other.contents, contents); }
  boolean canBeToTheLeftOf(Pattern other) { return compareLeftToRight(contents, other.contents); }
  
  boolean compareTopToBottom(int[][] top, int[][] bottom)
  {
    boolean same = true;
    for (int y=0; y<CUT_SIZE; y++)
    {
      for (int x=0; x<S; x++)
      {
        int tp = top[y+1][x];
        int bt = bottom[y][x];
        
        if (tp != bt)
        {
          same = false;
          break; // get out early when possible
        }
      }
    }
    return same;
  }
  
  boolean compareLeftToRight(int[][] left, int[][] right)
  {
    boolean same = true;
    for (int y=0; y<S; y++)
    {
      for (int x=0; x<CUT_SIZE; x++)
      {
        int lf = left[y][x+1];
        int rt = right[y][x];
        
        if (lf != rt)
        {
          same = false;
          break; // get out early when possible
        }
      }
    }
    return same;
  }
}

class PatternLibrary
{
  int[][][] adjacencies = new int[4][][]; // four cardinal directions
  Pattern[] patterns;
  int[] elements;
  int[] frequencies;
  int totalTiles = 1;
  
  PatternLibrary(PImage template)
  {
    totalTiles = gatherPatterns(template);
    for (int dir=0; dir<4; dir++)
    {
      adjacencies[dir] = new int[totalTiles][totalTiles];
    }
    findAdjacencies();
    println("Total tiles: " + totalTiles);
  }
  
  void placePattern(Pattern p, HashMap<Integer,Pattern> tiles, HashMap<Integer,Integer> freqs)
  {
    int k = p.hashCode();
    tiles.put(k, p);
    freqs.put(k, freqs.getOrDefault(k,0) + 1);
  }
  
  int gatherPatterns(PImage src)
  {
    HashMap<Integer,Integer> freqs = new HashMap();
    HashMap<Integer,Pattern> tiles = new HashMap();
    println("gathering patterns...");
    for (int y=0; y<src.height+S; y++)
    {
      for (int x=0; x<src.width+S; x++)
      {
        int[][] ptrn = new int[S][S];
        for (int dy=0; dy<S; dy++)
        {
          for (int dx=0; dx<S; dx++)
          {
            int tx = (x+dx) % src.width;
            int ty = (y+dy) % src.height;
            int idx = ty*src.width + tx;
            ptrn[dy][dx] = src.pixels[idx];
          }
        }
        
        Pattern block = new Pattern(ptrn);
        Pattern rota = block.rotNxNinetyDeg(1);
        Pattern rotb = block.rotNxNinetyDeg(2);
        Pattern rotc = block.rotNxNinetyDeg(3);
        placePattern(block, tiles, freqs);
        placePattern(block.flipH(), tiles, freqs);
        placePattern(block.flipV(), tiles, freqs);
        placePattern(rota, tiles, freqs);
        placePattern(rotb, tiles, freqs);
        placePattern(rotc, tiles, freqs);
        
        // Optional extra patterns
        //placePattern(rota.flipH(), tiles, freqs);
        //placePattern(rota.flipV(), tiles, freqs);
        //placePattern(rotb.flipH(), tiles, freqs);
        //placePattern(rotb.flipV(), tiles, freqs);
        //placePattern(rotc.flipH(), tiles, freqs);
        //placePattern(rotc.flipV(), tiles, freqs);
      }
    }
    
    println("Collecting elements...");
    Set<Integer> keys = tiles.keySet();
    patterns = new Pattern[keys.size()];
    elements = new int[patterns.length];
    frequencies = new int[patterns.length];
    int counter = 0;
    for (Integer key : keys)
    {
      Pattern selected = tiles.get(key);
      patterns[counter] = selected;
      elements[counter] = selected.contents[0][0];
      frequencies[counter] = freqs.get(key);
      counter++;
    }
    return patterns.length;
  }
  
  void markAllowed(int keyA, int dirA, int keyB, int dirB)
  {
    adjacencies[dirA][keyA][keyB] = 1;
    adjacencies[dirB][keyB][keyA] = 1;
  }
  
  void findAdjacencies()
  {
    println("building adjacency tables...");
    for (int key=0; key<patterns.length; key++)
    {
      Pattern selected = patterns[key];
      for (int otherIndex=0; otherIndex<patterns.length; otherIndex++)
      {
        Pattern other = patterns[otherIndex];
        if ( selected.canBeAbove(other) ) markAllowed(key, SOUTH, otherIndex, NORTH);
        if ( selected.canBeBelow(other) ) markAllowed(key, NORTH, otherIndex, SOUTH);
        if ( selected.canBeToTheRightOf(other) ) markAllowed(key, WEST, otherIndex, EAST);
        if ( selected.canBeToTheLeftOf(other) ) markAllowed(key, EAST, otherIndex, WEST);
      }
    }
  }
}

class Field
{
  int[] state;
  int[] allowBuffer; // Used to prevent object creation during main algorithm
  int tileType = -1;
  float entropy = 1.0;
  int count = 0;
  boolean needsUpdate = true;
  
  Field(int[] counts)
  {
    state = Arrays.copyOf(counts, counts.length);
    allowBuffer = new int[state.length];
    count = state.length;
    entropy = count; // all are possible initially
    needsUpdate = true;
  }
  
  void restrict(int[] allowed)
  {
    count = 0;
    for (int i=0; i<state.length; i++)
    {
      state[i] *= allowed[i];
      if (state[i] != 0) count++;
    }
    entropy = count - random(0.2);
  }
  
  void gatherNeighborhood(int[][] lookingDirection)
  {
    Arrays.fill(allowBuffer, 0);
    for (int i=0; i<state.length; i++)
    {
      if (state[i] != 0)
      {
        int[] mult = lookingDirection[i];
        for (int j=0; j<state.length; j++)
        {
          allowBuffer[j] |= mult[j];
        }
      }
    }
  }
  
  int[] getAllowed(int[][] lookingDirection)
  {
    if (count == 1)
    {
      if (tileType != -1) return lookingDirection[tileType]; // attempt shortcut
      else gatherNeighborhood(lookingDirection); // fall back to regular check
    }
    else
    {
      gatherNeighborhood(lookingDirection);
    }
    return allowBuffer;
  }
  
  int weightedChoice()
  {
    int len = 0;
    TreeMap tm = new TreeMap<Float,Integer>();
    float total = 0;
    for (int i=0; i<state.length; i++)
    {
      if (state[i] > 0)
      {
        total += state[i];
        tm.put(total, i);
        len++;
      }
    }
    if (len > 0)
    {
      float select = random(total);
      if (tm.higherEntry(select) != null)
      {
        int v = (Integer)tm.higherEntry(select).getValue();
        Arrays.fill(state, 0);
        state[v] = 1;
        count = 1;
        return v;
      }
      return -1;
    }
    return -1;
  }
  
  boolean collapse()
  {
    if (count < 1) return false; // contradiction
    tileType = weightedChoice();
    if (-1 == this.tileType) return false; // contradiction
    entropy = 0.0;
    count = 1;
    needsUpdate = true;
    return true;
  }
}

class Wave
{
  int superPosition = color(0,88,201);
  Stack<Integer> todo;
  
  int w = 1;
  int h = 1;
  boolean initial = true;
  boolean isStable = true;
  boolean contra = false;
  
  Field[] area; // flattened 2D array
  PatternLibrary lib;
  
  Wave(int wWidth, int wHeight, PatternLibrary pl)
  {
    this.w = wWidth;
    this.h = wHeight;
    this.area = new Field[this.w*this.h];
    this.lib = pl;
    this.reset();
    this.todo = new Stack();
    println("WxH: " + this.w + "x" + this.h);
    println("Patterns: " + lib.totalTiles);
  }
  
  int findLowestEntropyNotEqualToZero()
  {
    int idx = -1;
    float mx = 9999999;
    for (int key=0; key<area.length; key++)
    {
      Field f = area[key];
      float e = f.entropy;
      if ((e < mx) && (e > 0) && (-1 == f.tileType))
      {
        idx = key;
        mx = e;
      }
    }
    return idx;
  }
  
  void step()
  {
    if (isStable)
    {
      observe();
    }
    isStable = propagate();
  }
  
  void observe()
  {
    int idx = -1;
    if (initial) // random selection
    {
      int rx = (int)random(w);
      int ry = (int)random(h);
      idx = (ry * w) + rx;
      initial = false;
    }
    else
    {
      idx = findLowestEntropyNotEqualToZero();
    }
    if (idx != -1)
    {
      Field f = area[idx];
      if (f.collapse()) todo.push(idx); // do not use contradiction for remainder
      else contra = false;
    }
  }
  
  void adjustNeighbor(int n, int dir, Field ref)
  {
    Field nei = area[n];
    int prevCount = nei.count;
    if (-1 != nei.tileType) return; // prevent an error from wiping out the entire design
    nei.restrict( ref.getAllowed(lib.adjacencies[dir]) );
    if (nei.count != prevCount)
    {
      nei.needsUpdate = true;
      todo.push(n);
    }
  }
  
  boolean propagate()
  {
    int workLoad = 0;
    boolean done = todo.empty();
    while (!done && (workLoad < MAX_ITERATIONS))
    {
      int i = todo.pop();
      int x = i % w;
      int y = i / w;
      int dpx = (x + w + 1) % w;
      int dnx = (x + w - 1) % w;
      int dpy = (y + h + 1) % h;
      int dny = (y + h - 1) % h;
      int id_W = (y * w) + dnx;
      int id_E = (y * w) + dpx;
      int id_N = (dny * w) + x;
      int id_S = (dpy * w) + x;
      
      Field f = area[i];
      // Method:
      //   update each neighbor based on the contents of selected
      //   if neighbor changed, push it onto the stack
      adjustNeighbor(id_N, NORTH, f);
      adjustNeighbor(id_S, SOUTH, f);
      adjustNeighbor(id_E, EAST, f);
      adjustNeighbor(id_W, WEST, f);
      
      workLoad++;
      done = todo.empty();
    }
    return done;
  }
  
  void reset()
  {
    for (int x=0; x<w; x++)
    {
      for (int y=0; y<h; y++)
      {
        int idx = (y * w) + x;
        area[idx] = new Field(lib.frequencies);
      }
    }
    initial = true;
  }
  
  void displayTo(PGraphics pg)
  {
    pg.beginDraw();
    for (int y=0; y<h; y++)
    {
      for (int x=0; x<w; x++)
      {
        int k = (y * w) + x;
        Field select = area[k];
        if (select.needsUpdate)
        {
          int len = select.count;
          if ((1 == len) && (-1 != select.tileType))
          {
            int col = lib.elements[select.tileType];
            pg.set(x,y,col);
          }
          else if (lib.totalTiles == len)
          {
            int col = color(103,62,15);
            pg.set(x,y,col);
          }
          else
          {
            float ratio = float(len) / lib.totalTiles;
            int orange = color(214,75,0);
            int yellow = color(255,255,0);
            int col = lerpColor(orange, yellow, 1.0-ratio);
            pg.set(x,y,col);
          }
          select.needsUpdate = false;
        }
      }
    }
    pg.endDraw();
  }
}

void mouseClicked()
{
  wave.reset();
}

void setup()
{
  size(768,512,P2D);
  
  int outWidth = 90;
  int outHeight = 90;
  
  ((PGraphicsOpenGL)g).textureSampling(POINT);
  
  output = createGraphics(outWidth, outHeight, P2D);
  ((PGraphicsOpenGL)output).textureSampling(POINT);
  output.beginDraw();
  output.noStroke();
  output.background(0);
  output.endDraw();
  
  // Load image
  //PImage orig = loadImage("Hogs.png");
  //orig.loadPixels();
  
  // To me, looks like a contour map
  orig = createGraphics(32,32,P2D);
  orig.beginDraw();
  orig.background(0);
  orig.stroke(255);
  orig.noFill();
  orig.strokeWeight(2);
  orig.ellipse(orig.width/2,orig.height/2, 10,10);
  orig.loadPixels(); // this must be between begin- and endDraw()
  orig.endDraw();
  
  archive = new PatternLibrary(orig);
  wave = new Wave(outWidth, outHeight, archive);
  
  frameRate(30);
}


void draw()
{
  background(0);
  
  int SOME_NUMBER = 10; // repetitions per frame
  for (int i=0; i<SOME_NUMBER; i++)
  {
    wave.step();
  }
  wave.displayTo(output);
  
  image(output, 0, 0, 512, 512);
  image(orig, 600, 0);
  
  fill(255);
  text("frame: " + frameCount + "\ncontradiction: " + wave.contra, 512, 20);
}

