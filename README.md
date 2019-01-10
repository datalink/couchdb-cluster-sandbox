# CouchDB Cluster Sandbox

## Outline

This cluster sandbox is orchestrated using Docker Compose, which builds and
configures a stack consisting of 5 containers:

* 3 x CouchDB cluster nodes
* 1 x HAProxy load balancer
* 1 x Init container, which configures the nodes as a cluster

## Directory structure

```
.
├── cluster-init            Build files for init container
├── cluster-lb              Build files for load balancer container
├── cluster-node            Build files for node containers
└── nodes                   Data and config mounts for each node
    ├── 1
    │   ├── data
    │   └── etc
    ├── 2
    │   ├── data
    │   └── etc
    └── 3
        ├── data
        └── etc
```

## Commands

Build and start the stack:

```console
docker-compose up -d
```

Stop and tear down the stack:

```console
docker-compose down
```

## Stuff to look out for

The load balancer endpoint is exposed as http://localhost:5984 on the Docker
host. Fauxton can be accessed at http://localhost:5984/_utils and HAProxy
statistics can be accessed at http://localhost:5984/_haproxy_stats.

If the ports are enabled, the nodes can be directly accessed respectively at:

* http://localhost:59841
* http://localhost:59842
* http://localhost:59843

The relevant config lines in `docker-compose.yml` must be uncommented to enable
these ports.

Each node should have common server UUIDs and shared secrets. Compare the
`docker.ini` files in each node's config mount directory to confirm this:

* `./nodes/1/etc/docker.ini`
* `./nodes/2/etc/docker.ini`
* `./nodes/3/etc/docker.ini`

## Known Issues

Fauxton doesn't seem to honour sessions accessed via the HAProxy endpoint. It
seems that, if the load balancer directs a request to a node which doesn't
recognise the session ID, the user is kicked out to the login prompt.