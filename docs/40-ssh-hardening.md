# SSH Hardening – Debian 13 (Trixie)

Este documento describe la baseline de endurecimiento SSH empleada en este proyecto para servidores Debian 13.  
La configuración está alineada con CIS Debian Benchmark (sección 5.1.x), OpenSSH Security Guidelines y prácticas modernas de criptografía aplicada.

---

## 🎯 Objetivos del hardening SSH

- Reducir superficie de ataque del servicio SSH.
- Eliminar algoritmos inseguros o legacy.
- Forzar el uso de primitives criptográficas modernas.
- Aplicar límites para mitigar fuerza bruta y abuso de conexiones interactivas.
- Mejorar telemetría, auditoría y trazabilidad.
- Minimizar información expuesta al cliente.

---

## 🔐 Configuración principal aplicada (`sshd_config`)

### 1. **Protocolo y versiones**

```conf
Protocol 2
HostKeyAlgorithms rsa-sha2-512,rsa-sha2-256,ssh-ed25519
```

**Motivo:**  
Protocol 1 está obsoleto. RSA con SHA-1 queda fuera.

---

### 2. **Intercambio de claves (KexAlgorithms)**

```conf
KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256
```

**Motivo:**  
- `sntrup761x25519` → resistente a ataques cuánticos (hybrid PQ).  
- Curve25519 → rápida, segura y estándar de facto.

---

### 3. **Cifrados (Ciphers)**

```conf
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
```

**Motivo:**  
- ChaCha20 para hardware sin AES-NI.  
- AES-GCM para hosts con aceleración.

---

### 4. **MACs (Message Authentication Codes)**

```conf
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
```

**Motivo:**  
Modos **ETM (Encrypt-Then-MAC)** evitan varios ataques de padding y timing.

---

### 5. **Parámetros de tiempo y control de sesiones**

```conf
LoginGraceTime 20
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
MaxSessions 3
MaxStartups 10:30:60
```

**Motivo:**  
- Gracia mínima para reducir bots.  
- Control de keepalive.  
- Mitigación de fuerza bruta y conexiones en abanico.

---

### 6. **Endurecimiento de autenticación**

```conf
PermitRootLogin no
PermitEmptyPasswords no
PasswordAuthentication no
KbdInteractiveAuthentication no
UsePAM yes
AuthenticationMethods publickey
PubkeyAuthentication yes
```

**Motivo:**  
- Solo clave pública.  
- Root jamás por SSH.  
- Sin contraseñas → reduce superficie a 0 ante fuerza bruta.

---

### 7. **Aislamiento y restricciones adicionales**

```conf
AllowTcpForwarding no
X11Forwarding no
AllowAgentForwarding no
PermitUserEnvironment no
GatewayPorts no
```

**Motivo:**  
Mitiga abuso lateral y túneles no autorizados.

---

### 8. **Banner y auditoría**

```conf
Banner /etc/issue.net
LogLevel VERBOSE
```

**Motivo:**  
- Banner legal (CIS 1.6.x).  
- VERBOSE registra fingerprint de llaves → útil en auditoría forense.

---

### 9. **Restricciones por usuario / grupo (opcional avanzado)**

Ejemplo:

```conf
Match User deploy
    AllowTcpForwarding yes
    ForceCommand internal-sftp
```

---

## 📁 Ubicación de ficheros relevantes

```
/etc/ssh/sshd_config
/etc/ssh/moduli
/etc/ssh/ssh_host_*_key
/etc/issue.net
```

---

## 🔍 Hardening de /etc/ssh/moduli

Se eliminan primeros grupos Diffie-Hellman inseguros:

```bash
awk '$5 >= 3071' /etc/ssh/moduli > /etc/ssh/moduli.safe
mv /etc/ssh/moduli.safe /etc/ssh/moduli
```

---

## 🧪 Verificación y test

### 1. Probar sintaxis

```bash
sshd -t
```

### 2. Ver Kex negociados

```bash
ssh -vvv usuario@host
```

### 3. Comprobar soporte PQ

```bash
grep sntrup /var/log/auth.log
```

---

## 🔒 Recomendaciones operativas

- Desplegar claves **ed25519** para acceso normal.  
- Usar RSA 4096 solo como fallback.  
- Rotar claves anualmente.  
- Habilitar MFA basado en hardware (FIDO2/U2F) cuando sea posible.  
- Registrar huellas de claves en inventario de seguridad.

---

## ✔ Cumplimiento CIS (mapeo rápido)

| CIS Section | Control aplicado |
|------------|------------------|
| 5.1.1–5.1.3 | Permisos ficheros SSH |
| 5.1.4       | Access control / Match rules |
| 5.1.5       | Banner configurado |
| 5.1.6–5.1.15 | Kex, Ciphers, MACs |
| 5.1.19–5.1.22 | Root login, empty passwords, PAM |

El mapeo completo aparecerá en `cis/mapping-level2.md`.

---

## 📚 Referencias

- OpenSSH Security Guidelines  
- CIS Debian Linux Benchmark v1.1.0  
- NIST SP 800-57 / SP 800-131A  
- IETF draft: sntrup761 + x25519  
