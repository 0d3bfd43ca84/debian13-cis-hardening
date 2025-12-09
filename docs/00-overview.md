# 00 – Overview: Debian 13 Hardening Baseline

Este documento presenta la arquitectura general del **Hardening Pack para Debian 13**, una colección modular diseñada para obtener una base segura, auditable y alineada con los requisitos del **CIS Debian Benchmark** (Level 2), endurecimiento del kernel y buenas prácticas operativas.

El repositorio está organizado en módulos independientes que pueden aplicarse de forma conjunta o selectiva según el perfil del servidor.

---

## 1. Objetivos del proyecto

- Proporcionar una línea base de seguridad reproducible para servidores Debian 13 (Trixie).  
- Reducir superficie de ataque y reforzar controles de seguridad críticos.  
- Cumplir con las recomendaciones clave del CIS Benchmark v1.1.0.  
- Integrarse con mecanismos modernos (AppArmor, nftables, auditd).  
- Mantener compatibilidad con entornos de automatización (Ansible, Terraform).  
- Servir como base para auditorías de seguridad PCI-DSS / ISO 27001.  

> Esta baseline prioriza **servidores productivos expuestos** o con requisitos de cumplimiento.  
> No está orientada a entornos de escritorio ni contenedores.

---

## 2. Estructura de los módulos

El directorio `docs/` organiza cada área de hardening de forma independiente.

```
docs/
 ├── 00-overview.md
 ├── 10-nftables.md
 ├── 20-fail2ban.md
 ├── 30-auditd.md
 ├── 40-ssh-hardening.md
 ├── 50-apparmor.md
 └── 60-kernel-tuning.md
```

Cada módulo incluye:

- **Objetivos**
- **Configuración recomendada**
- **Racionales** (por qué se aplica)
- **Comandos de verificación**
- **Mapeo rápido a CIS Benchmark**
- **Referencias técnicas**

---

## 3. Descripción de módulos

### 3.1 10 – nftables baseline  
Firewall estricto con política DROP, mitigación de scans, rate-limit SSH y bloqueo completo de IPv6 (opcional).  
Define la capa defensiva principal.

### 3.2 20 – Fail2ban  
Protección activa frente a fuerza bruta.  
Integración mediante nftables, logging estructurado y jails mínimas pero efectivas.

### 3.3 30 – auditd  
Reglas de auditoría completas alineadas con CIS 4.1.x:  
identidad, privilegios, tiempo, cambios del kernel, AppArmor y eventos sensibles.  
Incluye configuración segura de overflow y preservación de logs.

### 3.4 40 – SSH Hardening  
Reemplazo completo del `sshd_config` para reforzar criptografía, autenticación, límites de sesión y logging.  
Incluye Kex híbridos PQ, ciphers modernos y políticas restrictivas.

### 3.5 50 – AppArmor  
Habilitación obligatoria del perfil MAC, enforcement de perfiles del sistema y auditoría de cambios.  
Fortalece servicios clave (sshd, nginx, chrony, system utilities).

### 3.6 60 – Kernel & sysctl Hardening  
Restricciones del kernel orientadas a seguridad:  
ASLR, ptrace, kexec, dmesg, spoofing, redirects, rate-control y protección IPv6.  
Mitigaciones de nivel bajo contra exploitación y tráfico malicioso.

---

## 4. Flujo recomendado de aplicación

```
1) Configurar nftables
2) Aplicar kernel tuning (sysctl)
3) Endurecer SSH
4) Habilitar AppArmor en enforce
5) Aplicar reglas auditd
6) Habilitar Fail2ban
```

Ordenado por impacto en red → kernel → servicios → auditoría → respuesta activa.

---

## 5. Alcance y exclusiones

### Incluido
- Hardening para servidores Debian 13 minimalistas o productivos.  
- Seguridad base para VPS, bare-metal o nodos críticos.  
- Endurecimiento de red, kernel, SSH, servicios y auditoría.  

### Excluido
- Contenedores Docker/Podman (rompe defaults).  
- Escritorios gráficos o entornos de usuario.  
- Infraestructuras con requisitos específicos IPv6-only.  
- Sistemas que dependan de módulos bloqueados (USB storage, squashfs).  

---

## 6. Auditoría y cumplimiento

El repositorio facilita verificaciones CIS mediante:

```
lynis audit system
nft list ruleset
auditctl -l
aa-status
sshd -t
sysctl -a
```

El mapeo completo aparecerá en:

```
docs/cis/mapping-level2.md
```

---

## 7. Referencias

- **CIS Debian Benchmark v1.1.0**  
- Debian Security Guide  
- Kernel Documentation  
- OpenSSH Security Guidelines  
- nftables & AppArmor Documentation  

---

## 8. Notas finales

Este hardening está diseñado como línea base **productiva y conservadora**.  
Puede adaptarse a entornos más restrictivos (modo “high security”) o más flexibles según el rol del servidor.
