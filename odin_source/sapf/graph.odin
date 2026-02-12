package sapf


Graph :: struct($Environment: typeid) {
    env: Environment,
    finished_fn:  proc(env: Environment, node: i64) -> bool,
    options_fn:   proc(env: Environment, node: i64, results: ^[dynamic]i64),
    step_fn:      proc(env: Environment, from, to: i64) -> i64,
    cost_fn:      proc(env: Environment, from, to: i64) -> f32,
    heuristic_fn: proc(env: Environment, node: i64) -> f32,
}


// Finite Graphs

FinEdge :: struct {
    from, to: i64,
}

FinEnvironment :: struct {
    neighbors:  map[i64][dynamic]i64,
    costs:      map[FinEdge]f32,
    target:     i64,
}

make_finite_graph :: proc(
    neighbors: map[i64][dynamic]i64, 
    costs:     map[FinEdge]f32, 
    target:    i64,
) -> Graph(FinEnvironment) {
    env := FinEnvironment {
        neighbors = neighbors,
        costs     = costs,
        target    = target,
    }

    return Graph(FinEnvironment) {
        env          = env,
        finished_fn  = fin_finished_fn,
        options_fn   = fin_options_fn,
        step_fn      = fin_step_fn,
        cost_fn      = fin_cost_fn,
        heuristic_fn = fin_heuristic_fn,
    }
}

fin_finished_fn :: proc(env: FinEnvironment, node: i64) -> bool {
    return node == env.target    
}

fin_options_fn :: proc(env: FinEnvironment, node: i64, results: ^[dynamic]i64) {
    clear(results)
    for next in env.neighbors[node] {
        append(results, next)
    }
}

fin_step_fn :: proc(env: FinEnvironment, from, to: i64) -> i64 {
    return to
}

fin_cost_fn :: proc(env: FinEnvironment, from, to: i64) -> f32 {
    return env.costs[{from, to}]
}

fin_heuristic_fn :: proc(env: FinEnvironment, node: i64) -> f32 {
    return 0
}

fin_reset_bridge :: proc(session: rawptr) -> StepResult {
    typed_session := (^Session(FinEnvironment))(session)
    return _reset(typed_session)
}

fin_step_bridge :: proc(session: rawptr, action: i64) -> StepResult {
    typed_session := (^Session(FinEnvironment))(session)
    return _step(typed_session, action)
}
