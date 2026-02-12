package sapf

Session :: struct($Environment: typeid) {
    graph:        Graph(Environment),
    start_node:   i64,
    current_node: i64,
    total_reward: f32,
    is_done:      bool,
}

StepResult :: struct {
    reward: f32,
    done:   b32,
    node:   i64,
}

_init :: proc(session: ^Session($Environment), graph: Graph(Environment), start: i64) {
    session.graph = graph
    session.start_node = start
    _reset(session)
}

_reset :: proc(session: ^Session($Environment)) -> StepResult {
    session.current_node = session.start_node
    session.total_reward = 0
    session.is_done = false
    return {0, false, session.current_node}
}

_step :: proc(session: ^Session($Environment), action: i64) -> StepResult {    
    if session.is_done {
        return {0, true, session.current_node}
    }
    cost := session.graph.cost_fn(session.graph.env, session.current_node, action)
    session.current_node = action

    if session.graph.finished_fn(session.graph.env, session.current_node) {
        session.is_done = true
        return {-cost, true, session.current_node}
    }
    return {-cost, false, session.current_node}
}
