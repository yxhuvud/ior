require "../lib/liburing_shim"

module IOR
  struct SQE
    private property sqe

    def initialize(@sqe : LibUring::IOUringSQE*)
    end

    def nop(**options)
      prep_rw(LibUring::Op::NOP, nil, nil, 0, 0, **options)
    end

    def read(fd, buf, size = buf.size, offset = -1, **options)
      prep_rw(LibUring::Op::READ, fd, buf.to_unsafe.address, size, offset, **options)
    end

    # TODO: Support using current position (ie offset -1), based on IORING_FEAT_RW_CUR_POS
    def readv(fd, iovecs, offset, **options)
      prep_rw(LibUring::Op::READV, fd, iovecs.to_unsafe.address, iovecs.size, offset, **options)
    end

    def write(fd, buf, size = buf.size, offset = -1, **options)
      prep_rw(LibUring::Op::WRITE, fd, buf.to_unsafe.address, size, offset, **options)
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

    def epoll_ctl
    end

    def send(fd, buf, size = buf.size, flags = 0, **options)
      prep_rw(LibUring::Op::SEND, fd, buf.to_unsafe.address, size, 0, **options).tap do |sqe|
        sqe.value.event_flags.msg_flags = flags
      end
    end

    def sendmsg(fd, msg : LibC::MsgHeader*, flags = 0, **options)
      prep_rw(LibUring::Op::SENDMSG, fd, msg.address, 1, 0, **options).tap do |sqe|
        sqe.value.event_flags.msg_flags = flags
      end
    end

    def recv(fd, buf, size = buf.size, flags = 0, **options)
      prep_rw(LibUring::Op::RECV, fd, buf.to_unsafe.address, size, 0, **options).tap do |sqe|
        sqe.value.event_flags.msg_flags = flags
      end
    end

    def recvmsg(fd, msg : LibC::MsgHeader*, flags = 0, **options)
      prep_rw(LibUring::Op::RECVMSG, fd, msg.address, 1, 0, **options).tap do |sqe|
        sqe.value.event_flags.msg_flags = flags
      end
    end

    def splice(fd_in, off_in : UInt64?, fd_out, off_out : UInt64?, size : Int32, flags = 0, **options)
      off_in ||= UInt64::MAX
      off_out ||= UInt64::MAX
      prep_rw(LibUring::Op::SPLICE, fd_out, off_in, size, off_out, **options).tap do |sqe|
        sqe.value.buf_or_pad.misc.splice_fd_in = fd_in.is_a?(Int32) ? fd_in : fd_in.fd
        sqe.value.event_flags.splice_flags = flags
      end
    end

    def timeout(time : LibC::Timespec*, relative = true, wait_nr = 0, **options)
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

    def connect(fd, addr : Socket::Addrinfo | Socket::Address, **options)
      prep_rw(LibUring::Op::CONNECT, fd, addr.to_unsafe.address, 0, addr.size, **options)
    end

    def fallocate(fd, offset, length, mode = 0, **options)
      prep_rw(LibUring::Op::FALLOCATE, fd, length.to_u64, mode, offset, **options)
    end

    # Absolute path, or relative to CWD
    def openat(pathname, relative_to_cwd = false, **options)
      if relative_to_cwd
        openat(LibUring::AT_FDCWD, pathname, **options)
      else
        openat(nil, pathname, **options)
      end
    end

    def openat(fd, pathname, flags : String, **options)
      oflags = ::Crystal::System::File.ior_open_flags(flags)
      openat(fd, pathname, oflags, **options)
    end

    def openat(fd, pathname : String, flags : UInt32 = 0, mode : LibC::ModeT = 0, **options)
      prep_rw(LibUring::Op::OPENAT, fd, pathname.to_unsafe.address, mode, 0, **options).tap do |sqe|
        sqe.value.event_flags.open_flags = flags
      end
    end

    # TODO: OPENAT2

    def close(fd, **options)
      prep_rw(LibUring::Op::CLOSE, fd, 0, 0, 0, **options)
    end

    def files_update(files : Array(Int32), off = 0, **options)
      prep_rw(LibUring::Op::FILES_UPDATE, -1, files.to_unsafe.address, files.size, off, **options)
    end

    private def prep_rw(op : LibUring::Op, io_or_index, addr : UInt64?, length, offset,
                        user_data = 0u64,
                        fixed_file = false,
                        io_drain = false,
                        io_link = false,
                        io_hardlink = false,
                        async = false)
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
      sqe.value.user_data = user_data
      sqe.value.buf_or_pad.pad2[0] = sqe.value.buf_or_pad.pad2[1] = sqe.value.buf_or_pad.pad2[2] = 0
      sqe
    end

    # ewww, but I couldn't figure out a good way to access the method
    # and I'd rather not copy the implementation.
    module ::Crystal::System::File
      def self.ior_open_flags(mode)
        (open_flag(mode) | LibC::O_CLOEXEC).to_u32
      end
    end
  end
end
