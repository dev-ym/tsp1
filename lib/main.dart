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
  List<Offset> blockers = [];
  List<int> path = [];
  double pathLength = 0.0;
  bool showPath = false;
  InteractionMode currentMode = InteractionMode.add;
  int? draggedCityIndex;
  int? draggedBlockerIndex;
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
    
    // Check cities first
    for (int i = 0; i < cities.length; i++) {
      double distance = sqrt(pow(cities[i].dx - tapPosition.dx, 2) + 
                           pow(cities[i].dy - tapPosition.dy, 2));
      if (distance <= tapRadius) {
        setState(() {
          cities.removeAt(i);
          _resetPath();
        });
        return;
      }
    }
    
    // Check blockers
    for (int i = 0; i < blockers.length; i++) {
      double distance = sqrt(pow(blockers[i].dx - tapPosition.dx, 2) + 
                           pow(blockers[i].dy - tapPosition.dy, 2));
      if (distance <= tapRadius) {
        setState(() {
          blockers.removeAt(i);
          _resetPath();
        });
        return;
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
            if (i == manualPath.first && manualPath.length == cities.length && !isPathClosed) {
              // Check if closing path is valid (no blockers crossed) and all cities are included
              if (_isValidPath([...manualPath, manualPath.first])) {
                isPathClosed = true;
                pathLength = _calculatePathLength(path);
              }
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
            // Add city to path - check if connection is valid
            if (manualPath.isEmpty || _isValidConnection(cities[manualPath.last], cities[i])) {
              manualPath.add(i);
              path = List.from(manualPath);
              isPathClosed = false; // Adding new city reopens path
              pathLength = _calculatePathLength(path);
            }
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
    
    // Check cities first
    for (int i = 0; i < cities.length; i++) {
      double distance = sqrt(pow(cities[i].dx - details.localPosition.dx, 2) + 
                           pow(cities[i].dy - details.localPosition.dy, 2));
      if (distance <= tapRadius) {
        draggedCityIndex = i;
        return;
      }
    }
    
    // Check blockers
    for (int i = 0; i < blockers.length; i++) {
      double distance = sqrt(pow(blockers[i].dx - details.localPosition.dx, 2) + 
                           pow(blockers[i].dy - details.localPosition.dy, 2));
      if (distance <= tapRadius) {
        draggedBlockerIndex = i;
        return;
      }
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (currentMode != InteractionMode.move) return;
    
    setState(() {
      if (draggedCityIndex != null) {
        cities[draggedCityIndex!] = details.localPosition;
        if (showPath) {
          pathLength = _calculatePathLength(path);
        }
      } else if (draggedBlockerIndex != null) {
        blockers[draggedBlockerIndex!] = details.localPosition;
        if (showPath) {
          pathLength = _calculatePathLength(path);
        }
      }
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    draggedCityIndex = null;
    draggedBlockerIndex = null;
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
      blockers.clear();
      _resetPath();
    });
  }

  void _addRandomBlockers() {
    setState(() {
      const int numBlockers = 3;
      const double minDistance = 30.0; // Minimum distance from cities and other blockers
      const double margin = 20.0; // Margin from edges
      
      Random random = Random();
      int attempts = 0;
      const int maxAttempts = 200;
      
      // Don't clear existing blockers - add to them instead
      
      for (int i = 0; i < numBlockers && attempts < maxAttempts; attempts++) {
        // Use conservative canvas size to ensure visibility
        double canvasWidth = 350.0;  // Reduced to be more conservative
        double canvasHeight = 250.0; // Reduced to be more conservative
        
        double x = margin + random.nextDouble() * (canvasWidth - 2 * margin);
        double y = margin + random.nextDouble() * (canvasHeight - 2 * margin);
        Offset newBlocker = Offset(x, y);
        
        bool validPosition = true;
        
        // Check distance from cities
        for (Offset city in cities) {
          if (_calculateDistance(city, newBlocker) < minDistance) {
            validPosition = false;
            break;
          }
        }
        
        // Check distance from other blockers
        if (validPosition) {
          for (Offset blocker in blockers) {
            if (_calculateDistance(blocker, newBlocker) < minDistance) {
              validPosition = false;
              break;
            }
          }
        }
        
        if (validPosition) {
          blockers.add(newBlocker);
          i++; // Only increment if we successfully placed a blocker
        }
      }
      
      _resetPath(); // Reset any existing path since blockers might invalidate it
    });
  }

  double _calculateDistance(Offset a, Offset b) {
    return sqrt(pow(a.dx - b.dx, 2) + pow(a.dy - b.dy, 2));
  }

  bool _isValidConnection(Offset start, Offset end) {
    const double blockerRadius = 8.0; // Same as city radius
    
    for (Offset blocker in blockers) {
      if (_lineIntersectsCircle(start, end, blocker, blockerRadius)) {
        return false;
      }
    }
    return true;
  }

  bool _isValidPath(List<int> testPath) {
    if (testPath.length < 2) return true;
    
    for (int i = 0; i < testPath.length - 1; i++) {
      if (!_isValidConnection(cities[testPath[i]], cities[testPath[i + 1]])) {
        return false;
      }
    }
    return true;
  }

  bool _lineIntersectsCircle(Offset lineStart, Offset lineEnd, Offset circleCenter, double radius) {
    // Calculate the distance from the circle center to the line segment
    double A = lineEnd.dy - lineStart.dy;
    double B = lineStart.dx - lineEnd.dx;
    double C = lineEnd.dx * lineStart.dy - lineStart.dx * lineEnd.dy;
    
    double distance = (A * circleCenter.dx + B * circleCenter.dy + C).abs() / sqrt(A * A + B * B);
    
    if (distance > radius) return false;
    
    // Check if the closest point on the line is within the line segment
    double t = ((circleCenter.dx - lineStart.dx) * (lineEnd.dx - lineStart.dx) + 
                (circleCenter.dy - lineStart.dy) * (lineEnd.dy - lineStart.dy)) /
               (pow(lineEnd.dx - lineStart.dx, 2) + pow(lineEnd.dy - lineStart.dy, 2));
    
    t = t.clamp(0.0, 1.0);
    
    Offset closestPoint = Offset(
      lineStart.dx + t * (lineEnd.dx - lineStart.dx),
      lineStart.dy + t * (lineEnd.dy - lineStart.dy),
    );
    
    return _calculateDistance(circleCenter, closestPoint) <= radius;
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
      
      // Simple nearest neighbor heuristic with blocker avoidance
      List<bool> visited = List.filled(cities.length, false);
      path = [0]; // Start from first city
      visited[0] = true;

      for (int i = 0; i < cities.length - 1; i++) {
        int current = path.last;
        int nearest = -1;
        double minDistance = double.infinity;

        for (int j = 0; j < cities.length; j++) {
          if (!visited[j] && _isValidConnection(cities[current], cities[j])) {
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
        } else {
          // No valid connection found - TSP might not be solvable with current blockers
          break;
        }
      }

      // Check if we can complete the tour
      if (path.length == cities.length && _isValidConnection(cities[path.last], cities[path.first])) {
        pathLength = _calculatePathLength(path);
        showPath = true;
      } else {
        // Cannot complete tour due to blockers
        path.clear();
        showPath = false;
        pathLength = 0.0;
        // Show a message or handle this case as needed
      }
    });
  }

  void _optimizePath() {
    if (path.length < 4) return;

    setState(() {
      // Simple 2-opt optimization with blocker checking
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

            // Check if new path is valid and better
            if (_isValidPath(newPath)) {
              double newLength = _calculatePathLength(newPath);
              if (newLength < pathLength) {
                path = newPath;
                pathLength = newLength;
                improved = true;
              }
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
        title: Text('TSP Solver with Blockers'),
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
          // Control buttons - compressed for mobile
          Padding(
            padding: EdgeInsets.all(4),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                _buildCompactButton(
                  onPressed: cities.length >= 3 ? _solveTSP : null,
                  icon: Icons.route,
                  label: 'Solve',
                ),
                _buildCompactButton(
                  onPressed: showPath && path.length >= 4 ? _optimizePath : null,
                  icon: Icons.trending_up,
                  label: 'Optimize',
                ),
                _buildCompactButton(
                  onPressed: cities.length >= 2 ? _startManualMode : null,
                  icon: Icons.touch_app,
                  label: 'Manual',
                  backgroundColor: isManualMode ? Colors.purple[600] : null,
                  foregroundColor: isManualMode ? Colors.white : null,
                ),
                _buildCompactButton(
                  onPressed: _clearCities,
                  icon: Icons.clear,
                  label: 'Clear',
                ),
              ],
            ),
          ),
          // Blocker controls - compressed
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: _buildCompactButton(
              onPressed: _addRandomBlockers,
              icon: Icons.block,
              label: 'Add Blockers',
              backgroundColor: Colors.brown[600],
              foregroundColor: Colors.white,
            ),
          ),
          // Manual mode controls - compressed
          if (isManualMode)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: Colors.purple[50],
              child: Wrap(
                spacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  Text(
                    'Manual Mode',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[700],
                      fontSize: 14,
                    ),
                  ),
                  _buildCompactButton(
                    onPressed: _clearManualPath,
                    icon: Icons.refresh,
                    label: 'Reset',
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                    isSmall: true,
                  ),
                  _buildCompactButton(
                    onPressed: _exitManualMode,
                    icon: Icons.exit_to_app,
                    label: 'Exit',
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                    isSmall: true,
                  ),
                ],
              ),
            ),
          // Mode selection - compressed
          if (!isManualMode)
            Container(
              padding: EdgeInsets.all(8),
              child: Column(
                children: [
                  Text(
                    'Mode:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildModeButton(InteractionMode.add, Icons.add_location, 'Add'),
                      _buildModeButton(InteractionMode.delete, Icons.delete_outline, 'Delete'),
                      _buildModeButton(InteractionMode.move, Icons.open_with, 'Move'),
                    ],
                  ),
                ],
              ),
            ),
          // Instructions - compressed
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              _getInstructionText(),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
                    blockers: blockers,
                    path: showPath ? path : [],
                    pathLength: pathLength,
                    currentMode: currentMode,
                    draggedCityIndex: draggedCityIndex,
                    draggedBlockerIndex: draggedBlockerIndex,
                    isManualMode: isManualMode,
                    manualPath: manualPath,
                    isPathClosed: isPathClosed,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          // City and blocker count - compressed
          Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Cities: ${cities.length}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(width: 16),
                Text(
                  'Blockers: ${blockers.length}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.brown[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    Color? backgroundColor,
    Color? foregroundColor,
    bool isSmall = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: isSmall ? 14 : 16),
      label: Text(label, style: TextStyle(fontSize: isSmall ? 11 : 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 6 : 8, 
          vertical: isSmall ? 4 : 6
        ),
        minimumSize: Size(0, isSmall ? 28 : 32),
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
          draggedBlockerIndex = null;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[600] : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.blue[800]! : Colors.grey[400]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[700],
              size: 16,
            ),
            SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInstructionText() {
    if (isManualMode) {
      String baseText = 'Click cities in order. Invalid connections blocked.';
      if (manualPath.length == cities.length && !isPathClosed) {
        baseText += ' Click first city to close path.';
      } else if (isPathClosed) {
        baseText += ' Path closed!';
      } else if (manualPath.length < cities.length) {
        baseText += ' Need all ${cities.length} cities to close.';
      }
      return '$baseText (${manualPath.length}/${cities.length})';
    }
    
    switch (currentMode) {
      case InteractionMode.add:
        return 'Tap to add cities. Need 3+ cities for TSP.';
      case InteractionMode.delete:
        return 'Tap cities or blockers to delete.';
      case InteractionMode.move:
        return 'Drag cities or blockers to move.';
      case InteractionMode.manual:
        return 'Click cities in order to build path.';
    }
  }
}

