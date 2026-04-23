    <cfif NOT request.hasPermission("users.edit")>
        <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
    </cfif>

    <cfset content = "">
    <cfsavecontent variable="content">
    <cfoutput>
    <div class="container-fluid py-3">
        <h1 class="h4 mb-2">LDAP Lookup Test Harness</h1>
        <p class="text-muted mb-4">
            This page tests the secure lookup endpoint used for Cougarnet ID discovery.
            It uses AppConfig keys for LDAP bind credentials and returns candidates for manual selection.
        </p>

        <div class="card shadow-sm mb-3">
            <div class="card-body">
                <div class="row g-3 align-items-end">
                    <div class="col-lg-4">
                        <label class="form-label">Lookup Type</label>
                        <select class="form-select" id="lookupUserType">
                            <option>Make a Selection</option>
                            <option value="faculty">Faculty</option>
                            <option value="staff">Staff</option>
                            <option value="current-student">Current Student</option>
                        </select>
                    </div>
                    <div class="col-lg-5">
                        <label class="form-label">Search Input</label>
                        <input
                            class="form-control"
                            id="lookupSearchTerm"
                            placeholder="Display Name, sAMAccountName, or email"
                            value=""
                        >
                    </div>
                    <div class="col-lg-3 d-grid">
                        <button class="btn btn-primary" type="button" id="runLookupBtn">
                            Search Cougarnet
                        </button>
                    </div>
                </div>

                <div class="row g-3 mt-1">
                    <div class="col-lg-6">
                        <label class="form-label">Selected Cougarnet ID (sAMAccountName)</label>
                        <input class="form-control" id="selectedSamAccountName" placeholder="No selection yet">
                    </div>
                    <div class="col-lg-6">
                        <label class="form-label">Status</label>
                        <div class="form-control bg-light" id="lookupStatus" style="min-height:38px;">Ready.</div>
                    </div>
                </div>
            </div>
        </div>

        <div class="alert alert-info mb-0">
            Required AppConfig keys: <code>ldap.cougarnet.bind_username</code>, <code>ldap.cougarnet.bind_password</code>.
            Optional: <code>ldap.cougarnet.server</code>, <code>ldap.cougarnet.start_dn</code>,
            <code>ldap.cougarnet.groups.faculty</code>, <code>ldap.cougarnet.groups.staff</code>,
            <code>ldap.cougarnet.groups.current_student</code>.
        </div>
    </div>

    <div class="modal fade" id="ldapResultsModal" tabindex="-1" aria-labelledby="ldapResultsModalLabel" aria-hidden="true">
        <div class="modal-dialog modal-xl modal-dialog-scrollable">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="ldapResultsModalLabel">LDAP Search Results</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body p-0">
                    <div class="table-responsive">
                        <table class="table table-sm table-hover mb-0 align-middle">
                            <thead class="table-light">
                                <tr>
                                    <th>Name</th>
                                    <th>sAMAccountName</th>
                                    <th>Email</th>
                                    <th>Department</th>
                                    <th>Title</th>
                                    <th class="text-end">Action</th>
                                </tr>
                            </thead>
                            <tbody id="ldapResultsBody">
                                <tr>
                                    <td colspan="6" class="text-muted p-3">No results yet.</td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </div>
    </cfoutput>

    <script>
    (function () {
        var runBtn = document.getElementById('runLookupBtn');
        var statusEl = document.getElementById('lookupStatus');
        var termEl = document.getElementById('lookupSearchTerm');
        var typeEl = document.getElementById('lookupUserType');
        var selectedEl = document.getElementById('selectedSamAccountName');
        var resultsBody = document.getElementById('ldapResultsBody');
        var modalEl = document.getElementById('ldapResultsModal');
        function getResultsModal() {
            if (!modalEl) return null;
            return bootstrap.Modal.getOrCreateInstance(modalEl);
        }

        function esc(str) {
            return String(str || '')
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;')
                .replace(/"/g, '&quot;')
                .replace(/'/g, '&#39;');
        }

        function setStatus(message, isError) {
            statusEl.textContent = message;
            statusEl.classList.toggle('text-danger', !!isError);
            statusEl.classList.toggle('text-success', !isError);
        }

        function renderRows(rows) {
            if (!rows || !rows.length) {
                resultsBody.innerHTML = '<tr><td colspan="6" class="text-muted p-3">No matches found.</td></tr>';
                return;
            }

            resultsBody.innerHTML = rows.map(function (row, idx) {
                return '' +
                    '<tr>' +
                        '<td>' + esc(row.displayName) + '</td>' +
                        '<td><code>' + esc(row.samAccountName) + '</code></td>' +
                        '<td>' + esc(row.mail) + '</td>' +
                        '<td>' + esc(row.department) + '</td>' +
                        '<td>' + esc(row.title) + '</td>' +
                        '<td class="text-end">' +
                            '<button class="btn btn-sm btn-outline-primary js-select-row" type="button" data-idx="' + idx + '">Use ID</button>' +
                        '</td>' +
                    '</tr>';
            }).join('');
        }

        function normalizeLdapRow(row) {
            row = row || {};
            return {
                displayName: row.displayName || row.DISPLAYNAME || '',
                samAccountName: row.samAccountName || row.SAMACCOUNTNAME || '',
                mail: row.mail || row.MAIL || '',
                department: row.department || row.DEPARTMENT || '',
                title: row.title || row.TITLE || ''
            };
        }

        var latestRows = [];

        resultsBody.addEventListener('click', function (event) {
            var btn = event.target.closest('.js-select-row');
            if (!btn) {
                return;
            }

            var idx = parseInt(btn.getAttribute('data-idx'), 10);
            var row = latestRows[idx] || null;
            if (!row || !row.samAccountName) {
                return;
            }

            selectedEl.value = row.samAccountName;
            setStatus('Selected ' + row.samAccountName + '.', false);
            if (modalEl) {
                getResultsModal().hide();
            }
        });

        runBtn.addEventListener('click', function () {
            var term = (termEl.value || '').trim();
            var userType = (typeEl.value || '').trim();

            if (term.length < 2) {
                setStatus('Enter at least 2 characters to search.', true);
                return;
            }

            runBtn.disabled = true;
            setStatus('Searching...', false);

            var body = new URLSearchParams();
            body.append('searchTerm', term);
            body.append('userType', userType);
            body.append('maxRows', '25');

            fetch('/admin/users/ldap_lookup.cfm', {
                method: 'POST',
                body: body,
                credentials: 'same-origin'
            })
            .then(function (r) { return r.json(); })
            .then(function (payload) {
                var ok = payload && (payload.success === true || payload.SUCCESS === true);
                var message = payload ? (payload.message || payload.MESSAGE) : '';
                var rows = payload ? (payload.data || payload.DATA || []) : [];

                if (!ok) {
                    setStatus(message || 'Lookup failed.', true);
                    latestRows = [];
                    renderRows(latestRows);
                    if (modalEl) {
                        getResultsModal().show();
                    }
                    return;
                }

                latestRows = rows.map(normalizeLdapRow);
                renderRows(latestRows);

                var count = latestRows.length;
                setStatus(count + ' match(es) found.', false);

                if (modalEl) {
                    getResultsModal().show();
                }
            })
            .catch(function (err) {
                setStatus('Network error: ' + err.message, true);
            })
            .finally(function () {
                runBtn.disabled = false;
            });
        });
    })();
    </script>
    </cfsavecontent>

    <cfinclude template="/admin/layout.cfm">