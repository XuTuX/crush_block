import 'dart:math';

/// 영역을 생성하는 함수
/// seed가 주어지면 결정론적으로 생성하되, 유효하지 않을 경우 seed를 점진적으로 변형하여 재시도
List<List<int>> generateRegions(int gridSize, int numTeams, int maxRegionSize,
    {int? seed}) {
  List<List<int>> grid;
  bool valid;
  int attempt = 0;
  const int maxAttempts = 50;

  do {
    // seed가 주어진 경우, 시도할 때마다 seed를 변형하여 다른 결과를 얻음
    final effectiveSeed = seed != null ? seed + attempt : null;
    grid = List.generate(gridSize, (_) => List.filled(gridSize, -1));
    Random random = effectiveSeed != null ? Random(effectiveSeed) : Random();

    List<int> teamCellCounts = List.filled(numTeams, 0);
    List<Map<String, dynamic>> frontierList = [];

    // 각 팀에 시드 셀 배치
    for (int team = 0; team < numTeams; team++) {
      int row, col;
      int seedAttempts = 0;
      do {
        row = random.nextInt(gridSize);
        col = random.nextInt(gridSize);
        seedAttempts++;
        if (seedAttempts > gridSize * gridSize * 2) break; // 안전장치
      } while (grid[row][col] != -1);

      grid[row][col] = team;
      teamCellCounts[team]++;
      frontierList.add({'point': Point(row, col), 'team': team});
    }

    // 영역 확장
    int expansionIterations = 0;
    final int maxExpansionIterations = gridSize * gridSize * 4; // 안전장치

    while (grid.any((row) => row.contains(-1))) {
      expansionIterations++;
      if (expansionIterations > maxExpansionIterations) break; // 무한루프 방지

      // 최대 영역 크기를 초과한 팀의 프론티어 제거
      frontierList.removeWhere(
          (cellInfo) => teamCellCounts[cellInfo['team']] >= maxRegionSize);

      if (frontierList.isEmpty) {
        // 프론티어가 비었을 때 남은 셀을 할당
        if (!assignRemainingCells(grid, gridSize)) break;
        continue;
      }

      // 확장 우선순위 조정: 현재 가장 작은 영역을 가진 팀들의 모든 프론티어 셀 중 하나를 무작위로 선택
      frontierList.sort((a, b) =>
          teamCellCounts[a['team']].compareTo(teamCellCounts[b['team']]));

      int minCount = teamCellCounts[frontierList[0]['team']];
      List<Map<String, dynamic>> candidates = frontierList
          .where((cell) => teamCellCounts[cell['team']] == minCount)
          .toList();

      var cellInfo = candidates[random.nextInt(candidates.length)];
      int team = cellInfo['team'];
      Point<int> point = cellInfo['point'];

      // 인접한 셀 중 하나 선택
      var neighbors = getNeighbors(grid, gridSize, point, unassigned: true);

      if (neighbors.isEmpty) {
        frontierList.remove(cellInfo);
        continue;
      }

      // 뭉침 현상(blob)을 유도하기 위해, 같은 팀 셀과 더 많이 인접한 이웃을 선호함
      neighbors.shuffle(random);
      neighbors.sort((a, b) {
        int aSame = _countSameTeamNeighbors(grid, gridSize, a, team);
        int bSame = _countSameTeamNeighbors(grid, gridSize, b, team);
        return bSame.compareTo(aSame); // 인접한 같은 팀 셀이 많을수록 앞으로
      });

      Point<int> neighbor = neighbors.first;
      grid[neighbor.x][neighbor.y] = team;
      teamCellCounts[team]++;
      frontierList.add({'point': neighbor, 'team': team});
    }

    // 남은 -1 셀이 있으면 강제로 할당 (반복적으로)
    int fillPasses = 0;
    while (grid.any((row) => row.contains(-1)) &&
        fillPasses < gridSize * gridSize) {
      if (!assignRemainingCells(grid, gridSize)) {
        // 인접한 할당된 셀이 없는 고립된 셀을 강제 할당
        _forceAssignIsolatedCells(grid, gridSize, random);
        break;
      }
      fillPasses++;
    }

    // 각 팀의 영역이 최소 크기를 충족하는지 확인
    valid = teamCellCounts.every((count) => confirmMinArea(count));
    attempt++;

    // 최대 시도 횟수 초과 시 현재 결과를 그대로 사용 (멈추는 것보다 나음)
    if (attempt >= maxAttempts) {
      valid = true;
    }
  } while (!valid);

  return grid;
}

