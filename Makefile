.PHONY :  spec clean all init build

all : 	build spec

spec  : build
	rm -rf .test
	mkdir -p .test
	crystal spec -Dpreview_mt --error-trace
build : init
	cc -march=native -g -c -o build/shim.o -Wall -O3 src/c/shim.c -Lbuild -luring

clean :
	rm build/*
	rm -rf ior
	rm -rf ior_spec

init :
	mkdir -p build
