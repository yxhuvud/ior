@[Link("liburing")]
lib LibUring
  # Not really certain this is correct:
  alias KernelRWFT = Int32

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
    RECVMSG # ^Linux 5.1
    TIMEOUT
    TIMEOUT_REMOVE
    ACCEPT
    ASYNC_CANCEL
    LINK_TIMEOUT # ^Linux 5.2
    CONNECT
    FALLOCATE
    OPENAT
    CLOSE
    FILES_UPDATE
    STATX
    READ
    WRITE # ^Linux 5.3
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
    sql_tail : LibC::UInt

    ring_sz : LibC::SizeT
    ring_ptr : Void*
  end

  union OffOrAddr2
    off : UInt64
    addr2 : UInt64
  end

  union EventFlags
    rw_flags : KernelRWFT
    fsync_flags : UInt32
    poll_events : UInt16
    sync_range_flags : UInt32
    msg_flags : UInt32
    timeout_flags : UInt32
    accept_flags : UInt32
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

  struct IOVec
    # Workaround to crystal issue #4599
    #  iov_base : Void*
    iov_base : Int64
    iov_len : LibC::SizeT
  end

  struct MsgHeader
    name : LibC::Sockaddr*
    namelen : LibC::Int
    iov : IOVec*
    iovlen : LibC::SizeT
    control : Void*
    controllen : LibC::SizeT
    flags : LibC::UInt
  end

  fun io_uring_queue_init_params(entries : LibC::UInt, ring : IOUring*, p : IOUringParams*) : LibC::Int
  fun io_uring_queue_init(entries : LibC::UInt, ring : IOUring*, flags : LibC::UInt) : LibC::Int
  fun io_uring_get_sqe(ring : IOUring*) : IOUringSQE*
  fun io_uring_submit(IOUring*) : LibC::Int
  fun io_uring_queue_exit(IOUring*) : Void
end
