# BlueSpice Helm chart

This repository contains the Helm chart for running BlueSpice on Kubernetes with a local Minikube setup.

## Prerequisites

- Kubernetes cluster available locally or in a managed environment
- Helm 3 installed
- Minikube for local development is recommended
- A writable PVC for the wiki data directory

For Minikube, the chart is tuned for the common RWO-only case:

- `wikiServicesCombineWebAndTask: true`
- `wikiServicesVolume.wiki-pvc.accessModes: ["ReadWriteOnce"]`

## Quick start for Minikube

1. Create the namespace:

```bash
kubectl create namespace bluespice
```

2. Install the chart:

```bash
helm upgrade --install bluespice ./helm -n bluespice -f ./helm/values-local.yaml
```

3. Wait for the install job to finish:

```bash
kubectl wait --for=condition=complete job/bluespice-install -n bluespice --timeout=600s
```

4. Start the local port-forward:

```bash
kubectl port-forward -n bluespice svc/wiki-web 8080:80
```

5. Open the wiki in the browser:

```text
http://localhost:8080
```

## Local defaults

The local values file in [helm/values-local.yaml](helm/values-local.yaml) already contains the Minikube-friendly defaults for this repo.

Important settings currently used there:

- `wikiServicesCombineWebAndTask: true`
- `wikiEnv.configEnv.WIKI_HOST: "localhost"`
- `wikiEnv.configEnv.WIKI_PORT: "8080"`
- `wikiEnv.configEnv.WIKI_PROTOCOL: "http"`
- `wikiEnv.configEnv.WIKI_INITIAL_ADMIN_USER: "Admin"`
- `wikiEnv.configEnv.WIKI_INITIAL_ADMIN_PASS: "pw123123123"`
- `wikiServicesVolume.wiki-pvc.accessModes: ["ReadWriteOnce"]`

Before production use, replace all password placeholders and sensitive values with real ones.

## Access and login

The wiki is configured for the local Minikube flow with these values:

- URL: http://localhost:8080
- User: Admin
- Password: pw123123123

If you want to read the generated admin password from the runtime filesystem instead of the static local value, use:

```bash
kubectl exec -n bluespice deploy/wiki-web -c wiki-web -- cat /data/initialAdminPassword
```

## Important notes

### Shared PVC for wiki-web and wiki-task

When the cluster does not support RWX, both containers must share the same PVC mount. The local setup keeps them in one pod and mounts `/data` with the correct subPath layout so the generated `.wikienv` file is visible to the web container.

### Install job behavior

The chart includes a post-install job that runs the BlueSpice installation logic. After the initial install, the job is not re-run during a normal upgrade unless you explicitly reinstall or re-trigger it.

### Optional services and disabled components

The local chart intentionally disables optional services that are not needed for the minimal wiki stack in development.

## Configuration examples

To install with replacement values:

```bash
helm upgrade --install bluespice ./helm -n bluespice \
  -f ./helm/values-local.yaml \
  --set-string wikiEnv.configEnv.WIKI_INITIAL_ADMIN_PASS='your-admin-password' \
  --set-string statefulBackendServices.database.secrets.MARIADB_ROOT_PASSWORD='your-root-password' \
  --set-string statefulBackendServices.database.secrets.MARIADB_PASSWORD='your-db-password'
```

To upgrade an existing release:

```bash
helm upgrade bluespice ./helm -n bluespice -f ./helm/values-local.yaml
```

## Troubleshooting

If the app does not come up, check the following in order:

1. `kubectl get pods -n bluespice`
2. `kubectl logs -n bluespice deploy/wiki-web -c wiki-web`
3. `kubectl exec -n bluespice deploy/wiki-web -c wiki-web -- ls -la /data`
4. `kubectl exec -n bluespice deploy/wiki-web -c wiki-web -- ls -la /data/wiki`

If the shared wiki volume is not mounted as expected, the app may block on the `.wikienv` file creation. The local Minikube overrides in [helm/values-local.yaml](helm/values-local.yaml) are designed to avoid that issue.

## Related docs

- BlueSpice Docker image docs
- Kubernetes values reference in the chart templates
- Local Minikube deployment notes in [helm/values-local.yaml](helm/values-local.yaml)
