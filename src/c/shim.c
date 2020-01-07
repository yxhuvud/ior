#include "liburing.h"

extern void _io_uring_cqe_seen(struct io_uring *ring, struct io_uring_cqe *cqe) {
        io_uring_cqe_seen(ring, cqe);
}

/* io_uring_smp_load_acquire */
/* io_uring_cq_advance */

/*  io_uring_sq_ready */
/* io_uring_sq_space_left */
/* io_uring_cq_ready */
/* io_uring_peek_cqe */
extern inline int _io_uring_wait_cqe(struct io_uring *ring, struct io_uring_cqe **cqe_ptr) {
        return io_uring_wait_cqe(ring, cqe_ptr);
}
extern int _io_uring_peek_cqe(struct io_uring *ring, struct io_uring_cqe **cqe) {
        return io_uring_peek_cqe(ring, cqe);
}
