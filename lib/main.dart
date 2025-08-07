import 'package:flutter/material.dart';
import 'dart:math';

void main() {
  runApp(TSPApp());
}

// Constants extracted for better maintainability
class TSPConstants {
  // Visual Constants
  static const double cityRadius = 8.0;
  static const double blockerRadius = 8.0;
  static const double tapRadius = 25.0; // Increased for better mobile experience
  static const double dragRadius = 30.0; // Larger drag area
  static const double pathStrokeWidth = 2.5;
  static const double arrowStrokeWidth = 2.0;
  static const double highlightRadius = 12.0;
  
  // Layout Constants
  static const double buttonSpacing = 8.0;
  static const double buttonPadding = 12.0;
  static const double compactButtonPadding = 8.0;
  static const double canvasMargin = 12.0;
  static const double controlPanelPadding = 16.0;
  static const double minButtonSize = 44.0; // iOS/Android minimum touch target
  
  // Algorithm Constants
  static const int maxOptimizationIterations = 500;
  static const int geneticAlgorithmPopulation = 30;
  static const int geneticAlgorithmGenerations = 50;
  static const double mutationRate = 0.1;
  static const double crossoverRate = 0.8;
  
  // Blocker Constants
  static const int defaultBlockerCount = 3;
  static const double minDistanceFromCities = 35.0;
  static const double minDistanceBetweenBlockers = 30.0;
  static const double canvasMarginForBlockers = 25.0;
  static const int maxBlockerPlacementAttempts = 300;
}

class TSPApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advanced TSP Solver',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: TSPHomePage(),
    );
  }
}

enum InteractionMode { add, delete, move, manual }
enum TSPAlgorithm { nearestNeighbor, genetic, twoOpt }

class TSPHomePage extends StatefulWidget {
  @override
  _TSPHomePageState createState() => _TSPHomePageState();
}

class _TSPHomePageState extends State<TSPHomePage> {
  GlobalKey canvasKey = GlobalKey();
  List<Offset> cities = [];
  List<Offset> blockers = [];
  List<int> path = [];
  double pathLength = 0.0;
  bool showPath = false;
  InteractionMode currentMode = InteractionMode.add;
  TSPAlgorithm selectedAlgorithm = TSPAlgorithm.nearestNeighbor;
  int? draggedCityIndex;
  int? draggedBlockerIndex;
  bool isManualMode = false;
  List<int> manualPath = [];
  bool isPathClosed = false;
  bool isSolving = false;

  void _handleTap(TapDownDetails details) {
    if (isSolving) return;
    
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
    // Check cities first
    for (int i = 0; i < cities.length; i++) {
      if (_isWithinRadius(cities[i], tapPosition, TSPConstants.tapRadius)) {
        setState(() {
          cities.removeAt(i);
          _resetPath();
        });
        return;
      }
    }
    
    // Check blockers
    for (int i = 0; i < blockers.length; i++) {
      if (_isWithinRadius(blockers[i], tapPosition, TSPConstants.tapRadius)) {
        setState(() {
          blockers.removeAt(i);
          _resetPath();
        });
        return;
      }
    }
  }

  bool _isWithinRadius(Offset point1, Offset point2, double radius) {
    return _calculateDistance(point1, point2) <= radius;
  }

