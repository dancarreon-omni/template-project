# Gestión de Releases — GitHub Actions

Versionado semántico automatizado a través de ***dev*** → ***stg*** → ***preprod*** → ***main***.
Las versiones usan estrictamente `MAJOR.MINOR.PATCH` — sin sufijos en el número en sí, solo en los tags de git para trazabilidad interna.

No se requiere acceso a servidores del cliente. El artefacto distribuible se adjunta directamente al GitHub Release y el cliente lo descarga desde ahí.

---

## Estrategia de Ramas

```
main      ← Producción. Fuente de verdad. Siempre estable. Protegida.
preprod   ← Pre-Producción. Espejo exacto de producción. Protegida.
stg       ← Staging. Entorno de pruebas QA. Protegida.
dev       ← Integración. Aquí aterrizan todas las features. Protegida.

feat/*     ← Nueva funcionalidad o mejora.
fix/*      ← Corrección de bugs no críticos.
hotfix/*   ← Correcciones de emergencia en producción únicamente.
revert/*   ← Reversión de una feature excluida del release.
refactor/* ← Reestructuración de código sin nueva funcionalidad.
release/*  ← Rama de estabilización para un release específico.
chore/*    ← Mantenimiento: dependencias, configuración, scripts.
```

### Flujo de promoción entre ramas

```
feat/*     ──┐
fix/*      ──┤
revert/*   ──┼──► dev ──► stg ──► preprod ──► main
refactor/* ──┤                          ↑
chore/*    ──┤                          │
release/*  ──┘                          │
hotfix/*   ─────────────────────────────┘
               (hotfix va directo a main, luego se sincroniza a dev)
```

---

## Reglas de Incremento de Versión

| Evento                                        | Incremento | Ejemplo              |
|-----------------------------------------------|------------|----------------------|
| Feature mergeada a ***dev***                  | Ninguno    | se mantiene `1.1.0`  |
| ***dev*** promovido a ***stg***               | MINOR      | `1.1.0 → 1.2.0`     |
| ***stg*** promovido a ***preprod***           | Ninguno    | se mantiene `1.2.0`  |
| ***preprod*** promovido a ***main***          | Ninguno    | se mantiene `1.2.0`  |
| Hotfix mergeado a ***main***                  | PATCH      | `1.2.0 → 1.2.1`     |
| Incremento MAJOR manual (cambio disruptivo)   | MAJOR      | `1.2.1 → 2.0.0`     |

> El número de versión se define en ***stg*** y ese mismo número viaja sin cambios hasta ***main***.

---

## Archivos de Workflow

| Archivo              | Disparador                              | Propósito                                          |
|----------------------|-----------------------------------------|----------------------------------------------------|
| `ci.yml`             | Push a `feat/*`, `fix/*`, `refactor/*`, `chore/*`, `release/*`, PR a `dev` | Lint, pruebas, build + validación de título de PR |
| `deploy-stg.yml`     | Push a ***dev***                        | Bump MINOR + build + artefacto en Staging          |
| `deploy-preprod.yml` | Push a ***preprod***                    | Regresión + build + GitHub Release borrador        |
| `deploy-main.yml`    | Push a ***main***                       | Publicar GitHub Release + adjuntar ZIP + sync dev  |
| `hotfix.yml`         | Push/PR en `hotfix/*`                   | Bump PATCH + release de emergencia                 |
| `major-bump.yml`     | Manual (`workflow_dispatch`)            | Bump MAJOR para cambios disruptivos                |
| `estado-ambientes.yml` | Manual + automático post-deploy       | Reporte de versión activa en cada ambiente         |

---

## Secrets de GitHub Requeridos

Configurar en **Settings → Secrets and variables → Actions**:

| Secret              | Descripción                                                              |
|---------------------|--------------------------------------------------------------------------|
| `GH_PAT`            | Personal Access Token con scope `repo` (para hacer push de tags/commits) |

> Los secrets de URLs de servidores no son necesarios ya que no se despliega directamente a ningún servidor. El artefacto se adjunta al GitHub Release.

> La integración con Slack está disponible pero no activa. Si en el futuro se desea activar, agregar el secret `SLACK_WEBHOOK_URL` y reincorporar los pasos de notificación en cada workflow.

---

