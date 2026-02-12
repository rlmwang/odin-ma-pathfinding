import ctypes
from ctypes import *

# Python bindings for Odin package: sapf
lib = ctypes.CDLL("./sapf.so")

lib.add.argtypes = [c_int32]
lib.add.restype = c_int32

