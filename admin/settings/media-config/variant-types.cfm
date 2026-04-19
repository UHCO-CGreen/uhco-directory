<!--- ── Authorization: settings.media_config.manage ─────────────────────── --->
<cfif NOT request.hasPermission("settings.media_config.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<!--- ── Services / DAO ───────────────────────────────────────────────────── --->
<cfset variantDAO  = createObject("component", "dao.UserImageVariantDAO").init()>
<cfset imagesDAO   = createObject("component", "dao.images_DAO").init()>

<!--- Resolve absolute paths for file cleanup.
     basePath = .../admin/settings/media-config/  so ..\..\..\ = site root --->
<cfset basePath  = getDirectoryFromPath(getCurrentTemplatePath())>
<cfset jFile     = createObject("java", "java.io.File")>
<cfset siteRoot  = jFile.init(basePath & "..\..\..").getCanonicalPath()>
<cfset publishedDirAbs = siteRoot & "\_published_images\">
<cfset variantDirAbs   = siteRoot & "\_temp_variants\">

<!--- ── Handle POST actions ──────────────────────────────────────────────── --->
<cfset actionMessage      = "">
<cfset actionMessageClass = "alert-success">

<cfif cgi.request_method EQ "POST">
    <cfset action = trim(form.action ?: "")>

    <!--- ── Save (insert or update) ──────────────────────────────────── --->
    <cfif action EQ "save">
        <cfset editID = val(form.imageVariantTypeID ?: 0)>
        <cfset code   = trim(form.code ?: "")>

        <cfif NOT len(code)>
            <cfset actionMessage      = "Code is required.">
            <cfset actionMessageClass = "alert-danger">
        <cfelse>
            <cftry>
                <cfif editID GT 0>
                    <cfset variantDAO.updateVariantType(
                        imageVariantTypeID = editID,
                        code            = code,
                        description     = trim(form.description ?: ""),
                        audience        = trim(form.audience ?: ""),
                        outputFormat    = trim(form.outputFormat ?: "jpg"),
                        widthPx         = val(form.widthPx ?: 0),
                        heightPx        = val(form.heightPx ?: 0),
                        allowManualCrop = structKeyExists(form, "allowManualCrop"),
                        allowResize     = structKeyExists(form, "allowResize"),
                        isActive        = structKeyExists(form, "isActive")
                    )>
                    <cfset actionMessage = "Variant type '#encodeForHTML(code)#' updated.">
                <cfelse>
                    <cfset newID = variantDAO.insertVariantType(
                        code            = code,
                        description     = trim(form.description ?: ""),
                        audience        = trim(form.audience ?: ""),
                        outputFormat    = trim(form.outputFormat ?: "jpg"),
                        widthPx         = val(form.widthPx ?: 0),
                        heightPx        = val(form.heightPx ?: 0),
                        allowManualCrop = structKeyExists(form, "allowManualCrop"),
                        allowResize     = structKeyExists(form, "allowResize"),
                        isActive        = structKeyExists(form, "isActive")
                    )>
                    <cfset actionMessage = "Variant type '#encodeForHTML(code)#' created (ID: #newID#).">
                </cfif>
            <cfcatch type="any">
                <cfset actionMessage      = "Error saving: #encodeForHTML(cfcatch.message)#">
                <cfset actionMessageClass = "alert-danger">
            </cfcatch>
            </cftry>
        </cfif>

    <!--- ── Delete (cascade: files + DB) ─────────────────────────────── --->
    <cfelseif action EQ "delete">
        <cfset deleteID = val(form.imageVariantTypeID ?: 0)>

        <cfif deleteID GT 0>
            <cftry>
                <!--- 1. Look up the variant type to get its Code --->
                <cfset vt = variantDAO.getVariantTypeByID(deleteID)>

                <cfif NOT structIsEmpty(vt)>
                    <cfset vtCode = vt.CODE ?: "">

                    <!--- 2. Delete temp variant files --->
                    <cfset userVariants = variantDAO.getVariantsByTypeID(deleteID)>
                    <cfloop from="1" to="#arrayLen(userVariants)#" index="dv">
                        <cfset lp = userVariants[dv].LOCALPATH ?: "">
                        <cfif len(lp)>
                            <cfset tempFile = variantDirAbs & listLast(lp, "/\")>
                            <cftry>
                                <cfif fileExists(tempFile)><cfset fileDelete(tempFile)></cfif>
                            <cfcatch></cfcatch>
                            </cftry>
                        </cfif>
                    </cfloop>

                    <!--- 3. Delete published image files --->
                    <cfset publishedImages = imagesDAO.getImagesByVariantCode(vtCode)>
                    <cfloop from="1" to="#arrayLen(publishedImages)#" index="dp">
                        <cfset pUrl = publishedImages[dp].IMAGEURL ?: "">
                        <cfif len(pUrl)>
                            <cfset pFilename = listLast(pUrl, "/\")>
                            <cfset pFile     = publishedDirAbs & pFilename>
                            <cftry>
                                <cfif fileExists(pFile)><cfset fileDelete(pFile)></cfif>
                            <cfcatch></cfcatch>
                            </cftry>
                        </cfif>
                    </cfloop>

                    <!--- 4. Delete DB records: published images, user variants, then variant type --->
                    <cfset imagesDAO.deleteByVariantCode(vtCode)>
                    <cfset variantDAO.deleteVariantsByTypeID(deleteID)>
                    <cfset variantDAO.deleteVariantType(deleteID)>

                    <cfset actionMessage = "Variant type '#encodeForHTML(vtCode)#' and all associated images deleted.">
                <cfelse>
                    <cfset actionMessage      = "Variant type not found.">
                    <cfset actionMessageClass = "alert-danger">
                </cfif>
            <cfcatch type="any">
                <cfset actionMessage      = "Error deleting: #encodeForHTML(cfcatch.message)#">
                <cfset actionMessageClass = "alert-danger">
            </cfcatch>
            </cftry>
        </cfif>
    </cfif>
</cfif>

<!--- ── Load data ────────────────────────────────────────────────────────── --->
<cfset allTypes = variantDAO.getVariantTypesAllAdmin()>

<!--- ── Determine if we're editing ───────────────────────────────────────── --->
<cfset editMode = false>
<cfset editType = {}>
<cfif structKeyExists(url, "edit") AND isNumeric(url.edit) AND val(url.edit) GT 0>
    <cfloop from="1" to="#arrayLen(allTypes)#" index="et">
        <cfif val(allTypes[et].IMAGEVARIANTTYPEID) EQ val(url.edit)>
            <cfset editType = allTypes[et]>
            <cfset editMode = true>
            <cfbreak>
        </cfif>
    </cfloop>
</cfif>

<!--- ═══════════════════════════════════════════════════════════════════════
     Page content
     ═══════════════════════════════════════════════════════════════════════ --->
<cfset content = "
<nav aria-label='breadcrumb' class='mb-3'>
    <ol class='breadcrumb'>
        <li class='breadcrumb-item'><a href='/admin/settings/'>Settings</a></li>
        <li class='breadcrumb-item'><a href='/admin/settings/media-config/'>User Media Config</a></li>
        <li class='breadcrumb-item active' aria-current='page'>Variant Types</li>
    </ol>
</nav>

<div class='d-flex justify-content-between align-items-center mb-3'>
    <div>
        <h1 class='mb-1'>Variant Types</h1>
        <p class='text-muted mb-0'>Define the image variant types available for user media processing.</p>
    </div>
</div>
">

<!--- ── Feedback ─────────────────────────────────────────────────────────── --->
<cfif len(actionMessage)>
    <cfset content &= "
    <div class='alert #actionMessageClass# alert-dismissible fade show' role='alert'>
        #actionMessage#
        <button type='button' class='btn-close' data-bs-dismiss='alert' aria-label='Close'></button>
    </div>
    ">
</cfif>

<!--- ═══════════════════════════════════════════════════════════════════════
     Add / Edit Form
     ═══════════════════════════════════════════════════════════════════════ --->
<cfset content &= "
<div class='card mb-4'>
    <div class='card-header fw-semibold'>
        <i class='bi bi-#editMode ? 'pencil-square' : 'plus-circle'# me-1'></i>
        #editMode ? 'Edit' : 'New'# Variant Type
    </div>
    <div class='card-body'>
        <form method='post'>
            <input type='hidden' name='action' value='save'>
            <input type='hidden' name='imageVariantTypeID' value='#editMode ? val(editType.IMAGEVARIANTTYPEID) : 0#'>

            <div class='row g-3'>
                <div class='col-md-4'>
                    <label for='vtCode' class='form-label'>Code <span class='text-danger'>*</span></label>
                    <input type='text' class='form-control font-monospace' id='vtCode' name='code'
                           value='#encodeForHTMLAttribute(editMode ? (editType.CODE ?: "") : "")#'
                           required maxlength='50'
                           placeholder='e.g. web_profile'>
                    <div class='form-text'>Unique identifier. Use lowercase_snake_case.</div>
                </div>
                <div class='col-md-8'>
                    <label for='vtDescription' class='form-label'>Description</label>
                    <input type='text' class='form-control' id='vtDescription' name='description'
                           value='#encodeForHTMLAttribute(editMode ? (editType.DESCRIPTION ?: "") : "")#'
                           maxlength='255'
                           placeholder='e.g. Web Profile Image'>
                </div>
            </div>

            <div class='row g-3 mt-1'>
                <div class='col-md-3'>
                    <label for='vtAudience' class='form-label'>Audience</label>
                    <input type='text' class='form-control' id='vtAudience' name='audience'
                           value='#encodeForHTMLAttribute(editMode ? (editType.AUDIENCE ?: "") : "")#'
                           maxlength='50'
                           placeholder='e.g. web, kiosk, print'>
                </div>
                <div class='col-md-3'>
                    <label for='vtOutputFormat' class='form-label'>Output Format</label>
                    <select class='form-select' id='vtOutputFormat' name='outputFormat'>
                        <option value='jpg' #(editMode AND (editType.OUTPUTFORMAT ?: '') EQ 'jpg') ? 'selected' : ''#>JPG</option>
                        <option value='png' #(editMode AND (editType.OUTPUTFORMAT ?: '') EQ 'png') ? 'selected' : ''#>PNG</option>
                        <option value='webp' #(editMode AND (editType.OUTPUTFORMAT ?: '') EQ 'webp') ? 'selected' : ''#>WebP</option>
                    </select>
                </div>
                <div class='col-md-3'>
                    <label for='vtWidthPx' class='form-label'>Width (px)</label>
                    <input type='number' class='form-control' id='vtWidthPx' name='widthPx'
                           value='#editMode ? val(editType.WIDTHPX ?: 0) : ""#'
                           min='0' placeholder='0 = auto'>
                </div>
                <div class='col-md-3'>
                    <label for='vtHeightPx' class='form-label'>Height (px)</label>
                    <input type='number' class='form-control' id='vtHeightPx' name='heightPx'
                           value='#editMode ? val(editType.HEIGHTPX ?: 0) : ""#'
                           min='0' placeholder='0 = auto'>
                </div>
            </div>

            <div class='row g-3 mt-1'>
                <div class='col-md-3'>
                    <div class='form-check form-switch mt-4'>
                        <input class='form-check-input' type='checkbox' id='vtAllowManualCrop' name='allowManualCrop'
                               #(editMode AND isBoolean(editType.ALLOWMANUALCROP ?: false) AND editType.ALLOWMANUALCROP) ? 'checked' : (!editMode ? '' : '')#>
                        <label class='form-check-label' for='vtAllowManualCrop'>Allow Manual Crop</label>
                    </div>
                    <div class='form-text'>Enables the crop tool for this variant.</div>
                </div>
                <div class='col-md-3'>
                    <div class='form-check form-switch mt-4'>
                        <input class='form-check-input' type='checkbox' id='vtAllowResize' name='allowResize'
                               #(editMode AND isBoolean(editType.ALLOWRESIZE ?: true) AND editType.ALLOWRESIZE) ? 'checked' : (!editMode ? 'checked' : '')#>
                        <label class='form-check-label' for='vtAllowResize'>Allow Resize</label>
                    </div>
                    <div class='form-text'>Enables proportional resize. Off = pass-through.</div>
                </div>
                <div class='col-md-3'>
                    <div class='form-check form-switch mt-4'>
                        <input class='form-check-input' type='checkbox' id='vtIsActive' name='isActive'
                               #(editMode AND isBoolean(editType.ISACTIVE ?: true) AND editType.ISACTIVE) ? 'checked' : (!editMode ? 'checked' : '')#>
                        <label class='form-check-label' for='vtIsActive'>Active</label>
                    </div>
                    <div class='form-text'>Inactive types are hidden from users.</div>
                </div>
            </div>

            <div class='mt-4 d-flex gap-2'>
                <button type='submit' class='btn btn-primary'>
                    <i class='bi bi-check-lg me-1'></i> #editMode ? 'Update' : 'Create'#
                </button>
">

<cfif editMode>
    <cfset content &= "
                <a href='/admin/settings/media-config/variant-types.cfm' class='btn btn-outline-secondary'>Cancel</a>
    ">
</cfif>

<cfset content &= "
            </div>
        </form>
    </div>
</div>
">

<!--- ═══════════════════════════════════════════════════════════════════════
     Existing Variant Types Table
     ═══════════════════════════════════════════════════════════════════════ --->
<cfset content &= "
<div class='card mb-4'>
    <div class='card-header d-flex justify-content-between align-items-center'>
        <span class='fw-semibold'><i class='bi bi-grid-3x3-gap me-1'></i> All Variant Types</span>
        <span class='badge bg-secondary'>#arrayLen(allTypes)#</span>
    </div>
">

<cfif arrayLen(allTypes) GT 0>
    <cfset content &= "
    <div class='table-responsive'>
        <table class='table table-hover align-middle mb-0'>
            <thead class='table-dark'>
                <tr>
                    <th>Code</th>
                    <th>Description</th>
                    <th>Audience</th>
                    <th>Format</th>
                    <th class='text-center'>Dimensions</th>
                    <th class='text-center'>Crop</th>
                    <th class='text-center'>Resize</th>
                    <th class='text-center'>Active</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
    ">

    <cfloop from="1" to="#arrayLen(allTypes)#" index="i">
        <cfset vt = allTypes[i]>
        <cfset vtID    = val(vt.IMAGEVARIANTTYPEID)>
        <cfset vtW     = val(vt.WIDTHPX ?: 0)>
        <cfset vtH     = val(vt.HEIGHTPX ?: 0)>
        <cfset vtDims  = (vtW GT 0 ? vtW : "auto") & " &times; " & (vtH GT 0 ? vtH : "auto")>
        <cfset vtCrop  = isBoolean(vt.ALLOWMANUALCROP ?: false) AND vt.ALLOWMANUALCROP>
        <cfset vtResize = isBoolean(vt.ALLOWRESIZE ?: true) AND vt.ALLOWRESIZE>
        <cfset vtActive = isBoolean(vt.ISACTIVE ?: true) AND vt.ISACTIVE>
        <cfset rowClass = vtActive ? "" : "table-secondary">

        <cfset content &= "
            <tr class='#rowClass#'>
                <td class='font-monospace'>#encodeForHTML(vt.CODE ?: "")#</td>
                <td>#encodeForHTML(vt.DESCRIPTION ?: "")#</td>
                <td>#encodeForHTML(vt.AUDIENCE ?: "")#</td>
                <td class='text-uppercase small'>#encodeForHTML(vt.OUTPUTFORMAT ?: "")#</td>
                <td class='text-center small'>#vtDims#</td>
                <td class='text-center'>#vtCrop ? '<i class=""bi bi-check-circle-fill text-success""></i>' : '<i class=""bi bi-dash text-muted""></i>'#</td>
                <td class='text-center'>#vtResize ? '<i class=""bi bi-check-circle-fill text-success""></i>' : '<i class=""bi bi-dash text-muted""></i>'#</td>
                <td class='text-center'>#vtActive ? '<span class=""badge bg-success"">Active</span>' : '<span class=""badge bg-secondary"">Inactive</span>'#</td>
                <td>
                    <div class='d-flex gap-1'>
                        <a href='/admin/settings/media-config/variant-types.cfm?edit=#vtID#' class='btn btn-sm btn-outline-primary'>
                            <i class='bi bi-pencil'></i>
                        </a>
                        <button type='button' class='btn btn-sm btn-outline-danger'
                                data-bs-toggle='modal'
                                data-bs-target='##deleteModal'
                                data-vt-id='#vtID#'
                                data-vt-code='#encodeForHTMLAttribute(vt.CODE ?: "")#'
                                data-vt-desc='#encodeForHTMLAttribute(vt.DESCRIPTION ?: "")#'>
                            <i class='bi bi-trash'></i>
                        </button>
                    </div>
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
        <p class='text-muted mb-0'><i class='bi bi-info-circle me-1'></i> No variant types defined yet.</p>
    </div>
    ">
</cfif>

<cfset content &= "
</div>
">

<!--- ═══════════════════════════════════════════════════════════════════════
     Processing Modes Reference
     ═══════════════════════════════════════════════════════════════════════ --->
<cfset content &= "
<div class='card mb-4'>
    <div class='card-header fw-semibold'><i class='bi bi-info-circle me-1'></i> Processing Modes</div>
    <div class='card-body'>
        <table class='table table-sm mb-0'>
            <thead>
                <tr><th>Crop</th><th>Resize</th><th>Behavior</th></tr>
            </thead>
            <tbody>
                <tr>
                    <td><i class='bi bi-check-circle-fill text-success'></i></td>
                    <td><i class='bi bi-check-circle-fill text-success'></i></td>
                    <td><strong>Crop &amp; Resize</strong> &mdash; Admin selects crop area, image is cropped then resized to target dimensions.</td>
                </tr>
                <tr>
                    <td><i class='bi bi-dash text-muted'></i></td>
                    <td><i class='bi bi-check-circle-fill text-success'></i></td>
                    <td><strong>Resize Only</strong> &mdash; Source image is proportionally resized to target width/height. No cropping.</td>
                </tr>
                <tr>
                    <td><i class='bi bi-dash text-muted'></i></td>
                    <td><i class='bi bi-dash text-muted'></i></td>
                    <td><strong>Pass-through</strong> &mdash; Source image is copied as-is to publishing. No resize, no crop.</td>
                </tr>
            </tbody>
        </table>
    </div>
</div>
">

<!--- ═══════════════════════════════════════════════════════════════════════
     Delete Confirmation Modal
     ═══════════════════════════════════════════════════════════════════════ --->
<cfset content &= "
<div class='modal fade' id='deleteModal' tabindex='-1' aria-labelledby='deleteModalLabel' aria-hidden='true'>
    <div class='modal-dialog'>
        <div class='modal-content'>
            <div class='modal-header bg-danger text-white'>
                <h5 class='modal-title' id='deleteModalLabel'>
                    <i class='bi bi-exclamation-triangle me-1'></i> Delete Variant Type
                </h5>
                <button type='button' class='btn-close btn-close-white' data-bs-dismiss='modal' aria-label='Close'></button>
            </div>
            <div class='modal-body'>
                <p>Are you sure you want to delete this variant type?</p>
                <div class='alert alert-warning'>
                    <strong id='deleteVtCode'></strong>
                    <span class='text-muted ms-2' id='deleteVtDesc'></span>
                </div>
                <p class='text-danger mb-0'>
                    <i class='bi bi-exclamation-triangle me-1'></i>
                    <strong>This will permanently delete:</strong>
                </p>
                <ul class='text-danger mb-0'>
                    <li>All generated temp variant files for this type</li>
                    <li>All published images for this type</li>
                    <li>All user variant assignment records</li>
                    <li>The variant type definition itself</li>
                </ul>
            </div>
            <div class='modal-footer'>
                <button type='button' class='btn btn-secondary' data-bs-dismiss='modal'>Cancel</button>
                <form method='post' class='d-inline'>
                    <input type='hidden' name='action' value='delete'>
                    <input type='hidden' name='imageVariantTypeID' id='deleteVtID' value=''>
                    <button type='submit' class='btn btn-danger'>
                        <i class='bi bi-trash me-1'></i> Delete Permanently
                    </button>
                </form>
            </div>
        </div>
    </div>
</div>

<script>
(function () {
    'use strict';
    var deleteModal = document.getElementById('deleteModal');
    if (deleteModal) {
        deleteModal.addEventListener('show.bs.modal', function (event) {
            var btn = event.relatedTarget;
            document.getElementById('deleteVtID').value        = btn.getAttribute('data-vt-id')   || '';
            document.getElementById('deleteVtCode').textContent = btn.getAttribute('data-vt-code') || '';
            document.getElementById('deleteVtDesc').textContent = btn.getAttribute('data-vt-desc') || '';
        });
    }
}());
</script>
">

<cfinclude template="/admin/layout.cfm">
