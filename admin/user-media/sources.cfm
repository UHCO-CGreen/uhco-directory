<!--- ── Authorization ─────────────────────────────────────────────────────── --->
<cfif NOT request.hasPermission("media.edit")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<!--- ── Validate required URL parameter ──────────────────────────────────── --->
<cfif NOT structKeyExists(url, "userid") OR NOT isNumeric(url.userid) OR val(url.userid) LTE 0>
    <cflocation url="#request.webRoot#/admin/user-media/index.cfm" addtoken="false">
</cfif>

<cfset userID = val(url.userid)>

<!--- ── Services (no SQL, no filesystem in this file) ────────────────────── --->
<cfset usersService      = createObject("component", "cfc.users_service").init()>
<cfset sourceService     = createObject("component", "cfc.UserImageSourceService").init()>
<cfset externalIDService = createObject("component", "cfc.externalID_service").init()>

<!--- ── Load user — stop gracefully if not found ─────────────────────────── --->
<cfset userResult = usersService.getUser(userID)>

<cfif NOT userResult.success>
    <cfset content = "
    <div class='alert alert-danger'>
        User not found. <a href='/admin/user-media/index.cfm'>Return to User Media</a>
    </div>
    ">
    <cfinclude template="/admin/layout.cfm">
    <cfabort>
</cfif>

<cfset user = userResult.data>

<!--- ── Source data from service (local folder via service abstraction) ───── --->
<cfset userExternalIDs = externalIDService.getExternalIDs(userID).data>
<cfset availableFiles  = sourceService.getAvailableFilesForUser(
    firstName   = user.FIRSTNAME ?: "",
    lastName    = user.LASTNAME  ?: "",
    middleName  = user.MIDDLENAME ?: "",
    externalIDs = userExternalIDs
)>
<cfset sourceKeys = sourceService.getSourceKeys()>

<!--- ── Handle POST actions (add / update / deactivate) ──────────────────── --->
<cfset actionMessage      = "">
<cfset actionMessageClass = "alert-success">

<cfif cgi.request_method EQ "POST">
    <cfset action = trim(form.action ?: "")>

    <cfif action EQ "add">
        <cfset result = sourceService.addSource(
            userID     = userID,
            sourceKey  = form.sourceKey  ?: "",
            sourcePath = form.sourcePath ?: ""
        )>
        <cfset actionMessage      = result.message>
        <cfset actionMessageClass = result.success ? "alert-success" : "alert-danger">

    <cfelseif action EQ "deactivate" AND isNumeric(form.sourceID ?: "")>
        <cfset result = sourceService.deactivateSource(
            sourceID = val(form.sourceID),
            userID   = userID
        )>
        <cfset actionMessage      = result.message>
        <cfset actionMessageClass = result.success ? "alert-success" : "alert-danger">

    <cfelseif action EQ "delete" AND isNumeric(form.sourceID ?: "")>
        <cfset result = sourceService.deleteSource(
            sourceID = val(form.sourceID),
            userID   = userID
        )>
        <cfset actionMessage      = result.message>
        <cfset actionMessageClass = result.success ? "alert-success" : "alert-danger">

    <cfelseif action EQ "update" AND isNumeric(form.sourceID ?: "")>
        <cfset result = sourceService.updateSource(
            sourceID   = val(form.sourceID),
            userID     = userID,
            sourceKey  = form.sourceKey  ?: "",
            sourcePath = form.sourcePath ?: ""
        )>
        <cfset actionMessage      = result.message>
        <cfset actionMessageClass = result.success ? "alert-success" : "alert-danger">
    </cfif>
</cfif>

<!--- ── Reload sources after any POST so the table reflects current state ─── --->
<cfset sourcesResult = sourceService.getSourcesForUser(userID)>
<cfset sources       = sourcesResult.data>

<!--- ── Build display values ─────────────────────────────────────────────── --->
<cfset displayName  = encodeForHTML(trim((user.FIRSTNAME ?: "") & " " & (user.LASTNAME ?: "")))>
<cfset displayEmail = encodeForHTML(user.EMAILPRIMARY ?: "")>

<!--- ═══════════════════════════════════════════════════════════════════════
     Page content — uses cfset content / cfset content &= convention
     matching all other admin pages.
     ═══════════════════════════════════════════════════════════════════════ --->

<!--- ── Breadcrumb + heading ─────────────────────────────────────────────── --->
<cfset content = "
<nav aria-label='breadcrumb' class='mb-3'>
    <ol class='breadcrumb'>
        <li class='breadcrumb-item'><a href='/admin/user-media/index.cfm'>User Media</a></li>
        <li class='breadcrumb-item active' aria-current='page'>Image Sources</li>
    </ol>
</nav>
<h1 class='mb-1'>Image Sources</h1>
<p class='text-muted mb-4'>Manage authoritative source images for a user. Changing or deactivating a source marks related variants as stale for explicit regeneration.</p>
">

