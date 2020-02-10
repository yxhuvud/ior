require "../lib/liburing_shim"
require "./sqe"
require "./cqe"

module IOR
  class IOUring
    # Not inheriting file logic from the various file descriptor classes
    # in Crystal stdlib as they have a lot of irrelevant functionality,
    # as well as lots of methods that emit blocking syscalls.
    private property closed : Bool
    private property registered_files : Bool

    def initialize(size = 32, sq_poll = false)
      @closed = false

      flags = LibUring::SETUP_FLAG::None
      # Other flags not currently relevant as we have no support of
      # initing using the params object. Do note that sqpoll requires
      # using only registred files and heightened privileges.
      flags |= LibUring::SETUP_FLAG::SQPOLL if sq_poll

      @ring = LibUring::IOUring.new
      @registered_files = false
      res = LibUring.io_uring_queue_init(size, ring, flags)
      unless res == 0
        raise "Init: #{err(res)}"
      end
    end

    def self.new(**options)
      ring = new(**options)
      yield ring
      ring.close
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
        raise "Submit #{err res}"
      end
      res
    end

    # Returns next event. Waits for an event to be completed if none
    # are available
    def wait
      wait 1
    end

    # Yields next event, and marks it as seen when done.
    def wait
      cqe = wait 1

      begin
        yield cqe
      ensure
        seen cqe
      end
    end

    # Returns next event. Waits for nr events to be completed if none
    # are available
    def wait(nr)
      cqe = wait_cqe(nr)
      if cqe.error?
        raise "Wait: #{err cqe.errno}"
      end

      cqe
    end

    # Returns next event if one is available.
    def peek
      cqe = wait_cqe(0)
      if cqe.errno == -LibC::EAGAIN
        nil
      elsif cqe.error?
        raise "Peek: #{err cqe.errno}"
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

    # Marks an event as consumed
    def seen(cqe)
      LibUringShim._io_uring_cqe_seen(ring, cqe)
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

    # Completion events waiting for processing.
    def cq_ready
      LibUringShim._io_uring_cq_ready(ring)
    end

    def sqe
      SQE.new(LibUring.io_uring_get_sqe(ring))
    end

    private def wait_cqe(nr)
      res = LibUringShim._io_uring_wait_cqe_nr(ring, out cqe_ptr, nr)
      CQE.new(cqe_ptr, res)
    end

    private def err(res)
      String.new(LibC.strerror(-res))
    end
  end
end
