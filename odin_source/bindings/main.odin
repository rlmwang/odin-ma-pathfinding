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
	"cstring" = "c_char_p",
	"rawptr"  = "c_void_p",
}

// Configuration struct for command line flags
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

    // Access the package name here
    odin_pkg_name := pkg.name 
    
    fmt.println("import ctypes")
    fmt.println("from ctypes import *")
    
    // You could use the package name to name the .so file or a comment
    fmt.printf("\n# Python bindings for Odin package: %s\n", odin_pkg_name)
    fmt.printf("lib = ctypes.CDLL(\"./%s.so\")\n\n", odin_pkg_name)

	for _, file in pkg.files {
		for decl in file.decls {
			gd, is_gd := decl.derived.(^ast.Value_Decl)
			if !is_gd do continue

			for val, i in gd.values {
				proc_lit, is_proc := val.derived.(^ast.Proc_Lit)
				if !is_proc do continue

				has_export := false
				for attr in gd.attributes {
					for elem in attr.elems {
                        // Assert that the expression is an Identifier
						if ident, ok := elem.derived.(^ast.Ident); ok {
                            if ident.name == "export" do has_export = true
                        }
					}
				}

				if has_export {
					// Assert the name expression to an Identifier
                    if name_ident, ok := gd.names[i].derived.(^ast.Ident); ok {
                        name := name_ident.name
                        gen_python_binding(name, proc_lit.type)
                    }
				}
			}
		}
	}
}

gen_python_binding :: proc(name: string, type: ^ast.Proc_Type) {
	// Argtypes
	args_str := ""
	if type.params != nil {
		for field, i in type.params.list {
			// Basic type extraction
			if ident, ok := field.type.derived.(^ast.Ident); ok {
				args_str = fmt.tprintf("%s%s", args_str, odin_to_ctypes[ident.name])
				if i < len(type.params.list) - 1 do args_str = fmt.tprintf("%s, ", args_str)
			}
		}
	}
	fmt.printf("lib.%s.argtypes = [%s]\n", name, args_str)

	// Restype
	if type.results != nil && len(type.results.list) > 0 {
		if ident, ok := type.results.list[0].type.derived.(^ast.Ident); ok {
			fmt.printf("lib.%s.restype = %s\n", name, odin_to_ctypes[ident.name])
		}
	} else {
		fmt.printf("lib.%s.restype = None\n", name)
	}
	fmt.println()
}
