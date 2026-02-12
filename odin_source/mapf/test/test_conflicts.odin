package mapf_test

import "core:testing"
import mapf "../"

@(test)
test_conflict__basic :: proc(t: ^testing.T) {
    path_a := []mapf.MapfStep(int){
        {0, {0, 1}}, {1, {1, 2}},
    }
    path_b := []mapf.MapfStep(int){
        {2, {0, 1}}, {1, {1, 2}},
    }
    conflict, ok := mapf.find_first_conflict(path_a, path_b, hash_node_id)
    testing.expect(t, ok)
    testing.expect_value(t, conflict, mapf.Conflict(int){
        step_a = mapf.MapfStep(int){1, {1, 2}},
        step_b = mapf.MapfStep(int){1, {1, 2}},
    })
}

@(test)
test_conflict__basic_far :: proc(t: ^testing.T) {
    path_a := []mapf.MapfStep(int){
        {0, {0, 1}}, {1, {1, 2}}, {2, {2, 3}},
    }
    path_b := []mapf.MapfStep(int){
        {2, {0, 1}}, {1, {1, 2}}, {0, {2, 3}},
    }
    conflict, ok := mapf.find_first_conflict(path_a, path_b, hash_node_id)
    testing.expect(t, ok)
    testing.expect_value(t, conflict, mapf.Conflict(int){
        step_a = mapf.MapfStep(int){1, {1, 2}},
        step_b = mapf.MapfStep(int){1, {1, 2}},
    })
}

@(test)
test_conflict__basic_uneven_left :: proc(t: ^testing.T) {
    path_a := []mapf.MapfStep(int){
        {0, {0, 1}}, {1, {1, 2}},
    }
    path_b := []mapf.MapfStep(int){
        {2, {0, 1}}, {1, {1, 2}}, {0, {2, 3}},
    }
    conflict, ok := mapf.find_first_conflict(path_a, path_b, hash_node_id)
    testing.expect(t, ok)
    testing.expect_value(t, conflict, mapf.Conflict(int){
        step_a = mapf.MapfStep(int){1, {1, 2}},
        step_b = mapf.MapfStep(int){1, {1, 2}},
    })
}

@(test)
test_conflict__basic_uneven_right :: proc(t: ^testing.T) {
    path_a := []mapf.MapfStep(int){
        {0, {0, 1}}, {1, {1, 2}}, {2, {2, 3}},
    }
    path_b := []mapf.MapfStep(int){
        {2, {0, 1}}, {1, {1, 2}},
    }
    conflict, ok := mapf.find_first_conflict(path_a, path_b, hash_node_id)
    testing.expect(t, ok)
    testing.expect_value(t, conflict, mapf.Conflict(int){
        step_a = mapf.MapfStep(int){1, {1, 2}},
        step_b = mapf.MapfStep(int){1, {1, 2}},
    })
}

@(test)
test_conflict__chase :: proc(t: ^testing.T) {
    path_a := []mapf.MapfStep(int){
        {0, {0, 1}}, {1, {1, 2}}, {2, {2, 3}},
    }
    path_b := []mapf.MapfStep(int){
        {1, {0, 1}}, {2, {1, 2}}, {3, {2, 3}},
    }
    _, ok := mapf.find_first_conflict(path_a, path_b, hash_node_id)
    testing.expect(t, !ok)
}

@(test)
test_conflict__chase_uneven_left :: proc(t: ^testing.T) {
    path_a := []mapf.MapfStep(int){
        {0, {0, 1}}, {1, {1, 2}},
    }
    path_b := []mapf.MapfStep(int){
        {1, {0, 1}}, {2, {1, 2}}, {3, {2, 3}},
    }
    _, ok := mapf.find_first_conflict(path_a, path_b, hash_node_id)
    testing.expect(t, !ok)
}

