package mapf_test

import "core:testing"
import mapf "../"

test_mapf :: proc(
    width, height: int, walls: [][2]MazeNode, agents: [][3]int,
) -> ([][]mapf.MapfStep(MazeNode), bool) {
    maze, _ := init_maze(width, height, 0, walls)
    defer maze_destroy(maze)

    full_agents: [dynamic]mapf.Agent(Maze, MazeNode)
    for a in agents {
        // start, stall, goal
        agent := mapf.Agent(Maze, MazeNode){
            grid = maze,
            start = MazeNode(a.x),
            stall = a.y,
        }
        agent.grid.goal = MazeNode(a.z)
        append(&full_agents, agent)
    }
    defer delete(full_agents)

    return mapf.multi_agent_conflict_based_search(
        agents          = full_agents[:],
        finish_fn       = maze_finish,
        steps_fn        = maze_steps,
        cost_fn         = maze_cost,
        heur_fn         = maze_heur,
        time_fn         = maze_step_time,
        node_hash_full  = maze_hash_full,
        node_hash_base  = maze_hash_base,
    )
}

@(test)
test_mapf_cbs__single_agent__straight_ahead :: proc(t: ^testing.T) {
    expected := [][]mapf.MapfStep(MazeNode){
        {{0, {0, 1}}, {1, {1, 2}}, {2, {2, 3}}},
    }
    paths, ok := test_mapf(3, 2, {}, {
        {0, 0, 2},
    })
    defer mapf.destroy_paths(paths)

    testing.expect(t, ok)
    for path, i in paths do for step, j in path {
        testing.expect_value(t, step, expected[i][j])
    }
}

@(test)
test_mapf_cbs__two_agents__parallel :: proc(t: ^testing.T) {
    expected := [][]mapf.MapfStep(MazeNode){
        {{0, {0, 1}}, {1, {1, 2}}, {2, {2, 3}}},
        {{3, {0, 1}}, {4, {1, 2}}, {5, {2, 3}}},
    }
    paths, ok := test_mapf(3, 2, {}, {
        {0, 0, 2}, {3, 0, 5},
    })
    defer mapf.destroy_paths(paths)

    testing.expect(t, ok)
    for path, i in paths do for step, j in path {
        testing.expect_value(t, step, expected[i][j])
    }
}

@(test)
test_mapf_cbs__two_agents__plus :: proc(t: ^testing.T) {
    expected := [][]mapf.MapfStep(MazeNode){
        {{3, {0, 2}}, {4, {2, 3}}, {5, {3, 4}}},
        {{7, {0, 1}}, {4, {1, 2}}, {1, {2, 3}}},
    }
    paths, ok := test_mapf(3, 3, {}, {
        {3, 0, 5}, {7, 0, 1},
    })
    defer mapf.destroy_paths(paths)

    testing.expect(t, ok)
    for path, i in paths do for step, j in path {
        testing.expect_value(t, step, expected[i][j])
    }
}

@(test)
test_mapf_cbs__two_agents__alleyway_simple :: proc(t: ^testing.T) {
    expected := [][]mapf.MapfStep(MazeNode){
        {{0, {0, 1}}, {1, {1, 2}}, {2, {2, 3}}},
        {{2, {0, 1}}, {3, {1, 3}}, {2, {3, 4}}, {1, {4, 5}}, {0, {5, 6}}},
    }
    paths, ok := test_mapf(4, 1, {}, {
        {0, 0, 2}, {2, 0, 0},
    })
    defer mapf.destroy_paths(paths)

    testing.expect(t, ok)
    for path, i in paths do for step, j in path {
        testing.expect_value(t, step, expected[i][j])
    }
}

@(test)
test_mapf_cbs__two_agents__alleyway_uturn :: proc(t: ^testing.T) {
    expected := [][]mapf.MapfStep(MazeNode){
        {{0, {0, 1}}, {1, {1, 2}}, {2, {2, 3}}, {6, {3, 4}}, {5, {4, 5}}, {4, {5, 6}}},
        {{1, {0, 1}}, {2, {1, 2}}, {3, {2, 3}}, {2, {3, 4}}, {1, {4, 5}}, {0, {5, 6}}},
    }
    paths, ok := test_mapf(4, 2, {
        {0, 4}, {1, 5},
    }, {
        {0, 0, 4}, {1, 0, 0},
    })
    defer mapf.destroy_paths(paths)

    testing.expect(t, ok)
    for path, i in paths do for step, j in path {
        testing.expect_value(t, step, expected[i][j])
    }
}
