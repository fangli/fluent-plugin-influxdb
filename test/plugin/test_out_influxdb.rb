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

  class DummyInfluxdbOutput < Fluent::Plugin::InfluxdbOutput
    attr_reader :influxdb
    def configure(conf)
      @influxdb = DummyInfluxDBClient.new()
      super
    end

    def write(chunk)
      super
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

  def create_raw_driver(conf=CONFIG)
    Fluent::Test::Driver::Output.new(Fluent::Plugin::InfluxdbOutput).configure(conf)
  end

  def create_driver(conf=CONFIG)
    Fluent::Test::Driver::Output.new(DummyInfluxdbOutput).configure(conf)
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

  sub_test_case "#write" do
    data("w/ arg" => ["
           <buffer tag>
             @type memory
           </buffer>
         ",'input.influxdb'],
        "default" => ["", nil])
    test "buffer" do |data|
      buffer_config, series = data
      driver = create_driver(CONFIG + "\n" + %[
        #{buffer_config}
      ])

      time = event_time("2011-01-02 13:14:15 UTC")
      driver.run(default_tag: 'input.influxdb') do
        driver.feed(time, {'a' => 1})
        driver.feed(time, {'a' => 2})
      end

      assert_equal([
        [
          [
            {
              :timestamp => time,
              :series    => series,
              :tags      => {},
              :values    => {'a' => 1}
            },
            {
              :timestamp => time,
              :series    => series,
              :tags      => {},
              :values    => {'a' => 2}
            },
          ],
          nil,
          nil
        ]
      ], driver.instance.influxdb.points)
    end
  end

  def test_write_with_measurement
    config_with_measurement = %Q(
      #{CONFIG}
      measurement test
    )

    driver = create_driver(config_with_measurement)

    time = event_time('2011-01-02 13:14:15 UTC')
    driver.run(default_tag: 'input.influxdb') do
      driver.feed(time, {'a' => 1})
      driver.feed(time, {'a' => 2})
    end

    assert_equal([
      [
        [
          {
            :timestamp => time,
            :series    => 'test',
            :tags      => {},
            :values    => {'a' => 1}
          },
          {
            :timestamp => time,
            :series    => 'test',
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
      <buffer tag>
        @type memory
      </buffer>
    )

    driver = create_driver(config_with_tags)

    time = event_time("2011-01-02 13:14:15 UTC")
    driver.run(default_tag: 'input.influxdb') do
      driver.feed(time, {'a' => 1, 'b' => ''})
      driver.feed(time, {'a' => 2, 'b' => 1})
      driver.feed(time, {'a' => 3, 'b' => ' '})
    end

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

  def test_auto_tagging
    config_with_tags = %Q(
      #{CONFIG}

      auto_tags true
    )

    driver = create_driver(config_with_tags)

    time = event_time("2011-01-02 13:14:15 UTC")
    driver.run(default_tag: 'input.influxdb') do
      driver.feed(time, {'a' => 1, 'b' => '1'})
      driver.feed(time, {'a' => 2, 'b' => 1})
      driver.feed(time, {'a' => 3, 'b' => ' '})
    end

    assert_equal([
      [
        [
          {
            :timestamp => time,
            :series    => 'input.influxdb',

            :values    => {'a' => 1},
            :tags      => {'b' => '1'},
          },
          {
            :timestamp => time,
            :series    => 'input.influxdb',
            :values    => {'a' => 2, 'b' => 1},
            :tags      => {},
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

  def test_ignore_empty_values
    config_with_tags = %Q(
      #{CONFIG}

      tag_keys ["b"]
    )

    driver = create_driver(config_with_tags)

    time = event_time('2011-01-02 13:14:15 UTC')
    driver.run(default_tag: 'input.influxdb') do
      driver.feed(time, {'b' => '3'})
      driver.feed(time, {'a' => 2, 'b' => 1})
    end

    assert_equal([
      [
        [
          {
            :timestamp => time,
            :series    => 'input.influxdb',

            :values    => {'a' => 2},
            :tags      => {'b' => 1},
          }
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
      <buffer tag>
        @type memory
      </buffer>
    ]
    driver = create_driver(config)

    time = event_time("2011-01-02 13:14:15 UTC")
    driver.run(default_tag: 'input.influxdb') do
      driver.feed(time, {'a' => 1})
      driver.feed(time, {'a' => 2})

      driver.feed(time + 1, {'a' => 1})
      driver.feed(time + 1, {'a' => 2})
    end

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
            :timestamp => time2,
            :series    => 'input.influxdb',
            :values    => {'a' => 1},
            :tags      => {'_seq' => 0},
          },
          {
            :timestamp => time2,
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
      <buffer tag>
        @type memory
      </buffer>
    ]
    driver = create_driver(config)

    time = event_time("2011-01-02 13:14:15 UTC")
    driver.run(default_tag: 'input.influxdb') do
      driver.feed(time, {'a' => 1})
      driver.feed(time, {'a' => 2})
    end

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
      <buffer tag>
        @type memory
      </buffer>
    ]
    driver = create_driver(config)

    time = event_time("2011-01-02 13:14:15 UTC")
    driver.run(default_tag: 'input.influxdb') do
      driver.feed(time, {'a' => 1})
      driver.feed(time, {'a' => 2, 'rp' => 'ephemeral_1d'})
      driver.feed(time, {'a' => 3, 'rp' => 'ephemeral_1m'})
    end

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
      <buffer tag>
        @type memory
      </buffer>
    ]
    driver = create_driver(config)

    time = event_time("2011-01-02 13:14:15 UTC")
    driver.run(default_tag: 'input.influxdb') do
      driver.feed(time, {'a' => 1})
      driver.feed(time, {'a' => 2, 'rp' => 'ephemeral_1d'})
      driver.feed(time, {'a' => 3, 'rp' => 'ephemeral_1m'})
      driver.feed(time, {'a' => 4})
    end

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
      ],
      [
        [
          {
            :timestamp => time,
            :series    => 'input.influxdb',
            :tags      => {},
            :values    => {'a' => 4},
          }
        ],
        nil,
        'ephemeral_1d'
      ]
    ], driver.instance.influxdb.points)

  end
end
