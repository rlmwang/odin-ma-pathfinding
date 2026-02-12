package sapf

import "base:runtime"
import "core:fmt"

VTable :: struct {
    reset: proc(session: rawptr) -> StepResult,
    step:  proc(session: rawptr, action: i64) -> StepResult,
}

@(private)
global_session: rawptr

@(private)
global_vtable: VTable

@export
init :: proc "c" (name: cstring) {
    context = runtime.default_context()
    name := string(name)
    fmt.println(name)

    if name == "finite_graph" {
        neighbors := make(map[i64][dynamic]i64)
        costs := make(map[FinEdge]f32)
        graph := make_finite_graph(neighbors, costs, 99)
        
        session := new(Session(FinEnvironment))
        _init(session, graph, 0)

        global_session = session
        global_vtable = VTable{
            reset = fin_reset_bridge,
            step  = fin_step_bridge,
        }
    }
}

@export
reset :: proc "c" () -> StepResult {
    context = runtime.default_context()
    if global_vtable.reset == nil do return {0, true, 0}
    return global_vtable.reset(global_session)
}

@export
step :: proc "c" (action: i64) -> StepResult {
    context = runtime.default_context()
    if global_vtable.step == nil do return {}
    return global_vtable.step(global_session, action)
}
