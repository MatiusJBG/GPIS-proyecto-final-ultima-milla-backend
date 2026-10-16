import { createApp } from './create-app.js';
import { loadConfig } from './config.js';

const config = loadConfig(process.env);
const app = createApp({ webOrigin: config.webOrigin });
const server = app.listen(config.port, () => {
  process.stdout.write(`API escuchando en http://localhost:${config.port}\n`);
});

for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.once(signal, () => {
    server.close((error) => {
      if (error) {
        process.stderr.write(`${error.message}\n`);
        process.exitCode = 1;
      }
    });
  });
}
