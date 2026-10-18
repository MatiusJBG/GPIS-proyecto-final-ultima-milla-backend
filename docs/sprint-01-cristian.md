# Sprint 01 · Cristian: integración con la base original

Estado: implementación backend e integración PostgreSQL verificadas localmente. Pendientes de cierre: revisión del contrato por Jhon/Alexis, PR revisado, CI/Sonar y recorrido web que corresponden al equipo. No declarar todo el sprint Done solo por este resultado.

Fecha: 18/10/2026, America/Guayaquil. Ejecutor: Codex asistiendo a Cristian. Base Git: `478582925cec21fec18782de53d66dc12db1ae0f`. Rama: `feature/sprint-01-cristian-orders`. La implementación se entrega en esta rama; el commit base identifica únicamente el punto de partida.

## Tareas

| Tarea | Resultado |
|---|---|
| T06 | Contrato OpenAPI canónico de siete operaciones, respuestas y errores compatibles con la base de Jhon; actualizado a las reglas y estados SQL reales. Pendiente revisión y copia versionada por frontend. |
| T11 | Revisados tipos, funciones, permisos, estado activo de zona y errores de las cuatro migraciones originales. Lookup real lee `is_active`; la API rechaza una zona inactiva sin insertar. |
| T12 | Registro separado del pedido persistido, estado inicial pendiente, puertos puros y Clock. Identidad/creación no dependen del cliente ni del reloj del dominio. |
| T13 | Un schema introspectado y una fábrica Prisma; bootstrap comparte cliente con rol app. Altas mediante funciones autorizadas y lectura del resultado dentro de transacción; cierre del cliente al detener la API. |
| T17 | ListOrders/GetOrder reutilizan consulta y mapper. Filtros AND por entrega, colección vacía válida, UUID y filtros validados; tipos de día/hora preservados sin convertirlos a UTC. |
| T23 | Verificados adaptadores y reglas con PostgreSQL real, permisos mínimos y datos aislados. Pendientes los reportes externos Sonar/CI y la revisión del equipo. |
| T27 | Núcleo Orders sin dependencias de Node/Express/Prisma/SQL/configuración; mapper y errores técnicos en bordes. Tipos mínimos de cliente compartidos en infraestructura, sin dependencia de Zones hacia Orders. |

## Paquete conservado

Se utiliza el `db-proyecto` descomprimido por el usuario. No se editaron sus migraciones, funciones, permisos, scripts, semilla, Compose ni manuales. Se compararon SHA-256 de todos sus archivos originales con un manifiesto tomado antes del arranque: sin diferencias. Solo se creó el `.env` local con contraseñas aleatorias y puerto propio; no se publican sus valores.

Docker responde en modo Linux. PostgreSQL `18.6-alpine` está healthy; cuatro migraciones, once tablas y dos vistas. Digest observado: `postgres@sha256:77f585114c32fbca283dc835b0596f4e52b51b4c6662d7810b2f4084f60a1873`.

Desarrollo usa `127.0.0.1:15432/logistica`: 5432 estaba bloqueado y otro proyecto ya ocupaba 5433. Se conservaron ambos servicios ajenos. La base de desarrollo permanece sin pedidos de prueba: cero registros comprobados; no se cargó la semilla opcional allí.

La introspección leyó el esquema mediante credenciales de mantenimiento proporcionadas solo a ese proceso. Generó once modelos en `prisma/schema.prisma`, sin modificar PostgreSQL. Prisma advierte que no representa todos los CHECK/triggers; las migraciones SQL siguen siendo la autoridad. CLI/Client/adapter están fijados en `7.10.1`, versión estable, y hay una sola fábrica por proceso de API.

## Reglas y compatibilidad

- El rol `logistica_app` tiene EXECUTE de `create_order` y no tiene INSERT directo sobre orders: permisos comprobados sin modificarlos.
- SQL devuelve el UUID al crear. El adaptador realiza alta y consulta en una transacción, y no responde éxito hasta que se confirma, incluyendo restricciones diferidas.
- Día/hora se proyectan como textos de entrega; createdAt/updatedAt provienen de PostgreSQL. Los campos adicionales del cliente se ignoran, incluidos id/status/createdAt.
- Estados reales: pendiente, asignado_a_ruta, recogido, en_camino y entregado.
- La función original rechaza altas con fecha pasada usando SQLSTATE 22007. Se conserva esa regla y se traduce a VALIDATION_ERROR/400. Las consultas de fechas históricas siguen permitidas.
- Lookup real informa actividad de zona. El campo opcional del puerto conserva compatibilidad con el repositorio en memoria anterior; el arranque real siempre inyecta el lookup Prisma que sí informa active.
- Conflictos únicos se traducen a DATA_CONFLICT; ausencia de zona a ZONE_NOT_FOUND; validaciones de entrada conocidas a VALIDATION_ERROR; fallos técnicos a PERSISTENCE_UNAVAILABLE sin mensajes del driver ni SQL.

