package mapf_test

import "core:testing"
import mapf "../"

test_sapf :: proc(
    width: int, height: int,
    start: MazeNode, stall: int, goal: MazeNode,
    walls: [][2]MazeNode, constraints: [][4]MazeNode,
) -> ([]mapf.MapfStep(MazeNode), bool, bool) {
    node_constraints := make(map[int][dynamic]mapf.Constraint)
    defer mapf.destroy_constraints(node_constraints)

    for v in constraints {
        if v.x != v.y do continue
        container, ok := &node_constraints[maze_hash_base(v.x)]
        if !ok {
            node_constraints[maze_hash_base(v.x)] = [dynamic]mapf.Constraint{}
            container = &node_constraints[maze_hash_base(v.x)]
        }
        append(container, mapf.Constraint{int(v.z), int(v.w)})
    }

    edge_constraints := make(map[[2]int][dynamic]mapf.Constraint)
    defer mapf.destroy_constraints(edge_constraints)

    for v in constraints {
        if v.x == v.y do continue
        container, ok := &edge_constraints[{maze_hash_base(v.x), maze_hash_base(v.y)}]
        if !ok {
            edge_constraints[{maze_hash_base(v.x), maze_hash_base(v.y)}] = [dynamic]mapf.Constraint{}
            container = &edge_constraints[{maze_hash_base(v.x), maze_hash_base(v.y)}]
        }
        append(container, mapf.Constraint{int(v.z), int(v.w)})
    }

    maze, maze_ok := init_maze(width, height, goal, walls)
    defer maze_destroy(maze)

    path, _, path_ok := mapf.a_star_constrained(
        grid             = maze,
        start            = start,
        stall            = stall,
        finish        = maze_finish,
        steps         = maze_steps,
        cost          = maze_cost,
        heur          = maze_heur,
        time     = maze_step_time,
        node_hash_full   = maze_hash_full,
        node_hash_base   = maze_hash_base,
        node_constraints = node_constraints,
        edge_constraints = edge_constraints,
    )
    return path, maze_ok, path_ok
}

@(test)
test_sapf__empty :: proc(t: ^testing.T) {
    expected := [][3]int{
        {0, 0, 1}, {1, 1, 2}, {4, 2, 3}, {7, 3, 4}, {8, 4, 5},
    }
    path, maze_ok, path_ok := test_sapf(3, 3, 0, 0, 8, {}, {})
    defer delete(path)

    testing.expect(t, maze_ok)
    testing.expect(t, path_ok)
    for step, idx in path {
        testing.expect_value(t, step.position, MazeNode(expected[idx].x))
        testing.expect_value(t, step.interval, expected[idx].yz)
    }
}

@(test)
test_sapf__force_down :: proc(t: ^testing.T) {
    expected := [][3]int{
        {0, 0, 1}, {3, 1, 2}, {6, 2, 3}, {7, 3, 4}, {8, 4, 5},
    }
    path, maze_ok, path_ok := test_sapf(3, 3, 0, 0, 8, {
        {0, 1}, {3, 4},
    }, {})
    defer delete(path)

    testing.expect(t, maze_ok)
    testing.expect(t, path_ok)
    for step, idx in path {
        testing.expect_value(t, step.position, MazeNode(expected[idx].x))
        testing.expect_value(t, step.interval, expected[idx].yz)
    }
}

@(test)
test_sapf__force_right :: proc(t: ^testing.T) {
    expected := [][3]int{
        {0, 0, 1}, {1, 1, 2}, {2, 2, 3}, {5, 3, 4}, {8, 4, 5},
    }
    path, maze_ok, path_ok := test_sapf(3, 3, 0, 0, 8, {
        {0, 3}, {1, 4},
    }, {})
    defer delete(path)

    testing.expect(t, maze_ok)
    testing.expect(t, path_ok)
    for step, idx in path {
        testing.expect_value(t, step.position, MazeNode(expected[idx].x))
        testing.expect_value(t, step.interval, expected[idx].yz)
    }
}

@(test)
test_sapf__center_blocked :: proc(t: ^testing.T) {
    expected := [][3]int{
        {0, 0, 1}, {1, 1, 2}, {2, 2, 3}, {5, 3, 4}, {8, 4, 5},
    }
    path, maze_ok, path_ok := test_sapf(3, 3, 0, 0, 8, {
        {1, 4}, {3, 4}, {4, 5}, {4, 7},
    }, {})
    defer delete(path)

    testing.expect(t, maze_ok)
    testing.expect(t, path_ok)
    for step, idx in path {
        testing.expect_value(t, step.position, MazeNode(expected[idx].x))
        testing.expect_value(t, step.interval, expected[idx].yz)
    }
}

