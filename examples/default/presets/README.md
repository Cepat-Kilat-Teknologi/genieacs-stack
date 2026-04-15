# GenieACS Preset Bundles

This directory ships declarative preset bundles that pair with
**[genieacs-relay](https://github.com/Cepat-Kilat-Teknologi/genieacs-relay)**
versions. A preset is a GenieACS configuration document that tells
the server to refresh specific TR-069 parameter paths on every device
inform, so the relay's read endpoints always return fresh data.

> **Why preset bundles?** GenieACS only stores the subset of TR-069
> parameters declared in an active preset or provision. Parameters
> that the CPE supports but that are NOT declared will never show
> up in the device tree — reads against them return empty.
>
> Relay v2.1.x only needed DeviceInfo + WLAN fields, which most
> vendors include in the default inform payload. Relay v2.2.0 adds
> endpoints that read richer data (associated WiFi clients, per-radio
> stats, PPPoE uptime, diagnostic result fields). Those reads return
> empty unless the corresponding paths are declared. The bundles in
> this directory fill the gap.

---

## `isp-saas-default.json` (paired with genieacs-relay v2.2.0+)

Declares 51 parameter paths covering the read endpoints added by
genieacs-relay v2.2.0. Groups and rationale:

| Group | Paths | Age (s) | Why | Relay endpoint consumer |
|---|---|---|---|---|
| **DeviceInfo** — identification | Manufacturer, ModelName, HardwareVersion | 86400 | Rarely changes | H1 `/status/{ip}` |
| **DeviceInfo** — software version | SoftwareVersion | 3600 | May change after firmware upgrade | H1 `/status/{ip}` |
| **DeviceInfo** — uptime | UpTime, SerialNumber | 60 / 86400 | UpTime for `online` flag; serial for search | H1 `/status/{ip}`, M5 `/devices/search` |
| **WAN PPP connection** | ConnectionStatus, ExternalIPAddress, Username, Uptime, LastConnectionError | 60 / 300 | Live PPPoE session state | H4 `/wan/{ip}` |
| **WAN IP connection** | ConnectionStatus, ExternalIPAddress, Uptime, AddressingType | 60 / 3600 | DHCP/static WAN path | H4 `/wan/{ip}` |
| **Associated WiFi clients** | AssociatedDeviceMACAddress, {X_,}SignalStrength, AuthenticationState | 60 | Client list changes frequently | M3 `/wifi-clients/{ip}` |
| **WiFi radio config** | Channel, TransmitPower, X_TXPower | 300 | Channel/power changes rarely | M7 `/wifi-stats/{ip}` |
| **WiFi radio stats** | Total{Bytes,Packets}{Sent,Received}, Errors{Sent,Received} | 60 | Traffic counters | M7 `/wifi-stats/{ip}` |
| **IPPingDiagnostics** — result fields | DiagnosticsState, {Success,Failure}Count, {Average,Min,Max}ResponseTime | 30 | Populated after diagnostic runs | M1 `/diag/ping/{ip}` result poll via `/params` |
| **TraceRouteDiagnostics** — result fields | DiagnosticsState, ResponseTime, RouteHopsNumberOfEntries, RouteHops.*.{HostAddress,HopHostAddressType,HopRTTimes} | 30 | Populated after diagnostic runs | M2 `/diag/traceroute/{ip}` result poll via `/params` |
| **WLAN MAC filter verify** | WLANAccessControlMode, WLANAccessControlEntry.*.MACAddress | 300 | Readback after write | L5 `/mac-filter/{ip}` |
| **Port forwarding verify** | PortMapping.*.{PortMappingEnabled,Protocol,ExternalPort,InternalClient,InternalPort,Description} | 300 | Readback after write | L1 `/port-forwarding/{ip}` |
| **Static DHCP verify** | DHCPStaticAddress.*.{Enable,Chaddr,Yiaddr} | 300 | Readback after write | L6 `/static-dhcp/{ip}` |

**Wildcards** (`*`) match any instance number. Used for multi-radio
WLAN (`WLANConfiguration.*`), variable-count associated clients
(`AssociatedDevice.*`), and multi-instance config objects
(`PortMapping.*`, `DHCPStaticAddress.*`).

**Age semantics:** the value represents the maximum staleness GenieACS
will tolerate before asking the CPE to re-send the parameter. Lower
values give fresher data at the cost of more TR-069 traffic; higher
values spare the device but may return stale values. The defaults in
this bundle are tuned for typical ISP deployments — operators are
free to tighten or relax per-path based on field experience.

---

## Installing the preset

### Option 1 — via genieacs-relay v2.2.0+ (recommended)

If you already have genieacs-relay v2.2.0 running, install the preset
through the relay's `PUT /api/v1/genieacs/presets/{name}` endpoint —
this is a nice self-contained path that uses the v2.2.0 L10 metadata
endpoint to bootstrap the very preset bundle that enriches the other
v2.2.0 endpoints.

```bash
curl -X PUT http://<relay-host>:8080/api/v1/genieacs/presets/isp-saas-default \
  -H "Content-Type: application/json" \
  -H "X-API-Key: <your-api-key>" \
  --data-binary @isp-saas-default.json
```

Expected response: `202 Accepted` with message
`Preset operation dispatched via GenieACS NBI.`

Verify the preset was accepted:

```bash
curl http://<relay-host>:8080/api/v1/genieacs/presets/isp-saas-default \
  -H "X-API-Key: <your-api-key>"
```

Expected: `200 OK` with the preset body echoed back.

### Option 2 — via GenieACS NBI directly

```bash
curl -X PUT http://<genieacs-host>:7557/presets/isp-saas-default \
  -H "Content-Type: application/json" \
  --data-binary @isp-saas-default.json
```

Expected: `200 OK` (GenieACS NBI does not return a body on PUT).

### Option 3 — via the GenieACS Web UI

1. Open the GenieACS UI at `http://<genieacs-host>:3000`
2. Navigate to **Admin → Presets**
3. Click **New** and paste the JSON body from
   `isp-saas-default.json`
4. Save

---

## Uninstalling

```bash
curl -X DELETE http://<relay-host>:8080/api/v1/genieacs/presets/isp-saas-default \
  -H "X-API-Key: <your-api-key>"
```

or via NBI:

```bash
curl -X DELETE http://<genieacs-host>:7557/presets/isp-saas-default
```

Device trees that were enriched by the preset will retain the already-fetched
values until the next inform — GenieACS does not actively purge data on
preset removal.

---

## Vendor caveats

Some parameter paths in this bundle are **vendor-specific extensions**:

- `X_SignalStrength` — ZTE, Huawei, FiberHome residential ONUs. Devices
  without this field still report via the standard `SignalStrength` path
  (also declared) so the relay falls back automatically.
- `X_TXPower` — ZTE / Huawei vendor extension. Standard
  `TransmitPower` path is declared as the primary.
- `LAN*.WLANConfiguration.*.Stats.*` — TR-098 standard but some CPE
  firmware implementations omit it. Absence → empty WiFi stats, not a
  hard error.

Paths that are missing on a specific device will simply not appear in
the device tree — the relay gracefully returns what's available and
doesn't fail the request.
