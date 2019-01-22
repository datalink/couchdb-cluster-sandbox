# CouchDB Cluster Sandbox

## Introduction

This project was set up to assist with learning and documenting the process
of setting up a CouchDB cluster.

As it is intended primarily for learning and experimenting, the number of nodes
and other settings have been hard-coded. It should be straightforward to update
the project with a dynamic configuration.

Feel free to submit issues and PRs with any corrections or ideas for
improvement.

## Outline

The cluster is orchestrated using Docker Compose, which builds and configures
a stack consisting of 5 containers on a network (`cluster`):

* 3 × CouchDB nodes (`node1.cluster`, `node2.cluster` and `node3.cluster`)
* 1 × HAProxy load balancer (`cluster-lb.cluster`)
* 1 × 'Init' container (`cluster-init.cluster`), which configures and enroles
  the nodes in the cluster

The CouchDB nodes are based on an official Docker image, modified with a custom
configuration file to ensure the same salted administrator credentials are
deployed to each node.

The load balancer service is based on an official HAProxy image, with a custom
configuration file containing a 'backend' that includes the 3 nodes.

The 'init' container is a small Alpine image embellished with with 'curl' and
'jq' packages. These utilities are used by the cluster init script to wait
for each CouchDB node to come online, then configure each in a cluster
once this happens.

## Directory structure

```text
.
├── cluster-init            Build files for init container
├── cluster-lb              Build files for load balancer container
├── cluster-node            Build files for node containers
└── nodes                   Data, config and log mounts for each node
    ├── 1
    │   ├── data
    │   ├── etc
    │   └── log
    ├── 2
    │   ├── data
    │   ├── etc
    │   └── log
    └── 3
        ├── data
        ├── etc
        └── log
```

## Commands

Build and start the stack in the foreground (use the `-d` option to background):

```console
docker-compose up [-d]
```

Check the logs of the init script to confirm that the cluster initialisation
has worked:

```console
docker logs -f cluster-init
```

Check the CouchDB logs of all nodes:

```console
tail -qf nodes/*/log/couch.log
```

Stop and tear down the stack:

```console
docker-compose down
```

Nuke the data directories:

```console
rm -rf nodes/1/ nodes/2/ nodes/3/
```

## Things to look out for

### Cluster Init

Sample output for a new cluster:

```console
Initialising a 3-node CouchDB cluster
Check all nodes active
Waiting for node1
Waiting for node2
Waiting for node3
Check cluster status and exit if already set up
Configure consistent UUID on all nodes
"6a8b456660e83bb3730dcfb4fa7c3782"
"107705b1dc3b0c4a034f9e14c79403e6"
"9a6fd000dbca2691187d957f87b2fe0c"
Set up common shared secret
""
""
""
Configure nodes 2 and 3 on node 1
{"ok":true}
{"ok":true}
Add nodes 2 and 3 on node 1
{"ok":true}
{"ok":true}
Finish cluster
{"ok":true}
Check cluster membership
{
  "all_nodes": [
    "couchdb@node1.cluster",
    "couchdb@node2.cluster",
    "couchdb@node3.cluster"
  ],
  "cluster_nodes": [
    "couchdb@node1.cluster",
    "couchdb@node2.cluster",
    "couchdb@node3.cluster"
  ]
}
Done!
Check http://localhost:5984/_haproxy_stats for HAProxy info.
Use http://localhost:5984/_utils for CouchDB admin.
```

Sample output if the cluster has already been configured:

```console
Initialising a 3-node CouchDB cluster
Check all nodes active
Waiting for node1
Waiting for node2
Waiting for node3
Check cluster status and exit if already set up
CouchDB cluster already set up with 3 nodes
[
  "couchdb@node1.cluster",
  "couchdb@node2.cluster",
  "couchdb@node3.cluster"
]
```

### Endpoints

The default administrator credentials are `admin` and `secret`.

On the Docker host:

* The load-balanced CouchDB endpoint is exposed as http://localhost:5984.
* Fauxton can be accessed at http://localhost:5984/_utils.
* HAProxy statistics can be accessed at http://localhost:5984/_haproxy_stats.

If the ports are enabled, the nodes can be directly accessed respectively at:

* http://localhost:59841
* http://localhost:59842
* http://localhost:59843

The relevant config lines in `docker-compose.yml` must be uncommented to enable
these ports.

### Configuration consistency

Each node should have common server UUIDs and shared secrets. Compare the
`docker.ini` files in each node's config mount directory to confirm this:

* `./nodes/1/etc/docker.ini`
* `./nodes/2/etc/docker.ini`
* `./nodes/3/etc/docker.ini`

When configured correctly, the UUID reported by each node's root URL should
also match. For example:

```console
$ curl -s -X GET http://localhost:59841 | jq -r .uuid
2d964d11d414ecd61d4eceb3fc00024b
$ curl -s -X GET http://localhost:59843 | jq -r .uuid
2d964d11d414ecd61d4eceb3fc00024b
$ curl -s -X GET http://localhost:59843 | jq -r .uuid
2d964d11d414ecd61d4eceb3fc00024b
```

## Setup notes

Items of note encountered during the setup process:

* Even if a node is reachable by simple hostname on the network, node names
  must use an *IP address* or *fully-qualified domain name* for the hostname
  portion, e.g. `couchdb@node1.cluster` in the case of this Docker network.
  See the [relevant documentation][1] for details.

[1]: https://docs.couchdb.org/en/master/setup/cluster.html#make-couchdb-use-correct-ip-fqdn-and-the-open-ports
