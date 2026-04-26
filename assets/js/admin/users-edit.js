/* ══════════════════════════════════════════════════════════
   Modal + AJAX CRUD for all repeating sections
   Each section: cards (display) + hidden inputs (data) + modal (edit) + AJAX save
   ══════════════════════════════════════════════════════════ */
document.addEventListener('DOMContentLoaded', function () {

    var dirtySectionButtons = {
        general: 'save-general-btn',
        flags: 'save-flags-btn',
        orgs: 'save-orgs-btn',
        extids: 'save-extids-btn',
        emails: 'saveEmailsBtn',
        phones: 'savePhonesBtn',
        aliases: 'saveAliasesBtn',
        addresses: 'saveAddressesBtn',
        degrees: 'saveDegreesBtn',
        awards: 'saveAwardsBtn',
        uh: 'save-uh-btn',
        bioinfo: 'save-bioinfo-btn',
        studentprofile: 'save-studentprofile-btn',
        tabdegrees: ['save-facultydeg-btn', 'save-emeritusdeg-btn', 'save-residentdeg-btn'],
        bio: 'save-bio-btn'
    };

    function setSectionDirty(section, isDirty) {
        var entry = dirtySectionButtons[section];
        if (!entry) return;
        var buttonIds = Array.isArray(entry) ? entry : [entry];
        buttonIds.forEach(function (buttonId) {
            var btn = document.getElementById(buttonId);
            if (!btn) return;
            btn.classList.add('btn-save-action');
            btn.classList.toggle('users-edit-save-needs', !!isDirty);
            btn.classList.toggle('btn-save-needs', !!isDirty);

            var badgeId = buttonId + '-unsaved-badge';
            var badge = document.getElementById(badgeId);
            if (isDirty) {
                if (!badge) {
                    badge = document.createElement('span');
                    badge.id = badgeId;
                    badge.className = 'badge rounded-pill bg-warning text-dark ms-2';
                    badge.textContent = 'Unsaved';
                    btn.insertAdjacentElement('beforebegin', badge);
                }
            } else if (badge) {
                badge.remove();
            }
        });
    }

    function markDirty(section) { setSectionDirty(section, true); }
    function clearDirty(section) { setSectionDirty(section, false); }

    function getSaveStatusEl(buttonId, statusId) {
        if (statusId) {
            var statusById = document.getElementById(statusId);
            if (statusById) {
                return statusById;
            }
        }
        var btn = document.getElementById(buttonId);
        if (!btn || !btn.parentNode) {
            return null;
        }
        var status = btn.parentNode.querySelector('.save-status');
        if (!status) {
            status = document.createElement('span');
            status.className = 'save-status';
            btn.parentNode.appendChild(status);
        }
        return status;
    }

    function wireSectionDirty(section, rootEl) {
        if (!rootEl) return;
        rootEl.addEventListener('input', function () { markDirty(section); });
        rootEl.addEventListener('change', function () { markDirty(section); });
    }

    function wireRepeaterDirty(section, containerEl) {
        if (!containerEl || typeof MutationObserver === 'undefined') return;
        var observer = new MutationObserver(function () { markDirty(section); });
        observer.observe(containerEl, { childList: true, subtree: true });
    }

    function escapeForAttributeSelector(value) {
        return String(value || '').replace(/\\/g, '\\\\').replace(/"/g, '\\"');
    }

    function replaceContainerFromFresh(currentPane, freshPane, containerId) {
        if (!currentPane || !freshPane) return;
        var currentContainer = currentPane.querySelector('#' + containerId);
        var freshContainer = freshPane.querySelector('#' + containerId);
        if (currentContainer && freshContainer) {
            currentContainer.innerHTML = freshContainer.innerHTML;
        }
    }

    function syncNamedFieldsFromFresh(currentPane, freshPane) {
        if (!currentPane || !freshPane) return;
        var freshFields = freshPane.querySelectorAll('input[name], select[name], textarea[name]');
        freshFields.forEach(function (freshField) {
            var name = freshField.getAttribute('name') || '';
            if (!name) return;

            var selector = '[name="' + escapeForAttributeSelector(name) + '"]';
            var currentFields = currentPane.querySelectorAll(selector);
            if (!currentFields.length) return;

            if (freshField.type === 'checkbox' || freshField.type === 'radio') {
                currentFields.forEach(function (currentField) {
                    if ((currentField.value || '') === (freshField.value || '')) {
                        currentField.checked = !!freshField.checked;
                    }
                });
                return;
            }

            var currentField = currentFields[0];
            if (currentField) {
                currentField.value = freshField.value;
            }
        });
    }

    function fetchFreshEditDocument() {
        return fetch(window.location.pathname + window.location.search, {
            method: 'GET',
            credentials: 'same-origin',
            headers: { 'X-Requested-With': 'XMLHttpRequest' },
            cache: 'no-store'
        })
        .then(function (r) { return r.text(); })
        .then(function (html) {
            return new DOMParser().parseFromString(html, 'text/html');
        });
    }

    function getRefreshButtonIdByTab(tabId) {
        var map = {
            'general-tab': 'refreshGeneralInfoBtn',
            'contact-tab': 'refreshContactInfoBtn',
            'bio-info-tab': 'refreshBiographicalInfoBtn',
            'flags-tab': 'refreshFlagsBtn',
            'orgs-tab': 'refreshOrgsBtn',
            'extids-tab': 'refreshExtidsBtn',
            'address-tab': 'refreshUhBtn'
        };
        return map[tabId] || '';
    }

    function setRefreshButtonLoading(tabId, isLoading) {
        var buttonId = getRefreshButtonIdByTab(tabId);
        if (!buttonId) return;
        var btn = document.getElementById(buttonId);
        if (!btn) return;

        var loadingCount = parseInt(btn.getAttribute('data-refresh-loading-count') || '0', 10);
        if (isLoading) {
            loadingCount += 1;
            if (loadingCount === 1) {
                btn.setAttribute('data-refresh-original-html', btn.innerHTML);
                btn.disabled = true;
                btn.innerHTML = "<span class='spinner-border spinner-border-sm me-1' role='status' aria-hidden='true'></span>Refreshing...";
            }
        } else {
            loadingCount = Math.max(0, loadingCount - 1);
            if (loadingCount === 0) {
                var originalHtml = btn.getAttribute('data-refresh-original-html');
                if (originalHtml) {
                    btn.innerHTML = originalHtml;
                }
                btn.disabled = false;
            }
        }

        btn.setAttribute('data-refresh-loading-count', String(loadingCount));
    }

    function refreshTabData(tabId) {
        var tabBtn = tabId ? document.getElementById(tabId) : null;
        var paneTarget = tabBtn ? (tabBtn.getAttribute('data-bs-target') || '') : '';
        if (!paneTarget || paneTarget.charAt(0) !== '#') {
            return Promise.resolve();
        }

        var paneId = paneTarget.substring(1);
        var currentPane = document.getElementById(paneId);
        if (!currentPane) {
            return Promise.resolve();
        }

        setRefreshButtonLoading(tabId, true);

        return fetchFreshEditDocument().then(function (freshDoc) {
            var freshPane = freshDoc.getElementById(paneId);
            if (!freshPane) {
                return;
            }

            syncNamedFieldsFromFresh(currentPane, freshPane);

            if (tabId === 'general-tab') {
                replaceContainerFromFresh(currentPane, freshPane, 'aliasesContainer');
                clearDirty('aliases');
            }
            if (tabId === 'contact-tab') {
                replaceContainerFromFresh(currentPane, freshPane, 'emailsContainer');
                replaceContainerFromFresh(currentPane, freshPane, 'phonesContainer');
                replaceContainerFromFresh(currentPane, freshPane, 'addressesContainer');
                clearDirty('emails');
                clearDirty('phones');
                clearDirty('addresses');
            }
            if (tabId === 'bio-info-tab') {
                replaceContainerFromFresh(currentPane, freshPane, 'degreesContainer');
                replaceContainerFromFresh(currentPane, freshPane, 'awardsContainer');
                clearDirty('degrees');
                clearDirty('awards');
            }
            if (tabId === 'student-profile-tab') {
                replaceContainerFromFresh(currentPane, freshPane, 'spAwardsContainer');
                clearDirty('studentprofile');
            }
        }).catch(function () {
            showSaveToast('Refresh failed. Please try again.', true);
        }).finally(function () {
            setRefreshButtonLoading(tabId, false);
        });
    }

    /* ── Save toast helper ── */
    function showSaveToast(message, isError) {
        var toastEl = document.getElementById('saveToast');
        var toastBody = document.getElementById('saveToastBody');
        if (!toastEl || !toastBody) return;
        toastBody.textContent = message;
        toastEl.classList.remove('text-bg-success', 'text-bg-danger');
        toastEl.classList.add(isError ? 'text-bg-danger' : 'text-bg-success');
        var toast = bootstrap.Toast.getOrCreateInstance(toastEl, { delay: 3000 });
        toast.show();
    }

    /* ── Helper: AJAX save a section ── */
    function ajaxSave(section, body, statusEl, onSuccess) {
        if (statusEl) { statusEl.textContent = ''; }
        return fetch('/admin/users/saveSection.cfm', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            credentials: 'same-origin',
            body: body.toString()
        })
        .then(function (r) { return r.json(); })
        .then(function (data) {
            if (data.success) {
                showSaveToast('Saved successfully.');
                clearDirty(section);
                if (onSuccess) onSuccess(data);
            } else {
                showSaveToast('Error: ' + (data.message || 'Unknown'), true);
            }
            return data;
        })
        .catch(function (err) {
            showSaveToast('Network error: ' + (err && err.message ? err.message : 'Unknown'), true);
            return { success: false, message: err && err.message ? err.message : 'Network error' };
        });
    }

    function esc(v) { return (v || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/'/g,'&#39;').replace(/"/g,'&quot;'); }

    /* ────────────────────────────────────────────────────────
       EMAIL SECTION
       ──────────────────────────────────────────────────────── */
    (function () {
        var container = document.getElementById('emailsContainer');
        if (!container) return;
        var modalEl = document.getElementById('emailModal');
        var modal = new bootstrap.Modal(modalEl);

        function getAllData() {
            var items = [];
            var hiddens = container.querySelectorAll('input[data-email-field="addr"]');
            hiddens.forEach(function (el) {
                var idx = el.getAttribute('data-email-idx');
                items.push({
                    addr: el.value,
                    type: (container.querySelector('input[data-email-field="type"][data-email-idx="'+idx+'"]') || {}).value || '',
                    primary: (container.querySelector('input[data-email-field="primary"][data-email-idx="'+idx+'"]') || {}).value || '0'
                });
            });
            return items;
        }

        function rebuild(items) {
            container.innerHTML = '';
            items.forEach(function (d, i) {
                container.insertAdjacentHTML('beforeend',
                    "<div class='card mb-2'><div class='card-body py-2 px-3'>" +
                    "<div class='d-flex justify-content-between align-items-center'><div>" +
                    "<strong>" + esc(d.addr) + "</strong>" +
                    (d.type ? " <span class='badge bg-secondary text-dark'>" + esc(d.type) + "</span>" : "") +
                    (d.primary === '1' ? " <span class='badge bg-success'>Primary</span>" : "") +
                    "</div><div>" +
                    "<button type='button' class='btn btn-sm btn-edit edit-email-btn' data-idx='" + i + "'><i class='bi bi-pencil-square me-1'></i>Edit</button> " +
                    "<button type='button' class='btn btn-sm btn-remove remove-email-btn' data-idx='" + i + "'><i class='bi bi-trash me-1'></i>Remove</button>" +
                    "</div></div></div></div>" +
                    "<input type='hidden' data-email-field='addr' data-email-idx='" + i + "' value='" + esc(d.addr) + "'>" +
                    "<input type='hidden' data-email-field='type' data-email-idx='" + i + "' value='" + esc(d.type) + "'>" +
                    "<input type='hidden' data-email-field='primary' data-email-idx='" + i + "' value='" + (d.primary || '0') + "'>"
                );
            });
        }

        function clearModal() {
            document.getElementById('emailEditIdx').value = '-1';
            document.getElementById('emailAddr').value = '';
            document.getElementById('emailType').value = '';
            document.getElementById('emailPrimaryChk').checked = false;
            document.getElementById('emailModalLabel').textContent = 'Add Email';
        }

        function fillModal(idx) {
            var items = getAllData();
            var d = items[idx];
            document.getElementById('emailEditIdx').value = idx;
            document.getElementById('emailAddr').value = d.addr;
            document.getElementById('emailType').value = d.type;
            document.getElementById('emailPrimaryChk').checked = d.primary === '1';
            document.getElementById('emailModalLabel').textContent = 'Edit Email';
        }

        function readModal() {
            return {
                addr: document.getElementById('emailAddr').value.trim(),
                type: document.getElementById('emailType').value,
                primary: document.getElementById('emailPrimaryChk').checked ? '1' : '0'
            };
        }

        document.getElementById('addEmailBtn').addEventListener('click', function () { clearModal(); modal.show(); });

        document.getElementById('saveEmailModalBtn').addEventListener('click', function () {
            var d = readModal();
            if (!d.addr) { alert('Email address is required.'); return; }
            if (/@uh\.edu\s*$/i.test(d.addr)) { alert('@uh.edu addresses cannot be added here.'); return; }
            var items = getAllData();
            var editIdx = parseInt(document.getElementById('emailEditIdx').value);
            if (editIdx >= 0) { items[editIdx] = d; } else { items.push(d); }
            rebuild(items);
            saveEmailsToDatabase({ hideModalOnSuccess: true });
        });

        container.addEventListener('click', function (e) {
            var btn = e.target.closest('.edit-email-btn');
            if (btn) { fillModal(parseInt(btn.dataset.idx)); modal.show(); return; }
            btn = e.target.closest('.remove-email-btn');
            if (btn) {
                var items = getAllData();
                items.splice(parseInt(btn.dataset.idx), 1);
                rebuild(items);
                saveEmailsToDatabase();
            }
        });

        function saveEmailsToDatabase(options) {
            options = options || {};
            var items = getAllData();
            var body = new URLSearchParams();
            body.append('userID', document.getElementById('pageUserID').value);
            body.append('section', 'emails');
            body.append('count', items.length);
            var primaryIdx = -1;
            items.forEach(function (d, i) {
                body.append('addr_' + i, d.addr);
                body.append('type_' + i, d.type);
                if (d.primary === '1') primaryIdx = i;
            });
            body.append('primary_idx', primaryIdx);
            var status = getSaveStatusEl('saveEmailsBtn', 'emailsSaveStatus');
            if (!status) return Promise.resolve({ success: false, message: 'Save status unavailable' });
            return ajaxSave('emails', body, status).then(function (data) {
                if (data && data.success && options.hideModalOnSuccess) {
                    modal.hide();
                }
                return data;
            });
        }

    })();

    /* ────────────────────────────────────────────────────────
       PHONE SECTION
       ──────────────────────────────────────────────────────── */
    (function () {
        var container = document.getElementById('phonesContainer');
        if (!container) return;
        var modalEl = document.getElementById('phoneModal');
        var modal = new bootstrap.Modal(modalEl);

        function getAllData() {
            var items = [];
            var hiddens = container.querySelectorAll('input[data-phone-field="number"]');
            hiddens.forEach(function (el) {
                var idx = el.getAttribute('data-phone-idx');
                items.push({
                    number: el.value,
                    type: (container.querySelector('input[data-phone-field="type"][data-phone-idx="'+idx+'"]') || {}).value || '',
                    primary: (container.querySelector('input[data-phone-field="primary"][data-phone-idx="'+idx+'"]') || {}).value || '0'
                });
            });
            return items;
        }

        function rebuild(items) {
            container.innerHTML = '';
            items.forEach(function (d, i) {
                container.insertAdjacentHTML('beforeend',
                    "<div class='card mb-2'><div class='card-body py-2 px-3'>" +
                    "<div class='d-flex justify-content-between align-items-center'><div>" +
                    "<strong>" + esc(d.number) + "</strong>" +
                    (d.type ? " <span class='badge bg-secondary text-dark'>" + esc(d.type) + "</span>" : "") +
                    (d.primary === '1' ? " <span class='badge bg-success'>Primary</span>" : "") +
                    "</div><div>" +
                    "<button type='button' class='btn btn-sm btn-edit edit-phone-btn' data-idx='" + i + "'><i class='bi bi-pencil-square me-1'></i>Edit</button> " +
                    "<button type='button' class='btn btn-sm btn-remove remove-phone-btn' data-idx='" + i + "'><i class='bi bi-trash me-1'></i>Remove</button>" +
                    "</div></div></div></div>" +
                    "<input type='hidden' data-phone-field='number' data-phone-idx='" + i + "' value='" + esc(d.number) + "'>" +
                    "<input type='hidden' data-phone-field='type' data-phone-idx='" + i + "' value='" + esc(d.type) + "'>" +
                    "<input type='hidden' data-phone-field='primary' data-phone-idx='" + i + "' value='" + (d.primary || '0') + "'>"
                );
            });
        }

        function clearModal() {
            document.getElementById('phoneEditIdx').value = '-1';
            document.getElementById('phoneNumber').value = '';
            document.getElementById('phoneType').value = '';
            document.getElementById('phonePrimaryChk').checked = false;
            document.getElementById('phoneModalLabel').textContent = 'Add Phone';
        }

        function fillModal(idx) {
            var items = getAllData();
            var d = items[idx];
            document.getElementById('phoneEditIdx').value = idx;
            document.getElementById('phoneNumber').value = d.number;
            document.getElementById('phoneType').value = d.type;
            document.getElementById('phonePrimaryChk').checked = d.primary === '1';
            document.getElementById('phoneModalLabel').textContent = 'Edit Phone';
        }

        function readModal() {
            return {
                number: document.getElementById('phoneNumber').value.trim(),
                type: document.getElementById('phoneType').value,
                primary: document.getElementById('phonePrimaryChk').checked ? '1' : '0'
            };
        }

        document.getElementById('addPhoneBtn').addEventListener('click', function () { clearModal(); modal.show(); });

        document.getElementById('savePhoneModalBtn').addEventListener('click', function () {
            var d = readModal();
            if (!d.number) { alert('Phone number is required.'); return; }
            var items = getAllData();
            var editIdx = parseInt(document.getElementById('phoneEditIdx').value);
            if (editIdx >= 0) { items[editIdx] = d; } else { items.push(d); }
            rebuild(items);
            savePhonesToDatabase({ hideModalOnSuccess: true });
        });

        container.addEventListener('click', function (e) {
            var btn = e.target.closest('.edit-phone-btn');
            if (btn) { fillModal(parseInt(btn.dataset.idx)); modal.show(); return; }
            btn = e.target.closest('.remove-phone-btn');
            if (btn) {
                var items = getAllData();
                items.splice(parseInt(btn.dataset.idx), 1);
                rebuild(items);
                savePhonesToDatabase();
            }
        });

        function savePhonesToDatabase(options) {
            options = options || {};
            var items = getAllData();
            var body = new URLSearchParams();
            body.append('userID', document.getElementById('pageUserID').value);
            body.append('section', 'phones');
            body.append('count', items.length);
            var primaryIdx = -1;
            items.forEach(function (d, i) {
                body.append('number_' + i, d.number);
                body.append('type_' + i, d.type);
                if (d.primary === '1') primaryIdx = i;
            });
            body.append('primary_idx', primaryIdx);
            var status = getSaveStatusEl('savePhonesBtn', 'phonesSaveStatus');
            if (!status) return Promise.resolve({ success: false, message: 'Save status unavailable' });
            return ajaxSave('phones', body, status).then(function (data) {
                if (data && data.success && options.hideModalOnSuccess) {
                    modal.hide();
                }
                return data;
            });
        }

    })();

    /* ────────────────────────────────────────────────────────
       ALIAS SECTION
       ──────────────────────────────────────────────────────── */
    (function () {
        var container = document.getElementById('aliasesContainer');
        if (!container) return;
        var modalEl = document.getElementById('aliasModal');
        var modal = new bootstrap.Modal(modalEl);

        /* Populate alias type select from global vars set by CF */
        var typeSel = document.getElementById('aliasType');
        if (typeof aliasTypeOptions !== 'undefined') {
            for (var ti = 0; ti < aliasTypeOptions.length; ti++) {
                var opt = document.createElement('option');
                opt.value = aliasTypeOptions[ti];
                opt.textContent = aliasTypeLabels[ti];
                typeSel.appendChild(opt);
            }
        }

        function getAllData() {
            var items = [];
            var hiddens = container.querySelectorAll('input[data-alias-field="first"]');
            hiddens.forEach(function (el) {
                var idx = el.getAttribute('data-alias-idx');
                var get = function(f) { return (container.querySelector('input[data-alias-field="'+f+'"][data-alias-idx="'+idx+'"]') || {}).value || ''; };
                items.push({ first: el.value, middle: get('middle'), last: get('last'), type: get('type'), source: get('source'), active: get('active'), primary: get('primary') });
            });
            return items;
        }

        function ensureSinglePrimary(items, preferredIdx) {
            var idx = typeof preferredIdx === 'number' ? preferredIdx : -1;
            var i;

            if (idx < 0) {
                for (i = 0; i < items.length; i++) {
                    if (items[i].primary === '1') { idx = i; break; }
                }
            }
            if (idx < 0) {
                for (i = 0; i < items.length; i++) {
                    if (items[i].active === '1') { idx = i; break; }
                }
            }
            if (idx < 0 && items.length) {
                idx = 0;
            }

            for (i = 0; i < items.length; i++) {
                items[i].primary = (i === idx) ? '1' : '0';
            }
        }

        function rebuild(items) {
            ensureSinglePrimary(items);
            container.innerHTML = '';
            items.forEach(function (d, i) {
                var name = [d.first, d.middle, d.last].filter(Boolean).join(' ');
                container.insertAdjacentHTML('beforeend',
                    "<div class='card mb-2'><div class='card-body py-2 px-3'>" +
                    "<div class='d-flex justify-content-between align-items-center'><div>" +
                    "<strong>" + esc(name) + "</strong>" +
                    (d.type ? " <span class='badge bg-info text-dark'>" + esc(d.type) + "</span>" : "") +
                    (d.source ? " <small class='text-muted'>(" + esc(d.source) + ")</small>" : "") +
                    (d.primary === '1' ? " <span class='badge bg-success'>Primary</span>" : "") +
                    (d.active === '1' ? " <span class='badge bg-success'>Active</span>" : " <span class='badge bg-secondary text-dark'>Inactive</span>") +
                    "</div><div>" +
                    "<button type='button' class='btn btn-sm btn-outline-primary set-primary-alias-btn' data-idx='" + i + "'" + (d.primary === '1' ? " disabled" : "") + ">Set Primary</button> " +
                    "<button type='button' class='btn btn-sm btn-edit edit-alias-btn' data-idx='" + i + "'><i class='bi bi-pencil-square me-1'></i>Edit</button> " +
                    "<button type='button' class='btn btn-sm btn-remove remove-alias-btn' data-idx='" + i + "'><i class='bi bi-trash me-1'></i>Remove</button>" +
                    "</div></div></div></div>" +
                    "<input type='hidden' data-alias-field='first' data-alias-idx='" + i + "' value='" + esc(d.first) + "'>" +
                    "<input type='hidden' data-alias-field='middle' data-alias-idx='" + i + "' value='" + esc(d.middle) + "'>" +
                    "<input type='hidden' data-alias-field='last' data-alias-idx='" + i + "' value='" + esc(d.last) + "'>" +
                    "<input type='hidden' data-alias-field='type' data-alias-idx='" + i + "' value='" + esc(d.type) + "'>" +
                    "<input type='hidden' data-alias-field='source' data-alias-idx='" + i + "' value='" + esc(d.source) + "'>" +
                    "<input type='hidden' data-alias-field='active' data-alias-idx='" + i + "' value='" + (d.active || '0') + "'>" +
                    "<input type='hidden' data-alias-field='primary' data-alias-idx='" + i + "' value='" + (d.primary || '0') + "'>"
                );
            });
        }

        function clearModal() {
            document.getElementById('aliasEditIdx').value = '-1';
            document.getElementById('aliasFirst').value = '';
            document.getElementById('aliasMiddle').value = '';
            document.getElementById('aliasLast').value = '';
            document.getElementById('aliasType').value = '';
            document.getElementById('aliasSource').value = '';
            document.getElementById('aliasActive').checked = true;
            document.getElementById('aliasModalLabel').textContent = 'Add Alias';
        }

        function fillModal(idx) {
            var items = getAllData();
            var d = items[idx];
            document.getElementById('aliasEditIdx').value = idx;
            document.getElementById('aliasFirst').value = d.first;
            document.getElementById('aliasMiddle').value = d.middle;
            document.getElementById('aliasLast').value = d.last;
            document.getElementById('aliasType').value = d.type;
            document.getElementById('aliasSource').value = d.source;
            document.getElementById('aliasActive').checked = d.active === '1';
            document.getElementById('aliasModalLabel').textContent = 'Edit Alias';
        }

        function readModal() {
            return {
                first: document.getElementById('aliasFirst').value.trim(),
                middle: document.getElementById('aliasMiddle').value.trim(),
                last: document.getElementById('aliasLast').value.trim(),
                type: document.getElementById('aliasType').value,
                source: document.getElementById('aliasSource').value.trim(),
                active: document.getElementById('aliasActive').checked ? '1' : '0'
            };
        }

        document.getElementById('addAliasBtn').addEventListener('click', function () { clearModal(); modal.show(); });

        document.getElementById('saveAliasModalBtn').addEventListener('click', function () {
            var d = readModal();
            if (!d.first && !d.last) { alert('First or Last name is required.'); return; }
            var items = getAllData();
            var editIdx = parseInt(document.getElementById('aliasEditIdx').value);
            var existingPrimary = '0';
            if (editIdx >= 0 && items[editIdx]) {
                existingPrimary = items[editIdx].primary || '0';
                d.primary = existingPrimary;
                items[editIdx] = d;
            } else {
                d.primary = items.length === 1 ? '1' : '0';
                items.push(d);
            }

            if (d.primary === '1' && d.active !== '1') {
                d.active = '1';
            }
            rebuild(items);
            saveAliasesToDatabase({ hideModalOnSuccess: true });
        });

        container.addEventListener('click', function (e) {
            var btn = e.target.closest('.edit-alias-btn');
            if (btn) { fillModal(parseInt(btn.dataset.idx)); modal.show(); return; }
            btn = e.target.closest('.set-primary-alias-btn');
            if (btn) {
                var items = getAllData();
                var idx = parseInt(btn.dataset.idx);
                if (!isNaN(idx) && items[idx]) {
                    items[idx].active = '1';
                    ensureSinglePrimary(items, idx);
                    rebuild(items);
                    saveAliasesToDatabase();
                }
                return;
            }
            btn = e.target.closest('.remove-alias-btn');
            if (btn) {
                var items = getAllData();
                items.splice(parseInt(btn.dataset.idx), 1);
                rebuild(items);
                saveAliasesToDatabase();
            }
        });

        function saveAliasesToDatabase(options) {
            options = options || {};
            var items = getAllData();
            ensureSinglePrimary(items);
            var body = new URLSearchParams();
            body.append('userID', document.getElementById('pageUserID').value);
            body.append('section', 'aliases');
            body.append('count', items.length);
            items.forEach(function (d, i) {
                body.append('first_' + i, d.first);
                body.append('middle_' + i, d.middle);
                body.append('last_' + i, d.last);
                body.append('type_' + i, d.type);
                body.append('source_' + i, d.source);
                body.append('active_' + i, d.active);
                body.append('primary_' + i, d.primary || '0');
            });
            var status = getSaveStatusEl('saveAliasesBtn', 'aliasesSaveStatus');
            if (!status) return Promise.resolve({ success: false, message: 'Save status unavailable' });
            return ajaxSave('aliases', body, status).then(function (data) {
                if (data && data.success && options.hideModalOnSuccess) {
                    modal.hide();
                }
                return data;
            });
        }

    })();

    /* ────────────────────────────────────────────────────────
       DEGREE SECTION (Bio tab)
       ──────────────────────────────────────────────────────── */
    (function () {
        var container = document.getElementById('degreesContainer');
        if (!container) return;
        var modalEl = document.getElementById('degreeModal');
        var modal = new bootstrap.Modal(modalEl);

        function getAllData() {
            var items = [];
            var hiddens = container.querySelectorAll('input[data-degree-field="name"]');
            hiddens.forEach(function (el) {
                var idx = el.getAttribute('data-degree-idx');
                var get = function(f) { return (container.querySelector('input[data-degree-field="'+f+'"][data-degree-idx="'+idx+'"]') || {}).value || ''; };
                items.push({ name: el.value, university: get('university'), year: get('year') });
            });
            return items;
        }

        function rebuild(items) {
            container.innerHTML = '';
            items.forEach(function (d, i) {
                container.insertAdjacentHTML('beforeend',
                    "<div class='card mb-2'><div class='card-body py-2 px-3'>" +
                    "<div class='d-flex justify-content-between align-items-center'><div>" +
                    "<strong>" + esc(d.name) + "</strong>" +
                    (d.university ? " <small class='text-muted'>— " + esc(d.university) + "</small>" : "") +
                    (d.year ? " <small class='text-muted'>(" + esc(d.year) + ")</small>" : "") +
                    "</div><div>" +
                    "<button type='button' class='btn btn-sm btn-edit edit-degree-btn' data-idx='" + i + "'><i class='bi bi-pencil-square me-1'></i>Edit</button> " +
                    "<button type='button' class='btn btn-sm btn-remove remove-degree-btn' data-idx='" + i + "'><i class='bi bi-trash me-1'></i>Remove</button>" +
                    "</div></div></div></div>" +
                    "<input type='hidden' data-degree-field='name' data-degree-idx='" + i + "' value='" + esc(d.name) + "'>" +
                    "<input type='hidden' data-degree-field='university' data-degree-idx='" + i + "' value='" + esc(d.university) + "'>" +
                    "<input type='hidden' data-degree-field='year' data-degree-idx='" + i + "' value='" + esc(d.year) + "'>"
                );
            });
        }

        function clearModal() {
            document.getElementById('degreeEditIdx').value = '-1';
            document.getElementById('degreeName').value = '';
            document.getElementById('degreeUniversity').value = '';
            document.getElementById('degreeYear').value = '';
            document.getElementById('degreeModalLabel').textContent = 'Add Degree';
        }

        function fillModal(idx) {
            var items = getAllData();
            var d = items[idx];
            document.getElementById('degreeEditIdx').value = idx;
            document.getElementById('degreeName').value = d.name;
            document.getElementById('degreeUniversity').value = d.university;
            document.getElementById('degreeYear').value = d.year;
            document.getElementById('degreeModalLabel').textContent = 'Edit Degree';
        }

        function readModal() {
            return {
                name: document.getElementById('degreeName').value.trim(),
                university: document.getElementById('degreeUniversity').value.trim(),
                year: document.getElementById('degreeYear').value.trim()
            };
        }

        document.getElementById('addDegreeBtn').addEventListener('click', function () { clearModal(); modal.show(); });

        document.getElementById('saveDegreeModalBtn').addEventListener('click', function () {
            var d = readModal();
            if (!d.name) { alert('Degree name is required.'); return; }
            var items = getAllData();
            var editIdx = parseInt(document.getElementById('degreeEditIdx').value);
            if (editIdx >= 0) { items[editIdx] = d; } else { items.push(d); }
            rebuild(items);
            saveDegreesToDatabase({ hideModalOnSuccess: true });
        });

        container.addEventListener('click', function (e) {
            var btn = e.target.closest('.edit-degree-btn');
            if (btn) { fillModal(parseInt(btn.dataset.idx)); modal.show(); return; }
            btn = e.target.closest('.remove-degree-btn');
            if (btn) {
                var items = getAllData();
                items.splice(parseInt(btn.dataset.idx), 1);
                rebuild(items);
                saveDegreesToDatabase();
            }
        });

        function saveDegreesToDatabase(options) {
            options = options || {};
            var items = getAllData();
            var body = new URLSearchParams();
            body.append('userID', document.getElementById('pageUserID').value);
            body.append('section', 'degrees');
            body.append('count', items.length);
            items.forEach(function (d, i) {
                body.append('name_' + i, d.name);
                body.append('univ_' + i, d.university);
                body.append('year_' + i, d.year);
            });
            var status = getSaveStatusEl('saveDegreesBtn', 'degreesSaveStatus');
            if (!status) return Promise.resolve({ success: false, message: 'Save status unavailable' });
            return ajaxSave('degrees', body, status, function (data) {
                /* Update composite degrees field if present */
                var comp = document.getElementById('compositeDegreesField');
                if (comp && data.composite) comp.value = data.composite;
            }).then(function (data) {
                if (data && data.success && options.hideModalOnSuccess) {
                    modal.hide();
                }
                return data;
            });
        }

    })();

    /* ────────────────────────────────────────────────────────
       AWARD SECTION
       ──────────────────────────────────────────────────────── */
    (function () {
        var container = document.getElementById('awardsContainer');
        if (!container) return;
        var modalEl = document.getElementById('awardModal');
        var modal = new bootstrap.Modal(modalEl);

        var awardSel = document.getElementById('awardSelect');
        var otherWrap = document.getElementById('awardOtherWrap');
        awardSel.addEventListener('change', function () {
            if (awardSel.value === 'Other') { otherWrap.classList.remove('d-none'); } else { otherWrap.classList.add('d-none'); document.getElementById('awardOtherInput').value = ''; }
            /* Auto-set type for predefined honors */
            if (typeof honorsSet !== 'undefined' && honorsSet[awardSel.value]) { document.getElementById('awardType').value = 'Honor'; }
        });

        function getAllData() {
            var items = [];
            var hiddens = container.querySelectorAll('input[data-award-field="name"]');
            hiddens.forEach(function (el) {
                var idx = el.getAttribute('data-award-idx');
                var get = function(f) { return (container.querySelector('input[data-award-field="'+f+'"][data-award-idx="'+idx+'"]') || {}).value || ''; };
                items.push({ name: el.value, type: get('type') });
            });
            return items;
        }

        function rebuild(items) {
            container.innerHTML = '';
            items.forEach(function (d, i) {
                container.insertAdjacentHTML('beforeend',
                    "<div class='card mb-2'><div class='card-body py-2 px-3'>" +
                    "<div class='d-flex justify-content-between align-items-center'><div>" +
                    "<strong>" + esc(d.name) + "</strong>" +
                    (d.type ? " <span class='badge bg-info text-dark'>" + esc(d.type) + "</span>" : "") +
                    "</div><div>" +
                    "<button type='button' class='btn btn-sm btn-edit edit-award-btn' data-idx='" + i + "'><i class='bi bi-pencil-square me-1'></i>Edit</button> " +
                    "<button type='button' class='btn btn-sm btn-remove remove-award-btn' data-idx='" + i + "'><i class='bi bi-trash me-1'></i>Remove</button>" +
                    "</div></div></div></div>" +
                    "<input type='hidden' data-award-field='name' data-award-idx='" + i + "' value='" + esc(d.name) + "'>" +
                    "<input type='hidden' data-award-field='type' data-award-idx='" + i + "' value='" + esc(d.type) + "'>"
                );
            });
        }

        function clearModal() {
            document.getElementById('awardEditIdx').value = '-1';
            document.getElementById('awardSelect').value = '';
            document.getElementById('awardOtherInput').value = '';
            otherWrap.classList.add('d-none');
            document.getElementById('awardType').value = '';
            document.getElementById('awardModalLabel').textContent = 'Add Award';
        }

        function fillModal(idx) {
            var items = getAllData();
            var d = items[idx];
            document.getElementById('awardEditIdx').value = idx;
            /* Check if name matches a predefined option */
            var opts = awardSel.options;
            var found = false;
            for (var oi = 0; oi < opts.length; oi++) {
                if (opts[oi].value === d.name) { found = true; break; }
            }
            if (found) {
                awardSel.value = d.name;
                otherWrap.classList.add('d-none');
            } else {
                awardSel.value = 'Other';
                otherWrap.classList.remove('d-none');
                document.getElementById('awardOtherInput').value = d.name;
            }
            document.getElementById('awardType').value = d.type;
            document.getElementById('awardModalLabel').textContent = 'Edit Award';
        }

        function readModal() {
            var name = awardSel.value === 'Other' ? document.getElementById('awardOtherInput').value.trim() : awardSel.value;
            return { name: name, type: document.getElementById('awardType').value };
        }

        document.getElementById('addAwardBtn').addEventListener('click', function () { clearModal(); modal.show(); });

        document.getElementById('saveAwardModalBtn').addEventListener('click', function () {
            var d = readModal();
            if (!d.name) { alert('Award name is required.'); return; }
            var items = getAllData();
            var editIdx = parseInt(document.getElementById('awardEditIdx').value);
            if (editIdx >= 0) { items[editIdx] = d; } else { items.push(d); }
            rebuild(items);
            saveAwardsToDatabase({ hideModalOnSuccess: true });
        });

        container.addEventListener('click', function (e) {
            var btn = e.target.closest('.edit-award-btn');
            if (btn) { fillModal(parseInt(btn.dataset.idx)); modal.show(); return; }
            btn = e.target.closest('.remove-award-btn');
            if (btn) {
                var items = getAllData();
                items.splice(parseInt(btn.dataset.idx), 1);
                rebuild(items);
                saveAwardsToDatabase();
            }
        });

        function saveAwardsToDatabase(options) {
            options = options || {};
            var items = getAllData();
            var body = new URLSearchParams();
            body.append('userID', document.getElementById('pageUserID').value);
            body.append('section', 'awards');
            body.append('count', items.length);
            items.forEach(function (d, i) {
                body.append('name_' + i, d.name);
                body.append('type_' + i, d.type);
            });
            var status = getSaveStatusEl('saveAwardsBtn', 'awardsSaveStatus');
            if (!status) return Promise.resolve({ success: false, message: 'Save status unavailable' });
            return ajaxSave('awards', body, status).then(function (data) {
                if (data && data.success && options.hideModalOnSuccess) {
                    modal.hide();
                }
                return data;
            });
        }

    })();

    /* ────────────────────────────────────────────────────────
       ADDRESS SECTION
       ──────────────────────────────────────────────────────── */
    (function () {
        var container = document.getElementById('addressesContainer');
        if (!container) return;
        var modalEl = document.getElementById('addressModal');
        var modal = new bootstrap.Modal(modalEl);

        function getAllData() {
            var items = [];
            var hiddens = container.querySelectorAll('input[data-addr-field="type"]');
            hiddens.forEach(function (el) {
                var idx = el.getAttribute('data-addr-idx');
                var get = function(f) { return (container.querySelector('input[data-addr-field="'+f+'"][data-addr-idx="'+idx+'"]') || {}).value || ''; };
                items.push({ type: el.value, addr1: get('addr1'), addr2: get('addr2'), city: get('city'),
                             state: get('state'), zip: get('zip'), building: get('building'), room: get('room'),
                             mailcode: get('mailcode'), primary: get('primary') });
            });
            return items;
        }

        function rebuild(items) {
            container.innerHTML = '';
            items.forEach(function (d, i) {
                var loc = [];
                if (d.addr1) loc.push(esc(d.addr1));
                if (d.addr2) loc.push(esc(d.addr2));
                var csz = [];
                if (d.city) csz.push(d.city);
                if (d.state) csz.push(d.state);
                var cszStr = csz.join(', ');
                if (d.zip) cszStr += ' ' + d.zip;
                if (cszStr) loc.push(esc(cszStr));
                var extras = [];
                if (d.building) extras.push('Bldg: ' + esc(d.building));
                if (d.room) extras.push('Rm: ' + esc(d.room));
                if (d.mailcode) extras.push('MC: ' + esc(d.mailcode));
                if (extras.length) loc.push(extras.join(' | '));

                container.insertAdjacentHTML('beforeend',
                    "<div class='card mb-2'><div class='card-body py-2 px-3'>" +
                    "<div class='d-flex justify-content-between align-items-start'><div>" +
                    "<strong>" + esc(d.type || '') + "</strong>" +
                    (d.primary === '1' ? " <span class='badge bg-success'>Primary</span>" : "") +
                    "<br><small class='text-muted'>" + loc.join('<br>') + "</small>" +
                    "</div><div>" +
                    "<button type='button' class='btn btn-sm btn-edit edit-address-btn' data-idx='" + i + "'><i class='bi bi-pencil-square me-1'></i>Edit</button> " +
                    "<button type='button' class='btn btn-sm btn-remove remove-address-btn' data-idx='" + i + "'><i class='bi bi-trash me-1'></i>Remove</button>" +
                    "</div></div></div></div>" +
                    "<input type='hidden' data-addr-field='type' data-addr-idx='" + i + "' value='" + esc(d.type) + "'>" +
                    "<input type='hidden' data-addr-field='addr1' data-addr-idx='" + i + "' value='" + esc(d.addr1) + "'>" +
                    "<input type='hidden' data-addr-field='addr2' data-addr-idx='" + i + "' value='" + esc(d.addr2) + "'>" +
                    "<input type='hidden' data-addr-field='city' data-addr-idx='" + i + "' value='" + esc(d.city) + "'>" +
                    "<input type='hidden' data-addr-field='state' data-addr-idx='" + i + "' value='" + esc(d.state) + "'>" +
                    "<input type='hidden' data-addr-field='zip' data-addr-idx='" + i + "' value='" + esc(d.zip) + "'>" +
                    "<input type='hidden' data-addr-field='building' data-addr-idx='" + i + "' value='" + esc(d.building) + "'>" +
                    "<input type='hidden' data-addr-field='room' data-addr-idx='" + i + "' value='" + esc(d.room) + "'>" +
                    "<input type='hidden' data-addr-field='mailcode' data-addr-idx='" + i + "' value='" + esc(d.mailcode) + "'>" +
                    "<input type='hidden' data-addr-field='primary' data-addr-idx='" + i + "' value='" + (d.primary || '0') + "'>"
                );
            });
        }

        function clearModal() {
            document.getElementById('addrEditIdx').value = '-1';
            document.getElementById('addrType').value = '';
            document.getElementById('addrAddr1').value = '';
            document.getElementById('addrAddr2').value = '';
            document.getElementById('addrCity').value = '';
            document.getElementById('addrState').value = '';
            document.getElementById('addrZip').value = '';
            document.getElementById('addrBuilding').value = '';
            document.getElementById('addrRoom').value = '';
            document.getElementById('addrMailcode').value = '';
            document.getElementById('addrPrimary').checked = false;
            document.getElementById('addressModalLabel').textContent = 'Add Address';
        }

        function fillModal(idx) {
            var items = getAllData();
            var d = items[idx];
            document.getElementById('addrEditIdx').value = idx;
            document.getElementById('addrType').value = d.type;
            document.getElementById('addrAddr1').value = d.addr1;
            document.getElementById('addrAddr2').value = d.addr2;
            document.getElementById('addrCity').value = d.city;
            document.getElementById('addrState').value = d.state;
            document.getElementById('addrZip').value = d.zip;
            document.getElementById('addrBuilding').value = d.building;
            document.getElementById('addrRoom').value = d.room;
            document.getElementById('addrMailcode').value = d.mailcode;
            document.getElementById('addrPrimary').checked = d.primary === '1';
            document.getElementById('addressModalLabel').textContent = 'Edit Address';
        }

        function readModal() {
            return {
                type: document.getElementById('addrType').value,
                addr1: document.getElementById('addrAddr1').value.trim(),
                addr2: document.getElementById('addrAddr2').value.trim(),
                city: document.getElementById('addrCity').value.trim(),
                state: document.getElementById('addrState').value.trim(),
                zip: document.getElementById('addrZip').value.trim(),
                building: document.getElementById('addrBuilding').value.trim(),
                room: document.getElementById('addrRoom').value.trim(),
                mailcode: document.getElementById('addrMailcode').value.trim(),
                primary: document.getElementById('addrPrimary').checked ? '1' : '0'
            };
        }

        /* Expose helpers so the "Copy to Addresses" button on the UH tab can inject a parsed address */
        container._addrGetAllData = getAllData;
        container._addrRebuild = rebuild;

        document.getElementById('addAddressBtn').addEventListener('click', function () { clearModal(); modal.show(); });

        document.getElementById('saveAddressBtn').addEventListener('click', function () {
            var d = readModal();
            if (!d.type) { alert('Address Type is required.'); return; }
            var items = getAllData();
            var editIdx = parseInt(document.getElementById('addrEditIdx').value);
            if (editIdx >= 0) { items[editIdx] = d; } else { items.push(d); }
            rebuild(items);
            saveAddressesToDatabase({ hideModalOnSuccess: true });
        });

        container.addEventListener('click', function (e) {
            var btn = e.target.closest('.edit-address-btn');
            if (btn) { fillModal(parseInt(btn.dataset.idx)); modal.show(); return; }
            btn = e.target.closest('.remove-address-btn');
            if (btn) {
                var items = getAllData();
                items.splice(parseInt(btn.dataset.idx), 1);
                rebuild(items);
                saveAddressesToDatabase();
            }
        });

        function saveAddressesToDatabase(options) {
            options = options || {};
            var items = getAllData();
            var body = new URLSearchParams();
            body.append('userID', document.getElementById('pageUserID').value);
            body.append('section', 'addresses');
            body.append('count', items.length);
            items.forEach(function (d, i) {
                body.append('type_' + i, d.type);
                body.append('addr1_' + i, d.addr1);
                body.append('addr2_' + i, d.addr2);
                body.append('city_' + i, d.city);
                body.append('state_' + i, d.state);
                body.append('zip_' + i, d.zip);
                body.append('building_' + i, d.building);
                body.append('room_' + i, d.room);
                body.append('mailcode_' + i, d.mailcode);
                body.append('primary_' + i, d.primary);
            });
            var status = getSaveStatusEl('saveAddressesBtn', 'addressesSaveStatus');
            if (!status) return Promise.resolve({ success: false, message: 'Save status unavailable' });
            return ajaxSave('addresses', body, status).then(function (data) {
                if (data && data.success && options.hideModalOnSuccess) {
                    modal.hide();
                }
                return data;
            });
        }

    })();

    /* ══════════════════════════════════════════════════════════════
       Per-Tab AJAX Save Handlers
       ══════════════════════════════════════════════════════════════ */

    function saveSectionAjax(section, body, statusEl) {
        if (statusEl) { statusEl.textContent = ''; }
        fetch('/admin/users/saveSection.cfm', { method: 'POST', body: body })
            .then(function (r) { return r.json(); })
            .then(function (data) {
                if (data.success) {
                    showSaveToast('Saved successfully.');
                    clearDirty(section);
                } else {
                    showSaveToast((data.message || 'Error saving.'), true);
                }
            })
            .catch(function (err) {
                showSaveToast('Network error: ' + (err && err.message ? err.message : 'Unknown'), true);
            });
    }

    var pageUserID = document.getElementById('pageUserID').value;

    wireSectionDirty('general', document.getElementById('general-pane'));
    wireSectionDirty('flags', document.getElementById('flags-pane'));
    wireSectionDirty('orgs', document.getElementById('orgs-pane'));
    wireSectionDirty('extids', document.getElementById('extids-pane'));
    wireSectionDirty('uh', document.getElementById('address-pane'));
    wireSectionDirty('bioinfo', document.getElementById('bio-info-pane'));
    wireSectionDirty('studentprofile', document.getElementById('student-profile-pane'));
    wireSectionDirty('tabdegrees', document.getElementById('faculty-profile-pane'));
    wireSectionDirty('tabdegrees', document.getElementById('emeritus-profile-pane'));
    wireSectionDirty('tabdegrees', document.getElementById('resident-profile-pane'));
    wireSectionDirty('bio', document.getElementById('bio-pane'));

    wireRepeaterDirty('emails', document.getElementById('emailsContainer'));
    wireRepeaterDirty('phones', document.getElementById('phonesContainer'));
    wireRepeaterDirty('aliases', document.getElementById('aliasesContainer'));
    wireRepeaterDirty('addresses', document.getElementById('addressesContainer'));
    wireRepeaterDirty('degrees', document.getElementById('degreesContainer'));
    wireRepeaterDirty('awards', document.getElementById('awardsContainer'));

    window.addEventListener('users-edit-tab-selected', function (event) {
        var tabId = event && event.detail ? (event.detail.tabId || '') : '';
        if (!tabId) return;
        refreshTabData(tabId);
    });

    var refreshGeneralInfoBtn = document.getElementById('refreshGeneralInfoBtn');
    if (refreshGeneralInfoBtn) {
        refreshGeneralInfoBtn.addEventListener('click', function () {
            refreshTabData('general-tab');
        });
    }

    var refreshContactInfoBtn = document.getElementById('refreshContactInfoBtn');
    if (refreshContactInfoBtn) {
        refreshContactInfoBtn.addEventListener('click', function () {
            refreshTabData('contact-tab');
        });
    }

    var refreshBiographicalInfoBtn = document.getElementById('refreshBiographicalInfoBtn');
    if (refreshBiographicalInfoBtn) {
        refreshBiographicalInfoBtn.addEventListener('click', function () {
            refreshTabData('bio-info-tab');
        });
    }

    var refreshFlagsBtn = document.getElementById('refreshFlagsBtn');
    if (refreshFlagsBtn) {
        refreshFlagsBtn.addEventListener('click', function () {
            refreshTabData('flags-tab');
        });
    }

    var refreshOrgsBtn = document.getElementById('refreshOrgsBtn');
    if (refreshOrgsBtn) {
        refreshOrgsBtn.addEventListener('click', function () {
            refreshTabData('orgs-tab');
        });
    }

    var refreshExtidsBtn = document.getElementById('refreshExtidsBtn');
    if (refreshExtidsBtn) {
        refreshExtidsBtn.addEventListener('click', function () {
            refreshTabData('extids-tab');
        });
    }

    var refreshUhBtn = document.getElementById('refreshUhBtn');
    if (refreshUhBtn) {
        refreshUhBtn.addEventListener('click', function () {
            refreshTabData('address-tab');
        });
    }

    /* ── Contact tab bulk save ── */
    var saveContactBtn = document.getElementById('save-contact-btn');
    if (saveContactBtn) {
        saveContactBtn.addEventListener('click', function () {
            var status = document.getElementById('save-contact-status');
            var emailPane = document.getElementById('contact-pane');
            if (!emailPane) {
                return;
            }

            function postSection(body) {
                return fetch('/admin/users/saveSection.cfm', {
                    method: 'POST',
                    body: body
                }).then(function (r) { return r.json(); });
            }

            function buildEmailsBody() {
                var body = new URLSearchParams();
                var items = [];
                var hiddens = emailPane.querySelectorAll('#emailsContainer input[data-email-field="addr"]');
                hiddens.forEach(function (el) {
                    var idx = el.getAttribute('data-email-idx');
                    var get = function (f) {
                        var target = emailPane.querySelector('#emailsContainer input[data-email-field="' + f + '"][data-email-idx="' + idx + '"]');
                        return target ? target.value : '';
                    };
                    items.push({ addr: el.value, type: get('type'), primary: get('primary') });
                });
                body.append('userID', pageUserID);
                body.append('section', 'emails');
                body.append('count', items.length);
                var primaryIdx = -1;
                items.forEach(function (d, i) {
                    body.append('address_' + i, d.addr || '');
                    body.append('type_' + i, d.type || '');
                    if ((d.primary || '0') === '1') {
                        primaryIdx = i;
                    }
                });
                body.append('primary_idx', primaryIdx);
                return body;
            }

            function buildPhonesBody() {
                var body = new URLSearchParams();
                var items = [];
                var hiddens = emailPane.querySelectorAll('#phonesContainer input[data-phone-field="number"]');
                hiddens.forEach(function (el) {
                    var idx = el.getAttribute('data-phone-idx');
                    var get = function (f) {
                        var target = emailPane.querySelector('#phonesContainer input[data-phone-field="' + f + '"][data-phone-idx="' + idx + '"]');
                        return target ? target.value : '';
                    };
                    items.push({ number: el.value, type: get('type'), primary: get('primary') });
                });
                body.append('userID', pageUserID);
                body.append('section', 'phones');
                body.append('count', items.length);
                var primaryIdx = -1;
                items.forEach(function (d, i) {
                    body.append('number_' + i, d.number || '');
                    body.append('type_' + i, d.type || '');
                    if ((d.primary || '0') === '1') {
                        primaryIdx = i;
                    }
                });
                body.append('primary_idx', primaryIdx);
                return body;
            }

            function buildAddressesBody() {
                var body = new URLSearchParams();
                var items = [];
                var hiddens = emailPane.querySelectorAll('#addressesContainer input[data-addr-field="type"]');
                hiddens.forEach(function (el) {
                    var idx = el.getAttribute('data-addr-idx');
                    var get = function (f) {
                        var target = emailPane.querySelector('#addressesContainer input[data-addr-field="' + f + '"][data-addr-idx="' + idx + '"]');
                        return target ? target.value : '';
                    };
                    items.push({
                        type: el.value,
                        addr1: get('addr1'),
                        addr2: get('addr2'),
                        city: get('city'),
                        state: get('state'),
                        zip: get('zip'),
                        building: get('building'),
                        room: get('room'),
                        mailcode: get('mailcode'),
                        primary: get('primary')
                    });
                });
                body.append('userID', pageUserID);
                body.append('section', 'addresses');
                body.append('count', items.length);
                items.forEach(function (d, i) {
                    body.append('type_' + i, d.type || '');
                    body.append('addr1_' + i, d.addr1 || '');
                    body.append('addr2_' + i, d.addr2 || '');
                    body.append('city_' + i, d.city || '');
                    body.append('state_' + i, d.state || '');
                    body.append('zip_' + i, d.zip || '');
                    body.append('building_' + i, d.building || '');
                    body.append('room_' + i, d.room || '');
                    body.append('mailcode_' + i, d.mailcode || '');
                    body.append('primary_' + i, d.primary || '0');
                });
                return body;
            }

            saveContactBtn.disabled = true;
            if (status) {
                status.textContent = 'Saving...';
                status.style.color = '#666';
            }

            Promise.all([
                postSection(buildEmailsBody()),
                postSection(buildPhonesBody()),
                postSection(buildAddressesBody())
            ]).then(function (results) {
                var ok = results.every(function (r) { return r && r.success; });
                showSaveToast(ok ? 'Contact info saved.' : 'Some sections failed to save.', !ok);
                if (ok) {
                    clearDirty('emails');
                    clearDirty('phones');
                    clearDirty('addresses');
                }
            }).catch(function () {
                showSaveToast('Network error saving contact info.', true);
            }).finally(function () {
                saveContactBtn.disabled = false;
            });
        });
    }

    /* ── General tab ── */
    var saveGeneralBtn = document.getElementById('save-general-btn');
    if (saveGeneralBtn) {
        saveGeneralBtn.addEventListener('click', function () {
            var pane = document.getElementById('general-pane');
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'general');
            ['Prefix','Suffix','Pronouns','FirstName','MiddleName','LastName','Title1','Title2','Title3'].forEach(function (f) {
                var el = pane.querySelector('[name="' + f + '"]');
                body.append(f, el ? el.value : '');
            });
            saveSectionAjax('general', body, document.getElementById('save-general-status'));
        });
    }

    /* ── Flags tab ── */
    var saveFlagsBtn = document.getElementById('save-flags-btn');
    if (saveFlagsBtn) {
        saveFlagsBtn.addEventListener('click', function () {
            var pane = document.getElementById('flags-pane');
            var checked = pane.querySelectorAll('input[name="Flags"]:checked');
            var ids = [];
            checked.forEach(function (cb) { ids.push(cb.value); });
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'flags');
            body.append('flagIDs', ids.join(','));
            saveSectionAjax('flags', body, document.getElementById('save-flags-status'));
        });
    }

    /* ── Organizations tab ── */
    var saveOrgsBtn = document.getElementById('save-orgs-btn');
    if (saveOrgsBtn) {
        saveOrgsBtn.addEventListener('click', function () {
            var pane = document.getElementById('orgs-pane');
            var checked = pane.querySelectorAll('input[name="Organizations"]:checked');
            var ids = [];
            checked.forEach(function (cb) { ids.push(cb.value); });
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'orgs');
            body.append('orgIDs', ids.join(','));
            checked.forEach(function (cb) {
                var orgID = cb.value;
                var titleEl = pane.querySelector('[name="roleTitle_' + orgID + '"]');
                var orderEl = pane.querySelector('[name="roleOrder_' + orgID + '"]');
                body.append('roleTitle_' + orgID, titleEl ? titleEl.value : '');
                body.append('roleOrder_' + orgID, orderEl ? orderEl.value : '0');
            });
            saveSectionAjax('orgs', body, document.getElementById('save-orgs-status'));
        });
    }

    /* ── External IDs tab ── */
    function escHtml(str) {
        return String(str || '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/\"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    var extidsLdapModalEl = document.getElementById('extidsLdapModal');
    var extidsLdapModal = extidsLdapModalEl ? new bootstrap.Modal(extidsLdapModalEl) : null;
    var extidsLdapRows = [];
    var extidsLdapStatusEl = document.getElementById('extids-ldap-status');
    var extidsLdapResultsBody = document.getElementById('extidsLdapResultsBody');

    function setExtidsLdapStatus(text, isError) {
        if (!extidsLdapStatusEl) {
            return;
        }
        extidsLdapStatusEl.textContent = text || '';
        extidsLdapStatusEl.classList.toggle('text-danger', !!isError);
        extidsLdapStatusEl.classList.toggle('text-muted', !isError);
    }

    function renderExtidsLdapRows(rows) {
        if (!extidsLdapResultsBody) {
            return;
        }
        if (!rows || !rows.length) {
            extidsLdapResultsBody.innerHTML = '<tr><td colspan="5" class="text-muted p-3">No matches found.</td></tr>';
            return;
        }

        extidsLdapResultsBody.innerHTML = rows.map(function (row, idx) {
            return '' +
                '<tr>' +
                    '<td>' + escHtml(row.displayName) + '</td>' +
                    '<td><code>' + escHtml(row.samAccountName) + '</code></td>' +
                    '<td>' + escHtml(row.employeeID) + '</td>' +
                    '<td>' + escHtml(row.mail) + '</td>' +
                    '<td class="text-end"><button type="button" class="btn btn-sm btn-outline-primary js-extids-ldap-select" data-idx="' + idx + '">Use</button></td>' +
                '</tr>';
        }).join('');
    }

    function normalizeLdapRow(row) {
        row = row || {};
        return {
            displayName: row.displayName || row.DISPLAYNAME || '',
            samAccountName: row.samAccountName || row.SAMACCOUNTNAME || '',
            employeeID: row.employeeID || row.EMPLOYEEID || '',
            mail: row.mail || row.MAIL || '',
            department: row.department || row.DEPARTMENT || '',
            title: row.title || row.TITLE || ''
        };
    }

    // Read alias objects from the hidden inputs stamped into the DOM by ColdFusion.
    function readAliasesFromDOM() {
        var aliases = {};
        document.querySelectorAll('[data-alias-field][data-alias-idx]').forEach(function (el) {
            var idx = el.getAttribute('data-alias-idx');
            var field = el.getAttribute('data-alias-field');
            if (!aliases[idx]) { aliases[idx] = {}; }
            aliases[idx][field] = el.value;
        });
        return Object.values(aliases);
    }

    // Format a name object {first, middle, last} into "Last, First M." style.
    function formatAliasName(a) {
        var first = (a.first || '').trim();
        var middle = (a.middle || '').trim();
        var last = (a.last || '').trim();
        if (!first && !last) { return ''; }
        var middleInitial = middle.length ? (' ' + middle.charAt(0)) : '';
        if (first && last) { return last + ', ' + first + middleInitial; }
        return (first + ' ' + last).trim();
    }

    // Build the ordered list of search terms to try for an LDAP name-based lookup.
    // Returns an array: name terms first (deduplicated), email as final fallback.
    function buildLdapSearchTerms(cougarnetEl, emailEl) {
        var aliases = readAliasesFromDOM();
        var nameTerms = [];
        var seen = {};

        // If CougarNet ID is populated, use it exclusively (sAMAccountName match).
        if (cougarnetEl && cougarnetEl.value.trim().length) {
            return [cougarnetEl.value.trim()];
        }

        // Check for an alias flagged as LDAP source — if found, use only that one.
        var ldapAlias = null;
        for (var i = 0; i < aliases.length; i++) {
            if ((aliases[i].source || '').trim().toUpperCase() === 'LDAP') {
                ldapAlias = aliases[i];
                break;
            }
        }

        if (ldapAlias) {
            var t = formatAliasName(ldapAlias);
            if (t.length >= 2) { nameTerms.push(t); }
        } else {
            // Use all aliases.
            for (var j = 0; j < aliases.length; j++) {
                var term = formatAliasName(aliases[j]);
                if (term.length >= 2 && !seen[term]) {
                    seen[term] = true;
                    nameTerms.push(term);
                }
            }

            // Also include the canonical name from the form fields.
            var firstEl  = document.querySelector('#general-pane [name="FirstName"]');
            var middleEl = document.querySelector('#general-pane [name="MiddleName"]');
            var lastEl   = document.querySelector('#general-pane [name="LastName"]');
            var canonical = formatAliasName({
                first:  firstEl  ? firstEl.value  : '',
                middle: middleEl ? middleEl.value : '',
                last:   lastEl   ? lastEl.value   : ''
            });
            if (canonical.length >= 2 && !seen[canonical]) {
                seen[canonical] = true;
                nameTerms.push(canonical);
            }
        }

        // Email fallback appended last.
        var email = emailEl ? emailEl.value.trim() : '';
        if (email.length >= 2 && !seen[email]) {
            nameTerms.push(email);
        }

        return nameTerms;
    }

    // Run one LDAP fetch for a single search term; resolves with the payload.
    function fetchLdapTerm(term) {
        var body = new URLSearchParams();
        body.append('searchTerm', term);
        body.append('userID', pageUserID);
        body.append('maxRows', '25');
        return fetch('/admin/users/ldap_lookup.cfm', {
            method: 'POST',
            body: body,
            credentials: 'same-origin'
        }).then(function (r) { return r.json(); });
    }

    // Try each search term in sequence; stop as soon as one returns rows.
    function fetchLdapSequential(terms) {
        if (!terms.length) {
            return Promise.resolve({ success: false, message: 'No search terms available.', data: [] });
        }
        return fetchLdapTerm(terms[0]).then(function (payload) {
            var ok   = payload && (payload.success === true || payload.SUCCESS === true);
            var rows = payload ? (payload.data || payload.DATA || []) : [];
            if (ok && rows.length > 0) {
                return payload;
            }
            // No results — try remaining terms.
            var remaining = terms.slice(1);
            if (!remaining.length) {
                return payload; // Return the last (empty) payload as the final answer.
            }
            return fetchLdapSequential(remaining);
        });
    }

    document.addEventListener('click', function (event) {
        var lookupBtn = event.target.closest('.js-cougarnet-lookup');
        if (lookupBtn) {
            var cougarnetEl = document.getElementById('extid-cougarnet-input');
            var emailEl = document.querySelector('#address-pane [name="EmailPrimary"]') || document.querySelector('#general-pane [name="EmailPrimary"]');
            var searchTerms = buildLdapSearchTerms(cougarnetEl, emailEl);

            if (!searchTerms.length || (searchTerms.length === 1 && searchTerms[0].length < 2)) {
                setExtidsLdapStatus('Enter at least 2 characters in CougarNet ID, email, or name before lookup.', true);
                return;
            }

            lookupBtn.disabled = true;
            setExtidsLdapStatus('Searching LDAP...', false);

            fetchLdapSequential(searchTerms)
            .then(function (payload) {
                var ok = payload && (payload.success === true || payload.SUCCESS === true);
                var message = payload ? (payload.message || payload.MESSAGE) : '';
                var rows = payload ? (payload.data || payload.DATA || []) : [];

                if (!ok) {
                    extidsLdapRows = [];
                    renderExtidsLdapRows(extidsLdapRows);
                    setExtidsLdapStatus(message || 'Lookup failed.', true);
                    if (extidsLdapModal) { extidsLdapModal.show(); }
                    return;
                }

                extidsLdapRows = rows.map(normalizeLdapRow);
                renderExtidsLdapRows(extidsLdapRows);
                setExtidsLdapStatus(extidsLdapRows.length + ' match(es) found.', false);
                if (extidsLdapModal) { extidsLdapModal.show(); }
            })
            .catch(function (err) {
                setExtidsLdapStatus('Network error: ' + err.message, true);
            })
            .finally(function () {
                lookupBtn.disabled = false;
            });
            return;
        }

        var selectBtn = event.target.closest('.js-extids-ldap-select');
        if (selectBtn) {
            var idx = parseInt(selectBtn.getAttribute('data-idx'), 10);
            var row = extidsLdapRows[idx] || null;
            var cougarnetInput = document.getElementById('extid-cougarnet-input');
            var peoplesoftInput = document.getElementById('extid-peoplesoft-input');
            if (row) {
                if (cougarnetInput) {
                    cougarnetInput.value = row.samAccountName || '';
                }
                if (peoplesoftInput) {
                    peoplesoftInput.value = row.employeeID || '';
                }
                markDirty('extids');
                setExtidsLdapStatus('Selected ' + (row.samAccountName || '') + '.', false);

                if (row.mail) {
                    var emailBody = new URLSearchParams();
                    emailBody.append('userID', pageUserID);
                    emailBody.append('section', 'addLdapEmailIfMissing');
                    emailBody.append('email', row.mail);
                    fetch('/admin/users/saveSection.cfm', {
                        method: 'POST',
                        body: emailBody,
                        credentials: 'same-origin'
                    })
                    .then(function (r) { return r.json(); })
                    .then(function (payload) {
                        if (payload && payload.success && payload.inserted) {
                            setExtidsLdapStatus('Selected ' + (row.samAccountName || '') + ' and added email ' + row.mail + '.', false);
                        }
                    })
                    .catch(function () {
                        // Ignore background email sync failures to keep lookup UX smooth.
                    });
                }

                if (row.displayName) {
                    var aliasBody = new URLSearchParams();
                    aliasBody.append('userID', pageUserID);
                    aliasBody.append('section', 'addLdapAliasIfMissing');
                    aliasBody.append('displayName', row.displayName);
                    fetch('/admin/users/saveSection.cfm', {
                        method: 'POST',
                        body: aliasBody,
                        credentials: 'same-origin'
                    })
                    .catch(function () {
                        // Ignore background alias sync failures to keep lookup UX smooth.
                    });
                }
            }
            if (extidsLdapModal) {
                extidsLdapModal.hide();
            }
        }
    });

    var saveExtidsBtn = document.getElementById('save-extids-btn');
    if (saveExtidsBtn) {
        saveExtidsBtn.addEventListener('click', function () {
            var pane = document.getElementById('extids-pane');
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'extids');
            pane.querySelectorAll('input[name^="extID_"]').forEach(function (inp) {
                body.append(inp.name, inp.value);
            });
            saveSectionAjax('extids', body, document.getElementById('save-extids-status'));
        });
    }

    /* ── UH Admin tab (SuperAdmin) ── */
    var saveUhBtn = document.getElementById('save-uh-btn');
    if (saveUhBtn) {
        saveUhBtn.addEventListener('click', function () {
            var pane = document.getElementById('address-pane');
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'uh');
            ['EmailPrimary','UH_API_ID','Room','Building','Campus','Division','DivisionName','Department','DepartmentName','Office_Mailing_Address','Mailcode'].forEach(function (f) {
                var el = pane.querySelector('[name="' + f + '"]');
                body.append(f, el ? el.value : '');
            });
            saveSectionAjax('uh', body, document.getElementById('save-uh-status'));
        });
    }

    /* ── Copy Office Mailing Address → Addresses tab ── */
    var copyAddrBtn = document.getElementById('copyToAddressesBtn');
    if (copyAddrBtn) {
        copyAddrBtn.addEventListener('click', function () {
            var raw = (document.getElementById('officeMailingAddress').value || '').trim();
            if (!raw) { alert('Office Mailing Address is empty.'); return; }

            /* Parse: "4349 Martin Luther King Blvd Health 1 RM 230 Houston, TX 77204-2020" */
            var parsed = { type: 'Office', addr1: '', addr2: '', city: '', state: '', zip: '',
                           building: '', room: '', mailcode: '', primary: '0' };

            var work = raw;

            /* Extract Room: RM/Room followed by digits */
            var rmMatch = work.match(/\b(?:RM|Room)\s+(\S+)/i);
            if (rmMatch) {
                parsed.room = rmMatch[1];
                work = work.replace(rmMatch[0], '').trim();
            }

            /* Known addresses and buildings for UHCO campus — match these FIRST
               so that punctuation in building names (e.g. "J. Davis Armistead")
               doesn't confuse the city/state/zip regex. */
            var knownAddresses = [
                { street: '4401 Martin Luther King Blvd', building: 'J. Davis Armistead' },
                { street: '4349 Martin Luther King Blvd', building: 'Health 1' }
            ];
            var matched = false;
            for (var ki = 0; ki < knownAddresses.length; ki++) {
                var ka = knownAddresses[ki];
                if (work.indexOf(ka.street) === 0) {
                    parsed.addr1 = ka.street;
                    var remainder = work.substring(ka.street.length).trim();
                    /* Strip known building name from the front of remainder */
                    if (remainder.indexOf(ka.building) === 0) {
                        parsed.building = ka.building;
                        remainder = remainder.substring(ka.building.length).trim();
                    }
                    /* Whatever is left should be "Houston, TX 77204-2020" */
                    var cszMatch = remainder.match(/,?\s*([A-Za-z\s]+),\s*([A-Z]{2})\s+(\d{5}(?:-\d{4})?)\s*$/);
                    if (cszMatch) {
                        parsed.city  = cszMatch[1].trim();
                        parsed.state = cszMatch[2];
                        parsed.zip   = cszMatch[3];
                    } else if (!parsed.building && remainder.length) {
                        /* Couldn't parse city/state — put leftover in building */
                        parsed.building = remainder;
                    }
                    matched = true;
                    break;
                }
            }

            if (!matched) {
                /* Extract City, State ZIP from the end: "Houston, TX 77204-2020" */
                var cszMatch = work.match(/,?\s*([A-Za-z\s]+),\s*([A-Z]{2})\s+(\d{5}(?:-\d{4})?)\s*$/);
                if (cszMatch) {
                    parsed.city  = cszMatch[1].trim();
                    parsed.state = cszMatch[2];
                    parsed.zip   = cszMatch[3];
                    work = work.substring(0, work.length - cszMatch[0].length).trim();
                }
                /* Fallback: split at street suffix */
                var streetEnd = work.search(/\b(Blvd|Boulevard|St|Street|Ave|Avenue|Dr|Drive|Rd|Road|Hwy|Highway|Pkwy|Parkway|Way|Lane|Ln|Circle|Cir)\b\.?\s*/i);
                if (streetEnd >= 0) {
                    var suffixMatch = work.substring(streetEnd).match(/^(\S+\.?)\s*(.*)/);
                    if (suffixMatch) {
                        parsed.addr1 = work.substring(0, streetEnd).trim() + ' ' + suffixMatch[1];
                        parsed.building = (suffixMatch[2] || '').trim();
                    }
                } else {
                    parsed.addr1 = work;
                }
            }

            /* Pull Mailcode from the UH pane if present */
            var mcEl = document.querySelector('[name="Mailcode"]');
            if (mcEl && mcEl.value.trim()) { parsed.mailcode = mcEl.value.trim(); }

            /* Pre-fill the address modal with parsed values for user review */
            document.getElementById('addrEditIdx').value = '-1';
            document.getElementById('addrType').value = parsed.type;
            document.getElementById('addrAddr1').value = parsed.addr1;
            document.getElementById('addrAddr2').value = parsed.addr2;
            document.getElementById('addrCity').value = parsed.city;
            document.getElementById('addrState').value = parsed.state;
            document.getElementById('addrZip').value = parsed.zip;
            document.getElementById('addrBuilding').value = parsed.building;
            document.getElementById('addrRoom').value = parsed.room;
            document.getElementById('addrMailcode').value = parsed.mailcode;
            document.getElementById('addrPrimary').checked = false;
            document.getElementById('addressModalLabel').textContent = 'Review Parsed Address';

            /* Swap buttons: hide the JS-only Save, show the Save to Database button */
            document.getElementById('saveAddressBtn').classList.add('d-none');
            document.getElementById('saveAddressToDbBtn').classList.remove('d-none');

            var addrModal = bootstrap.Modal.getOrCreateInstance(document.getElementById('addressModal'));
            addrModal.show();
        });
    }

    /* Save to Database button — direct AJAX insert for copied addresses */
    var saveToDbBtn = document.getElementById('saveAddressToDbBtn');
    if (saveToDbBtn) {
        saveToDbBtn.addEventListener('click', function () {
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'addAddress');
            body.append('type', document.getElementById('addrType').value);
            body.append('addr1', document.getElementById('addrAddr1').value.trim());
            body.append('addr2', document.getElementById('addrAddr2').value.trim());
            body.append('city', document.getElementById('addrCity').value.trim());
            body.append('state', document.getElementById('addrState').value.trim());
            body.append('zip', document.getElementById('addrZip').value.trim());
            body.append('building', document.getElementById('addrBuilding').value.trim());
            body.append('room', document.getElementById('addrRoom').value.trim());
            body.append('mailcode', document.getElementById('addrMailcode').value.trim());
            body.append('primary', document.getElementById('addrPrimary').checked ? '1' : '0');

            saveToDbBtn.disabled = true;
            saveToDbBtn.textContent = 'Saving...';

            fetch('/admin/users/saveSection.cfm', { method: 'POST', body: body })
                .then(function (r) { return r.json(); })
                .then(function (data) {
                    if (data.success) {
                        /* Add the new address card to the Contact tab via exposed helpers */
                        var addrContainer = document.getElementById('addressesContainer');
                        if (addrContainer && addrContainer._addrGetAllData && addrContainer._addrRebuild) {
                            var items = addrContainer._addrGetAllData();
                            items.push({
                                type: document.getElementById('addrType').value,
                                addr1: document.getElementById('addrAddr1').value.trim(),
                                addr2: document.getElementById('addrAddr2').value.trim(),
                                city: document.getElementById('addrCity').value.trim(),
                                state: document.getElementById('addrState').value.trim(),
                                zip: document.getElementById('addrZip').value.trim(),
                                building: document.getElementById('addrBuilding').value.trim(),
                                room: document.getElementById('addrRoom').value.trim(),
                                mailcode: document.getElementById('addrMailcode').value.trim(),
                                primary: document.getElementById('addrPrimary').checked ? '1' : '0'
                            });
                            addrContainer._addrRebuild(items);
                        }
                        bootstrap.Modal.getInstance(document.getElementById('addressModal')).hide();
                    } else {
                        alert('Error: ' + (data.message || 'Save failed.'));
                    }
                })
                .catch(function (err) { alert('Network error: ' + err.message); })
                .finally(function () {
                    saveToDbBtn.disabled = false;
                    saveToDbBtn.textContent = 'Save to Database';
                });
        });
    }

    /* Reset address modal buttons when closed */
    var addrModalEl = document.getElementById('addressModal');
    if (addrModalEl) {
        addrModalEl.addEventListener('hidden.bs.modal', function () {
            document.getElementById('saveAddressBtn').classList.remove('d-none');
            document.getElementById('saveAddressToDbBtn').classList.add('d-none');
        });
    }

    /* ── Biographical Info tab (DOB, Gender) ── */
    var saveBioinfoBtn = document.getElementById('save-bioinfo-btn');
    if (saveBioinfoBtn) {
        saveBioinfoBtn.addEventListener('click', function () {
            var pane = document.getElementById('bio-info-pane');
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'bioinfo');
            var dobEl = pane.querySelector('[name="DOB"]');
            var genEl = pane.querySelector('[name="Gender"]');
            body.append('DOB', dobEl ? dobEl.value : '');
            body.append('Gender', genEl ? genEl.value : '');

            ['CurrentGradYear','OriginalGradYear','sp_first_externship','sp_second_externship','sp_commencement_age'].forEach(function (f) {
                var el = pane.querySelector('[name="' + f + '"]');
                body.append(f, el ? el.value : '');
            });

            var editorEl = pane ? pane.querySelector('.users-edit-bio-editor') : null;
            var editorBody = editorEl ? editorEl.querySelector('.ql-editor') : null;
            var html = editorBody ? editorBody.innerHTML : '';
            if (html === '<p><br></p>') html = '';
            body.append('bioContent', html);

            saveSectionAjax('bioinfo', body, document.getElementById('save-bioinfo-status'));
        });
    }

    /* ── Student Profile tab ── */
    var saveStudentBtn = document.getElementById('save-studentprofile-btn');
    if (saveStudentBtn) {
        saveStudentBtn.addEventListener('click', function () {
            var pane = document.getElementById('student-profile-pane');
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'studentprofile');
            ['CurrentGradYear','OriginalGradYear','sp_first_externship','sp_second_externship','sp_commencement_age'].forEach(function (f) {
                var el = pane.querySelector('[name="' + f + '"]');
                body.append(f, el ? el.value : '');
            });
            /* sp degrees */
            var countEl = pane.querySelector('[id="sp_degreeCount"]');
            var spCount = countEl ? parseInt(countEl.value, 10) || 0 : 0;
            body.append('sp_degree_count', spCount);
            for (var i = 0; i < spCount; i++) {
                var n = pane.querySelector('[name="sp_deg_name_' + i + '"]');
                var u = pane.querySelector('[name="sp_deg_univ_' + i + '"]');
                var y = pane.querySelector('[name="sp_deg_year_' + i + '"]');
                body.append('sp_deg_name_' + i, n ? n.value : '');
                body.append('sp_deg_univ_' + i, u ? u.value : '');
                body.append('sp_deg_year_' + i, y ? y.value : '');
            }
            saveSectionAjax('studentprofile', body, document.getElementById('save-studentprofile-status'));
        });
    }

    /* ── Faculty / Emeritus / Resident degree tabs ── */
    function setupDegreeTabSave(btnId, statusId, prefix) {
        var btn = document.getElementById(btnId);
        if (!btn) return;
        btn.addEventListener('click', function () {
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'tabdegrees');
            body.append('prefix', prefix);
            var countEl = document.getElementById(prefix + '_degreeCount');
            var count = countEl ? parseInt(countEl.value, 10) || 0 : 0;
            body.append(prefix + '_degree_count', count);
            for (var i = 0; i < count; i++) {
                var n = document.querySelector('[name="' + prefix + '_deg_name_' + i + '"]');
                var u = document.querySelector('[name="' + prefix + '_deg_univ_' + i + '"]');
                var y = document.querySelector('[name="' + prefix + '_deg_year_' + i + '"]');
                body.append(prefix + '_deg_name_' + i, n ? n.value : '');
                body.append(prefix + '_deg_univ_' + i, u ? u.value : '');
                body.append(prefix + '_deg_year_' + i, y ? y.value : '');
            }
            saveSectionAjax('tabdegrees', body, document.getElementById(statusId));
        });
    }
    setupDegreeTabSave('save-facultydeg-btn', 'save-facultydeg-status', 'fac');
    setupDegreeTabSave('save-emeritusdeg-btn', 'save-emeritusdeg-status', 'emer');
    setupDegreeTabSave('save-residentdeg-btn', 'save-residentdeg-status', 'res');

    /* ── Bio tab ── */
    var saveBioBtn = document.getElementById('save-bio-btn');
    if (saveBioBtn) {
        saveBioBtn.addEventListener('click', function () {
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'bio');
            var editorEl = document.getElementById('bio-editor');
            var html = editorEl ? editorEl.querySelector('.ql-editor').innerHTML : '';
            if (html === '<p><br></p>') html = '';
            body.append('bioContent', html);
            saveSectionAjax('bio', body, document.getElementById('save-bio-status'));
        });
    }

});