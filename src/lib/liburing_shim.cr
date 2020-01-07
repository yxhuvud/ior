require "./liburing"

@[Link(ldflags: "#{__DIR__}/../../../build/shim.o")]
lib LibUringShim
  fun _io_uring_wait_cqe(ring : LibUring::IOUring*, cqe_ptr : LibUring::IOUringCQE**) : LibC::Int
      fun _io_uring_peek_cqe(ring : LibUring::IOUring*, cqe_ptr : LibUring::IOUringCQE**) : LibC::Int
  fun _io_uring_cqe_seen(ring : LibUring::IOUring*, cqe : LibUring::IOUringCQE*) : Void
end
