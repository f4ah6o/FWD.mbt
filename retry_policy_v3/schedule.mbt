///|
/// Deterministic retry schedule (v3).

fn pow_int(base : Int, exp : Int) -> Int {
  let mut acc = 1
  for _i in 0..<exp {
    acc = acc * base
  }
  acc
}

fn backoff_delay(backoff : BackoffPolicy, attempt_index : Int) -> Int {
  match backoff.kind {
    BackoffKind::Fixed => backoff.delay_ms
    BackoffKind::Exponential => {
      backoff.delay_ms * pow_int(backoff.factor, attempt_index - 1)
    }
  }
}

///|
/// Returns delay schedule in milliseconds for each attempt.
/// Attempt 1 is always 0 (immediate).
pub fn retry_schedule(policy : RetryPolicy) -> Array[Int] {
  let delays : Array[Int] = []
  for i in 0..<policy.max_attempts {
    if i == 0 {
      delays.push(0)
    } else {
      delays.push(backoff_delay(policy.backoff, i))
    }
  }
  delays
}
