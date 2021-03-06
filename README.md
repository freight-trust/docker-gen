# docker-gen

![latest 0.8.3](https://img.shields.io/badge/latest-0.8.3-green.svg?style=flat)
[![Travis CI](https://travis-ci.org/bugficks/docker-gen.svg?branch=master)](https://travis-ci.org/github/bugficks/docker-gen)
[![CircleCI](https://circleci.com/gh/bugficks/docker-gen.svg?style=svg)](https://circleci.com/gh/bugficks/docker-gen)
![License MIT](https://img.shields.io/badge/license-MIT-blue.svg?style=flat)

`docker-gen` is a file generator that renders templates using docker container
meta-data.

It can be used to generate various kinds of files for:

- **Centralized logging** -
  [fluentd](https://github.com/bugficks/docker-gen/blob/master/templates/fluentd.conf.tmpl),
  logstash or other centralized logging tools that tail the containers JSON log
  file or files within the container.
- **Log Rotation** -
  [logrotate](https://github.com/bugficks/docker-gen/blob/master/templates/logrotate.tmpl)
  files to rotate container JSON log files
- **Reverse Proxy Configs** -
  [nginx](https://github.com/bugficks/docker-gen/blob/master/templates/nginx.tmpl),
  [haproxy](https://github.com/jwilder/docker-discover), etc. reverse proxy
  configs to route requests from the host to containers
- **Service Discovery** - Scripts (python, bash, etc..) to register containers
  within [etcd](https://github.com/jwilder/docker-register), hipache, etc..

===

### Installation

There are three common ways to run docker-gen:

- on the host
- bundled in a container with another application
- separate standalone containers

#### Host Install

Linux/OSX binaries for
[release](https://github.com/bugficks/docker-gen/releases)

Download the version you need, untar, and install to your PATH.

```
$ wget https://github.com/bugficks/docker-gen/releases/download/VERSION/docker-gen-linux-amd64-VERSION.tar.gz
$ tar xvzf docker-gen-linux-amd64-VERSION.tar.gz
$ ./docker-gen
```

#### Bundled Container Install

Docker-gen can be bundled inside of a container along-side applications.

[jwilder/nginx-proxy](https://index.docker.io/u/jwilder/nginx-proxy/) trusted
build is an example of running docker-gen within a container along-side nginx.
[jwilder/docker-register](https://github.com/jwilder/docker-register) is an
example of running docker-gen within a container to do service registration with
etcd.

#### Separate Container Install

It can also be run as two separate containers using the
[joellinn/docker-gen](https://index.docker.io/u/joellinn/docker-gen/) image,
together with virtually any other image.

This is how you could run the official
[nginx](https://registry.hub.docker.com/_/nginx/) image and have docker-gen
generate a reverse proxy config in the same way that `nginx-proxy` works. You
may want to do this to prevent having the docker socket bound to a publicly
exposed container service.

Start nginx with a shared volume:

```
$ docker run -d -p 80:80 --name nginx -v /tmp/nginx:/etc/nginx/conf.d -t nginx
```

Fetch the template and start the docker-gen container with the shared volume:

```
$ mkdir -p /tmp/templates && cd /tmp/templates
$ curl -o nginx.tmpl https://raw.githubusercontent.com/joellinn/docker-gen/master/templates/nginx.tmpl
$ docker run -d --name nginx-gen --volumes-from nginx \
   -v /var/run/docker.sock:/tmp/docker.sock:ro \
   -v /tmp/templates:/etc/docker-gen/templates \
   -t joellinn/docker-gen -notify-sighup nginx -watch -only-exposed /etc/docker-gen/templates/nginx.tmpl /etc/nginx/conf.d/default.conf
```

===

### Usage

```
$ docker-gen
Usage: docker-gen [options] template [dest]

Generate files from docker container meta-data

Options:
  -config value
      config files with template directives. Config files will be merged if this option is specified multiple times. (default [])
  -endpoint string
      docker api endpoint (tcp|unix://..). Default unix:///var/run/docker.sock
  -interval int
      notify command interval (secs)
  -keep-blank-lines
      keep blank lines in the output file
  -notify restart xyz
      run command after template is regenerated (e.g restart xyz)
  -notify-output
      log the output(stdout/stderr) of notify command
  -notify-container container-ID
      container to send a signal to
  -notify-signal signal
      signal to send to the -notify-container. -1 to call docker restart. Defaults to 1 aka. HUP.
      All available signals available on the [dockerclient](https://github.com/fsouza/go-dockerclient/blob/01804dec8a84d0a77e63611f2b62d33e9bb2b64a/signal.go)
  -notify-sighup container-ID
      send HUP signal to container.  Equivalent to 'docker kill -s HUP container-ID' or `-notify-container container-ID -notify-signal 1`
  -only-exposed
      only include containers with exposed ports
  -only-published
      only include containers with published ports (implies -only-exposed)
  -include-stopped
      include stopped containers
  -tlscacert string
      path to TLS CA certificate file (default "/Users/jason/.docker/machine/machines/default/ca.pem")
  -tlscert string
      path to TLS client certificate file (default "/Users/jason/.docker/machine/machines/default/cert.pem")
  -tlskey string
      path to TLS client key file (default "/Users/jason/.docker/machine/machines/default/key.pem")
  -tlsverify
      verify docker daemon's TLS certicate (default true)
  -version
      show version
  -watch
      watch for container changes
  -wait
      minimum (and/or maximum) duration to wait after each container change before triggering

Arguments:
  template - path to a template to generate
  dest - path to a write the template. If not specfied, STDOUT is used

Environment Variables:
  DOCKER_HOST - default value for -endpoint
  DOCKER_CERT_PATH - directory path containing key.pem, cert.pm and ca.pem
  DOCKER_TLS_VERIFY - enable client TLS verification]
```

If no `<dest>` file is specified, the output is sent to stdout. Mainly useful
for debugging.

### Configuration file

Using the -config flag from above you can tell docker-gen to use the specified
config file instead of command-line options. Multiple templates can be defined
and they will be executed in the order that they appear in the config file.

An example configuration file, **docker-gen.cfg** can be found in the examples
folder.

#### Configuration File Syntax

```
[[config]]
Starts a configuration section

dest = "path/to/a/file"
path to a write the template. If not specfied, STDOUT is used

notifycmd = "/etc/init.d/foo reload"
run command after template is regenerated (e.g restart xyz)

onlyexposed = true
only include containers with exposed ports

template = "/path/to/a/template/file.tmpl"
path to a template to generate

watch = true
watch for container changes

wait = "500ms:2s"
debounce changes with a min:max duration. Only applicable if watch = true


[config.NotifyContainers]
Starts a notify container section

containername = 1
container name followed by the signal to send

container_id = 1
or the container id can be used followed by the signal to send
```

Putting it all together here is an example configuration file.

```
[[config]]
template = "/etc/nginx/nginx.conf.tmpl"
dest = "/etc/nginx/sites-available/default"
onlyexposed = true
notifycmd = "/etc/init.d/nginx reload"

[[config]]
template = "/etc/logrotate.conf.tmpl"
dest = "/etc/logrotate.d/docker"
watch = true

[[config]]
template = "/etc/docker-gen/templates/nginx.tmpl"
dest = "/etc/nginx/conf.d/default.conf"
watch = true
wait = "500ms:2s"

[config.NotifyContainers]
nginx = 1  # 1 is a signal number to be sent; here SIGHUP
e75a60548dc9 = 1  # a key can be either container name (nginx) or ID
```

===

### Templating

The templates used by docker-gen are written using the Go
[text/template](http://golang.org/pkg/text/template/) language. In addition to
the [built-in functions](http://golang.org/pkg/text/template/#hdr-Functions)
supplied by Go, docker-gen provides a number of additional functions to make it
simpler (or possible) to generate your desired output.

#### Emit Structure

Within the templates, the object emitted by docker-gen will be a structure
consisting of following Go structs:

```go
type RuntimeContainer struct {
    ID           string
    Addresses    []Address
    Networks     []Network
    Gateway      string
    Name         string
    Hostname     string
    Image        DockerImage
    Env          map[string]string
    Volumes      map[string]Volume
    Node         SwarmNode
    Labels       map[string]string
    IP           string
    IP6LinkLocal string
    IP6Global    string
    Mounts       []Mount
    State        State
}

type Address struct {
    IP           string
    IP6LinkLocal string
    IP6Global    string
    Port         string
    HostPort     string
    Proto        string
    HostIP       string
}

type Network struct {
    IP                  string
    Name                string
    Gateway             string
    EndpointID          string
    IPv6Gateway         string
    GlobalIPv6Address   string
    MacAddress          string
    GlobalIPv6PrefixLen int
    IPPrefixLen         int
}

type DockerImage struct {
    Registry   string
    Repository string
    Tag        string
}

type Mount struct {
  Name        string
  Source      string
  Destination string
  Driver      string
  Mode        string
  RW          bool
}

type Volume struct {
    Path      string
    HostPath  string
    ReadWrite bool
}

type SwarmNode struct {
    ID      string
    Name    string
    Address Address
}

type State struct {
  Running bool
}

// Accessible from the root in templates as .Docker
type Docker struct {
    Name                 string
    NumContainers        int
    NumImages            int
    Version              string
    ApiVersion           string
    GoVersion            string
    OperatingSystem      string
    Architecture         string
    CurrentContainerID   string
}

// Host environment variables accessible from root in templates as .Env

```

For example, this is a JSON version of an emitted RuntimeContainer struct:

```json
{
  "ID": "71e9768075836eb38557adcfc71a207386a0c597dbeda240cf905df79b18cebf",
  "Addresses": [
    {
      "IP": "172.17.0.4",
      "Port": "22",
      "Proto": "tcp",
      "HostIP": "192.168.10.24",
      "HostPort": "2222"
    }
  ],
  "Gateway": "172.17.42.1",
  "Node": {
    "ID": "I2VY:P7PF:TZD5:PGWB:QTI7:QDSP:C5UD:DYKR:XKKK:TRG2:M2BL:DFUN",
    "Name": "docker-test",
    "Address": {
      "IP": "192.168.10.24"
    }
  },
  "Labels": {
    "operatingsystem": "Ubuntu 14.04.2 LTS",
    "storagedriver": "devicemapper",
    "anything_foo": "something_bar"
  },
  "IP": "172.17.0.4",
  "Name": "docker_register",
  "Hostname": "71e976807583",
  "Image": {
    "Registry": "jwilder",
    "Repository": "docker-register"
  },
  "Env": {
    "ETCD_HOST": "172.17.42.1:4001",
    "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
    "DOCKER_HOST": "unix:///var/run/docker.sock",
    "HOST_IP": "172.17.42.1"
  },
  "Volumes": {
    "/mnt": {
      "Path": "/mnt",
      "HostPath": "/Users/joebob/tmp",
      "ReadWrite": true
    }
  }
}
```

#### Functions

- _`closest $array $value`_: Returns the longest matching substring in `$array`
  that matches `$value`
- _`coalesce ...`_: Returns the first non-nil argument.
- _`contains $map $key`_: Returns `true` if `$map` contains `$key`. Takes maps
  from `string` to `string`.
- _`dict $key $value ...`_: Creates a map from a list of pairs. Each `$key`
  value must be a `string`, but the `$value` can be any type (or `nil`). Useful
  for passing more than one value as a pipeline context to subtemplates.
- _`dir $path`_: Returns an array of filenames in the specified `$path`.
- _`exists $path`_: Returns `true` if `$path` refers to an existing file or
  directory. Takes a string.
- _`first $array`_: Returns the first value of an array or nil if the arry is
  nil or empty.
- _`groupBy $containers $fieldPath`_: Groups an array of `RuntimeContainer`
  instances based on the values of a field path expression `$fieldPath`. A field
  path expression is a dot-delimited list of map keys or struct member names
  specifying the path from container to a nested value, which must be a string.
  Returns a map from the value of the field path expression to an array of
  containers having that value. Containers that do not have a value for the
  field path in question are omitted.
- _`groupByKeys $containers $fieldPath`_: Returns the same as `groupBy` but only
  returns the keys of the map.
- _`groupByMulti $containers $fieldPath $sep`_: Like `groupBy`, but the string
  value specified by `$fieldPath` is first split by `$sep` into a list of
  strings. A container whose `$fieldPath` value contains a list of strings will
  show up in the map output under each of those strings.
- _`groupByLabel $containers $label`_: Returns the same as `groupBy` but
  grouping by the given label's value.
- _`hasPrefix $prefix $string`_: Returns whether `$prefix` is a prefix of
  `$string`.
- _`hasSuffix $suffix $string`_: Returns whether `$suffix` is a suffix of
  `$string`.
- _`intersect $slice1 $slice2`_: Returns the strings that exist in both string
  slices.
- _`json $value`_: Returns the JSON representation of `$value` as a `string`.
- _`keys $map`_: Returns the keys from `$map`. If `$map` is `nil`, a `nil` is
  returned. If `$map` is not a `map`, an error will be thrown.
- _`last $array`_: Returns the last value of an array.
- _`parseBool $string`_: parseBool returns the boolean value represented by the
  string. It accepts 1, t, T, TRUE, true, True, 0, f, F, FALSE, false, False.
  Any other value returns an error. Alias for
  [`strconv.ParseBool`](http://golang.org/pkg/strconv/#ParseBool)
- _`replace $string $old $new $count`_: Replaces up to `$count` occurences of
  `$old` with `$new` in `$string`. Alias for
  [`strings.Replace`](http://golang.org/pkg/strings/#Replace)
- _`sha1 $string`_: Returns the hexadecimal representation of the SHA1 hash of
  `$string`.
- _`setHTPasswd $file $user $password`_: Creates or adds `$user` with
  `$password` to htpasswd `$file`.
- _`split $string $sep`_: Splits `$string` into a slice of substrings delimited
  by `$sep`. Alias for [`strings.Split`](http://golang.org/pkg/strings/#Split)
- _`splitN $string $sep $count`_: Splits `$string` into a slice of substrings
  delimited by `$sep`, with number of substrings returned determined by
  `$count`. Alias for [`strings.SplitN`](https://golang.org/pkg/strings/#SplitN)
- _`trimPrefix $prefix $string`_: If `$prefix` is a prefix of `$string`, return
  `$string` with `$prefix` trimmed from the beginning. Otherwise, return
  `$string` unchanged.
- _`trimSuffix $suffix $string`_: If `$suffix` is a suffix of `$string`, return
  `$string` with `$suffix` trimmed from the end. Otherwise, return `$string`
  unchanged.
- _`trim $string`_: Removes whitespace from both sides of `$string`.
- _`toLower $string`_: Replace capital letters in `$string` to lowercase.
- _`toUpper $string`_: Replace lowercase letters in `$string` to uppercase.
- _`when $condition $trueValue $falseValue`_: Returns the `$trueValue` when the
  `$condition` is `true` and the `$falseValue` otherwise
- _`where $items $fieldPath $value`_: Filters an array or slice based on the
  values of a field path expression `$fieldPath`. A field path expression is a
  dot-delimited list of map keys or struct member names specifying the path from
  container to a nested value. Returns an array of items having that value.
- _`whereNot $items $fieldPath $value`_: Filters an array or slice based on the
  values of a field path expression `$fieldPath`. A field path expression is a
  dot-delimited list of map keys or struct member names specifying the path from
  container to a nested value. Returns an array of items **not** having that
  value.
- _`whereExist $items $fieldPath`_: Like `where`, but returns only items where
  `$fieldPath` exists (is not nil).
- _`whereNotExist $items $fieldPath`_: Like `where`, but returns only items
  where `$fieldPath` does not exist (is nil).
- _`whereAny $items $fieldPath $sep $values`_: Like `where`, but the string
  value specified by `$fieldPath` is first split by `$sep` into a list of
  strings. The comparison value is a string slice with possible matches. Returns
  items which OR intersect these values.
- _`whereAll $items $fieldPath $sep $values`_: Like `whereAny`, except all
  `$values` must exist in the `$fieldPath`.
- _`whereLabelExists $containers $label`_: Filters a slice of containers based
  on the existence of the label `$label`.
- _`whereLabelDoesNotExist $containers $label`_: Filters a slice of containers
  based on the non-existence of the label `$label`.
- _`whereLabelValueMatches $containers $label $pattern`_: Filters a slice of
  containers based on the existence of the label `$label` with values matching
  the regular expression `$pattern`.

===

### Examples

- [Automated Nginx Reverse Proxy for Docker](http://jasonwilder.com/blog/2014/03/25/automated-nginx-reverse-proxy-for-docker/)
- [Docker Log Management With Fluentd](http://jasonwilder.com/blog/2014/03/17/docker-log-management-using-fluentd/)
- [Docker Service Discovery Using Etcd and Haproxy](http://jasonwilder.com/blog/2014/07/15/docker-service-discovery/)

#### NGINX Reverse Proxy Config

[jwilder/nginx-proxy](https://index.docker.io/u/jwilder/nginx-proxy/) trusted
build.

Start nginx-proxy:

```
$ docker run -d -p 80:80 -v /var/run/docker.sock:/tmp/docker.sock -t jwilder/nginx-proxy
```

Then start containers with a VIRTUAL_HOST env variable:

```
$ docker run -e VIRTUAL_HOST=foo.bar.com -t ...
```

If you wanted to run docker-gen directly on the host, you could do it with:

```
$ docker-gen -only-published -watch -notify "/etc/init.d/nginx reload" templates/nginx.tmpl /etc/nginx/sites-enabled/default
```

#### Fluentd Log Management

This template generate a fluentd.conf file used by fluentd. It would then ship
log files off the host.

```
$ docker-gen -watch -notify "restart fluentd" templates/fluentd.tmpl /etc/fluent/fluent.conf
```

#### Service Discovery in Etcd

This template is an example of generating a script that is then executed. This
template generates a python script that is then executed which register
containers in Etcd using its HTTP API.

```
$ docker-gen -notify "/bin/bash /tmp/etcd.sh" -interval 10 templates/etcd.tmpl /tmp/etcd.sh
```

### Development

```
$ git clone <your fork>
$ make
```

### TODO

- Add event status for handling start and stop events differently

### License

MIT