## Entornos de GitHub Requeridos

Configurar en **Settings → Environments**:

### `stg`
- Sin revisores requeridos (se activa automáticamente al hacer push a ***dev***)
- No requiere secrets de servidor

### `preprod`
- Revisores requeridos: Líder de QA (1 aprobación)
- No requiere secrets de servidor

### `prod`
- Revisores requeridos: Tech Lead + 1 más (se recomiendan 2 aprobaciones)
- Rama de despliegue permitida: solo ***main***
- No requiere secrets de servidor

---

## Flujo de Trabajo Diario del Desarrollador

```bash
# 1. Crear una nueva feature desde dev
git checkout dev
git pull origin dev
git checkout -b feat/S2-DASH-107-graficas-tiempo-real

# 2. Trabajar y hacer commits con formato de Conventional Commits
git commit -m "feat(dashboard): agregar componente de gráfica en vivo [S2-DASH-107]"
git commit -m "fix(dashboard): corregir etiquetas del eje de la gráfica [S2-DASH-107]"

# 3. Abrir PR a dev
#    → CI corre automáticamente (lint + pruebas + build)
#    → El equipo revisa el código
#    → PR se mergea cuando es aprobado

# 4. dev se despliega automáticamente a stg con bump MINOR
#    (1.1.0 → 1.2.0) y sube el artefacto a GitHub Actions

# 5. QA prueba en stg
#    Si aprueba → abrir PR: stg → preprod

# 6. preprod se despliega automáticamente (misma versión 1.2.0)
#    Corre regresión completa, se crea tag rc, se crea GitHub Release borrador

# 7. Aprobación del negocio → abrir PR: preprod → main
#    El workflow de producción requiere aprobación manual en GitHub UI
#    Tras la aprobación → v1.2.0 se publica como GitHub Release con el ZIP adjunto
```

---

## Flujo de Hotfix

```bash
# Producción (main) está en v1.2.0, se encontró un bug crítico

# 1. Crear rama desde el tag de producción (NO desde dev)
git checkout -b hotfix/timeout-de-pago v1.2.0

# 2. Corregir el bug
git commit -m "fix(pagos): manejar timeout del gateway de forma elegante [CRIT-205]"

# 3. Push de la rama — CI la valida automáticamente
git push origin hotfix/timeout-de-pago

# 4. Abrir PR: hotfix/timeout-de-pago → main
#    El workflow valida y requiere aprobación del entorno prod
#    Al mergear → versión sube a 1.2.1, se publica GitHub Release con ZIP

# 5. El workflow sincroniza automáticamente v1.2.1 de vuelta a dev
#    para que el próximo release (1.3.0) también incluya la corrección
```

---

## Escenario de QA Desordenado

El equipo tiene 10 devs. El Dev A y el Dev B ambos mergean a ***dev***.
La feature del Dev B es aprobada por QA en ***stg*** primero. La del Dev A aún está siendo probada.

**Con esta configuración: se despliegan juntos a stg o se espera al próximo sprint.**

Como `deploy-stg.yml` despliega lo que haya en ***dev***, todas las features mergeadas van a ***stg*** juntas. Aplica el modelo de Release Train:

- Tanto A como B mergean a ***dev*** durante el sprint
- ***stg*** se despliega con ambos (bump MINOR → 1.2.0)
- QA aprueba B, pero A falla QA
- **Opción 1 (recomendada):** Revertir A de ***dev***, nuevo deploy a ***stg*** sin A. A corrige los problemas y entra al siguiente sprint como parte de `1.3.0`
- **Opción 2:** Usar un feature flag para A — el código se despliega pero permanece desactivado hasta que A pase QA, luego se activa el flag sin necesidad de un nuevo deploy

```bash
# Opción 1: Revertir una feature específica de dev
git checkout dev
git revert <merge-commit-sha-de-feature-A>
git push origin dev
# dev ahora solo tiene B → nuevo deploy a stg sale sin A
```

---

## Flujo de Rama `revert/*`

Las ramas `revert/*` se usan para deshabilitar o revertir una feature que ya estaba mergeada en ***dev*** pero que no debe ir al próximo release.

