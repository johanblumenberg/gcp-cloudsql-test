# Deploy

Deploy the service in a GCP project

```bash
$ export DOCKER_REPO=...

$ cd service
$ ./mvnw package
$ docker tag demo $DOCKER_REPO/demo
$ docker push $DOCKER_REPO/demo

$ cd infra
$ terraform init
$ terraform apply -var service_image=$DOCKER_REPO/demo -var project=<GCP project>
```

# Test

Check that the service is reachable

```bash
$ curl https://<...run.app>/debug/info
```

# Trigger the bug

Run the test to trigger the bug

```bash
$ curl https://<...run.app>/test
Success count: 252 [acquire:9624,release:724,query:1734]
```

The output shows that the service was able to make 252 SQL queries during 10 seconds,
and it also shows that the acquire and release connection operations take a considerable
time to complete.

Then change to use VPC connector instead of Direct VPC egress, by changing `infra/cloud-run.tf`:

```
    vpc_access {
#      network_interfaces {
#        network    = google_compute_network.vpc.name
#        subnetwork = google_compute_subnetwork.europe_north1-service.name
#      }
      connector = google_vpc_access_connector.connector.id
      egress = "ALL_TRAFFIC"
    }
```

Run the test to see the difference

```bash
$ curl https://<...run.app>/test
Success count: 63535 [acquire:4,release:1,query:43]
```

The output shows that the service was able to make 63535 queries during 10 seconds,
and it also shows that the acquire and release operations are fast.
