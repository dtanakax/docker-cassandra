#!/bin/bash
set -e

chown -R cassandra:cassandra /var/lib/cassandra
chown -R cassandra:cassandra /var/log/cassandra

# Accept listen_address
# Accept seeds via docker run -e SEEDS=seed1,seed2,...
# Backwards compatibility with older scripts that just passed the seed in
IP=${LISTEN_ADDRESS:-`hostname --ip-address`}
SEEDS=${SEEDS:-$IP}
if [ $# == 1 ]; then SEEDS="$1,$SEEDS"; fi

#if this container was linked to any other cassandra nodes, use them as seeds as well.
if [[ `env | grep _PORT_9042_TCP_ADDR` ]]; then
  SEEDS="$SEEDS,$(env | grep _PORT_9042_TCP_ADDR | sed 's/.*_PORT_9042_TCP_ADDR=//g' | sed -e :a -e N -e 's/\n/,/' -e ta)"
fi

echo "=> Configuring Cassandra to listen at $IP with seeds $SEEDS"

# Datastax agent execute 
if [ "$RUN_AGENT" = "True" ]; then
  # Recreate datastax agent config
  rm -f $AGENT_CONFIG/address.yaml
  cp -f $AGENT_CONFIG/address.yaml.org $AGENT_CONFIG/address.yaml

  # Setup datastax agent
  sed -i -e "s/#stomp_interface:/stomp_interface: \"$OPSCENTER_PORT_61620_TCP_ADDR\"/
             s/#local_interface:/local_interface: $IP/" $AGENT_CONFIG/address.yaml

  cp -f /etc/sv-full.conf /etc/supervisord.conf
else
  cp -f /etc/sv-min.conf /etc/supervisord.conf
fi

# Recreate cassandra config files
rm -f $CASSANDRA_CONFIG/cassandra.yaml $CASSANDRA_CONFIG/cassandra-env.sh $CASSANDRA_CONFIG/cassandra-rackdc.properties $CASSANDRA_CONFIG/cassandra-topology.properties
cp -f $CASSANDRA_CONFIG/cassandra.yaml.org $CASSANDRA_CONFIG/cassandra.yaml
cp -f $CASSANDRA_CONFIG/cassandra-env.sh.org $CASSANDRA_CONFIG/cassandra-env.sh
cp -f $CASSANDRA_CONFIG/cassandra-rackdc.properties.org $CASSANDRA_CONFIG/cassandra-rackdc.properties
cp -f $CASSANDRA_CONFIG/cassandra-topology.properties.org $CASSANDRA_CONFIG/cassandra-topology.properties

# Disable virtual nodes
sed -i -e "s/num_tokens/\#num_tokens/" $CASSANDRA_CONFIG/cassandra.yaml

# Setup cluster name
if [ -z "$CLUSTERNAME" ]; then
    echo "=> No cluster name specified, preserving default one"
else
    sed -i -e "s/^cluster_name:.*/cluster_name: $CLUSTERNAME/" $CASSANDRA_CONFIG/cassandra.yaml
fi

# Setup Cassandra
sed -i -e "s/^listen_address.*/listen_address: $IP/
           s/^rpc_address.*/rpc_address: 0.0.0.0/
           s/# broadcast_address.*/broadcast_address: $IP/
           s/# broadcast_rpc_address.*/broadcast_rpc_address: $IP/
           s/^commitlog_segment_size_in_mb.*/commitlog_segment_size_in_mb: 64/
           s/- seeds: \"127.0.0.1\"/- seeds: \"$SEEDS\"/" $CASSANDRA_CONFIG/cassandra.yaml

# With virtual nodes disabled, we need to manually specify the token
if [ -z "$TOKEN" ]; then
    echo "=> Missing initial token for Cassandra"
    exit -1
fi
echo "JVM_OPTS=\"\$JVM_OPTS -Dcassandra.initial_token=$TOKEN\"" >> $CASSANDRA_CONFIG/cassandra-env.sh

# Most likely not needed
echo "JVM_OPTS=\"\$JVM_OPTS -Djava.rmi.server.hostname=$IP\"" >> $CASSANDRA_CONFIG/cassandra-env.sh

sed -i -e "s/endpoint_snitch: SimpleSnitch/endpoint_snitch: $SNITCH/" $CASSANDRA_CONFIG/cassandra.yaml
echo "default=$DATACENTER:$RACK" > $CASSANDRA_CONFIG/cassandra-topology.properties

echo "dc=$DATACENTER" > $CASSANDRA_CONFIG/cassandra-rackdc.properties
echo "rack=$RACK" >> $CASSANDRA_CONFIG/cassandra-rackdc.properties

# Start process
echo "=> Starting Cassandra on $IP..."

# Executing supervisord
supervisord -n