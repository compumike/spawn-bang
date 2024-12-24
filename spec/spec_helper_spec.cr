require "./spec_helper"

describe "spec_helper" do
  describe "crystal_eval_code" do
    it "runs code" do
      status, output, error = crystal_eval_code(<<-END)
        puts "Hello, world!"
        STDERR.puts("This is on STDERR.")
        exit(2)
      END

      status.exit_code.should eq(2)
      output.should eq("Hello, world!\n")
      error.should eq("This is on STDERR.\n")
    end

    it "passes arguments and flags to crystal eval" do
      # workaround so `crystal tool format` doesn't break this...
      open_macro = "{" + "%"
      close_macro = "%" + "}"
      open_interpolate = "#" + "{"
      close_interpolate = "}"

      status, output, error = crystal_eval_code(<<-END, env: {"CRYSTAL_WORKERS" => "16", "TESTING" => "abc"}, args: ["-Dpreview_mt"])
        #{open_macro} if flag?(:preview_mt) #{close_macro}
          puts "preview_mt is enabled!"
        #{open_macro} else #{close_macro}
          puts "preview_mt is NOT enabled!"
        #{open_macro} end #{close_macro}
        puts "ENV[\\"CRYSTAL_WORKERS\\"] = #{open_interpolate}ENV["CRYSTAL_WORKERS"].inspect#{close_interpolate}"
        puts "ENV[\\"TESTING\\"] = #{open_interpolate}ENV["TESTING"].inspect#{close_interpolate}"
      END

      status.exit_code.should eq(0)
      output.lines.should eq([
        "preview_mt is enabled!",
        "ENV[\"CRYSTAL_WORKERS\"] = \"16\"",
        "ENV[\"TESTING\"] = \"abc\"",
      ])
      error.should eq("")
    end
  end
end