```bash
# Feature A ya está en dev pero no pasa QA y el sprint se cierra

# 1. Crear rama de exclusión
git checkout dev
git checkout -b "revert/S2-DASH-107-graficas-tiempo-real"

# 2. Revertir el merge commit de la feature
git revert <merge-commit-sha-de-feature-A> --no-edit

# 3. Abrir PR a dev para aplicar la reversión
git push origin "revert/S2-DASH-107-graficas-tiempo-real"
# PR: revert/S2-DASH-107 → dev

# 4. Al mergearse, dev ya no tiene la feature A
#    El próximo deploy a stg saldrá limpio sin A
#    La feature A puede retomarse en el siguiente sprint con una rama feat/* nueva
```

---

## Convención de Nombres de Ramas y Commits

### Nombres de ramas

```
feat/ETAPA-TICKET-descripcion-corta      # Nueva funcionalidad
fix/ETAPA-TICKET-descripcion-corta       # Corrección de bug
hotfix/TICKET-descripcion-corta          # Emergencia en producción
revert/ETAPA-TICKET-descripcion-corta    # Reversión de feature
refactor/ETAPA-TICKET-descripcion-corta  # Reestructuración de código
release/X.Y.Z                            # Rama de estabilización de release
chore/ETAPA-TICKET-descripcion-corta     # Tarea de mantenimiento

# Ejemplos:
feat/S2-DASH-107-graficas-tiempo-real
fix/S1-API-031-respuesta-nula-en-busqueda
hotfix/CRIT-205-timeout-de-pago
revert/S2-NOTIF-112-notificaciones-push
refactor/S2-AUTH-088-extraer-logica-sesion
release/1.2.0
chore/S2-DEP-003-actualizar-dependencias
```

### Formato de commits (Conventional Commits)

```
feat(modulo): descripción corta [TICKET]
fix(modulo): descripción corta [TICKET]
chore(ci): descripción
docs(readme): descripción
BREAKING CHANGE: descripción del cambio disruptivo

# Ejemplos:
feat(dashboard): agregar gráfica en tiempo real [S2-DASH-107]
fix(api): manejar respuesta nula en búsqueda vacía [S1-API-031]
chore(ci): actualizar versión a 1.2.0
BREAKING CHANGE: migrar formato de token de autenticación
```

---

## Regla de Títulos de PR

Todo Pull Request apuntando a ***dev*** debe tener un título que comience con el prefijo del tipo de cambio, seguido de **dos puntos y un espacio**. Esta regla es validada automáticamente por `ci.yml` y **bloquea el merge** si no se cumple.

### Formato

```
prefijo: Descripción clara y concisa del cambio
```

### Prefijos válidos y ejemplos

| Prefijo | Cuándo usarlo | Ejemplo de título |
|---|---|---|
| `feat:` | Nueva funcionalidad | `feat: Agregar login con Google` |
| `fix:` | Corrección de bug | `fix: Corregir respuesta nula en búsqueda` |
| `hotfix:` | Corrección urgente en producción | `hotfix: Timeout en pasarela de pago` |
| `revert:` | Revertir una feature de dev | `revert: Revertir notificaciones push` |
| `refactor:` | Reestructuración sin nueva funcionalidad | `refactor: Extraer lógica de autenticación` |
| `release:` | Estabilización de un release | `release: Release versión 1.2.0` |
| `chore:` | Mantenimiento y tareas técnicas | `chore: Actualizar dependencias de seguridad` |

### ¿Qué pasa si el título no cumple el formato?

El job `validar-titulo-pr` dentro de `ci.yml` fallará y publicará automáticamente un comentario en el PR indicando el error y cómo corregirlo. El PR **no podrá mergearse** hasta que el título sea corregido (siempre que tengas activada la opción _"Require status checks to pass before merging"_ en la configuración de la rama `dev` en GitHub).

### Activar la protección en GitHub

Para que la validación realmente bloquee el merge:

1. Ir a **Settings → Branches → Branch protection rules**
2. Seleccionar o crear una regla para `dev`
3. Activar **"Require status checks to pass before merging"**
4. Buscar y agregar el check **"Validar Título del PR"**
5. Guardar

---

## Reporte de Estado de Ambientes

El workflow `estado-ambientes.yml` permite consultar en cualquier momento qué versión está activa en cada rama, sin necesidad de acceder a ningún servidor.

### Cómo ejecutarlo manualmente

