package sapf


Graph :: struct($Environment: typeid, $Node: typeid) {
    env: Environment,
    finished_fn:  proc(env: Environment, node: Node) -> bool,
    options_fn:   proc(env: Environment, node: Node, results: ^[dynamic]Node),
    cost_fn:      proc(env: Environment, from, to: Node) -> f32,
    heuristic_fn: proc(env: Environment, node: Node) -> f32,
}


// Finite Graphs

FinNode :: i32
FinEdge :: struct {
    from, to: FinNode,
}

FinEnvironment :: struct {
    neighbors:  map[FinNode][dynamic]FinNode,
    costs:      map[FinEdge]f32,
    target:     FinNode,
}

make_finite_graph :: proc(
    neighbors: map[FinNode][dynamic]FinNode, 
    costs:     map[FinEdge]f32, 
    target:    FinNode,
) -> Graph(FinEnvironment, FinNode) {
    env := FinEnvironment {
        neighbors = neighbors,
        costs     = costs,
        target    = target,
    }

    return Graph(FinEnvironment, FinNode) {
        env          = env,
        finished_fn  = fin_finished_fn,
        options_fn   = fin_options_fn,
        cost_fn      = fin_cost_fn,
        heuristic_fn = fin_heuristic_fn,
    }
}

fin_finished_fn :: proc(env: FinEnvironment, node: FinNode) -> bool {
    return node == env.target    
}

fin_options_fn :: proc(env: FinEnvironment, node: FinNode, results: ^[dynamic]FinNode) {
    clear(results)
    for next in env.neighbors[node] {
        append(results, next)
    }
}

fin_cost_fn :: proc(env: FinEnvironment, from, to: FinNode) -> f32 {
    return env.costs[{from, to}]
}

fin_heuristic_fn :: proc(env: FinEnvironment, node: FinNode) -> f32 {
    return 0
}
