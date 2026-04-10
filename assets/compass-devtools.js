/*
 * compass-devtools.js
 * Debug panel, random-results preview, and party-positions preview for compass.html.
 * Only activated when the URL contains ?debug=1, ?randomresults=1, or ?partypositions=1.
 * Referenced via <script src="assets/compass-devtools.js"> in compass.html.
 *
 * Functions that depend on IIFE-scoped state are called with a helpers object (h):
 *   h.uiLang                       — current UI language code ('en'|'ta')
 *   h.escapeHtml(text)             — HTML-escapes a string
 *   h.normalizePositionValue(p)    — returns numeric position value
 *   h.getPositionLabel(p)          — returns display label for position
 *   h.getAllianceSubpartyPositions(...) — returns per-party position rows
 *   h.getCapturedUserResponseLabel(thesis, idx) — user's captured response
 *   h.debugLines                   — shared array for debug log lines
 *   h.debugLog(msg)                — shared logging function
 *   h.queryAllInRoots(container, selector) — multi-root querySelectorAll
 *   h.isVisible(el)                — visibility check
 */
(function (w) {
  'use strict';

  /* ── Standalone utilities (no external deps) ── */

  function describeEl(el) {
    var tag = (el.tagName || '').toLowerCase();
    var cls = (el.className && String(el.className).trim()) || '';
    var txt = (el.textContent || '').trim().replace(/\s+/g, ' ').substring(0, 40);
    return tag + (cls ? '.' + cls.split(' ').slice(0, 2).join('.') : '') + (txt ? ' [' + txt + ']' : '');
  }

  function clickBestTarget(el) {
    if (!el) return false;
    var direct = el.matches && el.matches('button, [role="button"], label, input, .party-item__button');
    if (direct) { el.click(); return true; }
    var nested = el.querySelector && el.querySelector('button, [role="button"], label, input, .party-item__button');
    if (nested) { nested.click(); return true; }
    el.click();
    return true;
  }

  function getRandomResponseChoice() {
    var choices = [
      { value: 2,    en: 'Strongly approve', ta: 'மிகவும் ஒப்புதல்' },
      { value: 1,    en: 'Approve',          ta: 'ஒப்புதல்' },
      { value: 0.5,  en: 'Partly',           ta: 'பகுதியாக ஒப்புதல்' },
      { value: 0,    en: 'Neutral',          ta: 'நடுநிலை' },
      { value: -1,   en: 'Reject',           ta: 'எதிர்ப்பு' },
      { value: -2,   en: 'Strongly reject',  ta: 'கடுமையான எதிர்ப்பு' }
    ];
    return choices[Math.floor(Math.random() * choices.length)];
  }

  /* ── Helpers that depend on uiLang (passed via h) ── */

  function makeGetPartyDisplayName(h) {
    return function getPartyDisplayName(party) {
      if (!party) return 'Party';
      var lang = h.uiLang;
      if (party.short && party.short[lang]) return party.short[lang];
      if (party.name  && party.name[lang])  return party.name[lang];
      if (party.short && party.short.en)    return party.short.en;
      if (party.name  && party.name.en)     return party.name.en;
      return party.alias || 'Party';
    };
  }

  /* ── Shared subparty cell builder ── */

  function buildSubpartyCells(party, thesis, titleEn, legacyExcerpts, h) {
    var pos = thesis.positions && thesis.positions[party.alias];
    if (!pos) {
      return '<td><span class="oec-random-stance">'
        + h.escapeHtml(h.uiLang === 'ta' ? 'தரவு இல்லை' : 'No data')
        + '</span></td>';
    }

    var posLabel = h.getPositionLabel(pos.position);
    var expl = (pos.explanation && (pos.explanation[h.uiLang] || pos.explanation.en || pos.explanation.ta)) || '';
    var sourceUrl = pos.source || '';
    var subpartyPositions = h.getAllianceSubpartyPositions(
      party.alias,
      pos.position,
      (pos.explanation && (pos.explanation.en || pos.explanation.ta)) || expl,
      titleEn,
      legacyExcerpts
    );

    var html = '<td>';
    html += '<span class="oec-random-stance">' + h.escapeHtml(posLabel) + '</span>';

    if (subpartyPositions.length > 1) {
      var uniq = {};
      subpartyPositions.forEach(function (sp) { uniq[sp.position] = true; });
      if (Object.keys(uniq).length > 1) {
        html += '<span class="oec-random-expl">'
          + h.escapeHtml(h.uiLang === 'ta'
            ? 'இந்த கூட்டணியில் கட்சிகள் வேறுபட்ட நிலைப்பாடுகளை கொண்டுள்ளன.'
            : 'Parties in this alliance hold different positions on this issue.')
          + '</span>';
      }
    }

    subpartyPositions.forEach(function (item) {
      var subLabel = h.getPositionLabel(item.position);
      html += '<span class="oec-random-subparty">' + h.escapeHtml(item.party + ': ' + subLabel) + '</span>';
      if (item.parsedExcerpt) {
        html += '<span class="oec-random-subparty-excerpt">'
          + h.escapeHtml(h.uiLang === 'ta'
            ? ('கூட்டணி குறிப்பிலிருந்து: ' + item.parsedExcerpt)
            : ('From alliance note: ' + item.parsedExcerpt))
          + '</span>';
      }
      if (item.excerpt) {
        html += '<span class="oec-random-subparty-excerpt">"' + h.escapeHtml(item.excerpt) + '"</span>';
      }
      if (item.source) {
        html += '<a class="oec-random-source" href="' + h.escapeHtml(item.source)
          + '" target="_blank" rel="noopener noreferrer">'
          + h.escapeHtml(h.uiLang === 'ta' ? (item.party + ' ஆதாரம்') : (item.party + ' Source'))
          + '</a>';
      }
    });

    if (expl) html += '<span class="oec-random-expl">' + h.escapeHtml(expl) + '</span>';
    if (sourceUrl) {
      html += '<a class="oec-random-source" href="' + h.escapeHtml(sourceUrl)
        + '" target="_blank" rel="noopener noreferrer">'
        + h.escapeHtml(h.uiLang === 'ta' ? 'ஆதாரம்' : 'Source')
        + '</a>';
    }
    html += '</td>';
    return html;
  }

  /* ── Public API ── */

  /**
   * Render synthetic random-response results into container.
   * Only for localhost + ?randomresults=1.
   *
   * h must include: uiLang, escapeHtml, normalizePositionValue,
   *                 getPositionLabel, getAllianceSubpartyPositions
   */
  function renderRandomResults(container, cfg, legacyExcerpts, h) {
    var parties = cfg.parties || [];
    var theses  = cfg.theses  || [];
    if (!container || !parties.length || !theses.length) return false;

    var getPartyDisplayName = makeGetPartyDisplayName(h);

    var userResponses = theses.map(function (thesis, idx) {
      var pick  = getRandomResponseChoice();
      var title = (thesis.title && (thesis.title[h.uiLang] || thesis.title.en || thesis.title.ta)) || ('Thesis ' + (idx + 1));
      return { value: pick.value, label: h.uiLang === 'ta' ? pick.ta : pick.en, title: title };
    });

    var scored = parties.map(function (party) {
      var total = 0, count = 0;
      for (var i = 0; i < theses.length; i++) {
        var pos = theses[i].positions && theses[i].positions[party.alias];
        if (!pos) continue;
        var partyValue    = h.normalizePositionValue(pos.position);
        var responseValue = userResponses[i].value;
        var similarity    = 1 - (Math.abs(responseValue - partyValue) / 4);
        total += Math.max(0, similarity);
        count += 1;
      }
      return {
        name:     getPartyDisplayName(party),
        alias:    party.alias || '',
        score:    count ? Math.round((total / count) * 100) : 0,
        answered: count
      };
    });
    scored.sort(function (a, b) { return b.score - a.score; });

    var html = '';
    html += '<div class="oec-random-results">';
    html += '<section class="oec-random-results__header">';
    html += '<h2 class="oec-random-results__title">'
      + (h.uiLang === 'ta'
        ? 'சீரற்ற பதில்களால் உருவாக்கப்பட்ட ஒப்பீட்டு முடிவு'
        : 'Comparison Result From Random Responses')
      + '</h2>';
    html += '<div class="oec-random-results__meta">'
      + (h.uiLang === 'ta'
        ? 'இது சோதனைக்கான செயற்கை முன்னோட்டம். ஒவ்வொரு ரீலோடிலும் புதிய பதில்கள் உருவாகும்.'
        : 'This is a synthetic test preview. Reload generates a new random response set.')
      + '</div>';
    html += '<button type="button" class="oec-random-results__rerun" id="oec-random-rerun">'
      + (h.uiLang === 'ta' ? 'மீண்டும் சீரற்ற முடிவு உருவாக்கு' : 'Generate New Random Result')
      + '</button>';
    html += '</section>';

    html += '<section class="oec-random-results__grid">';
    scored.forEach(function (item) {
      html += '<article class="oec-random-card">';
      html += '<div class="oec-random-card__name">' + item.name + '</div>';
      html += '<div class="oec-random-card__score">' + item.score + '%</div>';
      html += '<div class="oec-random-card__small">'
        + (h.uiLang === 'ta'
          ? ('ஒப்பீடு செய்யப்பட்ட தீர்மானங்கள்: ' + item.answered)
          : ('Theses compared: ' + item.answered))
        + '</div>';
      html += '</article>';
    });
    html += '</section>';

    html += '<section class="oec-random-results__responses">';
    html += '<h3>' + (h.uiLang === 'ta' ? 'தேர்ந்தெடுக்கப்பட்ட சீரற்ற பதில்கள் (முதல் 8)' : 'Selected Random Responses (first 8)') + '</h3>';
    html += '<ul>';
    userResponses.slice(0, 8).forEach(function (r) {
      html += '<li>' + h.escapeHtml(r.title) + ' - ' + h.escapeHtml(r.label) + '</li>';
    });
    html += '</ul>';
    html += '</section>';

    html += '<section class="oec-random-results__details">';
    html += '<h3>' + (h.uiLang === 'ta' ? 'தலைப்புவாரியான கட்சி நிலைப்பாடுகள்' : 'Issue-wise Party Stands') + '</h3>';
    html += '<table class="oec-random-details-table">';
    html += '<thead><tr>';
    html += '<th>' + (h.uiLang === 'ta' ? 'தீர்மானம்' : 'Thesis') + '</th>';
    html += '<th>' + (h.uiLang === 'ta' ? 'உங்கள் சீரற்ற பதில்' : 'Your Random Response') + '</th>';
    parties.forEach(function (party) {
      html += '<th>' + h.escapeHtml(getPartyDisplayName(party)) + '</th>';
    });
    html += '</tr></thead><tbody>';

    theses.forEach(function (thesis, idx) {
      var titleEn = (thesis.title && thesis.title.en) ? String(thesis.title.en) : '';
      var title   = (thesis.title && (thesis.title[h.uiLang] || thesis.title.en || thesis.title.ta)) || ('Thesis ' + (idx + 1));
      html += '<tr>';
      html += '<td>' + h.escapeHtml(title) + '</td>';
      html += '<td><span class="oec-random-stance">' + h.escapeHtml(userResponses[idx].label) + '</span></td>';
      parties.forEach(function (party) {
        html += buildSubpartyCells(party, thesis, titleEn, legacyExcerpts, h);
      });
      html += '</tr>';
    });

    html += '</tbody></table></section></div>';

    container.innerHTML = html;
    var rerunBtn = container.querySelector('#oec-random-rerun');
    if (rerunBtn) {
      rerunBtn.addEventListener('click', function () {
        try {
          var u = new URL(window.location.href);
          u.searchParams.set('randomresults', '1');
          u.searchParams.set('rnd', String(Date.now()));
          window.location.assign(u.toString());
          return;
        } catch (e) {}
        window.location.reload();
      });
    }
    return true;
  }

  /**
   * Render the full party-positions table into container.
   * Activated by ?partypositions=1.
   *
   * h must include: uiLang, escapeHtml, getPositionLabel,
   *                 getAllianceSubpartyPositions, getCapturedUserResponseLabel
   */
  function renderPartyPositions(container, cfg, legacyExcerpts, h) {
    var parties = cfg.parties || [];
    var theses  = cfg.theses  || [];
    if (!container || !parties.length || !theses.length) return false;

    var getPartyDisplayName = makeGetPartyDisplayName(h);

    var html = '';
    html += '<div class="oec-random-results">';
    html += '<section class="oec-random-results__header">';
    html += '<h2 class="oec-random-results__title">'
      + (h.uiLang === 'ta' ? 'கட்சிகளின் நிலைப்பாடு அட்டவணை' : 'Party Position Table')
      + '</h2>';
    html += '<div class="oec-random-results__meta">'
      + (h.uiLang === 'ta'
        ? 'ஒவ்வொரு தீர்மானத்திற்கும் கட்சிகளின் நிலைப்பாடுகள், கூட்டணி துணைக் கட்சி வரிகள், மற்றும் ஆதாரங்கள்.'
        : 'Issue-wise party positions with alliance partner sub-lines and source links.')
      + '</div>';
    html += '</section>';

    html += '<section class="oec-random-results__details">';
    html += '<h3>' + (h.uiLang === 'ta' ? 'தலைப்புவாரியான கட்சி நிலைப்பாடுகள்' : 'Issue-wise Party Stands') + '</h3>';
    html += '<table class="oec-random-details-table">';
    html += '<thead><tr>';
    html += '<th>' + (h.uiLang === 'ta' ? 'தீர்மானம்' : 'Thesis') + '</th>';
    html += '<th>' + h.escapeHtml(h.uiLang === 'ta' ? 'உங்கள் பதில்' : 'Your Response') + '</th>';
    parties.forEach(function (party) {
      html += '<th>' + h.escapeHtml(getPartyDisplayName(party)) + '</th>';
    });
    html += '</tr></thead><tbody>';

    theses.forEach(function (thesis, idx) {
      var titleEn = (thesis.title && thesis.title.en) ? String(thesis.title.en) : '';
      var title   = (thesis.title && (thesis.title[h.uiLang] || thesis.title.en || thesis.title.ta)) || ('Thesis ' + (idx + 1));
      html += '<tr>';
      html += '<td>' + h.escapeHtml(title) + '</td>';
      html += '<td><span class="oec-random-stance">'
        + h.escapeHtml(h.getCapturedUserResponseLabel(thesis, idx))
        + '</span></td>';
      parties.forEach(function (party) {
        html += buildSubpartyCells(party, thesis, titleEn, legacyExcerpts, h);
      });
      html += '</tr>';
    });

    html += '</tbody></table></section></div>';
    container.innerHTML = html;
    return true;
  }

  /**
   * Initialise the floating debug panel DOM.
   * Only called when ?debug=1.
   *
   * h must include: debugLines (array), debugLog (fn),
   *                 queryAllInRoots (fn), isVisible (fn)
   *
   * Returns { debugPanel, debugLogEl }.
   */
  function initDebugPanel(h) {
    function pickRandomSelection() {
      var oecContainer = document.getElementById('open-election-compass');
      var compareCandidates = h.queryAllInRoots(oecContainer, '.compare-section button, .compare-section [role="button"], .compare-section [class*="thesis"], .compare-section .chat-bubble, .compare-section label');
      var fallbackCandidates = h.queryAllInRoots(oecContainer, '#open-election-compass button, #open-election-compass [role="button"], #open-election-compass [class*="thesis"], #open-election-compass .party-item__button, #open-election-compass .party-item, #open-election-compass label');
      var candidates = (compareCandidates.length ? compareCandidates : fallbackCandidates)
        .filter(function (el) {
          if (!h.isVisible(el)) return false;
          if (el.closest('.oec-debug-panel')) return false;
          if (el.closest('.oec-source-inline')) return false;
          return true;
        });
      if (!candidates.length) {
        h.debugLog('random selection: no clickable candidates found');
        return;
      }
      var chosen = candidates[Math.floor(Math.random() * candidates.length)];
      h.debugLog('random selection click -> ' + describeEl(chosen));
      clickBestTarget(chosen);
    }

    var panel = document.createElement('div');
    panel.className = 'oec-debug-panel';
    panel.innerHTML =
      '<div class="oec-debug-controls">'
      + '<button type="button" class="oec-debug-btn" id="oec-debug-random">Random Selection</button>'
      + '<button type="button" class="oec-debug-btn" id="oec-debug-clear">Clear Log</button>'
      + '</div>'
      + '<div class="oec-debug-log" id="oec-debug-log">Source debug active...</div>';
    document.body.appendChild(panel);

    var logEl = panel.querySelector('#oec-debug-log');
    panel.querySelector('#oec-debug-random').addEventListener('click', pickRandomSelection);
    panel.querySelector('#oec-debug-clear').addEventListener('click', function () {
      h.debugLines.length = 0;
      if (logEl) logEl.textContent = 'Log cleared.';
    });

    return { debugPanel: panel, debugLogEl: logEl };
  }

  /* ── Expose namespace ── */
  w.OECDevTools = {
    renderRandomResults:  renderRandomResults,
    renderPartyPositions: renderPartyPositions,
    initDebugPanel:       initDebugPanel
  };

}(window));
