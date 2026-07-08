<cfsetting showdebugoutput="true">

<!--- ── Access guard: actual SUPER_ADMIN only (impersonation not allowed) ── --->
<cfif NOT request.isSuperAdmin()>
    <cflocation url="#request.webRoot#/admin/dashboard.cfm" addtoken="false">
    <cfabort>
</cfif>

<!--- ── Load active sessions ── --->
<cfset activeSessions = []>
<cfset sessionsDbOk = true>
<cftry>
    <cfset activeSessions = application.adminSessionsDAO.getActiveSessions()>
<cfcatch>
    <cfset sessionsDbOk = false>
</cfcatch>
</cftry>

<!--- ── Load recent auth events ── --->
<cfset recentEvents = []>
<cfset obsDbOk = true>
<cftry>
    <cfset recentEvents = application.authAuditService.getRecentEvents(100)>
<cfcatch>
    <cfset obsDbOk = false>
</cfcatch>
</cftry>

<cfset pageTitle = "Auth Observability">

<!--- ── Badge class by event type — must mirror the JS badgeMap below ── --->
<cfset badgeMap = {
    "LOGIN"                   = "bg-secondary text-dark",
    "UR_LOGIN"                = "bg-secondary text-dark",
    "LOGOUT"                  = "bg-secondary text-dark",
    "UR_LOGOUT"               = "bg-secondary text-dark",
    "LOGIN_FAILED"            = "bg-danger text-white",
    "UR_LOGIN_FAILED"         = "bg-danger text-white",
    "TRUSTED_LAUNCH"          = "bg-secondary text-dark",
    "UR_EXTERNAL_AUTH"        = "bg-primary text-white",
    "UR_EXTERNAL_AUTH_FAILED" = "bg-primary text-white",
    "IMPERSONATE_START"       = "bg-secondary text-dark",
    "IMPERSONATE_END"         = "bg-secondary text-dark",
    "FORCE_LOGOUT"            = "bg-secondary text-dark"
}>

<!--- ── Build active sessions rows HTML ── --->
<cfset sessionRowsHtml = "">
<cfset myUserID = val(session.user.adminUserID ?: 0)>
<cfif NOT sessionsDbOk>
    <cfset sessionRowsHtml = "<tr><td colspan='6' class='text-center text-danger py-3'>Unable to load sessions — database error.</td></tr>">
<cfelseif NOT arrayLen(activeSessions)>
    <cfset sessionRowsHtml = "<tr><td colspan='6' class='text-center text-muted py-3'>No active admin sessions.</td></tr>">
<cfelse>
    <cfloop array="#activeSessions#" index="ses">
        <cfset sesUID      = val(ses.ADMINUSERID ?: 0)>
        <cfset sesUser     = encodeForHTML(trim(ses.USERNAME    ?: ""))>
        <cfset sesName     = encodeForHTML(trim(ses.DISPLAYNAME ?: ""))>
        <cfset sesIP       = encodeForHTML(trim(ses.IPADDRESS   ?: ""))>
        <cfset sesPath     = encodeForHTML(trim(ses.LASTVISITEDPATH ?: ""))>
        <cfset sesLogin    = isDate(ses.LOGINTIME ?: "") ? dateTimeFormat(ses.LOGINTIME, "mmm d HH:nn:ss") : encodeForHTML(ses.LOGINTIME ?: "")>
        <cfset sesActivity = isDate(ses.LASTACTIVITY ?: "") ? dateTimeFormat(ses.LASTACTIVITY, "mmm d HH:nn:ss") : "—">
        <cfset isSelf      = (sesUID EQ myUserID)>

        <cfset sessionRowsHtml &= "<tr data-userid='#sesUID#'#(isSelf ? " class='table-info'" : "")#>">
        <cfset sessionRowsHtml &= "<td class='fw-semibold'>#sesUser##(isSelf ? " <span class='badge bg-info text-dark ms-1'>you</span>" : "")#<div class='small text-muted'>#sesName#</div></td>">
        <cfset sessionRowsHtml &= "<td class='small text-muted'>#sesIP#</td>">
        <cfset sessionRowsHtml &= "<td class='small text-nowrap text-muted'>#sesLogin#</td>">
        <cfset sessionRowsHtml &= "<td class='small text-nowrap text-muted'>#sesActivity#</td>">
        <cfset sessionRowsHtml &= "<td class='small text-muted obs-path-cell'>#(len(sesPath) ? sesPath : "<span class='text-muted fst-italic'>—</span>")#</td>">
        <cfif isSelf>
            <cfset sessionRowsHtml &= "<td></td>">
        <cfelse>
            <cfset sessionRowsHtml &= "<td class='text-end'><button class='btn btn-sm btn-ui-warning force-logout-btn' data-userid='#sesUID#' data-username='#encodeForHTMLAttribute(sesUser)#'><i class='bi bi-box-arrow-right me-1'></i>Force Logout</button></td>">
        </cfif>
        <cfset sessionRowsHtml &= "</tr>">
    </cfloop>
