# OpenCode VPS Agent - AGENTS.md

## Misión

Desplegar un agente OpenCode 24/7 en un VPS, accesible desde cualquier dispositivo (móvil, tablet, laptop) mediante web browser, sin depender del estado de la máquina local.

### Audiencia objetivo
- Uso personal (dev playground)
- Un solo desarrollador: @adalgarcia
- Proyectos personales accesibles remoto

### Problema que resuelve
La máquina local se suspende, pierde conectividad, o simplemente se apaga. Con OpenCode en un VPS:
- El agente está siempre disponible
- Las sesiones persisten entre reinicios
- Se puede acceder desde el celular en cualquier momento
- No se pierde progreso en refactorizaciones o migraciones largas

### Contexto técnico
Adaptado de una guía original de Claude Code a OpenCode, aprovechando:
- **Cloudflare Tunnel** existente en el host (sin abrir puertos)
- **Docker Compose** para aislamiento y reproducibilidad
- **OpenCode Go** como proveedor de modelos (bajo costo, alta confiabilidad)

---

## Servidor de Implementación

| Parámetro | Valor |
|-----------|-------|
| IP del VPS | `172.9.30.113` |
| Usuario SSH | `ubuntu` |
| SSH Key | `/home/soporte/.ssh/id_rsa` |
| SO Host | Ubuntu 24.04 LTS |

### Conexión SSH
```bash
ssh -i /home/soporte/.ssh/id_rsa ubuntu@172.9.30.113
```

---

## Fases del Proyecto

| Fase | Estado |
|------|--------|
| Fase 1: Contenedor base | ✅ Completada |
| Fase 2: Autenticación OpenCode Go | ⬜ Pendiente |
| Fase 3: Tunnel + acceso remoto | ✅ Completada |
| Fase 4: GitHub + git | ⬜ Pendiente |
| Fase 5: Operación continua | ⬜ Pendiente |
| Fase 6: Post-MVP | ⬜ Pendiente |

---

## Stack Tecnológico

| Componente | Tecnología |
|------------|-----------|
| SO host | Ubuntu 24.04 LTS (VPS) |
| Contenedor | Docker + Docker Compose |
| Agente | OpenCode (binario estático) |
| Provider | OpenCode Go ($10/mes) |
| Tunnel | Cloudflare Tunnel (en el HOST) |
| CLI GitHub | gh |

---

## Arquitectura

```
HOST (VPS 172.9.30.113)           CONTENEDOR
─────────────────────────         ────────────────────────
SSH (port 22)                     opencode web
cloudflared (tunnel existente)    → expone :4096
  ├─ servicio A                   →        otro servicio
  └─ opencode.adalgarcia.com      → 4096   OpenCode Web UI
```
