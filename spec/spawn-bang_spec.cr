require "./spec_helper"

macro assert_block_example_with_no_exception!
  status, output, error = crystal_eval_code(<<-END, env: config_env, args: config_args)
    require "./src/spawn-bang"
    ch = Channel(Nil).new
    spawn! { ch.send(nil) }
    ch.receive
    puts "Finished!"
  END

  status.exit_code.should eq(0)
  output.should eq("Finished!\n")
  error.should eq("")

  {status, output, error}
end

macro assert_block_example_with_exception!
  status, output, error = crystal_eval_code(<<-END, env: config_env, args: config_args)
    require "./src/spawn-bang"
    ch = Channel(Nil).new
    spawn! { raise ArgumentError.new("Nope"); ch.send(nil) }
    ch.receive
    puts "Finished!"
  END

  status.exit_code.should eq(1)
  output.should eq("")
  error.lines.should contain("Unhandled exception in spawn!: Nope (ArgumentError)")
  error.lines.last.should eq("spawn!: Fatal. Dying...")

  {status, output, error}
end

macro assert_block_example_with_global_variable_reuse!
  status, output, error = crystal_eval_code(<<-END, env: config_env, args: config_args)
    require "./src/spawn-bang"
    ch = Channel(Int32).new
    i = 0
    while i < 10
      spawn! { ch.send(i) }
      i += 1
    end
    
    10.times { puts ch.receive }
    puts "Finished!"
  END

  status.exit_code.should eq(0)
  # output will be "10\n10\n10\n10\n10\nFinished!\n" without multithreading, but may vary with multithreading enabled!
  output.lines.size.should eq(11)
  output.lines.last.should eq("Finished!")
  error.should eq("")

  {status, output, error}
end

macro assert_macro_example_with_no_exception!
  status, output, error = crystal_eval_code(<<-END, env: config_env, args: config_args)
    require "./src/spawn-bang"
    ch = Channel(Nil).new
    def send_nil(channel)
      channel.send(nil)
    end
    spawn!(send_nil(ch))
    ch.receive
    puts "Finished!"
  END

  status.exit_code.should eq(0)
  output.should eq("Finished!\n")
  error.should eq("")

  {status, output, error}
end

macro assert_macro_example_with_exception!
  status, output, error = crystal_eval_code(<<-END, env: config_env, args: config_args)
    require "./src/spawn-bang"
    ch = Channel(Nil).new
    def send_nil(channel)
      raise ArgumentError.new("Nope")
      channel.send(nil)
    end
    spawn!(send_nil(ch))
    ch.receive
    puts "Finished!"
  END

  status.exit_code.should eq(1)
  output.should eq("")
  error.lines.should contain("Unhandled exception in spawn!: Nope (ArgumentError)")
  error.lines.last.should eq("spawn!: Fatal. Dying...")

  {status, output, error}
end

macro assert_macro_example_with_captured_args!
  status, output, error = crystal_eval_code(<<-END, env: config_env, args: config_args)
    require "./src/spawn-bang"
    ch = Channel(Int32).new
    def send_value(channel, value)
      channel.send(value)
    end
    i = 0
    while i < 10
      spawn!(send_value(ch, i))
      i += 1
    end
    
    10.times { puts ch.receive }
    puts "Finished!"
  END

  status.exit_code.should eq(0)
  # output will be "0\n1\n2\n3\n4\n5\n6\n7\n8\n9\nFinished!\n" without multithreading, but the order may vary with multithreading enabled!
  output.lines.size.should eq(11)
  output.lines.last.should eq("Finished!")
  error.should eq("")

  {status, output, error}
end

describe "spawn!" do
  describe "Default Crystal config" do
    config_env = nil
    config_args = [] of String

    describe "block mode: spawn! { ... }" do
      it "spawns when there's no exception" do
        assert_block_example_with_no_exception!
      end

      it "dies when there's an exception" do
        assert_block_example_with_exception!
      end

      it "reuses a global variable, matching spawn" do
        _status, output, _error = assert_block_example_with_global_variable_reuse!

        # Without -Dpreview_mt, the spawned Fibers will run only after the loop is finished.
        output.should eq(("10\n" * 10) + "Finished!\n")
      end
    end

    describe "macro call mode: spawn!(...)" do
      it "spawns when there's no exception" do
        assert_macro_example_with_no_exception!
      end

      it "dies when there's an exception" do
        assert_macro_example_with_exception!
      end

      it "captures the current value of all call arguments, matching spawn" do
        _status, output, _error = assert_macro_example_with_captured_args!

        # Without -Dpreview_mt, the spawned Fibers will run in order.
        output.should eq("0\n1\n2\n3\n4\n5\n6\n7\n8\n9\nFinished!\n")
      end
    end
  end

  describe "-Dpreview_mt CRYSTAL_WORKERS=1" do
    config_env = {"CRYSTAL_WORKERS" => "1"}
    config_args = ["-Dpreview_mt"]

    describe "block mode: spawn! { ... }" do
      it "spawns when there's no exception" do
        assert_block_example_with_no_exception!
      end

      it "dies when there's an exception" do
        assert_block_example_with_exception!
      end

      it "reuses a global variable, matching spawn" do
        _status, output, _error = assert_block_example_with_global_variable_reuse!

        # With CRYSTAL_WORKERS=1,, the spawned Fibers will run only after the loop is finished.
        output.should eq(("10\n" * 10) + "Finished!\n")
      end
    end

    describe "macro call mode: spawn!(...)" do
      it "spawns when there's no exception" do
        assert_macro_example_with_no_exception!
      end

      it "dies when there's an exception" do
        assert_macro_example_with_exception!
      end

      it "captures the current value of all call arguments, matching spawn" do
        _status, output, _error = assert_macro_example_with_captured_args!

        # 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 should all appear EXACTLY ONCE EACH in the output,
        # thanks to the captured call argument, but may appear in any order due to concurrency
        output.lines.sort.should eq(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "Finished!"])
      end
    end
  end

  describe "-Dpreview_mt CRYSTAL_WORKERS=4" do
    config_env = {"CRYSTAL_WORKERS" => "4"}
    config_args = ["-Dpreview_mt"]

    describe "block mode: spawn! { ... }" do
      it "spawns when there's no exception" do
        assert_block_example_with_no_exception!
      end

      it "dies when there's an exception" do
        assert_block_example_with_exception!
      end

      it "reuses a global variable, matching spawn" do
        _status, output, _error = assert_block_example_with_global_variable_reuse!

        # Due to multithreading, the spawned Fibers are likely to get scheduled before the loop is finished,
        # so we may see any value 0 through 10 from each Fiber:
        values = output.lines.truncate(0, 10).map(&.to_i)
        values.each do |v|
          v.should be >= 0
          v.should be <= 10
        end

        # Highly unlikely that they'd all be the same?
        # But possible, especially if all are 10.
        values.uniq.size.should be >= 2
      end
    end

    describe "macro call mode: spawn!(...)" do
      it "spawns when there's no exception" do
        assert_macro_example_with_no_exception!
      end

      it "dies when there's an exception" do
        assert_macro_example_with_exception!
      end

      it "captures the current value of all call arguments, matching spawn" do
        _status, output, _error = assert_macro_example_with_captured_args!

        # 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 should all appear EXACTLY ONCE EACH in the output,
        # thanks to the captured call argument, but may appear in any order due to concurrency
        output.lines.sort.should eq(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "Finished!"])
      end
    end
  end
end
