import 'package:flutter/material.dart';
import 'dart:math';

void main() {
  runApp(TSPApp());
}

class TSPApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TSP Solver',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: TSPHomePage(),
    );
  }
}

enum InteractionMode { add, delete, move, manual }

class TSPHomePage extends StatefulWidget {
  @override
  _TSPHomePageState createState() => _TSPHomePageState();
}

class _TSPHomePageState extends State<TSPHomePage> {
  List<Offset> cities = [];
  List<int> path = [];
  double pathLength = 0.0;
  bool showPath = false;
  InteractionMode currentMode = InteractionMode.add;
  int? draggedCityIndex;
  bool isManualMode = false;
  List<int> manualPath = [];
  bool isPathClosed = false;

  void _handleTap(TapDownDetails details) {
    if (currentMode == InteractionMode.add) {
      _addCity(details);
    } else if (currentMode == InteractionMode.delete) {
      _deleteCity(details.localPosition);
    } else if (currentMode == InteractionMode.manual) {
      _handleManualPathBuilding(details.localPosition);
    }
  }

  void _addCity(TapDownDetails details) {
    setState(() {
      cities.add(details.localPosition);
      _resetPath();
    });
  }

  void _deleteCity(Offset tapPosition) {
    const double tapRadius = 20.0;
    
    for (int i = 0; i < cities.length; i++) {
      double distance = sqrt(pow(cities[i].dx - tapPosition.dx, 2) + 
                           pow(cities[i].dy - tapPosition.dy, 2));
      if (distance <= tapRadius) {
        setState(() {
          cities.removeAt(i);
          _resetPath();
        });
        break;
      }
    }
  }

  void _handleManualPathBuilding(Offset tapPosition) {
    const double tapRadius = 20.0;
    
    for (int i = 0; i < cities.length; i++) {
      double distance = sqrt(pow(cities[i].dx - tapPosition.dx, 2) + 
                           pow(cities[i].dy - tapPosition.dy, 2));
      if (distance <= tapRadius) {
        setState(() {
          int existingIndex = manualPath.indexOf(i);
          
          if (existingIndex != -1) {
            // Check if clicking on first city to close the path
            if (i == manualPath.first && manualPath.length >= 3 && !isPathClosed) {
              // Close the path
              isPathClosed = true;
              pathLength = _calculatePathLength(path);
            } else if (isPathClosed && i == manualPath.first) {
              // Reopen the path if clicking first city again when closed
              isPathClosed = false;
              pathLength = _calculatePathLength(path);
            } else {
              // City already in path - retract to this point
              manualPath = manualPath.sublist(0, existingIndex + 1);
              path = List.from(manualPath);
              isPathClosed = false; // Reopen path when retracting
              pathLength = _calculatePathLength(path);
            }
          } else {
            // Add city to path
            manualPath.add(i);
            path = List.from(manualPath);
            isPathClosed = false; // Adding new city reopens path
            pathLength = _calculatePathLength(path);
          }
          
          showPath = manualPath.length > 1;
        });
        break;
      }
    }
  }

  void _startManualMode() {
    setState(() {
      currentMode = InteractionMode.manual;
      isManualMode = true;
      manualPath.clear();
      path.clear();
      showPath = false;
      pathLength = 0.0;
      isPathClosed = false;
    });
  }

  void _exitManualMode() {
    setState(() {
      isManualMode = false;
      if (currentMode == InteractionMode.manual) {
        currentMode = InteractionMode.add;
      }
    });
  }

  void _clearManualPath() {
    setState(() {
      manualPath.clear();
      path.clear();
      showPath = false;
      pathLength = 0.0;
      isPathClosed = false;
    });
  }

