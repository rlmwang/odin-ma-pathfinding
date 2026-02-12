package mapf

import pq "core:container/priority_queue"


A_Star_Step :: struct($Node: typeid) {
    node: Node,
    time: int,
    cost: f32,
    heur: f32,
}

a_star :: proc(
    grid:       $Grid,
    start:      $Node,
    stall:      int,
    finish:  proc(grid: Grid, position: Node) -> bool,
    steps:   proc(grid: Grid, position: Node, time: int) -> []Node,
    cost:    proc(grid: Grid, from, to: Node) -> f32,
    heur:    proc(grid: Grid, position: Node) -> f32,
) -> ([]Node, f32, bool) {
    Step :: A_Star_Step(Node)

    step_less :: proc(a, b: Step) -> bool {
        return a.cost + a.heur < b.cost + b.heur
    }
    step_swap :: proc(queue: []Step, i, j: int) {
        queue[i], queue[j] = queue[j], queue[i]
    }

    cost := make(map[Node]f32)
    defer delete(cost)

    seen := make(map[Node]Step)
    defer delete(seen)

    queue: pq.Priority_Queue(Step)
    pq.init(&queue, less=step_less, swap=step_swap, capacity=64)
    defer pq.destroy(&queue)

    start_nodes: Node
    start_nodes[0] = start

    pq.push(&queue, Step{
        nodes   = start_nodes,
        length  = 1,
        time    = 0,
        cost    = 0,
        heur    = heur(grid, start),
    })
    cost[start] = 0

    for pq.len(queue) > 0 {
        cur_step := pq.pop(&queue)
        cur_node := cur_step.nodes[cur_step.length-1]

        if finish(grid, cur_node) {
            path := reconstruct_path(
                start   = start,
                end     = &cur_step,
                seen    = seen,
            )
            return path, cur_step.cost, true
        }

        nxt_steps := steps(grid, cur_node, cur_step.time)
        defer delete(nxt_steps)

        for &nxt_step in nxt_steps {
            new_cost := cur_step.cost
            
            cur_node = cur_step.nodes[cur_step.length-1]
            for nxt_node in nxt_step.nodes[: nxt_step.length] {
                defer cur_node = nxt_node

                new_cost += cost(grid, cur_node, nxt_node)
            }

            lst_node := nxt_step.nodes[nxt_step.length-1]
            new_heur := heur(grid, lst_node)
            old_cost, ok := cost[lst_node]

            if !ok || old_cost > new_cost {
                seen[lst_node] = cur_step
                cost[lst_node] = new_cost
                pq.push(&queue, Step{
                    nodes   = nxt_step.nodes,
                    length  = nxt_step.length, 
                    time    = cur_step.time + nxt_step.length,
                    cost    = new_cost,
                    heur    = new_heur,
                })
            }
        }
    }
    return {}, 0, false
}

@(private="file")
reconstruct_path :: proc(
    start:  $Node,
    end:    ^A_Star_Step(Node),
    seen:   map[Node]A_Star_Step(Node),
) -> []Node {
    path: [dynamic]Node
    #reverse for node in end.nodes[:end.length] {
        append(&path, node)
    }
    step := end
    for step.nodes[step.length-1] != start {
        step = &seen[step.nodes[step.length-1]]
        #reverse for node in step.nodes[:step.length] {
            append(&path, node)
        }
    }
    invert_array(path[:])
    return path[:]
}