</cfif>

<!--- ── Build event rows HTML ── --->
<cfset eventRowsHtml = "">
<cfif NOT obsDbOk>
    <cfset eventRowsHtml = "<tr><td colspan='6' class='text-center text-danger py-4'>Unable to load auth events — database error.</td></tr>">
<cfelseif NOT arrayLen(recentEvents)>
    <cfset eventRowsHtml = "<tr id='noEventsRow'><td colspan='6' class='text-center text-muted py-4'>No auth events recorded yet.</td></tr>">
<cfelse>
    <cfloop array="#recentEvents#" index="ev">
        <cfset evType    = encodeForHTML(trim(ev.EVENTTYPE  ?: ""))>
        <cfset evSource  = encodeForHTML(trim(ev.SOURCE     ?: ""))>
        <cfset evUser    = encodeForHTML(trim(ev.USERNAME   ?: ""))>
        <cfset evIP      = encodeForHTML(trim(ev.IPADDRESS  ?: ""))>
        <cfset evDetails = encodeForHTML(trim(ev.DETAILS    ?: ""))>
        <cfset evAt      = isDate(ev.EVENTAT ?: "") ? dateTimeFormat(ev.EVENTAT, "mmm d HH:nn:ss") : encodeForHTML(ev.EVENTAT ?: "")>
        <cfset evBadge   = structKeyExists(badgeMap, uCase(trim(ev.EVENTTYPE ?: ""))) ? badgeMap[uCase(trim(ev.EVENTTYPE ?: ""))] : "bg-secondary">
        <cfset eventRowsHtml &= "<tr data-source='#encodeForHTMLAttribute(evSource)#' data-etype='#encodeForHTMLAttribute(uCase(trim(ev.EVENTTYPE ?: "")))#'>">
        <cfset eventRowsHtml &= "<td><span class='badge #evBadge# obs-badge'>#evType#</span></td>">
        <cfset eventRowsHtml &= "<td><span class='badge bg-light text-dark border'>#evSource#</span></td>">
        <cfset eventRowsHtml &= "<td class='fw-semibold'>#evUser#</td>">
        <cfset eventRowsHtml &= "<td class='small text-muted'>#evIP#</td>">
        <cfset eventRowsHtml &= "<td class='small text-muted text-truncate obs-details-cell'>#len(evDetails) ? evDetails : '<span class=''text-muted fst-italic''>—</span>'#</td>">
        <cfset eventRowsHtml &= "<td class='small text-nowrap text-muted'>#evAt#</td>">
        <cfset eventRowsHtml &= "</tr>">
    </cfloop>
</cfif>


<cfsavecontent variable="content">
<cfoutput>

<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item active">Auth Observability</li>
    </ol>
</nav>

