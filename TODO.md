# GenieACS Stack — TODO

> Future enhancements for the GenieACS multiarch/multiplatform stack.
> Phase 1-6 completed on 2026-04-04. All 55 issues resolved (commit `ed5265b`).

---

## Security & Hardening

- [ ] **Read-only container filesystem** — Set `read_only: true` on all containers with `tmpfs` mounts for `/tmp`, `/var/log`, and GenieACS working directories. Reduces attack surface from container filesystem writes.

## Kubernetes & Helm

- [ ] **Bitnami MongoDB sub-chart** — Replace hand-rolled MongoDB StatefulSet with `bitnami/mongodb` as a Helm dependency. Gains automated backup, TLS, replica set support, and upstream maintenance.
- [ ] **Kubernetes Operator** — Evaluate building a custom Operator (Kubebuilder/operator-sdk) for GenieACS lifecycle management: automated upgrades, backup scheduling, and device provisioning workflows.
- [ ] **Multi-cluster ArgoCD** — Document external cluster targeting and ApplicationSet patterns for GitOps-managed multi-site TR-069 deployments.

## Platform Support

- [ ] **ARMv7 variant** — Offer a Node.js 22 LTS-based image for 32-bit ARM devices (Raspberry Pi 3, older IoT gateways). Node.js 24 dropped ARMv7 to experimental tier.

## Observability

- [ ] **Grafana dashboard** — Pre-built dashboard for GenieACS metrics: active CPE connections, NBI request rates, CWMP inform counts, and MongoDB performance. Export as JSON for import into existing Grafana instances.
