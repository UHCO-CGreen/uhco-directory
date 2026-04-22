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
<cfset flagsService      = createObject("component", "cfc.flags_service").init()>

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
<cfset userFlags       = flagsService.getUserFlags(userID).data>
<cfset sourceProvider  = sourceService.getSourceProvider()>
<cfset sourceKeys = sourceService.getSourceKeys()>
<cfset availableFiles = []>

<!--- Local provider can load file options synchronously. Dropbox is lazy-loaded via AJAX. --->
<cfif sourceProvider NEQ "dropbox">
    <cfset availableFiles = sourceService.getAvailableFilesForUserByFlags(
        firstName   = user.FIRSTNAME ?: "",
        lastName    = user.LASTNAME  ?: "",
        middleName  = user.MIDDLENAME ?: "",
        externalIDs = userExternalIDs,
        userFlags   = userFlags
    )>
</cfif>

<!--- ── AJAX endpoints (no layout output) ───────────────────────────────── --->
<cfif structKeyExists(url, "ajax")>
    <cfset ajaxAction = lCase(trim(url.ajax ?: ""))>
    <cfsetting showdebugoutput="false">

    <cfif ajaxAction EQ "loadfiles">
        <cftry>
            <cfset ajaxFiles = sourceService.getAvailableFilesForUserByFlags(
                firstName   = user.FIRSTNAME ?: "",
                lastName    = user.LASTNAME  ?: "",
                middleName  = user.MIDDLENAME ?: "",
                externalIDs = userExternalIDs,
                userFlags   = userFlags
            )>
            <cfcontent type="application/json; charset=utf-8" reset="true"><cfoutput>#serializeJSON({ success=true, files=ajaxFiles })#</cfoutput><cfabort>
        <cfcatch type="any">
            <cfcontent type="application/json; charset=utf-8" reset="true"><cfoutput>#serializeJSON({ success=false, message=(cfcatch.message ?: "Unable to load source images."), detail=(cfcatch.detail ?: "") })#</cfoutput><cfabort>
        </cfcatch>
        </cftry>
    </cfif>

    <cfif ajaxAction EQ "addsource" AND cgi.request_method EQ "POST">
        <cftry>
            <cfset ajaxResult = sourceService.addSource(
                userID     = userID,
                sourceKey  = form.sourceKey  ?: "",
                sourcePath = form.sourcePath ?: ""
            )>
            <cfset ajaxPayload = {
                success = ajaxResult.success,
                message = ajaxResult.message
            }>
            <cfif ajaxResult.success>
                <cfset ajaxPayload.redirectUrl = "/admin/user-media/variants.cfm?userid=#userID#&sourceid=#ajaxResult.sourceID#">
            </cfif>
            <cfcontent type="application/json; charset=utf-8" reset="true"><cfoutput>#serializeJSON(ajaxPayload)#</cfoutput><cfabort>
        <cfcatch type="any">
            <cfcontent type="application/json; charset=utf-8" reset="true"><cfoutput>#serializeJSON({ success=false, message=(cfcatch.message ?: "Unable to add source."), detail=(cfcatch.detail ?: "") })#</cfoutput><cfabort>
        </cfcatch>
        </cftry>
    </cfif>

    <cfcontent type="application/json; charset=utf-8" reset="true"><cfoutput>#serializeJSON({ success=false, message="Unknown AJAX action." })#</cfoutput><cfabort>
</cfif>

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
        <a href='/admin/user-media/variants.cfm?userid=#userID#&sourceid=#s.USERIMAGESOURCEID#' class='btn btn-sm btn-secondary ms-1'>Manage Variants</a>
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

