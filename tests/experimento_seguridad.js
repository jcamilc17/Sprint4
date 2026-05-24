/**
 * experimento_seguridad.js — ASR-S4-SEG (Seguridad)
 * 
 * Verifica que el rate limiting bloquea al atacante (≥90% con 429)
 * mientras los usuarios legítimos siguen siendo atendidos con P95 ≤ 100ms.
 * 
 * Uso:
 *   k6 run experimento_seguridad.js
 * 
 * Duración: 3 minutos
 * Grupos: 500 VUs atacante + 100 VUs legítimos
 */
import http from 'k6/http';
import { check, sleep } from 'k6';

const ALB = 'http://biteco-alb-308585655.us-east-1.elb.amazonaws.com';
const ENDPOINT = '/api/reportes/mensual?empresa_id=1&mes=3&anio=2026';

export const options = {
  scenarios: {
    atacante: {
      executor: 'constant-vus',
      vus: 500,
      duration: '3m',
      exec: 'testAtacante',
    },
    legitimo: {
      executor: 'constant-vus',
      vus: 100,
      duration: '3m',
      exec: 'testLegitimo',
    },
  },
  thresholds: {
    'http_req_duration{scenario:legitimo}': ['p(95)<100'],
  },
};

export function testAtacante() {
  const res = http.get(`${ALB}${ENDPOINT}`);
  check(res, {
    'Atacante bloqueado 429': (r) => r.status === 429,
  });
  // Sin sleep — flood continuo
}

export function testLegitimo() {
  const res = http.get(`${ALB}${ENDPOINT}`);
  check(res, {
    'Legítimo responde': (r) => r.status === 200 || r.status === 401,
  });
  sleep(1);
}