  void _handleManualPathBuilding(Offset tapPosition) {
    for (int i = 0; i < cities.length; i++) {
      if (_isWithinRadius(cities[i], tapPosition, TSPConstants.tapRadius)) {
        setState(() {
          int existingIndex = manualPath.indexOf(i);
          
          if (existingIndex != -1) {
            // Handle clicking on existing city in path
            if (i == manualPath.first && manualPath.length == cities.length && !isPathClosed) {
              // Try to close the path
              if (_isValidPath([...manualPath, manualPath.first])) {
                isPathClosed = true;
                path = List.from(manualPath);
                pathLength = _calculatePathLength(path);
              }
            } else if (isPathClosed && i == manualPath.first) {
              // Reopen the path
              isPathClosed = false;
              pathLength = _calculatePathLength(manualPath);
            } else {
              // Retract to this point
              manualPath = manualPath.sublist(0, existingIndex + 1);
              path = List.from(manualPath);
              isPathClosed = false;
              pathLength = _calculatePathLength(manualPath);
            }
          } else {
            // Add new city to path
            if (manualPath.isEmpty || _isValidConnection(cities[manualPath.last], cities[i])) {
              manualPath.add(i);
              path = List.from(manualPath);
              isPathClosed = false;
              pathLength = _calculatePathLength(manualPath);
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
    if (currentMode != InteractionMode.move || isSolving) return;
    
    // Check cities first
    for (int i = 0; i < cities.length; i++) {
      if (_isWithinRadius(cities[i], details.localPosition, TSPConstants.dragRadius)) {
        draggedCityIndex = i;
        return;
      }
    }
    
    // Check blockers
    for (int i = 0; i < blockers.length; i++) {
      if (_isWithinRadius(blockers[i], details.localPosition, TSPConstants.dragRadius)) {
        draggedBlockerIndex = i;
        return;
      }
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (currentMode != InteractionMode.move || isSolving) return;
    
    setState(() {
      if (draggedCityIndex != null) {
        cities[draggedCityIndex!] = details.localPosition;
        if (showPath) {
          pathLength = _calculatePathLength(path);
        }
      }
      if (draggedBlockerIndex != null) {
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
      Random random = Random();
      int attempts = 0;
      int addedBlockers = 0;
      
      while (addedBlockers < TSPConstants.defaultBlockerCount && 
             attempts < TSPConstants.maxBlockerPlacementAttempts) {
        attempts++;
        
        // // Use conservative canvas size
        // double canvasWidth = 320.0;
        // double canvasHeight = 240.0;
        final RenderBox renderBox = canvasKey.currentContext!.findRenderObject() as RenderBox;
        final Size size = renderBox.size;
        
        double canvasWidth = size.width - 32;
        double canvasHeight = size.height - 25;

        double x = TSPConstants.canvasMarginForBlockers + 
                  random.nextDouble() * (canvasWidth - 2 * TSPConstants.canvasMarginForBlockers);
        double y = TSPConstants.canvasMarginForBlockers + 
                  random.nextDouble() * (canvasHeight - 2 * TSPConstants.canvasMarginForBlockers);
        Offset newBlocker = Offset(x, y);
        
        if (_isValidBlockerPosition(newBlocker)) {
          blockers.add(newBlocker);
          addedBlockers++;
        }
      }
      
      _resetPath();
    });
  }

  bool _isValidBlockerPosition(Offset position) {
    // Check distance from cities
    for (Offset city in cities) {
      if (_calculateDistance(city, position) < TSPConstants.minDistanceFromCities) {
        return false;
      }
    }
    
    // Check distance from other blockers
    for (Offset blocker in blockers) {
      if (_calculateDistance(blocker, position) < TSPConstants.minDistanceBetweenBlockers) {
        return false;
      }
    }
    
    return true;
  }

  double _calculateDistance(Offset a, Offset b) {
    return sqrt(pow(a.dx - b.dx, 2) + pow(a.dy - b.dy, 2));
  }

  bool _isValidConnection(Offset start, Offset end) {
    for (Offset blocker in blockers) {
      if (_lineIntersectsCircle(start, end, blocker, TSPConstants.blockerRadius)) {
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
    double A = lineEnd.dy - lineStart.dy;
    double B = lineStart.dx - lineEnd.dx;
    double C = lineEnd.dx * lineStart.dy - lineStart.dx * lineEnd.dy;
    
    double distance = (A * circleCenter.dx + B * circleCenter.dy + C).abs() / sqrt(A * A + B * B);
    
    if (distance > radius) return false;
    
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
    
    // Add distance back to start if path should be closed
    if (currentPath.length > 2 && (!isManualMode || isPathClosed)) {
      length += _calculateDistance(cities[currentPath.last], cities[currentPath.first]);
    }
    return length;
  }

  // Enhanced TSP Solver with multiple algorithms
  Future<void> _solveTSP() async {
    if (cities.length < 3 || isSolving) return;

    setState(() {
      isSolving = true;
      isManualMode = false;
      isPathClosed = false;
    });

    try {
      List<int>? solution;
      
      switch (selectedAlgorithm) {
        case TSPAlgorithm.nearestNeighbor:
          solution = await _solveNearestNeighbor();
          break;
        case TSPAlgorithm.genetic:
          solution = await _solveGeneticAlgorithm();
          break;
        case TSPAlgorithm.twoOpt:
          solution = await _solveTwoOpt();
          break;
      }

      setState(() {
        if (solution != null && solution.length == cities.length) {
          // Verify the solution is valid with blockers
          if (_isValidPath([...solution, solution.first])) {
            path = solution;
            pathLength = _calculatePathLength(path);
            showPath = true;
          } else {
            // Clear if invalid
            path.clear();
            showPath = false;
            pathLength = 0.0;
          }
        } else {
          path.clear();
          showPath = false;
          pathLength = 0.0;
        }
        isSolving = false;
      });
    } catch (e) {
      setState(() {
        isSolving = false;
        path.clear();
        showPath = false;
        pathLength = 0.0;
      });
    }
  }

  Future<List<int>?> _solveNearestNeighbor() async {
    await Future.delayed(Duration(milliseconds: 100));
    
    List<bool> visited = List.filled(cities.length, false);
    List<int> solution = [0];
    visited[0] = true;

    for (int i = 0; i < cities.length - 1; i++) {
      int current = solution.last;
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
        solution.add(nearest);
        visited[nearest] = true;
      } else {
        return null; // Cannot complete tour
      }
    }

    // Check if we can complete the tour
    if (_isValidConnection(cities[solution.last], cities[solution.first])) {
      return solution;
    } else {
      return null;
    }
  }

  Future<List<int>?> _solveTwoOpt() async {
    // Start with nearest neighbor, then improve with 2-opt
    List<int>? initialSolution = await _solveNearestNeighbor();
    if (initialSolution == null) return null;

    await Future.delayed(Duration(milliseconds: 200));
    
    List<int> currentSolution = List.from(initialSolution);
    double currentLength = _calculatePathLength(currentSolution);
    bool improved = true;
    int iterations = 0;

    while (improved && iterations < TSPConstants.maxOptimizationIterations) {
      improved = false;
      iterations++;

      for (int i = 1; i < currentSolution.length - 1; i++) {
        for (int j = i + 1; j < currentSolution.length; j++) {
          if (j - i == 1) continue;

          // Create new path with 2-opt swap
          List<int> newSolution = List.from(currentSolution);
          _reverse(newSolution, i, j);

          // Check if new path is valid and better
          if (_isValidPath([...newSolution, newSolution.first])) {
            double newLength = _calculatePathLength(newSolution);
            if (newLength < currentLength) {
              currentSolution = newSolution;
              currentLength = newLength;
              improved = true;
            }
          }
        }
      }
    }

    return currentSolution;
  }

  void _reverse(List<int> path, int start, int end) {
    while (start < end) {
      int temp = path[start];
      path[start] = path[end];
      path[end] = temp;
      start++;
      end--;
    }
  }

  Future<List<int>?> _solveGeneticAlgorithm() async {
    await Future.delayed(Duration(milliseconds: 300));
    
    Random random = Random();
    
    // Generate initial population
    List<List<int>> population = [];
    for (int i = 0; i < TSPConstants.geneticAlgorithmPopulation; i++) {
      List<int> individual = List.generate(cities.length, (index) => index);
      // Keep first city fixed, shuffle the rest
      individual.sublist(1).shuffle(random);
      population.add(individual);
    }

    for (int generation = 0; generation < TSPConstants.geneticAlgorithmGenerations; generation++) {
      // Evaluate fitness (shorter paths are better, so use 1/distance)
      List<double> fitness = population.map((individual) {
        if (_isValidPath([...individual, individual.first])) {
          double length = _calculatePathLength(individual);
          return length > 0 ? 1.0 / length : 0.0;
        } else {
          return 0.0; // Invalid paths get zero fitness
        }
      }).toList();

      // Selection and breeding
      List<List<int>> newPopulation = [];
      
      // Elitism - keep best individual
      int bestIndex = 0;
      double bestFitness = fitness[0];
      for (int i = 1; i < fitness.length; i++) {
        if (fitness[i] > bestFitness) {
          bestFitness = fitness[i];
          bestIndex = i;
        }
      }
      
      if (bestFitness > 0) {
        newPopulation.add(List.from(population[bestIndex]));
      }

      while (newPopulation.length < TSPConstants.geneticAlgorithmPopulation) {
        // Tournament selection
        List<int> parent1 = _tournamentSelection(population, fitness, random);
        List<int> parent2 = _tournamentSelection(population, fitness, random);

        // Crossover
        List<int> child = random.nextDouble() < TSPConstants.crossoverRate
            ? _orderCrossover(parent1, parent2, random)
            : List.from(parent1);

        // Mutation
        if (random.nextDouble() < TSPConstants.mutationRate) {
          _mutate(child, random);
        }

        newPopulation.add(child);
      }

      population = newPopulation;
    }

    // Return best solution
    List<double> finalFitness = population.map((individual) {
      if (_isValidPath([...individual, individual.first])) {
        double length = _calculatePathLength(individual);
        return length > 0 ? 1.0 / length : 0.0;
      } else {
        return 0.0;
      }
    }).toList();

    int bestIndex = 0;
    double bestFitness = finalFitness[0];
    for (int i = 1; i < finalFitness.length; i++) {
      if (finalFitness[i] > bestFitness) {
        bestFitness = finalFitness[i];
        bestIndex = i;
      }
    }

    return bestFitness > 0 ? population[bestIndex] : null;
  }

  List<int> _tournamentSelection(List<List<int>> population, List<double> fitness, Random random) {
    int tournamentSize = 3;
    List<int> bestIndividual = population[0];
    double bestFitness = fitness[0];

    for (int i = 0; i < tournamentSize; i++) {
      int randomIndex = random.nextInt(population.length);
      if (fitness[randomIndex] > bestFitness) {
        bestIndividual = population[randomIndex];
        bestFitness = fitness[randomIndex];
      }
    }

    return List.from(bestIndividual);
  }

  List<int> _orderCrossover(List<int> parent1, List<int> parent2, Random random) {
    int length = parent1.length;
    List<int> child = List.filled(length, -1);
    
    // Select a random segment from parent1
    int start = random.nextInt(length);
    int end = random.nextInt(length);
    if (start > end) {
      int temp = start;
      start = end;
      end = temp;
    }

    // Copy segment from parent1
    for (int i = start; i <= end; i++) {
      child[i] = parent1[i];
    }

    // Fill remaining positions with cities from parent2 in order
    Set<int> used = Set.from(child.where((x) => x != -1));
    int childIndex = 0;
    
    for (int i = 0; i < length; i++) {
      if (!used.contains(parent2[i])) {
        while (childIndex < length && child[childIndex] != -1) {
          childIndex++;
        }
        if (childIndex < length) {
          child[childIndex] = parent2[i];
        }
      }
    }

    return child;
  }

  void _mutate(List<int> individual, Random random) {
    if (individual.length < 3) return;
    
    // Swap mutation (avoid swapping the first city)
    int index1 = 1 + random.nextInt(individual.length - 1);
    int index2 = 1 + random.nextInt(individual.length - 1);
    
    int temp = individual[index1];
    individual[index1] = individual[index2];
    individual[index2] = temp;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Advanced TSP Solver'),
        backgroundColor: Colors.blue[700],
        elevation: 2,
      ),
      body: Column(
        children: [
          // Path length and algorithm display
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(TSPConstants.controlPanelPadding),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.straighten, color: Colors.blue[700]),
                    SizedBox(width: TSPConstants.buttonSpacing),
                    Text(
                      'Path Length: ${pathLength.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Algorithm: ${_getAlgorithmName(selectedAlgorithm)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          // Algorithm selector
          Padding(
            padding: EdgeInsets.all(TSPConstants.compactButtonPadding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Algorithm: ', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<TSPAlgorithm>(
                  value: selectedAlgorithm,
                  onChanged: isSolving ? null : (TSPAlgorithm? newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedAlgorithm = newValue;
                      });
                    }
                  },
                  items: TSPAlgorithm.values.map((TSPAlgorithm algorithm) {
                    return DropdownMenuItem<TSPAlgorithm>(
                      value: algorithm,
                      child: Text(_getAlgorithmName(algorithm)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          
          // Main control buttons with better spacing
          Padding(
            padding: EdgeInsets.symmetric(horizontal: TSPConstants.buttonSpacing),
            child: Wrap(
              spacing: TSPConstants.buttonSpacing,
              runSpacing: TSPConstants.buttonSpacing,
              alignment: WrapAlignment.center,
              children: [
                _buildEnhancedButton(
                  onPressed: cities.length >= 3 && !isSolving ? _solveTSP : null,
                  icon: isSolving ? Icons.hourglass_empty : Icons.route,
                  label: isSolving ? 'Solving...' : 'Solve',
                  color: Colors.blue,
                ),
                _buildEnhancedButton(
                  onPressed: cities.length >= 2 && !isSolving ? _startManualMode : null,
                  icon: Icons.touch_app,
                  label: 'Manual',
                  color: isManualMode ? Colors.purple : Colors.grey,
                ),
                _buildEnhancedButton(
                  onPressed: !isSolving ? _clearCities : null,
                  icon: Icons.clear,
                  label: 'Clear',
                  color: Colors.red,
                ),
                _buildEnhancedButton(
                  onPressed: !isSolving ? _addRandomBlockers : null,
                  icon: Icons.block,
                  label: 'Add Blockers',
                  color: Colors.brown,
                ),
              ],
            ),
          ),
          
          // Manual mode controls with improved spacing
          if (isManualMode)
            Container(
              margin: EdgeInsets.all(TSPConstants.compactButtonPadding),
              padding: EdgeInsets.all(TSPConstants.buttonPadding),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple[200]!),
              ),
              child: Column(
                children: [
                  Text(
                    'Manual Mode Active',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[700],
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: TSPConstants.buttonSpacing),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCompactButton(
                        onPressed: _clearManualPath,
                        icon: Icons.refresh,
                        label: 'Reset Path',
                        backgroundColor: Colors.orange[600],
                        foregroundColor: Colors.white,
                      ),
                      SizedBox(width: TSPConstants.buttonSpacing),
                      _buildCompactButton(
                        onPressed: _exitManualMode,
                        icon: Icons.exit_to_app,
                        label: 'Exit Manual',
                        backgroundColor: Colors.grey[600],
                        foregroundColor: Colors.white,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          
          // Mode selection with better touch targets
          if (!isManualMode && !isSolving)
            Container(
              padding: EdgeInsets.all(TSPConstants.buttonPadding),
              child: Column(
                children: [
                  Text(
                    'Interaction Mode',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: TSPConstants.buttonSpacing),
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
          
          // Instructions with better typography
          Padding(
            padding: EdgeInsets.symmetric(horizontal: TSPConstants.buttonPadding, vertical: 8),
            child: Text(
              _getInstructionText(),
              style: TextStyle(
                color: Colors.grey[600], 
                fontSize: 11,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Drawing canvas with better margins
          Expanded(
            child: Container(
              key: canvasKey,
              margin: EdgeInsets.all(TSPConstants.canvasMargin),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!, width: 2),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: GestureDetector(
                  onTapDown: _handleTap,
                  onPanStart: _handlePanStart,
                  onPanUpdate: _handlePanUpdate,
                  onPanEnd: _handlePanEnd,
                  child: CustomPaint(
                    painter: EnhancedTSPPainter(
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
                      isSolving: isSolving,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
          
          // Status bar with counts and better spacing
          Container(
            padding: EdgeInsets.all(TSPConstants.buttonPadding),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatusItem(Icons.location_city, 'Cities', cities.length.toString(), Colors.red[600]!),
                _buildStatusItem(Icons.block, 'Blockers', blockers.length.toString(), Colors.brown[600]!),
                if (showPath)
                  _buildStatusItem(Icons.route, 'Path Steps', path.length.toString(), Colors.blue[600]!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required MaterialColor color,
  }) {
    return SizedBox(
      height: TSPConstants.minButtonSize,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color[600],
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: TSPConstants.buttonPadding,
            vertical: TSPConstants.compactButtonPadding,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildCompactButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return SizedBox(
      height: 36,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: TextStyle(fontSize: 9)),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
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
        height: TSPConstants.minButtonSize,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[600] : Colors.grey[200],
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? Colors.blue[800]! : Colors.grey[400]!,
            width: 2,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ] : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[700],
              size: 20,
            ),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(height: 2),
        Text(
          '$label: $value',
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _getAlgorithmName(TSPAlgorithm algorithm) {
    switch (algorithm) {
      case TSPAlgorithm.nearestNeighbor:
        return 'Nearest Neighbor';
      case TSPAlgorithm.genetic:
        return 'Genetic Algorithm';
      case TSPAlgorithm.twoOpt:
        return '2-Opt Optimization';
    }
  }

  String _getInstructionText() {
    if (isSolving) {
      return 'Solving TSP with ${_getAlgorithmName(selectedAlgorithm)}...';
    }
    
    if (isManualMode) {
      String baseText = 'Click cities in order to build path manually. Blockers prevent invalid connections.';
      if (manualPath.length == cities.length && !isPathClosed) {
        baseText += ' Click first city to close the path.';
      } else if (isPathClosed) {
        baseText += ' Path completed successfully!';
      } else if (manualPath.isNotEmpty) {
        baseText += ' Progress: ${manualPath.length}/${cities.length} cities visited.';
      }
      return baseText;
    }
    
    switch (currentMode) {
      case InteractionMode.add:
        return 'Tap anywhere to add cities. You need at least 3 cities to solve the TSP.';
      case InteractionMode.delete:
        return 'Tap on cities or blockers to remove them from the canvas.';
      case InteractionMode.move:
        return 'Drag cities or blockers to reposition them. Path will update automatically.';
      case InteractionMode.manual:
        return 'Click cities in the order you want to visit them.';
    }
  }
}

class EnhancedTSPPainter extends CustomPainter {
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
  final bool isSolving;

  EnhancedTSPPainter({
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
    required this.isSolving,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawModeIndicator(canvas, size);
    
    if (isSolving) {
      _drawSolvingIndicator(canvas, size);
    }
    _drawBlockers(canvas);
    _drawPath(canvas);
    _drawCities(canvas);
  }

  void _drawBlockers(Canvas canvas) {
    for (int i = 0; i < blockers.length; i++) {
      double radius = TSPConstants.blockerRadius;
      Color fillColor = Colors.brown[600]!;
      Color borderColor = Colors.brown[900]!;
      double strokeWidth = 2.0;

      // Highlight dragged blocker
      if (i == draggedBlockerIndex) {
        fillColor = Colors.brown[400]!;
        borderColor = Colors.brown[800]!;
        strokeWidth = 3.0;
        radius = TSPConstants.highlightRadius;
      }

      Paint fillPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill;

      Paint borderPaint = Paint()
        ..color = borderColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(blockers[i], radius, fillPaint);
      canvas.drawCircle(blockers[i], radius, borderPaint);

      // Draw "B" label
      _drawText(canvas, blockers[i], 'B', Colors.white, 12, FontWeight.bold, true);
    }
  }

  void _drawPath(Canvas canvas) {
    if (path.length < 2) return;

    Paint pathPaint = Paint()
      ..color = Colors.blue[600]!
      ..strokeWidth = TSPConstants.pathStrokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw path lines
    for (int i = 0; i < path.length - 1; i++) {
      canvas.drawLine(cities[path[i]], cities[path[i + 1]], pathPaint);
    }

    // Draw closing line if needed
    if (path.length > 2 && (!isManualMode || isPathClosed)) {
      canvas.drawLine(cities[path.last], cities[path.first], pathPaint);
    }

    // Draw direction arrows
    _drawDirectionArrows(canvas);
  }

  void _drawDirectionArrows(Canvas canvas) {
    Paint arrowPaint = Paint()
      ..color = Colors.blue[800]!
      ..strokeWidth = TSPConstants.arrowStrokeWidth
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < path.length; i++) {
      int nextIndex = (i + 1) % path.length;
      if (path.length == 2 && i == 1) break;
      if (isManualMode && !isPathClosed && i == path.length - 1) break;

      Offset from = cities[path[i]];
      Offset to = cities[path[nextIndex]];
      
      // Arrow position (75% along the line)
      Offset arrowPos = Offset(
        from.dx + (to.dx - from.dx) * 0.75,
        from.dy + (to.dy - from.dy) * 0.75,
      );

      // Arrow direction
      double angle = atan2(to.dy - from.dy, to.dx - from.dx);
      
      // Draw arrowhead with better proportions
      double arrowLength = 12;
      double arrowAngle = 0.6;
      
      canvas.drawLine(
        arrowPos,
        Offset(
          arrowPos.dx - arrowLength * cos(angle - arrowAngle),
          arrowPos.dy - arrowLength * sin(angle - arrowAngle),
        ),
        arrowPaint,
      );
      canvas.drawLine(
        arrowPos,
        Offset(
          arrowPos.dx - arrowLength * cos(angle + arrowAngle),
          arrowPos.dy - arrowLength * sin(angle + arrowAngle),
        ),
        arrowPaint,
      );
    }
  }

  void _drawCities(Canvas canvas) {
    for (int i = 0; i < cities.length; i++) {
      Map<String, dynamic> appearance = _getCityAppearance(i);
      double radius = appearance['radius'];
      Color fillColor = appearance['fillColor'];
      Color borderColor = appearance['borderColor'];
      double strokeWidth = appearance['strokeWidth'];

      Paint fillPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill;

      Paint borderPaint = Paint()
        ..color = borderColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(cities[i], radius, fillPaint);
      canvas.drawCircle(cities[i], radius, borderPaint);

      // Draw city label
      String label = _getCityLabel(i);
      _drawText(canvas, cities[i], label, Colors.white, 12, FontWeight.bold, true);
    }
  }

  Map<String, dynamic> _getCityAppearance(int cityIndex) {
    double radius = TSPConstants.cityRadius;
    Color fillColor = Colors.red[600]!;
    Color borderColor = Colors.red[900]!;
    double strokeWidth = 2.0;
    
    if (isManualMode) {
      int pathIndex = manualPath.indexOf(cityIndex);
      
      if (pathIndex != -1) {
        // City is in manual path
        fillColor = Colors.purple[400]!;
        borderColor = Colors.purple[900]!;
        
        // Special highlighting for closeable path
        if (cityIndex == manualPath.first && manualPath.length == cities.length) {
          if (isPathClosed) {
            fillColor = Colors.teal[600]!;
            borderColor = Colors.teal[900]!;
            strokeWidth = 4.0;
          } else {
            fillColor = Colors.lime[600]!;
            borderColor = Colors.lime[900]!;
            strokeWidth = 3.0;
          }
          radius = TSPConstants.highlightRadius;
        }
        
        // Highlight current end of path
        if (pathIndex == manualPath.length - 1 && cityIndex != manualPath.first) {
          fillColor = Colors.amber[600]!;
          borderColor = Colors.amber[900]!;
          strokeWidth = 3.0;
          radius = TSPConstants.highlightRadius;
        }
      } else {
        fillColor = Colors.purple[600]!;
        borderColor = Colors.purple[900]!;
      }
    } else {
      // Mode-based appearance
      switch (currentMode) {
        case InteractionMode.delete:
          fillColor = Colors.red[300]!;
          borderColor = Colors.red[600]!;
          break;
        case InteractionMode.move:
          if (cityIndex == draggedCityIndex) {
            fillColor = Colors.orange[600]!;
            borderColor = Colors.orange[900]!;
            strokeWidth = 3.0;
            radius = TSPConstants.highlightRadius;
          } else {
            fillColor = Colors.green[600]!;
            borderColor = Colors.green[900]!;
          }
          break;
        default:
          fillColor = Colors.red[600]!;
          borderColor = Colors.red[900]!;
          break;
      }
    }
    
    return {
      'radius': radius,
      'fillColor': fillColor,
      'borderColor': borderColor,
      'strokeWidth': strokeWidth,
    };
  }

  String _getCityLabel(int cityIndex) {
    if (isManualMode) {
      int pathIndex = manualPath.indexOf(cityIndex);
      return pathIndex != -1 ? (pathIndex + 1).toString() : cityIndex.toString();
    }
    return cityIndex.toString();
  }

  void _drawModeIndicator(Canvas canvas, Size size) {
    String modeText = _getModeText();
    Color modeColor = _getModeColor();

    _drawText(
      canvas,
      Offset(15, 15),
      modeText,
      modeColor,
      14,
      FontWeight.bold,
      false,
    );
  }

  void _drawSolvingIndicator(Canvas canvas, Size size) {
    // Draw semi-transparent overlay
    Paint overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.3);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlayPaint);

    // Draw indicator in center
    Offset center = Offset(size.width / 2, size.height / 2);
    Paint indicatorPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Simple circle indicator
    canvas.drawCircle(center, 30, indicatorPaint);
    
    _drawText(
      canvas,
      Offset(center.dx, center.dy + 50),
      'Solving...',
      Colors.white,
      16,
      FontWeight.bold,
      false,
    );
  }

  String _getModeText() {
    if (isSolving) return 'SOLVING';
    if (isManualMode) return 'MANUAL MODE';
    
    switch (currentMode) {
      case InteractionMode.add:
        return 'ADD MODE';
      case InteractionMode.delete:
        return 'DELETE MODE';
      case InteractionMode.move:
        return 'MOVE MODE';
      case InteractionMode.manual:
        return 'MANUAL MODE';
    }
  }

  Color _getModeColor() {
    if (isSolving) return Colors.orange[600]!;
    if (isManualMode) return Colors.purple[600]!;
    
    switch (currentMode) {
      case InteractionMode.add:
        return Colors.blue[600]!;
      case InteractionMode.delete:
        return Colors.red[600]!;
      case InteractionMode.move:
        return Colors.green[600]!;
      case InteractionMode.manual:
        return Colors.purple[600]!;
    }
  }

  void _drawText(Canvas canvas, Offset position, String text, 
  Color color, double fontSize, FontWeight fontWeight, bool center) {
    TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (center ? position.dx - textPainter.width / 2 : position.dx),
        (center ? position.dy - textPainter.height / 2 : position.dy),
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is! EnhancedTSPPainter) return true;
    
    // Add check for "draggedBlockerIndex != null" to workaround blocker position freeze 
    // when showing path

    return cities != oldDelegate.cities ||
           blockers != oldDelegate.blockers ||
           path != oldDelegate.path ||
           currentMode != oldDelegate.currentMode ||
           draggedCityIndex != oldDelegate.draggedCityIndex ||
           draggedBlockerIndex != oldDelegate.draggedBlockerIndex ||
           draggedBlockerIndex != null ||
           isManualMode != oldDelegate.isManualMode ||
           manualPath != oldDelegate.manualPath ||
           isPathClosed != oldDelegate.isPathClosed ||
           isSolving != oldDelegate.isSolving;
  }
}