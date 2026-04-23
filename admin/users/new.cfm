<cfif NOT request.hasPermission("users.edit")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset flagsService = createObject("component", "cfc.flags_service").init()>
<cfset allFlagsResult = flagsService.getAllFlags()>
<cfset allFlags = allFlagsResult.data />

<cfset externalIDService = createObject("component", "cfc.externalID_service").init()>
<cfset allSystemsResult = externalIDService.getSystems()>
<cfset allSystems = allSystemsResult.data>

<!--- Build ordered quick-add flags list from configured UserFlags. --->
<cfset quickFlagDefs = [
    { key = "alumni", label = "Alumni" },
    { key = "current-student", label = "Current Student" },
    { key = "faculty-fulltime", label = "Faculty-Fulltime" },
    { key = "faculty-adjunct", label = "Faculty-Adjunct" },
    { key = "joint faculty appointment", label = "Joint Faculty Appointment" },
    { key = "resident", label = "Resident" },
    { key = "staff", label = "Staff" }
]>
<cfset quickFlags = []>

<cfloop array="#quickFlagDefs#" index="flagDef">
    <cfset matchedFlag = {}>
    <cfloop from="1" to="#arrayLen(allFlags)#" index="i">
        <cfset row = allFlags[i]>
        <cfif lCase(trim(row.FLAGNAME ?: "")) EQ flagDef.key>
            <cfset matchedFlag = {
                FLAGID = row.FLAGID,
                FLAGNAME = flagDef.label
            }>
            <cfbreak>
        </cfif>
    </cfloop>
    <cfif NOT structIsEmpty(matchedFlag)>
        <cfset arrayAppend(quickFlags, matchedFlag)>
    </cfif>
</cfloop>

<!--- Locate ExternalSystems IDs for CougarNet + PeopleSoft fields. --->
<cfset cougarNetSystemID = 0>
<cfset peopleSoftSystemID = 0>
<cfloop from="1" to="#arrayLen(allSystems)#" index="i">
    <cfset sys = allSystems[i]>
    <cfset scanText = lCase(trim((sys.SYSTEMNAME ?: "") & " " & (sys.SYSTEMCODE ?: "")))>
    <cfif cougarNetSystemID EQ 0 AND findNoCase("cougarnet", scanText)>
        <cfset cougarNetSystemID = val(sys.SYSTEMID)>
    </cfif>
    <cfif peopleSoftSystemID EQ 0 AND findNoCase("peoplesoft", scanText)>
        <cfset peopleSoftSystemID = val(sys.SYSTEMID)>
    </cfif>
</cfloop>

<cfset cougarNetDisabledAttr = (cougarNetSystemID GT 0 ? "" : "disabled")>
<cfset peopleSoftDisabledAttr = (peopleSoftSystemID GT 0 ? "" : "disabled")>
<cfset cougarNetMissingHtml = (cougarNetSystemID GT 0 ? "" : "<div class='form-text text-warning'>CougarNet system not configured.</div>")>
<cfset peopleSoftMissingHtml = (peopleSoftSystemID GT 0 ? "" : "<div class='form-text text-warning'>PeopleSoft system not configured.</div>")>

<cfset content = "
<h1>Quick Add User</h1>

<form class='mt-4' method='POST' action='/admin/users/saveUser.cfm'>
    <input type='hidden' name='processExternalIDs' value='1'>
    <input type='hidden' name='returnTo' value='/admin/users/index.cfm'>

    <div class='row mb-3'>
        <div class='col-md-4'>
            <label class='form-label'>First Name</label>
            <input class='form-control' name='FirstName' required>
        </div>
        <div class='col-md-4'>
            <label class='form-label'>Middle Name</label>
            <input class='form-control' name='MiddleName'>
        </div>
        <div class='col-md-4'>
            <label class='form-label'>Last Name</label>
            <input class='form-control' name='LastName' required>
        </div>
    </div>

    <div class='row mb-3'>
        <div class='col-md-6'>
            <label class='form-label'>@UH Email</label>
            <input class='form-control' id='emailPrimary' name='EmailPrimary' type='email' required>
            <div class='invalid-feedback' id='emailPrimaryErr'></div>
        </div>
    </div>

    <div class='mb-3'>
        <label class='form-label'>Flags</label>
        <div class='border p-3 rounded admin-scroll-panel-xs'>
">

<cfif arrayLen(quickFlags) GT 0>
    <cfloop from="1" to="#arrayLen(quickFlags)#" index="i">
        <cfset qf = quickFlags[i]>
        <cfset content &= "
            <div class='form-check'>
                <input class='form-check-input' type='checkbox' name='Flags' value='#qf.FLAGID#' id='flag#qf.FLAGID#' data-flagname='#lCase(qf.FLAGNAME)#'>
                <label class='form-check-label' for='flag#qf.FLAGID#'>
                    #EncodeForHTML(qf.FLAGNAME)#
                </label>
            </div>
        ">
    </cfloop>
<cfelse>
    <cfset content &= "<p class='text-muted mb-0'>No matching quick-add flags were found in UserFlags.</p>">
