package mapf

import "core:slice"
import pq "core:container/priority_queue"


Agent :: struct($Grid, $Node: typeid) {
    grid: Grid, start: Node, stall: int,
}

ConflictNode :: struct {
    parent:     int,
    agent:      int,
    path:       int,
    precedence: Precedence,
    path_cost:  f32,
    node_cost:  f32,
}

ConflictStep :: struct {
    node:   int,
    cost:   f32,
}

Conflict :: struct($Node: typeid) {
    agent_a:    int,
    agent_b:    int,
    step_a:     MapfStep(Node),
    step_b:     MapfStep(Node),
    priority:   int,
}

Precedence :: struct {
    agent:  int,
    edge:   [2]int,
    time:   [2]int,
}

multi_agent_conflict_based_search :: proc(
    agents:         []Agent($Grid, $Node),
    steps_fn:       proc(grid: Grid, position: Node, time: int) -> []Node,
    time_fn:        proc(grid: Grid, from, to: Node, time, wait: int) -> int,
    cost_fn:        proc(grid: Grid, from, to: Node, time, wait: int) -> f32,
    heur_fn:        proc(grid: Grid, position: Node) -> f32,
    finish_fn:      proc(grid: Grid, position: Node) -> bool,
    node_hash_full: proc(node: Node) -> int,
    node_hash_base: proc(node: Node) -> int,
) -> ([][]MapfStep(Node), bool) {
    N := len(agents)

    paths: [dynamic][]MapfStep(Node)

    costs: [dynamic]f32
    defer delete(costs)

    tree: [dynamic]ConflictNode
    defer delete(tree)

    node_constraints := make(map[int][dynamic]Constraint)
    defer destroy_constraints(node_constraints)

    edge_constraints := make(map[[2]int][dynamic]Constraint)
    defer destroy_constraints(edge_constraints)

    agent: Agent(Grid, Node)
    new: ConflictNode

    cost: f32
    path: []MapfStep(Node)
    path_ok: bool

    conflict: Conflict(Node)
    has_conflict: bool

    queue: pq.Priority_Queue(ConflictStep)
    pq.init(&queue, less=cbs_less, swap=cbs_swap, capacity=64)
    defer pq.destroy(&queue)

    // initial paths

    for ag in agents {
        path, cost, path_ok = a_star_constrained(
            grid             = ag.grid,
            start            = ag.start,
            stall            = ag.stall,
            finish_fn        = finish_fn,
            steps_fn         = steps_fn,
            cost_fn          = cost_fn,
            heur_fn          = heur_fn,
            time_fn     = time_fn,
            node_hash_full   = node_hash_full,
            node_hash_base   = node_hash_base,
            node_constraints = {},
            edge_constraints = {},
        )

        if !path_ok do return {}, false
        append(&paths, path)
        append(&costs, cost)
    }

    // initial conflicts

    conflict = {}
    has_conflict = false
    for j in 0..<N do for i in 0..<j {
        new_conflict, ok := find_first_conflict(
            paths[i], paths[j], node_hash_base,
        )
        if !ok do continue

        new_conflict.priority = get_priority(new_conflict)
        if has_conflict && new_conflict.priority >= conflict.priority do continue

        new_conflict.agent_a = i
        new_conflict.agent_b = j
        conflict = new_conflict
        has_conflict = true
    }
    if !has_conflict do return paths[:], true

    // initial node A

    agent = agents[conflict.agent_a]
    new   = ConflictNode{
        parent = -1,
        agent  = conflict.agent_a,
        precedence = {
            agent = conflict.agent_b,
            edge  = {
                node_hash_base(conflict.step_b.position),
                node_hash_base(conflict.step_a.position),
            },
            time  = conflict.step_b.interval,
        },
        path = len(paths),
    }
    fetch_constraints(tree[:], &node_constraints, &edge_constraints, new, conflict.agent_a)
    path, new.path_cost, path_ok = a_star_constrained(
        grid             = agent.grid,
        start            = agent.start,
        stall            = agent.stall,
        finish_fn        = finish_fn,
        steps_fn         = steps_fn,
        cost_fn          = cost_fn,
        heur_fn          = heur_fn,
        time_fn     = time_fn,
        node_hash_full   = node_hash_full,
        node_hash_base   = node_hash_base,
        node_constraints = node_constraints,
        edge_constraints = edge_constraints,
    )

    if path_ok {
        new.node_cost = fetch_costs(tree[:], new, costs[:])
        pq.push(&queue, ConflictStep{node = len(tree), cost = new.node_cost})
        append(&paths, path)
        append(&tree, new)
    }

    // initial node B

    agent = agents[conflict.agent_b]
    new   = ConflictNode{
        parent = -1,
        agent  = conflict.agent_b,
        precedence = {
            agent = conflict.agent_a,
            edge  = {
                node_hash_base(conflict.step_a.position),
                node_hash_base(conflict.step_b.position),
            },
            time  = conflict.step_a.interval,
        },
        path = len(paths),
    }
    fetch_constraints(tree[:], &node_constraints, &edge_constraints, new, conflict.agent_b)
    path, new.path_cost, path_ok = a_star_constrained(
        grid             = agent.grid,
        start            = agent.start,
        stall            = agent.stall,
        finish_fn        = finish_fn,
        steps_fn         = steps_fn,
        cost_fn          = cost_fn,
        heur_fn          = heur_fn,
        time_fn     = time_fn,
        node_hash_full   = node_hash_full,
        node_hash_base   = node_hash_base,
        node_constraints = node_constraints,
        edge_constraints = edge_constraints,
    )
    
    if path_ok {
        new.node_cost = fetch_costs(tree[:], new, costs[:])
        pq.push(&queue, ConflictStep{node = len(tree), cost = new.node_cost})
        append(&paths, path)
        append(&tree, new)
    }

    // start loop

    for pq.len(queue) > 0 {
        step := pq.pop(&queue)
        if step.node > 1_000 do break

        to_path := fetch_paths(tree[:], step.node, paths[:], len(agents))
        defer delete(to_path)

        // find conflicts

        conflict = {}
        has_conflict = false
        for j in 0..<N do for i in 0..<j {
            new_conflict, ok := find_first_conflict(
                paths[to_path[i]], paths[to_path[j]], node_hash_base,
            )
            if !ok do continue

            new_conflict.priority = get_priority(new_conflict)
            if has_conflict && new_conflict.priority >= conflict.priority do continue

            new_conflict.agent_a = i
            new_conflict.agent_b = j
            conflict = new_conflict
            has_conflict = true
        }
        if !has_conflict {
            res: [dynamic][]MapfStep(Node)
            for i in 0..<N {
                pa: [dynamic]MapfStep(Node)
                for st in paths[to_path[i]] do append(&pa, st)
                append(&res, pa[:])
            }
            destroy_paths(paths[:])
            return res[:], true
        }

        // parse node A
    
        agent = agents[conflict.agent_a]
        new   = ConflictNode{
            parent = step.node,
            agent  = conflict.agent_a,
            precedence = {
                agent = conflict.agent_b,
                edge  = {
                    node_hash_base(conflict.step_b.position),
                    node_hash_base(conflict.step_a.position),
                },
                time  = conflict.step_b.interval,
            },
            path = len(paths),
        }
        fetch_constraints(tree[:], &node_constraints, &edge_constraints, new, conflict.agent_a)
        path, new.path_cost, path_ok = a_star_constrained(
            grid             = agent.grid,
            start            = agent.start,
            stall            = agent.stall,
            finish_fn        = finish_fn,
            steps_fn         = steps_fn,
            cost_fn          = cost_fn,
            heur_fn          = heur_fn,
            time_fn     = time_fn,
            node_hash_full   = node_hash_full,
            node_hash_base   = node_hash_base,
            node_constraints = node_constraints,
            edge_constraints = edge_constraints,
        )
        if path_ok {
            new.node_cost = fetch_costs(tree[:], new, costs[:])
            pq.push(&queue, ConflictStep{node = len(tree), cost = new.node_cost})
            append(&paths, path)
            append(&tree, new)
        }

        // parse node B

        agent = agents[conflict.agent_b]
        new   = ConflictNode{
            parent = step.node,
            agent  = conflict.agent_b,
            precedence = {
                agent = conflict.agent_a,
                edge  = {
                    node_hash_base(conflict.step_a.position),
                    node_hash_base(conflict.step_b.position),
                },
                time  = conflict.step_a.interval,
            },
            path = len(paths),
        }
        fetch_constraints(tree[:], &node_constraints, &edge_constraints, new, conflict.agent_b)
        path, new.path_cost, path_ok = a_star_constrained(
            grid             = agent.grid,
            start            = agent.start,
            stall            = agent.stall,
            finish_fn        = finish_fn,
            steps_fn         = steps_fn,
            cost_fn          = cost_fn,
            heur_fn          = heur_fn,
            time_fn     = time_fn,
            node_hash_full   = node_hash_full,
            node_hash_base   = node_hash_base,
            node_constraints = node_constraints,
            edge_constraints = edge_constraints,
        )
        if path_ok {
            new.node_cost = fetch_costs(tree[:], new, costs[:])
            pq.push(&queue, ConflictStep{node = len(tree), cost = new.node_cost})
            append(&paths, path)
            append(&tree, new)
        }
    }
    
    destroy_paths(paths[:])
    return {}, false
}

