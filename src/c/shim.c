#include "liburing.h"

extern inline void _io_uring_cqe_seen(struct io_uring *ring, struct io_uring_cqe *cqe) {
  io_uring_cqe_seen(ring, cqe);
}

extern inline unsigned _io_uring_cq_ready(struct io_uring *ring) {
  return io_uring_cq_ready(ring);
}

extern inline int _io_uring_wait_cqe_nr(struct io_uring *ring, struct io_uring_cqe **cqe_ptr, unsigned wait_nr) {
  return io_uring_wait_cqe_nr(ring, cqe_ptr, wait_nr);
}
