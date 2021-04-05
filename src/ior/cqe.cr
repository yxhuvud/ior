require "../lib/liburing_shim"

module IOR
  struct CQE
    private property cqe

    def initialize(@cqe : LibUring::IOUringCQE*, @res : Int32)
    end

    def to_unsafe
      @cqe
    end

    def errno
      ring_errno.none? ? cqe_errno : ring_errno
    end

    def res
      @cqe.value.res
    end

    def user_data
      @cqe.value.user_data
    end

    def ring_errno
      @res < 0 ? Errno.new(-@res) : Errno.new(0)
    end

    def cqe_errno
      res < 0 ? Errno.new(-res) : Errno.new(0)
    end

    def error_message
      errno.message
    end

    def success?
      !ring_error? && !cqe_error?
    end

    def ring_error?
      @res < 0
    end

    def cqe_error?
      res < 0
    end

    def bad_file_descriptor?
      (-res) == 9
    end

    def eagain?
      (-res) == 11
    end

    def timed_out?
      (-res) == 62
    end

    def canceled?
      (-res) == 125
    end
  end
end
