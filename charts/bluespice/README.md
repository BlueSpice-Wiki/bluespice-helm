# BlueSpice Helm Chart

<img style="display:block;margin:auto" src="https://bluespice.com/wp-content/uploads/2022/09/bluespice_logo.png" alt="BlueSpice MediaWiki logo" />

Helm chart for containerized deployment of [BlueSpice Wiki](https://bluespice.com) on Kubernetes.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Platform-Specific Notes](#platform-specific-notes)
- [Configuration](#configuration)
- [Local Development](#local-development)
- [Upgrade](#upgrade)
- [Further Documentation](#further-documentation)

## Prerequisites

- Kubernetes 1.25+
- Helm 3.10+
- A StorageClass that supports `ReadWriteMany` (RWX) for the wiki PVC — or use `wikiServicesCombineWebAndTask: true` with `ReadWriteOnce` (see [Local Development](#local-development))

## Installation

> [!WARNING]
> Depending on your Kubernetes platform and storage/network stack, additional adjustments may be required.
> Check [Platform-Specific Notes](#platform-specific-notes) before installing.

> [!NOTE]
> `values-local.yaml` is the local template for Minikube. It keeps the non-sensitive defaults, but you still need to replace the password placeholders before install or override them with `--set`.

```bash
# 1. Create namespace
kubectl create namespace bluespice

# 2. Install
helm install bluespice . -n bluespice -f values-local.yaml

# 3. Wait for the install Job to complete (~3-5 min on first install)
kubectl wait --for=condition=complete job/bluespice-install -n bluespice --timeout=600s

# 4. Access the wiki
kubectl port-forward -n bluespice svc/wiki-web 8080:80
# → http://localhost:8080
```

> [!NOTE]
> Wait a few seconds after the port-forward starts before opening the URL. PHP-FPM inside the pod may still be initializing and will return HTTP 503 briefly.

The post-install Job runs `/app/bin/run-installation` automatically and sets up the database schema. On subsequent `helm upgrade` calls the Job does not run again.

To disable the install Job (e.g. when restoring from backup):
```bash
helm install bluespice . -n bluespice -f values-local.yaml --set installation.enabled=false
```

### Local secrets for minikube

Replace the placeholders in `values-local.yaml` before install:

- `wikiEnv.configEnv.WIKI_INITIAL_ADMIN_PASS`
- `statefulBackendServices.database.secrets.MARIADB_ROOT_PASSWORD`
- `statefulBackendServices.database.secrets.MARIADB_PASSWORD`

> [!IMPORTANT]
> All three passwords must be **at least 10 characters** long. MediaWiki enforces this for the admin password, and using shorter values causes the install Job to silently skip database setup — the Job will still report success, but the wiki will be non-functional.

The file already includes the other Minikube-local defaults such as `global.image.*`, `wikiEnv.configEnv.EDITION`, `wikiServicesCombineWebAndTask`, `wikiEnv.extraEnvFrom`, and the `wire` env wiring.

Or keep `values-local.yaml` unchanged and override the placeholders at install time with `--set-string`:

```bash
helm install bluespice . -n bluespice \
  -f values-local.yaml \
  --set-string wikiEnv.configEnv.WIKI_INITIAL_ADMIN_PASS='your-admin-password' \
  --set-string statefulBackendServices.database.secrets.MARIADB_ROOT_PASSWORD='your-root-password' \
  --set-string statefulBackendServices.database.secrets.MARIADB_PASSWORD='your-wiki-password'
```

For the initial login, use the admin user from `wikiEnv.configEnv.WIKI_INITIAL_ADMIN_USER`.
By default that is `Admin`. The password is either the value you set in `WIKI_INITIAL_ADMIN_PASS` or the generated one stored at `/data/initialAdminPassword` after install:

```bash
kubectl exec -n bluespice deployment/wiki-web -c wiki-web -- cat /data/initialAdminPassword
```

When you access the wiki through `kubectl port-forward`, keep `WIKI_HOST` on `localhost` and `WIKI_PORT` on `8080` in `values-local.yaml`. A hostname like `wiki.local` or a mismatching public port will make the login redirect point to an unreachable URL on your machine.

## Platform-Specific Notes

The following sections are based on the stack we tested in Minikube. Other platforms are marked as untested and may need additional adjustment.

### Minikube

- Use `values-local.yaml`.
- Minikube usually provides `ReadWriteOnce` only, while the chart default for `wiki-pvc` is `ReadWriteMany`.
- Keep `wikiServicesCombineWebAndTask: true` for local RWO storage.

### kind (untested)

- `kind` local-path storage is typically `ReadWriteOnce`.
- Use the same approach as minikube (`wikiServicesCombineWebAndTask: true`, `ReadWriteOnce`).
- Set `wikiServicesVolume.wiki-pvc.storageClassName` to your actual class (often `standard` or `local-path`).

### Managed Kubernetes (EKS/GKE/AKS) (untested)

- Verify whether your StorageClass supports `ReadWriteMany`.
- If RWX is unavailable, switch to RWO + `wikiServicesCombineWebAndTask: true`.
- Review ingress class and annotations (`ingress.ingressClassName`, `ingress.ingressAnnotations`) for your controller.

### OpenShift (untested)

- Review pod security settings (`global.podSecurityContext`, `global.containerSecurityContext`).
- You may need to set `fsGroup` depending on your SCC and storage setup.

## Configuration

All values can be overridden by passing `-f your-values.yaml` to `helm install`/`helm upgrade`.  
**Never commit passwords to version control.** Pass secrets via a separate values file excluded from git, or via `--set`.

### Required — must be set before install

| Value | Description |
|---|---|
| `statefulBackendServices.database.secrets.MARIADB_ROOT_PASSWORD` | MariaDB root password |
| `statefulBackendServices.database.secrets.MARIADB_PASSWORD` | MariaDB password for the wiki user |

### Wiki

| Value | Default | Description |
|---|---|---|
| `wikiEnv.configEnv.WIKI_NAME` | `BlueSpice` | Name of the wiki |
| `wikiEnv.configEnv.WIKI_LANG` | `en` | Wiki language |
| `wikiEnv.configEnv.WIKI_HOST` | `localhost` | Public hostname (used in URLs and emails) |
| `wikiEnv.configEnv.WIKI_PORT` | `80` | Public port |
| `wikiEnv.configEnv.WIKI_PROTOCOL` | `http` | `http` or `https` |
| `wikiEnv.configEnv.EDITION` | `free` | `free` (Docker Hub) or `pro` (private registry) |
| `wikiEnv.configEnv.WIKI_INITIAL_ADMIN_USER` | `Admin` | Username of the initial admin account |
| `wikiEnv.configEnv.WIKI_INITIAL_ADMIN_PASS` | _(empty = auto-generate)_ | Initial admin password — read from `/data/initialAdminPassword` after install |

Read the generated admin password after install:
```bash
kubectl exec -n bluespice deployment/wiki-web -c wiki-web -- cat /data/initialAdminPassword
```

### Images

| Value | Default | Description |
|---|---|---|
| `global.image.repository` | `bluespice` | Registry/org for the wiki image (`bluespice/wiki`) |
| `global.image.backendrepo` | `bluespice` | Registry/org for backend images (diagram, pdf, …) |
| `global.image.helperName` | `helper` | Init-container image name (private registries may use `k8s-helper`) |
| `global.image.wikiTag` | `5.2` | Wiki image tag |
| `global.image.backendTag` | `5.2` | Backend image tag |
| `global.imagePullPolicy` | `IfNotPresent` | Image pull policy |
| `global.regcred` | _(empty)_ | Base64-encoded Docker config JSON for private registry pull secret |

### Storage

| Value | Default | Description |
|---|---|---|
| `wikiServicesVolume.wiki-pvc.storageClassName` | _(cluster default)_ | StorageClass for the wiki PVC |
| `wikiServicesVolume.wiki-pvc.accessModes` | `["ReadWriteMany"]` | Use `["ReadWriteOnce"]` together with `wikiServicesCombineWebAndTask: true` if RWX is unavailable |
| `wikiServicesVolume.wiki-pvc.resources.requests.storage` | `5Gi` | Wiki PVC size |
| `wikiServicesCombineWebAndTask` | `false` | Run wiki-web and wiki-task in the same pod (required when using RWO storage) |

### Database

| Value | Default | Description |
|---|---|---|
| `wikiEnv.configEnv.DB_HOST` | `database` | Database hostname |
| `wikiEnv.configEnv.DB_USER` | `bluespice` | Database user |
| `wikiEnv.configEnv.DB_NAME` | `bluespice` | Database name |
| `statefulBackendServices.database.enabled` | `true` | Deploy the bundled MariaDB — set to `false` to use an external database |
| `statefulBackendServices.database.secrets.MARIADB_ROOT_PASSWORD` | _(empty)_ | **Required** — MariaDB root password |
| `statefulBackendServices.database.secrets.MARIADB_PASSWORD` | _(empty)_ | **Required** — MariaDB wiki user password |

To use an **external database**, set `statefulBackendServices.database.enabled: false` and provide `wikiEnv.secretEnv.DB_PASS`.

### Search (OpenSearch)

Disabled by default. Enable to get full-text search:

```yaml
statefulBackendServices.search:
  enabled: true
wikiEnv:
  configEnv:
    SEARCH_HOST: search
    SEARCH_PORT: "9200"
    SEARCH_PROTOCOL: http
```

### Optional Services

| Value | Default | Description |
|---|---|---|
| `ai.enabled` | `false` | Enable AI service connection |
| `statefulBackendServices.search.enabled` | `false` | Enable bundled OpenSearch |

### Ingress

| Value | Default | Description |
|---|---|---|
| `ingress.tls` | `true` | Enable TLS on the Ingress |
| `ingress.tlsSecret` | `wiki-ingress-cert` | TLS Secret name |
| `ingress.ingressClassName` | _(empty)_ | Ingress class |
| `ingress.ingressAnnotations` | `{}` | Additional Ingress annotations |

## Local Development

For local development, use the [Minikube notes](#minikube) in [Platform-Specific Notes](#platform-specific-notes) together with `values-local.yaml`.

## Upgrade

```bash
helm upgrade bluespice . -n bluespice -f values-local.yaml
```

The post-install Job does **not** run on upgrade. To run database updates manually after an upgrade:
```bash
kubectl exec -n bluespice deployment/wiki-web -c wiki-web -- /app/bin/run-updates
```

## Further Documentation

- [BlueSpice Installation Guide (Docker)](https://en.wiki5.bluespice.com/wiki/Setup:Installation_Guide/Docker)
- [BlueSpice Wiki image documentation](https://github.com/hallowelt/docker-bluespice-wiki/blob/main/README.md)
- [Support & contact](https://bluespice.com/contact/)
- [Community forums](https://community.bluespice.com/)
