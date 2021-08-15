.PHONY :  build spec clean all init-liburing init

all : 	liburing build spec

spec  :
	rm -rf .test
	mkdir -p .test
	crystal spec -Dpreview_mt --error-trace

liburing : init init-liburing
	$(MAKE) -C submodules/liburing
	cp submodules/liburing/src/liburing.a build/

build : init
	cc -march=native -g -c -o build/shim.o -Wall -O3 src/c/shim.c -Lbuild -luring -Isubmodules/liburing/src/include

clean :
	rm build/*
	rm -rf ior
	rm -rf ior_spec
	$(MAKE) -C submodules/liburing clean

init :
	mkdir -p build

init-liburing :
	@if [ ! -f "submodules/liburing/README" ]; then \
	    rm -rf submodules/liburing; \
	    git clone https://github.com/axboe/liburing submodules/liburing; \
	fi
	cd submodules/liburing && git fetch && git checkout b936762bb0aea0c259ee4
