require "../lib/liburing_shim"

module IOR
  struct CQE
    private property cqe

    def initialize(@cqe : LibUring::IOUringCQE*, @res : Int32)
    end

    def to_unsafe
      @cqe
    end

    def error?
      @res < 0
    end

    def errno
      @res
    end

    def res
      @cqe.value.res
    end

    def user_data
      @cqe.value.user_data
    end

    def error_message
      String.new(LibC.strerror(-(error? ? @res : res)))
    end

    def eagain?
      (-res) == 11
    end

    def timed_out?
      (-res) == 62
    end
  end
end
