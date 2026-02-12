package mapf

import pq "core:container/priority_queue"


MapfStep :: struct($Node: typeid) {
    position:   Node,
    interval:   [2]int,
}

A_Cons_Node :: struct($Node: typeid) {
    node:   Node,
    time:   int,
}

A_Cons_Step :: struct($Node: typeid) {
    node:       A_Cons_Node(Node),
    interval:   int,
    time:       int,
    cost:       f32,
    heur:       f32,
}

MapfWait :: struct {
    time:       int,
    interval:   int, 
}

Constraint :: [2]int

a_star_constrained :: proc(
    grid:               $Grid,
    start:              $Node,
    stall:              int,
    steps_fn:           proc(grid: Grid, position: Node, time: int) -> []Node,
    time_fn:            proc(grid: Grid, from, to: Node, time, wait: int) -> int,
    cost_fn:            proc(grid: Grid, from, to: Node, time, wait: int) -> f32,
    heur_fn:            proc(grid: Grid, position: Node) -> f32,
    finish_fn:          proc(grid: Grid, position: Node) -> bool,
    node_hash_full:     proc(node: Node) -> int,
    node_hash_base:     proc(node: Node) -> int,
    node_constraints:   map[int][dynamic]Constraint,
    edge_constraints:   map[[2]int][dynamic]Constraint,
) -> ([]MapfStep(Node), f32, bool) {
    Step :: A_Cons_Step(Node)

    step_less :: proc(a, b: Step) -> bool {
        return a.cost + a.heur < b.cost + b.heur
    }
    step_swap :: proc(queue: []Step, i, j: int) {
        queue[i], queue[j] = queue[j], queue[i]
    }

    cost := make(map[[2]int]f32)
    defer delete(cost)

    seen := make(map[[2]int]Step)
    defer delete(seen)

    queue: pq.Priority_Queue(Step)
    pq.init(&queue, less=step_less, swap=step_swap, capacity=64)
    defer pq.destroy(&queue)

    {        
        interval := 0
        n_cons, n_ok := node_constraints[node_hash_base(start)]
        if n_ok {
            interval = find_first_constraint(n_cons[:], stall)
        }

        start_node: A_Cons_Node(Node) = {start, stall}

        pq.push(&queue, Step{
            node        = start_node,
            interval    = interval,
            time        = stall,
            cost        = 0,
            heur        = heur_fn(grid, start),
        })
        cost[{node_hash_full(start), interval}] = 0
    }

    for pq.len(queue) > 0 {
        cur_step := pq.pop(&queue)
        cur_node := cur_step.node.node

        if finish_fn(grid, cur_node) {
            path := re_construct_path(
                start           = start,
                end             = &cur_step,
                seen            = seen,
                node_hash       = node_hash_full,
            )
            return path, cur_step.cost, true
        }

        nxt_steps := steps_fn(grid, cur_node, cur_step.time)
        defer delete(nxt_steps)

        stp: for &nxt_step in nxt_steps {

            // lowest arrival time

            cur_node  = cur_step.node.node
            low_time := cur_step.time
            low_time += time_fn(grid, cur_node, nxt_step, low_time, 0)

            // find gaps at last node

            waiting: [dynamic]MapfWait
            defer delete(waiting)

            n_cons, n_ok := node_constraints[node_hash_base(nxt_step)]

            if !n_ok || len(n_cons) == 0 {
                append(&waiting, MapfWait{0, 0})
            } else {
                interval := find_first_constraint(n_cons[:], low_time)
                #reverse for ncon, offset in n_cons[interval:] {
                    append(&waiting, MapfWait{ncon.y - low_time, interval + offset + 1})
                }
                if interval >= len(n_cons) || low_time < n_cons[interval].x {
                    append(&waiting, MapfWait{0, interval})
                }
            }

            // check for valid gaps

            wait_loop: for wait in waiting {
                new_node: A_Cons_Node(Node)

                new_time := cur_step.time + wait.time
                new_cost := cur_step.cost

                cur_time := new_time
                cur_node  = cur_step.node.node
                nxt_node := nxt_step

                new_cost += cost_fn(grid, cur_node, nxt_node, cur_time, wait.time)
                new_time += time_fn(grid, cur_node, nxt_node, cur_time, wait.time)
                new_node = {nxt_node, new_time}

                // check if valid

                n0_cons, n0_ok := node_constraints[node_hash_base(cur_node)]
                n1_cons, n1_ok := node_constraints[node_hash_base(nxt_node)]
                ed_cons, ed_ok := edge_constraints[{node_hash_base(cur_node), node_hash_base(nxt_node)}]

                if n0_ok {
                    interval := find_first_constraint(n0_cons[:], new_time)
                    if interval < len(n0_cons) && new_time > n0_cons[interval].x do continue wait_loop
                }
                if n1_ok {
                    interval := find_first_constraint(n1_cons[:], new_time)
                    if interval < len(n1_cons) && new_time >= n1_cons[interval].x do continue wait_loop
                }
                if ed_ok {
                    for ed_con in ed_cons {
                        if new_time <= ed_con.x || ed_con.y < cur_time do continue
                        continue wait_loop
                    }
                }

                // assign step if cheaper

                fin_node := nxt_step
                new_hash := [2]int{node_hash_full(fin_node), wait.interval}
                new_heur := heur_fn(grid, fin_node)

                old_cost, old_ok := cost[new_hash]

                if !old_ok || old_cost > new_cost {
                    seen[new_hash] = cur_step
                    cost[new_hash] = new_cost
    
                    pq.push(&queue, Step{
                        node     = new_node,
                        interval = wait.interval,
                        time     = new_time,
                        cost     = new_cost,
                        heur     = new_heur,
                    })
                }
            }
        }
    }
    return {}, 0, false
}

@(private="file")
find_first_constraint :: proc(
    cons:   []Constraint,
    time:   int,
) -> int {
    index := 0
    for con in cons {
        if time < con.y do break
        index += 1
    }
    return index
}

@(private="file")
re_construct_path :: proc(
    start:      $Node,
    end:        ^A_Cons_Step(Node),
    seen:       map[[2]int]A_Cons_Step(Node),
    node_hash:  proc(node: Node) -> int,
) -> []MapfStep(Node) {
    path: [dynamic]MapfStep(Node)

    time := end.time
    append(&path, MapfStep(Node){
        position = end.node.node,
        interval = {time, time + 1},
    })

    step := end
    for step.node.node != start {
        hash := [2]int{node_hash(step.node.node), step.interval}
        step = &seen[hash]

        append(&path, MapfStep(Node){
            position = step.node.node,
            interval = {step.time, time},
        })
        time = step.node.time
    }
    invert_array(path[:])
    return path[:]
}

destroy_constraints :: proc(constraints: map[$T][dynamic]Constraint) {
    for _, value in constraints do delete(value)
    delete(constraints)
}
