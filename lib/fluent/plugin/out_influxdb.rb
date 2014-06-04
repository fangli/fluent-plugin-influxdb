# encoding: UTF-8

class Fluent::InfluxdbOutput < Fluent::BufferedOutput
  Fluent::Plugin.register_output('influxdb', self)

  include Fluent::SetTimeKeyMixin
  config_set_default :include_time_key, false

  config_set_default :influx_time_key, 'time'

  config_param :time_key, :string, :default => 'time'
  config_param :host, :string,  :default => 'localhost'
  config_param :port, :integer,  :default => 8086
  config_param :dbname, :string,  :default => 'fluentd'
  config_param :user, :string,  :default => 'root'
  config_param :password, :string,  :default => 'root'
  config_param :time_precision, :string, :default => 's'
  config_param :time_zone, :string, :default => ''


  def initialize
    super
    require 'date'
    require 'tzinfo'
    require 'net/http'
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
      record_time = record[@time_key]
      record_time = DateTime.parse(record_time) if record_time && record_time.is_a?(String)

      if time_zone && time_zone != ""
        tz = TZInfo::Timezone.get(time_zone)

        period = tz.period_for_utc(record_time)
        rational_offset = period.utc_total_offset_rational

        record_time = tz.utc_to_local(record_time).new_offset(rational_offset) -
          period.utc_total_offset_rational
      end
      record_time = Time.at(time || record_time) if @include_time_key
      record[@time_key] = record_time.strftime("%s").to_f if record_time

      # The `time` field type should be a float type
      if @time_key == @influx_time_key
        record[@time_key] = time unless record.has_key?(@time_key)
      else
        record[@include_time_key] = record_time.strftime("%s").to_f if record_time
        record[@include_time_key] ||= time
      end

      bulk << {
        'name' => tag,
        'columns' => record.keys,
        'points' => [record.values],
      }
    end

    http = Net::HTTP.new(@host, @port.to_i)
    request = Net::HTTP::Post.new("/db/#{@dbname}/series?u=#{@user}&p=#{password}&time_precision=#{time_precision}", {'content-type' => 'application/json; charset=utf-8'})
    request.body = Yajl::Encoder.encode(bulk)
    http.request(request).value
  end
end
