# Out of the Box Supply Chains for TCE

Series of reusable Cartographer Supply Chains and templates for driving
workloads from source code to running Knative service in a cluster.

## Components

* Cartographer's ClusterSupplyChain and associated resources (templates)

## Configuration

The following configuration values can be set to customize the installation.

| Value                 | Default             | Description                       | 
| --------------------- | ------------------- | --------------------------------- |
| `registry.server`     | none **(required)** | hostname of the registry server where app images are pushed to |
| `registry.repository` | none **(required)** | where the app images are stored in the image registry |
| `service_account`     | `default`           | name of the serviceaccount to use by default in any children resources |
| `cluster_builder`     | `default`           | name of the kpack clusterbuilder to use by default in any kpack image objects |
| `git_implementation`  | `go-git`            | git implementation to use in flux gitrepository objects |

## Installation

The Cartographer supply chains provided in this package require all
resources of which objects they create to be previously installed in the
cluster, those being:

- **cartographer**, for choreographing kubernetes resources according to the
  definition of the supply chains

- **kapp-controller**, for providing both the packaging primitives for
  installing this package as well as the `App` CRD used by the supply chain to
  deploy the applications built according to the supply chains

- **cartographer-conventions**, for applying conventions to the podtemplatespec
  embeded in the final configuration generated for the application

- **kpack**, for building container images out of source code

- **source-controller**, for keeping track of changes to a git repository and
  making source code available internally in the cluster

- **knative serving**, for running the application

With the dependencies met, proceed with the installation of this package:


1. Create a file named `ootb-supply-chains.yaml` that specifies the
   corresponding values to the properties you want to change. For example:

    ```yaml
    cluster_builder: default
    service_account: default

    registry:
      server: REGISTRY-SERVER
      repository: REGISTRY-REPOSITORY
    ```

1. With the configuration ready, install the package by running:

    ```shell
    tanzu package install ootb-supply-chains \
      --package-name ootb-supply-chains.community.tanzu.vmware.com \
      --version ${OOTB_SUPPLY_CHAINS_PACKAGE_VERSION} \
      --values-file ootb-supply-chains.yaml
    ```

    Example output:

    ```
    \ Installing package 'ootb-supply-chains.community.tanzu.vmware.com'
    | Getting package metadata for 'ootb-supply-chains.community.tanzu.vmware.com'
    | Creating service account 'ootb-supply-chains-default-sa'
    | Creating cluster admin role 'ootb-supply-chains-default-cluster-role'
    | Creating cluster role binding 'ootb-supply-chains-default-cluster-rolebinding'
    | Creating secret 'ootb-supply-chains-default-values'
    | Creating package resource
    - Waiting for 'PackageInstall' reconciliation for 'ootb-supply-chains'
    / 'PackageInstall' resource install status: Reconciling


     Added installed package 'ootb-supply-chains' in namespace 'default'
    ```

## Usage

### Source to URL Supply Chain

To make use of the supply chain, we must first have in the same namespace as
where the Workload is submitted to a couple of objects that the resources
managed by the supplychain need so they can properly do their work:

- **container image registry secret** for providing credentials to the kpack
  Image objects created so the container images created can be pushed to the
  desired registry

- **serviceaccount** for providing means of representing inside Kubernete's
  role-based access control system the permissions that the Cartographer
  controller can make use of in favor of the Workload

- **rolebinding** for binding roles to the serviceaccount that represents the
  workload.


#### Container Image Registry Secret

1. Create a secret with push credentials for the Docker registry that you plan
   on publishing OCI images to with kpack.

    ```shell
    tanzu secret registry add registry-credentials \
      --server REGISTRY-SERVER \
      --username REGISTRY-USERNAME \
      --password REGISTRY-PASSWORD \
      --namespace YOUR-NAMESPACE
    ```

    Alternatively, you can create the secret using `kubectl`:

    ```
    kubectl create secret docker-registry registry-credentials \
      --docker-server=REGISTRY-SERVER \
      --docker-username=REGISTRY-USERNAME \
      --docker-password=REGISTRY-PASSWORD
    ```

    Where:

    - `REGISTRY-SERVER` is the URL of the registry. 

        - For Dockerhub, this must be `https://index.docker.io/v1/`.
          Specifically, it must have the leading `https://`, the `v1` path, and
          the trailing `/`. 
        - For GCR, this is `gcr.io`. The username can be `_json_key` and the
          password can be the JSON credentials you get from the GCP UI (under
          `IAM -> Service Accounts` create an account or edit an existing one
          and create a key with type JSON)

#### ServiceAccount

Create a ServiceAccount to be used by Cartographer to manage the supply chain
resources as well as pass it down to them (the resources) so they are able to
gather necessary data and/or credentials to deal with the Kubernetes API.

Here we also need to associate the previously created Secret
(`registry-credentials`) to it so that anyone referencing such ServiceAccount
also gather the credentials to pull/push images to/from the container image
registry where the application should reside.


```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: hello-world
secrets:
  - name: registry-credentials
imagePullSecrets:
  - name: registry-credentials
```


#### RoleBinding

Bind to the ServiceAccount the role that would then permit the controllers
involved to act upon the objects managed by the supplychain

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: hello-world
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ootb-supply-chain-source-to-url-workload
subjects:
  - kind: ServiceAccount
    name: hello-world
```

### Workload creation

```yaml
apiVersion: carto.run/v1alpha1
kind: Workload
metadata:
  name: hello-world
  labels:
    app.kubernetes.io/part-of: hello-world

    # type of this workload. this is required in order to match this workload
    # against the supplychain bundled in this package.
    #
    apps.tanzu.vmware.com/workload-type: web
spec:
  # name of the serviceaccount to grant to Cartographer the necessary
  # privileges for creating/watching/etc the resources defined by the
  # supply chain.
  #
  serviceAccountName: hello-world

  # details about where source code can be found in order to keep track of
  # changes to it so the resources managed by the supply chain can create new
  # builds and deployments whenever new revisions are found.
  #
  source:
    git:
      url: https://github.com/kontinue/hello-world
      ref: {branch: main}
```

#### Optional Parameters

- `service_account` (string): overrides the default name of the serviceaccount
  (set in `ootb-values.yaml`) to pass on to the children objects.

- `cluster_builder` (string): overrides the default name of the clusterbuilder
  (set in `ootb-values.yaml`) to be used by the `kpack/Image` created by the
supply chain.

## License

Copyright 2022 VMware Inc. All rights reserved

[GCR]: https://cloud.google.com/container-registry/ 
[DockerHub]: https://hub.docker.com/
