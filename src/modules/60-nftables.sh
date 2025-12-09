#!/usr/bin/env bash

step_60_nftables() {
  log_step "[9/12] Configurando nftables (firewall base + conntrack + IPv6 DROP)..."

  cat >/etc/nftables.conf <<'EOF'
flush ruleset

table inet firewall {

  chain input {
    type filter hook input priority 0;
    policy drop;

    # 0) IPv6 completamente deshabilitado (también está en sysctl)
    meta nfproto ipv6 drop

    # 1) Loopback siempre permitido
    iif "lo" accept

    # 2) Conntrack básico
    ct state invalid limit rate 5/minute burst 5 packets \
      log prefix "NFT INVALID: " counter drop
    ct state established,related accept

    # 3) ICMPv4 básico (necesario para que IPv4 funcione bien)
    ip protocol icmp icmp type {
      echo-request, echo-reply,
      destination-unreachable,
      time-exceeded,
      parameter-problem
    } accept

    # 4) Fragmentos raros
    ip frag-off & 0x1FFF != 0x0 limit rate 5/minute burst 5 packets \
      log prefix "NFT FRAG BLOQ: " counter drop

    # 5) Scans TCP típicos
    tcp flags == 0x0  limit rate 5/minute burst 5 packets \
      log prefix "NFT NULL SCAN: " counter drop

    tcp flags == 0xFF limit rate 5/minute burst 5 packets \
      log prefix "NFT XMAS SCAN: " counter drop

    tcp flags & (fin | syn) == fin | syn limit rate 5/minute burst 5 packets \
      log prefix "NFT SYN-FIN: " counter drop

    tcp flags & (syn | rst) == syn | rst limit rate 5/minute burst 5 packets \
      log prefix "NFT SYN-RST: " counter drop

    # 6) SSH (único puerto abierto por defecto)
    #    Limit más alto para no romper orquestación (Ansible, etc.)
    tcp dport 22 ct state new \
      limit rate 100/second burst 200 packets \
      counter accept

    # 7) Todo lo demás: drop (silencioso, con contador)
    counter drop
  }

  chain forward {
    type filter hook forward priority 0;
    policy drop;
  }

  chain output {
    type filter hook output priority 0;
    policy accept;
  }
}
EOF

  systemctl enable nftables.service >/dev/null 2>&1 || true
  systemctl restart nftables.service

  echo "  -> nftables activo:"
  nft list ruleset || true
}
