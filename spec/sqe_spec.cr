require "./spec_helper"
require "socket"

# stolen from crystal repo, spec_helper.cr
def unused_local_port
  TCPServer.open("::", 0) do |server|
    server.local_address.port
  end
end

describe IOR::SQE do
  describe "#read" do
    it "reads into supplied buffer" do
      content = "This is content for read"
      File.write ".test/read", content

      IOR::IOUring.new do |ring|
        File.open(".test/read") do |fh|
          buf = Slice(UInt8).new(32) { 0u8 }

          ring.sqe.read(fh, buf, user_data: 4711)
          ring.submit_and_wait
          ring.peek do |cqe|
            cqe.user_data.should eq 4711
            cqe.res.should eq content.size
            String.new(buf[0, cqe.res]).should eq content
          end
        end
      end
    end
  end

  describe "#readv" do
    it "reads into supplied buffer" do
      content = "This is content for readv"
      File.write ".test/readv", content

      IOR::IOUring.new do |ring|
        File.open(".test/readv") do |fh|
          buf = Slice(UInt8).new(32) { 0u8 }

          ring.sqe.readv(fh, iovec(buf), 0, user_data: 4711)
          ring.submit.should eq 1
          cqe = ring.wait

          cqe.user_data.should eq 4711
          cqe.res.should eq content.size
          String.new(buf[0, cqe.res]).should eq content
        end
      end
    end
  end

  describe "#write" do
    it "writes into file" do
      content = "This is content for write"

      IOR::IOUring.new do |ring|
        File.open(".test/write", "w") do |fh|
          ring.sqe.write(fh, content, user_data: 4711)
          ring.submit.should eq 1
          cqe = ring.wait

          cqe.user_data.should eq 4711
          cqe.res.should eq content.size
          File.read(".test/write").should eq content
        end
      end
    end
  end

  describe "#writev" do
    it "writes into file" do
      content = "This is content for writev"

      IOR::IOUring.new do |ring|
        File.open(".test/writev", "w") do |fh|
          ring.sqe.writev(fh, iovec(content), 0, user_data: 4711)
          ring.submit.should eq 1
          cqe = ring.wait

          cqe.user_data.should eq 4711
          cqe.res.should eq content.size
          File.read(".test/writev").should eq content
        end
      end
    end
  end

  describe "#recvmsg" do
    it "receives on socket" do
      str = "hello world!"
      left, right = UNIXSocket.pair
      IOR::IOUring.new do |ring|
        buf = Slice(UInt8).new(32) { 0u8 }
        header = msgheader(iovec(buf))

        right.write str.to_slice
        ring.sqe.recvmsg(left, pointerof(header), 0, user_data: 4711)
        ring.submit.should eq 1
        cqe = ring.wait

        cqe.user_data.should eq 4711
        cqe.res.should eq str.size
        String.new(buf[0, cqe.res]).should eq str
      end
    end
  end

  describe "#sendmsg" do
    it "sends on socket" do
      str = "hello world!"
      left, right = UNIXSocket.pair
      IOR::IOUring.new do |ring|
        header = msgheader(iovec(str))

        ring.sqe.sendmsg(left, pointerof(header), 0, user_data: 4711)
        ring.submit.should eq 1
        cqe = ring.wait
        left.close

        cqe.user_data.should eq 4711
        cqe.res.should eq str.size
        right.gets_to_end.should eq str
      end
    end
  end

  describe "#add_poll" do
    it "polls socket" do
      str = "hello world!"
      left, right = UNIXSocket.pair
      IOR::IOUring.new do |ring|
        ring.sqe.poll_add(left, :POLLIN, user_data: 4711)
        ring.submit
        cqe = ring.peek.should be_nil

        spawn { right.write str.to_slice }

        ring.wait do |cqe|
          (cqe.res & LibC::POLL_FLAG::POLLIN.to_i > 0).should be_true
          cqe.user_data.should eq 4711
        end
      end
    end
  end

  describe "#timeout" do
    it "timeouts" do
      time = 0.001.seconds
      timespec = LibC::Timespec.new(tv_sec: time.to_i, tv_nsec: time.nanoseconds)
      IOR::IOUring.new do |ring|
        ring.sqe.timeout(pointerof(timespec), user_data: 4711)
        ring.submit
        ring.peek.should eq nil

        cqe = ring.wait
        cqe.user_data.should eq 4711
        cqe.timed_out?.should be_true
      end
    end

    it "returns early if appropriate amount of events has completed." do
      time = 0.001.seconds
      timespec = LibC::Timespec.new(tv_sec: time.to_i, tv_nsec: time.nanoseconds)
      IOR::IOUring.new do |ring|
        ring.sqe.timeout(pointerof(timespec), user_data: 4711)
        ring.sqe.nop(user_data: 17)
        ring.submit

        cqe = ring.wait
        cqe.user_data.should eq 17
        ring.seen cqe

        cqe = ring.wait
        cqe.user_data.should eq 4711
        cqe.timed_out?.should be_false
        ring.seen cqe
      end
    end
  end

  describe "#link_timeout" do
    it "timeouts op if op takes a long time." do
      time = 0.005.seconds
      left, right = UNIXSocket.pair
      timespec = LibC::Timespec.new(tv_sec: time.to_i, tv_nsec: time.nanoseconds)
      IOR::IOUring.new do |ring|
        ring.sqe.poll_add(left, user_data: 4711, io_link: true)
        ring.sqe.link_timeout(pointerof(timespec), user_data: 13)
        ring.submit
        ring.peek.should be_nil

        # Different Linux versions return these in different order.
        seen = Array(UInt64).new(2) do
          cqe = ring.wait
          case cqe.user_data
          when 4711
            cqe.timed_out?.should be_false
            cqe.canceled?.should be_true
          when 13
            cqe.timed_out?.should be_true
            cqe.canceled?.should be_false
          end
          ring.seen cqe
          cqe.user_data
        end

        seen.sort.should eq [13, 4711]
      end
    end

    it "lets op finish if it can within time." do
      time = 5.seconds
      left, right = UNIXSocket.pair
      timespec = LibC::Timespec.new(tv_sec: time.to_i, tv_nsec: time.nanoseconds)
      buf = Slice(UInt8).new(32) { 0u8 }
      header = msgheader(iovec(buf))
      IOR::IOUring.new do |ring|
        ring.sqe.recvmsg(left, pointerof(header), 0, user_data: 4711, io_link: true)
        ring.sqe.link_timeout(pointerof(timespec), user_data: 13)
        ring.submit
        right.write buf

        cqe = ring.wait
        cqe.user_data.should eq 4711
        cqe.timed_out?.should be_false
        cqe.canceled?.should be_false
        ring.seen cqe

        cqe = ring.wait
        cqe.user_data.should eq 13
        cqe.timed_out?.should be_false
        cqe.canceled?.should be_true
        ring.seen cqe
      end
    end
  end

  describe "#timeout_remove" do
    it "removes a timeout" do
      time = 5.days
      timespec = LibC::Timespec.new(tv_sec: time.to_i, tv_nsec: time.nanoseconds)
      IOR::IOUring.new do |ring|
        ring.sqe.timeout(pointerof(timespec), user_data: 4711)
        ring.submit
        ring.sqe.timeout_remove(4711, user_data: 13)
        ring.submit

        # The order between this and the following group is arbitrary,
        # but consistent for this particular test. Don't rely on it.
        cqe = ring.wait
        cqe.user_data.should eq 4711
        cqe.error_message.should eq "Operation canceled"
        cqe.timed_out?.should be_false
        ring.seen cqe

        cqe = ring.wait
        cqe.user_data.should eq 13
        cqe.res.should eq 0
      end
    end
  end

  describe "#async_cancel" do
    it "cancels" do
      left, right = UNIXSocket.pair
      IOR::IOUring.new do |ring|
        ring.sqe.poll_add(left, user_data: 4711)
        ring.submit
        cqe = ring.peek.should be_nil

        ring.sqe.async_cancel(4711, user_data: 13)
        ring.submit

        # Different Linux versions return these in different order.
        seen = Array(UInt64).new(2) do
          cqe = ring.wait
          case cqe.user_data
          when 4711
            cqe.error_message.should eq "Operation canceled"
            cqe.canceled?.should be_true
          when 13
            cqe.res.should eq 0
          end
          ring.seen cqe
          cqe.user_data
        end

        seen.sort.should eq [13, 4711]
      end
    end
  end

  describe "#accept" do
    it "accepts incoming connections" do
      client_done = Channel(Nil).new
      server = Socket.new(Socket::Family::INET, Socket::Type::STREAM, Socket::Protocol::TCP)
      begin
        port = unused_local_port
        server.bind("0.0.0.0", port)
        server.listen

        spawn do
          TCPSocket.new("127.0.0.1", port).close
        ensure
          client_done.send nil
        end
        # Make certain the above executes
        Fiber.yield

        IOR::IOUring.new do |ring|
          loop do
            ring.sqe.accept(server.fd, user_data: 4711)
            ring.submit
            cqe = ring.wait
            if cqe.eagain?
              ring.seen cqe
              next
            end

            (cqe.res > 0).should be_true
            sock = Socket.new(cqe.res, server.family, server.type, server.protocol, server.blocking)
            ring.seen cqe
            sock.close
            break
          end
        end
      ensure
        server.close
        client_done.receive
      end
    end
  end

  describe "#connect" do
    it "connects" do
      port = unused_local_port
      TCPServer.open("127.0.0.1", port) do |server|
        Socket::Addrinfo.tcp("127.0.0.1", port) do |addrinfo|
          fd = LibC.socket(addrinfo.family, addrinfo.type, addrinfo.protocol)
          IOR::IOUring.new do |ring|
            ring.sqe.connect(fd, addrinfo, user_data: 4711)
            ring.submit_and_wait
            cqe = ring.wait
            cqe.error_message.should eq "Success"
            server.accept
            sock = TCPSocket.new(fd: fd, family: addrinfo.family)
            sock.close
          end
        end
      end
    end
  end

  describe "#fallocate" do
    it "adjusts the size of a file" do
      File.write ".test/fallocate", "test"
      File.size(".test/fallocate").should eq 4
      File.open ".test/fallocate", "w" do |f|
        IOR::IOUring.new do |ring|
          ring.sqe.fallocate f.fd, 0, 1024
          ring.submit_and_wait
          cqe = ring.wait
          cqe.success?.should be_true
          ring.seen cqe
        end
      end
      File.size(".test/fallocate").should eq 1024
    end
  end

  describe "#openat" do
    it "Can open files" do
      File.write ".test/openat", "test"
      IOR::IOUring.new do |ring|
        ring.sqe.openat ".test/openat", relative_to_cwd: true, flags: "r"
        ring.submit_and_wait
        cqe = ring.wait
        cqe.success?.should eq true
        fd = cqe.res
        # File doesn't have a convenient way to initialize from a file
        # descriptor :/
        file = IO::FileDescriptor.new fd
        buf = Slice(UInt8).new(4) { 0u8 }
        file.read(buf)
        String.new(buf).should eq "test"
        ring.seen cqe
      end
    end

    # TODO: Test file creation
    # TODO: Test file relative to directory
  end

  describe "#close" do
    it "works" do
      fh = File.open ".test/close", "w"
      IOR::IOUring.new do |ring|
        ring.sqe.close fh.fd
        ring.submit_and_wait
        cqe = ring.wait
        cqe.success?.should eq true
      end
    end
  end

  describe "#files_update" do
    it "can update files" do
      content = "This is content for reg"
      File.write ".test/files_update1", content
      File.write ".test/files_update2", content * 2

      IOR::IOUring.new do |ring|
        fh1 = File.open(".test/files_update1")
        fh2 = File.open(".test/files_update2")
        ring.register_files [fh1]
        ring.sqe.files_update([fh2.fd], 0)

        ring.submit_and_wait
        cqe = ring.wait
        cqe.success?.should be_true
        ring.seen cqe

        buf = Slice(UInt8).new(content.size * 2) { 0u8 }
        ring.sqe.readv(0, iovec(buf), 0, user_data: 4711, fixed_file: true)
        ring.submit.should eq 1

        ring.wait do |cqe|
          cqe.user_data.should eq 4711
          cqe.res.should eq content.size * 2
          String.new(buf[0, cqe.res]).should eq content * 2
        end
      end
    end
  end
end
