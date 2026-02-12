import ctypes
from ctypes import *

# Python bindings for Odin package: sapf
lib = ctypes.CDLL("./sapf.so")

class StepResult(ctypes.Structure):
    _fields_ = [
        ("reward", c_float),
        ("done", c_int32),
        ("node", c_int64),
    ]

lib.init.argtypes = [c_char_p]
lib.init.restype = None

lib.reset.argtypes = []
lib.reset.restype = StepResult

lib.step.argtypes = [c_int64]
lib.step.restype = StepResult

lib.graph.argtypes = []
lib.graph.restype = c_char_p

