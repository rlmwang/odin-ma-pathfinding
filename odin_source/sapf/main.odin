package sapf

import "base:runtime"
import "core:fmt"

@(private)
global_session: rawptr

@export
init :: proc "c" (name: cstring) {
    context = runtime.default_context()
    name := string(name)
    fmt.println(name)

    if name == "finite_graph" {
        n := make(map[FinNode][dynamic]FinNode)
        c := make(map[FinEdge]f32)
        
        g := make_finite_graph(n, c, 99)
        s := new(Session(FinEnvironment, FinNode))
        
        _init(s, g, 0)

        global_session = s
    }
}