<div class="obs-shell">

    <!--- ── Page header ── --->
    <div class="d-flex align-items-center justify-content-between mb-3 flex-wrap gap-2">
        <div>
            <h4 class="mb-0 fw-bold"><i class="bi bi-shield-lock-fill me-2 text-primary"></i>Auth Observability</h4>
            <small class="text-muted">Real-time authentication event log - admin and UserReview contexts</small>
        </div>
        <div class="d-flex align-items-center gap-2">

            <span class="badge bg-light text-dark border" id="evCount">#arrayLen(recentEvents)# event(s)</span>
        </div>
    </div>

    <!--- ── Active Sessions panel ── --->
    <div class="card shadow-sm mb-4">
        <div class="card-header py-2 d-flex align-items-center justify-content-between">
            <span class="fw-semibold small"><i class="bi bi-people-fill me-1 text-success"></i>Active Admin Sessions
                <span class="badge bg-success ms-1" id="activeCount">#arrayLen(activeSessions)#</span>
            </span>
            <button class="btn btn-sm btn-ui-go" onclick="location.reload()" title="Refresh"><i class="bi bi-arrow-clockwise"></i></button>
        </div>
        <div class="table-responsive">
            <table class="table table-sm table-hover mb-0 align-middle" id="sessionTable">
                <thead class="table-light">
                    <tr>
                        <th>Username</th>
                        <th style="width:130px">IP Address</th>
                        <th style="width:145px">Login (UTC)</th>
                        <th style="width:145px">Last Activity</th>
                        <th>Last Page</th>
                        <th style="width:130px"></th>
                    </tr>
                </thead>
                <tbody id="sessionTbody">
                    #sessionRowsHtml#
                </tbody>
            </table>
        </div>
        <cfif NOT sessionsDbOk>
            <div class="card-footer py-1 small text-danger"><i class="bi bi-exclamation-triangle-fill me-1"></i>Database error loading sessions.</div>
        </cfif>
    </div>

    <!--- ── Force-logout confirm modal ── --->
    <div class="modal fade" id="forceLogoutModal" tabindex="-1" aria-labelledby="forceLogoutModalLabel" aria-hidden="true">
        <div class="modal-dialog modal-sm">
            <div class="modal-content">
                <div class="modal-header py-2">
                    <h6 class="modal-title" id="forceLogoutModalLabel"><i class="bi bi-box-arrow-right me-1 text-danger"></i>Force Logout</h6>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body py-2 small">
                    Force-logout <strong id="forceLogoutUsername"></strong>? They will be redirected to login on their next request.
                </div>
                <div class="modal-footer py-2">
                    <button type="button" class="btn btn-sm btn-ui-cancel" data-bs-dismiss="modal">Cancel</button>
                    <button type="button" class="btn btn-sm btn-ui-warning" id="forceLogoutConfirmBtn">Force Logout</button>
                </div>
            </div>
        </div>
    </div>

    <!--- ── Event feed filter bar ── --->
    <div class="mb-3 d-flex flex-wrap gap-2 align-items-center">
        <span class="small text-muted fw-semibold me-1">Filter:</span>
        <span class="badge bg-secondary text-dark obs-filter obs-filter-badge active" data-filter="all"         role="button" tabindex="0">All</span>
        <span class="badge bg-secondary text-dark obs-filter obs-filter-badge"       data-filter="LOGIN"       role="button" tabindex="0">Login</span>
        <span class="badge bg-secondary text-dark obs-filter obs-filter-badge"       data-filter="LOGOUT"      role="button" tabindex="0">Logout</span>
        <span class="badge bg-danger text-white obs-filter obs-filter-badge"         data-filter="FAILED"      role="button" tabindex="0">Failed</span>
        <span class="badge bg-secondary text-dark obs-filter obs-filter-badge"       data-filter="TRUSTED"     role="button" tabindex="0">Trusted</span>
        <span class="badge bg-secondary text-dark obs-filter obs-filter-badge"       data-filter="IMPERSONATE" role="button" tabindex="0">Impersonate</span>
        <span class="badge bg-secondary text-dark obs-filter obs-filter-badge ms-3"  data-source="admin"       role="button" tabindex="0">Admin</span>
        <span class="badge bg-secondary text-dark obs-filter obs-filter-badge"       data-source="userreview"  role="button" tabindex="0">UserReview</span>
    </div>

    <!--- ── Recent Events table ── --->
    <div class="card shadow-sm">
        <div class="card-header py-2 d-flex align-items-center justify-content-between">
            <span class="fw-semibold small"><i class="bi bi-list-ul me-1"></i>Recent Events (last 100)</span>
            <button class="btn btn-sm btn-ui-go" onclick="location.reload()"><i class="bi bi-arrow-clockwise"></i></button>
        </div>
        <div class="table-responsive">
            <table class="table table-sm table-hover mb-0 align-middle obs-event-table" id="eventTable">
                <thead class="table-light">
                    <tr>
                        <th style="width:160px">Event</th>
                        <th style="width:100px">Source</th>
                        <th>Username</th>
                        <th style="width:130px">IP Address</th>
                        <th>Details</th>
                        <th style="width:130px">Time (UTC)</th>
                    </tr>
                </thead>
                <tbody id="eventTbody">
                    #eventRowsHtml#
                </tbody>
            </table>
        </div>
    </div>

    <div class="mt-2 small text-muted">
        Events loaded at page load. Use the refresh button to update.
        <cfif NOT obsDbOk><span class="text-danger ms-2"><i class="bi bi-exclamation-triangle-fill me-1"></i>Database connection error on load.</span></cfif>
    </div>

</div><!--- /.obs-shell --->

