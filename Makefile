all:
	cc -march=native  -g  -c -o build/shim.o -Wall -O3 src/c/shim.c
	crystal run spec/ior_spec.cr 

clean:
	rm build/*
	rm ior
	rm ior_spec