fetch_constraints :: proc(
    tree: []ConflictNode,
    node_constraints: ^map[int][dynamic]Constraint,
    edge_constraints: ^map[[2]int][dynamic]Constraint,
    node: ConflictNode,
    agent: int,
) {
    node := node
    prec := node.precedence

    for _, &n_cons in node_constraints do clear(&n_cons)
    for _, &e_cons in edge_constraints do clear(&e_cons)

    if prec.edge.x == prec.edge.y {
        n_cons, n_ok := &node_constraints[prec.edge.x]
        if !n_ok {
            node_constraints[prec.edge.x] = {}
            n_cons = &node_constraints[prec.edge.x]
        }
        append(n_cons, prec.time)
    } else {
        e_cons, e_ok := &edge_constraints[prec.edge.yx]
        if !e_ok {
            edge_constraints[prec.edge.yx] = {}
            e_cons = &edge_constraints[prec.edge.yx]
        }
        append(e_cons, prec.time)
    }
    for node.parent >= 0 {
        node = tree[node.parent]
        prec = node.precedence
        if prec.agent == agent do continue

        if prec.edge.x == prec.edge.y {
            n_cons, n_ok := &node_constraints[prec.edge.x]
            if !n_ok {
                node_constraints[prec.edge.x] = {}
                n_cons = &node_constraints[prec.edge.x]
            }
            append(n_cons, prec.time)
        } else {
            e_cons, e_ok := &edge_constraints[prec.edge.yx]
            if !e_ok {
                edge_constraints[prec.edge.yx] = {}
                e_cons = &edge_constraints[prec.edge.yx]
            }
            append(e_cons, prec.time)
        }
    }

    for _, &n_cons in node_constraints do slice.sort_by(n_cons[:], constraint_less)
    for _, &e_cons in edge_constraints do slice.sort_by(e_cons[:], constraint_less)
}

