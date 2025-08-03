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

class TSPHomePage extends StatefulWidget {
  @override
  _TSPHomePageState createState() => _TSPHomePageState();
}

enum InteractionMode { add, delete, move }

class _TSPHomePageState extends State<TSPHomePage> {
  List<Offset> cities = [];
  List<int> path = [];
  double pathLength = 0.0;
  bool showPath = false;
  InteractionMode currentMode = InteractionMode.add;
  int? draggedCityIndex;

  void _handleTap(TapDownDetails details) {
    if (currentMode == InteractionMode.add) {
      _addCity(details);
    } else if (currentMode == InteractionMode.delete) {
      _deleteCity(details.localPosition);
    }
  }

  void _addCity(TapDownDetails details) {
    setState(() {
      cities.add(details.localPosition);
      _resetPath();
    });
  }

  void _deleteCity(Offset tapPosition) {
    const double tapRadius = 20.0; // Larger tap area for easier deletion
    
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
    if (currentPath.length > 2) {
      length += _calculateDistance(cities[currentPath.last], cities[currentPath.first]);
    }
    return length;
  }

  void _solveTSP() {
    if (cities.length < 3) return;

    setState(() {
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
          // Mode selection
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
                  onPressed: _clearCities,
                  icon: Icon(Icons.clear),
                  label: Text('Clear'),
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
          draggedCityIndex = null; // Reset any ongoing drag
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
    switch (currentMode) {
      case InteractionMode.add:
        return 'Tap anywhere to add cities. Need minimum 3 cities to solve TSP.';
      case InteractionMode.delete:
        return 'Tap on any city to delete it.';
      case InteractionMode.move:
        return 'Drag any city to move it. Path length updates in real-time.';
    }
  }
}

class TSPPainter extends CustomPainter {
  final List<Offset> cities;
  final List<int> path;
  final double pathLength;
  final InteractionMode currentMode;
  final int? draggedCityIndex;

  TSPPainter({
    required this.cities,
    required this.path,
    required this.pathLength,
    required this.currentMode,
    this.draggedCityIndex,
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

      // Close the loop
      if (path.length > 2) {
        drawPath.lineTo(cities[path[0]].dx, cities[path[0]].dy);
      }

      canvas.drawPath(drawPath, pathPaint);

      // Draw arrows to show direction
      Paint arrowPaint = Paint()
        ..color = Colors.blue[800]!
        ..strokeWidth = 1.5;

      for (int i = 0; i < path.length; i++) {
        int nextIndex = (i + 1) % path.length;
        if (path.length == 2 && i == 1) break; // Don't draw arrow back for 2 cities

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

    for (int i = 0; i < cities.length; i++) {
      Paint currentCityPaint;
      Paint currentBorderPaint;
      Color textColor = Colors.white;

      // Choose colors based on current mode and state
      if (currentMode == InteractionMode.delete) {
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
        } else {
          currentCityPaint = moveCityPaint;
          currentBorderPaint = moveCityBorderPaint;
        }
      } else {
        currentCityPaint = cityPaint;
        currentBorderPaint = cityBorderPaint;
      }

      double radius = (i == draggedCityIndex) ? 10 : 8;
      
      canvas.drawCircle(cities[i], radius, currentCityPaint);
      canvas.drawCircle(cities[i], radius, currentBorderPaint);

      // Draw city number
      TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: i.toString(),
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