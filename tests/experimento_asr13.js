/**
 * experimento_asr13.js — ASR-13 (Mantenimiento)
 * 
 * Verifica que el redespliegue de MS-Reportes no genera errores
 * en MS-Usuario ni MS-Nubes.
 * 
 * Uso:
 *   k6 run experimento_asr13.js
 * 
 * Procedimiento:
 *   1. Correr este script
 *   2. Al minuto 1, reiniciar MS-Reportes en EC2
 *   3. Verificar 0% errores en ms_usuario y ms_nubes
 */
import http from 'k6/http';
import { check, sleep } from 'k6';

const ALB = 'http://biteco-alb-308585655.us-east-1.elb.amazonaws.com';

export const options = {
  scenarios: {
    ms_usuario: {
      executor: 'constant-vus',
      vus: 10,
      duration: '3m',
      exec: 'testUsuario',
    },
    ms_nubes: {
      executor: 'constant-vus',
      vus: 10,
      duration: '3m',
      exec: 'testNubes',
    },
    ms_reportes: {
      executor: 'constant-vus',
      vus: 10,
      duration: '3m',
      exec: 'testReportes',
    },
  },
  thresholds: {
    'http_req_failed{scenario:ms_usuario}': ['rate==0'],
    'http_req_failed{scenario:ms_nubes}': ['rate==0'],
  },
};

export function testUsuario() {
  const res = http.get(`${ALB}/health-check/`);
  check(res, { 'MS-Usuario OK': (r) => r.status === 200 });
  sleep(1);
}

export function testReportes() {
  const res = http.get(`${ALB}/health-check/`);
  check(res, { 'MS-Reportes responde': (r) => r.status === 200 || r.status === 502 });
  sleep(1);
}

export function testNubes() {
  const res = http.get(`${ALB}/api/nubes/consumo?empresa_id=1&mes=3&anio=2026`);
  check(res, { 'MS-Nubes OK': (r) => r.status === 200 });
  sleep(1);
}