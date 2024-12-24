require "spec"
require "../src/spawn-bang"

def crystal_eval_code(code : String, env : Process::Env = nil, args : Array(String) = [] of String) : Tuple(Process::Status, String, String)
  eval_stdin = IO::Memory.new(code)
  eval_stdout = IO::Memory.new
  eval_stderr = IO::Memory.new
  eval_status : Process::Status = Process.run(
    "crystal",
    ["eval", *args],
    env: env,
    input: eval_stdin,
    output: eval_stdout,
    error: eval_stderr
  )
  {eval_status, eval_stdout.to_s, eval_stderr.to_s}
end
