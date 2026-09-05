import { test } from 'node:test';
import assert from 'node:assert/strict';
import { effectiveness, matchupChart, BEATS } from '../src/combat/natures.js';

test('the chakra wheel is a closed 5-cycle', () => {
  const start = 'fire';
  let cur = start;
  const seen = [];
  for (let i = 0; i < 5; i++) { seen.push(cur); cur = BEATS[cur]; }
  assert.equal(cur, start);
  assert.deepEqual(seen, ['fire', 'wind', 'lightning', 'earth', 'water']);
});

test('weakness deals double, resistance deals half, otherwise neutral', () => {
  assert.equal(effectiveness('fire', 'wind'), 2);
  assert.equal(effectiveness('wind', 'lightning'), 2);
  assert.equal(effectiveness('lightning', 'earth'), 2);
  assert.equal(effectiveness('earth', 'water'), 2);
  assert.equal(effectiveness('water', 'fire'), 2);

  assert.equal(effectiveness('wind', 'fire'), 0.5);
  assert.equal(effectiveness('fire', 'water'), 0.5);
  assert.equal(effectiveness('water', 'earth'), 0.5);

  assert.equal(effectiveness('fire', 'lightning'), 1);
  assert.equal(effectiveness('physical', 'fire'), 1);
  assert.equal(effectiveness('cursed', 'water'), 1);
  assert.equal(effectiveness('fire', null), 1);
});

test('matchup chart lists beats/weakTo for each nature', () => {
  const chart = matchupChart();
  assert.equal(chart.length, 5);
  const fire = chart.find((r) => r.nature === 'fire');
  assert.equal(fire.beats, 'wind');
  assert.equal(fire.weakTo, 'water');
  assert.equal(fire.row.wind, 2);
  assert.equal(fire.row.water, 0.5);
});
