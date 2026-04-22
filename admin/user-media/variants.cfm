<!--- ── Authorization ─────────────────────────────────────────────────────── --->
<cfif NOT request.hasPermission("media.edit")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<!--- ── Validate required URL parameters ─────────────────────────────────── --->
<cfif NOT structKeyExists(url, "userid") OR NOT isNumeric(url.userid) OR val(url.userid) LTE 0>
    <cflocation url="#request.webRoot#/admin/user-media/index.cfm" addtoken="false">
</cfif>
<cfif NOT structKeyExists(url, "sourceid") OR NOT isNumeric(url.sourceid) OR val(url.sourceid) LTE 0>
    <cflocation url="#request.webRoot#/admin/user-media/sources.cfm?userid=#val(url.userid)#" addtoken="false">
</cfif>

<cfset userID   = val(url.userid)>
<cfset sourceID = val(url.sourceid)>

<!--- ── Services (no SQL, no filesystem in this file) ────────────────────── --->
<cfset usersService   = createObject("component", "cfc.users_service").init()>
<cfset variantService = createObject("component", "cfc.UserImageVariantService").init()>
<cfset sourceService  = createObject("component", "cfc.UserImageSourceService").init()>

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

<!--- ── Handle POST actions ──────────────────────────────────────────────── --->
<!---
     Generation requires USER_MEDIA_ADMIN or SUPER_ADMIN.
     Authorization is already enforced at the top of this page.
     Individual actions are not silently elevated — no further privilege
     branching is needed because the page gate covers both actions.
--->
<cfset actionMessage      = "">
<cfset actionMessageClass = "alert-success">

<cfif cgi.request_method EQ "POST">
    <cfset action = trim(form.action ?: "")>

    <!--- ── Assign a variant type to this source ─────────────────────── --->
    <cfif action EQ "assign" AND isNumeric(form.imageVariantTypeID ?: "") AND val(form.imageVariantTypeID) GT 0>
        <cfset result = variantService.assignSource(
            userID             = userID,
            imageVariantTypeID = val(form.imageVariantTypeID),
            userImageSourceID  = sourceID
        )>
        <cfset actionMessage      = result.message>
        <cfset actionMessageClass = result.success ? "alert-success" : "alert-danger">

    <!--- ── Remove an assigned variant (only when not published) ───── --->
    <cfelseif action EQ "unassign" AND isNumeric(form.imageVariantTypeID ?: "") AND val(form.imageVariantTypeID) GT 0>
        <cfset result = variantService.unassignSource(
            userID             = userID,
            imageVariantTypeID = val(form.imageVariantTypeID),
            userImageSourceID  = sourceID
        )>
        <cfset actionMessage      = result.message>
        <cfset actionMessageClass = result.success ? "alert-success" : "alert-danger">

    <!--- ── Generate a single variant ───────────────────────────────── --->
    <cfelseif action EQ "generate" AND isNumeric(form.imageVariantTypeID ?: "") AND val(form.imageVariantTypeID) GT 0>
        <cfset result = variantService.generateVariant(
            userID             = userID,
            imageVariantTypeID = val(form.imageVariantTypeID),
            userImageSourceID  = sourceID
        )>
        <cfset actionMessage      = result.message>
        <cfset actionMessageClass = result.success ? "alert-success" : "alert-danger">

    <!--- ── Publish all current variants ─────────────────────────────── --->
    <cfelseif action EQ "publishAll">
        <cfif NOT request.hasPermission("media.publish")>
            <cfset actionMessage = "You do not have permission to publish media.">
            <cfset actionMessageClass = "alert-danger">
        <cfelse>
            <cfset publishingService = createObject("component", "cfc.PublishingService").init()>
            <cfset result = publishingService.publishAllVariants(userID, sourceID)>
            <cfset actionMessage      = result.message>
            <cfset actionMessageClass = result.success ? "alert-success" : "alert-danger">

            <!--- Append per-variant details if there are mixed results --->
            <cfif arrayLen(result.results) GT 0 AND NOT result.success>
                <cfloop from="1" to="#arrayLen(result.results)#" index="px">
                    <cfset pr = result.results[px]>
                    <cfif NOT pr.success>
                        <cfset actionMessage = actionMessage & " | " & pr.message>
                    </cfif>
                </cfloop>
            </cfif>
        </cfif>

    <!--- ── Unpublish a single published variant ───────────────────── --->
    <cfelseif action EQ "unpublish" AND isNumeric(form.imageVariantTypeID ?: "") AND val(form.imageVariantTypeID) GT 0>
        <cfif NOT request.hasPermission("media.unpublish")>
            <cfset actionMessage = "You do not have permission to unpublish media.">
            <cfset actionMessageClass = "alert-danger">
        <cfelse>
            <cfset publishingService = createObject("component", "cfc.PublishingService").init()>
            <cfset result = publishingService.unpublishVariant(
                userID             = userID,
                imageVariantTypeID = val(form.imageVariantTypeID),
                userImageSourceID  = sourceID
            )>
            <cfset actionMessage      = result.message>
            <cfset actionMessageClass = result.success ? "alert-success" : "alert-danger">
        </cfif>

    </cfif>
