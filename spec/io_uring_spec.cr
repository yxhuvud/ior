require "./spec_helper"
require "socket"

describe IOR::IOUring do
  describe ".new" do
    pending
  end

  describe "registering files" do
    it "should be possible to work with registered files" do
      content = "This is content for reg"
      File.write ".test/register", content

      IOR::IOUring.new do |ring|
        File.open(".test/register") do |fh|
          buf = Slice(UInt8).new(32) { 0u8 }
          ring.register_files([fh])

          ring.sqe.readv(0, iovec(buf), 0, user_data: 4711, fixed_file: true)
          ring.submit.should eq 1
          cqe = ring.wait

          cqe.value.user_data.should eq 4711
          cqe.value.res.should eq content.size
          String.new(buf[0, cqe.value.res]).should eq content
        end
      end
    end

    pending "should be possible to set the sq_poll flag and use registered flags" do
      content = "This is content for sqpoll"
      File.write ".test/sqpoll", content

      # Eh, this requires root. Pending this for now.

      # IOR::IOUring.new(sq_poll: true) do |ring|
      #   File.open(".test/sqpoll") do |fh|
      #     buf = Slice(UInt8).new(32) { 0u8 }
      #     ring.register_files([fh])

      #     sqe = ring.sqe.readv(0, iovec(buf), 0, user_data: 4711, fixed_file: true)
      #     sleep 1
      #     cqe = ring.wait

      #     cqe.value.user_data.should eq 4711
      #     cqe.value.res.should eq content.size
      #     String.new(buf[0, cqe.value.res]).should eq content
      #   end
      # end
    end
  end

  describe "#ready/#space_left/#cq_ready" do
    it "keep track of the queue sizes" do
      IOR::IOUring.new(size: 4) do |ring|
        ring.sq_ready.should eq 0
        ring.sq_space_left.should eq 4

        3.times { ring.sqe.nop }

        ring.sq_ready.should eq 3
        ring.sq_space_left.should eq 1
        ring.cq_ready.should eq 0

        ring.submit
        ring.wait 3

        ring.sq_ready.should eq 0
        ring.sq_space_left.should eq 4
        ring.cq_ready.should eq 3
      end
    end
  end
end
