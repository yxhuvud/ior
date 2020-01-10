# ior
Bindings for liburing. These bindings are not intended to be safe, or
to replace the built-in ways of doing IO in Crystal. Rather this is
intended to be the base other libraries and applications use so that
they can accomplish that.

## Installation

0. Install liburing ( https://github.com/axboe/liburing ) and a recent Linux kernel.

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     ior:
       github: yxhuvud/ior
   ```

2. Run `shards install`

## Usage
The basic abstraction is the uring. A uring consists of a submission
queue and a completion queue. A user writes to the submission queue
and reads from the completion queue. An instance can be created by
calling `IOR::IOUring.new` (there is also a block version available).
Operations on a ring include:

* `ring.submit`: Submits the currently unsubmitted events in the submission
queue. Multiple events can be submitted at once.

* `ring.wait`, `ring.wait(n)` : Wait until there is at least one (`n`) entry in the
completion queue. Then it returns the first of those.

* `ring.peek`: If there is an unprocessed entry in the submission queue,
return it. Otherwise return `nil`.

* `ring.seen(cqe_ptr)`: Marks the given completion queue event as seen.

* `ring.sqe`: Fetches a submission queue event.

  The following operations are then supported to configure the sqe.

  * `sqe.nop`: Submit an event and get it back in the completion queue, without actually doing anything.
  * `sqe.readv`, `sqe.writev`: Vectored writes. Same as `readv` and `writev` syscalls.
  * `sqe.fsync`: File sync. Same as `fsync` syscall, but note that the
                queue doesn't promise to handle events in order, by default.
  * `sqe.sendmsg`, `sqe.recvmsg`: Network read/write. Same as `sendmsg` and `recvmsg` syscalls.
  * `sqe.poll_add`: Similar to `poll` and `epoll`.

  All SQEs supports the following options:
    * `fixed_file` : Use one of the previously registered files. See `IOR::IOUring#register_files`.
    * `io_drain`: Process all other entries in the ring before processing this.
    * `io_link`: If this is set, then the next event will not be started before the processing of this even is done.
    * `io_hardlink`: Same as above but different. See `man` pages for description.

  See https://github.com/yxhuvud/ior/blob/master/src/ior/sqe.cr and `man io_uring_enter` for details.

* `ring.close`: Tear down the ring.

* `ring.register_files`, `ring.unregister_files`: In addition to working with normal file
descriptors, IOUring can avoid the cost of setting up internal
structures for each and every call by registering a list of files in
advance. To make use of these files, the submission queue event (sqe)
must have the `fixed_file` flag set.

* `ring.sq_ready`: Shows how many unsubmitted events are present in the submission queue.

* `ring.space_left`: Shows how many more events can be sent before `submit` is necessary.

* `ring.cq_read`: Shows how many events are waiting in the completion queue.

Example:
```crystal
require "ior"

fh = File.open(".test/readv")
buf = Slice(UInt8).new(32) { 0u8 }
vec = LibC::IOVec.new
vec.base = buf.to_unsafe
vec.len = buf.size
iovecs = Slice(LibC::IOVec).new(1, vec)

# First create a ring:
ring = IOR::IOUring.new

# Set up a submission queue event. Multiple submissions can be sent
# out at once. They will be executed in undefined order by default,
# but it is possible to define the order if need be.

# The user_data field that is set is also set on the corresponding
# completion event, and can for example contain a pointer to something
# that instructs the program on how to handle the result.
ring.sqe.readv(fh, buf, 0, user_data: 4711)

# Then tell the kernel about it. This is a syscall that doesn't block.
ring.submit

# Then wait for the result. This will return immediately without
# having to do any syscall if there is already events ready to
# consume, and if not it will block until there is at least one event
# ready.

# wait returns an event from the completion queue.
cqe = ring.wait

# These contain the user_data and and result from the call. In this
# case the content of the file.
string = String.new(buf[0, cqe.value.res])
cqe.value.user_data # => 4711

# When processed a completion event should be marked as consumed:
ring.seen(cqe)

# Cleanup:
fh.close
ring.close
```

## Read more
Additional resource can be found in the `man` pages, and at
https://kernel.dk/io_uring.pdf or https://github.com/axboe/liburing .


## Development
See installation instructions. Additionally some specs need the
`-Dpreview_mt` flag set or they will block forever.

## Contributing

1. Fork it (<https://github.com/your-github-user/ior/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Linus Sellberg](https://github.com/yxhuvud) - creator and maintainer
