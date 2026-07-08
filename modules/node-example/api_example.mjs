// api_example.mjs  (run with: node api_example.mjs)
//
// Demonstrates every UHCO Directory API v1 endpoint.
// Requires Node 18+ (built-in fetch).
//
// NOTE: ColdFusion serializes all struct keys as UPPERCASE.
//       Every response field must be accessed in UPPERCASE (e.g. res.TOTAL, res.DATA).
//
// Usage:
//   1. Set TOKEN and SECRET below (or via environment variables).
//   2. node api_example.mjs

const BASE   = 'https://portal.opt.uh.edu/api/v1';
const TOKEN  = process.env.UHCO_TOKEN  || 'uhcs_5d4148ed-0649-6c40-fa900e1bd87c9d169b4f58fb';
const SECRET = process.env.UHCO_SECRET || '';   // leave blank if no secret needed

// ---------------------------------------------------------------------------
// Core request helper
// ---------------------------------------------------------------------------

async function apiGet(path, params = {}) {
  const url = new URL(BASE + path);
  for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v);

  const headers = { 'Authorization': `Bearer ${TOKEN}` };
  if (SECRET) headers['X-API-Secret'] = SECRET;

  const res = await fetch(url, { headers });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`HTTP ${res.status} ${res.statusText}: ${body}`);
  }
  return res.json();
}

// ---------------------------------------------------------------------------
// Examples
// ---------------------------------------------------------------------------

// 1. API root — available endpoints
const root = await apiGet('/');
console.log('=== API Info ===');
console.log(`${root.API} v${root.VERSION}`);
console.log('Endpoints:', root.ENDPOINTS);

// ---------------------------------------------------------------------------
// People list
// ---------------------------------------------------------------------------

// 2. All people — first page (default limit 50, max 500)
const list = await apiGet('/people', { limit: 10 });
console.log(`\n=== People list (total: ${list.TOTAL}) ===`);
list.DATA.forEach(p => {
  const name = p.NAMES?.[0];
  console.log(`  [${p.USERID}] ${name?.LASTNAME ?? '?'}, ${name?.FIRSTNAME ?? '?'}`);
});

// 3. Pagination — second page
const page2 = await apiGet('/people', { limit: 10, offset: 10 });
console.log(`\n=== People page 2 (offset 10) ===`);
console.log(`  Returned ${page2.DATA.length} of ${page2.TOTAL}`);

// 4. Search by name
const search = await apiGet('/people', { search: 'smith', limit: 5 });
console.log(`\n=== Search "smith" (${search.TOTAL} results) ===`);
search.DATA.forEach(p => {
  const name = p.NAMES?.[0];
  console.log(`  [${p.USERID}] ${name?.LASTNAME ?? '?'}, ${name?.FIRSTNAME ?? '?'}`);
});

// 5. Filter by flag (Clinical-Attending needs no secret)
const attending = await apiGet('/people', { flag: 'Clinical-Attending', limit: 5 });
console.log(`\n=== Clinical-Attending (${attending.TOTAL} total) ===`);
attending.DATA.forEach(p => {
  const name = p.NAMES?.[0];
  console.log(`  [${p.USERID}] ${name?.LASTNAME ?? '?'}, ${name?.FIRSTNAME ?? '?'}`);
});

// 6. Filter by flag — Current-Student (requires secret with Current-Student access)
const students = await apiGet('/people', { flag: 'Current-Student', limit: 5 });
console.log(`\n=== Current-Student (visible without/with secret: ${students.TOTAL}) ===`);
console.log('  First orgs:', students.DATA[0]?.ORGANIZATIONS ?? []);

// 7. Filter by organization
const orgFilter = await apiGet('/people', { org: 'OD Program', limit: 5 });
console.log(`\n=== OD Program members (${orgFilter.TOTAL}) ===`);
orgFilter.DATA.forEach(p => console.log(`  [${p.USERID}]`));

// 8. Filter by grad year (Alumni only — requires secret with Alumni access)
const gradYear = await apiGet('/people', { flag: 'Alumni', gradyear: 2022, limit: 5 });
console.log(`\n=== Alumni grad year 2022 (${gradYear.TOTAL}) ===`);

// ---------------------------------------------------------------------------
// Single person — full profile and sub-resources
// ---------------------------------------------------------------------------

// Use the first person from the list for sub-resource demos
const demoID = list.DATA[0]?.USERID;

