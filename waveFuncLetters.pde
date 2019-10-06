
// Most of the logic is the same here.
// The primary difference is the pattern creation step.
// Character frequencies were pulled from Wikipedia.

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
int DRAW_SIZE = 32;

PGraphics output;

LetterLibrary archive;
Wave wave;


class LetterLibrary
{
  int[][][] adjacencies = new int[4][][]; // four cardinal directions
  int[] elements;
  int[] frequencies;
  int totalTiles = 1;
  
  // ordered alphabetically
  float[] freqs = {
    81.67,14.92,27.82,42.53,127.02,22.28,20.15,
    60.94,69.66,1.53,7.72,40.25,24.06,67.49,
    75.07,19.29,0.95,59.87,63.27,90.56,27.58,
    9.78,23.6,1.5,19.74,0.74
  };
  
  LetterLibrary()
  {
    totalTiles = gatherPatterns();
    
    for (int dir=0; dir<4; dir++)
    {
      adjacencies[dir] = new int[totalTiles][totalTiles];
    }
    findAdjacencies();
    println("Total tiles: " + totalTiles);
  }
  
  int gatherPatterns()
  {
    println("Collecting elements...");
    elements = new int[26];
    frequencies = new int[26];
    for (int c=0; c<26; c++)
    {
      elements[c] = c + 'A';
      frequencies[c] = int(1000*freqs[c]);
    }
    return 26;
  }
  
  void markAllowed(int keyA, int dirA, int keyB, int dirB)
  {
    adjacencies[dirA][keyA][keyB] = 1;
    adjacencies[dirB][keyB][keyA] = 1;
  }
  
  void findAdjacencies()
  {
    println("All letters can be adjacent...");
    for (int key=0; key<26; key++)
    {
      for (int otherIndex=0; otherIndex<26; otherIndex++)
      {
        markAllowed(key, SOUTH, otherIndex, NORTH);
        markAllowed(key, NORTH, otherIndex, SOUTH);
        markAllowed(key, WEST, otherIndex, EAST);
        markAllowed(key, EAST, otherIndex, WEST);
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
  
  void setTo(int ch)
  {
    tileType = ch;
    Arrays.fill(state, 0);
    state[ch] = 1;
    entropy = 0;
    count = 1;
    needsUpdate = true;
  }
}

class Wave
{
  Stack<Integer> todo;
  
  int w = 1;
  int h = 1;
  boolean initial = true;
  boolean isStable = true;
  
  Field[] area; // flattened 2D array
  LetterLibrary lib;
  
  Wave(int wWidth, int wHeight, LetterLibrary pl)
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
  
  void setHorizontalWord(String s, int x, int y)
  {
    int cx = x;
    int cy = y;
    for (char c: s.toCharArray())
    {
      int id = (cy * w) + cx;
      Field target = area[id];
      target.setTo(c - 'A');
      
      cx = (cx + 1) % w;
    }
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
    output.beginDraw();
    output.background(0);
    output.endDraw();
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
            pg.fill(0,255,0);
            pg.text( char(lib.elements[select.tileType]), x*DRAW_SIZE,y*DRAW_SIZE);
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
  size(1024,768,P2D);
  
  int outWidth = 30;
  int outHeight = 22;
  
  output = createGraphics(outWidth*DRAW_SIZE, outHeight*DRAW_SIZE, P2D);
  ((PGraphicsOpenGL)output).textureSampling(POINT);
  output.beginDraw();
  output.noStroke();
  output.background(0);
  output.textSize(11);
  output.endDraw();

  archive = new LetterLibrary();
  wave = new Wave(outWidth, outHeight, archive);
  
  wave.setHorizontalWord("PROCESSING", 4, 11);
  
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
  
  image(output, 0, 0);
  
}

