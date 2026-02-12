package mapf


invert_array :: proc(arr: []$T) {
    i, j := 0, len(arr) - 1
    for true {
        if i >= j do break
        arr[i], arr[j] = arr[j], arr[i]
        i, j = i + 1, j - 1
    }
}
