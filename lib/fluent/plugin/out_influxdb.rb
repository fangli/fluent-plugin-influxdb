# encoding: UTF-8
require 'date'
require 'influxdb'

class Fluent::InfluxdbOutput < Fluent::BufferedOutput
  Fluent::Plugin.register_output('influxdb', self)

  include Fluent::HandleTagNameMixin

  config_param :host, :string,  :default => 'localhost'
  config_param :port, :integer,  :default => 8086
  config_param :dbname, :string,  :default => 'fluentd'
  config_param :user, :string,  :default => 'root'
  config_param :password, :string,  :default => 'root', :secret => true
  config_param :time_precision, :string, :default => 's'
  config_param :use_ssl, :bool, :default => false


  def initialize
    super
  end

  def configure(conf)
    super
    @influxdb = InfluxDB::Client.new @dbname, host: @host,
                                              port: @port,
                                              username: @user,
                                              password: @password,
                                              async: false,
                                              time_precision: @time_precision,
                                              use_ssl: @use_ssl
  end

  def start
    super
  end

  def format(tag, time, record)
    # TODO: Use tag based chunk separation for more reliability
    [tag, time, record].to_msgpack
  end

  def shutdown
    super
  end

  def write(chunk)
    points = {}
    chunk.msgpack_each do |tag, time, record|
      unless record.empty?
        record[:time] = time unless record.has_key?('time')
        points[tag] ||= []
        points[tag] << record
      end
    end

    points.each { |tag, records|
      @influxdb.write_point(tag, records)
    }
  end
end
