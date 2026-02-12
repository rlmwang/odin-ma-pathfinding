package sapf

Session :: struct($Environment: typeid, $Node: typeid) {
    graph:        Graph(Environment, Node),
    start_node:   Node,
    current_node: Node,
    total_reward: f32,
    is_done:      bool,
}

_init :: proc(session: ^Session($Environment, $Node), graph: Graph(Environment, Node), start: Node) {
    session.graph = graph
    session.start_node = start
    _reset(session)
}

_reset :: proc(session: ^Session($Environment, $Node)) {
    session.current_node = session.start_node
    session.total_reward = 0
    session.is_done = false
}

_step :: proc(session: ^Session($Environment, $Node), action: Node) -> (reward: f32, done: bool) {    
    if session.is_done do return 0, true
    
    cost := session.graph.cost_fn(session.graph.env, session.current_node, action)
    session.current_node = action

    if session.graph.finished_fn(session.graph.env, session.current_node) {
        session.is_done = true
        return -cost, true
    }
    return -cost, false
}
