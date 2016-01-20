# jenkins-standalone
Run a stateless Jenkins master on Apache Mesos and Marathon.
For more information, see <http://rogerignazio.com/blog/scaling-jenkins-mesos-marathon>

*Note: if you're looking to run Jenkins on Mesos or DCOS and save your job configurations
and build history to disk, you might want to check out Mesosphere's
[jenkins-mesos][mesosphere-jenkins-mesos] project instead.*

## Usage
```
Usage: ./jenkins-standalone.sh <required_arguments> [optional_arguments]

REQUIRED ARGUMENTS
  -z, --zookeeper     The ZooKeeper URL, e.g. zk://10.132.188.212:2181/mesos
  -r, --redis-host    The hostname or IP address to a Redis instance

OPTIONAL ARGUMENTS
  -u, --user          The user to run the Jenkins slave under. Defaults to
                      the same username that launched the Jenkins master.
  -d, --docker        The name of a Docker image to use for the Jenkins slave.
```

Redis is used as the broker for Logstash and the Jenkins Logstash plugin.

When copying/pasting this command into Marathon, each line should be
concatenated with `&&`, so that it only proceeds if the previous command
was successful.

Example usage:
```
git clone https://github.com/rji/jenkins-standalone
cd jenkins-standalone
./jenkins-standalone.sh -z $(cat /etc/mesos/zk) -r redis.example.com -u jenkins -d example/docker-image
```

You can also use the Marathon API to create apps. There is an example
`jenkins-standalone.json` in the `examples/` directory.

```
$ curl -i -H 'Content-Type: application/json' -d @jenkins-standalone.json marathon.example.com:8080/v2/apps
```

[mesosphere-jenkins-mesos]: https://github.com/mesosphere/jenkins-mesos
