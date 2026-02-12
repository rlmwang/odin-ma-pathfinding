#+feature dynamic-literals

package main

import "core:fmt"
import "core:os"
import "core:flags"
import "core:odin/ast"
import "core:odin/parser"

odin_to_ctypes := map[string]string{
    "i32"     = "c_int32",
    "i64"     = "c_int64",
    "f32"     = "c_float",
    "f64"     = "c_double",
    "bool"    = "c_bool",
    "b32"     = "c_int32", 
    "cstring" = "c_char_p",
    "rawptr"  = "c_void_p",
    "int"     = "c_longlong",
}

Options :: struct {
    path: string `args:"pos=0" usage:"Path to the Odin source directory"`,
}

main :: proc() {
    opt: Options
    flags.parse(&opt, args=os.args[1:])

    if opt.path == "" do opt.path = "."

    pkg, ok := parser.parse_package_from_path(opt.path)
    if !ok {
        fmt.eprintf("Error: Could not parse Odin package at path: %s\n", opt.path)
        os.exit(1)
    }

    // --- STEP 1: Identify strictly exported types ---
    used_types := make(map[string]bool)
    for _, file in pkg.files {
        for decl in file.decls {
            gd, ok := decl.derived.(^ast.Value_Decl)
            if !ok do continue

            // Check if this declaration has @export
            is_exported := false
            for attr in gd.attributes {
                for elem in attr.elems {
                    if ident, ok := elem.derived.(^ast.Ident); ok && ident.name == "export" {
                        is_exported = true
                    }
                }
            }

            if is_exported {
                for val in gd.values {
                    if proc_lit, ok := val.derived.(^ast.Proc_Lit); ok {
                        // Capture return types
                        if proc_lit.type.results != nil {
                            for field in proc_lit.type.results.list {
                                if ident, ok := field.type.derived.(^ast.Ident); ok {
                                    used_types[ident.name] = true
                                }
                            }
                        }
                        // Capture parameter types
                        if proc_lit.type.params != nil {
                            for field in proc_lit.type.params.list {
                                if ident, ok := field.type.derived.(^ast.Ident); ok {
                                    used_types[ident.name] = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- STEP 2: Generate Python File ---
    fmt.println("import ctypes")
    fmt.println("from ctypes import *")
    fmt.printf("\n# Python bindings for Odin package: %s\n", pkg.name)
    fmt.printf("lib = ctypes.CDLL(\"./%s.so\")\n\n", pkg.name)

    // Pass 1: Structs (ONLY if they are in used_types)
    for _, file in pkg.files {
        for decl in file.decls {
            gd, ok := decl.derived.(^ast.Value_Decl)
            if !ok do continue

            for val, i in gd.values {
                if s_type, ok := val.derived.(^ast.Struct_Type); ok {
                    struct_name := gd.names[i].derived.(^ast.Ident).name
                    // STRICTOR CHECK: Is this struct actually used in an exported function?
                    if _, found := used_types[struct_name]; found {
                        gen_python_struct(struct_name, s_type)
                    }
                }
            }
        }
    }

    // Pass 2: Procedures
    for _, file in pkg.files {
        for decl in file.decls {
            gd, ok := decl.derived.(^ast.Value_Decl)
            if !ok do continue

            is_exported := false
            for attr in gd.attributes {
                for elem in attr.elems {
                    if ident, ok := elem.derived.(^ast.Ident); ok && ident.name == "export" {
                        is_exported = true
                    }
                }
            }

            if is_exported {
                for val, i in gd.values {
                    if proc_lit, ok := val.derived.(^ast.Proc_Lit); ok {
                        proc_name := gd.names[i].derived.(^ast.Ident).name
                        gen_python_binding(proc_name, proc_lit.type)
                    }
                }
            }
        }
    }
}

gen_python_struct :: proc(name: string, s_type: ^ast.Struct_Type) {
    fmt.printf("class %s(ctypes.Structure):\n", name)
    fmt.println("    _fields_ = [")
    for field in s_type.fields.list {
        for name_expr in field.names {
            f_name := name_expr.derived.(^ast.Ident).name
            if f_name == "from" do f_name = "from_"
            
            py_type := "c_void_p"
            if ident, ok := field.type.derived.(^ast.Ident); ok {
                if val, found := odin_to_ctypes[ident.name]; found {
                    py_type = val
                }
            }
            fmt.printf("        (\"%s\", %s),\n", f_name, py_type)
        }
    }
    fmt.println("    ]\n")
}

gen_python_binding :: proc(name: string, type: ^ast.Proc_Type) {
    args_list: [dynamic]string
    defer delete(args_list)

    if type.params != nil {
        for field in type.params.list {
            if ident, ok := field.type.derived.(^ast.Ident); ok {
                py_type := odin_to_ctypes[ident.name] or_else ident.name
                append(&args_list, py_type)
            }
        }
    }

    arg_str := ""
    for s, i in args_list {
        arg_str = fmt.tprintf("%s%s%s", arg_str, s, i < len(args_list)-1 ? ", " : "")
    }

    fmt.printf("lib.%s.argtypes = [%s]\n", name, arg_str)

    if type.results != nil && len(type.results.list) > 0 {
        if ident, ok := type.results.list[0].type.derived.(^ast.Ident); ok {
            py_type := odin_to_ctypes[ident.name] or_else ident.name
            fmt.printf("lib.%s.restype = %s\n", name, py_type)
        }
    } else {
        fmt.printf("lib.%s.restype = None\n", name)
    }
    fmt.println()
}
