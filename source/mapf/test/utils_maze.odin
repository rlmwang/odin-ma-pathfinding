package mapf_test

Dir :: enum{RIGHT, DOWN, LEFT, UP}
Dir_Set :: bit_set[Dir]

Maze :: struct{
    width, height: int,
    walls: []Dir_Set,
    goal: MazeNode,
}

MazeNode :: distinct int

init_maze :: proc(width, height: int, goal: MazeNode, walls: [][2]MazeNode) -> (Maze, bool) {
    if int(goal) >= width * height do return {}, false
    maze := Maze{
        width = width, height = height, goal = goal,
        walls = make([]Dir_Set, width * height),
    }
    for i in 0..<height {
        maze.walls[i * width] += {.LEFT}
        maze.walls[i * width + width - 1] += {.RIGHT}
    }
    for j in 0..<width {
        maze.walls[j] += {.UP}
        maze.walls[width * height - j - 1] += {.DOWN}
    }
    for w in walls {
        if int(w.x) >= width * height || int(w.y) >= width * height do return maze, false
        switch int(w.y - w.x) {
        case 1:
            maze.walls[w.x] += {.RIGHT}
            maze.walls[w.y] += {.LEFT}
        case -1:
            maze.walls[w.x] += {.LEFT}
            maze.walls[w.y] += {.RIGHT}
        case width:
            maze.walls[w.x] += {.DOWN}
            maze.walls[w.y] += {.UP}
        case -width:
            maze.walls[w.x] += {.UP}
            maze.walls[w.y] += {.DOWN}
        case:
            return maze, false
        }
    }
    return maze, true
}

maze_finish :: proc(maze: Maze, position: MazeNode) -> bool {
    return position == maze.goal
}

@(require_results)
maze_steps :: proc(maze: Maze, position: MazeNode, time: int) -> []MazeNode {
    steps: [dynamic]MazeNode
    for dir in ~maze.walls[position] {
        vec := DIR_TO_VEC[dir]
        append(&steps, position + MazeNode(vec.x + vec.y * maze.width))
    }
    return steps[:]
}

maze_cost :: proc(maze: Maze, from, to: MazeNode, time, wait: int) -> f32 {
    return f32(1 + wait)
}

maze_heur :: proc(maze: Maze, position: MazeNode) -> f32 {
    diff := int(maze.goal - position)
    return f32(abs(diff % maze.width) + abs(diff / maze.width))
}

maze_hash_full :: proc(node: MazeNode) -> int {
    return 2 * int(node) - 1
}

maze_hash_base :: proc(node: MazeNode) -> int {
    return int(node) + 3
}

maze_step_time :: proc(maze: Maze, from, to: MazeNode, time, wait: int) -> int {
    return 1
}

maze_destroy :: proc(maze: Maze) {
    delete(maze.walls)
}

DIR_TO_VEC := [Dir][2]int{
    .RIGHT = { 1,  0},
    .LEFT  = {-1,  0},
    .UP    = { 0, -1},
    .DOWN  = { 0,  1},
}
