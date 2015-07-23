require 'helper'
class InfluxdbOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    type influxdb
    host  localhost
    port  8086
    dbname test
    user  testuser
    password  mypwd
    use_ssl false
    time_precision s
  ]

  def create_raw_driver(conf=CONFIG, tag='test')
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::InfluxdbOutput, tag).configure(conf)
  end

  def create_driver(conf=CONFIG, tag='test')
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::InfluxdbOutput, tag) do
      def write(chunk)
        chunk.read
      end
    end.configure(conf)
  end

  def test_configure
    driver = create_raw_driver %[
      dbname test
      user  testuser
      password  mypwd
    ]
    assert_equal('test', driver.instance.config['dbname'])
    assert_equal('testuser', driver.instance.config['user'])
    assert_equal('xxxxxx', driver.instance.config['password'])
  end

  def test_format
    driver = create_driver(CONFIG, 'test')
    time = Time.parse('2011-01-02 13:14:15 UTC').to_i

    driver.emit({'a' => 1}, time)
    driver.emit({'a' => 2}, time)

    driver.expect_format(['test', time, {'a' => 1}].to_msgpack)
    driver.expect_format(['test', time, {'a' => 2}].to_msgpack)

    driver.run
  end

  def test_write
    driver = create_driver(CONFIG, 'input.influxdb')

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    driver.emit({'a' => 1}, time)
    driver.emit({'a' => 2}, time)

    data = driver.run

    assert_equal(['input.influxdb', time, {'a' => 1}].to_msgpack +
                 ['input.influxdb', time, {'a' => 2}].to_msgpack, data)
  end
end
