require "../lib/liburing_shim"

module IOR
  class IOUring
    # Not inheriting file logic from the various file descriptor classes
    # in Crystal stdlib as they have a lot of irrelevant functionality,
    # as well as lots of methods that emit blocking syscalls.
    private property closed : Bool
    private property ring : Pointer(LibUring::IOUring)

    def initialize(size = 32)
      @closed = false

      flags = 0
      # TODO: Support
      # SETUP_SQPOLL: !
      # SETUP_CQSIZE
      LibUring.io_uring_queue_init(size, out @ring, flags)
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

    private def get_sqe
      LibUring.io_uring_get_sqe(ring)
    end

    def readv(fd, iovecs, offset, user_data = 0)
      prep_rw(LibUring::Op::READV, fd, iovecs.to_unsafe, iovecs.size, offset, user_data)
    end

    def writev(fd, iovecs, offset, user_data = 0)
      prep_rw(LibUring::Op::WRITEV, fd, iovecs.to_unsafe, iovecs.size, offset, user_data)
    end

    def sendmsg(fd, msg : MsgHeader*, flags, user_data = 0)
      prep_rw(LibUring::Op::SENDMSG, fd, msg, 1, 0, user_data).tap do |sqe|
        sqe.flags = flags
      end
    end

    def recvmsg(fd, msg : MsgHeader*, flags, user_data = 0)
      prep_rw(LibUring::Op::RECVMSG, fd, msg, 1, 0, user_data).tap do |sqe|
        sqe.flags = flags
      end
    end

    private def prep_rw(op : LibUring::Op, file : File, addr, length, offset, user_data)
      sqe = get_sqe
      sqe.value.opcode = op
      sqe.value.flags = 0
      sqe.value.ioprio = 0
      sqe.value.fd = file.fd
      sqe.value.off_or_addr2.off = offset
      sqe.value.addr = addr.address
      sqe.value.len = length
      sqe.value.event_flags.rw_flags = 0
      sqe.value.user_data = user_data
      sqe.value.buf_or_pad.pad2[0] = sqe.value.buf_or_pad.pad2[1] = sqe.value.buf_or_pad.pad2[2] = 0
      sqe
    end
  end
end
