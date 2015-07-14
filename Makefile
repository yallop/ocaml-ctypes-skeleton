include Makefile.config

OCAML_CFLAGS=$(CFLAGS:%=-ccopt %)

all: bindings.cma

type_bindings.ml functions.ml:
	gcc  $(CFLAGS) -E $(FILENAME) | OCAMLRUNPARAM='b,l=2028k' ocaml-bindings-generator --export=$(REGEX) --functions-filename functions.ml --types-filename type_bindings.ml

type_bindings.cmo: type_bindings.ml
	ocamlfind c -g -c -package ctypes.stubs type_bindings.ml

type_generator.cmo: type_generator.ml
	ocamlfind c -g -c -package ctypes.stubs type_generator.ml

generate_types.byte: type_bindings.cmo type_generator.cmo
	ocamlfind c -g -o generate_types.byte -package ctypes.stubs -linkpkg type_bindings.cmo type_generator.cmo

generate_types.c: generate_types.byte
	echo "#include <"$(FILENAME)">" > generate_types.c
	OCAMLRUNPARAM=b ./generate_types.byte >> generate_types.c

generate_types: generate_types.c
	gcc $(CFLAGS) -I $$(ocamlfind query ctypes) -o generate_types generate_types.c

generated_types.ml: generate_types
	OCAMLRUNPARAM=b ./generate_types > generated_types.ml

generated_types.cmo: generated_types.ml
	ocamlfind c -g -c -package ctypes.stubs generated_types.ml

functions.cmo: functions.ml generated_types.cmo type_bindings.cmo
	ocamlfind c -g -c -package ctypes.stubs functions.ml

generate_bindings.cmo: functions.cmo generate_bindings.ml
	ocamlfind c -g -c -package ctypes.stubs generate_bindings.ml

bindings_generator.byte: functions.cmo generate_bindings.cmo
	ocamlfind c -g -o bindings_generator.byte -package ctypes.stubs -linkpkg type_bindings.cmo generated_types.cmo functions.cmo generate_bindings.cmo

generate_ml_bindings.cmo: functions.cmo generate_ml_bindings.ml
	ocamlfind c -g -c -package ctypes.stubs generate_ml_bindings.ml

ml_bindings_generator.byte: type_bindings.cmo generated_types.cmo functions.cmo generate_ml_bindings.cmo
	ocamlfind c -g -o ml_bindings_generator.byte -package ctypes.stubs -linkpkg type_bindings.cmo generated_types.cmo functions.cmo generate_ml_bindings.cmo

generated_bindings.ml: ml_bindings_generator.byte
	OCAMLRUNPARAM=b ./ml_bindings_generator.byte > generated_bindings.ml

generated_bindings.cmo: generated_bindings.ml
	ocamlfind c -g -c -package ctypes.stubs generated_bindings.ml

bindings.cmo: generated_bindings.cmo bindings.ml
	ocamlfind c -g -c -package ctypes.stubs bindings.ml

generated_bindings_stubs.c: bindings_generator.byte
	echo "#define const /* hmm */" > generated_bindings_stubs.c
	echo "#include <"$(FILENAME)">" >> generated_bindings_stubs.c
	OCAMLRUNPARAM=b ./bindings_generator.byte >> generated_bindings_stubs.c

generated_bindings_stubs.o: generated_bindings_stubs.c
	ocamlfind c $(OCAML_CFLAGS) -c -I $$(ocamlfind query ctypes) -g -o generated_bindings_stubs.o generated_bindings_stubs.c	

bindings.cma: generated_types.cmo functions.cmo generated_bindings.cmo generated_bindings_stubs.o bindings.cmo
	ocamlfind mklib -o bindings -package ctypes.stubs -linkpkg type_bindings.cmo generated_types.cmo functions.cmo generated_bindings_stubs.o generated_bindings.cmo bindings.cmo $(LIBRARY)

.PHONY: clean
clean:
	rm -f *.cmi *.cmo *.cma *.o *.byte generated_types.ml generate_types \
	extract_types type_bindings.ml functions.ml \
	generate_types.c generated_bindings.ml generated_bindings_stubs.c \
        dllbindings.so libbindings.a
