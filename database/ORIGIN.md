# Procedencia de los archivos de base de datos

Los archivos SQL y shell, y `compose.test.yaml` de la raíz, son copias sin cambios del paquete `db-proyecto` entregado por el equipo el 18/10/2026. Se incorporan para que la integración sea reproducible al clonar el backend y en GitHub Actions, sin depender de otra carpeta local.

`original-checksums.json` conserva los SHA-256 originales de esos diez archivos. `npm run db:verify` y el lanzador de integración comprueban su integridad antes de usarlos. Las reglas de `.gitattributes` conservan los finales LF de SQL/shell/YAML en todos los sistemas.

No se copian credenciales, volúmenes, respaldos ni datos de la base de desarrollo. El entorno de pruebas usa únicamente la definición original de `compose.test.yaml` y su semilla ficticia en una base temporal.

Matías conserva la responsabilidad sobre la cadena SQL. Las actualizaciones deben proceder de sus migraciones revisadas y actualizar su procedencia; no modificar una migración ya aplicada ni generar otra cadena Prisma Migrate.
