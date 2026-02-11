# Example Hummingbird web app that supports dynamic reconfiguration

This example starts from the template that the Hummingbird projects for a simple web server.

The app sources take advantage of swift-configuration to establish a static, initial configuration as well as a dynamic, reloading configuration that reads a JSON file from the filesystem.
The mechanism, coupled with an example kubernetes configMap and deployment configuration, show how to take advantage of a configuration object that updates automatically as the configMap changes.

The initial, static configuration is configured in [Sources/App/App.swift](./Sources/App/App.swift). 
In the initial setup, the code provides in-memory defaults that can be overrided, in order, by:
- a local environment file (`.env`)
- set environment variables
- command-line arguments

The static configuration provides example configuration settings that control:
- the log level for the application
- the logger name
- the location of the JSON file to use for dynamic configuration

The dynamic configuration is set up in the buildApplication method in [Sources/App/App+build.swift](./Sources/App/App+build.swift).
It loads the location of the JSON file from the static configuration, throwing an error and terminating the app if that file doesn't exist.
The code creates an additional configuration reader to access the configuration from the JSON data, and hands that configuration reader into the buildRouter() method, alongside the static configuration, to allow the use of both within the routes it assembles.
The default configuration for the ReloadingFileProvider checks for updates to the JSON file roughly every 15 seconds.

Example Kubernetes deployment, service, and configuration map manifests are in [deploy](./deploy/). They define a basic example config-map that contains JSON content, and maps that configuration to the filesystem within the deployed pod(s).
When the configuration map is updated, the Kubernetes control plan updates the content on the filesystem, and shortly thereafter the app reads the new value and makes it available inside the app.
