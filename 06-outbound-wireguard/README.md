# 06 — Outbound WireGuard: the site dials the hub, nothing dials the site

The lab increment for the article *Connecting Edge Sites Through NAT*. Every
connection in this topology starts at the edge site and travels outward to the
hub. The customer's router forwards nothing in: there is no port forward, no
inbound VPN endpoint, and no rule anyone from the fleet side would have to ask
for.

## What it proves

1. **The site is unreachable from outside.** Before the tunnel exists, the hub
   has no route into the site's network at all, and nothing at the site accepts
   a new inbound session.
2. **One outbound dial creates the whole path.** The edge server sends its
   first WireGuard packet outward. The customer's router NATs it outward and
   keeps the mapping. That mapping is the only reason return traffic can come
   back.
3. **The hub learns the site at the NAT's address, never the site's.** Look at
   `wg show` on the hub: the peer's endpoint is the router's WAN address and a
   port the router chose by itself. Nobody configured a port forward to make
   that happen.
4. **A 25-second keepalive holds the mapping open**, so the hub can reach the
   site through the tunnel at any time without ever initiating a connection to
   the customer's network.

## Topology

```
                    "the internet"                the customer's network
                 192.168.77.0/24                   192.168.78.0/24
                ┌───────────────┐   ┌─────────────┐   ┌────────────────┐
                │      hub      │   │ nat (router)│   │      edge      │
                │ 192.168.77.10 │◄──│  .77.2/.78.2│◄──│  192.168.78.10 │
                │  wg0 10.77.0.1│   │  NAT out →  │   │  wg0 10.77.0.2 │
                │ UDP/51820 open│   │ forward: nil│   │ dials out only │
                └───────────────┘   └─────────────┘   └────────────────┘
```

- `hub` — the central cluster. Listens on UDP 51820 and answers. It never
  dials a site; the site's own outbound packets are what give the hub a return
  path. The site's LAN range is installed as an unreachable route, the way
  production hubs have no path into a customer's network.
- `nat` — stands in for the customer's firewall. It does exactly what a
  customer's router does: masquerades the LAN outward, forwards nothing in,
  accepts no new inbound session. The one exception is SSH from the harness's
  management interface, the way a customer's admin reaches their router from
  their own side. Nothing in this lab ever configures it from the fleet side.
  (The router takes `.2` on both networks: the host takes `.1` on VirtualBox
  host-only networks.)
- `edge` — the edge server at the site. It dials the hub, keeps the mapping
  alive with `PersistentKeepalive = 25`, and is the only machine that ever
  initiates anything. Its default gateway is the router, so every packet out
  crosses it, exactly as at a real site.

## Running it

```bash
cd 06-outbound-wireguard
vagrant up
```

The first `up` takes a few minutes (three Debian VMs, `apt` inside each). The
`nat` VM's iptables rules and all WireGuard state re-apply on every boot, so
`vagrant reload` leaves the topology in the same shape.

Key exchange happens through the shared folder at provision time: the hub
writes `keys/hub.pub`, the edge waits for it, publishes `keys/edge.pub`, and
the hub admits exactly that key as `10.77.0.2`. The `keys/` directory is
generated at run time and git-ignored; regenerate the whole lab by deleting it.

Three demo commands, one per machine:

```bash
vagrant ssh hub  -c /vagrant/scripts/demo.sh
vagrant ssh nat  -c /vagrant/scripts/demo.sh
vagrant ssh edge -c /vagrant/scripts/demo.sh
```

What each shows:

- **hub** — the failed route into the site's LAN, the failed dial to the site,
  and then `wg show`: the peer present, its endpoint the router's translated
  address, a fresh handshake, and a successful ping to `10.77.0.2` through the
  tunnel the site created.
- **nat** — the router's entire configuration: one MASQUERADE rule outward,
  zero DNAT rules, and a FORWARD chain that only lets established traffic back
  in.
- **edge** — `wg show` from the site's side: persistent keepalive every 25
  seconds, the hub's address as its endpoint, and a ping to `10.77.0.1`.

## What this increment does not prove

One hub, one site, one tunnel. No k3s on the edge server yet, no application
releases down the tunnel, no OS plane, no additional ring sites, and no
multiple-sites-per-hub addressing. Each of those arrives with the article that
claims it.
