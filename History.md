Changelog
=========

0.3.1 (Jan, 07, 2017)
=====

- Add auto_tags parameter

0.3.0 (Dec, 15, 2016)
=====

- Skip events which contains only tags
- Fix error handling for v1.0 client
- Adjust timestamp based on precision

0.2.8 (July, 06, 2016)
=====

- Accept comma-separated multiple hosts in host parameter

0.2.7 (May, 10, 2016)
=====

- Add default_retention_policy and retention_policy parameters

0.2.6 (Apr, 22, 2016)
=====

- Add time_key parameter
- Add retry parameter
- Skip database check when user doesn't have right permission

0.2.5 (Apr, 19, 2016)
=====

- Ignore blank tag value
- Improve the configuration verificaiton

0.2.4 (Apr, 11, 2016)
=====

- Add verify_ssl option

0.2.3 (Feb, 27, 2016)
=====

- Add sequence_tag option
- Add parameter descriptions

0.2.2 (Nov, 02, 2015)
=====

- Ignore event when field has null

0.2.1 (July, 31, 2015)
=====

- Add tag_keys parameter to support influxdb tags

0.2.0 (July, 27, 2015)
=====

- Use influxdb gem 0.2.0 for influxdb 0.9 support

0.1.8 (July, 12, 2015)
=====

- Force to use influxdb gem v0.1.x

0.1.7 (Jun, 9, 2015)
=====

- Keep original time field if present

0.1.6 (May 30, 2015)
=====

- Fix wrong require

0.1.5 (May 29, 2015)
=====

- Improve write performance
- Add the ability to handle a tag

0.1.4 (Apr 8, 2015)
=====

- influxdb gem should be runtime dependency
- Add use_ssl option

0.1.3 (Apr 3, 2015)
=====

- Use influxdb gem to write data
- Ignore empty record to avoid client exception

0.1.2
=====

- Remove value recognize from configuration

0.1.0
=====

- Initial gem release.