1. Ir a **GitHub → Actions → Estado de Ambientes**
2. Clic en **Run workflow**
3. Seleccionar si mostrar el historial de releases (`true` por defecto)
4. Clic en **Run workflow**
5. Abrir la ejecución y ver el **Summary**

### Qué muestra el reporte

**Versión actual por ambiente**

| Ambiente | Versión | Último tag | Commit | Fecha | Último deploy |
|---|---|---|---|---|---|
| 🟢 main | `v1.0.3` | `v1.0.3` | `a3f9c12` | 2025-03-10 | Ana García |
| 🟡 preprod | `v1.0.3` | `v1.0.3-rc.1` | `a3f9c12` | 2025-03-09 | github-actions |
| 🔵 stg | `v1.0.4` | `v1.0.4-stg` | `b7e2d45` | 2025-03-14 | Carlos López |
| 🟣 dev | `v1.0.4` | — | `c1a8f33` | 2025-03-15 | María Torres |

**Diferencias entre ambientes**

| Comparación | Commits de diferencia | Estado |
|---|---|---|
| dev → stg | 0 | ✅ Sincronizado |
| stg → preprod | 8 | ⚠️ 8 commit(s) adelante |
| preprod → main | 0 | ✅ Sincronizado |
| dev → main (total) | 8 | ⚠️ 8 commit(s) adelante |

También incluye el historial de los últimos 5 releases en cada ambiente con fecha y autor.

### Cuándo se ejecuta automáticamente

Además de la ejecución manual, el reporte se regenera automáticamente al finalizar con éxito cualquier deploy:

- Después de cada deploy a ***stg*** (vía `deploy-stg.yml`)
- Después de cada deploy a ***preprod*** (vía `deploy-preprod.yml`)
- Después de cada release a ***main*** (vía `deploy-main.yml`)

Esto significa que siempre habrá una ejecución reciente con el estado actualizado, sin que nadie tenga que ejecutarlo manualmente.

### Caso de uso: desarrollador nuevo rastreando un bug

```bash
# Opción A — desde GitHub (sin instalar nada)
# 1. Ir a GitHub → Actions → Estado de Ambientes
# 2. Abrir la última ejecución exitosa
# 3. Clic en Summary — ver versión de cada ambiente al instante

# Opción B — desde la terminal
git fetch --all --tags

# Ver versión de cada rama directamente
git show origin/main:package.json    | grep '"version"'
git show origin/preprod:package.json | grep '"version"'
git show origin/stg:package.json     | grep '"version"'
git show origin/dev:package.json     | grep '"version"'

# Ver historial completo de releases
git tag --sort=-version:refname | grep -E "^v[0-9]+\.[0-9]+\.[0-9]+$"

# Ver todos los deploys de un ambiente específico
git tag --sort=-version:refname | grep "stg"
git tag --sort=-version:refname | grep "rc"

# Buscar en qué versión se introdujo un commit específico
git tag --contains <commit-sha> --sort=-version:refname
```

---

## El token GH_PAT

### ¿Por qué no alcanza con el token automático de GitHub?

GitHub Actions genera automáticamente un token llamado `GITHUB_TOKEN` en cada ejecución. Sin embargo, tiene una limitación de seguridad intencional: **los commits y tags que crea el `GITHUB_TOKEN` no disparan otros workflows**.

Esto rompe el flujo de promoción entre ambientes:

```
deploy-stg.yml hace commit de versión → push a dev
  → debería disparar deploy-preprod.yml... pero no lo hace
  → porque GITHUB_TOKEN no activa workflows subsecuentes
```

El `GH_PAT` es un Personal Access Token que sí dispara workflows, porque GitHub lo trata como un push de una persona real.

### ¿Es siempre necesario?

Depende de la configuración del repositorio:

| Situación | ¿Necesita GH_PAT? |
|---|---|
| Ramas protegidas (`dev`, `stg`, `preprod`, `main`) | **Sí** — `GITHUB_TOKEN` no puede hacer push a ramas protegidas |
| Sin branch protection | No estrictamente, pero sigue siendo necesario para que los commits del bot activen el siguiente workflow |
| Usando `workflow_dispatch` entre workflows | No — cada workflow llama al siguiente explícitamente sin necesitar un commit intermedio |

