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
  config_param :remove_keys, :string, :default => nil
  config_param :keep_keys, :string, :default => nil
  config_param :renew_record, :bool, :default => false


  def initialize
    super
  end

  def configure(conf)
    super
    @placeholder_expander = PlaceholderExpander.new({
      :log           => log,
      :auto_typecast => @auto_typecast,
    })
    @maped_opts = {
      'dbname' => @dbname,
      'host' => @host,
      'port' => @port,
      'username' => @user,
      'password' => @password,
      'async' => false,
      'time_precision' => @time_precision,
      'use_ssl' => @use_ssl
    }
    @influxdb = {}
    if @remove_keys
      @remove_keys = @remove_keys.split(',')
    end

    if @keep_keys
      raise Fluent::ConfigError, "`renew_record` must be true to use `keep_keys`" unless @renew_record
      @keep_keys = @keep_keys.split(',')
    end
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
    data = {}
    chunk.msgpack_each do |tag, time, record|
      unless record.empty?
        tag_parts = tag.split('.')
        tag_prefix = tag_prefix(tag_parts)
        tag_suffix = tag_suffix(tag_parts)
        tags = {
          'tag' => tag,
          'tag_parts' => tag_parts,
          'tag_prefix' => tag_prefix,
          'tag_suffix' => tag_suffix,
          'hostname' => @hostname,
        }
        @placeholder_expander.prepare_placeholders(time, record, tags)
        opts = expand_placeholders(@maped_opts)
        db = get_db(opts)
        unless data.has_key?(db)
          data[db] = []
        end
        point = {}
        point[:timestamp] = record.delete('time') || time
        point[:series] = tag
        point[:values] = reform(record)
        data[db] << point
      end
    end
    data.each do |key, points|
      @influxdb[key].write_points(points)
    end
  end

  def get_db(opts)
    db = "#{opts['host']}:#{opts['port']}|#{opts['dbname']}|#{opts['username']}|#{opts['password']}"
    @influxdb = {} unless @influxdb
    unless @influxdb.has_key?(db)
      @influxdb[db] = InfluxDB::Client.new opts['dbname'], host: opts['host'],
                                                           port: opts['port'],
                                                           username: opts['user'],
                                                           password: opts['password'],
                                                           async: false,
                                                           time_precision: @time_precision,
                                                           use_ssl: @use_ssl
    end
    return db
  end

  # Based on filter_http_record_modifier that was based on filter_http_record_modifier
  def reform(record)
    new_record = @renew_record ? {} : record.dup
    @keep_keys.each {|k| new_record[k] = record[k]} if @keep_keys and @renew_record
    @remove_keys.each {|k| new_record.delete(k) } if @remove_keys

    new_record
  end

  def expand_placeholders(value)
    if value.is_a?(String)
      new_value = @placeholder_expander.expand(value)
    elsif value.is_a?(Hash)
      new_value = {}
      value.each_pair do |k, v|
        new_value[@placeholder_expander.expand(k, true)] = expand_placeholders(v)
      end
    elsif value.is_a?(Array)
      new_value = []
      value.each_with_index do |v, i|
        new_value[i] = expand_placeholders(v)
      end
    else
      new_value = value
    end
    new_value
  end

  def tag_prefix(tag_parts)
    return [] if tag_parts.empty?
    tag_prefix = [tag_parts.first]
    1.upto(tag_parts.size-1).each do |i|
      tag_prefix[i] = "#{tag_prefix[i-1]}.#{tag_parts[i]}"
    end
    tag_prefix
  end

  def tag_suffix(tag_parts)
    return [] if tag_parts.empty?
    rev_tag_parts = tag_parts.reverse
    rev_tag_suffix = [rev_tag_parts.first]
    1.upto(tag_parts.size-1).each do |i|
      rev_tag_suffix[i] = "#{rev_tag_parts[i]}.#{rev_tag_suffix[i-1]}"
    end
    rev_tag_suffix.reverse!
  end

  class PlaceholderExpander
    attr_reader :placeholders, :log

    def initialize(params)
      @log = params[:log]
      @auto_typecast = params[:auto_typecast]
    end

    def prepare_placeholders(time, options, tags)
      placeholders = { '${time}' => Time.at(time).to_s }
      options.each {|key, value| crawl_placeholder(value, placeholders, "#{key}")}

      tags.each do |key, value|
        if value.kind_of?(Array) # tag_parts, etc
          size = value.size
          value.each_with_index { |v, idx|
            placeholders.store("${#{key}[#{idx}]}", v)
            placeholders.store("${#{key}[#{idx-size}]}", v) # support [-1]
          }
        else # string, interger, float, and others?
          placeholders.store("${#{key}}", value)
        end
      end

      @placeholders = placeholders
    end

    def crawl_placeholder (value, placeholder, before, limit = 50)
      if limit >= 0
        if value.kind_of?(Hash) 
          value.each {|key, v| crawl_placeholder(v, placeholder, "#{before}.#{key}", limit - 1)}
        elsif value.kind_of?(Array) # tag_parts, etc
          size = value.size
          value.each_with_index { |v, idx|
            crawl_placeholder(v, placeholder, "#{before}[#{idx}]", limit - 1)
            crawl_placeholder(v, placeholder, "#{before}[#{idx-size}]", limit - 1) #suport [-1]
          }
        end
      end
      # string, interger, float, and others?
      placeholder.store("${#{before}}", value)
    end

    def expand(str, force_stringify=false)
      if @auto_typecast and !force_stringify
        single_placeholder_matched = str.match(/\A(\${[^}]+}|__[A-Z_]+__)\z/)
        if single_placeholder_matched
          log_unknown_placeholder($1)
          return @placeholders[single_placeholder_matched[1]]
        end
      end
      str.gsub(/(\${[^}]+}|__[A-Z_]+__)/) {
        log_unknown_placeholder($1)
        @placeholders[$1]
      }
    end

    private
    def log_unknown_placeholder(placeholder)
      unless @placeholders.include?(placeholder)
        log.warn "unknown placeholder `#{placeholder}` found"
      end
    end
  end
end

