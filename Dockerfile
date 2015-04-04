# Set the base image
FROM tanaka0323/java7

# File Author / Maintainer
MAINTAINER Naomine Egawa, naomine.egawa@gmail.com

ENV DEBIAN_FRONTEND noninteractive

# Install Cassandra with DataStax
RUN echo "deb http://debian.datastax.com/community stable main" | tee -a /etc/apt/sources.list.d/cassandra.sources.list
COPY sources.list /etc/apt/sources.list
RUN curl -L http://debian.datastax.com/debian/repo_key | apt-key add -
RUN apt-get update && \
  apt-get install -y dsc20=2.0.14-1 cassandra=2.0.14 && \
  rm -rf /var/lib/apt/lists/*

ENV CASSANDRA_CONFIG /etc/cassandra

# Init Cassandra
# RUN service cassandra stop && \
#   rm -rf /var/lib/cassandra/data/system/*

# Start
# RUN service cassandra start


