require "../lib/liburing_shim"

module IOR
  struct SQE
    private property sqe

    def initialize(@sqe : LibUring::IOUringSQE*)
    end

    def nop(**options)
      prep_rw(LibUring::Op::NOP, nil, nil, 0, 0, **options)
    end

    # TODO: Support using current position (ie offset -1), based on IORING_FEAT_RW_CUR_POS
    def readv(fd, iovecs, offset, **options)
      prep_rw(LibUring::Op::READV, fd, iovecs.to_unsafe.address, iovecs.size, offset, **options)
    end

    def writev(fd, iovecs, offset, **options)
      prep_rw(LibUring::Op::WRITEV, fd, iovecs.to_unsafe.address, iovecs.size, offset, **options)
    end

    def fsync(fd, flags = 0, **options)
      prep_rw(LibUring::Op::FSYNC, fd, nil, 0, 0, **options).tap do |sqe|
        sqe.value.event_flags.fsync_flags = flags
      end
    end

    def poll_add(fd, poll_mask : LibC::POLL_FLAG = LibC::POLL_FLAG::POLLIN, **options)
      prep_rw(LibUring::Op::POLL_ADD, fd, nil, 0, 0, **options).tap do |sqe|
        sqe.value.event_flags.poll_events = poll_mask
      end
    end

    def sendmsg(fd, msg : LibC::MsgHeader*, flags, **options)
      prep_rw(LibUring::Op::SENDMSG, fd, msg.address, 1, 0, **options).tap do |sqe|
        sqe.value.event_flags.msg_flags = flags
      end
    end

    def recvmsg(fd, msg : LibC::MsgHeader*, flags, **options)
      prep_rw(LibUring::Op::RECVMSG, fd, msg.address, 1, 0, **options).tap do |sqe|
        sqe.value.event_flags.msg_flags = flags
      end
    end

    def timeout(time : LibC::Timespec*, relative = true, wait_nr = 1, **options)
      prep_rw(LibUring::Op::TIMEOUT, nil, time.address, 1, wait_nr, **options).tap do |sqe|
        sqe.value.event_flags.timeout_flags = relative ? 0 : 1
      end
    end

    # Note: Requires the preceding operation in the same submit to
    # have the io_link flag set.
    def link_timeout(time : LibC::Timespec*, relative = true, **options)
      prep_rw(LibUring::Op::LINK_TIMEOUT, nil, time.address, 1, 0, **options).tap do |sqe|
        sqe.value.event_flags.timeout_flags = relative ? 0 : 1
      end
    end

    def timeout_remove(cancel_userdata : UInt64, **options)
      prep_rw(LibUring::Op::TIMEOUT_REMOVE, nil, cancel_userdata, 0, 0, **options)
    end

    def async_cancel(cancel_userdata : UInt64, **options)
      prep_rw(LibUring::Op::ASYNC_CANCEL, nil, cancel_userdata, 0, 0, **options)
    end

    # TODO: Support passing sockaddr, socklen and flags.
    def accept(fd, **options)
      prep_rw(LibUring::Op::ACCEPT, fd, nil, 0, 0, **options)
    end

    def connect(fd, addr : Socket::Addrinfo, **options)
      prep_rw(LibUring::Op::CONNECT, fd, addr.to_unsafe.address, 0, addr.size, **options)
    end

    private def prep_rw(op : LibUring::Op, io_or_index, addr : UInt64?, length, offset,
                        user_data = 0u64,
                        fixed_file = false, io_drain = false, io_link = false, io_hardlink = false, async = false)
      flags = LibUring::SQE_FLAG::None
      flags |= LibUring::SQE_FLAG::FIXED_FILE if fixed_file
      flags |= LibUring::SQE_FLAG::IO_DRAIN if io_drain
      flags |= LibUring::SQE_FLAG::IO_LINK if io_link
      flags |= LibUring::SQE_FLAG::IO_HARDLINK if io_hardlink
      flags |= LibUring::SQE_FLAG::ASYNC if async

      sqe.value.opcode = op
      sqe.value.flags = flags
      sqe.value.ioprio = 0
      if io_or_index
        sqe.value.fd = io_or_index.is_a?(Int32) ? io_or_index : io_or_index.fd
      end
      sqe.value.off_or_addr2.off = offset
      sqe.value.addr = addr if addr
      sqe.value.len = length
      sqe.value.event_flags.rw_flags = 0 # TODO
      sqe.value.user_data = user_data
      sqe.value.buf_or_pad.pad2[0] = sqe.value.buf_or_pad.pad2[1] = sqe.value.buf_or_pad.pad2[2] = 0
      sqe
    end
  end
end