</cfif>

<!--- ── Load data after any POST so the matrix reflects current state ─────── --->
<cfset sourceRecord = sourceService.getSourceByID(sourceID)>
<cfif structIsEmpty(sourceRecord) OR val(sourceRecord.USERID ?: 0) NEQ userID>
    <cflocation url="#request.webRoot#/admin/user-media/sources.cfm?userid=#userID#" addtoken="false">
</cfif>
<cfset sourceFilename = listLast(sourceRecord.DROPBOXPATH ?: "", "/\")>

<cfset variantMatrix = variantService.getVariantMatrix(userID, sourceID)>

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
        <li class='breadcrumb-item'><a href='/admin/user-media/sources.cfm?userid=#userID#'>Image Sources</a></li>
        <li class='breadcrumb-item active' aria-current='page'>Image Variants</li>
    </ol>
</nav>
<h1 class='mb-1'>Image Variants</h1>
<p class='text-muted mb-4'>
    Assign variant types to this source, then generate and publish.
    Each source image gets its own independent set of variants.
</p>
">

<!--- ── User context card ────────────────────────────────────────────────── --->
<cfset content &= "
<div class='card mb-4'>
    <div class='card-header fw-semibold'><i class='bi bi-person-circle me-1'></i> User &amp; Source</div>
    <div class='card-body'>
        <dl class='row mb-0'>
            <dt class='col-sm-2'>Name</dt>
            <dd class='col-sm-10'>#displayName#</dd>
            <dt class='col-sm-2'>Email</dt>
            <dd class='col-sm-10'>#displayEmail#</dd>
            <dt class='col-sm-2'>User ID</dt>
            <dd class='col-sm-10'>#userID#</dd>
            <dt class='col-sm-2'>Source</dt>
            <dd class='col-sm-10'>
                <span class='badge bg-primary me-1'>#encodeForHTML(sourceRecord.SOURCEKEY ?: "")#</span>
                <code>#encodeForHTML(sourceFilename)#</code>
                <span class='text-muted small ms-2'>(Source ID: #sourceID#)</span>
            </dd>
        </dl>
    </div>
</div>
">

<!--- ── Action feedback ──────────────────────────────────────────────────── --->
<cfif len(actionMessage)>
    <cfset content &= "
    <div class='alert #actionMessageClass# alert-dismissible fade show' role='alert'>
        #encodeForHTML(actionMessage)#
        <button type='button' class='btn-close' data-bs-dismiss='alert' aria-label='Close'></button>
    </div>
    ">
</cfif>

<!--- ── Variant matrix ───────────────────────────────────────────────────── --->
<cfset content &= "
<div class='card mb-4'>
    <div class='card-header d-flex justify-content-between align-items-center'>
        <span class='fw-semibold'><i class='bi bi-grid-3x3-gap me-1'></i> Variant Matrix</span>
        <div class='d-flex align-items-center gap-2'>
">

<cfif request.hasPermission("settings.media_config.manage")>
    <cfset content &= "
            <a href='/admin/settings/media-config/variant-types.cfm' class='btn btn-sm btn-outline-secondary'>
                <i class='bi bi-sliders me-1'></i> Types
            </a>
    ">
</cfif>

<cfset content &= "
            <span class='badge bg-secondary'>#arrayLen(variantMatrix)# type(s)</span>
        </div>
    </div>
">

<cfif arrayLen(variantMatrix) GT 0>

    <cfset content &= "
    <div class='table-responsive'>
        <table class='table table-hover align-middle mb-0'>
            <thead class='table-dark'>
                <tr>
                    <th>Variant</th>
                    <th>Audience</th>
                    <th class='text-center'>Status</th>
                    <th>Last Generated</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
    ">

    <cfloop from="1" to="#arrayLen(variantMatrix)#" index="i">
        <cfset v = variantMatrix[i]>

        <!--- ── Status badge ────────────────────────────────────────── --->
        <cfset statusClass = trim(v.DISPLAYSTATUSCLASS ?: "")>
        <cfset statusClassLower = lCase(statusClass)>
        <cfif !len(statusClass)>
            <cfset statusClass = "text-bg-secondary">
            <cfset statusClassLower = "text-bg-secondary">
        </cfif>
        <!--- Guard against classes with no background utility. --->
        <cfif !find("bg-", statusClassLower) AND !find("text-bg-", statusClassLower)>
            <cfset statusClass = "text-bg-secondary">
            <cfset statusClassLower = "text-bg-secondary">
        </cfif>
        <!--- Ensure readable text on light badge backgrounds. --->
        <cfif (find("bg-light", statusClassLower) OR find("bg-warning", statusClassLower) OR find("bg-info", statusClassLower) OR find("bg-secondary", statusClassLower))
            AND !find("text-dark", statusClassLower)
            AND !find("text-body", statusClassLower)>
            <cfset statusClass &= " text-dark">
        </cfif>
        <!--- Our theme uses white as --bs-secondary, so add a border for contrast. --->
        <cfif find("bg-secondary", statusClassLower) AND !find("border", statusClassLower)>
            <cfset statusClass &= " border border-secondary-subtle">
        </cfif>
        <cfset statusBadge = "<span class='badge #encodeForHTML(statusClass)#'><i class='bi bi-circle-fill me-1'></i>#encodeForHTML(v.DISPLAYSTATUSLABEL ?: "Unknown")#</span>">

        <!--- ── Last generated display ──────────────────────────────── --->
        <cfset generatedDisplay = "">
        <cfif len(v.GENERATEDAT)>
            <cfset generatedDisplay = dateTimeFormat(v.GENERATEDAT, "mmm d, yyyy h:nn tt")>
        <cfelse>
            <cfset generatedDisplay = "<span class='text-muted'>Never</span>">
        </cfif>

        <!--- ── Dimensions display ───────────────────────────────────── --->
        <cfset dimDisplay = "">
        <cfset hasWidthPx = isNumeric(v.WIDTHPX ?: "") AND val(v.WIDTHPX) GT 0>
        <cfset hasHeightPx = isNumeric(v.HEIGHTPX ?: "") AND val(v.HEIGHTPX) GT 0>
        <cfif hasWidthPx AND hasHeightPx>
            <cfset dimDisplay = " <small class='text-muted'>(#val(v.WIDTHPX)# &times; #val(v.HEIGHTPX)#)</small>">
        <cfelseif hasWidthPx>
            <cfset dimDisplay = " <small class='text-muted'>(#val(v.WIDTHPX)# &times; auto)</small>">
        <cfelseif hasHeightPx>
            <cfset dimDisplay = " <small class='text-muted'>(auto &times; #val(v.HEIGHTPX)#)</small>">
        </cfif>

        <cfset content &= "
            <tr>
                <td>
                    <span class='fw-semibold'>#encodeForHTML(v.DESCRIPTION)#</span>#dimDisplay#
                    <div class='text-muted small font-monospace'>#encodeForHTML(v.CODE)#</div>
                </td>
                <td>#encodeForHTML(v.AUDIENCE)#</td>
                <td class='text-center'>#statusBadge#">

        <!--- Show error message beneath badge when status is error --->
        <cfif v.STATUS EQ "error" AND len(v.ERRORMESSAGE)>
            <cfset content &= "
                    <div class='text-danger small mt-1'>#encodeForHTML(left(v.ERRORMESSAGE, 200))#</div>">
        </cfif>

        <cfset content &= "
                </td>
                <td class='small'>#generatedDisplay#</td>
                <td>
        ">

        <cfif len(v.PREVIEWURL ?: "")>
            <cfset content &= "
                    <button
                        type='button'
                        class='btn btn-sm btn-outline-dark me-1 js-variant-preview'
                        data-bs-toggle='modal'
                        data-bs-target='##variantPreviewModal'
                        data-preview-url='#encodeForHTMLAttribute(v.PREVIEWURL ?: "")#'
                        data-variant-name='#encodeForHTMLAttribute(v.DESCRIPTION ?: "")#'
                        data-variant-code='#encodeForHTMLAttribute(v.CODE ?: "")#'
                        data-variant-status='#encodeForHTMLAttribute(v.DISPLAYSTATUSLABEL ?: "")#'
                        data-preview-source='#encodeForHTMLAttribute(v.PREVIEWSOURCE ?: "")#'
                    >
                        <i class='bi bi-eye me-1'></i> View
                    </button>
            ">
        </cfif>

        <cfif v.DISPLAYSTATUS EQ "not_assigned">
            <!--- Not yet assigned — show Assign button --->
            <cfset content &= "
                    <form method='post' class='d-inline'>
                        <input type='hidden' name='action' value='assign'>
                        <input type='hidden' name='imageVariantTypeID' value='#encodeForHTMLAttribute(v.IMAGEVARIANTTYPEID)#'>
                        <button type='submit' class='btn btn-sm btn-outline-primary'>
                            <i class='bi bi-plus-circle me-1'></i> Assign
                        </button>
                    </form>
            ">
        <cfelse>
            <!--- Already assigned — show Generate/Crop/Transfer link --->
            <cfset vtMode = lCase(trim(v.MODE ?: 'resize_only'))>
            <cfset vtAllowCrop   = (vtMode EQ 'crop_resize')>
            <cfset vtAllowResize = (vtMode NEQ 'passthrough')>

            <cfif vtAllowCrop>
                <cfset content &= "
                    <a href='/admin/user-media/crop.cfm?userid=#userID#&sourceid=#sourceID#&imageVariantTypeID=#encodeForHTMLAttribute(v.IMAGEVARIANTTYPEID)#'
                       class='btn btn-sm btn-success'>
                        <i class='bi bi-crop'></i> Crop &amp; Generate
                    </a>
                ">
            <cfelse>
                <cfset content &= "
                    <a href='/admin/user-media/resize.cfm?userid=#userID#&sourceid=#sourceID#&imageVariantTypeID=#encodeForHTMLAttribute(v.IMAGEVARIANTTYPEID)#'
                       class='btn btn-sm btn-success'>
                        <i class='bi bi-gear'></i> #vtAllowResize ? 'Resize' : 'Transfer'#
                    </a>
                ">
            </cfif>

            <cfif NOT (isBoolean(v.HASPUBLISHEDIMAGE ?: false) AND v.HASPUBLISHEDIMAGE)>
                <cfset content &= "
                    <form method='post' class='d-inline ms-1'>
                        <input type='hidden' name='action' value='unassign'>
                        <input type='hidden' name='imageVariantTypeID' value='#encodeForHTMLAttribute(v.IMAGEVARIANTTYPEID)#'>
                        <button type='submit' class='btn btn-sm btn-outline-danger'
                                onclick='return confirm(\'Remove assignment for #encodeForJavaScript(v.DESCRIPTION ?: "this variant")#?\');'>
                            <i class='bi bi-x-circle me-1'></i> Remove
                        </button>
                    </form>
                ">
            <cfelse>
                <cfset content &= "
                    <span class='badge text-bg-success ms-1' title='Published variants cannot be removed'>Published</span>
                ">
            </cfif>

            <cfif (isBoolean(v.HASPUBLISHEDIMAGE ?: false) AND v.HASPUBLISHEDIMAGE)>
                <cfif request.hasPermission("media.unpublish")>
                    <cfset content &= "
                        <form method='post' class='d-inline ms-1'>
                            <input type='hidden' name='action' value='unpublish'>
                            <input type='hidden' name='imageVariantTypeID' value='#encodeForHTMLAttribute(v.IMAGEVARIANTTYPEID)#'>
                            <button type='submit' class='btn btn-sm btn-outline-danger'
                                    onclick='return confirm(\'Unpublish #encodeForJavaScript(v.DESCRIPTION ?: "this variant")#? This removes the published file and DB record.\');'>
                                <i class='bi bi-trash me-1'></i> Unpublish
                            </button>
                        </form>
                    ">
                <cfelse>
                    <cfset content &= "
                        <span class='badge text-bg-success ms-1'>Published</span>
                    ">
                </cfif>
            </cfif>
        </cfif>

        <cfset content &= "
                </td>
            </tr>
        ">
    </cfloop>

    <cfset content &= "
            </tbody>
        </table>
    </div>
    ">

<cfelse>
    <cfset content &= "
    <div class='card-body'>
        <p class='text-muted mb-0'>
            <i class='bi bi-info-circle me-1'></i>
            No active variant types are defined. Ask an administrator to seed the
            <code>ImageVariantTypes</code> table.
        </p>
    </div>
    ">
</cfif>

<cfset content &= "
</div>
">

<cfset content &= "
<div class='modal fade' id='variantPreviewModal' tabindex='-1' aria-labelledby='variantPreviewModalLabel' aria-hidden='true'>
    <div class='modal-dialog modal-lg modal-dialog-centered'>
        <div class='modal-content'>
            <div class='modal-header'>
                <h5 class='modal-title' id='variantPreviewModalLabel'>Variant Preview</h5>
                <button type='button' class='btn-close' data-bs-dismiss='modal' aria-label='Close'></button>
            </div>
            <div class='modal-body text-center'>
                <div class='small text-muted mb-3' id='variantPreviewMeta'></div>
                <img
                    id='variantPreviewImage'
                    src=''
                    alt='Variant preview'
                    class='img-fluid rounded border d-none media-modal-preview-image'
                >
                <div id='variantPreviewEmpty' class='text-muted py-5 d-none'>Preview not available.</div>
            </div>
        </div>
    </div>
</div>
">

<cfsavecontent variable="pageScripts">
<script>
document.addEventListener('DOMContentLoaded', function () {
    var previewModal = document.getElementById('variantPreviewModal');
    if (!previewModal) {
        return;
    }

    previewModal.addEventListener('show.bs.modal', function (event) {
        var trigger = event.relatedTarget;
        var previewImage = document.getElementById('variantPreviewImage');
        var previewEmpty = document.getElementById('variantPreviewEmpty');
        var previewMeta = document.getElementById('variantPreviewMeta');
        var previewTitle = document.getElementById('variantPreviewModalLabel');

        if (!trigger || !previewImage || !previewEmpty || !previewMeta || !previewTitle) {
            return;
        }

        var previewUrl = trigger.getAttribute('data-preview-url') || '';
        var variantName = trigger.getAttribute('data-variant-name') || 'Variant Preview';
        var variantCode = trigger.getAttribute('data-variant-code') || '';
        var variantStatus = trigger.getAttribute('data-variant-status') || '';
        var previewSource = trigger.getAttribute('data-preview-source') || '';

        previewTitle.textContent = variantName;
        previewMeta.textContent = variantCode
            ? (variantCode + (variantStatus ? ' | ' + variantStatus : '') + (previewSource ? ' | ' + previewSource : ''))
            : (variantStatus + (previewSource ? ' | ' + previewSource : ''));

        if (previewUrl) {
            previewImage.src = previewUrl;
            previewImage.alt = variantName;
            previewImage.classList.remove('d-none');
            previewEmpty.classList.add('d-none');
        } else {
            previewImage.src = '';
            previewImage.classList.add('d-none');
            previewEmpty.classList.remove('d-none');
        }
    });

    previewModal.addEventListener('hidden.bs.modal', function () {
        var previewImage = document.getElementById('variantPreviewImage');
        if (previewImage) {
            previewImage.src = '';
        }
    });
});
</script>
</cfsavecontent>

<!--- ── Publish All button ───────────────────────────────────────────────── --->
<!---
     Show the Publish button only when at least one variant is "current"
     and has a temp file (non-empty LOCALPATH).  Publishing copies each
     current temp variant to /_published_images/, upserts UserImages, and
     deletes the temp file.
--->
<cfset publishableCount = 0>
<cfloop from="1" to="#arrayLen(variantMatrix)#" index="px">
    <cfif variantMatrix[px].STATUS EQ "current" AND len(variantMatrix[px].LOCALPATH)>
        <cfset publishableCount++>
    </cfif>
</cfloop>

<cfif publishableCount GT 0 AND request.hasPermission("media.publish")>
    <cfset content &= "
    <div class='card mb-4 border-primary'>
        <div class='card-body d-flex justify-content-between align-items-center'>
            <div>
                <i class='bi bi-upload me-1 text-primary'></i>
                <strong>#publishableCount#</strong> variant(s) ready to publish.
                Publishing copies images to the published folder and records them in the directory.
            </div>
            <form method='post' class='d-inline'>
                <input type='hidden' name='action' value='publishAll'>
                <button type='submit' class='btn btn-primary'>
                    <i class='bi bi-cloud-arrow-up me-1'></i> Publish All
                </button>
            </form>
        </div>
    </div>
    ">
</cfif>



<cfinclude template="/admin/layout.cfm">
