///|
struct GuardChannel[T] {
  consumers : Array[((T) -> Unit, (T) -> Bool)]
  buffer : Array[T]
}

///|
pub fn[T] GuardChannel::new() -> GuardChannel[T] {
  { consumers: [], buffer: [], }
}

///|
pub fn[T] GuardChannel::send(self : GuardChannel[T], v : T) -> Unit {
  if self.consumers.length() > 0 {
    for i, consumer in self.consumers {
      let (c, pred) = consumer
      if pred(v) {
        self.consumers.remove(i) |> ignore
        return c(v)
      }
    }
  }
  self.buffer.push(v)
}

///|
pub async fn[T] GuardChannel::recv(
  self : GuardChannel[T],
  pred : (T) -> Bool,
) -> T {
  if self.buffer.length() > 0 {
    for i, v in self.buffer {
      if pred(v) {
        self.buffer.remove(i) |> ignore
        return v
      }
    }
  }
  @kit.suspend(fn(k) { self.consumers.push((k, pred)) })
}

///|
test "Simple usage" {
  let ch = GuardChannel::new()
  ch.send(1)
  ch.send(0)
  let mut v1 = None
  let mut v2 = None
  @kit.run_async(() => {
    v1 = Some(ch.recv(fn(v) { v % 2 == 0 }))
    v2 = Some(ch.recv(fn(v) { v % 2 == 1 }))
  })
  assert_eq(v1, Some(0))
  assert_eq(v2, Some(1))
}
