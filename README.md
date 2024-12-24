# spawn-bang

In [Crystal](https://crystal-lang.org/), an unhandled exception in the main `Fiber` causes the process to die with `exit(1)`, while an unhandled exception in a `spawn`-ed Fiber will print the exception to STDERR and stop that Fiber, but the process will otherwise keep running. This makes it far too easy to have an unnoticed, unhandled exception. This **spawn-bang** shard makes available a top-level method and macro `spawn!` which is identical to `spawn` but will terminate the process with `exit(1)` if there is an unhandled exception.

In general, you can always replace `spawn` with `spawn!`. You are still free to (and encouraged to) implement your own exception handling within `spawn!`, especially for exceptions you know are likely to happen and you'd like to ignore or handle without killing the process. Using `spawn!` simply changes the default behavior for unhandled exceptions.

**spawn-bang** is currently used in production on [Heii On-Call](https://heiioncall.com/).

## How it works

The code:

```crystal
require "spawn-bang"

spawn! do
  # YOUR CODE GOES HERE
end
```

is 100% equivalent to:

```crystal
spawn do
  begin
    # YOUR CODE GOES HERE
  rescue ex
    STDERR.print "Unhandled exception in spawn!: "
    ex.inspect_with_backtrace(STDERR)
    STDERR.print "spawn!: Fatal. Dying..."
    STDERR.flush
    exit(1)
  end
end
```

A macro version is also provided for compatibility with the macro version of `spawn`. See [Spawning a call](https://crystal-lang.org/reference/guides/concurrency.html#spawning-a-call).

## Proposed for inclusion in Crystal standard library

I would like to see `spawn!` included in the Crystal standard library, rather than requiring this shard.

If you agree, feel free to comment on: [Proposal for spawn! on Crystal forum](https://forum.crystal-lang.org/t/proposal-add-spawn-to-exit-1-on-any-unhandled-exception-in-spawned-fiber/7432)

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     spawn-bang:
       github: compumike/spawn-bang
   ```

2. Run `shards install`

## Usage

1. Add `require "spawn-bang"`

2. Replace all occurences of `spawn` with `spawn!`

## See also

- [crystal/src/concurrent.cr](https://github.com/crystal-lang/crystal/blob/master/src/concurrent.cr)
- [Crystal Concurrency Guide](https://crystal-lang.org/reference/guides/concurrency.html)
- [Proposal for spawn! on Crystal forum](https://forum.crystal-lang.org/t/proposal-add-spawn-to-exit-1-on-any-unhandled-exception-in-spawned-fiber/7432)
