# Set the base image
FROM tanaka0323/java7

# File Author / Maintainer
MAINTAINER Daisuke Tanaka, tanaka@infocorpus.com

ENV DEBIAN_FRONTEND noninteractive
ENV CASSANDRA_VERSION 2.1.4
ENV DSC21_VERSION 2.1.4-1
ENV AGENT_VERSION 5.1.1

RUN apt-get -y update
RUN apt-get install -y curl procps sudo sysstat \
    && rm -rf /var/lib/apt/lists/*
RUN apt-get clean all

RUN groupadd -r cassandra && useradd -r -g cassandra cassandra

# Add DataStax sources
RUN echo "deb http://debian.datastax.com/community stable main" | tee -a /etc/apt/sources.list.d/datastax.sources.list
RUN curl -L http://debian.datastax.com/debian/repo_key | apt-key add -

# Workaround for https://github.com/docker/docker/issues/6345
RUN ln -s -f /bin/true /usr/bin/chfn

RUN apt-get -y update \
    && apt-get install -y cassandra=$CASSANDRA_VERSION dsc21=$DSC21_VERSION datastax-agent=$AGENT_VERSION supervisor \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get clean all

# Environment variables
ENV CASSANDRA_CONFIG    /etc/cassandra
ENV AGENT_CONFIG        /etc/datastax-agent

ENV CLUSTERNAME         CassCluster
ENV TOKEN               256
ENV SNITCH              SimpleSnitch
ENV DATACENTER          datacenter1
ENV RACK                rack1
ENV RUN_AGENT           False
ENV MAX_HEAP_SIZE       1G
ENV HEAP_NEWSIZE        200M

# Adding the configuration file
COPY start.sh /start.sh
COPY sv-min.conf /etc/
COPY sv-full.conf /etc/
COPY address.yaml $AGENT_CONFIG/address.yaml.org
RUN chmod +x /start.sh
RUN cp -f $CASSANDRA_CONFIG/cassandra.yaml $CASSANDRA_CONFIG/cassandra.yaml.org
RUN cp -f $CASSANDRA_CONFIG/cassandra-env.sh $CASSANDRA_CONFIG/cassandra-env.sh.org
RUN cp -f $CASSANDRA_CONFIG/cassandra-rackdc.properties $CASSANDRA_CONFIG/cassandra-rackdc.properties.org
RUN cp -f $CASSANDRA_CONFIG/cassandra-topology.properties $CASSANDRA_CONFIG/cassandra-topology.properties.org

# Necessary since cassandra is trying to override the system limitations
# See https://groups.google.com/forum/#!msg/docker-dev/8TM_jLGpRKU/dewIQhcs7oAJ
RUN rm -f /etc/security/limits.d/cassandra.conf

# Define mountable directories.
VOLUME ["/var/lib/cassandra", "/etc/cassandra", "/etc/datastax-agent"]

ENTRYPOINT ["./start.sh"]

EXPOSE 7199 7000 7001 9160 9042 22 8012 61621

CMD ["supervisord", "-n"]
