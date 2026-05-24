/**
 * experimento_asr1.js — ASR-1 (Latencia)
 * 
 * Verifica que el Microservicio de Reportes mantiene P95 ≤ 100ms
 * bajo carga progresiva de hasta 900 usuarios concurrentes.
 * 
 * Uso:
 *   k6 run experimento_asr1.js
 * 
 * Duración: ~13 minutos
 */
import http from 'k6/http';
import { check, sleep } from 'k6';

const ALB = 'http://biteco-alb-308585655.us-east-1.elb.amazonaws.com';

export const options = {
  stages: [
    { duration: '2m', target: 100 },
    { duration: '2m', target: 200 },
    { duration: '2m', target: 400 },
    { duration: '2m', target: 600 },
    { duration: '2m', target: 800 },
    { duration: '2m', target: 900 },
    { duration: '1m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<100'],
    'checks{check:status valido}': ['rate==1'],
  },
};

export default function () {
  const res = http.get(
    `${ALB}/api/reportes/mensual?empresa_id=1&mes=3&anio=2026`
  );
  check(res, {
    'status valido': (r) => r.status === 200 || r.status === 401,
  });
  sleep(1);
}