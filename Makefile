.PHONY :  build run clean all

all : 	build run

run  :
	rm -rf .test
	mkdir -p .test
	crystal spec -Dpreview_mt

build :
	mkdir -p build
	cc -march=native  -g  -c -o build/shim.o -Wall -O3 src/c/shim.c

clean :
	rm build/*
	rm -rf ior
	rm -rf ior_spec