<!--- ── User context card ────────────────────────────────────────────────── --->
<cfset content &= "
<div class='card mb-4'>
    <div class='card-header fw-semibold'><i class='bi bi-person-circle me-1'></i> User</div>
    <div class='card-body'>
        <dl class='row mb-0'>
            <dt class='col-sm-2'>Name</dt>
            <dd class='col-sm-10'>#displayName#</dd>
            <dt class='col-sm-2'>Email</dt>
            <dd class='col-sm-10'>#displayEmail#</dd>
            <dt class='col-sm-2'>User ID</dt>
            <dd class='col-sm-10'>#userID#</dd>
        </dl>
    </div>
</div>
">

<!--- ── Action feedback message ──────────────────────────────────────────── --->
<cfif len(actionMessage)>
    <cfset content &= "
    <div class='alert #actionMessageClass# alert-dismissible fade show' role='alert'>
        #encodeForHTML(actionMessage)#
        <button type='button' class='btn-close' data-bs-dismiss='alert' aria-label='Close'></button>
    </div>
    ">
</cfif>

<!--- ── Existing sources table ───────────────────────────────────────────── --->
<cfset content &= "
<div class='card mb-4'>
    <div class='card-header d-flex justify-content-between align-items-center'>
        <span class='fw-semibold'><i class='bi bi-images me-1'></i> Existing Image Sources</span>
        <span class='badge bg-secondary'>#arrayLen(sources)#</span>
    </div>
    <div class='card-body p-0'>
">

