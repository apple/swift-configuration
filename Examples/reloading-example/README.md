# Example Hummingbird web app that supports dynamic reconfiguration

This example starts from the template that the Hummingbird project provides for a simple web server.

The app takes advantage of Swift Configuration to establish a static, initial configuration as well as a dynamic, reloading configuration that reads a YAML file from the filesystem.
The mechanism, coupled with an example Kubernetes configMap and deployment configuration, shows how to take advantage of a configuration value that updates automatically as the configMap changes.

The initial, static configuration lives in [Sources/App/App.swift](./Sources/App/App.swift).
The code provides in-memory defaults that can be overridden, in order, by:
- Command-line arguments provided to the executable, which overrides the following mechanisms.
- Environment variables, if set where the executable runs.
- A local environment file (`.env`), if provided.

The static configuration provides example configuration settings that control:
- The log level for the application.
- The logger name.
- The location of the YAML file to use for dynamic configuration.

The dynamic configuration lives in the `buildApplication` method in [Sources/App/App+build.swift](./Sources/App/App+build.swift).
It loads the location of the YAML file from the static configuration, throwing an error and terminating the app if that file doesn't exist.
The code creates an additional configuration reader to access the configuration from the YAML data, and hands that configuration reader into the `buildRouter()` method, alongside the static configuration, to allow the use of both within the routes it assembles.
The default configuration for the `ReloadingFileProvider` checks for updates to the YAML file roughly every 15 seconds.

Example Kubernetes deployment, service, and configuration map manifests live in [deploy](./deploy/). They define a basic example config-map that contains YAML content, and map that configuration to the filesystem within the deployed pod(s).
When the configuration map is updated, the Kubernetes control plane updates the content on the filesystem, and shortly thereafter the app reads the new value and makes it available inside the app.

## Demonstration using Kind

These steps use Docker, Kind (Kubernetes in Docker), and `kubectl` to illustrate the dynamic reloading capability in swift-configuration.

The commands are prefixed with t1, t2, or t3 that represent a shell in a terminal window.
The later steps utilize additional shells in terminal windows, as some of these example commands "take over" a shell.

- Create a local kubernetes cluster using kind:

t1:
```bash
kind create cluster
```

- Verify the cluster is operational:

t1:
```bash
kubectl get pods -A
```

- Build the example code using docker:

t2:
```bash
docker build -t reloading-example:latest .
```

- Push the resulting image into the kubernetes cluster:

t2:
```bash
kind load docker-image reloading-example:latest
```

- Apply the kubernetes manifests to create the configuration map and deployment

t1:
```bash
kubectl apply -f deploy/example-configmap.yaml
kubectl apply -f deploy/example-deployment.yaml
```

- Verify the pod is operational:

t1:
```bash
kubectl get pods
```

t1:
```bash
kubectl port-forward deployment/http-server 8080:8080
```

t2:
```bash
while true; do; sleep 1; curl http://localhost:8080 && echo ""; done
```

The endpoint starts with reporting "Hello Swift", the value provided by the configuration map.
When you apply updates to the configuration map, changing the name from "Swift" to "CNCF",
the endpoint returns that value when the config map has been written into the pod and the service reloads the value:

t3:
```bash
kubectl apply -f deploy/example-configmap-updated.yaml
```

When using Kind, updates are not immediate and can take 30 seconds or more to appear.

To clean up, delete the cluster and the pods running within it:


```bash
kind cluster delete
```