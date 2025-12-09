# 10 – nftables Hardening Baseline (Debian 13)

Firewall baseline para servidores Debian 13 (Trixie) utilizando **nftables**.  
Diseñada para cumplir controles del CIS Debian Benchmark (sección 3.x), minimizar superficie de ataque y ofrecer un filtrado estricto, predecible y auditable.

Esta configuración está orientada a servidores expuestos públicamente o en entornos de seguridad reforzada.

---

## 1. Objetivos

- Política por defecto **DROP** en todas las cadenas.
- Bloqueo completo de **IPv6** (cuando no se usa).
- Endurecimiento de **conntrack**.
- Mitigación de scans (NULL, XMAS, SYN-FIN, SYN-RST).
- Rate-limit seguro para SSH compatible con automatización (Ansible).
- Registros mínimos pero útiles para análisis forense.
- Compatibilidad con servicios estándar sin abrir puertos inesperadamente.

---

## 2. Estructura del firewall

La política se organiza en:

```
/etc/nftables.conf
└── table inet filter {
        chains: input, forward, output
        reglas: baseline + hardening
    }
```

Se utiliza **tabla inet** para unificar IPv4 e IPv6 (aunque IPv6 se bloquea explícitamente).

---

## 3. Reglas principales

### 3.1 Política por defecto

```nft
table inet filter {
    chain input {
        type filter hook input priority 0;
        policy drop;
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
```

- `input` DROP → control total de tráfico entrante.
- `output` ACCEPT → simplifica servidores que consumen APIs externas.

---

### 3.2 Aceptación de tráfico esencial

```nft
# Loopback
ip saddr 127.0.0.1 accept
ip6 saddr ::1 accept

# Paquetes establecidos/relacionados
ct state established,related accept
```

---

### 3.3 Bloqueo total de IPv6 (si no se utiliza)

```nft
ip6 nexthdr icmpv6 drop
ip6 drop
```

> *Advertencia:* solo aplicar cuando IPv6 no se use en absoluto.

---

### 3.4 Protección contra scans y tráfico malformado

#### NULL scan:

```nft
tcp flags == 0x00 drop
```

#### XMAS scan:

```nft
tcp flags & (fin|psh|urg) == (fin|psh|urg) drop
```

#### SYN-FIN / SYN-RST:

```nft
tcp flags & (syn|fin) == (syn|fin) drop
tcp flags & (syn|rst) == (syn|rst) drop
```

---

### 3.5 SSH con rate-limit (compatible automation)

```nft
tcp dport 22 ct state new limit rate 3/second burst 10 accept
tcp dport 22 drop
```

**Motivo:**  
- Permite flujos legítimos de Ansible/SSH.  
- Bloquea barridos de fuerza bruta / bots.

---

### 3.6 ICMP seguro

```nft
ip protocol icmp icmp type echo-request limit rate 2/second accept
ip protocol icmp drop
```

ICMP limitado → mantiene diagnóstico sin abrir vectores de flooding.

---

### 3.7 Registros mínimos (opcional)

```nft
limit rate 2/second log prefix "nftables-drop: " group 1
```

Evita floods del journal.

---

## 4. Servicio systemd para nftables

Archivo: `/etc/systemd/system/nftables.service.d/override.conf`

```ini
[Service]
ExecStartPost=/usr/sbin/nft list ruleset
```

Muestra el ruleset activo al iniciar (útil durante auditorías).

---

## 5. Comprobaciones

### 5.1 Validación sintaxis

```bash
nft -c -f /etc/nftables.conf
```

### 5.2 Ver reglas activas

```bash
nft list ruleset
```

### 5.3 Monitorizar actividad

```bash
journalctl -t kernel -g nftables
```

---

## 6. Puertos típicos a abrir (según rol)

Ejemplos:

```nft
tcp dport 80 accept
tcp dport 443 accept
tcp dport 8333 accept   # Bitcoin Core
```

Mantener la mínima superficie posible.

---

## 7. Mapeo rápido a CIS Benchmark

| CIS Control | Implementación |
|-------------|----------------|
| 3.4.x       | Política por defecto DROP |
| 3.5.x       | nftables como firewall principal |
| 3.5.1.1     | Deny IPv6 si no se usa |
| 3.5.2.x     | Reglas explícitas, tráfico establecido, loopback |
| 3.5.3.x     | SSH controlado y limitado |
| 3.6.x       | Logging controlado |

El mapeo completo aparecerá en `../cis/mapping-level2.md`.

---

## 8. Referencias

- CIS Debian Benchmark v1.1.0 (secciones 3.x)
- nftables Wiki & Documentation
- RedHat Security Guide – nftables hardening
