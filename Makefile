.PHONY :  spec clean all

all : 	spec

spec  :
	rm -rf .test
	mkdir -p .test
	crystal spec -Dpreview_mt --error-trace

clean :
	rm -rf ior
	rm -rf ior_spec
