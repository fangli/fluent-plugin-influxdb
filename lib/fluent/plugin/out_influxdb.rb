# encoding: UTF-8
require 'date'
require 'influxdb'

class Fluent::InfluxdbOutput < Fluent::BufferedOutput
  Fluent::Plugin.register_output('influxdb', self)

  config_param :host, :string,  :default => 'localhost'
  config_param :port, :integer,  :default => 8086
  config_param :dbname, :string,  :default => 'fluentd'
  config_param :user, :string,  :default => 'root'
  config_param :password, :string,  :default => 'root'
  config_param :time_precision, :string, :default => 's'


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
                                              time_precision: @time_precision
                                              
  end

  def start
    super
  end

  def format(tag, time, record)
    [tag, time, record].to_msgpack
  end

  def shutdown
    super
  end

  def write(chunk)
    chunk.msgpack_each do |tag, time, record|
      unless record.empty?
        record[:time] = time
        @influxdb.write_point(tag, record)
      end
    end
  end
end