class TSPPainter extends CustomPainter {
  final List<Offset> cities;
  final List<Offset> blockers;
  final List<int> path;
  final double pathLength;
  final InteractionMode currentMode;
  final int? draggedCityIndex;
  final int? draggedBlockerIndex;
  final bool isManualMode;
  final List<int> manualPath;
  final bool isPathClosed;

  TSPPainter({
    required this.cities,
    required this.blockers,
    required this.path,
    required this.pathLength,
    required this.currentMode,
    this.draggedCityIndex,
    this.draggedBlockerIndex,
    required this.isManualMode,
    required this.manualPath,
    required this.isPathClosed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw blockers first (so they appear behind paths)
    Paint blockerPaint = Paint()
      ..color = Colors.brown[600]!
      ..style = PaintingStyle.fill;

    Paint blockerBorderPaint = Paint()
      ..color = Colors.brown[900]!
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    Paint draggedBlockerPaint = Paint()
      ..color = Colors.brown[400]!
      ..style = PaintingStyle.fill;

    Paint draggedBlockerBorderPaint = Paint()
      ..color = Colors.brown[800]!
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < blockers.length; i++) {
      Paint currentBlockerPaint;
      Paint currentBlockerBorderPaint;
      double radius = 8;

      if (i == draggedBlockerIndex) {
        currentBlockerPaint = draggedBlockerPaint;
        currentBlockerBorderPaint = draggedBlockerBorderPaint;
        radius = 10;
      } else {
        currentBlockerPaint = blockerPaint;
        currentBlockerBorderPaint = blockerBorderPaint;
      }

      canvas.drawCircle(blockers[i], radius, currentBlockerPaint);
      canvas.drawCircle(blockers[i], radius, currentBlockerBorderPaint);

      // Draw "B" text on blockers
      TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: 'B',
          style: TextStyle(
            color: Colors.white,
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
          blockers[i].dx - textPainter.width / 2,
          blockers[i].dy - textPainter.height / 2,
        ),
      );
    }

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
          if (i == manualPath.first && manualPath.length == cities.length) {
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