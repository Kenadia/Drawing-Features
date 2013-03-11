final int WAIT_STATE = 0; // Waiting for user to begin input
final int USER_STATE = 1; // User is inputting
final int DRAW_STATE = 2; // Draw region points

final float ANGLE_THRESHOLD = HALF_PI;

int state;
ArrayList path;
ArrayList regions; // <Integer> Start points of critical regions
ArrayList critical; // Boundary points and points of largest distance to the segments connecting them
ArrayList burnSets; // Sets of suspected redundant points--one from each set is preserved
ArrayList burned;
float [] distances;
float [] angles;
float [] turns;
float maxDistance;
int startTime;

void setup() {
  size(400, 400);
  background(0);
  waitState();
}

void waitState() {
  state = WAIT_STATE;
  path = new ArrayList();
  regions = new ArrayList();
  critical = new ArrayList();
  burnSets = new ArrayList();
  burned = new ArrayList();
}

void drawLine(DrawPoint p1, DrawPoint p2) {
  line(p1.p.x, p1.p.y, p2.p.x, p2.p.y);
}

void drawPath(ArrayList a) {
  DrawPoint p1 = (DrawPoint) a.get(0);
  for(int i = 1; i < a.size(); i++) {
    DrawPoint p2 = (DrawPoint) a.get(i);
    drawLine(p1, p2);
    p1 = p2;
  }
}

