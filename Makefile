.PHONY :  build spec clean all

all : 	liburing build spec

spec  :
	rm -rf .test
	mkdir -p .test
	crystal spec -Dpreview_mt --error-trace

liburing :
	$(MAKE) -C submodules/liburing
	cp submodules/liburing/src/liburing.a build

build :
	mkdir -p build
	cc -march=native -g -c -o build/shim.o -Wall -O3 src/c/shim.c -Lbuild -luring -Isubmodules/liburing/src/include

clean :
	rm build/*
	rm -rf ior
	rm -rf ior_spec
	$(MAKE) -C submodules/liburing clean