<cfif arrayLen(sources) GT 0>
    <cfset content &= "
        <table class='table table-striped table-hover mb-0'>
            <thead class='table-dark'>
                <tr>
                    <th>Source Key</th>
                    <th>File</th>
                    <th class='text-center'>Status</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
    ">

    <cfloop from="1" to="#arrayLen(sources)#" index="i">
        <cfset s        = sources[i]>
        <cfset filename = listLast(s.DROPBOXPATH, "/\")>
        <cfset isActive = isBoolean(s.ISACTIVE) ? s.ISACTIVE : (val(s.ISACTIVE) EQ 1)>

        <cfset content &= "
            <tr>
                <td><span class='badge bg-primary'>#encodeForHTML(s.SOURCEKEY)#</span></td>
                <td class='text-muted small font-monospace'>#encodeForHTML(filename)#</td>
                <td class='text-center'>
        ">

        <cfif isActive>
            <cfset content &= "<span class='badge bg-success'>Active</span>">
        <cfelse>
            <cfset content &= "<span class='badge bg-secondary'>Inactive</span>">
        </cfif>

        <cfset content &= "
                </td>
                <td>
                    <button type='button' class='btn btn-sm btn-info'
                            data-bs-toggle='modal'
                            data-bs-target='##editModal'
                            data-source-id='#s.USERIMAGESOURCEID#'
                            data-source-key='#encodeForHTMLAttribute(s.SOURCEKEY)#'
                            data-source-path='#encodeForHTMLAttribute(s.DROPBOXPATH)#'>
                        Edit
                    </button>
        ">

        <cfif isActive>
            <cfset content &= "
                    <form method='post' class='d-inline ms-1'
                          onsubmit=""return confirm('Deactivate this source? All related variants will be marked stale and must be regenerated manually.')"">
                        <input type='hidden' name='action'   value='deactivate'>
                        <input type='hidden' name='sourceID' value='#s.USERIMAGESOURCEID#'>
                        <button type='submit' class='btn btn-sm btn-warning'>Deactivate</button>
                    </form>
            ">
        </cfif>
        <cfset content &= "
                    <form method='post' class='d-inline ms-1'
                          onsubmit=&quot;return confirm('Permanently delete this source record? This cannot be undone.')&quot;>
                        <input type='hidden' name='action'   value='delete'>
                        <input type='hidden' name='sourceID' value='#s.USERIMAGESOURCEID#'>
                        <button type='submit' class='btn btn-sm btn-danger'>Delete</button>
                    </form>
        ">
        <cfset content &= "
        <a href='/admin/user-media/variants.cfm?userid=#userID#&sourceid=#s.USERIMAGESOURCEID#' class='btn btn-sm btn-secondary ms-1'>AssignVariants</a>
                </td>
            </tr>
        ">
    </cfloop>

    <cfset content &= "
            </tbody>
        </table>
    ">
<cfelse>
    <cfset content &= "<p class='text-muted p-3 mb-0'>No image sources on record for this user.</p>">
</cfif>

<cfset content &= "
    </div>
</div>
">

<!--- ── Add source form ──────────────────────────────────────────────────── --->
<cfset content &= "
<div class='card mb-4'>
    <div class='card-header fw-semibold'><i class='bi bi-plus-circle me-1'></i> Add Image Source</div>
    <div class='card-body'>
        <form method='post'>
            <input type='hidden' name='action' value='add'>
            <div class='row g-3 align-items-end'>
                <div class='col-md-4'>
                    <label class='form-label'>Source Key <span class='text-danger'>*</span></label>
                    <select name='sourceKey' class='form-select' required>
                        <option value=''>— select —</option>
">

<cfloop from="1" to="#arrayLen(sourceKeys)#" index="k">
    <cfset content &= "<option value='#encodeForHTMLAttribute(sourceKeys[k])#'>#encodeForHTML(sourceKeys[k])#</option>">
</cfloop>

<cfset content &= "
                    </select>
                </div>
                <div class='col-md-6'>
                    <label class='form-label'>Source File <span class='text-danger'>*</span></label>
                    <select name='sourcePath' class='form-select' required>
                        <option value=''>— select file —</option>
">

<cfif arrayLen(availableFiles) GT 0>
    <cfloop from="1" to="#arrayLen(availableFiles)#" index="f">
        <cfset af = availableFiles[f]>
        <cfset content &= "<option value='#encodeForHTMLAttribute(af.path)#'>#encodeForHTML(af.filename)#</option>">
    </cfloop>
<cfelse>
    <cfset content &= "<option value='' disabled>No files found in _temp_source/</option>">
</cfif>

<cfset content &= "
                    </select>
                    <div class='form-text text-muted'>Files from <code>/admin/_temp_source/</code></div>
                </div>
                <div class='col-md-2'>
                    <button type='submit' class='btn btn-primary w-100'>
                        <i class='bi bi-plus'></i> Add
                    </button>
                </div>
            </div>
        </form>
    </div>
</div>
">

<!--- ── Edit source modal ────────────────────────────────────────────────── --->
<cfset content &= "
<div class='modal fade' id='editModal' tabindex='-1' aria-labelledby='editModalLabel' aria-hidden='true'>
    <div class='modal-dialog'>
        <div class='modal-content'>
            <div class='modal-header'>
                <h5 class='modal-title' id='editModalLabel'><i class='bi bi-pencil me-1'></i> Edit Image Source</h5>
                <button type='button' class='btn-close' data-bs-dismiss='modal' aria-label='Close'></button>
            </div>
            <form method='post'>
                <input type='hidden' name='action'   value='update'>
                <input type='hidden' name='sourceID' id='editSourceID' value=''>
                <div class='modal-body'>
                    <div class='mb-3'>
                        <label class='form-label'>Source Key <span class='text-danger'>*</span></label>
                        <select name='sourceKey' id='editSourceKey' class='form-select' required>
                            <option value=''>— select —</option>
">

<cfloop from="1" to="#arrayLen(sourceKeys)#" index="k">
    <cfset content &= "<option value='#encodeForHTMLAttribute(sourceKeys[k])#'>#encodeForHTML(sourceKeys[k])#</option>">
</cfloop>

<cfset content &= "
                        </select>
                    </div>
                    <div class='mb-3'>
                        <label class='form-label'>Source File <span class='text-danger'>*</span></label>
                        <select name='sourcePath' id='editSourcePath' class='form-select' required>
                            <option value=''>— select file —</option>
">

<cfif arrayLen(availableFiles) GT 0>
    <cfloop from="1" to="#arrayLen(availableFiles)#" index="f">
        <cfset af = availableFiles[f]>
        <cfset content &= "<option value='#encodeForHTMLAttribute(af.path)#'>#encodeForHTML(af.filename)#</option>">
    </cfloop>
</cfif>

<cfset content &= "
                        </select>
                    </div>
                    <p class='text-muted small mb-0'>
                        <i class='bi bi-info-circle me-1'></i>
                        Saving changes will mark all related variants as stale.
                    </p>
                </div>
                <div class='modal-footer'>
                    <button type='button' class='btn btn-secondary' data-bs-dismiss='modal'>Cancel</button>
                    <button type='submit' class='btn btn-primary'>Save Changes</button>
                </div>
            </form>
        </div>
    </div>
</div>

<script>
// Populate edit modal fields from data-* attributes set on each Edit button.
document.addEventListener('DOMContentLoaded', function () {
    var editModal = document.getElementById('editModal');
    if (!editModal) { return; }

    editModal.addEventListener('show.bs.modal', function (event) {
        var btn        = event.relatedTarget;
        var sourceID   = btn.getAttribute('data-source-id')   || '';
        var sourceKey  = btn.getAttribute('data-source-key')  || '';
        var sourcePath = btn.getAttribute('data-source-path') || '';

        document.getElementById('editSourceID').value = sourceID;

        var keySelect = document.getElementById('editSourceKey');
        for (var i = 0; i < keySelect.options.length; i++) {
            keySelect.options[i].selected = (keySelect.options[i].value === sourceKey);
        }

        var pathSelect = document.getElementById('editSourcePath');
        for (var j = 0; j < pathSelect.options.length; j++) {
            pathSelect.options[j].selected = (pathSelect.options[j].value === sourcePath);
        }
    });
});
</script>
">

<cfinclude template="/admin/layout.cfm">
