require_relative './calculator'

class TestSuite

  # AssertResult is the result of a single assertion, with the ability to print
  # the source code that caused a failure.
  class AssertResult
    def initialize(is_pass, backtrace)
      @is_pass = is_pass
      @backtrace = backtrace
    end

    def pass?
      @is_pass
    end

    def fail?
      !@is_pass
    end

    def to_s
      pass? ? '.' : 'F'
    end

    def failure_msg
      return nil if pass?

      "FAIL:\n" + 
      "    #{source_code}\n" +
      "  in #{@backtrace}\n"
    end

    def source_code
      lines = IO.readlines(@backtrace.absolute_path)[@backtrace.lineno - 1, 1]
      lines.first.sub(/^\s+/, '').chomp
    end
  end

  # TestResult is essentially a list of AssertResult objects.
  class TestResult
    def initialize(assert_results)
      @assert_results = assert_results
    end

    def to_s
      summary = '  ' + @assert_results.map(&:to_s).join('')

      failures = @assert_results.select(&:fail?).map(&:failure_msg)
      indented_failures = failures.map { |x| x.sub(/^/, '  ')}

      (summary + "\n\n" + indented_failures.join("\n")).chomp
    end

    def num_assertions
      @num_assertions ||= @assert_results.size
    end

    def num_failures
      @num_failures ||= @assert_results.count(&:fail?)
    end
  end

  def initialize(suite_name, &blk)
    @suite_name = suite_name
    @blk = blk
    @tests = {}
    @results = {}
  end

  def run
    # Save the tests as blocks, but don't execute them yet.
    instance_eval(&@blk)

    # Now execute them.
    @tests.each do |test_name, blk|
      @cur_test = test_name
      instance_eval(&blk)

      result = TestResult.new(@results[@cur_test])
      @results[@cur_test] = result

      printf "\n#{@suite_name} #{test_name}:\n#{result}"
    end

    # Print test result summary.
    all_results = @results.values
    num_assertions = all_results.map(&:num_assertions).sum
    num_failures = all_results.map(&:num_failures).sum

    assertion_text = num_assertions == 1 ? "assertion" : "assertions"
    failure_text = num_failures == 1 ? "failure" : "failures"
    puts "#{num_assertions} #{assertion_text}, #{num_failures} #{failure_text}."
  end

  def test(name, &blk)
    raise "You've already defined a test named '#{name}'" if @tests[name]

    @tests[name] = blk
  end

  def assert(result)
    @results[@cur_test] ||= []
    @results[@cur_test] << AssertResult.new(result, caller_locations.first)
  end

  def assert_raise(expected_err=StandardError, &blk)
    assert_block(expected_err, true, &blk)
  end

  def assert_no_raise(expected_err=StandardError, &blk)
    assert_block(expected_err, false, &blk)
  end

  private

  def assert_block(expected_err=StandardError, will_error, &blk)
    @results[@cur_test] ||= []
    blk.call
    @results[@cur_test] << AssertResult.new(!will_error, caller_locations.first)
  rescue expected_err
    @results[@cur_test] << AssertResult.new(will_error, caller_locations.first)
  end
end

calculator_test = TestSuite.new("Calculator") do
  def calculator
    Calculator.new
  end

  test("can add positive numbers") do
    assert(calculator.add(1, 2) == 3)
    assert(calculator.add(2, 2) == 4)
    assert(calculator.add(1, 1) == 2)
  end

  test("can add negative numbers") do
    assert(calculator.add(-1, 2) == 1)
    assert(calculator.add(2, -2) == 0)
    assert(calculator.add(-1, -1) == -2)
  end

  test("can divide") do
    assert(calculator.div(8, 2) == 4)
    assert_raise { calculator.div(8, 0) }
    assert_no_raise { calculator.div(8, 1) }
  end
end

class SharedCalculatorTests
  def self.new(calculator)
    Proc.new do
      test("can add positive numbers") do
        assert(calculator.add(1, 2) == 3)
        assert(calculator.add(2, 2) == 4)
        assert(calculator.add(1, 1) == 2)
      end

      test("can add negative numbers") do
        assert(calculator.add(-1, 2) == 1)
        assert(calculator.add(2, -2) == 0)
        assert(calculator.add(-1, -1) == -2)
      end

      test("can divide") do
        assert(calculator.div(8, 2) == 4)
        assert_raise { calculator.div(8, 0) }
        assert_no_raise { calculator.div(8, 1) }
      end
    end
  end
end

calculator_test.run

configured_calc_test = TestSuite.new(
  "Calculator", &SharedCalculatorTests.new(Calculator.new)
)
configured_calc_test.run