find_first_conflict :: proc(
    path_a:     []MapfStep($Node),
    path_b:     []MapfStep(Node),
    hash_node:  proc(node: Node) -> int,
) -> (Conflict(Node), bool) {
    if len(path_a) == 0 || len(path_b) == 0 do return {}, false

    i, j, t: int
    a := path_a[0]
    b := path_b[0]
    changed := true
    ok := false

    for changed {
        if (
            hash_node(a.position) == hash_node(b.position) ||
            (
                a.interval.y == b.interval.y &&
                i + 1 < len(path_a) &&
                j + 1 < len(path_b) &&
                hash_node(a.position) == hash_node(path_b[j + 1].position) &&
                hash_node(b.position) == hash_node(path_a[i + 1].position) \
            )\
        ) {
            return {step_a = a, step_b = b}, true
        }
        if i + 1 == len(path_a) {
            b, ok = find_first_conflict_step_path(a, path_b[j:], hash_node)
            return {step_a = a, step_b = b}, ok
        }
        if j + 1 == len(path_b) {
            a, ok = find_first_conflict_step_path(b, path_a[i:], hash_node)
            return {step_a = a, step_b = b}, ok
        }
        t = min(a.interval.y, b.interval.y)
        changed = false
        if a.interval.y == t && i + 1 < len(path_a){
            i += 1
            a = path_a[i]
            changed = true
        }
        if b.interval.y == t && j + 1 < len(path_b) {
            j += 1
            b = path_b[j]
            changed = true
        }
    }
    return {}, false
}

find_first_conflict_step_path :: proc(
    step: MapfStep($Node), path: []MapfStep(Node),
    hash_node: proc(node: Node) -> int,
) -> (MapfStep(Node), bool) {
    for that in path {
        if that.interval.y <= step.interval.x do continue
        if step.interval.y <= that.interval.x do break
        if hash_node(step.position) == hash_node(that.position) {
            return that, true
        }
    }
    return {}, false
}

fetch_costs :: proc(tree: []ConflictNode, node: ConflictNode, costs: []f32) -> (res: f32) {
    node := node

    path_costs := make([]f32, len(costs))
    defer delete(path_costs)

    path_costs[node.agent] = node.path_cost

    for node.parent >= 0 {
        node = tree[node.parent]
        if path_costs[node.agent] > 0 do continue
        path_costs[node.agent] = node.path_cost
    }
    for cost, agent in costs {
        if path_costs[agent] > 0 do continue
        path_costs[agent] = cost
    }
    for cost in path_costs {
        res += cost
    }
    return res
}

fetch_paths :: proc(
    tree: []ConflictNode, from: int, paths: [][]MapfStep($Node), N: int,
) -> map[int]int {
    node := tree[from]

    found := make(map[int]int)
    found[node.agent] = node.path

    for node.parent >= 0 {
        node = tree[node.parent]
        _, ok := found[node.agent]
        if ok do continue
        found[node.agent] = node.path
    }
    for agent in 0..<N {
        _, ok := found[agent]
        if ok do continue
        found[agent] = agent
    }
    return found
}

get_priority :: proc(conflict: Conflict($Node)) -> int {
    return min(conflict.step_a.interval.x, conflict.step_b.interval.x)
}

destroy_paths :: proc(paths: [][]MapfStep($Node)) {
    for path in paths {
        delete(path)
    }
    delete(paths)
}

cbs_less :: proc(a, b: ConflictStep) -> bool {
    return a.cost < b.cost
}

cbs_swap :: proc(queue: []ConflictStep, i, j: int) {
    queue[i], queue[j] = queue[j], queue[i]
}

constraint_less :: proc(a, b: Constraint) -> bool {
    return a.x < b.x || a.x == b.x && a.y < b.y
}
