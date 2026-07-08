<!---
    User Permissions — grant and revoke module access permissions for identity users.
    Permission: settings.user_permissions.manage.
--->

<cfif NOT request.hasPermission("settings.user_permissions.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfinclude template="/admin/settings/section-status-config.cfm">
<cfset sectionStatus = getSettingsSectionStatus("user-permissions")>

<cfset accessService = createObject("component", "cfc.access_service").init()>
<cfset usersService  = createObject("component", "cfc.users_service").init()>

<cfset allAreas = accessService.getAccessAreas().data>
<cfset msgParam = structKeyExists(url, "msg") ? url.msg : "">
<cfset errParam = structKeyExists(url, "err") ? url.err : "">

<!--- Selected user lookup --->
<cfset selectedUserID  = (structKeyExists(url, "userID") AND isNumeric(url.userID) AND val(url.userID) GT 0) ? int(val(url.userID)) : 0>
<cfset selectedUser    = {}>
<cfset userPermissions = []>
<cfset returnTo = structKeyExists(url, "returnTo") ? trim(url.returnTo) : "">

<cfif selectedUserID GT 0>
    <cfset selectedUser    = usersService.getUser(selectedUserID).data>
    <cfset userPermissions = accessService.getPermissionsForUser(selectedUserID).data>
</cfif>

<!--- Build user list for name autocomplete --->
<cfset allUsers = usersService.listUsers()>
<cfset userLookupArr = []>
<cfloop array="#allUsers#" index="u">
    <cfset arrayAppend(userLookupArr, {
        "id"    = val(u.USERID ?: 0),
        "first" = trim(u.FIRSTNAME ?: ""),
        "last"  = trim(u.LASTNAME ?: "")
    })>
</cfloop>
<cfset userLookupJSON = serializeJSON(userLookupArr)>
<!--- Double any # so cfoutput doesn't try to evaluate them as expressions --->
<cfset userLookupJSONSafe = replace(userLookupJSON, "##", "####", "all")>

<cfset prefilledName = (selectedUserID GT 0 AND NOT structIsEmpty(selectedUser))
    ? trim((selectedUser.FIRSTNAME ?: "") & " " & (selectedUser.LASTNAME ?: ""))
    : "">

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-user-permissions-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item active">External Access Permissions</li>
    </ol>
</nav>

<cfif len(returnTo)>
    <div class="mb-3">
        <a href="#encodeForHTML(returnTo)#" class="btn btn-ui-cancel btn-sm">
            <i class="bi bi-arrow-left me-1"></i>Back to User
        </a>
    </div>
</cfif>

<div class="d-flex justify-content-between align-items-center mb-4">
    <div>
        <h1 class="mb-1"><i class="bi bi-key-fill me-2"></i>External Access Permissions</h1>
        <p class="text-muted">Grant or revoke module access permissions for identity users.</p>
    </div>
    <cfif len(sectionStatus)>
        <div class="mb-3">
            <span class="badge bg-warning text-dark">Currently in: #sectionStatus#</span>
        </div>
    </cfif>
</div>



<div class="row g-4">

    <!--- ── User search ───────────────────────────────────────────────────── --->
    <div class="col-12 col-lg-4">
        <div class="card border-0 shadow-sm h-100">
            <div class="card-body">
                <h5 class="card-title mb-3"><i class="bi bi-search me-2"></i>Find User</h5>
                <form method="get" action="/admin/settings/user-permissions/" id="userLookupForm">
                    <div class="mb-3">
                        <label class="form-label" for="userNameInput">Name</label>
                        <div class="position-relative">
                            <input type="text"
                                   id="userNameInput"
                                   class="form-control"
                                   placeholder="Type a name to search…"
                                   autocomplete="off"
                                   spellcheck="false"
                                   value="#encodeForHTMLAttribute(prefilledName)#">
                            <div id="userSuggestList"
                                 class="list-group position-absolute w-100 shadow"
                                 style="display:none; z-index:1050; max-height:260px; overflow-y:auto; top:calc(100% + 2px); left:0;">
                            </div>
                        </div>
                        <input type="hidden" id="userIDHidden" name="userID"
                               value="#(selectedUserID GT 0 ? selectedUserID : '')#">
                        <div class="form-text text-muted" id="userSelectedHint"
                             style="#(selectedUserID GT 0 ? '' : 'display:none;')#">
                            <cfif selectedUserID GT 0>ID: #selectedUserID#</cfif>
                        </div>
                        <div class="invalid-feedback" id="userLookupError">
                            Select a user from the list.
                        </div>
                    </div>
                    <button type="submit" class="btn btn-ui-filter w-100">
                        <i class="bi bi-search me-1"></i>Look Up User
                    </button>
                </form>
            </div>
        </div>
    </div>

    <!--- ── User permissions panel ───────────────────────────────────────── --->
    <div class="col-12 col-lg-8">
        <cfif selectedUserID GT 0>
            <cfif structIsEmpty(selectedUser)>
                <div class="alert alert-warning">No user found with ID #encodeForHTML(selectedUserID)#.</div>
            <cfelse>
                <div class="card border-0 shadow-sm mb-3">
                    <div class="card-body">
                        <h5 class="card-title mb-1">
                            #encodeForHTML( !isNull(selectedUser.FIRSTNAME) ? selectedUser.FIRSTNAME : "" )#
                            #encodeForHTML( !isNull(selectedUser.LASTNAME) ? selectedUser.LASTNAME : "" )#
                            <small class="text-muted fw-normal ms-2">ID #encodeForHTML(selectedUserID)#</small>
                        </h5>
                        <p class="text-muted small mb-0">#encodeForHTML(selectedUser.EMAILPRIMARY ?: "")#</p>
                    </div>
                </div>

                <!--- Current permissions --->
                <div class="card border-0 shadow-sm mb-3">
                    <div class="card-header bg-transparent">
                        <strong>Current Permissions</strong>
                        <span class="badge bg-secondary ms-2">#arrayLen(userPermissions)#</span>
                    </div>
                    <cfif arrayLen(userPermissions)>
                        <div class="table-responsive">
                            <table class="table table-sm table-hover align-middle mb-0 settings-table">
                                <thead>
                                    <tr>
                                        <th>Permission</th>
                                        <th class="text-end">Actions</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <cfloop array="#userPermissions#" index="perm">
                                        <tr>
                                            <td><code>#encodeForHTML(perm)#</code></td>
                                            <td class="text-end">
                                                <form method="post" action="/admin/settings/user-permissions/save.cfm" class="d-inline">
                                                    <input type="hidden" name="action"     value="revoke">
                                                    <input type="hidden" name="userID"     value="#selectedUserID#">
                                                    <input type="hidden" name="permission" value="#encodeForHTMLAttribute(perm)#">
                                                    <cfif len(returnTo)><input type="hidden" name="returnTo" value="#encodeForHTMLAttribute(returnTo)#"></cfif>
                                                    <button type="submit" class="btn btn-sm btn-ui-delete users-list-action-button users-list-action-button-delete"
                                                            data-confirm="Revoke #encodeForJavaScript(perm)# from this user?"
                                                            title="Revoke permission">
                                                        <i class="bi bi-trash"></i>
                                                    </button>
                                                </form>
                                            </td>
                                        </tr>
                                    </cfloop>
                                </tbody>
                            </table>
                        </div>
                    <cfelse>
                        <div class="card-body text-muted small">No permissions assigned.</div>
                    </cfif>
                </div>

                <!--- Grant permission form --->
                <div class="card border-0 shadow-sm">
                    <div class="card-body">
                        <h6 class="card-title mb-3"><i class="bi bi-plus-circle me-1"></i>Grant Permission</h6>
                        <cfif arrayLen(allAreas)>
                            <form method="post" action="/admin/settings/user-permissions/save.cfm" class="row g-2">
                                <input type="hidden" name="action" value="grant">
                                <input type="hidden" name="userID" value="#selectedUserID#">
                                <cfif len(returnTo)><input type="hidden" name="returnTo" value="#encodeForHTMLAttribute(returnTo)#"></cfif>
                                <div class="col">
                                    <select name="areaID" class="form-select" required>
                                        <option value="">— select permission —</option>
                                        <cfloop array="#allAreas#" index="area">
                                            <cfset alreadyHas = arrayFindNoCase(userPermissions, area.ACCESSNAME) GT 0>
                                            <option value="#area.ACCESSAREAID#"
                                                    #(alreadyHas ? 'disabled class="text-muted"' : '')#>
                                                #encodeForHTML(area.ACCESSNAME)##(alreadyHas ? ' (already granted)' : '')#
                                            </option>
                                        </cfloop>
                                    </select>
                                </div>
                                <div class="col-auto">
                                    <button type="submit" class="btn btn-ui-save">
                                        <i class="bi bi-plus-lg me-1"></i>Grant
                                    </button>
                                </div>
                            </form>
                        <cfelse>
                            <p class="text-muted small mb-0">
                                No permission definitions found in AccessAreas.
                                Run the migration first.
                            </p>
                        </cfif>
                    </div>
                </div>

            </cfif>
        <cfelse>
            <div class="card border-0 shadow-sm">
                <div class="card-body text-muted text-center py-5">
                    <i class="bi bi-person-lock display-4 mb-3 d-block"></i>
                    Search for a user by name to view and manage their permissions.
                </div>
            </div>
        </cfif>
    </div>

</div>

<!--- ── Available permission definitions ────────────────────────────────── --->
<div class="mt-5">
    <h5><i class="bi bi-list-ul me-2"></i>Available Permission Definitions</h5>
    <p class="text-muted small">These are the permission strings defined in AccessAreas. Add new ones via the <a href="/admin/settings/admin-permissions/access-areas/">Access Areas</a> page using dot-notation format (e.g. <code>module.action</code>).</p>
    <cfif arrayLen(allAreas)>
        <div class="d-flex flex-wrap gap-2 mt-3">
            <cfloop array="#allAreas#" index="area">
                <span class="badge bg-light text-dark border"><code>#encodeForHTML(area.ACCESSNAME)#</code></span>
            </cfloop>
        </div>
    <cfelse>
        <p class="text-muted">No permission definitions found. Run migration 012 to seed defaults.</p>
    </cfif>
</div>

</div>

</cfoutput>
</cfsavecontent>

<cfsavecontent variable="pageScripts">
<cfoutput>
<script nonce="#encodeForHTMLAttribute(request.cspNonce ?: '')#">
<cfif len(msgParam)>
if (window.AdminUI && typeof window.AdminUI.showToast === 'function') {
    window.AdminUI.showToast("#encodeForJavaScript(msgParam)#", { tone: 'success' });
}
</cfif>
<cfif len(errParam)>
if (window.AdminUI && typeof window.AdminUI.showToast === 'function') {
    window.AdminUI.showToast("#encodeForJavaScript(errParam)#", { tone: 'danger' });
}
</cfif>
(function () {
    var users = #userLookupJSONSafe#;

    var input  = document.getElementById('userNameInput');
    var hidden = document.getElementById('userIDHidden');
    var list   = document.getElementById('userSuggestList');
    var hint   = document.getElementById('userSelectedHint');
    var error  = document.getElementById('userLookupError');
    var form   = document.getElementById('userLookupForm');

    if (!input || !hidden || !list || !form) return;

    function normalize(s) {
        return (s || '').toLowerCase().replace(/\s+/g, ' ').trim();
    }

    function matches(user, q) {
        var f  = normalize(user.first);
        var l  = normalize(user.last);
        var nq = normalize(q);
        if (!nq) return false;
        return (
            (f + ' ' + l).indexOf(nq) !== -1 ||
            (l + ' ' + f).indexOf(nq) !== -1 ||
            (l + ', ' + f).indexOf(nq) !== -1 ||
            l.indexOf(nq) === 0 ||
            f.indexOf(nq) === 0
        );
    }

    function highlight(text, q) {
        if (!q) return encodeHTML(text);
        var re = new RegExp('(' + q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ')', 'gi');
        return encodeHTML(text).replace(re, '<strong>$1</strong>');
    }

    function encodeHTML(s) {
        return String(s)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    }

    function showList(filtered, q) {
        list.innerHTML = '';
        if (!filtered.length) {
            list.style.display = 'none';
            return;
        }
        var cap = filtered.slice(0, 25);
        cap.forEach(function (user) {
            var btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'list-group-item list-group-item-action py-1 px-2 small';
            btn.innerHTML =
                highlight(user.last, q) + ', ' + highlight(user.first, q) +
                ' <span class="text-muted ms-1">ID ' + encodeHTML(user.id) + '</span>';
            btn.addEventListener('mousedown', function (e) {
                e.preventDefault();
                selectUser(user);
            });
            list.appendChild(btn);
        });
        if (filtered.length > 25) {
            var more = document.createElement('div');
            more.className = 'list-group-item text-muted small py-1 px-2 fst-italic';
            more.textContent = (filtered.length - 25) + ' more — keep typing to narrow results';
            list.appendChild(more);
        }
        list.style.display = 'block';
    }

    function hideList() {
        list.style.display = 'none';
    }

    function selectUser(user) {
        input.value  = user.first + ' ' + user.last;
        hidden.value = user.id;
        if (hint) {
            hint.textContent = 'ID: ' + user.id;
            hint.style.display = '';
        }
        if (error) error.style.display = 'none';
        input.classList.remove('is-invalid');
        hideList();
        form.requestSubmit();
    }

    input.addEventListener('input', function () {
        hidden.value = '';
        if (hint) hint.style.display = 'none';
        var q = this.value.trim();
        if (q.length < 2) { hideList(); return; }
        var filtered = users.filter(function (u) { return matches(u, q); });
        showList(filtered, q);
    });

    input.addEventListener('keydown', function (e) {
        if (list.style.display === 'none') return;
        var items = list.querySelectorAll('button.list-group-item');
        var active = list.querySelector('button.list-group-item.active');
        var idx = active ? Array.prototype.indexOf.call(items, active) : -1;

        if (e.key === 'ArrowDown') {
            e.preventDefault();
            if (active) active.classList.remove('active');
            var next = items[idx + 1] || items[0];
            if (next) next.classList.add('active');
        } else if (e.key === 'ArrowUp') {
            e.preventDefault();
            if (active) active.classList.remove('active');
            var prev = items[idx - 1] || items[items.length - 1];
            if (prev) prev.classList.add('active');
        } else if (e.key === 'Enter') {
            if (active) {
                e.preventDefault();
                active.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
            }
        } else if (e.key === 'Escape') {
            hideList();
        }
    });

    input.addEventListener('blur', function () {
        setTimeout(hideList, 150);
    });

    input.addEventListener('focus', function () {
        var q = this.value.trim();
        if (q.length >= 2 && !hidden.value) {
            var filtered = users.filter(function (u) { return matches(u, q); });
            showList(filtered, q);
        }
    });

    form.addEventListener('submit', function (e) {
        if (!hidden.value) {
            e.preventDefault();
            input.classList.add('is-invalid');
            if (error) error.style.display = 'block';
            input.focus();
        }
    });
})();
</script>
</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
