def spawn!(*args, **opts, &block)
  # This wraps the passed block in a catch-all begin/rescue which kills the process on an unhandled exception.
  spawn(*args, **opts) do
    begin
      block.call
    rescue ex
      STDERR.print "Unhandled exception in spawn!: "
      ex.inspect_with_backtrace(STDERR)
      STDERR.print "spawn!: Fatal. Dying..."
      STDERR.flush
      exit(1)
    end
  end
end

macro spawn!(call, *, name = nil, same_thread = false, &block)
  # This macro is 100% copied from https://github.com/crystal-lang/crystal/blob/master/src/concurrent.cr
  # with "spawn" replaced by "spawn!":
  {% if block %}
    {% raise "`spawn!(call)` can't be invoked with a block, did you mean `spawn!(name: ...) { ... }`?" %}
  {% end %}

  {% if call.is_a?(Call) %}
    ->(
      {% for arg, i in call.args %}
        __arg{{i}} : typeof({{arg.is_a?(Splat) ? arg.exp : arg}}),
      {% end %}
      {% if call.named_args %}
        {% for narg, i in call.named_args %}
          __narg{{i}} : typeof({{narg.value}}),
        {% end %}
      {% end %}
      ) {
      spawn!(name: {{name}}, same_thread: {{same_thread}}) do
        {% if call.receiver %}{{ call.receiver }}.{% end %}{{call.name}}(
          {% for arg, i in call.args %}
            {% if arg.is_a?(Splat) %}*{% end %}__arg{{i}},
          {% end %}
          {% if call.named_args %}
            {% for narg, i in call.named_args %}
              {{narg.name}}: __narg{{i}},
            {% end %}
          {% end %}
        )
      end
      }.call(
        {% for arg in call.args %}
          {{arg.is_a?(Splat) ? arg.exp : arg}},
        {% end %}
        {% if call.named_args %}
          {{call.named_args.map(&.value).splat}}
        {% end %}
      )
  {% else %}
    spawn! do
      {{call}}
    end
  {% end %}
end
