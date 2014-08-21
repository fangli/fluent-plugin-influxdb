# encoding: UTF-8
require 'date'
require 'net/http'

class Fluent::InfluxdbOutput < Fluent::BufferedOutput
  Fluent::Plugin.register_output('influxdb', self)

  config_param :host, :string,  :default => 'localhost'
  config_param :port, :integer,  :default => 8086
  config_param :dbname, :string,  :default => 'fluentd'
  config_param :user, :string,  :default => 'root'
  config_param :password, :string,  :default => 'root'
  config_param :time_precision, :string, :default => 's'
  config_param :request_timeout, :integer, :default => 60
  config_set_default :buffer_chunk_limit, :integer, :default => 512 * 1024

  def initialize
    super
  end

  def configure(conf)
    if !conf['buffer_type'] || conf['buffer_type'] == 'memory'
      conf['buffer_queue_limit'] ||= 1024
    else
      conf['buffer_queue_limit'] ||= 4096
    end

    super
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
    bulk = []

    chunk.msgpack_each do |tag, time, record|
      bulk << {
        'name' => tag,
        'columns' => record.keys << 'time',
        'points' => [record.values << time],
      }
    end

    http = Net::HTTP.new(@host, @port.to_i)
    http.read_timeout = @request_timeout
    request = Net::HTTP::Post.new("/db/#{@dbname}/series?u=#{@user}&p=#{password}&time_precision=#{time_precision}", {'content-type' => 'application/json; charset=utf-8'})
    request.body = Yajl::Encoder.encode(bulk)
    http.request(request).value
  end
end
