require 'helper'

class InfluxdbOutputTest < Test::Unit::TestCase
  class DummyInfluxDBClient
    attr_reader :points

    def initialize
      @points = []
    end

    def list_databases
      [{'name' => 'test'}]
    end

    def stop!
    end

    def write_points(points, precision=nil, retention_policy=nil)
      @points << [points, precision, retention_policy]
    end
  end

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
      attr_reader :influxdb
      def configure(conf)
        @influxdb = DummyInfluxDBClient.new()
        super
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

    assert_equal([
      [
        [
          {
            :timestamp => time,
            :series    => 'input.influxdb',
            :tags      => {},
            :values    => {'a' => 1}
          },
          {
            :timestamp => time,
            :series    => 'input.influxdb',
            :tags      => {},
            :values    => {'a' => 2}
          },
        ],
        nil,
        nil
      ]
    ], driver.instance.influxdb.points)

  end

  def test_empty_tag_keys
    config_with_tags = %Q(
      #{CONFIG}

      tag_keys ["b"]
    )

    driver = create_driver(config_with_tags, 'input.influxdb')

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    driver.emit({'a' => 1, 'b' => ''}, time)
    driver.emit({'a' => 2, 'b' => 1}, time)
    driver.emit({'a' => 3, 'b' => ' '}, time)

    data = driver.run

    assert_equal([
      [
        [
          {
            :timestamp => time,
            :series    => 'input.influxdb',
            :values    => {'a' => 1},
            :tags      => {},
          },
          {
            :timestamp => time,
            :series    => 'input.influxdb',
            :values    => {'a' => 2},
            :tags      => {'b' => 1},
          },
          {
            :timestamp => time,
            :series    => 'input.influxdb',
            :values    => {'a' => 3},
            :tags      => {},
          },
        ],
        nil,
        nil
      ]
    ], driver.instance.influxdb.points)
  end

  def test_seq
    config = %[
      type influxdb
      host  localhost
      port  8086
      dbname test
      user  testuser
      password  mypwd
      use_ssl false
      time_precision s 
      sequence_tag _seq
    ]
    driver = create_driver(config, 'input.influxdb')

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    driver.emit({'a' => 1}, time)
    driver.emit({'a' => 2}, time)

    driver.emit({'a' => 1}, time + 1)
    driver.emit({'a' => 2}, time + 1)

    data = driver.run

    assert_equal([
      [
        [
          {
            :timestamp => time,
            :series    => 'input.influxdb',
            :values    => {'a' => 1},
            :tags      => {'_seq' => 0},
          },
          {
            :timestamp => time,
            :series    => 'input.influxdb',
            :values    => {'a' => 2},
            :tags      => {'_seq' => 1},
          },
          {
            :timestamp => time + 1,
            :series    => 'input.influxdb',
            :values    => {'a' => 1},
            :tags      => {'_seq' => 0},
          },
          {
            :timestamp => time + 1,
            :series    => 'input.influxdb',
            :values    => {'a' => 2},
            :tags      => {'_seq' => 1},
          }
        ],
        nil,
        nil
      ]
    ], driver.instance.influxdb.points)

  end

  def test_write_default_retention_policy_only
    config = CONFIG + "\n" + %[
      default_retention_policy ephemeral_1d
    ]
    driver = create_driver(config, 'input.influxdb')

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    driver.emit({'a' => 1}, time)
    driver.emit({'a' => 2}, time)

    data = driver.run

    assert_equal([
      [
        [
          {
            :timestamp => time,
            :series    => 'input.influxdb',
            :tags      => {},
            :values    => {'a' => 1}
          },
          {
            :timestamp => time,
            :series    => 'input.influxdb',
            :tags      => {},
            :values    => {'a' => 2}
          },
        ],
        nil,
        'ephemeral_1d'
      ]
    ], driver.instance.influxdb.points)

  end

  def test_write_respective_retention_policy
    config = CONFIG + "\n" + %[
      retention_policy_key rp
    ]
    driver = create_driver(config, 'input.influxdb')

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    driver.emit({'a' => 1}, time)
    driver.emit({'a' => 2, 'rp' => 'ephemeral_1d'}, time)
    driver.emit({'a' => 3, 'rp' => 'ephemeral_1m'}, time)

    data = driver.run

    assert_equal([
      [
        [
          {
            :timestamp => time,
            :series    => 'input.influxdb',
            :tags      => {},
            :values    => {'a' => 1},
          }
        ],
        nil,
        nil
      ],
      [
        [
          {
            :timestamp => time,
            :series    => 'input.influxdb',
            :tags      => {},
            :values    => {'a' => 2},
          }
        ],
        nil,
        'ephemeral_1d'
      ],
      [
        [
          {
            :timestamp => time,
            :series    => 'input.influxdb',
            :tags      => {},
            :values    => {'a' => 3},
          }
        ],
        nil,
        'ephemeral_1m'
      ]
    ], driver.instance.influxdb.points)

  end

  def test_write_combined_retention_policy
    config = CONFIG + "\n" + %[
      default_retention_policy ephemeral_1d
      retention_policy_key rp
    ]
    driver = create_driver(config, 'input.influxdb')

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    driver.emit({'a' => 1}, time)
    driver.emit({'a' => 2, 'rp' => 'ephemeral_1d'}, time)
    driver.emit({'a' => 3, 'rp' => 'ephemeral_1m'}, time)

    data = driver.run

    assert_equal([
      [
        [
          {
            :timestamp => time,
            :series    => 'input.influxdb',
            :tags      => {},
            :values    => {'a' => 1},
          },
          {
            :timestamp => time,
            :series    => 'input.influxdb',
            :tags      => {},
            :values    => {'a' => 2},
          }
        ],
        nil,
        'ephemeral_1d'
      ],
      [
        [
          {
            :timestamp => time,
            :series    => 'input.influxdb',
            :tags      => {},
            :values    => {'a' => 3},
          }
        ],
        nil,
        'ephemeral_1m'
      ]
    ], driver.instance.influxdb.points)

  end
end
