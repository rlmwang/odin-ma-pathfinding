package sapf

import "core:encoding/json"
import "core:fmt"

Graph :: struct($Environment: typeid) {
    env:        Environment,
    start:      i64,
    finished:   proc(env: Environment, node: i64) -> bool,
    options:    proc(env: Environment, node: i64, results: ^[dynamic]i64),
    step:       proc(env: Environment, from, to: i64) -> (i64, f32),
    heuristic:  proc(env: Environment, node: i64) -> f32,
    graph_data: proc(env: Environment, start: i64) -> string,
}

// Finite Abstract Graphs

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
    start:     i64,
    target:    i64,
) -> Graph(FinEnvironment) {
    env := FinEnvironment {
        neighbors = neighbors,
        costs     = costs,
        target    = target,
    }
    return Graph(FinEnvironment) {
        env         = env,
        start       = start,
        finished    = fin_finished,
        options     = fin_options,
        step        = fin_step,
        heuristic   = fin_heuristic,
        graph_data  = fin_graph_data,
    }
}

fin_finished :: proc(env: FinEnvironment, node: i64) -> bool {
    return node == env.target    
}

fin_options :: proc(env: FinEnvironment, node: i64, results: ^[dynamic]i64) {
    clear(results)
    for next in env.neighbors[node] {
        append(results, next)
    }
}

fin_step :: proc(env: FinEnvironment, from, to: i64) -> (i64, f32) {
    return to, env.costs[{from, to}]
}

fin_heuristic :: proc(env: FinEnvironment, node: i64) -> f32 {
    return 0
}

FinSnapshot :: struct {
    neighbors:  map[string][dynamic]i64, 
    costs:      [dynamic]FinCostEntry,
    start:      i64,
    target:     i64,
}
FinCostEntry :: struct {
    u:    i64,
    v:    i64,
    cost: f32,
}
fin_graph_data :: proc(env: FinEnvironment, start: i64) -> string {
    snapshot := FinSnapshot{
        neighbors = make(map[string][dynamic]i64),
        costs     = make([dynamic]FinCostEntry),
        start     = start,
        target    = env.target,
    }

    for node, list in env.neighbors {
        node_str := fmt.tprintf("%d", node) 
        snapshot.neighbors[node_str] = list
    }
    for edge, val in env.costs {
        append(&snapshot.costs, FinCostEntry{u = edge.from, v = edge.to, cost = val})
    }
    json_bytes, _ := json.marshal(snapshot)
    return string(json_bytes)
}

fin_reset_bridge :: proc(session: rawptr) -> StepResult {
    typed_session := (^Session(FinEnvironment))(session)
    return _reset(typed_session)
}

fin_step_bridge :: proc(session: rawptr, action: i64) -> StepResult {
    typed_session := (^Session(FinEnvironment))(session)
    return _step(typed_session, action)
}

fin_graph_bridge :: proc(session: rawptr) -> string {
    typed_session := (^Session(FinEnvironment))(session)
    return typed_session.graph.graph_data(typed_session.graph.env, typed_session.graph.start)
}
