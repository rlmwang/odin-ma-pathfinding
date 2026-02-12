import ctypes
from ctypes import *

# Python bindings for Odin package: sapf
lib = ctypes.CDLL("./sapf.so")

lib.init.argtypes = [c_char_p]
lib.init.restype = None