## Evidencia observada

Entorno: Windows x64, Node 24.11.0, npm 11.6.1, Prisma 7.10.1. Las comprobaciones locales corresponden a la implementación de esta rama. El resultado de CI debe consultarse sobre el SHA publicado.

| Comprobación | Resultado |
|---|---|
| Arranque original | Healthy; 4 migraciones / 11 tablas / 2 vistas. |
| Introspección/generación | 11 modelos; cliente generado. Solo lectura de PostgreSQL. |
| Suite SQL del paquete | PASS integridad, capacidad, fecha/zona, transiciones, historial, idempotencia, rollback y privilegios. |
| Concurrencia SQL | PASS al último cupo, sin pérdida ni sobrecapacidad. |
| Suite única HTTP/Prisma/PostgreSQL | 3 suites, 32 pruebas aprobadas. Rol real de aplicación; sin simular persistencia. |
| Reproducibilidad de integración | Segunda ejecución desde otro contenedor limpio: 32/32, SQL y concurrencia aprobados. Salida en `docs/evidence/sprint-01-postgres.txt`; exit code 0. |
| Instalación final | `npm ci` aprobado; cliente Prisma generado automáticamente, sin operación DDL. |
| Tipos y calidad | typecheck, typecheck:test, ESLint y build aprobados después de la instalación limpia. |
| Modo de regresión | 30 aprobadas y 2 variantes exclusivas de PostgreSQL omitidas; mismos archivos de suite. |
| API sobre desarrollo | GET /health, /zones y /orders responden 200 en localhost:3000. Zonas/pedidos vacíos; sin cargar la semilla de demostración. |
| Revisión anterior en memoria | 18 pruebas heredadas y exploración de 50 solicitudes aprobadas antes de integrar la base. Esos resultados anteriores no se usan como aceptación de las reglas SQL actuales. |

La primera ejecución del runner SQL sin configuración de sesión falló en concurrencia con `relation zones does not exist`: las conexiones nuevas del administrador no seleccionaban el esquema. Se repitió el mismo script original con `PGOPTIONS=-csearch_path=logistica,pg_catalog` exclusivamente para sus sesiones; pasó. No se alteró el search_path persistente de ningún rol ni los archivos de base.

SHA-256 del contrato final local: `a71ead7ee35e67176861ea9dd09f7d979fda6598157e7c2cf167a37e527f03d4`. Frontend debe registrar el hash y el commit real que se aprueben, no el commit base ni el hash de una versión anterior.

## Casos de backend

- CP-003: alta/consulta, validación y conflictos de zonas por HTTP con PostgreSQL real.
- CP-005: registro/recuperación, campos ausentes e inválidos, JSON mal formado y ausencia de inserciones rechazadas. El texto con apariencia de SQL se conserva como dirección literal.
- CP-009: separación explícita de creación y entrega posterior, conservación al recuperar, metadatos del cliente ignorados y filtros AND. Fixture de doce pedidos tomada de `database/seeds/demo.sql` original para el entorno real; conteos 12/6/4/2/0 y contenido de la intersección comprobados.
- CP-010: pedido para el día real en Guayaquil; variantes de fecha pasada y zona inactiva verificadas con la base original.

Se extendieron los mismos archivos de Jest/Supertest de Jhon para usar repositorios reales cuando el lanzador configura TEST_DATABASE_URL; no se creó otra suite API ni pruebas unitarias. El modo en memoria queda disponible únicamente como regresión.

## Aislamiento y reproducción

El paquete original de pruebas está incorporado sin cambios y con diez hashes verificados; DATABASE_PACKAGE_DIR=. lo selecciona. También puede apuntar a la copia externa idéntica. Ejecutar `npm run test:integration:postgres`. El lanzador usa un nombre Compose único, la definición test original, tmpfs y un puerto efímero local. Primero ejecuta los scripts SQL originales y luego Jest contra el rol app. La limpieza valida identidad del contenedor, nombre del proyecto y base logistica_test antes de truncar datos exclusivamente temporales. Conserva schema_migrations y reutiliza la semilla del paquete. El finally elimina solo los contenedores/red y archivo temporal de esa ejecución; nunca el volumen de desarrollo.

No se ejecutaron Prisma Migrate/db push, migraciones nuevas, cambios de permisos, cambios de SQL, restauraciones ni borrado de volúmenes. No se ha ejecutado el recorrido frontend CP-015 ni completado CP-016 con ambos reportes Sonar/CI. El PR y el resultado de CI se registrarán al publicar la rama. SonarQube local está activo; su análisis espera recuperar el acceso a la cuenta admin.
