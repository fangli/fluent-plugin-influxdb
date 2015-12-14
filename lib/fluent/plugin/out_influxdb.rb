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
  config_param :tag_keys, :array, :default => []
  config_param :sequence_tag, :string, :default => nil


  def initialize
    super
    @seq = 0
    @prev_timestamp = nil
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

  FORMATTED_RESULT_FOR_INVALID_RECORD = ''.freeze

  def format(tag, time, record)
    # TODO: Use tag based chunk separation for more reliability
    if record.empty? || record.has_value?(nil)
      FORMATTED_RESULT_FOR_INVALID_RECORD
    else
      [tag, time, record].to_msgpack
    end
  end

  def shutdown
    super
  end

  def write(chunk)
    points = []
    chunk.msgpack_each do |tag, time, record|
      timestamp = record.delete('time') || time
      if tag_keys.empty?
        values = record
        tags = {}
      else
        values = {}
        tags = {}
        record.each_pair do |k, v|
          if @tag_keys.include?(k)
            tags[k] = v
          else
            values[k] = v
          end
        end
      end
      if @sequence_tag
        if @prev_timestamp == timestamp
          @seq += 1
        else
          @seq = 0
        end
        tags[@sequence_tag] = @seq
        @prev_timestamp = timestamp
      end
      point = {
        :timestamp => timestamp,
        :series    => tag,
        :values    => values,
        :tags      => tags,
      }
      points << point
    end

    @influxdb.write_points(points)
  end
end