@(test)
test_conflict__chase_uneven_right :: proc(t: ^testing.T) {
    path_a := []mapf.MapfStep(int){
        {0, {0, 1}}, {1, {1, 2}}, {2, {2, 3}},
    }
    path_b := []mapf.MapfStep(int){
        {1, {0, 1}}, {2, {1, 2}},
    }
    _, ok := mapf.find_first_conflict(path_a, path_b, hash_node_id)
    testing.expect(t, !ok)
}

@(test)
test_conflict__wait_left :: proc(t: ^testing.T) {
    path_a := []mapf.MapfStep(int){
        {0, {0, 2}}, {1, {2, 3}}, {2, {3, 4}},
    }
    path_b := []mapf.MapfStep(int){
        {2, {0, 1}}, {1, {1, 3}}, {0, {3, 4}},
    }
    conflict, ok := mapf.find_first_conflict(path_a, path_b, hash_node_id)
    expected := mapf.Conflict(int){
        step_a = mapf.MapfStep(int){1, {2, 3}},
        step_b = mapf.MapfStep(int){1, {1, 3}},
    }
    testing.expect(t, ok)
    testing.expect_value(t, conflict, expected)
}

@(test)
test_conflict__wait_right :: proc(t: ^testing.T) {
    path_a := []mapf.MapfStep(int){
        {0, {0, 1}}, {1, {1, 3}}, {2, {3, 4}},
    }
    path_b := []mapf.MapfStep(int){
        {2, {0, 2}}, {1, {2, 3}}, {0, {3, 4}},
    }
    conflict, ok := mapf.find_first_conflict(path_a, path_b, hash_node_id)
    testing.expect(t, ok)
    testing.expect_value(t, conflict, mapf.Conflict(int){
        step_a = mapf.MapfStep(int){1, {1, 3}},
        step_b = mapf.MapfStep(int){1, {2, 3}},
    })
}

@(test)
test_conflict__cross :: proc(t: ^testing.T) {
    path_a := []mapf.MapfStep(int){
        {0, {0, 1}}, {1, {1, 2}}, {2, {2, 3}}, {3, {3, 4}},
    }
    path_b := []mapf.MapfStep(int){
        {3, {0, 1}}, {2, {1, 2}}, {1, {2, 3}}, {0, {3, 4}},
    }
    conflict, ok := mapf.find_first_conflict(path_a, path_b, hash_node_id)
    testing.expect(t, ok)
    testing.expect_value(t, conflict, mapf.Conflict(int){
        step_a = mapf.MapfStep(int){1, {1, 2}},
        step_b = mapf.MapfStep(int){2, {1, 2}},
    })
}

@(test)
test_conflict__cross_uneven_left :: proc(t: ^testing.T) {
    path_a := []mapf.MapfStep(int){
        {0, {0, 2}}, {1, {2, 3}},
    }
    path_b := []mapf.MapfStep(int){
        {2, {0, 1}}, {1, {1, 2}}, {0, {2, 3}},
    }
    conflict, ok := mapf.find_first_conflict(path_a, path_b, hash_node_id)
    testing.expect(t, ok)
    testing.expect_value(t, conflict, mapf.Conflict(int){
        step_a = mapf.MapfStep(int){0, {0, 2}},
        step_b = mapf.MapfStep(int){1, {1, 2}},
    })
}

@(test)
test_conflict__cross_uneven_right :: proc(t: ^testing.T) {
    path_a := []mapf.MapfStep(int){
        {0, {0, 1}}, {1, {1, 2}}, {2, {2, 3}},
    }
    path_b := []mapf.MapfStep(int){
        {2, {0, 2}}, {1, {2, 3}},
    }
    conflict, ok := mapf.find_first_conflict(path_a, path_b, hash_node_id)
    testing.expect(t, ok)
    testing.expect_value(t, conflict, mapf.Conflict(int){
        step_a = mapf.MapfStep(int){1, {1, 2}},
        step_b = mapf.MapfStep(int){2, {0, 2}},
    })
}

hash_node_id :: proc(node: int) -> int {
    return node
}
