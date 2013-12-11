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
  config_param :value_field, :string, :default => '_value'
  config_param :time_precision, :string, :default => 's'


  def initialize
    super
  end

  def configure(conf)
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

      value = record[@value_field]
      record.delete(@value_field)

      bulk << {
        'name' => tag,
        'columns' => ['time', 'value'].concat(record.keys),
        'points' => [[time, value].concat(record.values)],
      }
    end

    http = Net::HTTP.new(@host, @port.to_i)
    request = Net::HTTP::Post.new("/db/#{@dbname}/series?u=#{@user}&p=#{password}&time_precision=#{time_precision}", {'content-type' => 'application/json; charset=utf-8'})
    request.body = Yajl::Encoder.encode(bulk)
    http.request(request).value
  end
end
