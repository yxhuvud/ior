require "./liburing"

@[Link(ldflags: "#{__DIR__}/../../build/shim.o")]
lib LibUringShim
  fun _io_uring_cq_ready(ring : LibUring::IOUring*) : LibC::UInt
  fun _io_uring_wait_cqe_nr(ring : LibUring::IOUring*, cqe_ptr : LibUring::IOUringCQE**, nr : LibC::UInt) : LibC::Int
  fun _io_uring_cqe_seen(ring : LibUring::IOUring*, cqe : LibUring::IOUringCQE*) : Void
end
