///|
pub fn[K, V] memo_once(f : (K) -> V) -> (K) -> V {
  let mut cache : (K, V)? = None
  fn(k : K) -> V {
    match cache {
      Some(pair) => pair.1
      None => {
        let v = f(k)
        cache = Some((k, v))
        v
      }
    }
  }
}

///|
pub fn[K : Eq, V] memo_once1(f : (K) -> V) -> (K) -> V {
  let mut cache : (K, V)? = None
  fn(k : K) -> V {
    match cache {
      Some(pair) =>
        if pair.0 == k {
          pair.1
        } else {
          let v = f(k)
          cache = Some((k, v))
          v
        }
      None => {
        let v = f(k)
        cache = Some((k, v))
        v
      }
    }
  }
}

///|
priv struct Test {
  a : Int
  b : String
}

///|
fn Test::new(a : Int, b : String) -> Self {
  { a, b }
}

///|
fn Test::sum(self : Self) -> Int {
  self.a + self.b.length()
}

///|
let memoized_sum : (Test) -> Int = memo_once(Test::sum)

///|
test {
  let t1 = Test::new(3, "abc")
  let t2 = Test::new(3, "abc")
  if not(memoized_sum(t1) == 6) {
    panic()
  }
  if not(memoized_sum(t2) == 6) {
    panic()
  }
}
