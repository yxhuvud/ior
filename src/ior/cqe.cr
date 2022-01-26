require "../lib/liburing_shim"

module IOR
  struct CQE
    struct Result
      property result : Int32

      def initialize(@result)
      end

      def to_i
        result
      end

      def bad_file_descriptor?
        (-result) == 9
      end

      def eagain?
        (-result) == 11
      end

      def timed_out?
        (-result) == 62
      end

      def canceled?
        (-result) == 125
      end

      def error?
        result < 0
      end

      def success?
        !error?
      end

      def errno
        result < 0 ? Errno.new(-result) : Errno.new(0)
      end
    end

    delegate timed_out?, canceled?, eagain?, bad_file_descriptor?, to: @result

    private property cqe
    getter result : Result

    def initialize(@cqe : LibUring::IOUringCQE*, @res : Int32)
      @result = @cqe ? Result.new(@cqe.value.res) : Result.new(0)
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
      result.errno
    end

    def error_message
      errno.message
    end

    def success?
      !ring_error? && result.success?
    end

    def ring_error?
      @res < 0
    end

    def ring_timed_out?
      @res == -62
    end

    def cqe_error?
      result.error?
    end
  end
end