void draw() {
  if(state == USER_STATE) {
    path.add(new DrawPoint(mouseX, mouseY, millis() - startTime));
    stroke(#666666); // grey
    if(path.size() > 2) {
      DrawPoint p1 = (DrawPoint) path.get(path.size() - 2);
      DrawPoint p2 = (DrawPoint) path.get(path.size() - 1);
      drawLine(p1, p2);
    }
  }
  if(state == DRAW_STATE) {
    if(path.size() > 1) {
      background(0);
      measure();
      analyze();
      stroke(#333333); // dark grey
      drawPath(path);
      stroke(#000099); // blue
      drawPath(critical);
      stroke(#ffff00); // yellow
      for(Object o : critical) {
        ((DrawPoint) o).draw();
      }
      println(serializeFeatures());
    }
    waitState();
  }
}

void mousePressed() {
  if(state == WAIT_STATE) {
    background(0);
    state = USER_STATE;
    startTime = millis();
  }
}

void mouseReleased() {
  if(state == USER_STATE) {
    state = DRAW_STATE;
  }
}

void measure() {
  int n = path.size();
  distances = new float [n]; // distances[0] is not used
  angles = new float [n]; // angles[0] is not used
  turns = new float [n]; // turns[0] and turns[1] are not used
  DrawPoint p0 = ((DrawPoint) path.get(0));
  DrawPoint p1 = (DrawPoint) path.get(1);
  distances[1] = p0.distanceTo(p1);
  maxDistance = distances[1];
  angles[1] = p0.angleTo(p1);
  for(int i = 2; i < n; i++) {
    DrawPoint p2 = (DrawPoint) path.get(i);
    distances[i] = p1.distanceTo(p2);
    angles[i] = p1.angleTo(p2);
    turns[i] = angles[i] - angles[i - 1];
    p1 = p2;
    if(distances[i] > maxDistance) {
      maxDistance = distances[i];
    }
  }
}

void analyze() {
  // Find critical regions
  regions.add(0);
  float lastAngle = angles[1];
  float maxDiff = 0.0;
  int maxDiffPoint = 0;
  float minDiff = 0.0;
  int minDiffPoint = 0;
  for(int i = 2; i < path.size(); i++) {
    float diff = angleDifference(angles[i], lastAngle); // change in angle since the last marked point
    if(diff > maxDiff) {
      maxDiff = diff;
      maxDiffPoint = i;
    } else if(diff < minDiff) {
      minDiff = diff;
      minDiffPoint = i;
    }
    if(maxDiff - minDiff > ANGLE_THRESHOLD) {
      if(maxDiff != 0.0) {
        if(minDiff != 0.0) {
          regions.add(maxDiffPoint < minDiffPoint? maxDiffPoint : minDiffPoint);
          regions.add((maxDiffPoint < minDiffPoint? minDiffPoint : maxDiffPoint) - 1);
        } else {
          regions.add(maxDiffPoint - 1);
        }
      } else {
        if(minDiff != 0.0) {
          regions.add(minDiffPoint - 1);
        }
      }
      maxDiff = minDiff = 0.0;
      lastAngle = angles[i];
    }
  }
  regions.add(path.size() - 1);
  
  // Find points of biggest distance to the line connecting region boundary points in each region
  // and also add boundary points
  critical.add(path.get(0));
  if(path.size() > 2) {
    int i = 2;
    for(int currentRegion = 1; currentRegion < regions.size(); currentRegion++) {
      int boundaryPoint = (Integer) regions.get(currentRegion);
      float maxDistanceToLine = 0.0;
      int maxDistanceToLinePoint = i;
      while(i <= boundaryPoint) {
        DrawPoint dp = (DrawPoint) path.get(i);
        DrawPoint leftP = (DrawPoint) path.get((Integer) regions.get(currentRegion - 1));
        DrawPoint rightP = (DrawPoint) path.get((Integer) regions.get(currentRegion));
        float distanceToLine = (dp).distanceToLine(leftP, rightP);
        if(distanceToLine > maxDistanceToLine) {
          maxDistanceToLine = distanceToLine;
          maxDistanceToLinePoint = i;
        }
        i++;
      }
      critical.add(path.get(maxDistanceToLinePoint));
      if(maxDistanceToLinePoint != boundaryPoint) {
        critical.add(path.get(boundaryPoint));
      }
    }
  } else if(path.size() == 2) {
    critical.add(path.get(1));
  }
  
  // Take out points that are less important
  DrawPoint p0 = (DrawPoint) critical.get(0);
  DrawPoint p1 = (DrawPoint) critical.get(1);
  float minAngle = p0.angleTo(p1);
  float maxAngle = minAngle;
  ArrayList burnSet = new ArrayList();
  for(int i = 2; i < critical.size(); i++) {
    DrawPoint p2 = (DrawPoint) critical.get(i);
    float distance = p1.distanceTo(p2);
    float angle = p1.angleTo(p2);
    float change1 = abs(angleDifference(angle, minAngle));
    float change2 = abs(angleDifference(angle, maxAngle));
    float thresholdValue = PI / 8.0 + 100.0 / pow(distance - 3.0, 2);
    if(change1 < thresholdValue && change2 < thresholdValue) {
      if(burnSet.isEmpty()) {
        burnSet.add(critical.get(i - 2));
      }
      burnSet.add(critical.get(i - 1));
      if(angle < minAngle) {
        minAngle = angle;
      } else if (angle > maxAngle) {
        maxAngle = angle;
      }
    } else {
      if(!burnSet.isEmpty()) {
        burnSet.add(critical.get(i - 1));
        burnSet.add(critical.get(i));
        burnSets.add(burnSet);
        burnSet = new ArrayList();
      }
      p1 = p2;
      minAngle = maxAngle = angle;
    }
  }
  // Keep the point that has the largest squared distances from the start and end points
  // I think this won't work since it will pretty much always end up being the start or end point
  for(Object o : burnSets) {
    float maxDistance = 0.0;
    float maxDistancePoint = 0;
    burnSet = (ArrayList) o;
    DrawPoint start = (DrawPoint) burnSet.get(0);
    DrawPoint end = (DrawPoint) burnSet.get(burnSet.size() - 1);
    for(int i = 1; i < burnSet.size() - 1; i++) {
      DrawPoint dp = (DrawPoint) burnSet.get(i);
      float distance = pow(dp.distanceTo(start), 2) + pow(dp.distanceTo(end), 2);
      if(distance > maxDistance) {
        maxDistance = distance;
        maxDistancePoint = i;
      }
    }
    for(int i = 1; i < burnSet.size() - 1; i++) {
      if(i != maxDistancePoint) {
        burned.add(burnSet.get(i));
      }
    }
  }
  for(Object o : burned) {
    critical.remove(o);
  }
}

String formatInt(int n, int characters) {
  String zeroes = "";
  int digits = int(log(n) / log(10)) + 1;
  for(int i = digits; i < characters; i++) {
    zeroes += "0";
  }
  return zeroes + n;
}

String serializeFeatures() {
  String feat = "";
  int n = critical.size();
  feat += formatInt(n, 8);
  for(int i = 0; i < n; i++) {
    feat += ((DrawPoint) critical.get(i)).serialize();
  }
  return feat;
}

float angleDifference(float a1, float a2) {
  float d = a1 - a2;
  if(d > PI) {
    return d - TWO_PI;
  } else if (d < -PI) {
    return d + TWO_PI;
  }
  return d;
}

class DrawPoint {
  final PVector p;
  final int t;
  
  DrawPoint(int x, int y, int it) {
    p = new PVector(x, y);
    t = it;
  }
  
  float distanceTo(DrawPoint dp2) {
    return p.dist(dp2.p);
  }
  
  float angleTo(DrawPoint dp2) {
    float dx = dp2.p.x - p.x;
    float dy = dp2.p.y - p.y;
    return atan2(dp2.p.y - p.y, dp2.p.x - p.x);
  }
  
  float distanceToLine(DrawPoint leftP, DrawPoint rightP) {
    PVector lToP = PVector.sub(p, leftP.p);
    PVector segment = PVector.sub(rightP.p, leftP.p);
    segment.normalize();
    PVector projection = PVector.mult(segment, lToP.dot(segment));
    PVector perpendicular = PVector.sub(lToP, projection);
    return perpendicular.mag();
  }
  
  void draw() {
    point(p.x, p.y);
    point(p.x - 1, p.y);
    point(p.x + 1, p.y);
    point(p.x, p.y - 1);
    point(p.x, p.y + 1);
  }
  
  String formatInt(int n, int characters) {
    String zeroes = "";
    int digits = int(log(n) / log(10)) + 1;
    for(int i = digits; i < characters; i++) {
      zeroes += "0";
    }
    return zeroes + n;
  }
  
  String serialize() {
    return formatInt(int(p.x), 4) + formatInt(int(p.y), 4) + formatInt(t, 8);
  }
}