<!--- ── Compute which folders were searched (for display hint) ───────────── --->
<cfset searchedFolders = sourceService.getAllowedFoldersByFlags(userFlags)>
<cfset dropboxBrowseMode = sourceService.getDropboxBrowseMode()>
<cfset folderBrowseFolders = sourceService.getDropboxFolderBrowseFolders()>
<cfset candidateFolderNames = sourceService.getCandidateFolderNames(
    firstName   = user.FIRSTNAME ?: "",
    lastName    = user.LASTNAME  ?: "",
    middleName  = user.MIDDLENAME ?: "",
    externalIDs = userExternalIDs
)>
<cfset folderHintHtml = "">
<cfif sourceProvider EQ "dropbox">
    <cfif dropboxBrowseMode EQ "folders">
        <!--- Folder mode: targeted per-user subfolder --->
        <cfset candidateList = arrayLen(candidateFolderNames) ? encodeForHTML(arrayToList(candidateFolderNames, ", ")) : "<em>none &mdash; no IDs or name data found</em>">
        <cfif arrayLen(searchedFolders) GT 0>
            <cfset folderHintHtml = "<div class='form-text text-muted mt-2'><i class='bi bi-person-vcard me-1'></i>Folder mode &mdash; searching <strong>" & encodeForHTML(arrayToList(searchedFolders, ", ")) & "</strong> for subfolder named: <code>" & candidateList & "</code></div>">
        <cfelse>
            <cfset folderHintHtml = "<div class='form-text text-muted mt-2'><i class='bi bi-person-vcard me-1'></i>Folder mode active &mdash; no flag-matched folders found for this user.</div>">
        </cfif>
    <cfelseif dropboxBrowseMode EQ "mixed">
        <cfset candidateList = arrayLen(candidateFolderNames) ? encodeForHTML(arrayToList(candidateFolderNames, ", ")) : "<em>none &mdash; no IDs or name data found</em>">
        <cfset mixedFolderModeFolders = []>
        <cfset mixedFileModeFolders = []>
        <cfloop array="#searchedFolders#" index="sf">
            <cfif arrayFindNoCase(folderBrowseFolders, sf)>
                <cfset arrayAppend(mixedFolderModeFolders, sf)>
            <cfelse>
                <cfset arrayAppend(mixedFileModeFolders, sf)>
            </cfif>
        </cfloop>
        <cfif arrayLen(searchedFolders) GT 0>
            <cfset folderHintHtml = "<div class='form-text text-muted mt-2'><i class='bi bi-diagram-3 me-1'></i>Mixed mode &mdash; folder lookup in <strong>" & encodeForHTML(arrayToList(mixedFolderModeFolders, ", ")) & "</strong> for subfolder named <code>" & candidateList & "</code>; file scan in <strong>" & encodeForHTML(arrayToList(mixedFileModeFolders, ", ")) & "</strong>.</div>">
        <cfelse>
            <cfset folderHintHtml = "<div class='form-text text-muted mt-2'><i class='bi bi-diagram-3 me-1'></i>Mixed mode active &mdash; no flag-matched folders found for this user.</div>">
        </cfif>
    <cfelse>
        <!--- File mode (default): name-token scan across flag folders --->
        <cfif arrayLen(searchedFolders) GT 0>
            <cfset folderHintHtml = "<div class='form-text text-muted mt-2'><i class='bi bi-folder2-open me-1'></i>Searching in: <strong>" & encodeForHTML(arrayToList(searchedFolders, ", ")) & "</strong> (based on user&rsquo;s flags)</div>">
        <cfelse>
            <cfset folderHintHtml = "<div class='form-text text-muted mt-2'><i class='bi bi-folder2-open me-1'></i>Searching all Headshots folders (no flag match)</div>">
        </cfif>
    </cfif>
</cfif>

<!--- ── Build image picker HTML (shared between add form and edit modal) ──── --->
<!--- Add form picker — radio name="sourcePath", IDs prefixed "sf_add_" --->
<cfset addPickerHtml = "">
<cfif sourceProvider EQ "dropbox">
    <cfset addPickerHtml = "
    <div class='mb-2'>
        <button type='button' id='loadAddImagesBtn' class='btn btn-outline-primary btn-sm'>
            <i class='bi bi-cloud-download me-1'></i>Load Source Images
        </button>
    </div>
    <div id='addFilePickerStatus' class='alert alert-info mb-2 d-none'>
        <div class='fw-semibold mb-1'><i class='bi bi-cloud-download me-1'></i>Downloading Source Images</div>
        <div class='progress' role='progressbar' aria-label='Downloading source images'>
            <div class='progress-bar progress-bar-striped progress-bar-animated' style='width: 20%'></div>
        </div>
        <div class='small text-muted mt-1'>Fetching images from Dropbox. This can take a moment.</div>
    </div>
    <div id='addFilePickerHost'></div>
    ">
