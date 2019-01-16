#!/usr/bin/env sh

#
# CouchDB Cluster Init Service
#
# Waits for CouchDB nodes to come online, then configures the nodes in a cluster.
#

echo "Initialising a 3-node CouchDB cluster"

# Set up admin users (this has been pulled up into local.ini of the cluster-node Dockerfile)
#curl -s -X PUT http://node1.cluster:5984/_node/couchdb@node1.cluster/_config/admins/admin -d '"secret"'
#curl -s -X PUT http://node2.cluster:5984/_node/couchdb@node2.cluster/_config/admins/admin -d '"secret"'
#curl -s -X PUT http://node3.cluster:5984/_node/couchdb@node3.cluster/_config/admins/admin -d '"secret"'

# Check all nodes active
echo "Check all nodes active"
function waitForNode() {
  echo "Waiting for ${1}"
  NODE_ACTIVE=""
  until [ "${NODE_ACTIVE}" = "ok" ]; do
    sleep 1
    NODE_ACTIVE=$(curl -s --user admin:secret -X GET http://${1}.cluster:5984/_up | jq -r .status)
  done
}
waitForNode node1
waitForNode node2
waitForNode node3

# Check cluster status and exit if already set up
echo "Check cluster status and exit if already set up"
ALL_NODES_COUNT=$(curl -s --user admin:secret -X GET http://node1.cluster:5984/_membership | jq '.all_nodes | length')
if [ "${ALL_NODES_COUNT}" -eq 3 ] ; then
  echo "CouchDB cluster already set up with ${ALL_NODES_COUNT} nodes"
  curl -s --user admin:secret -X GET http://node1.cluster:5984/_membership | jq '.all_nodes'
  exit
fi

# Configure consistent UUID on all nodes
echo "Configure consistent UUID on all nodes"
SHARED_UUID=$(curl -s -X GET http://node1.cluster:5984/_uuids | jq .uuids[0])
curl -s --user admin:secret -X PUT http://node1.cluster:5984/_node/_local/_config/couchdb/uuid -d "${SHARED_UUID}"
curl -s --user admin:secret -X PUT http://node2.cluster:5984/_node/_local/_config/couchdb/uuid -d "${SHARED_UUID}"
curl -s --user admin:secret -X PUT http://node3.cluster:5984/_node/_local/_config/couchdb/uuid -d "${SHARED_UUID}"

# Set up common shared secret
echo "Set up common shared secret"
SHARED_SECRET=$(curl -s -X GET http://node1.cluster:5984/_uuids | jq .uuids[0])
curl -s --user admin:secret -X PUT http://node1.cluster:5984/_node/_local/_config/couch_httpd_auth/secret -d "${SHARED_SECRET}"
curl -s --user admin:secret -X PUT http://node2.cluster:5984/_node/_local/_config/couch_httpd_auth/secret -d "${SHARED_SECRET}"
curl -s --user admin:secret -X PUT http://node3.cluster:5984/_node/_local/_config/couch_httpd_auth/secret -d "${SHARED_SECRET}"

# Enable cluster (looks to be redundant, as it seems configuring an admin user implicitly marks the cluster as enabled)
#curl -s --user admin:secret -X POST http://node1.cluster:5984/_cluster_setup -H "content-type:application/json" -d '{"action":"enable_cluster","username":"admin","password":"secret","bind_address":"0.0.0.0","node_count":3}'

# Configure nodes 2 and 3 on node 1
echo "Configure nodes 2 and 3 on node 1"
curl -s --user admin:secret -X POST http://node1.cluster:5984/_cluster_setup -H "Content-Type: application/json" -d '{"action":"enable_cluster","remote_node":"node2.cluster","port":"5984","username":"admin","password":"secret","bind_address":"0.0.0.0","node_count":3}'
curl -s --user admin:secret -X POST http://node1.cluster:5984/_cluster_setup -H "Content-Type: application/json" -d '{"action":"enable_cluster","remote_node":"node3.cluster","port":"5984","username":"admin","password":"secret","bind_address":"0.0.0.0","node_count":3}'

# Add nodes 2 and 3 on node 1
echo "Add nodes 2 and 3 on node 1"
curl -s --user admin:secret -X POST http://node1.cluster:5984/_cluster_setup -H "Content-Type: application/json" -d '{"action":"add_node","host":"node2.cluster","port":"5984","username":"admin","password":"secret"}'
curl -s --user admin:secret -X POST http://node1.cluster:5984/_cluster_setup -H "Content-Type: application/json" -d '{"action":"add_node","host":"node3.cluster","port":"5984","username":"admin","password":"secret"}'

# Finish cluster
echo "Finish cluster"
curl -s --user admin:secret -X POST http://node1.cluster:5984/_cluster_setup -H "Content-Type: application/json" -d '{"action": "finish_cluster"}'

# Check cluster membership
echo "Check cluster membership"
curl -s --user admin:secret -X GET http://node1.cluster:5984/_membership | jq

# Create default system databases (this seems to be implicit in the cluster setup process)
#echo "Create default system databases"
#curl -s --user admin:secret -X PUT http://node1.cluster:5984/_users
#curl -s --user admin:secret -X PUT http://node1.cluster:5984/_replicator
#curl -s --user admin:secret -X PUT http://node1.cluster:5984/_global_changes

# Done!
echo "Done!"
echo "Check http://localhost:5984/_haproxy_stats for HAProxy info."
echo "Use http://localhost:5984/_utils for CouchDB admin."