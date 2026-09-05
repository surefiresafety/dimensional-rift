// Tutorial scenes: maps, interactables and dialogue.
// Tile legend:
//   # wall/building   . floor   , grass   = road   ~ water   T training post
//   D door            P PC/TV    C abandoned car   X dimensional tear
//   S Spider-Man      K Kakashi  G gap (needs Web-Swing)   B boulder (needs Web-Pull)
//   H Hokage's office marker     E wild encounter zone      @ player start
export const SCENES = {
  bedroom: {
    name: 'Your Bedroom — New York City',
    palette: { '.': '#5b4636', '#': '#2b2118', P: '#3b6ea5', D: '#8b5a2b', W: '#9ab7ff' },
    map: [
      '##########',
      '#W......P#',
      '#........#',
      '#..@.....#',
      '#........#',
      '#........#',
      '########D#',
    ],
    intro: [
      { speaker: '', text: 'The sky outside the window is glowing a strange, glitchy purple...' },
      { speaker: '', text: 'Tip: walk up to the TV (blue) and press SPACE to interact.' },
    ],
  },
  nyc: {
    name: 'Times Square — New York City',
    palette: { '=': '#3a3a3f', '.': '#6b6b70', '#': '#1e2230', C: '#c23b3b', X: '#b06cff', S: '#e02b2b' },
    map: [
      '####################',
      '#..................#',
      '#.=====C======C===.#',
      '#.================.#',
      '#.==C======S=====C.#',
      '#.=========X======.#',
      '#.================.#',
      '#.====C=======C===.#',
      '#..................#',
      '#########@##########',
    ],
    intro: [
      { speaker: '', text: 'Cars sit abandoned in the road. In the centre, Spider-Man strains to hold a glowing tear shut with his webs.' },
    ],
  },
  konoha: {
    name: 'Training Grounds — Hidden Leaf Village',
    palette: { ',': '#3f8a3a', '.': '#5a9b52', '#': '#1f4a1b', T: '#8b5a2b', '~': '#2f6fb5', G: '#2f6fb5', B: '#777', H: '#d9a441', E: '#3f8a3a', K: '#b7c4cf' },
    map: [
      '####################',
      '#,,,,,,,,,,,,,,,,,H#',
      '#,,T,,,,,,,,,,,,,,,#',
      '#,,,,,@,,,,,,,,,,,,#',
      '#,,T,,,,,,,,,,,B,,,#',
      '#,,,,,,,,,,,,,,#,,,#',
      '#,,T,,,,,,,,,,,#,,,#',
      '#~~~~~~~G~~~~~~#EEE#',
      '#,,,,,,,,,,,,,,#EEE#',
      '#,,,,,,,,,,,,,,#EEE#',
      '#,,,,,,,,,,,,,,#,,,#',
      '#,,,,,,,,,,,,,,,,,,#',
      '####################',
    ],
  },
};

// --- Dialogue sequences -----------------------------------------------------

export const DIALOGUE = {
  news: [
    { speaker: 'TV', text: 'BREAKING: "A massive energy spike has been detected in Times Square! Authorities urge everyone to stay indoors."' },
    { speaker: 'You', text: 'Times Square... that\'s where the purple light is coming from. I have to see this.' },
    { speaker: '', text: 'Tip: head to the door (bottom) to leave.' },
  ],
  doorLocked: [{ speaker: 'You', text: 'Something\'s happening outside. I should check the TV first.' }],

  spidey: [
    { speaker: 'Spider-Man', text: 'Hey, kid! Little dangerous out here for a stroll! Whatever is on the other side of this portal is leaking some really bad energy.' },
    { speaker: 'You', text: 'I want to help!' },
    { speaker: 'Spider-Man', text: 'No way, you don\'t even have a... wait, look out!' },
    { speaker: '', text: 'A small Cursed Spirit crawls out of the portal!' },
    { speaker: 'Spider-Man', text: 'I can\'t let go of the portal! Here, catch!' },
    { speaker: 'SYSTEM', text: 'You equipped the Web-Shooter! (Skill Unlocked: Web-Stun)', flag: 'webShooter' },
    { speaker: '', text: 'You raise the Web-Shooter at the monster... but the portal shudders and DESTABILIZES!' },
    { speaker: '', text: 'With a deafening roar, you and the monster are sucked into the rift!', flag: 'toKonoha' },
  ],

  konohaWake: [
    { speaker: 'You', text: 'Where am I? This isn\'t New York...' },
    { speaker: '', text: 'Wooden training posts stand in a grassy clearing. Suddenly, the Cursed Spirit from the portal lands in front of you!' },
    { speaker: '???', text: 'Hey! Duck!' },
    { speaker: '', text: 'A shuriken flies past your head and hits the monster! A silver-haired ninja steps out from the trees.' },
    { speaker: 'Kakashi', text: 'I don\'t know what that thing is... but my ninjutsu isn\'t working on it. Kid, whatever you have on your wrist, use it now!' },
  ],

  afterToad: [
    { speaker: 'SYSTEM', text: 'A golden glow surrounds you...' },
    { speaker: 'Kakashi', text: 'You copied its power? Incredible... you have a strange chakra, kid.' },
    { speaker: 'Kakashi', text: 'Come with me to the Hokage\'s office. We need to figure out how to get you home.' },
    { speaker: '', text: 'Objective: reach the Hokage\'s office marker (gold, top-right). Press TAB to manage your 4 skill slots.' },
  ],

  gap: [{ speaker: 'SYSTEM', text: 'A river blocks the way. Web-Swing! You fire a web at a branch and swing across.' }],
  gapNoWeb: [{ speaker: 'You', text: 'Too wide to jump. If only I had something to swing with...' }],
  boulder: [{ speaker: 'You', text: 'A huge boulder. My web isn\'t strong enough to pull this yet. (Web-Pull: learn it from Spider-Man later.)' }],
  hokage: [
    { speaker: 'Kakashi', text: 'This is as far as the prototype goes. Next stop: the Hokage\'s office, then Jujutsu High.' },
    { speaker: '', text: 'Thanks for playing the Dimensional Rift tutorial! Wander into the tall grass (east) to fight more enemies and collect skills.' },
  ],
  encounterHint: [{ speaker: '', text: 'Rustling in the grass... Enemies here drop new skills when defeated. Remember: only 4 can be equipped at once.' }],
};

export const ENCOUNTERS = ['cursed_spirit_grade4', 'rogue_ninja', 'cursed_toad'];
