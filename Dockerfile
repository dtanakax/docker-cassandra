# Set the base image
FROM tanaka0323/java7

# File Author / Maintainer
MAINTAINER Daisuke Tanaka, tanaka@infocorpus.com

ENV DEBIAN_FRONTEND noninteractive
ENV CASSANDRA_VERSION 2.1.4
ENV DSC21_VERSION 2.1.4-1

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r cassandra && useradd -r -g cassandra cassandra

RUN apt-get -y update
RUN apt-get install -y curl procps openssh-server openssl sudo sysstat \
    && rm -rf /var/lib/apt/lists/*
RUN apt-get clean all

# Configure SSH server
# Create OpsCenter account
RUN mkdir -p /var/run/sshd && chmod -rx /var/run/sshd \
    && rm -f /etc/ssh/ssh_host_rsa_key \
    && ssh-keygen -t rsa -N '' -f /etc/ssh/ssh_host_rsa_key \
    && sed -ri 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config \
    && sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config \
    && sed -ri 's/#UsePAM no/UsePAM no/g' /etc/ssh/sshd_config \
    && useradd -m -G users,root -p $(openssl passwd -1 "opscenter") opscenter \
    && echo "%root ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Add DataStax sources
RUN echo "deb http://debian.datastax.com/community stable main" | tee -a /etc/apt/sources.list.d/datastax.sources.list
RUN curl -L http://debian.datastax.com/debian/repo_key | apt-key add -

# Workaround for https://github.com/docker/docker/issues/6345
RUN ln -s -f /bin/true /usr/bin/chfn

RUN apt-get -y update \
    && apt-get install -y cassandra=$CASSANDRA_VERSION dsc21=$DSC21_VERSION supervisor \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get clean all

# Environment variables
ENV CASSANDRA_CONFIG    /etc/cassandra
ENV CLUSTERNAME         CassCluster
ENV TOKEN               256
ENV SNITCH              SimpleSnitch
ENV DATACENTER          datacenter1
ENV RACK                rack1

# Adding the configuration file
COPY start.sh /start.sh
COPY supervisord.conf /etc/
RUN chmod +x /start.sh
RUN cp -f $CASSANDRA_CONFIG/cassandra.yaml $CASSANDRA_CONFIG/cassandra.yaml.org
RUN cp -f $CASSANDRA_CONFIG/cassandra-env.sh $CASSANDRA_CONFIG/cassandra-env.sh.org
RUN cp -f $CASSANDRA_CONFIG/cassandra-rackdc.properties $CASSANDRA_CONFIG/cassandra-rackdc.properties.org
RUN cp -f $CASSANDRA_CONFIG/cassandra-topology.properties $CASSANDRA_CONFIG/cassandra-topology.properties.org

# Necessary since cassandra is trying to override the system limitations
# See https://groups.google.com/forum/#!msg/docker-dev/8TM_jLGpRKU/dewIQhcs7oAJ
RUN rm -f /etc/security/limits.d/cassandra.conf

# Define mountable directories.
VOLUME ["/var/lib/cassandra"]

EXPOSE 7199 7000 7001 9160 9042 22 8012 61621

# Executing sh
ENTRYPOINT ./start.sh
