let () = Cstubs.write_c ~prefix:"ctypes_autogen" Format.std_formatter (module Functions.Bindings)