if (demoID) {
  // 9. Full profile
  const person = await apiGet(`/people/${demoID}`);
  console.log(`\n=== Person ${demoID} ===`);
  console.log('  Names:   ', person.NAMES);
  console.log('  Orgs:    ', person.ORGANIZATIONS?.map(o => o.ORGNAME));
  console.log('  Flags:   ', person.FLAGS?.map(f => f.FLAGNAME));

  // 10. Flags only
  const flags = await apiGet(`/people/${demoID}/flags`);
  console.log(`\n=== Person ${demoID} flags ===`, flags.DATA);

  // 11. Organizations
  const orgs = await apiGet(`/people/${demoID}/organizations`);
  console.log(`\n=== Person ${demoID} orgs ===`, orgs.DATA?.map(o => o.ORGNAME));

  // 12. Addresses
  const addresses = await apiGet(`/people/${demoID}/addresses`);
  console.log(`\n=== Person ${demoID} addresses ===`, addresses.DATA);

  // 13. Emails
  const emails = await apiGet(`/people/${demoID}/emails`);
  console.log(`\n=== Person ${demoID} emails ===`, emails.DATA);

  // 14. Degrees
  const degrees = await apiGet(`/people/${demoID}/degrees`);
  console.log(`\n=== Person ${demoID} degrees ===`, degrees.DATA);

  // 15. Academic info (class year, program, etc.)
  const academic = await apiGet(`/people/${demoID}/academic`);
  console.log(`\n=== Person ${demoID} academic ===`, academic.DATA);

  // 16. Student profile (requires Current-Student secret)
  const studentProfile = await apiGet(`/people/${demoID}/studentprofile`);
  console.log(`\n=== Person ${demoID} student profile ===`, studentProfile.DATA);

  // 17. External IDs
  const externalIDs = await apiGet(`/people/${demoID}/externalids`);
  console.log(`\n=== Person ${demoID} external IDs ===`, externalIDs.DATA);

  // 18. Images
  const images = await apiGet(`/people/${demoID}/images`);
  console.log(`\n=== Person ${demoID} images ===`, images.DATA);

  // 19. Awards
  const awards = await apiGet(`/people/${demoID}/awards`);
  console.log(`\n=== Person ${demoID} awards ===`, awards.DATA);

  // 20. Bio
  const bio = await apiGet(`/people/${demoID}/bio`);
  console.log(`\n=== Person ${demoID} bio ===`, bio.DATA);

  // 21. Access / permissions
  const access = await apiGet('/access', { userID: demoID });
  console.log(`\n=== Access for user ${demoID} ===`, access);
}

// ---------------------------------------------------------------------------
// Organizations
// ---------------------------------------------------------------------------

// 22. All organizations
const allOrgs = await apiGet('/organizations');
console.log(`\n=== Organizations (${allOrgs.DATA.length}) ===`);
allOrgs.DATA.forEach(o => console.log(`  [${o.ORGID}] ${o.ORGNAME}`));

// 23. Single organization (use first org)
const firstOrgID = allOrgs.DATA[0]?.ORGID;
if (firstOrgID) {
  const singleOrg = await apiGet(`/organizations/${firstOrgID}`);
  console.log(`\n=== Org ${firstOrgID} ===`, singleOrg);
}

// ---------------------------------------------------------------------------
// Flags catalog
// ---------------------------------------------------------------------------

// 24. All flags
const allFlags = await apiGet('/flags');
console.log(`\n=== Flags (${allFlags.DATA.length}) ===`);
allFlags.DATA.forEach(f => console.log(`  ${f.FLAGNAME}`));

// ---------------------------------------------------------------------------
// Quick-pull endpoints
// ---------------------------------------------------------------------------

// 25. Attending — Clinical-Attending curated list (token only)
const qpAttending = await apiGet('/quickpulls/attending');
console.log(`\n=== Quickpull: Attending (${qpAttending.TOTAL}) ===`);
qpAttending.DATA.slice(0, 3).forEach(p => console.log(`  [${p.USERID}] ${p.DISPLAYNAME ?? ''}`));

// 26. Deans — deans with kiosk image (token only)
const qpDeans = await apiGet('/quickpulls/deans');
console.log(`\n=== Quickpull: Deans (${qpDeans.TOTAL}) ===`);
qpDeans.DATA.forEach(p => console.log(`  [${p.USERID}] ${p.DISPLAYNAME ?? ''}`));

// 27. Grad class — Alumni by grad year (requires secret with Alumni access)
//     program: "OD Program" | "PhD Program" | "MS Program" | "All"
//     filter (optional): "A-C" | "D-G" | "H-K" | "L-M" | "N-P" | "Q-S" | "T-Z"
const qpGradClass = await apiGet('/quickpulls/gradclass', { year: 2022, program: 'OD Program' });
console.log(`\n=== Quickpull: Grad Class 2022 OD (${qpGradClass.TOTAL}) ===`);
qpGradClass.DATA.slice(0, 3).forEach(p => console.log(`  [${p.USERID}] ${p.DISPLAYNAME ?? ''}`));

// 28. Grad class with last-name filter
const qpGradSlice = await apiGet('/quickpulls/gradclass', { year: 2022, program: 'All', filter: 'A-C' });
console.log(`\n=== Quickpull: Grad Class 2022 All A-C (${qpGradSlice.TOTAL}) ===`);

// 29. Single graduate by UserID (requires secret with Alumni access)
const firstGradID = qpGradClass.DATA[0]?.USERID;
if (firstGradID) {
  const qpGrad = await apiGet('/quickpulls/graduate', { id: firstGradID });
  console.log(`\n=== Quickpull: Graduate ${firstGradID} ===`, qpGrad.DATA);
}

// 30. MyUHCO profile by external ID (requires secret with Alumni or Current-Student access)
// const qpMyUHCO = await apiGet('/quickpulls/myuhco', { id: 'some-external-id' });
// console.log('\n=== Quickpull: MyUHCO ===', qpMyUHCO);

// 31. MyUHCO roster catalog (requires secret with Alumni or Current-Student access)
const qpRosters = await apiGet('/quickpulls/myuhco-rosters', { publishedOnly: 'true' });
console.log(`\n=== Quickpull: MyUHCO Rosters (${qpRosters.TOTAL} published) ===`);
qpRosters.DATA.slice(0, 3).forEach(r => console.log(`  ${r.FILENAME ?? r.ROSTERNAME ?? JSON.stringify(r)}`));

// ---------------------------------------------------------------------------
// Permission roster
// ---------------------------------------------------------------------------

// 32. Users with a given permission
const permRoster = await apiGet('/permission-roster', { permission: 'portal.access' });
console.log(`\n=== Permission roster: portal.access (${permRoster.DATA?.length ?? 0}) ===`);
permRoster.DATA?.slice(0, 3).forEach(u => console.log(`  [${u.USERID}] ${u.USERNAME ?? ''}`));