<cfelse>
    <!--- Local provider — keep original select for backwards compatibility --->
    <cfset addPickerHtml = "<select name='sourcePath' class='form-select' required><option value=''>— select file —</option>">
    <cfloop from="1" to="#arrayLen(availableFiles)#" index="f">
        <cfset af = availableFiles[f]>
        <cfset addPickerHtml &= "<option value='#encodeForHTMLAttribute(af.path)#'>#encodeForHTML(af.filename)#</option>">
    </cfloop>
    <cfif arrayLen(availableFiles) EQ 0>
        <cfset addPickerHtml &= "<option value='' disabled>No files found in _temp_source/</option>">
    </cfif>
    <cfset addPickerHtml &= "</select><div class='form-text text-muted'>Files from <code>/admin/_temp_source/</code></div>">
</cfif>

<!--- Edit modal picker — radio name="sourcePath", IDs prefixed "sf_edit_" --->
<cfset editPickerHtml = "">
<cfif sourceProvider EQ "dropbox">
    <cfset editPickerHtml = "
    <div class='mb-2'>
        <button type='button' id='loadEditImagesBtn' class='btn btn-outline-primary btn-sm'>
            <i class='bi bi-cloud-download me-1'></i>Load Source Images
        </button>
    </div>
    <div id='editFilePickerStatus' class='alert alert-info mb-2 d-none'>
        <div class='fw-semibold mb-1'><i class='bi bi-cloud-download me-1'></i>Downloading Source Images</div>
        <div class='progress' role='progressbar' aria-label='Downloading source images'>
            <div class='progress-bar progress-bar-striped progress-bar-animated' style='width: 20%'></div>
        </div>
        <div class='small text-muted mt-1'>Fetching images from Dropbox. This can take a moment.</div>
    </div>
    <div id='editFilePickerHost'></div>
    ">
<cfelse>
    <cfset editPickerHtml = "<select name='sourcePath' id='editSourcePath' class='form-select' required><option value=''>— select file —</option>">
    <cfloop from="1" to="#arrayLen(availableFiles)#" index="f">
        <cfset af = availableFiles[f]>
        <cfset editPickerHtml &= "<option value='#encodeForHTMLAttribute(af.path)#'>#encodeForHTML(af.filename)#</option>">
    </cfloop>
    <cfset editPickerHtml &= "</select>">
</cfif>

<!--- ── Add source form ──────────────────────────────────────────────────── --->
<cfset content &= "
<div class='card mb-4'>
    <div class='card-header fw-semibold'><i class='bi bi-plus-circle me-1'></i> Add Image Source</div>
    <div class='card-body'>
        <form method='post' id='addSourceForm'>
            <input type='hidden' name='action' value='add'>
            <div class='row g-3 align-items-end mb-3'>
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
                <div class='col-md-2'>
                    <button type='submit' id='addSourceSubmit' class='btn btn-primary w-100'>
                        <i class='bi bi-plus'></i> Add
                    </button>
                </div>
            </div>
            <div id='addSourceStatus' class='alert alert-info d-none' role='status' aria-live='polite'>
                <div class='fw-semibold mb-1'><i class='bi bi-hourglass-split me-1'></i>Getting Things Ready</div>
                <div class='progress' role='progressbar' aria-label='Assigning source'>
                    <div class='progress-bar progress-bar-striped progress-bar-animated' style='width: 35%'></div>
                </div>
                <div class='small text-muted mt-1'>Assigning selected image to source key.</div>
            </div>
            <div>
                <label class='form-label'>Source File <span class='text-danger'>*</span></label>
                #addPickerHtml#
                #folderHintHtml#
            </div>
        </form>
    </div>
</div>
">

<!--- ── Edit source modal ────────────────────────────────────────────────── --->
<cfset content &= "
<div class='modal fade' id='editModal' tabindex='-1' aria-labelledby='editModalLabel' aria-hidden='true'>
    <div class='modal-dialog modal-lg'>
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
                        #editPickerHtml#
                        #folderHintHtml#
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

">

