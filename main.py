import ctypes
from ctypes import c_int32

lib = ctypes.CDLL("./sapf.so")
lib.add.argtypes = [c_int32]
lib.add.restype = c_int32

print(lib.add(1))
print(lib.add(1))
print(lib.add(1))
print(lib.add(1))
