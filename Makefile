.PHONY :  spec clean all init build

all : 	build spec

spec  : build
	rm -rf .test
	mkdir -p .test
	crystal spec -Dpreview_mt --error-trace

build/liburing.a: init
	@if [ ! -f "submodules/liburing/README" ]; then \
	    rm -rf submodules/liburing; \
	    git clone https://github.com/axboe/liburing submodules/liburing; \
	fi
	cd submodules/liburing && git fetch && git checkout b936762bb0aea0c259ee4
	$(MAKE) -C submodules/liburing
	cp submodules/liburing/src/liburing.a build/

build : init build/liburing.a
	cc -march=native -g -c -o build/shim.o -Wall -O3 src/c/shim.c -Lbuild -luring -Isubmodules/liburing/src/include

clean :
	rm build/*
	rm -rf ior
	rm -rf ior_spec
	$(MAKE) -C submodules/liburing clean

init :
	mkdir -p build