</cfif>

<cfset content &= "
        </div>
    </div>

    <div class='row mb-3'>
        <div class='col-md-6'>
            <label class='form-label'>COUGARNET ID</label>
            <div class='input-group'>
                <input class='form-control' id='newUserCougarnetID' name='extID_#cougarNetSystemID#' #cougarNetDisabledAttr#>
                <button class='btn btn-outline-secondary' type='button' id='newUserCougarnetLookupBtn' #cougarNetDisabledAttr#>Lookup</button>
            </div>
            #cougarNetMissingHtml#
        </div>
        <div class='col-md-6'>
            <label class='form-label'>PEOPLESOFT ID</label>
            <div class='input-group'>
                <input class='form-control' id='newUserPeopleSoftID' name='extID_#peopleSoftSystemID#' #peopleSoftDisabledAttr#>
                <button class='btn btn-outline-secondary' type='button' id='newUserPeopleSoftLookupBtn' #peopleSoftDisabledAttr#>Lookup</button>
            </div>
            #peopleSoftMissingHtml#
        </div>
    </div>

    <div id='newUserCougarnetLookupStatus' class='small text-muted mb-3'></div>

    <div class='modal fade' id='newUserCougarnetLookupModal' tabindex='-1' aria-labelledby='newUserCougarnetLookupModalLabel' aria-hidden='true'>
        <div class='modal-dialog modal-lg modal-dialog-scrollable'>
            <div class='modal-content'>
                <div class='modal-header'>
                    <h5 class='modal-title' id='newUserCougarnetLookupModalLabel'>Select CougarNet Account</h5>
                    <button type='button' class='btn-close' data-bs-dismiss='modal' aria-label='Close'></button>
                </div>
                <div class='modal-body p-0'>
                    <div class='table-responsive'>
                        <table class='table table-sm table-hover mb-0 align-middle'>
                            <thead class='table-light'>
                                <tr>
                                    <th>Name</th>
                                    <th>COUGARNET</th>
                                    <th>PEOPLESOFT</th>
                                    <th>Email</th>
                                    <th class='text-end'>Action</th>
                                </tr>
                            </thead>
                            <tbody id='newUserCougarnetLookupResultsBody'>
                                <tr>
                                    <td colspan='7' class='text-muted p-3'>No results loaded.</td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script>
    (function () {
        var epEl  = document.getElementById('emailPrimary');
        var epErr = document.getElementById('emailPrimaryErr');
        var cougarnetLookupBtn = document.getElementById('newUserCougarnetLookupBtn');
        var peopleSoftLookupBtn = document.getElementById('newUserPeopleSoftLookupBtn');
        var cougarnetInputEl = document.getElementById('newUserCougarnetID');
        var peopleSoftInputEl = document.getElementById('newUserPeopleSoftID');
        var cougarnetStatusEl = document.getElementById('newUserCougarnetLookupStatus');
        var cougarnetResultsBodyEl = document.getElementById('newUserCougarnetLookupResultsBody');
        var cougarnetModalEl = document.getElementById('newUserCougarnetLookupModal');
        var cougarnetModal = cougarnetModalEl ? new bootstrap.Modal(cougarnetModalEl) : null;
        var cougarnetRows = [];

        function escHtml(str) {
            return String(str || '')
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;')
                .replace(/\"/g, '&quot;')
                .replace(/'/g, '&#39;');
        }

        function setLookupStatus(text, isError) {
            if (!cougarnetStatusEl) {
                return;
            }
            cougarnetStatusEl.textContent = text || '';
            cougarnetStatusEl.classList.toggle('text-danger', !!isError);
            cougarnetStatusEl.classList.toggle('text-muted', !isError);
        }

        function inferUserTypeFromFlags() {
            var checked = Array.prototype.slice.call(document.querySelectorAll('input[name="Flags"]:checked'));
            var names = checked.map(function (cb) { return (cb.getAttribute('data-flagname') || '').toLowerCase(); });

            if (names.some(function (name) { return name === 'current student' || name === 'current-student'; })) {
                return 'current-student';
            }
            if (names.some(function (name) { return name === 'staff'; })) {
                return 'staff';
            }
            if (names.some(function (name) {
                return name === 'faculty-fulltime' || name === 'faculty-adjunct' || name === 'joint faculty appointment' || name === 'faculty';
            })) {
                return 'faculty';
            }
            return '';
        }

        function renderLookupRows(rows) {
            if (!cougarnetResultsBodyEl) {
                return;
            }
            if (!rows || !rows.length) {
                cougarnetResultsBodyEl.innerHTML = '<tr><td colspan="5" class="text-muted p-3">No matches found.</td></tr>';
                return;
            }

            cougarnetResultsBodyEl.innerHTML = rows.map(function (row, idx) {
                return '' +
                    '<tr>' +
                        '<td>' + escHtml(row.displayName) + '</td>' +
                        '<td><code>' + escHtml(row.samAccountName) + '</code></td>' +
                        '<td>' + escHtml(row.employeeID) + '</td>' +
                        '<td>' + escHtml(row.mail) + '</td>' +
                        '<td class="text-end"><button type="button" class="btn btn-sm btn-outline-primary js-newuser-ldap-select" data-idx="' + idx + '">Use</button></td>' +
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

        function showError(el, errEl, msg) { el.classList.add('is-invalid'); errEl.textContent = msg; }
        function clearError(el, errEl) { el.classList.remove('is-invalid'); errEl.textContent = ''; }
        function validatePrimary() {
            var val = (epEl ? epEl.value : '').trim().toLowerCase();
            if (val && !val.endsWith('@uh.edu')) {
                showError(epEl, epErr, 'Must be a @uh.edu address (e.g. jsmith@uh.edu).');
                return false;
            }
            if (epEl) clearError(epEl, epErr);
            return true;
        }
        if (epEl) epEl.addEventListener('blur', validatePrimary);

        document.addEventListener('click', function (event) {
            var pickBtn = event.target.closest('.js-newuser-ldap-select');
            if (!pickBtn) {
                return;
            }
            var idx = parseInt(pickBtn.getAttribute('data-idx'), 10);
            var row = cougarnetRows[idx] || null;
            if (row) {
                if (cougarnetInputEl) {
                    cougarnetInputEl.value = row.samAccountName || '';
                }
                if (peopleSoftInputEl) {
                    peopleSoftInputEl.value = row.employeeID || '';
                }
                setLookupStatus('Selected ' + (row.samAccountName || '') + '.', false);
            }
            if (cougarnetModal) {
                cougarnetModal.hide();
            }
        });

        function runLookup(seedSourceInputEl, triggerBtn) {
            if (!triggerBtn) {
                return;
            }
                var userType = inferUserTypeFromFlags();
                var firstNameEl = document.querySelector('[name="FirstName"]');
                var middleNameEl = document.querySelector('[name="MiddleName"]');
                var lastNameEl = document.querySelector('[name="LastName"]');
                var seedTerm = '';

                if (seedSourceInputEl && seedSourceInputEl.value.trim().length) {
                    seedTerm = seedSourceInputEl.value.trim();
                } else {
                    var firstName = (firstNameEl ? firstNameEl.value : '').trim();
                    var middleName = (middleNameEl ? middleNameEl.value : '').trim();
                    var lastName = (lastNameEl ? lastNameEl.value : '').trim();
                    var middleInitial = middleName.length ? (' ' + middleName.charAt(0)) : '';
                    var formattedName = '';

                    if (firstName.length && lastName.length) {
                        formattedName = lastName + ', ' + firstName + middleInitial;
                    } else {
                        formattedName = (firstName + ' ' + lastName).trim();
                    }

                    if (formattedName.length) {
                        seedTerm = formattedName;
                    } else if (epEl && epEl.value.trim().length) {
                        seedTerm = epEl.value.trim();
                    }
                }

                if (!userType) {
                    setLookupStatus('Select at least one faculty/staff/current-student flag before lookup.', true);
                    return;
                }
                if (seedTerm.length < 2) {
                    setLookupStatus('Enter at least 2 characters in CougarNet ID, email, or name before lookup.', true);
                    return;
                }

                triggerBtn.disabled = true;
                setLookupStatus('Searching LDAP...', false);

                var body = new URLSearchParams();
                body.append('searchTerm', seedTerm);
                body.append('userType', userType);
                body.append('maxRows', '25');

                fetch('/admin/users/lookup_cougarnet.cfm', {
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
                        cougarnetRows = [];
                        renderLookupRows(cougarnetRows);
                        setLookupStatus(message || 'Lookup failed.', true);
                        if (cougarnetModal) { cougarnetModal.show(); }
                        return;
                    }

                    cougarnetRows = rows.map(normalizeLdapRow);
                    renderLookupRows(cougarnetRows);
                    setLookupStatus(cougarnetRows.length + ' match(es) found.', false);
                    if (cougarnetModal) { cougarnetModal.show(); }
                })
                .catch(function (err) {
                    setLookupStatus('Network error: ' + err.message, true);
                })
                .finally(function () {
                    triggerBtn.disabled = false;
                });
        }

        if (cougarnetLookupBtn) {
            cougarnetLookupBtn.addEventListener('click', function () {
                runLookup(cougarnetInputEl, cougarnetLookupBtn);
            });
        }

        if (peopleSoftLookupBtn) {
            peopleSoftLookupBtn.addEventListener('click', function () {
                runLookup(peopleSoftInputEl, peopleSoftLookupBtn);
            });
        }

        var form = epEl ? epEl.closest('form') : null;
        if (form) {
            form.addEventListener('submit', function (e) {
                if (!validatePrimary()) {
                    e.preventDefault();
                    var inv = document.querySelector('.is-invalid');
                    if (inv) inv.focus();
                }
            });
        }
    })();
    </script>

    <button class='btn btn-success'>Save User</button>
    <a href='/admin/users/index.cfm' class='btn btn-secondary'>Cancel</a>
</form>
" />

<cfinclude template="/admin/layout.cfm">
