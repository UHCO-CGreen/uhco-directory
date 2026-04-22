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
        <cfset submittedMode = "resize_only">
        <cfif structKeyExists(form, "vtMode")>
            <cfset submittedMode = lCase(trim(form.vtMode))>
        </cfif>
        <cfif NOT listFindNoCase("crop_resize,resize_only,passthrough", submittedMode)>
            <cfset submittedMode = "resize_only">
        </cfif>

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
                        mode            = submittedMode,
                        outputFormat    = trim(form.outputFormat ?: "jpg"),
                        widthPx         = val(form.widthPx ?: 0),
                        heightPx        = val(form.heightPx ?: 0),
                        isActive        = structKeyExists(form, "isActive")
                    )>
                    <cfset actionMessage = "Variant type '#encodeForHTML(code)#' updated.">
                <cfelse>
                    <cfset newID = variantDAO.insertVariantType(
                        code            = code,
                        description     = trim(form.description ?: ""),
                        audience        = trim(form.audience ?: ""),
                        mode            = submittedMode,
                        outputFormat    = trim(form.outputFormat ?: "jpg"),
                        widthPx         = val(form.widthPx ?: 0),
                        heightPx        = val(form.heightPx ?: 0),
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
<div class='settings-page settings-variant-types-page'>
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
<cfset editMode_Current = "">
<cfif editMode>
    <cfif structKeyExists(editType, "MODE") AND len(trim(editType["MODE"]))>
        <cfset editMode_Current = lCase(trim(editType["MODE"]))>
    <cfelse>
        <cfset editMode_Current = "resize_only">
    </cfif>
    <cfif NOT listFindNoCase("crop_resize,resize_only,passthrough", editMode_Current)>
        <cfset editMode_Current = "resize_only">
    </cfif>
</cfif>

<cfset content &= "
<div class='card mb-4 settings-shell'>
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
                    <label for='vtMode' class='form-label'>Mode <span class='text-danger'>*</span></label>
                    <select class='form-select' id='vtMode' name='vtMode' required>
                        <option value='' #(NOT editMode OR editMode_Current EQ "") ? 'selected' : ''#>— select mode —</option>
                        <option value='crop_resize' #(editMode_Current EQ "crop_resize") ? 'selected' : ''#>Crop & Resize</option>
                        <option value='resize_only' #(editMode_Current EQ "resize_only") ? 'selected' : ''#>Resize Only</option>
                        <option value='passthrough' #(editMode_Current EQ "passthrough") ? 'selected' : ''#>Pass-through (Format-Independent)</option>
                    </select>
                    <div class='form-text'>Processing mode determines which fields are required.</div>
                </div>
            </div>

            <div id='dimensionsControls' class='row g-3 mt-1' style='display: none;'>
                <div class='col-md-4'>
                    <label for='vtOutputFormat' class='form-label'>Output Format</label>
                    <select class='form-select' id='vtOutputFormat' name='outputFormat'>
                        <option value='jpg' #(editMode AND (editType.OUTPUTFORMAT ?: '') EQ 'jpg') ? 'selected' : ''#>JPG</option>
                        <option value='png' #(editMode AND (editType.OUTPUTFORMAT ?: '') EQ 'png') ? 'selected' : ''#>PNG</option>
                        <option value='webp' #(editMode AND (editType.OUTPUTFORMAT ?: '') EQ 'webp') ? 'selected' : ''#>WebP</option>
                    </select>
                    <div class='form-text text-muted small'>Output format for resized/cropped variants.</div>
                </div>
                <div class='col-md-4'>
                    <label for='vtWidthPx' class='form-label'>Width (px)</label>
                    <input type='number' class='form-control' id='vtWidthPx' name='widthPx'
                           value='#editMode ? val(editType.WIDTHPX ?: 0) : ""#'
                           min='0' placeholder='0 = auto'>
                    <div class='form-text text-muted small'>0 or leave blank for auto-fit.</div>
                </div>
                <div class='col-md-4'>
                    <label for='vtHeightPx' class='form-label'>Height (px)</label>
                    <input type='number' class='form-control' id='vtHeightPx' name='heightPx'
                           value='#editMode ? val(editType.HEIGHTPX ?: 0) : ""#'
                           min='0' placeholder='0 = auto'>
                    <div class='form-text text-muted small'>0 or leave blank for auto-fit.</div>
                </div>
            </div>

            <div id='passthroughInfo' class='alert alert-info mt-3' style='display: none;'>
                <i class='bi bi-info-circle me-1'></i>
                <strong>Pass-through Mode:</strong> Format and dimensions are not used. Source images (PNG, JPG, or WebP) are copied as-is without any processing.
            </div>

            <div class='row g-3 mt-1'>
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
<div class='card mb-4 settings-shell settings-summary-card'>
    <div class='card-header d-flex justify-content-between align-items-center'>
        <span class='fw-semibold'><i class='bi bi-grid-3x3-gap me-1'></i> All Variant Types</span>
        <span class='badge settings-badge-count'>#arrayLen(allTypes)#</span>
    </div>
">

<cfif arrayLen(allTypes) GT 0>
    <cfset content &= "
    <div class='table-responsive'>
        <table class='table table-hover align-middle mb-0 settings-table'>
            <thead>
                <tr>
                    <th>Code</th>
                    <th>Description</th>
                    <th>Audience</th>
                    <th class='text-center'>Dimensions</th>
                    <th>Mode</th>
                    <th>Format</th>
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
        <cfset vtModeKey = "resize_only">
        <cfif structKeyExists(vt, "MODE")>
            <cfset vtModeKey = lCase(trim(vt["MODE"]))>
        </cfif>
        <cfif NOT listFindNoCase("crop_resize,resize_only,passthrough", vtModeKey)>
            <cfset vtModeKey = "resize_only">
        </cfif>
        <cfset vtActive = isBoolean(vt.ISACTIVE ?: true) AND vt.ISACTIVE>
        <cfset rowClass = vtActive ? "" : "table-secondary">
        <cfset vtMode = vtModeKey EQ "crop_resize" ? "Crop & Resize" : (vtModeKey EQ "resize_only" ? "Resize Only" : "Pass-through")>

        <cfset content &= "
            <tr class='#rowClass#'>
                <td class='font-monospace'>#encodeForHTML(vt.CODE ?: "")#</td>
                <td>#encodeForHTML(vt.DESCRIPTION ?: "")#</td>
                <td>#encodeForHTML(vt.AUDIENCE ?: "")#</td>
                <td class='text-center small'>#vtDims#</td>
                <td><span class='badge bg-info text-dark'>#vtMode#</span></td>
                <td class='text-uppercase small'>#(vtMode EQ "Pass-through" ? "Any" : encodeForHTML(vt.OUTPUTFORMAT ?: ""))#</td>
                <td class='text-center'>#vtActive ? '<span class="badge settings-badge-active">Active</span>' : '<span class="badge bg-secondary text-dark">Inactive</span>'#</td>
                <td>
                    <div class='settings-action-group'>
                        <a href='/admin/settings/media-config/variant-types.cfm?edit=#vtID#' class='btn btn-sm btn-info users-list-action-button users-list-action-button-edit' title='Edit Variant Type' data-bs-toggle='tooltip' data-bs-title='Edit Variant Type' aria-label='Edit Variant Type'>
                            <i class='bi bi-pencil-square'></i>
                        </a>
                        <button type='button' class='btn btn-sm btn-danger users-list-action-button users-list-action-button-delete'
                                title='Delete Variant Type'
                                data-bs-toggle='tooltip'
                                data-bs-title='Delete Variant Type'
                                aria-label='Delete Variant Type'
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
<div class='card mb-4 settings-shell settings-reference-card'>
    <div class='card-header fw-semibold'><i class='bi bi-info-circle me-1'></i> Processing Modes</div>
    <div class='card-body'>
        <table class='table table-sm mb-3'>
            <thead>
                <tr><th>Mode</th><th>Behavior</th><th>Source Formats</th></tr>
            </thead>
            <tbody>
                <tr>
                    <td><span class='badge bg-info text-dark'>Crop & Resize</span></td>
                    <td>Admin selects crop area, image is cropped then resized to target dimensions. Output format specified.</td>
                    <td>JPG, PNG</td>
                </tr>
                <tr>
                    <td><span class='badge bg-info text-dark'>Resize Only</span></td>
                    <td>Source image is proportionally resized to target width/height with no cropping. Output format specified.</td>
                    <td>JPG, PNG</td>
                </tr>
                <tr>
                    <td><span class='badge bg-info text-dark'>Pass-through</span></td>
                    <td><strong>Format-independent:</strong> Source image is copied as-is to publishing without resizing or cropping. Output format is preserved from source (PNG stays PNG, JPG stays JPG, WebP stays WebP). No format conversion, no ColdFusion image processing.</td>
                    <td>JPG, PNG, WebP</td>
                </tr>
            </tbody>
        </table>
        <div class='alert alert-info small mb-0'>
            <i class='bi bi-lightbulb me-1'></i>
            <strong>WebP Support:</strong> Pass-through variants support WebP source images. Other modes (Crop & Resize, Resize Only) work with JPG and PNG only.
        </div>
    </div>
</div>
">

<!--- ═══════════════════════════════════════════════════════════════════════
     Delete Confirmation Modal
     ═══════════════════════════════════════════════════════════════════════ --->
<cfset content &= "
<div class='modal fade settings-danger-modal' id='deleteModal' tabindex='-1' aria-labelledby='deleteModalLabel' aria-hidden='true'>
    <div class='modal-dialog'>
        <div class='modal-content'>
            <div class='modal-header text-white'>
                <h5 class='modal-title' id='deleteModalLabel'>
                    <i class='bi bi-exclamation-triangle me-1'></i> Delete Variant Type
                </h5>
                <button type='button' class='btn-close btn-close-white' data-bs-dismiss='modal' aria-label='Close'></button>
            </div>
            <div class='modal-body'>
                <p class='text-muted small mb-1'><strong>Pass-through Mode:</strong> Format-independent &mdash; accepts PNG, JPG, or WebP and outputs in the same format without resizing or cropping.</p>
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
                var modeSelect = document.getElementById('vtMode');
                var dimensionsControls = document.getElementById('dimensionsControls');
                var passthroughInfo = document.getElementById('passthroughInfo');
                var widthInput = document.getElementById('vtWidthPx');
                var heightInput = document.getElementById('vtHeightPx');
                var formatSelect = document.getElementById('vtOutputFormat');

                function updateFormState() {
                    var mode = modeSelect.value;

                    if (mode === 'crop_resize') {
                        // Crop & Resize
                        dimensionsControls.style.display = 'flex';
                        passthroughInfo.style.display = 'none';
                        widthInput.disabled = false;
                        heightInput.disabled = false;
                        formatSelect.disabled = false;
                    } else if (mode === 'resize_only') {
                        // Resize Only
                        dimensionsControls.style.display = 'flex';
                        passthroughInfo.style.display = 'none';
                        widthInput.disabled = false;
                        heightInput.disabled = false;
                        formatSelect.disabled = false;
                    } else if (mode === 'passthrough') {
                        // Pass-through
                        dimensionsControls.style.display = 'none';
                        passthroughInfo.style.display = 'block';
                        widthInput.disabled = true;
                        heightInput.disabled = true;
                        formatSelect.disabled = true;
                    } else {
                        // No selection
                        dimensionsControls.style.display = 'none';
                        passthroughInfo.style.display = 'none';
                    }
                }

                if (modeSelect) {
                    modeSelect.addEventListener('change', updateFormState);
                    // Initialize on page load
                    updateFormState();
                }
            }());
            </script>

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

<cfset content &= "</div>">

<cfinclude template="/admin/layout.cfm">
