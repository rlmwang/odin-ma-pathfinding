import ctypes
from ctypes import *

# Python bindings for Odin package: sapf
lib = ctypes.CDLL("./sapf.so")

lib.init.argtypes = [c_char_p]
lib.init.restype = None

lib.reset.argtypes = []
lib.reset.restype = 

lib.step.argtypes = [c_int64]
lib.step.restype = 

