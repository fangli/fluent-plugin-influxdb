# encoding: UTF-8
require 'date'
require 'influxdb'

class Fluent::InfluxdbOutput < Fluent::BufferedOutput
  Fluent::Plugin.register_output('influxdb', self)

  include Fluent::HandleTagNameMixin

  config_param :host, :string,  :default => 'localhost',
               :desc => "The IP or domain of influxDB."
  config_param :port, :integer,  :default => 8086,
               :desc => "The HTTP port of influxDB."
  config_param :dbname, :string,  :default => 'fluentd',
               :desc => <<-DESC
The database name of influxDB.
You should create the database and grant permissions at first.
DESC
  config_param :user, :string,  :default => 'root',
               :desc => "The DB user of influxDB, should be created manually."
  config_param :password, :string,  :default => 'root', :secret => true,
               :desc => "The password of the user."
  config_param :time_key, :string, :default => 'time',
               :desc => 'Use value of this tag if it exists in event instead of event timestamp'
  config_param :time_precision, :string, :default => 's',
               :desc => <<-DESC
The time precision of timestamp.
You should specify either hour (h), minutes (m), second (s),
millisecond (ms), microsecond (u), or nanosecond (n).
DESC
  config_param :use_ssl, :bool, :default => false,
               :desc => "Use SSL when connecting to influxDB."
  config_param :verify_ssl, :bool, :default => true,
               :desc => "Enable/Disable SSL Certs verification when connecting to influxDB via SSL."
  config_param :tag_keys, :array, :default => [],
               :desc => "The names of the keys to use as influxDB tags."
  config_param :sequence_tag, :string, :default => nil,
               :desc => <<-DESC
The name of the tag whose value is incremented for the consecutive simultaneous
events and reset to zero for a new event with the different timestamp.
DESC


  def initialize
    super
    @seq = 0
    @prev_timestamp = nil
  end

  def configure(conf)
    super
  end

  def start
    super

    $log.info "Connecting to database: #{@dbname}, host: #{@host}, port: #{@port}, username: #{@user}, password = #{@password}, use_ssl = #{@use_ssl}, verify_ssl = #{@verify_ssl}"

    # ||= for testing.
    @influxdb ||= InfluxDB::Client.new @dbname, host: @host,
                                                port: @port,
                                                username: @user,
                                                password: @password,
                                                async: false,
                                                time_precision: @time_precision,
                                                use_ssl: @use_ssl,
                                                verify_ssl: @verify_ssl

    begin
      existing_databases = @influxdb.list_databases.map { |x| x['name'] }
      unless existing_databases.include? @dbname
        raise Fluent::ConfigError, 'Database ' + @dbname + ' doesn\'t exist. Create it first, please. Existing databases: ' + existing_databases.join(',')
      end
    rescue InfluxDB::AuthenticationError
      $log.info "skip database presence check because '#{@user}' user doesn't have admin privilege. Check '#{@dbname}' exists on influxdb"
    end
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
      timestamp = record.delete(@time_key).to_i || time
      if tag_keys.empty?
        values = record
        tags = {}
      else
        values = {}
        tags = {}
        record.each_pair do |k, v|
          if @tag_keys.include?(k)
            # If the tag value is not nil, empty, or a space, add the tag
            if v.to_s.strip != ''
              tags[k] = v
            end
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