### Alternativa sin PAT (repositorio sin branch protection)

Activar en **Settings → Actions → General**:
- Workflow permissions → **"Read and write permissions"** ✅
- **"Allow GitHub Actions to create and approve pull requests"** ✅

Con esto el `GITHUB_TOKEN` nativo puede hacer push a ramas no protegidas. Si en algún momento se agregan reglas de protección de ramas, será necesario crear el PAT.

### Cómo crear el GH_PAT

1. Ir a **GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)**
2. Clic en **"Generate new token (classic)"**
3. Nombre sugerido: `CI_RELEASE_BOT`
4. Expiración: 1 año (renovar anualmente)
5. Scopes requeridos: marcar únicamente **`repo`** (incluye todo lo necesario)
6. Clic en **"Generate token"** y copiar el valor
7. Ir al repositorio → **Settings → Secrets and variables → Actions → New repository secret**
8. Nombre: `GH_PAT`, valor: el token copiado

> El token tiene los mismos permisos que tu cuenta. Se recomienda crear una cuenta de servicio dedicada (bot) para el equipo y generar el PAT desde esa cuenta, de modo que los commits automatizados aparezcan con un usuario neutro en lugar del tuyo personal.

---

## El archivo VERSION

Todos los workflows leen y escriben la versión desde un único archivo de texto plano llamado `VERSION`, ubicado en la raíz del repositorio:

```
VERSION          ← raíz del repositorio
```

### Contenido

El archivo contiene únicamente el número de versión en formato `MAJOR.MINOR.PATCH`, sin espacios ni saltos de línea adicionales:

```
1.4.2
```

### Por qué este enfoque es agnóstico al lenguaje

| Lenguaje | Archivo de manifiesto | Archivo de versión en este sistema |
|---|---|---|
| Node.js | `package.json` | `VERSION` |
| Python | `pyproject.toml` / `setup.py` | `VERSION` |
| PHP | `composer.json` | `VERSION` |
| Java | `pom.xml` | `VERSION` |
| .NET | `.csproj` | `VERSION` |
| Go | `go.mod` | `VERSION` |
| Ruby | `Gemfile` / `.gemspec` | `VERSION` |
| Cualquier otro | — | `VERSION` |

> El archivo de manifiesto del lenguaje (si existe) **no necesita actualizarse** con la versión — ese archivo gestiona dependencias, no el versionado del release. Si tu equipo prefiere mantener la versión sincronizada en ambos lados, puede hacerse con un paso adicional en el workflow, pero no es requerido por este sistema.

### Crear el archivo por primera vez

```bash
echo "0.1.0" > VERSION
git add VERSION
git commit -m "chore: inicializar archivo VERSION"
```

Si el archivo no existe cuando se ejecuta `bump-version.sh`, el script lo crea automáticamente con `0.0.0`.

---

## Scripts

### `.github/scripts/bump-version.sh`

Lee el archivo `VERSION` en la raíz del repositorio, incrementa la parte especificada, escribe el resultado y exporta `nueva_version` como output de GitHub Actions.

Este script es completamente agnóstico al lenguaje de programación — no depende de `package.json`, `pyproject.toml`, `.csproj`, `pom.xml` ni ningún otro archivo de manifiesto. La versión vive únicamente en `VERSION`.

```bash
chmod +x .github/scripts/bump-version.sh
./.github/scripts/bump-version.sh minor   # 1.1.0 → 1.2.0
./.github/scripts/bump-version.sh patch   # 1.2.0 → 1.2.1
./.github/scripts/bump-version.sh major   # 1.2.1 → 2.0.0
```

---

## Resumen de Tags de Git Generados Automáticamente

| Tag                  | Creado en           | Propósito                                    |
|----------------------|---------------------|----------------------------------------------|
| `v1.2.0-stg`         | Deploy a ***stg***  | Trazabilidad del build en staging            |
| `v1.2.0-rc.1`        | Deploy a ***preprod*** | Marca el release candidate                |
| `v1.2.0`             | Deploy a ***main*** | Tag de producción limpio y definitivo        |
| `v1.2.1`             | Hotfix a ***main*** | Corrección de emergencia                     |
| `v2.0.0-hito`        | Bump MAJOR manual   | Marcador de inicio de nueva versión mayor    |
