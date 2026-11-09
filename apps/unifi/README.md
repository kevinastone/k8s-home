# UniFi Controller Routing & Health Architecture

This directory configures external ingress routing and dashboard discovery for the physical UniFi Dream Machine / UniFi OS Console located outside the Kubernetes cluster at `192.168.20.1`.

## Current Setup & Architectural Limitations

### 1. External Envoy Gateway Backend (`backend.yaml`)

UniFi OS runs on dedicated external hardware and exhibits specific protocol quirks:

- **TLS & Self-Signed Certificates**: UniFi OS uses self-signed HTTPS certificates on port 443 (`insecureSkipVerify: true`).
- **WebSocket over TLS Negotiation**: UniFi OS advertises HTTP/2 support during ALPN negotiation, but its WebSocket endpoints only support HTTP/1.1 upgrade handshakes and lack RFC 8441 Extended CONNECT support.
- **Vendor-Specific CRD**: We currently use Envoy Gateway's vendor-specific [`gateway.envoyproxy.io/v1alpha1 Backend`](./backend.yaml) with `appProtocols: [gateway.envoyproxy.io/wss]` to enforce HTTP/1.1 upstream for WebSocket upgrades over TLS.

### 2. Homepage Health Check Stub (`deployment.yaml`)

- Homepage discovers the UniFi dashboard entry via annotations on [`http-route.yaml`](./http-route.yaml).
- Homepage's Kubernetes service integration expects in-cluster pods to verify availability via `gethomepage.dev/pod-selector: "app.kubernetes.io/name=unifi"`.
- Direct Homepage ping checks (e.g. `gethomepage.dev/ping: "https://192.168.20.1"`) fail or produce inconsistent results due to external network routing boundaries and self-signed certificate validation inside the Homepage container.
- To prevent Homepage from marking the UniFi service as degraded or offline, a lightweight stub pause container ([`deployment.yaml`](./deployment.yaml) running `registry.k8s.io/pause`) is deployed solely to satisfy the `pod-selector` health check.

## Future Enhancements & Upstream Dependencies

We intend to eliminate both the vendor-specific `Backend` resource and the stub pause deployment once upstream Gateway API and Envoy Gateway capabilities mature:

1. **Standard Gateway API (X)Backend Support**:

   - Upstream Kubernetes Gateway API is evolving standard backend delegation and policy mechanisms (such as standard Backend / `BackendTLSPolicy` / Backend extensions).
   - Once Envoy Gateway fully supports standard Gateway API backend extension specifications for IP endpoints, custom protocol enforcement, and upstream TLS skip-verify, the vendor-specific `gateway.envoyproxy.io/v1alpha1 Backend` can be replaced with standardized manifests.

1. **Native Gateway / Controller Health Probing**:

   - Once Envoy Gateway or Homepage supports native external upstream health checking integrated with Gateway API status conditions or HTTPRoute status, Homepage can consume health status directly without requiring the stub `unifi-health` pause deployment.
