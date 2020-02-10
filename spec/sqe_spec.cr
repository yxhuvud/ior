require "./spec_helper"
require "socket"

describe IOR::SQE do
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
      end
    end
  end
end