<style>
.obs-shell { max-width: 1200px; }
.obs-badge { font-size: .75rem; }
.obs-details-cell { max-width: 260px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.obs-path-cell    { max-width: 300px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.obs-event-table tbody tr { transition: background .15s; }
.obs-event-table tbody tr.obs-hidden { display: none; }
.obs-filter-badge { cursor: pointer; user-select: none; transition: opacity .15s; font-size: .78rem; }
.obs-filter-badge:hover { opacity: .65; }
.obs-filter-badge.active { opacity: 1; }
</style>

<script nonce="#encodeForHTMLAttribute(request.cspNonce ?: '')#">
(function () {
    var CSRF_TOKEN = (document.querySelector('meta[name="csrf-token"]') || {}).content || '';
    var WEBROOT    = (document.querySelector('meta[name="uhco-webroot"]') || {}).content || '';
    var MY_USER_ID = #val(session.user.adminUserID ?: 0)#;

    // -- Active sessions — force-logout updates --------------------------------
    function removeSessionRow(userID) {
        if (!userID) return;
        var tbody = document.getElementById('sessionTbody');
        if (!tbody) return;
        var row = tbody.querySelector('tr[data-userid="' + userID + '"]');
        if (row) {
            row.remove();
            updateActiveCount(0);
        }
    }

    function updateActiveCount(delta) {
        var el = document.getElementById('activeCount');
        if (!el) return;
        var current = parseInt(el.textContent || '0', 10);
        el.textContent = Math.max(0, current + delta);
    }

    // -- Force logout --------------------------------
    var pendingForceLogoutID = 0;

    document.addEventListener('click', function (e) {
        var btn = e.target.closest('.force-logout-btn');
        if (!btn) return;
        pendingForceLogoutID = parseInt(btn.getAttribute('data-userid') || '0', 10);
        var uname = btn.getAttribute('data-username') || pendingForceLogoutID;
        var labelEl = document.getElementById('forceLogoutUsername');
        if (labelEl) labelEl.textContent = uname;
        var modal = bootstrap.Modal.getOrCreate(document.getElementById('forceLogoutModal'));
        modal.show();
    });

    document.getElementById('forceLogoutConfirmBtn').addEventListener('click', function () {
        if (!pendingForceLogoutID) return;
        var btn = this;
        btn.disabled = true;
        btn.textContent = 'Working…';

        fetch(WEBROOT + '/admin/settings/observability/force-logout.cfm', {
            method:  'POST',
            headers: {
                'Content-Type':  'application/x-www-form-urlencoded',
                'X-CSRF-Token':  CSRF_TOKEN
            },
            body: 'targetUserID=' + encodeURIComponent(pendingForceLogoutID)
        })
        .then(function (r) { return r.json(); })
        .then(function (data) {
            bootstrap.Modal.getInstance(document.getElementById('forceLogoutModal')).hide();
            if (data.success) {
                removeSessionRow(pendingForceLogoutID);
            } else {
                alert('Force logout failed: ' + (data.error || 'Unknown error'));
            }
        })
        .catch(function () {
            alert('Request failed. Check the console for details.');
        })
        .finally(function () {
            btn.disabled = false;
            btn.textContent = 'Force Logout';
            pendingForceLogoutID = 0;
        });
    });

    // -- Event feed filter --------------------------------
    var currentFilter = 'all';
    var currentSource = 'all';

    document.querySelectorAll('.obs-filter').forEach(function (btn) {
        btn.addEventListener('click', function () {
            var filter = this.getAttribute('data-filter');
            var source = this.getAttribute('data-source');
            if (filter) {
                document.querySelectorAll('.obs-filter[data-filter]').forEach(function (b) { b.classList.remove('active'); });
                this.classList.add('active');
                currentFilter = filter;
            }
            if (source) {
                if (currentSource === source) {
                    currentSource = 'all';
                    this.classList.remove('active');
                } else {
                    document.querySelectorAll('.obs-filter[data-source]').forEach(function (b) { b.classList.remove('active'); });
                    currentSource = source;
                    this.classList.add('active');
                }
            }
            applyFilterToAll();
        });
    });

    function applyCurrentFilter(tr) {
        var type = (tr.getAttribute('data-etype')  || '').toUpperCase();
        var src  = (tr.getAttribute('data-source') || '').toLowerCase();
        tr.classList.toggle('obs-hidden', !matchesFilter(type, src));
    }

    function applyFilterToAll() {
        var tbody = document.getElementById('eventTbody');
        if (!tbody) return;
        tbody.querySelectorAll('tr').forEach(applyCurrentFilter);
        var countEl = document.getElementById('evCount');
        if (countEl) countEl.textContent = tbody.querySelectorAll('tr:not(.obs-hidden)').length + ' event(s)';
    }

    function matchesFilter(type, src) {
        if (currentSource !== 'all' && src !== currentSource) return false;
        if (currentFilter === 'all')         return true;
        if (currentFilter === 'LOGIN')       return type === 'LOGIN'       || type === 'UR_LOGIN';
        if (currentFilter === 'LOGOUT')      return type === 'LOGOUT'      || type === 'UR_LOGOUT'    || type === 'FORCE_LOGOUT';
        if (currentFilter === 'FAILED')      return type.indexOf('FAILED') >= 0;
        if (currentFilter === 'TRUSTED')     return type === 'TRUSTED_LAUNCH' || type === 'UR_EXTERNAL_AUTH';
        if (currentFilter === 'IMPERSONATE') return type.indexOf('IMPERSONATE') >= 0;
        return false;
    }
}());
</script>
</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
