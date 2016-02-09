#!/bin/bash
set -e

# $JENKINS_VERSION should be an LTS release
JENKINS_VERSION="1.642.1"

# List of Jenkins plugins, in the format "${PLUGIN_NAME}/${PLUGIN_VERSION}"
JENKINS_PLUGINS=(
    "ansible/0.4"
    "build-flow-plugin/0.18"
    "build-monitor-plugin/latest"
    "build-name-setter/1.5.1"
    "build-pipeline-plugin/1.4.9"
    "credentials/1.24"
    "disk-usage/0.28"
    "email-ext/2.40.5"
    "git/2.4.2"
    "git-client/1.19.3"
    "git-changelog/1.2"
    "github-api/1.72"
    "github/1.17.0"
    "github-oauth/0.22.2"
    "greenballs/1.15"
    "http-post/1.2"
    "javadoc/1.3"
    "job-dsl/1.42"
    "jquery/1.11.2"
    "jquery-ui/1.0.2"
    "junit/1.10"
    "log-parser/2.0"
    "logstash/1.1.1"
    "mailer/1.16"
    "maven-plugin/2.12.1"
    "matrix-project/1.6"
    "matrix-auth/1.2"
    "metadata/1.1.0b"
    "mesos/0.10.0"
    "monitoring/1.58.0"
    "oauth-credentials/0.3"
    "parameterized-trigger/2.30"
    "pagerduty/0.2.2"
    "plain-credentials/1.1"
    "rebuild/1.25"
    "saferestart/0.3"
    "scm-api/1.0"
    "script-security/1.17"
    "slack/1.8.1"
    "ssh-credentials/1.11"
    "ssh-slaves/1.10"
    "thinBackup/1.7.4"
    "token-macro/1.10"
    "jenkinswalldisplay/0.6.30"
)

JENKINS_WAR_MIRROR="http://mirrors.jenkins-ci.org/war-stable"
JENKINS_PLUGINS_MIRROR="http://mirrors.jenkins-ci.org/plugins"

usage () {
    cat <<EOT
Usage: $0 <required_arguments> [optional_arguments]

REQUIRED ARGUMENTS
  -z, --zookeeper     The ZooKeeper URL, e.g. zk://10.132.188.212:2181/mesos
  -r, --redis-host    The hostname or IP address to a Redis instance

OPTIONAL ARGUMENTS
  -u, --user          The user to run the Jenkins slave under. Defaults to
                      the same username that launched the Jenkins master.
  -d, --docker        The name of a Docker image to use for the Jenkins slave.

EOT
    exit 1
}

# Ensure we have an accessible wget
if ! command -v wget > /dev/null; then
    echo "Error: wget not found in \$PATH"
    echo
    exit 1
fi

# Print usage if arguments passed is less than the required number
if [[ ! $# > 3 ]]; then
    usage
fi

# Process command line arguments
while [[ $# > 1 ]]; do
    key="$1"; shift
    case $key in
        -z|--zookeeper)
            ZOOKEEPER_PATHS="$1"   ; shift ;;
        -r|--redis-host)
            REDIS_HOST="$1"        ; shift ;;
        -u|--user)
            SLAVE_USER="${1-''}"   ; shift ;;
        -d|--docker)
            DOCKER_IMAGE="${1-''}" ; shift ;;
        -h|--help)
            usage ;;
        *)
            echo "Unknown option: ${key}"; exit 1 ;;
    esac
done

# Jenkins WAR file
if [[ ! -f "jenkins.war" ]]; then
    wget -nc "${JENKINS_WAR_MIRROR}/${JENKINS_VERSION}/jenkins.war"
fi

# Jenkins plugins
[[ ! -d "plugins" ]] && mkdir "plugins"
for plugin in ${JENKINS_PLUGINS[@]}; do
    IFS='/' read -a plugin_info <<< "${plugin}"
    plugin_path="${plugin_info[0]}/${plugin_info[1]}/${plugin_info[0]}.hpi"
    wget -nc -P plugins "${JENKINS_PLUGINS_MIRROR}/${plugin_path}"
done

# Jenkins config files
PORT=${PORT-"8080"}

sed -i "s!_MAGIC_ZOOKEEPER_PATHS!${ZOOKEEPER_PATHS}!" config.xml
sed -i "s!_MAGIC_REDIS_HOST!${REDIS_HOST}!" jenkins.plugins.logstash.LogstashInstallation.xml
sed -i "s!_MAGIC_JENKINS_URL!http://${HOST}:${PORT}!" jenkins.model.JenkinsLocationConfiguration.xml
sed -i "s!_MAGIC_JENKINS_SLAVE_USER!${SLAVE_USER}!" config.xml

# Optional: configure containerInfo
if [[ ! -z $DOCKER_IMAGE ]]; then
    container_info="<containerInfo>\n            <type>DOCKER</type>\n            <dockerImage>${DOCKER_IMAGE}</dockerImage>\n            <networking>BRIDGE</networking>\n            <useCustomDockerCommandShell>false</useCustomDockerCommandShell>\n            <dockerPrivilegedMode>false</dockerPrivilegedMode>\n             <dockerForcePullImage>false</dockerForcePullImage>\n          </containerInfo>"

    sed -i "s!_MAGIC_CONTAINER_INFO!${container_info}!" config.xml
else
    # Remove containerInfo from config.xml
    sed -i "/_MAGIC_CONTAINER_INFO/d" config.xml
fi

# Start the master
export JENKINS_HOME="$(pwd)"
java \
    -Dhudson.DNSMultiCast.disabled=true            \
    -Dhudson.udp=-1                                \
    -jar jenkins.war                               \
    -Djava.awt.headless=true                       \
    --webroot=war                                  \
    --httpPort=${PORT}                             \
    --ajp13Port=-1                                 \
    --httpListenAddress=0.0.0.0                    \
    --ajp13ListenAddress=127.0.0.1                 \
    --preferredClassLoader=java.net.URLClassLoader \
    --logfile=../jenkins.log
