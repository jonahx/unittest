require_relative './calculator'

class TestSuite

  class AssertResult
    def initialize(is_pass, backtrace)
      @is_pass = is_pass
      @backtrace = backtrace
    end

    def pass?
      @is_pass
    end

    def to_s
      pass? ? '.' : 'F'
    end

    def failure_msg
      return nil if pass?

      "FAIL:\n" + 
      "  #{@backtrace}\n" +
      "  #{source_code}\n"
    end

    def source_code
      IO.readlines(@backtrace.absolute_path)[@backtrace.lineno - 1, 1].first
    end
  end

  def initialize(name, &blk)
    @name = name
    @blk = blk
    @tests = {}
    @test_results = {}
  end

  def run
    instance_eval(&@blk)

    @tests.each do |name, blk|
      @cur_test = name
      instance_eval(&blk)
    end

    print_results
  end

  def print_results
    num_assertions = 0
    num_failures = 0

    @test_results.each do |name, assertion_results|
      puts "#{@name} #{name}:"
      puts '  ' + assertion_results.map(&:to_s).join("")

      num_assertions += assertion_results.count
      num_failures += assertion_results.count {|x| !x.pass? } 
    end

    if num_failures > 0
      puts "\nFAILURES:"
      @test_results.each do |name, assertion_results|
      end
    end

    assertion_text = num_assertions == 1 ? "assertion" : "assertions"
    failure_text = num_failures == 1 ? "failure" : "failures"
    puts "\n#{num_assertions} #{assertion_text}, #{num_failures} #{failure_text}."
  end

  def test(name, &blk)
    if @tests[name]
      # TODO: Add line number.
      raise "You've already defined a test named '#{name}'"
    end

    @tests[name] = blk
  end

  def assert(result)
    @test_results[@cur_test] ||= []
    @test_results[@cur_test] << AssertResult.new(result, caller_locations.first)
  end
end

calculator_test = TestSuite.new("Calculator") do
  def calculator
    Calculator.new
  end

  test("add works") do
    assert(calculator.add(1, 2) == 3)
    assert(calculator.add(2, 2) == 5)
    assert(calculator.add(1, 1) == 2)
  end

  #TODO: divide by zero raises
end

calculator_test.run


__END__

TestSuite.new("Arithmetic") do
  def calculator
    Calculator.new
  end

  test("add works") do
    assert(calculator.add(1, 2) == 3)
  end

  test(
    TestSuite.new("negative numbers", self) do
      test("add works") do
        assert(calculator.add(-1, 2) == 1)
      end
    end
  )
end
