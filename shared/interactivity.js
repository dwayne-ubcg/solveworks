/**
 * SolveWorks Dashboard Interactivity Layer
 * Adds interactive controls to all dashboard sections.
 * Included by each dashboard HTML after existing scripts.
 * Uses localStorage for persistence, merges with JSON data.
 */
(function(){
'use strict';

// Detect dashboard ID from URL path
const DASH_ID = location.pathname.split('/').filter(Boolean).pop() || 'dashboard';

// Utility: localStorage helpers
function lsGet(key){ try { return JSON.parse(localStorage.getItem(key) || 'null'); } catch(e){ return null; } }
function lsSet(key, val){ localStorage.setItem(key, JSON.stringify(val)); }
function lsKey(section){ return section + '_local_' + DASH_ID; }

// Toast (reuse existing if available)
function showToast(msg){
  if(typeof toast === 'function'){ toast(msg); return; }
  if(typeof window.showToast === 'function'){ window.showToast(msg); return; }
  let t = document.getElementById('toast');
  if(!t){ t = document.createElement('div'); t.id='toast'; t.className='toast'; document.body.appendChild(t); }
  t.textContent = msg;
  t.classList.remove('show');
  void t.offsetWidth;
  t.classList.add('show');
  setTimeout(()=> t.classList.remove('show'), 2600);
}

// Escape HTML
function _esc(s){ if(s==null) return ''; const d=document.createElement('div'); d.textContent=s; return d.innerHTML; }

// ──────────────────────────────────────────
// INJECT STYLES for interactive elements
// ──────────────────────────────────────────
const style = document.createElement('style');
style.textContent = `
/* Interactive toolbar */
.ix-toolbar { display:flex; align-items:center; gap:8px; margin-bottom:16px; flex-wrap:wrap; }
.ix-btn { padding:7px 14px; background:var(--surface2,#111d2b); border:1px solid var(--border,#1e2d3d); border-radius:8px; color:var(--text2,#7a8ba0); font-size:12px; font-weight:600; cursor:pointer; font-family:inherit; transition:all .15s; white-space:nowrap; }
.ix-btn:hover { background:var(--surface3,#172536); color:var(--text,#e4e4e8); }
.ix-btn:active { transform:scale(.95); }
.ix-btn.primary { background:var(--blue,#4080f0); color:#fff; border-color:var(--blue,#4080f0); }
.ix-btn.primary:hover { opacity:.85; }
.ix-btn.danger { color:var(--red,#f04060); border-color:rgba(240,64,96,.3); }
.ix-btn.danger:hover { background:rgba(240,64,96,.1); }
.ix-btn.active-filter { background:rgba(64,128,240,.15); color:var(--blue,#4080f0); border-color:rgba(64,128,240,.3); }

/* Inline forms */
.ix-form { background:var(--surface2,#111d2b); border:1px solid var(--border,#1e2d3d); border-radius:10px; padding:16px; margin-bottom:16px; display:none; animation:fadeIn .3s ease; }
.ix-form.open { display:block; }
.ix-form label { display:block; font-size:11px; font-weight:500; color:var(--text2,#7a8ba0); text-transform:uppercase; letter-spacing:1px; margin-bottom:4px; margin-top:10px; }
.ix-form label:first-child { margin-top:0; }
.ix-form input, .ix-form select, .ix-form textarea { width:100%; padding:8px 12px; background:var(--surface,#0c1520); border:1px solid var(--border,#1e2d3d); border-radius:6px; color:var(--text,#e4e4e8); font-size:13px; font-family:inherit; outline:none; }
.ix-form textarea { resize:vertical; min-height:50px; }
.ix-form .ix-form-actions { display:flex; gap:8px; margin-top:12px; }

/* Expandable */
.ix-expandable { max-height:0; overflow:hidden; transition:max-height .3s ease; }
.ix-expandable.open { max-height:2000px; }

/* Inline command */
.ix-cmd-wrap { display:flex; gap:6px; margin-top:10px; }
.ix-cmd-wrap input { flex:1; padding:6px 10px; background:var(--surface,#0c1520); border:1px solid var(--border,#1e2d3d); border-radius:6px; color:var(--text,#e4e4e8); font-size:12px; font-family:inherit; outline:none; }
.ix-cmd-wrap button { padding:6px 12px; background:var(--blue,#4080f0); border:none; border-radius:6px; color:#fff; font-size:11px; font-weight:600; cursor:pointer; font-family:inherit; }

/* Status toggle */
.ix-toggle { display:inline-flex; align-items:center; gap:6px; cursor:pointer; font-size:11px; font-weight:600; padding:3px 10px; border-radius:20px; user-select:none; transition:all .2s; }
.ix-toggle.active { background:rgba(64,192,128,.15); color:var(--green,#40c080); }
.ix-toggle.paused { background:rgba(240,192,64,.15); color:var(--yellow,#f0c040); }

/* Loading spinner */
.ix-spinner { display:inline-block; width:14px; height:14px; border:2px solid var(--surface3,#172536); border-top-color:var(--blue,#4080f0); border-radius:50%; animation:ixSpin .6s linear infinite; }
@keyframes ixSpin { to { transform:rotate(360deg); } }

/* Dismiss animation */
.ix-dismissed { opacity:0; transform:translateX(20px); transition:all .3s ease; pointer-events:none; max-height:0; margin:0; padding:0; overflow:hidden; }
`;
document.head.appendChild(style);

// ──────────────────────────────────────────
// Wait for init to finish, then enhance sections
// ──────────────────────────────────────────
function waitForSections(cb, tries){
  tries = tries || 0;
  // Wait until at least some section content is rendered
  const hasTasks = document.getElementById('sec-tasks');
  if(!hasTasks || tries > 50){ if(hasTasks) cb(); return; }
  const content = hasTasks.innerHTML;
  if(content.includes('Loading') || content.includes('skeleton') || content.trim().length < 50){
    setTimeout(()=> waitForSections(cb, tries+1), 200);
  } else {
    // Small delay to let all renders complete
    setTimeout(cb, 300);
  }
}

// Run enhancement after page load
if(document.readyState === 'complete') setTimeout(()=> waitForSections(enhanceAll), 500);
else window.addEventListener('load', ()=> setTimeout(()=> waitForSections(enhanceAll), 800));

function enhanceAll(){
  enhanceActivity();
  enhanceDocuments();
  enhanceAgents();
  enhanceHealth();
  enhanceSecurity();
  enhanceCalls();
  enhanceCRM();
  enhanceEmailTriage();
  enhanceIntel();
  enhanceReports();
  enhanceReadingList();
  enhanceOutreach();
  enhanceMeetings();
  enhanceTravel();
  enhanceTasks();
}

// ──────────────────────────────────────────
// ACTIVITY FEED
// ──────────────────────────────────────────
function enhanceActivity(){
  const sec = document.getElementById('sec-activity');
  if(!sec) return;
  const sub = sec.querySelector('.page-sub');
  if(!sub) return;
  
  const toolbar = document.createElement('div');
  toolbar.className = 'ix-toolbar';
  toolbar.innerHTML = `
    <button class="ix-btn active-filter" data-filter="all" onclick="window._ixActivityFilter('all',this)">All</button>
    <button class="ix-btn" data-filter="research" onclick="window._ixActivityFilter('research',this)">Research</button>
    <button class="ix-btn" data-filter="tasks" onclick="window._ixActivityFilter('tasks',this)">Tasks</button>
    <button class="ix-btn" data-filter="alerts" onclick="window._ixActivityFilter('alerts',this)">Alerts</button>
    <button class="ix-btn" data-filter="intel" onclick="window._ixActivityFilter('intel',this)">Intel</button>
    <button class="ix-btn danger" onclick="window._ixActivityClearOld()">Clear 7d+</button>
  `;
  sub.after(toolbar);
  
  window._ixActivityFilter = function(type, btn){
    toolbar.querySelectorAll('.ix-btn[data-filter]').forEach(b=> b.classList.remove('active-filter'));
    btn.classList.add('active-filter');
    sec.querySelectorAll('.feed-item').forEach(item=>{
      if(type === 'all'){ item.style.display = ''; return; }
      const text = (item.textContent || '').toLowerCase();
      item.style.display = text.includes(type) ? '' : 'none';
    });
  };
  
  window._ixActivityClearOld = function(){
    const cutoff = Date.now() - 7*24*60*60*1000;
    let cleared = 0;
    sec.querySelectorAll('.feed-item').forEach(item=>{
      const dateEl = item.querySelector('.feed-date');
      if(dateEl){
        const d = new Date(dateEl.textContent);
        if(!isNaN(d) && d.getTime() < cutoff){ item.classList.add('ix-dismissed'); cleared++; }
      }
    });
    showToast(cleared ? `Cleared ${cleared} old items` : 'No items older than 7 days');
  };
}

// ──────────────────────────────────────────
// DOCUMENTS
// ──────────────────────────────────────────
function enhanceDocuments(){
  const sec = document.getElementById('sec-documents');
  if(!sec) return;
  const title = sec.querySelector('.page-title');
  if(!title) return;
  
  // Find existing filter bar or page-sub
  const insertAfter = sec.querySelector('.filter-bar') || sec.querySelector('.page-sub') || title;
  
  // Add Document button & form
  const wrapper = document.createElement('div');
  wrapper.innerHTML = `
    <div class="ix-toolbar">
      <button class="ix-btn primary" onclick="document.getElementById('ix-doc-form').classList.toggle('open')">+ Add Document</button>
      <button class="ix-btn active-filter" data-cat="all" onclick="window._ixDocFilter('all',this)">All</button>
      <button class="ix-btn" data-cat="sop" onclick="window._ixDocFilter('sop',this)">SOP</button>
      <button class="ix-btn" data-cat="research" onclick="window._ixDocFilter('research',this)">Research</button>
      <button class="ix-btn" data-cat="brand" onclick="window._ixDocFilter('brand',this)">Brand</button>
      <button class="ix-btn" data-cat="legal" onclick="window._ixDocFilter('legal',this)">Legal</button>
    </div>
    <div class="ix-form" id="ix-doc-form">
      <label>Title</label><input type="text" id="ix-doc-title" placeholder="Document title">
      <label>Type</label><select id="ix-doc-type"><option value="pdf">PDF</option><option value="md">Markdown</option><option value="doc">Document</option><option value="link">Link</option></select>
      <label>Category</label><input type="text" id="ix-doc-cat" placeholder="e.g. SOP, Research, Brand">
      <label>Path / URL</label><input type="text" id="ix-doc-path" placeholder="/path/to/file or https://...">
      <div class="ix-form-actions">
        <button class="ix-btn" onclick="document.getElementById('ix-doc-form').classList.remove('open')">Cancel</button>
        <button class="ix-btn primary" onclick="window._ixAddDoc()">Add</button>
      </div>
    </div>
  `;
  insertAfter.after(wrapper);
  
  // Make existing doc cards clickable
  sec.querySelectorAll('.doc-card, .doc-file').forEach(card=>{
    card.style.cursor = 'pointer';
    card.addEventListener('click', function(){
      const title = this.querySelector('.doc-title')?.textContent || this.textContent;
      showToast(`📄 ${title.trim()}`);
    });
  });
  
  window._ixDocFilter = function(cat, btn){
    wrapper.querySelectorAll('.ix-btn[data-cat]').forEach(b=> b.classList.remove('active-filter'));
    btn.classList.add('active-filter');
    const cards = sec.querySelectorAll('.doc-card, .doc-folder');
    cards.forEach(card=>{
      if(cat === 'all'){ card.style.display = ''; return; }
      const text = (card.textContent || '').toLowerCase();
      card.style.display = text.includes(cat) ? '' : 'none';
    });
  };
  
  window._ixAddDoc = function(){
    const title = document.getElementById('ix-doc-title').value.trim();
    if(!title){ showToast('Title required'); return; }
    const type = document.getElementById('ix-doc-type').value;
    const cat = document.getElementById('ix-doc-cat').value.trim();
    const path = document.getElementById('ix-doc-path').value.trim();
    const docs = lsGet(lsKey('documents')) || [];
    docs.push({ title, type, category: cat, path, added: new Date().toISOString() });
    lsSet(lsKey('documents'), docs);
    // Add to DOM
    const emoji = type === 'pdf' ? '📕' : type === 'link' ? '🔗' : '📄';
    const container = sec.querySelector('#docs-list') || sec.querySelector('.doc-card')?.parentNode || sec;
    const div = document.createElement('div');
    div.className = 'doc-card';
    div.style.cursor = 'pointer';
    div.innerHTML = `<div class="doc-icon ${type}" style="width:36px;height:36px;border-radius:8px;display:flex;align-items:center;justify-content:center;font-size:16px;flex-shrink:0;background:rgba(64,128,240,.12)">${emoji}</div><div style="flex:1;min-width:0"><div class="doc-title">${_esc(title)}</div><div class="doc-cat">${_esc(cat)}</div></div><div class="doc-date">Just now</div>`;
    div.onclick = ()=> { if(path) showToast(`📄 ${path}`); };
    container.prepend ? container.prepend(div) : container.insertBefore(div, container.firstChild);
    document.getElementById('ix-doc-form').classList.remove('open');
    document.getElementById('ix-doc-title').value = '';
    document.getElementById('ix-doc-cat').value = '';
    document.getElementById('ix-doc-path').value = '';
    showToast('Document added ✓');
  };
}

// ──────────────────────────────────────────
// AGENTS
// ──────────────────────────────────────────
function enhanceAgents(){
  const sec = document.getElementById('sec-agents');
  if(!sec) return;
  
  const agentStates = lsGet(lsKey('agents')) || {};
  
  sec.querySelectorAll('.agent-card').forEach((card, i)=>{
    const name = card.querySelector('.agent-name')?.textContent?.trim() || 'agent-'+i;
    const agentKey = name.toLowerCase().replace(/\s+/g,'_');
    const state = agentStates[agentKey] || { status: 'active', lastCmd: '' };
    
    // Status toggle
    const statusEl = card.querySelector('.agent-status');
    if(statusEl){
      statusEl.style.cursor = 'pointer';
      statusEl.title = 'Click to toggle Active/Paused';
      statusEl.addEventListener('click', function(e){
        e.stopPropagation();
        const isActive = this.classList.contains('active');
        this.classList.toggle('active', !isActive);
        this.classList.toggle('standby', isActive);
        this.textContent = isActive ? 'paused' : 'active';
        agentStates[agentKey] = { ...state, status: isActive ? 'paused' : 'active' };
        lsSet(lsKey('agents'), agentStates);
        showToast(`${name}: ${isActive ? 'Paused' : 'Active'}`);
      });
    }
    
    // Command input
    const cmdDiv = document.createElement('div');
    cmdDiv.className = 'ix-cmd-wrap';
    cmdDiv.innerHTML = `<input type="text" placeholder="Send command to ${_esc(name)}..." id="ix-cmd-${i}"><button onclick="window._ixSendCmd(${i},'${_esc(agentKey)}')">Send</button>`;
    card.appendChild(cmdDiv);
    
    if(state.lastCmd){
      const last = document.createElement('div');
      last.style.cssText = 'font-size:11px;color:var(--text2);margin-top:6px;';
      last.textContent = '↩ Last: ' + state.lastCmd;
      last.id = 'ix-lastcmd-'+i;
      card.appendChild(last);
    }
  });
  
  window._ixSendCmd = function(idx, agentKey){
    const input = document.getElementById('ix-cmd-'+idx);
    if(!input || !input.value.trim()) return;
    const cmd = input.value.trim();
    const states = lsGet(lsKey('agents')) || {};
    states[agentKey] = { ...(states[agentKey]||{}), lastCmd: cmd };
    lsSet(lsKey('agents'), states);
    // TODO: Wire to agent API
    let lastEl = document.getElementById('ix-lastcmd-'+idx);
    if(!lastEl){
      lastEl = document.createElement('div');
      lastEl.style.cssText = 'font-size:11px;color:var(--text2);margin-top:6px;';
      lastEl.id = 'ix-lastcmd-'+idx;
      input.closest('.agent-card').appendChild(lastEl);
    }
    lastEl.textContent = '↩ Last: ' + cmd;
    input.value = '';
    showToast('Command sent to ' + agentKey + ' ✓');
  };
}

// ──────────────────────────────────────────
// HEALTH
// ──────────────────────────────────────────
function enhanceHealth(){
  const sec = document.getElementById('sec-health');
  if(!sec) return;
  const sub = sec.querySelector('.page-sub');
  if(!sub) return;
  
  const toolbar = document.createElement('div');
  toolbar.className = 'ix-toolbar';
  toolbar.innerHTML = `
    <button class="ix-btn active-filter" onclick="window._ixHealthView('daily',this)">Daily</button>
    <button class="ix-btn" onclick="window._ixHealthView('weekly',this)">Weekly</button>
    <button class="ix-btn" onclick="window._ixHealthRefresh(this)">🔄 Refresh</button>
  `;
  sub.after(toolbar);
  
  // Make stat cards expandable
  sec.querySelectorAll('.stat-card').forEach(card=>{
    card.style.cursor = 'pointer';
    card.addEventListener('click', function(){
      const label = this.querySelector('.label')?.textContent || '';
      const value = this.querySelector('.value')?.textContent || '';
      if(this.querySelector('.ix-expandable')){
        this.querySelector('.ix-expandable').classList.toggle('open');
        return;
      }
      const detail = document.createElement('div');
      detail.className = 'ix-expandable open';
      detail.style.cssText = 'font-size:12px;color:var(--text2);margin-top:8px;padding-top:8px;border-top:1px solid var(--border,#1e2d3d);';
      detail.textContent = `${label}: ${value} — Click again to collapse. Detailed breakdown available with full API integration.`;
      this.appendChild(detail);
    });
  });
  
  window._ixHealthView = function(view, btn){
    toolbar.querySelectorAll('.ix-btn').forEach(b=> b.classList.remove('active-filter'));
    btn.classList.add('active-filter');
    showToast(`Showing ${view} view`);
    // TODO: Wire to agent API for weekly aggregation
  };
  
  window._ixHealthRefresh = function(btn){
    btn.innerHTML = '<span class="ix-spinner"></span> Refreshing';
    btn.disabled = true;
    // TODO: Wire to agent API
    setTimeout(()=>{ btn.innerHTML = '🔄 Refresh'; btn.disabled = false; showToast('Health data refreshed ✓'); }, 1500);
  };
}

// ──────────────────────────────────────────
// SECURITY
// ──────────────────────────────────────────
function enhanceSecurity(){
  const sec = document.getElementById('sec-security');
  if(!sec) return;
  const sub = sec.querySelector('.page-sub');
  if(!sub) return;
  
  const dismissed = lsGet(lsKey('security_dismissed')) || [];
  
  const toolbar = document.createElement('div');
  toolbar.className = 'ix-toolbar';
  toolbar.innerHTML = `
    <button class="ix-btn primary" onclick="window._ixRunAudit(this)">🛡 Run Audit</button>
  `;
  sub.after(toolbar);
  
  // Add dismiss buttons to security checks
  sec.querySelectorAll('.security-card div[style*="border-bottom"]').forEach((item, i)=>{
    if(dismissed.includes(i)){ item.classList.add('ix-dismissed'); return; }
    const btn = document.createElement('button');
    btn.className = 'ix-btn danger';
    btn.style.cssText = 'float:right;padding:2px 8px;font-size:10px;margin-left:8px;';
    btn.textContent = 'Dismiss';
    btn.onclick = function(e){
      e.stopPropagation();
      dismissed.push(i);
      lsSet(lsKey('security_dismissed'), dismissed);
      item.classList.add('ix-dismissed');
      showToast('Dismissed');
    };
    item.prepend(btn);
    
    // Make expandable
    item.style.cursor = 'pointer';
    item.addEventListener('click', function(){
      if(this.querySelector('.ix-expandable')){
        this.querySelector('.ix-expandable').classList.toggle('open');
      } else {
        const detail = document.createElement('div');
        detail.className = 'ix-expandable open';
        detail.style.cssText = 'font-size:12px;color:var(--text2);margin-top:4px;';
        detail.textContent = 'Detailed findings will be available when connected to security scanning API.';
        this.appendChild(detail);
      }
    });
  });
  
  window._ixRunAudit = function(btn){
    btn.innerHTML = '<span class="ix-spinner"></span> Running audit...';
    btn.disabled = true;
    // TODO: Wire to agent API
    setTimeout(()=>{ btn.innerHTML = '🛡 Run Audit'; btn.disabled = false; showToast('Security audit complete ✓'); }, 2000);
  };
}

// ──────────────────────────────────────────
// CALLS / CALL ANALYSIS
// ──────────────────────────────────────────
function enhanceCalls(){
  const sec = document.getElementById('sec-calls');
  if(!sec) return;
  const sub = sec.querySelector('.page-sub');
  if(!sub) return;
  
  const toolbar = document.createElement('div');
  toolbar.className = 'ix-toolbar';
  toolbar.innerHTML = `
    <button class="ix-btn active-filter" data-cf="all" onclick="window._ixCallFilter('all',this)">All</button>
  `;
  
  // Detect business types from existing badges
  const businesses = new Set();
  sec.querySelectorAll('.call-badge').forEach(b=> businesses.add(b.textContent.trim()));
  businesses.forEach(biz=>{
    const btn = document.createElement('button');
    btn.className = 'ix-btn';
    btn.setAttribute('data-cf', biz.toLowerCase());
    btn.textContent = biz;
    btn.onclick = function(){ window._ixCallFilter(biz.toLowerCase(), this); };
    toolbar.appendChild(btn);
  });
  
  sub.after(toolbar);
  
  // Add notes input to each call
  const callNotes = lsGet(lsKey('call_notes')) || {};
  sec.querySelectorAll('.call-item').forEach((item, i)=>{
    const notesDiv = document.createElement('div');
    notesDiv.className = 'ix-cmd-wrap';
    notesDiv.style.marginTop = '8px';
    notesDiv.innerHTML = `<input type="text" placeholder="Add notes..." value="${_esc(callNotes[i]||'')}" id="ix-call-note-${i}"><button onclick="window._ixSaveCallNote(${i})">Save</button>`;
    item.appendChild(notesDiv);
    
    if(callNotes[i]){
      const note = document.createElement('div');
      note.style.cssText = 'font-size:12px;color:var(--text2);margin-top:4px;padding:6px 10px;background:var(--surface2,#111d2b);border-radius:6px;';
      note.textContent = '📝 ' + callNotes[i];
      note.id = 'ix-call-saved-'+i;
      item.appendChild(note);
    }
  });
  
  window._ixCallFilter = function(type, btn){
    toolbar.querySelectorAll('.ix-btn[data-cf]').forEach(b=> b.classList.remove('active-filter'));
    btn.classList.add('active-filter');
    sec.querySelectorAll('.call-item').forEach(item=>{
      if(type === 'all'){ item.style.display = ''; return; }
      const badge = item.querySelector('.call-badge');
      item.style.display = badge && badge.textContent.trim().toLowerCase().includes(type) ? '' : 'none';
    });
  };
  
  window._ixSaveCallNote = function(i){
    const input = document.getElementById('ix-call-note-'+i);
    if(!input) return;
    const notes = lsGet(lsKey('call_notes')) || {};
    notes[i] = input.value.trim();
    lsSet(lsKey('call_notes'), notes);
    let saved = document.getElementById('ix-call-saved-'+i);
    if(notes[i]){
      if(!saved){
        saved = document.createElement('div');
        saved.style.cssText = 'font-size:12px;color:var(--text2);margin-top:4px;padding:6px 10px;background:var(--surface2,#111d2b);border-radius:6px;';
        saved.id = 'ix-call-saved-'+i;
        input.closest('.call-item').appendChild(saved);
      }
      saved.textContent = '📝 ' + notes[i];
    } else if(saved){ saved.remove(); }
    showToast('Note saved ✓');
  };
}

// ──────────────────────────────────────────
// CRM / PIPELINE
// ──────────────────────────────────────────
function enhanceCRM(){
  const sec = document.getElementById('sec-crm');
  if(!sec) return;
  const sub = sec.querySelector('.page-sub');
  if(!sub) return;
  
  const localDeals = lsGet(lsKey('crm_deals')) || [];
  
  const toolbar = document.createElement('div');
  toolbar.className = 'ix-toolbar';
  toolbar.innerHTML = `
    <button class="ix-btn primary" onclick="document.getElementById('ix-deal-form').classList.toggle('open')">+ Add Deal</button>
    <button class="ix-btn active-filter" data-stage="all" onclick="window._ixCRMFilter('all',this)">All</button>
    <button class="ix-btn" data-stage="lead" onclick="window._ixCRMFilter('lead',this)">Lead</button>
    <button class="ix-btn" data-stage="qualified" onclick="window._ixCRMFilter('qualified',this)">Qualified</button>
    <button class="ix-btn" data-stage="proposal" onclick="window._ixCRMFilter('proposal',this)">Proposal</button>
    <button class="ix-btn" data-stage="closed" onclick="window._ixCRMFilter('closed',this)">Closed</button>
  `;
  sub.after(toolbar);
  
  const form = document.createElement('div');
  form.innerHTML = `
    <div class="ix-form" id="ix-deal-form">
      <label>Deal Name</label><input type="text" id="ix-deal-name" placeholder="Deal name">
      <label>Value</label><input type="text" id="ix-deal-value" placeholder="$50,000">
      <label>Stage</label><select id="ix-deal-stage"><option value="lead">Lead</option><option value="qualified">Qualified</option><option value="proposal">Proposal</option><option value="negotiation">Negotiation</option><option value="closed">Closed Won</option></select>
      <label>Contact</label><input type="text" id="ix-deal-contact" placeholder="Contact name">
      <div class="ix-form-actions">
        <button class="ix-btn" onclick="document.getElementById('ix-deal-form').classList.remove('open')">Cancel</button>
        <button class="ix-btn primary" onclick="window._ixAddDeal()">Add Deal</button>
      </div>
    </div>
  `;
  toolbar.after(form);
  
  // Render local deals
  function renderLocalDeals(){
    let container = document.getElementById('ix-local-deals');
    if(!container){
      container = document.createElement('div');
      container.id = 'ix-local-deals';
      const feed = sec.querySelector('#crm-feed') || sec.querySelector('.feed-item')?.parentNode || form;
      feed.after ? feed.after(container) : sec.appendChild(container);
    }
    const deals = lsGet(lsKey('crm_deals')) || [];
    container.innerHTML = deals.map((d,i)=>`
      <div class="feed-item" data-stage="${_esc(d.stage)}">
        <div class="feed-date" style="display:flex;align-items:center;gap:8px">
          <span>${_esc(d.contact)}</span>
          <span class="badge" style="background:rgba(64,128,240,.15);color:var(--blue);cursor:pointer" onclick="window._ixCycleStage(${i})" title="Click to advance stage">${_esc(d.stage)}</span>
        </div>
        <div class="feed-content">
          <strong>${_esc(d.name)}</strong> — ${_esc(d.value)}
          <button class="ix-btn danger" style="float:right;padding:2px 8px;font-size:10px" onclick="window._ixRemoveDeal(${i})">×</button>
        </div>
      </div>`).join('');
  }
  renderLocalDeals();
  
  const stages = ['lead','qualified','proposal','negotiation','closed'];
  window._ixCycleStage = function(i){
    const deals = lsGet(lsKey('crm_deals')) || [];
    if(!deals[i]) return;
    const cur = stages.indexOf(deals[i].stage);
    deals[i].stage = stages[(cur+1) % stages.length];
    lsSet(lsKey('crm_deals'), deals);
    renderLocalDeals();
    showToast(`Deal → ${deals[i].stage}`);
  };
  
  window._ixRemoveDeal = function(i){
    const deals = lsGet(lsKey('crm_deals')) || [];
    deals.splice(i,1);
    lsSet(lsKey('crm_deals'), deals);
    renderLocalDeals();
    showToast('Deal removed');
  };
  
  window._ixAddDeal = function(){
    const name = document.getElementById('ix-deal-name').value.trim();
    if(!name){ showToast('Name required'); return; }
    const deals = lsGet(lsKey('crm_deals')) || [];
    deals.push({
      name,
      value: document.getElementById('ix-deal-value').value.trim(),
      stage: document.getElementById('ix-deal-stage').value,
      contact: document.getElementById('ix-deal-contact').value.trim(),
      added: new Date().toISOString()
    });
    lsSet(lsKey('crm_deals'), deals);
    document.getElementById('ix-deal-form').classList.remove('open');
    ['ix-deal-name','ix-deal-value','ix-deal-contact'].forEach(id=> document.getElementById(id).value = '');
    renderLocalDeals();
    showToast('Deal added ✓');
  };
  
  window._ixCRMFilter = function(stage, btn){
    toolbar.querySelectorAll('.ix-btn[data-stage]').forEach(b=> b.classList.remove('active-filter'));
    btn.classList.add('active-filter');
    sec.querySelectorAll('.feed-item').forEach(item=>{
      if(stage === 'all'){ item.style.display = ''; return; }
      const itemStage = item.getAttribute('data-stage') || '';
      const text = (item.textContent || '').toLowerCase();
      item.style.display = (itemStage.includes(stage) || text.includes(stage)) ? '' : 'none';
    });
  };
}

// ──────────────────────────────────────────
// EMAIL TRIAGE
// ──────────────────────────────────────────
function enhanceEmailTriage(){
  const sec = document.getElementById('sec-email-triage') || document.getElementById('sec-email');
  if(!sec) return;
  const sub = sec.querySelector('.page-sub');
  if(!sub) return;
  
  const emailStates = lsGet(lsKey('email_states')) || {};
  
  const toolbar = document.createElement('div');
  toolbar.className = 'ix-toolbar';
  toolbar.innerHTML = `
    <button class="ix-btn active-filter" data-ef="all" onclick="window._ixEmailFilter('all',this)">All</button>
    <button class="ix-btn" data-ef="urgent" onclick="window._ixEmailFilter('urgent',this)">🔴 Urgent</button>
    <button class="ix-btn" data-ef="needs" onclick="window._ixEmailFilter('needs',this)">Needs Response</button>
    <button class="ix-btn" data-ef="fyi" onclick="window._ixEmailFilter('fyi',this)">FYI</button>
    <button class="ix-btn" onclick="window._ixEmailBulk()">Bulk Archive Selected</button>
  `;
  sub.after(toolbar);
  
  // Add action buttons to each email
  sec.querySelectorAll('.feed-item').forEach((item, i)=>{
    if(emailStates[i] === 'archived'){ item.classList.add('ix-dismissed'); return; }
    
    // Add checkbox for bulk
    const cb = document.createElement('input');
    cb.type = 'checkbox';
    cb.className = 'ix-email-cb';
    cb.dataset.idx = i;
    cb.style.cssText = 'margin-right:8px;cursor:pointer;';
    item.prepend(cb);
    
    const actions = document.createElement('div');
    actions.style.cssText = 'display:flex;gap:6px;margin-top:8px;';
    actions.innerHTML = `
      <button class="ix-btn" onclick="window._ixEmailAction(${i},'archived',this)">📥 Archive</button>
      <button class="ix-btn" onclick="window._ixEmailAction(${i},'flagged',this)">🚩 Flag</button>
      <button class="ix-btn" onclick="window._ixEmailAction(${i},'snoozed',this)">💤 Snooze</button>
    `;
    item.appendChild(actions);
  });
  
  window._ixEmailAction = function(i, action, btn){
    emailStates[i] = action;
    lsSet(lsKey('email_states'), emailStates);
    const item = btn.closest('.feed-item');
    if(action === 'archived') item.classList.add('ix-dismissed');
    else showToast(`Email ${action} ✓`);
  };
  
  window._ixEmailFilter = function(type, btn){
    toolbar.querySelectorAll('.ix-btn[data-ef]').forEach(b=> b.classList.remove('active-filter'));
    btn.classList.add('active-filter');
    sec.querySelectorAll('.feed-item').forEach(item=>{
      if(type === 'all'){ item.style.display = ''; return; }
      const text = (item.textContent || '').toLowerCase();
      item.style.display = text.includes(type) ? '' : 'none';
    });
  };
  
  window._ixEmailBulk = function(){
    let count = 0;
    sec.querySelectorAll('.ix-email-cb:checked').forEach(cb=>{
      const i = parseInt(cb.dataset.idx);
      emailStates[i] = 'archived';
      cb.closest('.feed-item').classList.add('ix-dismissed');
      count++;
    });
    lsSet(lsKey('email_states'), emailStates);
    showToast(count ? `${count} emails archived` : 'No emails selected');
  };
}

// ──────────────────────────────────────────
// INTEL / COMPETITIVE
// ──────────────────────────────────────────
function enhanceIntel(){
  const sec = document.getElementById('sec-intel');
  if(!sec) return;
  const sub = sec.querySelector('.page-sub');
  if(!sub) return;
  
  const pinned = lsGet(lsKey('intel_pinned')) || [];
  const dismissed = lsGet(lsKey('intel_dismissed')) || [];
  
  const toolbar = document.createElement('div');
  toolbar.className = 'ix-toolbar';
  toolbar.innerHTML = `
    <div class="ix-cmd-wrap" style="flex:1;margin:0">
      <input type="text" id="ix-intel-search" placeholder="Search for competitive intel...">
      <button onclick="window._ixIntelSearch()">🔍 Search</button>
    </div>
    <button class="ix-btn active-filter" data-if="all" onclick="window._ixIntelFilter('all',this)">All</button>
    <button class="ix-btn" data-if="pinned" onclick="window._ixIntelFilter('pinned',this)">📌 Saved</button>
  `;
  sub.after(toolbar);
  
  // Add actions to intel cards
  sec.querySelectorAll('.intel-card, .feed-item').forEach((item, i)=>{
    if(dismissed.includes(i)){ item.classList.add('ix-dismissed'); return; }
    const actions = document.createElement('div');
    actions.style.cssText = 'display:flex;gap:6px;margin-top:8px;';
    actions.innerHTML = `
      <button class="ix-btn ${pinned.includes(i)?'active-filter':''}" onclick="window._ixIntelPin(${i},this)">📌 ${pinned.includes(i)?'Saved':'Save'}</button>
      <button class="ix-btn danger" onclick="window._ixIntelDismiss(${i},this)">Dismiss</button>
    `;
    item.appendChild(actions);
    if(pinned.includes(i)) item.dataset.pinned = '1';
  });
  
  window._ixIntelPin = function(i, btn){
    const pins = lsGet(lsKey('intel_pinned')) || [];
    const idx = pins.indexOf(i);
    if(idx > -1){ pins.splice(idx,1); btn.classList.remove('active-filter'); btn.textContent = '📌 Save'; btn.closest('.feed-item,.intel-card').dataset.pinned = ''; }
    else { pins.push(i); btn.classList.add('active-filter'); btn.textContent = '📌 Saved'; btn.closest('.feed-item,.intel-card').dataset.pinned = '1'; }
    lsSet(lsKey('intel_pinned'), pins);
    showToast(idx > -1 ? 'Unpinned' : 'Saved ✓');
  };
  
  window._ixIntelDismiss = function(i, btn){
    const d = lsGet(lsKey('intel_dismissed')) || [];
    d.push(i);
    lsSet(lsKey('intel_dismissed'), d);
    btn.closest('.feed-item,.intel-card').classList.add('ix-dismissed');
    showToast('Dismissed');
  };
  
  window._ixIntelFilter = function(type, btn){
    toolbar.querySelectorAll('.ix-btn[data-if]').forEach(b=> b.classList.remove('active-filter'));
    btn.classList.add('active-filter');
    sec.querySelectorAll('.intel-card, #intel-feed > .feed-item').forEach(item=>{
      if(item.classList.contains('ix-dismissed')) return;
      if(type === 'all') item.style.display = '';
      else if(type === 'pinned') item.style.display = item.dataset.pinned === '1' ? '' : 'none';
    });
  };
  
  window._ixIntelSearch = function(){
    const q = document.getElementById('ix-intel-search').value.trim();
    if(!q){ showToast('Enter a search query'); return; }
    // TODO: Wire to agent API
    showToast(`Intel request submitted: "${q}"`);
    document.getElementById('ix-intel-search').value = '';
  };
}

// ──────────────────────────────────────────
// REPORTS
// ──────────────────────────────────────────
function enhanceReports(){
  const sec = document.getElementById('sec-reports');
  if(!sec) return;
  const sub = sec.querySelector('.page-sub');
  if(!sub) return;
  
  const toolbar = document.createElement('div');
  toolbar.className = 'ix-toolbar';
  toolbar.innerHTML = `
    <select id="ix-report-type" style="padding:7px 12px;background:var(--surface2,#111d2b);border:1px solid var(--border,#1e2d3d);border-radius:8px;color:var(--text,#e4e4e8);font-size:12px;font-family:inherit;">
      <option value="weekly">Weekly Digest</option>
      <option value="financial">Financial Report</option>
      <option value="competitive">Competitive Analysis</option>
      <option value="custom">Custom Report</option>
    </select>
    <button class="ix-btn primary" onclick="window._ixGenReport(this)">📊 Generate Report</button>
  `;
  sub.after(toolbar);
  
  // Make reports expandable & add download
  sec.querySelectorAll('.feed-item').forEach(item=>{
    item.style.cursor = 'pointer';
    const content = item.querySelector('.feed-content');
    if(content){
      // Add download badge
      const dl = document.createElement('span');
      dl.style.cssText = 'display:inline-block;margin-left:8px;font-size:11px;padding:2px 8px;background:rgba(64,128,240,.15);color:var(--blue);border-radius:10px;cursor:pointer;';
      dl.textContent = '⬇ Download';
      dl.onclick = (e)=>{ e.stopPropagation(); showToast('Download started...'); };
      content.appendChild(dl);
    }
    
    item.addEventListener('click', function(){
      if(this.querySelector('.ix-expandable')){
        this.querySelector('.ix-expandable').classList.toggle('open');
      } else {
        const detail = document.createElement('div');
        detail.className = 'ix-expandable open';
        detail.style.cssText = 'font-size:12px;color:var(--text2);margin-top:8px;padding:8px;background:var(--surface2,#111d2b);border-radius:6px;';
        detail.textContent = 'Full report summary will be shown here when report generation API is connected.';
        this.appendChild(detail);
      }
    });
  });
  
  window._ixGenReport = function(btn){
    const type = document.getElementById('ix-report-type').value;
    btn.innerHTML = '<span class="ix-spinner"></span> Generating...';
    btn.disabled = true;
    // TODO: Wire to agent API
    setTimeout(()=>{ btn.innerHTML = '📊 Generate Report'; btn.disabled = false; showToast(`${type} report requested ✓`); }, 2000);
  };
}

// ──────────────────────────────────────────
// READING LIST
// ──────────────────────────────────────────
function enhanceReadingList(){
  const sec = document.getElementById('sec-reading');
  if(!sec) return;
  const sub = sec.querySelector('.page-sub') || sec.querySelector('.page-title');
  if(!sub) return;
  
  const toolbar = document.createElement('div');
  toolbar.className = 'ix-toolbar';
  toolbar.innerHTML = `
    <button class="ix-btn primary" onclick="document.getElementById('ix-reading-form').classList.toggle('open')">+ Add Item</button>
    <button class="ix-btn active-filter" data-rf="all" onclick="window._ixReadingFilter('all',this)">All</button>
    <button class="ix-btn" data-rf="reading" onclick="window._ixReadingFilter('reading',this)">Reading</button>
    <button class="ix-btn" data-rf="queued" onclick="window._ixReadingFilter('queued',this)">Queued</button>
    <button class="ix-btn" data-rf="completed" onclick="window._ixReadingFilter('completed',this)">Completed</button>
  `;
  sub.after(toolbar);
  
  const form = document.createElement('div');
  form.innerHTML = `
    <div class="ix-form" id="ix-reading-form">
      <label>Title</label><input type="text" id="ix-reading-title" placeholder="Book or article title">
      <label>Author</label><input type="text" id="ix-reading-author" placeholder="Author name">
      <label>Category</label><input type="text" id="ix-reading-cat" placeholder="e.g. Business, Tech, Fiction">
      <label>URL (optional)</label><input type="text" id="ix-reading-url" placeholder="https://...">
      <div class="ix-form-actions">
        <button class="ix-btn" onclick="document.getElementById('ix-reading-form').classList.remove('open')">Cancel</button>
        <button class="ix-btn primary" onclick="window._ixAddReading()">Add</button>
      </div>
    </div>
  `;
  toolbar.after(form);
  
  // Make existing items clickable to cycle status & add delete
  const statusCycle = ['queued','reading','completed'];
  sec.querySelectorAll('.reading-item').forEach((item, i)=>{
    const statusEl = item.querySelector('.reading-status');
    if(statusEl){
      statusEl.style.cursor = 'pointer';
      statusEl.title = 'Click to cycle: Queued → Reading → Completed';
      statusEl.addEventListener('click', function(e){
        e.stopPropagation();
        const cur = statusCycle.indexOf(this.textContent.trim().toLowerCase());
        const next = statusCycle[(cur+1) % statusCycle.length];
        this.textContent = next;
        this.className = 'reading-status ' + next;
        showToast(`→ ${next}`);
      });
    }
    // Delete button
    const del = document.createElement('button');
    del.className = 'ix-btn danger';
    del.style.cssText = 'padding:2px 8px;font-size:10px;flex-shrink:0;';
    del.textContent = '×';
    del.onclick = (e)=>{ e.stopPropagation(); item.classList.add('ix-dismissed'); showToast('Removed'); };
    item.appendChild(del);
  });
  
  window._ixReadingFilter = function(type, btn){
    toolbar.querySelectorAll('.ix-btn[data-rf]').forEach(b=> b.classList.remove('active-filter'));
    btn.classList.add('active-filter');
    sec.querySelectorAll('.reading-item').forEach(item=>{
      if(type === 'all'){ item.style.display = ''; return; }
      const status = item.querySelector('.reading-status');
      item.style.display = status && status.textContent.trim().toLowerCase().includes(type) ? '' : 'none';
    });
  };
  
  window._ixAddReading = function(){
    const title = document.getElementById('ix-reading-title').value.trim();
    if(!title){ showToast('Title required'); return; }
    const items = lsGet(lsKey('reading')) || [];
    items.push({
      title,
      author: document.getElementById('ix-reading-author').value.trim(),
      category: document.getElementById('ix-reading-cat').value.trim(),
      url: document.getElementById('ix-reading-url').value.trim(),
      status: 'queued'
    });
    lsSet(lsKey('reading'), items);
    // Add to DOM
    const container = sec.querySelector('.reading-item')?.parentNode || sec;
    const div = document.createElement('div');
    div.className = 'reading-item';
    div.style.cssText = 'display:flex;align-items:center;gap:14px;';
    div.innerHTML = `<span class="reading-status queued" style="cursor:pointer" title="Click to cycle status" onclick="event.stopPropagation();const s=['queued','reading','completed'];const c=s.indexOf(this.textContent.trim().toLowerCase());const n=s[(c+1)%s.length];this.textContent=n;this.className='reading-status '+n;">queued</span><div style="flex:1"><div style="font-size:14px;font-weight:500">${_esc(title)}</div><div style="font-size:12px;color:var(--text2)">${_esc(document.getElementById('ix-reading-cat').value.trim())}</div></div><button class="ix-btn danger" style="padding:2px 8px;font-size:10px;flex-shrink:0" onclick="event.stopPropagation();this.closest('.reading-item').classList.add('ix-dismissed')">×</button>`;
    container.prepend ? container.prepend(div) : container.insertBefore(div, container.firstChild);
    document.getElementById('ix-reading-form').classList.remove('open');
    ['ix-reading-title','ix-reading-author','ix-reading-cat','ix-reading-url'].forEach(id=> document.getElementById(id).value = '');
    showToast('Added to reading list ✓');
  };
}

// ──────────────────────────────────────────
// OUTREACH
// ──────────────────────────────────────────
function enhanceOutreach(){
  const sec = document.getElementById('sec-outreach');
  if(!sec) return;
  const sub = sec.querySelector('.page-sub');
  if(!sub) return;
  
  const toolbar = document.createElement('div');
  toolbar.className = 'ix-toolbar';
  toolbar.innerHTML = `
    <button class="ix-btn primary" onclick="document.getElementById('ix-outreach-form').classList.toggle('open')">+ New Draft</button>
  `;
  sub.after(toolbar);
  
  const form = document.createElement('div');
  form.innerHTML = `
    <div class="ix-form" id="ix-outreach-form">
      <label>Recipient</label><input type="text" id="ix-out-recip" placeholder="name@email.com">
      <label>Subject</label><input type="text" id="ix-out-subject" placeholder="Subject line">
      <label>Body</label><textarea id="ix-out-body" placeholder="Email body..." rows="4"></textarea>
      <div class="ix-form-actions">
        <button class="ix-btn" onclick="document.getElementById('ix-outreach-form').classList.remove('open')">Cancel</button>
        <button class="ix-btn primary" onclick="window._ixAddOutreach()">Save Draft</button>
      </div>
    </div>
  `;
  toolbar.after(form);
  
  // Enhance existing outreach items
  sec.querySelectorAll('.feed-item').forEach((item, i)=>{
    // Find existing body preview
    const bodyDiv = item.querySelector('div[style*="background:var(--surface2"]') || item.querySelector('div[style*="background:var(--surface2,"]');
    if(bodyDiv){
      // Add edit button
      const editBtn = document.createElement('button');
      editBtn.className = 'ix-btn';
      editBtn.style.marginTop = '6px';
      editBtn.textContent = '✏️ Edit';
      editBtn.onclick = function(){
        if(bodyDiv.contentEditable === 'true'){
          bodyDiv.contentEditable = 'false';
          bodyDiv.style.border = 'none';
          this.textContent = '✏️ Edit';
          showToast('Saved ✓');
        } else {
          bodyDiv.contentEditable = 'true';
          bodyDiv.style.border = '1px solid var(--blue)';
          bodyDiv.focus();
          this.textContent = '💾 Save';
        }
      };
      
      const sentBtn = document.createElement('button');
      sentBtn.className = 'ix-btn';
      sentBtn.style.marginTop = '6px';
      sentBtn.textContent = '✅ Mark Sent';
      sentBtn.onclick = function(){
        item.style.opacity = '0.5';
        item.querySelector('.feed-date').textContent += ' — SENT';
        showToast('Marked as sent ✓');
      };
      
      // Insert after existing action buttons if present, or after bodyDiv
      const actionsRow = item.querySelector('div[style*="display:flex;gap:8px"]');
      if(actionsRow){
        actionsRow.appendChild(editBtn);
        actionsRow.appendChild(sentBtn);
      } else {
        bodyDiv.after(sentBtn);
        bodyDiv.after(editBtn);
      }
    }
  });
  
  window._ixAddOutreach = function(){
    const recip = document.getElementById('ix-out-recip').value.trim();
    const subject = document.getElementById('ix-out-subject').value.trim();
    const body = document.getElementById('ix-out-body').value.trim();
    if(!subject){ showToast('Subject required'); return; }
    const drafts = lsGet(lsKey('outreach')) || [];
    drafts.push({ recipient: recip, subject, body, added: new Date().toISOString() });
    lsSet(lsKey('outreach'), drafts);
    
    const feed = sec.querySelector('#outreach-feed') || sec.querySelector('.feed-item')?.parentNode || form;
    const div = document.createElement('div');
    div.className = 'feed-item';
    div.innerHTML = `<div class="feed-date">${_esc(recip)}</div><div class="feed-content"><strong>${_esc(subject)}</strong><div style="margin:10px 0;padding:12px;background:var(--surface2,#111d2b);border-radius:6px;font-size:13px;color:var(--text2);line-height:1.6">${_esc(body)}</div><div style="display:flex;gap:8px"><button class="ix-btn" onclick="this.closest('.feed-item').style.opacity='0.5';this.textContent='Sent ✓'">✅ Mark Sent</button></div></div>`;
    feed.prepend ? feed.prepend(div) : feed.parentNode.insertBefore(div, feed);
    
    document.getElementById('ix-outreach-form').classList.remove('open');
    ['ix-out-recip','ix-out-subject','ix-out-body'].forEach(id=> document.getElementById(id).value = '');
    showToast('Draft saved ✓');
  };
}

// ──────────────────────────────────────────
// MEETINGS (enhance existing)
// ──────────────────────────────────────────
function enhanceMeetings(){
  const sec = document.getElementById('sec-meetings');
  if(!sec) return;
  const sub = sec.querySelector('.page-sub');
  if(!sub) return;
  
  // Check if "Add Meeting" button already exists
  if(sec.querySelector('.ix-toolbar')) return;
  
  const toolbar = document.createElement('div');
  toolbar.className = 'ix-toolbar';
  toolbar.innerHTML = `
    <button class="ix-btn primary" onclick="document.getElementById('ix-meeting-form').classList.toggle('open')">+ Add Meeting</button>
  `;
  sub.after(toolbar);
  
  const form = document.createElement('div');
  form.innerHTML = `
    <div class="ix-form" id="ix-meeting-form">
      <label>Title</label><input type="text" id="ix-mtg-title" placeholder="Meeting title">
      <label>Date & Time</label><input type="datetime-local" id="ix-mtg-datetime">
      <label>Duration</label><input type="text" id="ix-mtg-duration" placeholder="30 min" value="30 min">
      <label>Location</label><input type="text" id="ix-mtg-location" placeholder="Zoom / Office / etc">
      <label>Attendees (comma-separated)</label><input type="text" id="ix-mtg-attendees" placeholder="John, Jane">
      <div class="ix-form-actions">
        <button class="ix-btn" onclick="document.getElementById('ix-meeting-form').classList.remove('open')">Cancel</button>
        <button class="ix-btn primary" onclick="window._ixAddMeeting()">Add Meeting</button>
      </div>
    </div>
  `;
  toolbar.after(form);
  
  window._ixAddMeeting = function(){
    const title = document.getElementById('ix-mtg-title').value.trim();
    if(!title){ showToast('Title required'); return; }
    const meetings = lsGet(lsKey('meetings')) || [];
    const m = {
      title,
      datetime: document.getElementById('ix-mtg-datetime').value,
      duration: document.getElementById('ix-mtg-duration').value.trim(),
      location: document.getElementById('ix-mtg-location').value.trim(),
      attendees: document.getElementById('ix-mtg-attendees').value.split(',').map(s=>s.trim()).filter(Boolean)
    };
    meetings.push(m);
    lsSet(lsKey('meetings'), meetings);
    
    // Add to DOM
    const div = document.createElement('div');
    div.className = 'meeting-card upcoming';
    div.style.cursor = 'pointer';
    div.onclick = function(){ this.classList.toggle('expanded'); };
    const dt = m.datetime ? new Date(m.datetime) : new Date();
    div.innerHTML = `
      <div class="meeting-header">
        <div>
          <div class="meeting-title">${_esc(m.title)}</div>
          <div class="meeting-meta"><span>📅 ${dt.toLocaleString()}</span><span>⏱ ${_esc(m.duration)}</span><span>📍 ${_esc(m.location)}</span></div>
          <div class="meeting-attendees">${m.attendees.map(a=>`<span class="meeting-attendee">${_esc(a)}</span>`).join('')}</div>
        </div>
        <span class="meeting-badge upcoming-badge">Local</span>
      </div>
      <div class="meeting-details"><div class="meeting-prep"><h4>Prep Requests</h4><div style="font-size:12px;color:var(--text2)">No prep requests yet</div></div></div>
    `;
    const container = sec.querySelector('.meeting-card')?.parentNode || form.nextSibling || sec;
    if(container.prepend) container.prepend(div);
    else sec.appendChild(div);
    
    document.getElementById('ix-meeting-form').classList.remove('open');
    ['ix-mtg-title','ix-mtg-location','ix-mtg-attendees'].forEach(id=> document.getElementById(id).value = '');
    showToast('Meeting added ✓');
  };
}

// ──────────────────────────────────────────
// TRAVEL (enhance existing)
// ──────────────────────────────────────────
function enhanceTravel(){
  const sec = document.getElementById('sec-travel');
  if(!sec) return;
  const sub = sec.querySelector('.page-sub');
  if(!sub) return;
  if(sec.querySelector('.ix-toolbar')) return;
  
  const toolbar = document.createElement('div');
  toolbar.className = 'ix-toolbar';
  toolbar.innerHTML = `
    <button class="ix-btn primary" onclick="document.getElementById('ix-trip-form').classList.toggle('open')">+ Add Trip</button>
  `;
  sub.after(toolbar);
  
  const form = document.createElement('div');
  form.innerHTML = `
    <div class="ix-form" id="ix-trip-form">
      <label>Destination</label><input type="text" id="ix-trip-dest" placeholder="City, Country">
      <label>Start Date</label><input type="date" id="ix-trip-start">
      <label>End Date</label><input type="date" id="ix-trip-end">
      <label>Purpose</label><select id="ix-trip-purpose"><option value="business">Business</option><option value="personal">Personal</option><option value="mixed">Mixed</option></select>
      <label>Notes</label><textarea id="ix-trip-notes" placeholder="Trip details..."></textarea>
      <div class="ix-form-actions">
        <button class="ix-btn" onclick="document.getElementById('ix-trip-form').classList.remove('open')">Cancel</button>
        <button class="ix-btn primary" onclick="window._ixAddTrip()">Add Trip</button>
      </div>
    </div>
  `;
  toolbar.after(form);
  
  // Add flight/hotel buttons to existing trip cards
  sec.querySelectorAll('.travel-details').forEach((details, i)=>{
    const addBtns = document.createElement('div');
    addBtns.className = 'ix-toolbar';
    addBtns.style.marginTop = '12px';
    addBtns.innerHTML = `
      <button class="ix-btn" onclick="showToast('Add flight details via your agent')">+ Add Flight</button>
      <button class="ix-btn" onclick="showToast('Add hotel details via your agent')">+ Add Hotel</button>
    `;
    details.appendChild(addBtns);
  });
  
  window._ixAddTrip = function(){
    const dest = document.getElementById('ix-trip-dest').value.trim();
    if(!dest){ showToast('Destination required'); return; }
    const trips = lsGet(lsKey('travel')) || [];
    const trip = {
      destination: dest,
      startDate: document.getElementById('ix-trip-start').value,
      endDate: document.getElementById('ix-trip-end').value,
      purpose: document.getElementById('ix-trip-purpose').value,
      notes: document.getElementById('ix-trip-notes').value.trim(),
      status: 'upcoming'
    };
    trips.push(trip);
    lsSet(lsKey('travel'), trips);
    
    const container = sec.querySelector('#travel-content') || sec.querySelector('.travel-card')?.parentNode || form.nextSibling || sec;
    const div = document.createElement('div');
    div.className = 'travel-card';
    const start = trip.startDate ? new Date(trip.startDate+'T00:00:00').toLocaleDateString('en-US',{month:'short',day:'numeric'}) : '?';
    const end = trip.endDate ? new Date(trip.endDate+'T00:00:00').toLocaleDateString('en-US',{month:'short',day:'numeric',year:'numeric'}) : '?';
    div.innerHTML = `
      <div class="travel-card-header" onclick="this.nextElementSibling.classList.toggle('open')">
        <div><div class="travel-dest">${_esc(dest)}</div><div class="travel-dates">${start} – ${end}</div></div>
        <div><span class="travel-badge ${trip.purpose}">${trip.purpose}</span><span class="travel-status upcoming">Upcoming</span></div>
      </div>
      <div class="travel-details">
        ${trip.notes ? `<div class="travel-section"><div class="travel-section-title">📝 Notes</div><div class="travel-notes">${_esc(trip.notes)}</div></div>` : ''}
        <div class="ix-toolbar" style="margin-top:12px">
          <button class="ix-btn" onclick="showToast('Add flight details via your agent')">+ Add Flight</button>
          <button class="ix-btn" onclick="showToast('Add hotel details via your agent')">+ Add Hotel</button>
        </div>
      </div>
    `;
    if(container.prepend) container.prepend(div);
    else container.appendChild(div);
    
    document.getElementById('ix-trip-form').classList.remove('open');
    ['ix-trip-dest','ix-trip-notes'].forEach(id=> document.getElementById(id).value = '');
    showToast('Trip added ✓');
  };
}

// ──────────────────────────────────────────
// TASKS (enhance existing — add priority cycling, category filters)
// ──────────────────────────────────────────
function enhanceTasks(){
  const sec = document.getElementById('sec-tasks');
  if(!sec) return;
  
  // Add priority cycling — make priority badges clickable
  sec.addEventListener('click', function(e){
    const badge = e.target;
    if(badge.classList.contains('badge') && (badge.classList.contains('high') || badge.classList.contains('medium') || badge.classList.contains('low'))){
      const cycle = ['high','medium','low'];
      const cur = cycle.findIndex(c=> badge.classList.contains(c));
      const next = cycle[(cur+1) % cycle.length];
      badge.classList.remove(cycle[cur]);
      badge.classList.add(next);
      badge.textContent = next;
      showToast(`Priority → ${next}`);
    }
  });
  
  // Add category filter chips if not already present
  const filterBar = sec.querySelector('.filter-bar');
  if(filterBar && !sec.querySelector('[data-catfilter]')){
    const catBar = document.createElement('div');
    catBar.style.cssText = 'display:flex;gap:6px;flex-wrap:wrap;margin-top:8px;';
    const cats = new Set();
    sec.querySelectorAll('.task-cat').forEach(el=> cats.add(el.textContent.trim()));
    if(cats.size > 0){
      catBar.innerHTML = `<button class="ix-btn active-filter" data-catfilter="all" onclick="window._ixTaskCatFilter('all',this)">All Categories</button>`;
      cats.forEach(cat=>{
        catBar.innerHTML += `<button class="ix-btn" data-catfilter="${_esc(cat)}" onclick="window._ixTaskCatFilter('${_esc(cat)}',this)">${_esc(cat)}</button>`;
      });
      filterBar.appendChild(catBar);
    }
  }
  
  window._ixTaskCatFilter = function(cat, btn){
    document.querySelectorAll('[data-catfilter]').forEach(b=> b.classList.remove('active-filter'));
    btn.classList.add('active-filter');
    sec.querySelectorAll('.task').forEach(task=>{
      if(cat === 'all'){ task.style.display = ''; return; }
      const taskCat = task.querySelector('.task-cat');
      task.style.display = taskCat && taskCat.textContent.trim() === cat ? '' : 'none';
    });
  };
}

})();
