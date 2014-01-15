# Fluent::Plugin::InfluxDB

fluent-plugin-influxdb is a buffered output plugin for fluentd and influxDB.

If you are using fluentd as a collector and want to organize your time-series data in influxDB, this is your right choice!

## Installation

    $ fluent-gem install fluent-plugin-influxdb

## Usage

Just like other regular output plugins, Use type `influxdb` in your fluentd configuration under `match` scope:

`type` `influxdb`

--------------

**Options:**

`host`: The IP or domain of influxDB, default to "localhost"

`port`: The HTTP port of influxDB, default to 8086

`dbname`: The database name of influxDB, default to "fluentd". you should create the database and grant permissions first

`user`: The DB user of influxDB, should be created manually, default to "root"

`password`: The password of the user, default to "root"
    
`time_precision`: The time precision of timestamp. default to "s". should specify either second (s), millisecond (m), or microsecond (u)



## Configuration Example


```
<match mylog.*>
  type influxdb
  host  localhost
  port  8086
  dbname test
  user  testuser
  password  mypwd
  time_precision s
</match>
```

## Cache and multiprocess


fluentd-plugin-influxdb is a buffered output plugin. So additional buffer configuration would be (with default values):

```
buffer_type memory
flush_interval 60
retry_limit 17
retry_wait 1.0
num_threads 1
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