@(test)
test_sapf__go_to_center :: proc(t: ^testing.T) {
    expected := [][3]int{
        {0, 0, 1}, {3, 1, 2}, {6, 2, 3}, {7, 3, 4}, {4, 4, 5},
    }
    path, maze_ok, path_ok := test_sapf(3, 3, 0, 0, 4, {
        {1, 4}, {3, 4}, {4, 5},
    }, {})
    defer delete(path)

    testing.expect(t, maze_ok)
    testing.expect(t, path_ok)
    for step, idx in path {
        testing.expect_value(t, step.position, MazeNode(expected[idx].x))
        testing.expect_value(t, step.interval, expected[idx].yz)
    }
}

@(test)
test_sapf__dont_wait_at_start :: proc(t: ^testing.T) {
    expected := [][3]int{
        {0, 0, 1}, {1, 1, 2},
    }
    path, maze_ok, path_ok := test_sapf(2, 1, 0, 0, 1, {}, {
        {1, 1, 0, 1},
    })
    defer delete(path)

    testing.expect(t, maze_ok)
    testing.expect(t, path_ok)
    for step, idx in path {
        testing.expect_value(t, step.position, MazeNode(expected[idx].x))
        testing.expect_value(t, step.interval, expected[idx].yz)
    }
}

@(test)
test_sapf__wait_at_start :: proc(t: ^testing.T) {
    expected := [][3]int{
        {0, 0, 3}, {1, 3, 4},
    }
    path, maze_ok, path_ok := test_sapf(2, 1, 0, 0, 1, {}, {
        {1, 1, 0, 3},
    })
    defer delete(path)

    testing.expect(t, maze_ok)
    testing.expect(t, path_ok)
    for step, idx in path {
        testing.expect_value(t, step.position, MazeNode(expected[idx].x))
        testing.expect_value(t, step.interval, expected[idx].yz)
    }
}

@(test)
test_sapf__still_wait_at_start :: proc(t: ^testing.T) {
    expected := [][3]int{
        {0, 0, 3}, {1, 3, 4},
    }
    path, maze_ok, path_ok := test_sapf(2, 1, 0, 0, 1, {}, {
        {1, 1, 1, 3},
    })
    defer delete(path)

    testing.expect(t, maze_ok)
    testing.expect(t, path_ok)
    for step, idx in path {
        testing.expect_value(t, step.position, MazeNode(expected[idx].x))
        testing.expect_value(t, step.interval, expected[idx].yz)
    }
}

@(test)
test_sapf__just_squeeze_through :: proc(t: ^testing.T) {
    expected := [][3]int{
        {0, 0, 1}, {1, 1, 2},
    }
    path, maze_ok, path_ok := test_sapf(2, 1, 0, 0, 1, {}, {
        {1, 1, 2, 3},
    })
    defer delete(path)

    testing.expect(t, maze_ok)
    testing.expect(t, path_ok)
    for step, idx in path {
        testing.expect_value(t, step.position, MazeNode(expected[idx].x))
        testing.expect_value(t, step.interval, expected[idx].yz)
    }
}

@(test)
test_sapf__wait_and_squeeze :: proc(t: ^testing.T) {
    expected := [][3]int{
        {0, 0, 3}, {1, 3, 4},
    }
    path, maze_ok, path_ok := test_sapf(2, 1, 0, 0, 1, {}, {
        {1, 1, 1, 3}, {1, 1, 4, 5},
    })
    defer delete(path)

    testing.expect(t, maze_ok)
    testing.expect(t, path_ok)
    for step, idx in path {
        testing.expect_value(t, step.position, MazeNode(expected[idx].x))
        testing.expect_value(t, step.interval, expected[idx].yz)
    }
}

@(test)
test_sapf__zig_zag :: proc(t: ^testing.T) {
    expected := [][3]int{
        {0, 0, 2}, {1, 2, 4}, {0, 4, 6}, {1, 6, 8}, {2, 8, 9},
    }
    path, maze_ok, path_ok := test_sapf(3, 1, 0, 0, 2, {}, {
        {0, 0, 2, 4}, {1, 1, 0, 2}, {1, 1, 4, 6}, {2, 2, 0, 8},
    })
    defer delete(path)

    testing.expect(t, maze_ok)
    testing.expect(t, path_ok)
    for step, idx in path {
        testing.expect_value(t, step.position, MazeNode(expected[idx].x))
        testing.expect_value(t, step.interval, expected[idx].yz)
    }
}