<cfsavecontent variable="sourcesScript">
<cfoutput>
<script>
(function () {
    var sourceProvider = '#encodeForJavaScript(sourceProvider)#';
    var loadFilesUrl = '/admin/user-media/sources.cfm?userid=#userID#&ajax=loadfiles';
    var addSourceUrl = '/admin/user-media/sources.cfm?userid=#userID#&ajax=addsource';
    var currentSourcePath = '';
    var filesLoaded = false;

    function escapeHtml(value) {
        return String(value || '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/\u0022/g, '&quot;')
            .replace(/'/g, '&##39;');
    }

    function initPicker(pickerEl) {
        if (!pickerEl) { return; }
        var radios = pickerEl.querySelectorAll('.source-file-radio');
        radios.forEach(function (radio) {
            radio.addEventListener('change', function () {
                pickerEl.querySelectorAll('.source-file-item').forEach(function (item) {
                    item.classList.remove('selected');
                });
                if (radio.checked && radio.closest('.source-file-item')) {
                    radio.closest('.source-file-item').classList.add('selected');
                }
            });
        });
    }

    function markStatus(statusEl, level, title, detail, percent) {
        if (!statusEl) { return; }
        statusEl.classList.remove('alert-info', 'alert-success', 'alert-danger', 'd-none');
        statusEl.classList.add('alert-' + level);
        var pct = (typeof percent === 'number') ? percent : (level === 'info' ? 30 : (level === 'success' ? 100 : 100));
        if (pct < 0) { pct = 0; }
        if (pct > 100) { pct = 100; }

        statusEl.innerHTML =
            "<div class='fw-semibold mb-1'><i class='bi bi-hourglass-split me-1'></i>" + escapeHtml(title) + "</div>" +
            "<div class='progress' role='progressbar' aria-label='Progress'>" +
            "<div class='progress-bar progress-bar-striped progress-bar-animated' style='width: " + pct + "%'></div>" +
            "</div>" +
            "<div class='small text-muted mt-1'>" + escapeHtml(detail || '') + "</div>";
        if (level === 'success') {
            var successBar = statusEl.querySelector('.progress-bar');
            if (successBar) {
                successBar.classList.remove('progress-bar-animated');
                successBar.style.width = '100%';
            }
        }
        if (level === 'danger') {
            statusEl.querySelector('.progress').remove();
        }
    }

    function setProgress(statusEl, percent) {
        if (!statusEl) { return; }
        var progressBar = statusEl.querySelector('.progress-bar');
        if (!progressBar) { return; }
        var pct = Math.max(0, Math.min(100, percent));
        progressBar.style.width = pct + '%';
    }

    function buildPickerHtml(files, pickerId, inputName) {
        var html = "<div class='source-file-picker" + (pickerId === 'editFilePicker' ? " source-file-picker-modal" : "") + "' id='" + pickerId + "'>";
        files.forEach(function (file, index) {
            var id = pickerId + '_' + (index + 1);
            var filePath = (file && (file.path || file.PATH)) ? (file.path || file.PATH) : '';
            var fileName = (file && (file.filename || file.FILENAME)) ? (file.filename || file.FILENAME) : '';
            html += "<label class='source-file-item' for='" + id + "'>";
            html += "<input type='radio' name='" + inputName + "' id='" + id + "' value='" + escapeHtml(filePath) + "' class='source-file-radio'" + (index === 0 ? " required" : "") + ">";
            html += "<img src='/admin/user-media/_serve_dropbox_image.cfm?path=" + encodeURIComponent(filePath) + "' alt='" + escapeHtml(fileName) + "' class='source-file-thumb' loading='lazy'>";
            html += "<span class='source-file-name'>" + escapeHtml(fileName) + "</span>";
            html += "</label>";
        });
        html += "</div>";
        return html;
    }

    function preselectEditPath(sourcePath) {
        var picker = document.getElementById('editFilePicker');
        if (!picker) { return; }
        var found = false;
        picker.querySelectorAll('.source-file-radio').forEach(function (radio) {
            var match = (radio.value === sourcePath);
            radio.checked = match;
            if (radio.closest('.source-file-item')) {
                radio.closest('.source-file-item').classList.toggle('selected', match);
            }
            if (match) { found = true; }
        });
        if (!found) {
            var first = picker.querySelector('.source-file-radio');
            if (first) {
                first.checked = true;
                if (first.closest('.source-file-item')) {
                    first.closest('.source-file-item').classList.add('selected');
                }
            }
        }
    }

    function loadDropboxFiles() {
        if (sourceProvider !== 'dropbox' || filesLoaded) { return; }

        var addStatus = document.getElementById('addFilePickerStatus');
        var editStatus = document.getElementById('editFilePickerStatus');
        var addHost = document.getElementById('addFilePickerHost');
        var editHost = document.getElementById('editFilePickerHost');

        markStatus(addStatus, 'info', 'Downloading Source Images', 'Fetching images from Dropbox. This can take a moment.', 20);
        markStatus(editStatus, 'info', 'Downloading Source Images', 'Fetching images from Dropbox. This can take a moment.', 20);
        setTimeout(function () {
            setProgress(addStatus, 45);
            setProgress(editStatus, 45);
        }, 500);

        fetch(loadFilesUrl, {
            method: 'GET',
            headers: { 'X-Requested-With': 'XMLHttpRequest' }
        })
        .then(function (resp) {
            return resp.text().then(function (text) {
                var data = null;
                try { data = text ? JSON.parse(text) : null; } catch (e) { data = null; }
                if (!resp.ok) {
                    throw new Error((data && data.message) ? data.message : ('HTTP ' + resp.status));
                }
                if (!data) {
                    throw new Error('Source image response was not valid JSON.');
                }
                return data;
            });
        })
        .then(function (data) {
            var success = !!(data && (data.success === true || data.SUCCESS === true));
            var message = (data && (data.message || data.MESSAGE)) ? (data.message || data.MESSAGE) : '';
            var files = [];
            if (data) {
                if (Array.isArray(data.files)) {
                    files = data.files;
                } else if (Array.isArray(data.FILES)) {
                    files = data.FILES;
                }
            }

            // If backend says failure but still returned files, continue with files.
            // This avoids false-negative UI states caused by payload shape differences.
            if (!success && !files.length) {
                throw new Error(message || 'Could not load source images.');
            }

            filesLoaded = true;

            if (!files.length) {
                var emptyHtml = "<div class='alert alert-warning mb-0'><i class='bi bi-exclamation-triangle me-1'></i>No images found for this user in the searched folders.</div>";
                if (addHost) { addHost.innerHTML = emptyHtml; }
                if (editHost) { editHost.innerHTML = emptyHtml; }
                markStatus(addStatus, 'danger', 'No Source Images Found', 'No images were returned from Dropbox for this user.');
                markStatus(editStatus, 'danger', 'No Source Images Found', 'No images were returned from Dropbox for this user.');
                return;
            }

            if (addHost) {
                addHost.innerHTML = buildPickerHtml(files, 'addFilePicker', 'sourcePath');
                initPicker(document.getElementById('addFilePicker'));
            }
            if (editHost) {
                editHost.innerHTML = buildPickerHtml(files, 'editFilePicker', 'sourcePath');
                initPicker(document.getElementById('editFilePicker'));
                if (currentSourcePath) { preselectEditPath(currentSourcePath); }
            }

            setProgress(addStatus, 90);
            setProgress(editStatus, 90);

            if (success) {
                markStatus(addStatus, 'success', 'Source Images Ready', files.length + ' image(s) loaded.');
                markStatus(editStatus, 'success', 'Source Images Ready', files.length + ' image(s) loaded.');
            } else {
                markStatus(addStatus, 'info', 'Source Images Ready', files.length + ' image(s) loaded. ' + (message || 'Partial response received.'), 100);
                markStatus(editStatus, 'info', 'Source Images Ready', files.length + ' image(s) loaded. ' + (message || 'Partial response received.'), 100);
            }
        })
        .catch(function (err) {
            filesLoaded = false;
            markStatus(addStatus, 'danger', 'Unable to Load Source Images', err && err.message ? err.message : 'An error occurred.');
            markStatus(editStatus, 'danger', 'Unable to Load Source Images', err && err.message ? err.message : 'An error occurred.');
        });
    }

    document.addEventListener('DOMContentLoaded', function () {
        var loadAddBtn = document.getElementById('loadAddImagesBtn');
        var loadEditBtn = document.getElementById('loadEditImagesBtn');
        if (loadAddBtn) {
            loadAddBtn.addEventListener('click', loadDropboxFiles);
        }
        if (loadEditBtn) {
            loadEditBtn.addEventListener('click', loadDropboxFiles);
        }

        var addForm = document.getElementById('addSourceForm');
        var addStatus = document.getElementById('addSourceStatus');
        var addSubmitBtn = document.getElementById('addSourceSubmit');

        if (addForm && sourceProvider === 'dropbox') {
            addForm.addEventListener('submit', function (event) {
                event.preventDefault();

                var selected = addForm.querySelector('input[name="sourcePath"]:checked');
                var selectedKey = addForm.querySelector('select[name="sourceKey"]');
                if (!selectedKey || !selectedKey.value) {
                    alert('Please choose a Source Key.');
                    return;
                }
                if (!filesLoaded) {
                    alert('Click "Load Source Images" before adding a source.');
                    return;
                }
                if (!selected) {
                    alert('Please select a source image.');
                    return;
                }

                addSubmitBtn.disabled = true;
                markStatus(addStatus, 'info', 'Getting Things Ready', 'Assigning selected image to source key.', 35);
                setTimeout(function () {
                    setProgress(addStatus, 75);
                }, 400);

                var body = new FormData(addForm);
                fetch(addSourceUrl, {
                    method: 'POST',
                    body: body,
                    headers: { 'X-Requested-With': 'XMLHttpRequest' }
                })
                .then(function (resp) {
                    return resp.text().then(function (text) {
                        var data = null;
                        try { data = text ? JSON.parse(text) : null; } catch (e) { data = null; }
                        if (!resp.ok) {
                            throw new Error((data && data.message) ? data.message : ('HTTP ' + resp.status));
                        }
                        if (!data) {
                            throw new Error('Add source response was not valid JSON.');
                        }
                        return data;
                    });
                })
                .then(function (data) {
                    var success = !!(data && (data.success === true || data.SUCCESS === true));
                    var message = (data && (data.message || data.MESSAGE)) ? (data.message || data.MESSAGE) : '';
                    var redirectUrl = (data && (data.redirectUrl || data.REDIRECTURL)) ? (data.redirectUrl || data.REDIRECTURL) : '';

                    if (!success) {
                        throw new Error(message || 'Unable to add source.');
                    }
                    markStatus(addStatus, 'success', 'Source Added', message || 'Source added successfully.');
                    window.location.href = redirectUrl || window.location.href;
                })
                .catch(function (err) {
                    addSubmitBtn.disabled = false;
                    markStatus(addStatus, 'danger', 'Unable to Add Source', err && err.message ? err.message : 'An error occurred.');
                });
            });
        }

        // ── Edit modal: pre-select the right image when modal opens ──────────
        var editModal = document.getElementById('editModal');
        if (!editModal) { return; }

        editModal.addEventListener('show.bs.modal', function (event) {
            var btn        = event.relatedTarget;
            var sourceID   = btn.getAttribute('data-source-id')   || '';
            var sourceKey  = btn.getAttribute('data-source-key')  || '';
            var sourcePath = btn.getAttribute('data-source-path') || '';
            currentSourcePath = sourcePath;

            document.getElementById('editSourceID').value = sourceID;

            // Populate source key select
            var keySelect = document.getElementById('editSourceKey');
            for (var i = 0; i < keySelect.options.length; i++) {
                keySelect.options[i].selected = (keySelect.options[i].value === sourceKey);
            }

            // Image picker: check the matching radio and mark it selected
            var picker = document.getElementById('editFilePicker');
            if (picker) {
                preselectEditPath(sourcePath);
            } else {
                // Fallback: local provider select element
                var pathSelect = document.getElementById('editSourcePath');
                if (pathSelect) {
                    for (var j = 0; j < pathSelect.options.length; j++) {
                        pathSelect.options[j].selected = (pathSelect.options[j].value === sourcePath);
                    }
                }
            }
        });
    });
}());
</script>
</cfoutput>
</cfsavecontent>

<cfset content &= sourcesScript>

<cfinclude template="/admin/layout.cfm">
