lib LibC
  # Not really certain this is correct:
  alias KernelRWFT = Int32

  struct IOVec
    base : Void*
    len : LibC::SizeT
  end

  struct MsgHeader
    name : LibC::SockaddrStorage*
    namelen : LibC::Int
    iov : IOVec*
    iovlen : LibC::SizeT
    control : Void*
    controllen : LibC::SizeT
    flags : LibC::UInt
  end

  # Defined in poll.h
  @[Flags]
  enum POLL_FLAG : UInt16
    POLLIN     = 0x0001
    POLLPRI    = 0x0002
    POLLOUT    = 0x0004
    POLLERR    = 0x0008
    POLLHUP    = 0x0010
    POLLNVAL   = 0x0020
    POLLRDNORM = 0x0040
    POLLRDBAND = 0x0080
    POLLWRNORM = 0x0100
    POLLWRBAND = 0x0200
    POLLMSG    = 0x0400
    POLLREMOVE = 0x1000
    POLLRDHUP  = 0x2000
  end
end