@(test)
test_sapf__zig_zag__start_too_tight :: proc(t: ^testing.T) {
    path, maze_ok, path_ok := test_sapf(3, 1, 0, 0, 2, {}, {
        {0, 0, 1, 4}, {1, 1, 0, 2}, {1, 1, 4, 6}, {2, 2, 0, 8},
    })
    defer delete(path)

    testing.expect(t, maze_ok)
    testing.expect(t, !path_ok)
}

@(test)
test_sapf__zig_zag__middle_too_tight :: proc(t: ^testing.T) {
    path, maze_ok, path_ok := test_sapf(3, 1, 0, 0, 2, {}, {
        {0, 0, 2, 4}, {1, 1, 0, 2}, {1, 1, 3, 6}, {2, 2, 0, 8},
    })
    defer delete(path)

    testing.expect(t, maze_ok)
    testing.expect(t, !path_ok)
}

@(test)
test_sapf__zig_zag__tower :: proc(t: ^testing.T) {
    expected := [][3]int{
        {0, 0, 1}, {1, 1, 2}, {0, 2, 3}, {1, 3, 4},
        {0, 4, 5}, {1, 5, 6}, {0, 6, 7}, {1, 7, 8}, {2, 8, 9},
    }
    path, maze_ok, path_ok := test_sapf(3, 1, 0, 0, 2, {}, {
        {1, 1, 0, 1}, {0, 0, 1, 2}, {1, 1, 2, 3}, {0, 0, 3, 4}, 
        {1, 1, 4, 5}, {0, 0, 5, 6}, {1, 1, 6, 7}, {2, 2, 0, 8},
    })
    defer delete(path)

    testing.expect(t, maze_ok)
    testing.expect(t, path_ok)
    for step, idx in path {
        testing.expect_value(t, step.position, MazeNode(expected[idx].x))
        testing.expect_value(t, step.interval, expected[idx].yz)
    }
}

@(test)
test_sapf__edge_wait :: proc(t: ^testing.T) {
    expected := [][3]int{
        {0, 0, 2}, {1, 2, 3}, {2, 3, 4},
    }
    path, maze_ok, path_ok := test_sapf(3, 1, 0, 0, 2, {}, {
        {0, 1, 0, 1},
    })
    defer delete(path)

    testing.expect(t, maze_ok)
    testing.expect(t, path_ok)
    for step, idx in path {
        testing.expect_value(t, step.position, MazeNode(expected[idx].x))
        testing.expect_value(t, step.interval, expected[idx].yz)
    }
}

@(test)
test_sapf__edge_sneak :: proc(t: ^testing.T) {
    expected := [][3]int{
        {0, 0, 1}, {1, 1, 2}, {2, 2, 3},
    }
    path, maze_ok, path_ok := test_sapf(3, 1, 0, 0, 2, {}, {
        {0, 1, 1, 2},
    })
    defer delete(path)

    testing.expect(t, maze_ok)
    testing.expect(t, path_ok)
    for step, idx in path {
        testing.expect_value(t, step.position, MazeNode(expected[idx].x))
        testing.expect_value(t, step.interval, expected[idx].yz)
    }
}

@(test)
test_sapf__node_edge_combo :: proc(t: ^testing.T) {
    expected := [][3]int{
        {0, 0, 3}, {1, 3, 4}, {2, 4, 5},
    }
    path, maze_ok, path_ok := test_sapf(3, 1, 0, 0, 2, {}, {
        {0, 1, 1, 2}, {1, 1, 0, 2},
    })
    defer delete(path)

    testing.expect(t, maze_ok)
    testing.expect(t, path_ok)
    for step, idx in path {
        testing.expect_value(t, step.position, MazeNode(expected[idx].x))
        testing.expect_value(t, step.interval, expected[idx].yz)
    }
}

@(test)
test_sapf__edge_and_max_wait :: proc(t: ^testing.T) {
    path, maze_ok, path_ok := test_sapf(3, 1, 0, 0, 2, {}, {
        {0, 0, 1, 2}, {0, 1, 0, 1},
    })
    defer delete(path)

    testing.expect(t, maze_ok)
    testing.expect(t, !path_ok)
}
