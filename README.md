# Fluent::Plugin::InfluxDB, a plugin for [Fluentd](http://fluentd.org)

fluent-plugin-influxdb is a buffered output plugin for fluentd and influxDB.

If you are using fluentd as a collector and want to organize your time-series data in influxDB, this is your right choice!

## NOTE

This version uses influxdb-ruby version 0.2.0 which no longer supports InfluxDB version 0.8 (which is also deprecated).
If you are using InfluxDB version 0.8 please specify version 0.1.8 of this plugin.

## Requirements

| fluent-plugin-influxdb | fluentd | ruby |
|------------------------|---------|------|
| >= 1.0.0 | >= v0.14.0 | >= 2.1 |
|  < 1.0.0 | >= v0.12.0 | >= 1.9 |

NOTE: fluent-plugin-influxdb v1.0.0 is now RC. We will release stable v1.0.0 soon.

## Installation

    $ fluent-gem install fluent-plugin-influxdb -v "~> 0.3"  --no-document # for fluentd v0.12 or later
    $ fluent-gem install fluent-plugin-influxdb -v 1.0.0.rc1 --no-document # for fluentd v0.14 or later

### Ruby 2.0 or earlier

`influxdb` gem requires `cause` gem in Ruby 2.0 or earlier. If you want to use `fluent-plugin-influxdb` with Ruby 2.0 or earlier,
you should install `cause` gem before install `fluent-plugin-influxdb`.

We don't recommend to use Ruby 2.0 or earlier version because these are EOL.
If you don't have a problem, use ruby 2.1 or later in production.

## Usage

Just like other regular output plugins, Use type `influxdb` in your fluentd configuration under `match` scope:

`type` `influxdb`

--------------

**Options:**

`host`: The IP or domain of influxDB, separate with comma, default to "localhost"

`port`: The HTTP port of influxDB, default to 8086

`dbname`: The database name of influxDB, default to "fluentd". you should create the database and grant permissions first

`measurement`: The measurement/serise for record insertion. The default is nil.

`user`: The DB user of influxDB, should be created manually, default to "root"

`password`: The password of the user, default to "root"

`retry`: The finite number of retry times. default is infinite

`use_ssl`: Use SSL when connecting to influxDB. default to false

`verify_ssl`: Enable/Disable SSL Certs verification when connecting to influxDB via SSL. default to true

`time_key`: Use value of this tag if it exists in event instead of event timestamp

`time_precision`: The time precision of timestamp. default to "s". should specify either hour (h), minutes (m), second (s), millisecond (ms), microsecond (u), or nanosecond (ns)

`auto_tags`: Enable/Disable auto-tagging behaviour which makes strings tags.

`tag_keys`: The names of the keys to use as influxDB tags.

`sequence_tag`: The name of the tag whose value is incremented for the consecutive simultaneous events and reset to zero for a new event with the different timestamp

`default_retention_policy`: The retention policy applied by default.  influxdb >= 0.2.3 is required to use this functionality.

`retention_policy_key`: The name of the key in the record whose value specifies the retention policy.  The default retention policy will be applied if no such key exists.  influxdb >= 0.2.3 is required to use this functionality.

### Fluentd Tag and InfluxDB Series

influxdb plugin uses Fluentd event tag for InfluxDB series.
So if you have events with `app.event`, influxdb plugin inserts events into `app.event` series in InfluxDB.

If you set `measurement` parameter, use its value instead of event tag.

## Configuration Example

```
<match mylog.*>
  @type influxdb
  host  localhost
  port  8086
  dbname test
  user  testuser
  password  mypwd
  use_ssl false
  time_precision s
  tag_keys ["key1", "key2"]
  sequence_tag _seq
</match>
```

## Cache and multiprocess


fluentd-plugin-influxdb is a buffered output plugin. So additional buffer configuration would be (with default values):

```
buffer_type memory
buffer_chunk_limit 524288 # 512 * 1024
buffer_queue_limit 1024
flush_interval 60
retry_limit 17
retry_wait 1.0
num_threads 1
```

The details of BufferedOutput is [here](http://docs.fluentd.org/articles/buffer-plugin-overview).

---

fluentd-plugin-influxdb also includes the HandleTagNameMixin mixin which allows the following additional options:

```
remove_tag_prefix <tag_prefix_to_remove_including_the_dot>
remove_tag_suffix <tag_suffix_to_remove_including_the_dot>
add_tag_prefix <tag_prefix_to_add_including_the_dot>
add_tag_suffix <tag_suffix_to_add_including_the_dot>
```

---

Also please consider using [fluent-plugin-multiprocess](https://github.com/frsyuki/fluent-plugin-multiprocess) to fork multiple threads for your metrics:

## Contributing


1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request


## Licence


This package was distributed under MIT licence, see LICENCE file for details.

This plugin was written by Fang.Li and was inspired by [Uken's](https://github.com/uken/fluent-plugin-elasticsearch) elasticsearch plugin.
