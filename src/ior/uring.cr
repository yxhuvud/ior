require "../lib/liburing"
require "./sqe"
require "./cqe"

module IOR
  class IOUring
    # Not inheriting file logic from the various file descriptor classes
    # in Crystal stdlib as they have a lot of irrelevant functionality,
    # as well as lots of methods that emit blocking syscalls.
    private property closed : Bool
    private property registered_files : Bool
    getter size : Int32
    getter sq_poll : Bool
    getter io_poll : Bool

    # Regarding worker, it is quite useless now as it only works with
    # sqpoll set. It used to be more useful.
    def initialize(@size = 32, @sq_poll = false, @io_poll = false, worker : IOUring? = nil)
      @closed = false
      @registered_files = false

      flags = LibUring::SETUP_FLAG::None
      # Do note that sqpoll requires using only registered files and
      # heightened privileges.
      # TODO: Moar flags?
      flags |= LibUring::SETUP_FLAG::SQPOLL if sq_poll
      flags |= LibUring::SETUP_FLAG::IOPOLL if io_poll

      @ring = LibUring::IOUring.new

      params =
        if worker
          LibUring::IOUringParams.new(
            flags: flags | LibUring::SETUP_FLAG::ATTACH_WQ,
            wq_fd: worker.fd
          )
        else
          LibUring::IOUringParams.new(
            flags: flags,
          )
        end
      res = LibUring.io_uring_queue_init_params(size, ring, pointerof(params))

      unless res == 0
        raise "Init: #{Errno.new(-res)}"
      end
    end

    def self.new(**options)
      ring = new(**options)
      begin
        yield ring
      ensure
        ring.close
      end
    end

    private def ring
      pointerof(@ring)
    end

    def close
      LibUring.io_uring_queue_exit(ring)
      @closed = true
    end

    def closed?
      @closed
    end

    def finalize
      return if closed?

      close rescue nil
    end

    # Register files for less costly access.
    # Note: Registering will replace any other registered files.
    # TODO: Support io_uring_register_files_update when kernel get
    # support for it.
    def register_files(files)
      unregister_files if @registered_files
      fds = files.map &.fd
      LibUring.io_uring_register_files(ring, fds, fds.size)
      @registered_files = true
    end

    def unregister_files
      LibUring.io_uring_unregister_files(ring)
      @registered_files = false
    end

    # Submit events to kernel
    def submit
      res = LibUring.io_uring_submit(ring)
      if res < 0
        raise "Submit #{Errno.new -res}"
      end
      res
    end

    # Returns next event. Waits for an event to be completed if none
    # are available
    def wait : CQE
      wait(1)
    end

    # Returns next event. Waits for an event to be completed if none
    # are available.
    def wait(timeout : LibC::Timespec*) : CQE?
      wait(1, timeout)
    end

    # Yields next event, and marks it as seen when done.
    def wait
      cqe = wait(1)

      begin
        yield cqe
      ensure
        seen cqe
      end
    end

    # Yields next event unless a timeout happens, and marks it as seen
    # when done.
    def wait(timeout : LibC::Timespec*)
      cqe = wait(1, timeout)
      return unless cqe

      begin
        yield cqe
      ensure
        seen cqe
      end
    end

    # Returns next event. Waits for nr events to be completed if none
    # are available
    def wait(nr) : CQE
      cqe = wait_cqe(nr)
      if cqe.ring_error?
        raise "Wait: #{cqe.ring_errno.message}"
      end

      cqe
    end

    # Returns next event unless timeout happens. Waits for nr events to be completed if none
    # are available
    def wait(nr, timeout : LibC::Timespec*) : CQE?
      cqe = wait_cqe(nr, timeout)
      return nil if cqe.ring_timed_out?
      raise "Wait: #{cqe.ring_errno.message}" if cqe.ring_error?

      cqe
    end

    # Submit events to kernel, and wait for nr responses. Saves a
    # syscall compared to submit followed by wait. Returns submission
    # count so user will still need a call to wait to actually get to
    # the result.
    def submit_and_wait(nr = 1)
      res = LibUring.io_uring_submit_and_wait(ring, nr)
      if res < 0
        raise "Submit #{Errno.new(-res).message}"
      end
      res
    end

    # Returns next event if one is available.
    def peek
      cqe = wait_cqe(0)
      if cqe.ring_errno.eagain?
        nil
      elsif cqe.ring_error?
        raise "Peek: #{cqe.ring_errno.message}"
      else
        cqe
      end
    end

    # Yields next event if available, and marks it as seen when done.
    def peek
      if cqe = peek
        begin
          yield cqe
        ensure
          seen(cqe)
        end
      end
    end

    # Peek and yield multiple CQEs, using a provided buffer as
    # intermediary cache.
    def peek(into cqes)
      res = LibUring.io_uring_peek_batch_cqe(ring, cqes, cqes.size)
      res.times do |i|
        cqe = IOR::CQE.new(cqes[i], 0)
        yield cqe
        seen cqe
      end
    end

    # Marks an event as consumed
    def seen(cqe : IOR::CQE)
      LibUring.io_uring_cqe_seen(ring, cqe)
    end

    # Return how many unsubmitted entries there is in the submission
    # queue.
    def sq_ready
      sq = ring.value.sq
      sq.sqe_tail - sq.sqe_head
    end

    # Space left in the submission queue.
    def sq_space_left
      ring.value.sq.kring_entries.value - sq_ready
    end

    # Returns true if there are any unsubmitted SQEs.
    def unsubmitted?
      sq_ready != 0
    end

    # Returns true if the submission queue is full.
    def full_submission_queue?
      sq_space_left == 0
    end

    # Completion events waiting for processing.
    def cq_ready
      LibUring.io_uring_cq_ready(ring)
    end

    # Returns a sqe if there is space available, or nil.
    def sqe
      if sqe_ptr = LibUring.io_uring_get_sqe(ring)
        SQE.new(sqe_ptr)
      else
        nil
      end
    end

    def sqe! : SQE
      sqe.not_nil!
    end

    def fd
      ring.value.ring_fd
    end

    private def wait_cqe(nr) : CQE
      res = LibUring.io_uring_wait_cqe_nr(ring, out cqe_ptr, nr)
      CQE.new(cqe_ptr, res)
    end

    private def wait_cqe(nr, timeout) : CQE
      res = LibUring.io_uring_wait_cqes(ring, out cqe_ptr, nr, timeout, nil)
      CQE.new(cqe_ptr, res)
    end
  end
end
