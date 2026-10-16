# API de logística de última milla

API independiente del repositorio web. El composition root vive en `src/bootstrap`; `createApp(dependencies)` se puede componer por separado de la entrada que ejecuta `listen`. Las capas Domain y Application quedan libres de Express, SQL, variables de entorno y IO.

## Versiones fijadas

- Node.js 24.11.0 (`.nvmrc`) y npm 11.
- TypeScript 6.0.3.
- Express 5.3.0.

El `package-lock.json` de este repositorio fija las dependencias instaladas. Prisma y la conexión a PostgreSQL se configuran en el trabajo de base de datos, siguiendo exclusivamente su manual.

## Estructura

```text
src/
  bootstrap/                  configuración de proceso, composición y listen
  modules/
    zones/{domain,application/ports,application/use-cases,infrastructure/postgres,presentation/http}/
    orders/{domain,application/ports,application/use-cases,infrastructure,presentation/http}/
```

Las carpetas de módulos quedan preparadas para sus responsables. `GET /health` informa que el proceso HTTP está activo.

## Comandos

```powershell
npm ci
npm run dev
npm run typecheck
npm run build
npm start
```

La API usa `PORT` (predeterminado `3000`) y `WEB_ORIGIN` (predeterminado `http://localhost:5173`). Copia `.env.example` a `.env` para la configuración local de la aplicación. Ninguna variable `VITE_*` ni cliente web contiene credenciales.