  void _handlePanStart(DragStartDetails details) {
    if (currentMode != InteractionMode.move) return;
    
    const double tapRadius = 20.0;
    
    for (int i = 0; i < cities.length; i++) {
      double distance = sqrt(pow(cities[i].dx - details.localPosition.dx, 2) + 
                           pow(cities[i].dy - details.localPosition.dy, 2));
      if (distance <= tapRadius) {
        draggedCityIndex = i;
        break;
      }
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (currentMode != InteractionMode.move || draggedCityIndex == null) return;
    
    setState(() {
      cities[draggedCityIndex!] = details.localPosition;
      if (showPath) {
        pathLength = _calculatePathLength(path);
      }
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    draggedCityIndex = null;
  }

  void _resetPath() {
    showPath = false;
    pathLength = 0.0;
    path.clear();
    manualPath.clear();
    isManualMode = false;
    isPathClosed = false;
  }

  void _clearCities() {
    setState(() {
      cities.clear();
      _resetPath();
    });
  }

  double _calculateDistance(Offset a, Offset b) {
    return sqrt(pow(a.dx - b.dx, 2) + pow(a.dy - b.dy, 2));
  }

  double _calculatePathLength(List<int> currentPath) {
    if (currentPath.length < 2) return 0.0;
    
    double length = 0.0;
    for (int i = 0; i < currentPath.length - 1; i++) {
      length += _calculateDistance(cities[currentPath[i]], cities[currentPath[i + 1]]);
    }
    // Add distance back to start to complete the tour
    if (currentPath.length > 2 && (!isManualMode || isPathClosed)) {
      length += _calculateDistance(cities[currentPath.last], cities[currentPath.first]);
    }
    return length;
  }

  void _solveTSP() {
    if (cities.length < 3) return;

    setState(() {
      isManualMode = false;
      isPathClosed = false;
      
      // Simple nearest neighbor heuristic
      List<bool> visited = List.filled(cities.length, false);
      path = [0]; // Start from first city
      visited[0] = true;

      for (int i = 0; i < cities.length - 1; i++) {
        int current = path.last;
        int nearest = -1;
        double minDistance = double.infinity;

        for (int j = 0; j < cities.length; j++) {
          if (!visited[j]) {
            double distance = _calculateDistance(cities[current], cities[j]);
            if (distance < minDistance) {
              minDistance = distance;
              nearest = j;
            }
          }
        }

        if (nearest != -1) {
          path.add(nearest);
          visited[nearest] = true;
        }
      }

      pathLength = _calculatePathLength(path);
      showPath = true;
    });
  }

  void _optimizePath() {
    if (path.length < 4) return;

    setState(() {
      // Simple 2-opt optimization
      bool improved = true;
      while (improved) {
        improved = false;
        for (int i = 1; i < path.length - 2; i++) {
          for (int j = i + 1; j < path.length; j++) {
            if (j - i == 1) continue;

            List<int> newPath = List.from(path);
            // Reverse the segment between i and j
            for (int k = 0; k < (j - i + 1) / 2; k++) {
              int temp = newPath[i + k];
              newPath[i + k] = newPath[j - k];
              newPath[j - k] = temp;
            }

            double newLength = _calculatePathLength(newPath);
            if (newLength < pathLength) {
              path = newPath;
              pathLength = newLength;
              improved = true;
            }
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('TSP Solver'),
        backgroundColor: Colors.blue[700],
      ),
      body: Column(
        children: [
          // Path length display
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.straighten, color: Colors.blue[700]),
                SizedBox(width: 8),
                Text(
                  'Path Length: ${pathLength.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
          // Control buttons
          Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: cities.length >= 3 ? _solveTSP : null,
                  icon: Icon(Icons.route),
                  label: Text('Solve TSP'),
                ),
                ElevatedButton.icon(
                  onPressed: showPath && path.length >= 4 ? _optimizePath : null,
                  icon: Icon(Icons.trending_up),
                  label: Text('Optimize'),
                ),
                ElevatedButton.icon(
                  onPressed: cities.length >= 2 ? _startManualMode : null,
                  icon: Icon(Icons.touch_app),
                  label: Text('Manual'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isManualMode ? Colors.purple[600] : null,
                    foregroundColor: isManualMode ? Colors.white : null,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _clearCities,
                  icon: Icon(Icons.clear),
                  label: Text('Clear'),
                ),
              ],
            ),
          ),
          // Manual mode controls
          if (isManualMode)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.purple[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    'Manual Path Building',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[700],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _clearManualPath,
                    icon: Icon(Icons.refresh, size: 16),
                    label: Text('Reset Path'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _exitManualMode,
                    icon: Icon(Icons.exit_to_app, size: 16),
                    label: Text('Exit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                ],
              ),
            ),
          // Mode selection
          if (!isManualMode)
            Container(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Interaction Mode:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildModeButton(InteractionMode.add, Icons.add_location, 'Add'),
                      _buildModeButton(InteractionMode.delete, Icons.delete_outline, 'Delete'),
                      _buildModeButton(InteractionMode.move, Icons.open_with, 'Move'),
                    ],
                  ),
                ],
              ),
            ),
          // Instructions
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _getInstructionText(),
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
          // Drawing canvas
          Expanded(
            child: Container(
              margin: EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: GestureDetector(
                onTapDown: _handleTap,
                onPanStart: _handlePanStart,
                onPanUpdate: _handlePanUpdate,
                onPanEnd: _handlePanEnd,
                child: CustomPaint(
                  painter: TSPPainter(
                    cities: cities,
                    path: showPath ? path : [],
                    pathLength: pathLength,
                    currentMode: currentMode,
                    draggedCityIndex: draggedCityIndex,
                    isManualMode: isManualMode,
                    manualPath: manualPath,
                    isPathClosed: isPathClosed,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          // City count
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Cities: ${cities.length}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(InteractionMode mode, IconData icon, String label) {
    bool isSelected = currentMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          currentMode = mode;
          draggedCityIndex = null;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[600] : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blue[800]! : Colors.grey[400]!,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[700],
              size: 20,
            ),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInstructionText() {
    if (isManualMode) {
      String baseText = 'Click cities in order to build path. Click visited city to retract.';
      if (manualPath.length >= 3 && !isPathClosed) {
        baseText += ' Click first city again to close path.';
      } else if (isPathClosed) {
        baseText += ' Path is closed! Click first city to reopen.';
      }
      return '$baseText Path: ${manualPath.length} cities';
    }
    
    switch (currentMode) {
      case InteractionMode.add:
        return 'Tap anywhere to add cities. Need minimum 3 cities to solve TSP.';
      case InteractionMode.delete:
        return 'Tap on any city to delete it.';
      case InteractionMode.move:
        return 'Drag any city to move it. Path length updates in real-time.';
      case InteractionMode.manual:
        return 'Click cities in order to build path manually.';
    }
  }
}

class TSPPainter extends CustomPainter {
  final List<Offset> cities;
  final List<int> path;
  final double pathLength;
  final InteractionMode currentMode;
  final int? draggedCityIndex;
  final bool isManualMode;
  final List<int> manualPath;
  final bool isPathClosed;

  TSPPainter({
    required this.cities,
    required this.path,
    required this.pathLength,
    required this.currentMode,
    this.draggedCityIndex,
    required this.isManualMode,
    required this.manualPath,
    required this.isPathClosed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw path
    if (path.length > 1) {
      Paint pathPaint = Paint()
        ..color = Colors.blue[600]!
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      Path drawPath = Path();
      drawPath.moveTo(cities[path[0]].dx, cities[path[0]].dy);

      for (int i = 1; i < path.length; i++) {
        drawPath.lineTo(cities[path[i]].dx, cities[path[i]].dy);
      }

      // Close the loop only if not in manual mode OR if path is closed in manual mode
      if (path.length > 2 && (!isManualMode || isPathClosed)) {
        drawPath.lineTo(cities[path[0]].dx, cities[path[0]].dy);
      }

      canvas.drawPath(drawPath, pathPaint);

      // Draw arrows to show direction
      Paint arrowPaint = Paint()
        ..color = Colors.blue[800]!
        ..strokeWidth = 1.5;

      for (int i = 0; i < path.length; i++) {
        int nextIndex = (i + 1) % path.length;
        if (path.length == 2 && i == 1) break;
        if (isManualMode && !isPathClosed && i == path.length - 1) break;

        Offset from = cities[path[i]];
        Offset to = cities[path[nextIndex]];
        
        // Calculate arrow position (80% along the line)
        Offset arrowPos = Offset(
          from.dx + (to.dx - from.dx) * 0.8,
          from.dy + (to.dy - from.dy) * 0.8,
        );

        // Calculate arrow direction
        double angle = atan2(to.dy - from.dy, to.dx - from.dx);
        
        // Draw arrowhead
        canvas.drawLine(
          arrowPos,
          Offset(
            arrowPos.dx - 10 * cos(angle - 0.5),
            arrowPos.dy - 10 * sin(angle - 0.5),
          ),
          arrowPaint,
        );
        canvas.drawLine(
          arrowPos,
          Offset(
            arrowPos.dx - 10 * cos(angle + 0.5),
            arrowPos.dy - 10 * sin(angle + 0.5),
          ),
          arrowPaint,
        );
      }
    }

    // Draw cities
    Paint cityPaint = Paint()
      ..color = Colors.red[600]!
      ..style = PaintingStyle.fill;

    Paint cityBorderPaint = Paint()
      ..color = Colors.red[900]!
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Special paint for delete mode
    Paint deleteCityPaint = Paint()
      ..color = Colors.red[300]!
      ..style = PaintingStyle.fill;

    Paint deleteCityBorderPaint = Paint()
      ..color = Colors.red[600]!
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Special paint for move mode
    Paint moveCityPaint = Paint()
      ..color = Colors.green[600]!
      ..style = PaintingStyle.fill;

    Paint moveCityBorderPaint = Paint()
      ..color = Colors.green[900]!
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Special paint for manual mode
    Paint manualCityPaint = Paint()
      ..color = Colors.purple[600]!
      ..style = PaintingStyle.fill;

    Paint manualCityBorderPaint = Paint()
      ..color = Colors.purple[900]!
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    Paint visitedCityPaint = Paint()
      ..color = Colors.purple[400]!
      ..style = PaintingStyle.fill;

    Paint nextCityPaint = Paint()
      ..color = Colors.amber[600]!
      ..style = PaintingStyle.fill;

    Paint nextCityBorderPaint = Paint()
      ..color = Colors.amber[900]!
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < cities.length; i++) {
      Paint currentCityPaint;
      Paint currentBorderPaint;
      Color textColor = Colors.white;
      double radius = 8;

      // Choose colors based on current mode and state
      if (isManualMode) {
        int pathIndex = manualPath.indexOf(i);
        if (pathIndex != -1) {
          // City is in the manual path
          currentCityPaint = visitedCityPaint;
          currentBorderPaint = manualCityBorderPaint;
          
          // Highlight the first city differently if path can be closed
          if (i == manualPath.first && manualPath.length >= 3) {
            if (isPathClosed) {
              // Show closed state with special color
              currentCityPaint = Paint()
                ..color = Colors.teal[600]!
                ..style = PaintingStyle.fill;
              currentBorderPaint = Paint()
                ..color = Colors.teal[900]!
                ..strokeWidth = 4.0
                ..style = PaintingStyle.stroke;
            } else {
              // Show that this city can close the path
              currentCityPaint = Paint()
                ..color = Colors.lime[600]!
                ..style = PaintingStyle.fill;
              currentBorderPaint = Paint()
                ..color = Colors.lime[900]!
                ..strokeWidth = 3.0
                ..style = PaintingStyle.stroke;
            }
            radius = 10;
          }
          
          // Highlight the last city in the path (if not the first city)
          if (pathIndex == manualPath.length - 1 && i != manualPath.first) {
            currentCityPaint = nextCityPaint;
            currentBorderPaint = nextCityBorderPaint;
            radius = 10;
          }
        } else {
          // City not yet visited
          currentCityPaint = manualCityPaint;
          currentBorderPaint = manualCityBorderPaint;
        }
      } else if (currentMode == InteractionMode.delete) {
        currentCityPaint = deleteCityPaint;
        currentBorderPaint = deleteCityBorderPaint;
      } else if (currentMode == InteractionMode.move) {
        if (i == draggedCityIndex) {
          // Highlight the city being dragged
          currentCityPaint = Paint()
            ..color = Colors.orange[600]!
            ..style = PaintingStyle.fill;
          currentBorderPaint = Paint()
            ..color = Colors.orange[900]!
            ..strokeWidth = 3.0
            ..style = PaintingStyle.stroke;
          radius = 10;
        } else {
          currentCityPaint = moveCityPaint;
          currentBorderPaint = moveCityBorderPaint;
        }
      } else {
        currentCityPaint = cityPaint;
        currentBorderPaint = cityBorderPaint;
      }
      
      canvas.drawCircle(cities[i], radius, currentCityPaint);
      canvas.drawCircle(cities[i], radius, currentBorderPaint);

      // Draw city number or path order
      String displayText;
      if (isManualMode) {
        int pathIndex = manualPath.indexOf(i);
        if (pathIndex != -1) {
          displayText = (pathIndex + 1).toString();
        } else {
          displayText = i.toString();
        }
      } else {
        displayText = i.toString();
      }

      TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: displayText,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          cities[i].dx - textPainter.width / 2,
          cities[i].dy - textPainter.height / 2,
        ),
      );
    }

    // Draw mode indicator in top-left corner
    String modeText = '';
    Color modeColor = Colors.grey[600]!;
    if (isManualMode) {
      modeText = 'MANUAL MODE';
      modeColor = Colors.purple[600]!;
    } else {
      switch (currentMode) {
        case InteractionMode.add:
          modeText = 'ADD MODE';
          modeColor = Colors.blue[600]!;
          break;
        case InteractionMode.delete:
          modeText = 'DELETE MODE';
          modeColor = Colors.red[600]!;
          break;
        case InteractionMode.move:
          modeText = 'MOVE MODE';
          modeColor = Colors.green[600]!;
          break;
        case InteractionMode.manual:
          modeText = 'MANUAL MODE';
          modeColor = Colors.purple[600]!;
          break;
      }
    }

    TextPainter modeTextPainter = TextPainter(
      text: TextSpan(
        text: modeText,
        style: TextStyle(
          color: modeColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    modeTextPainter.layout();
    modeTextPainter.paint(canvas, Offset(10, 10));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}