const { test } = require('node:test');
const assert = require('node:assert/strict');
const { isValidTitle } = require('../src/validators');

test('rechaza titulos vacios o solo espacios', () => {
  assert.equal(isValidTitle(''), false);
  assert.equal(isValidTitle('   '), false);
  assert.equal(isValidTitle(undefined), false);
});

test('rechaza titulos mayores a 255 caracteres', () => {
  assert.equal(isValidTitle('a'.repeat(256)), false);
});

test('acepta titulos validos', () => {
  assert.equal(isValidTitle('Configurar pipeline CI/CD'), true);
});
