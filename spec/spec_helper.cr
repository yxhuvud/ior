require "spec"
require "../src/ior"

def iovec(buf : Slice)
  vec = LibC::IOVec.new
  vec.base = buf.to_unsafe
  vec.len = buf.size
  iovecs = Slice(LibC::IOVec).new(1, vec)
end

def iovec(buf : String)
  vec = LibC::IOVec.new
  vec.base = buf.to_unsafe
  vec.len = buf.size
  iovecs = Slice(LibC::IOVec).new(1, vec)
end

def msgheader(iovecs)
  hdr = LibC::MsgHeader.new
  hdr.iov = iovecs
  hdr.iovlen = iovecs.size
  hdr
end
