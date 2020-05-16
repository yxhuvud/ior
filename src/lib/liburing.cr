require "./libc"

@[Link("liburing")]
lib LibUring
  enum Op : UInt8
    NOP
    READV
    WRITEV
    FSYNC
    READ_FIXED
    WRITE_FIXED
    POLL_ADD
    POLL_REMOVE
    SYNC_FILE_RANGE
    SENDMSG
    RECVMSG # ^Linux 5.3
    TIMEOUT # ^Linux 5.4
    TIMEOUT_REMOVE
    ACCEPT
    ASYNC_CANCEL
    LINK_TIMEOUT
    CONNECT # ^Linux 5.5
    FALLOCATE
    OPENAT
    CLOSE
    FILES_UPDATE
    STATX
    READ
    WRITE
    FADVISE
    MADVISE # ^Linux 5.6
    SEND
    RECV
    OPENAT2
    EPOLL_CTL
    SPLICE
    PROVIDE_BUFFERS
    REMOVE_BUFFERS
  end

  @[Flags]
  enum SQE_FLAG : UInt8
    FIXED_FILE
    IO_DRAIN
    IO_LINK
    IO_HARDLINK
    ASYNC
    BUFFER_SELECT
  end

  @[Flags]
  enum SETUP_FLAG : LibC::UInt
    IOPOLL
    SQPOLL
    SQ_AFF
    CQSIZE
    CLAMP
    ATTACH_WQ
  end

  struct IOUringSQ
    khead : LibC::UInt*
    ktail : LibC::UInt*
    kring_mask : LibC::UInt*
    kring_entries : LibC::UInt*
    kflags : LibC::UInt*
    kdropped : LibC::UInt*
    array : LibC::UInt*
    io_uring_sqe : IOUringSQE*
    sqe_head : LibC::UInt
    sqe_tail : LibC::UInt

    ring_sz : LibC::SizeT
    ring_ptr : Void*
  end

  union OffOrAddr2
    off : UInt64
    addr2 : UInt64
  end

  union EventFlags
    rw_flags : LibC::KernelRWFT
    fsync_flags : UInt32
    poll_events : LibC::POLL_FLAG
    sync_range_flags : UInt32
    msg_flags : UInt32
    timeout_flags : UInt32
    accept_flags : UInt32
    cancel_flags : UInt32
    open_flags : UInt32
    statx_flags : UInt32
    fadvice_flags : UInt32
    splice_flags : UInt32
  end

  union BufOrPad
    buf_index : UInt16
    pad2 : UInt64[3]
  end

  struct IOUringSQE
    opcode : Op
    flags : UInt8
    ioprio : UInt16
    fd : Int32
    off_or_addr2 : OffOrAddr2
    addr : UInt64
    len : UInt32
    event_flags : EventFlags
    user_data : UInt64
    buf_or_pad : BufOrPad
  end

  struct IOUringCQE
    user_data : UInt64
    res : Int32
    flags : UInt32
  end

  struct IOUringCQ
    khead : LibC::UInt*
    ktail : LibC::UInt*
    kring_mask : LibC::UInt*
    kring_entries : LibC::UInt*
    koverflow : LibC::UInt*
    cqes : IOUringCQE*

    ring_sz : LibC::SizeT
    ring_ptr : Void*
  end

  struct IOUring
    sq : IOUringSQ
    cq : IOUringCQ
    flags : LibC::UInt
    ring_fd : LibC::Int
  end

  struct IOSQRingOffsets
    head : UInt32
    tail : UInt32
    ring_mask : UInt32
    ring_entries : UInt32
    flags : UInt32
    dropped : UInt32
    array : UInt32
    resv1 : UInt32
    resv2 : UInt64
  end

  struct IOCQRingOffsets
    head : UInt32
    tail : UInt32
    ring_mask : UInt32
    ring_entries : UInt32
    overflow : UInt32
    cqes : UInt32
    resv : UInt64[2]
  end

  struct IOUringParams
    sq_entries : UInt32
    cq_entries : UInt32
    flags : UInt32
    sq_thread_cpu : UInt32
    sq_thread_idle : UInt32
    features : UInt32
    resv : UInt32[4]
    sq_off : IOSQRingOffsets
    cq_off : IOCQRingOffsets
  end

  fun io_uring_queue_init_params(entries : LibC::UInt, ring : IOUring*, p : IOUringParams*) : LibC::Int
  fun io_uring_queue_init(entries : LibC::UInt, ring : IOUring*, flags : SETUP_FLAG) : LibC::Int
  fun io_uring_get_sqe(ring : IOUring*) : IOUringSQE*
  fun io_uring_submit(IOUring*) : LibC::Int
  fun io_uring_submit_and_wait(IOUring*, nr : LibC::UInt) : LibC::Int
  fun io_uring_queue_exit(IOUring*) : Void

  fun io_uring_register_files(ring : IOUring*, files : LibC::Int*, nr_files : LibC::UInt) : LibC::Int
  fun io_uring_unregister_files(ring : IOUring*) : LibC::Int

  # OPENAT magic number to open relative to current working directory
  AT_FDCWD = -100
end