/// 고립된 셀(-1)을 인접 여부와 관계없이 가장 가까운 팀에 강제 할당
void _forceAssignIsolatedCells(
    List<List<int>> grid, int gridSize, Random random) {
  for (int i = 0; i < gridSize; i++) {
    for (int j = 0; j < gridSize; j++) {
      if (grid[i][j] == -1) {
        // 가장 가까운 할당된 셀 찾기
        int bestTeam = 0;
        double bestDist = double.infinity;
        for (int r = 0; r < gridSize; r++) {
          for (int c = 0; c < gridSize; c++) {
            if (grid[r][c] != -1) {
              double dist = (r - i).abs() + (c - j).abs().toDouble();
              if (dist < bestDist) {
                bestDist = dist;
                bestTeam = grid[r][c];
              }
            }
          }
        }
        grid[i][j] = bestTeam;
      }
    }
  }
}

/// 특정 셀과 인접한 같은 팀의 셀 개수를 세는 함수
int _countSameTeamNeighbors(
    List<List<int>> grid, int gridSize, Point<int> point, int team) {
  int count = 0;
  List<Point<int>> directions = [
    const Point(-1, 0),
    const Point(1, 0),
    const Point(0, -1),
    const Point(0, 1),
  ];

  for (var dir in directions) {
    int nx = point.x + dir.x;
    int ny = point.y + dir.y;
    if (nx >= 0 && nx < gridSize && ny >= 0 && ny < gridSize) {
      if (grid[nx][ny] == team) {
        count++;
      }
    }
  }
  return count;
}

bool confirmMinArea(int count) {
  // Relaxed from 7 to 4 to ensure faster generation and more diverse layouts
  return count >= 5;
}

/// 남은 셀을 할당하는 함수
bool assignRemainingCells(List<List<int>> grid, int gridSize) {
  bool changed = false;
  for (int i = 0; i < gridSize; i++) {
    for (int j = 0; j < gridSize; j++) {
      if (grid[i][j] == -1) {
        var neighbors =
            getNeighbors(grid, gridSize, Point(i, j), unassigned: false);
        if (neighbors.isNotEmpty) {
          int team = grid[neighbors.first.x][neighbors.first.y];
          grid[i][j] = team;
          changed = true;
        }
      }
    }
  }
  return changed;
}

/// 인접한 셀들을 반환하는 함수
List<Point<int>> getNeighbors(
    List<List<int>> grid, int gridSize, Point<int> point,
    {bool unassigned = false}) {
  List<Point<int>> neighbors = [];
  List<Point<int>> directions = [
    const Point(-1, 0), // 위
    const Point(1, 0), // 아래
    const Point(0, -1), // 왼쪽
    const Point(0, 1), // 오른쪽
  ];

  for (var dir in directions) {
    int newRow = point.x + dir.x;
    int newCol = point.y + dir.y;
    if (newRow >= 0 && newRow < gridSize && newCol >= 0 && newCol < gridSize) {
      if (unassigned && grid[newRow][newCol] == -1) {
        neighbors.add(Point(newRow, newCol));
      } else if (!unassigned && grid[newRow][newCol] != -1) {
        neighbors.add(Point(newRow, newCol));
      }
    }
  }
  return neighbors;
}
