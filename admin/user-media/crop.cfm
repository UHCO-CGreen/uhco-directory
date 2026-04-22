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
<cfif NOT structKeyExists(url, "imageVariantTypeID") OR NOT isNumeric(url.imageVariantTypeID) OR val(url.imageVariantTypeID) LTE 0>
    <cflocation url="#request.webRoot#/admin/user-media/variants.cfm?userid=#val(url.userid)#&sourceid=#val(url.sourceid)#" addtoken="false">
</cfif>

<cfset userID             = val(url.userid)>
<cfset sourceID           = val(url.sourceid)>
<cfset imageVariantTypeID = val(url.imageVariantTypeID)>

<!--- ── Services ─────────────────────────────────────────────────────────── --->
<cfset usersService   = createObject("component", "cfc.users_service").init()>
<cfset variantService = createObject("component", "cfc.UserImageVariantService").init()>
<cfset sourceService  = createObject("component", "cfc.UserImageSourceService").init()>

<!--- ── Load user ────────────────────────────────────────────────────────── --->
<cfset userResult = usersService.getUser(userID)>
<cfif NOT userResult.success>
    <cflocation url="#request.webRoot#/admin/user-media/index.cfm" addtoken="false">
</cfif>
<cfset user = userResult.data>

<!--- ── Load variant matrix to find this variant type + source info ───────── --->
<cfset variantMatrix = variantService.getVariantMatrix(userID, sourceID)>
<cfset variant = {}>
<cfloop from="1" to="#arrayLen(variantMatrix)#" index="i">
    <cfif val(variantMatrix[i].IMAGEVARIANTTYPEID) EQ imageVariantTypeID>
        <cfset variant = variantMatrix[i]>
        <cfbreak>
    </cfif>
</cfloop>

<!--- ── Guard: variant type must exist and have an assigned source ────────── --->
<cfif structIsEmpty(variant) OR variant.STATUS EQ "missing">
    <cflocation url="#request.webRoot#/admin/user-media/variants.cfm?userid=#userID#&sourceid=#sourceID#" addtoken="false">
</cfif>

<!--- ── Derive display values ────────────────────────────────────────────── --->
<cfset displayName   = encodeForHTML(trim((user.FIRSTNAME ?: "") & " " & (user.LASTNAME ?: "")))>
<cfset variantName   = encodeForHTML(variant.DESCRIPTION ?: "")>
<cfset variantCode   = encodeForHTML(variant.CODE ?: "")>
<cfset targetWidth   = isNumeric(variant.WIDTHPX ?: "") ? int(val(variant.WIDTHPX)) : 0>
<cfset targetHeight  = isNumeric(variant.HEIGHTPX ?: "") ? int(val(variant.HEIGHTPX)) : 0>
<cfset rawDropboxPath = variant.SOURCEDROPBOXPATH ?: "">
<cfset sourceUrl = "">
<cfif len(rawDropboxPath)>
    <cfif left(rawDropboxPath, 14) EQ "/_temp_source/">
        <!--- Local file: use the web path directly. --->
        <cfset sourceUrl = rawDropboxPath>
    <cfelse>
        <!--- Dropbox file: proxy through our serve endpoint. --->
        <cfset sourceUrl = request.webRoot & "/admin/user-media/_serve_dropbox_image.cfm?path=" & encodeForURL(rawDropboxPath)>
    </cfif>
</cfif>
<cfset allowCrop     = isBoolean(variant.ALLOWMANUALCROP ?: false) AND variant.ALLOWMANUALCROP>

<!--- If this variant type does not allow manual crop, redirect back ───────── --->
<cfif NOT allowCrop>
    <cflocation url="#request.webRoot#/admin/user-media/variants.cfm?userid=#userID#&sourceid=#sourceID#" addtoken="false">
</cfif>

<!--- ── Handle POST actions ────────────────────────────────────────────── --->
<cfset actionMessage      = "">
<cfset actionMessageClass = "alert-success">
<cfset generationSuccess  = false>
<cfset publishSuccess     = false>
<cfset previewUrl         = "">

<cfif cgi.request_method EQ "POST">
    <cfset postAction = trim(form.action ?: "")>

    <!--- ── Crop & Generate ──────────────────────────────────────────── --->
    <cfif postAction EQ "cropGenerate">
        <cfset cropData = {}>
        <cfif isNumeric(form.cropX ?: "") AND isNumeric(form.cropY ?: "")
              AND isNumeric(form.cropWidth ?: "") AND isNumeric(form.cropHeight ?: "")
              AND val(form.cropWidth) GT 0 AND val(form.cropHeight) GT 0>
            <cfset cropData = {
                x      = val(form.cropX),
                y      = val(form.cropY),
                width  = val(form.cropWidth),
                height = val(form.cropHeight)
            }>
        </cfif>

        <cfset result = variantService.generateVariant(
            userID             = userID,
            imageVariantTypeID = imageVariantTypeID,
            userImageSourceID  = sourceID,
            cropData           = cropData
        )>

        <cfset actionMessage      = result.message>
        <cfset actionMessageClass = result.success ? "alert-success" : "alert-danger">
        <cfset generationSuccess  = result.success>

        <!--- Refresh variant data to get the output path --->
        <cfif result.success>
            <cfset variantMatrix = variantService.getVariantMatrix(userID, sourceID)>
            <cfloop from="1" to="#arrayLen(variantMatrix)#" index="i">
                <cfif val(variantMatrix[i].IMAGEVARIANTTYPEID) EQ imageVariantTypeID>
                    <cfset variant = variantMatrix[i]>
                    <cfbreak>
                </cfif>
            </cfloop>
            <cfif len(variant.LOCALPATH ?: "")>
                <cfset previewUrl = variant.LOCALPATH & "?v=" & getTickCount()>
            </cfif>
        </cfif>

    <!--- ── Publish this variant ─────────────────────────────────────── --->
    <cfelseif postAction EQ "publish">
        <cfif NOT request.hasPermission("media.publish")>
            <cfset actionMessage = "You do not have permission to publish media.">
            <cfset actionMessageClass = "alert-danger">
            <cfset publishSuccess = false>
        <cfelse>
            <cfset publishingService = createObject("component", "cfc.PublishingService").init()>
            <cfset result = publishingService.publishVariant(
                userID             = userID,
                imageVariantTypeID = imageVariantTypeID,
                userImageSourceID  = sourceID
            )>
            <cfset actionMessage      = result.message>
            <cfset actionMessageClass = result.success ? "alert-success" : "alert-danger">
            <cfset publishSuccess     = result.success>
        </cfif>

        <!--- Refresh variant data --->
        <cfset variantMatrix = variantService.getVariantMatrix(userID, sourceID)>
        <cfloop from="1" to="#arrayLen(variantMatrix)#" index="i">
            <cfif val(variantMatrix[i].IMAGEVARIANTTYPEID) EQ imageVariantTypeID>
                <cfset variant = variantMatrix[i]>
                <cfbreak>
            </cfif>
        </cfloop>
    </cfif>
</cfif>

<!--- ── Determine if a generated file exists for the publish button ──────── --->
<cfset hasGeneratedFile = len(variant.LOCALPATH ?: "") AND variant.STATUS EQ "current">
<cfif hasGeneratedFile AND NOT len(previewUrl)>
    <cfset previewUrl = variant.LOCALPATH & "?v=" & getTickCount()>
</cfif>

<!--- ═══════════════════════════════════════════════════════════════════════
     Page content
     ═══════════════════════════════════════════════════════════════════════ --->
<cfset content = "
<nav aria-label='breadcrumb' class='mb-3'>
    <ol class='breadcrumb'>
        <li class='breadcrumb-item'><a href='/admin/user-media/index.cfm'>User Media</a></li>
        <li class='breadcrumb-item'><a href='/admin/user-media/sources.cfm?userid=#userID#'>Image Sources</a></li>
        <li class='breadcrumb-item'><a href='/admin/user-media/variants.cfm?userid=#userID#&sourceid=#sourceID#'>Image Variants</a></li>
        <li class='breadcrumb-item active' aria-current='page'>Crop &amp; Generate</li>
    </ol>
</nav>

<div class='d-flex justify-content-between align-items-start mb-3'>
    <div>
        <h1 class='mb-1'>Crop &amp; Generate</h1>
        <p class='text-muted mb-0'>
            <strong>#variantName#</strong>
            <span class='font-monospace ms-2'>#variantCode#</span>
            &mdash; #targetWidth# &times; #targetHeight# px
            &mdash; #displayName#
        </p>
    </div>
    <a href='/admin/user-media/variants.cfm?userid=#userID#&sourceid=#sourceID#' class='btn btn-outline-secondary'>
        <i class='bi bi-arrow-left me-1'></i> Back to Variants
    </a>
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

<!--- ── Generation result preview ────────────────────────────────────────── --->
<cfif (generationSuccess OR hasGeneratedFile) AND len(previewUrl)>
    <cfset content &= "
    <div class='card mb-4'>
        <div class='card-header fw-semibold bg-success text-white d-flex justify-content-between align-items-center'>
            <span><i class='bi bi-check-circle me-1'></i> Generated Output</span>
    ">

    <!--- Publish button shown when there is a current generated file --->
    <cfif hasGeneratedFile AND request.hasPermission("media.publish")>
        <cfset content &= "
            <form method='post' class='d-inline'>
                <input type='hidden' name='action' value='publish'>
                <button type='submit' class='btn btn-sm btn-light'>
                    <i class='bi bi-cloud-arrow-up me-1'></i> Publish
                </button>
            </form>
        ">
    </cfif>

    <cfset content &= "
        </div>
        <div class='card-body text-center'>
            <img src='#encodeForHTMLAttribute(previewUrl)#'
                 alt='Generated variant preview'
                  class='img-fluid rounded border media-preview-image'>
            <p class='text-muted small mt-2 mb-0'>
                File: #encodeForHTML(variant.LOCALPATH)#
                &mdash; #targetWidth# &times; #targetHeight# px
            </p>
        </div>
    </div>
    ">
</cfif>

<!--- ── Publish success confirmation ─────────────────────────────────────── --->
<cfif publishSuccess>
    <cfset content &= "
    <div class='card mb-4 border-primary'>
        <div class='card-body text-center'>
            <i class='bi bi-check-circle-fill text-primary fs-1 mb-2 d-block'></i>
            <h5>Published Successfully</h5>
            <p class='text-muted mb-0'>
                This variant has been published to the directory.
                You can re-crop, regenerate, and re-publish at any time.
            </p>
        </div>
    </div>
    ">
</cfif>

<!--- ── Crop tool ────────────────────────────────────────────────────────── --->
<cfif len(sourceUrl)>
    <cfset content &= "
    <div class='card mb-4'>
        <div class='card-header fw-semibold'>
            <i class='bi bi-crop me-1'></i> Select Crop Area
            <span class='text-muted fw-normal ms-2'>Target: #targetWidth# &times; #targetHeight# px</span>
        </div>
        <div class='card-body p-0'>
            <div class='media-crop-stage'>
                <img id='cropSourceImage'
                     src='#encodeForHTMLAttribute(sourceUrl)#'
                     alt='Source image'
                     class='media-crop-source'>
            </div>
        </div>
        <div class='card-footer d-flex justify-content-between align-items-center'>
            <div class='text-muted small' id='cropInfo'>
                Drag the crop box or its handles to adjust. The aspect ratio is locked to #targetWidth#:#targetHeight#.
            </div>
            <form method='post' id='cropForm'>
                <input type='hidden' name='action'    value='cropGenerate'>
                <input type='hidden' name='cropX'     id='cropX' value=''>
                <input type='hidden' name='cropY'     id='cropY' value=''>
                <input type='hidden' name='cropWidth'  id='cropWidth' value=''>
                <input type='hidden' name='cropHeight' id='cropHeight' value=''>
                <button type='submit' class='btn btn-success' id='cropSubmitBtn'>
                    <i class='bi bi-crop me-1'></i> Crop &amp; Generate
                </button>
            </form>
        </div>
    </div>
    ">
<cfelse>
    <cfset content &= "
    <div class='alert alert-warning'>
        <i class='bi bi-exclamation-triangle me-1'></i>
        No source image path available. Ensure a source is assigned on the
        <a href='/admin/user-media/variants.cfm?userid=#userID#&sourceid=#sourceID#'>variants page</a>.
    </div>
    ">
</cfif>

<cfset pageScripts = "
<link rel='stylesheet' href='https://cdn.jsdelivr.net/npm/cropperjs@1.6.2/dist/cropper.min.css'>
<script src='https://cdn.jsdelivr.net/npm/cropperjs@1.6.2/dist/cropper.min.js'></script>
">

<cfif len(sourceUrl)>
<cfset pageScripts &= "
<script>
(function () {
    'use strict';

    var img       = document.getElementById('cropSourceImage');
    var form      = document.getElementById('cropForm');
    var submitBtn = document.getElementById('cropSubmitBtn');
    var infoEl    = document.getElementById('cropInfo');
    var cropper   = null;

    function initCropper() {
        if (cropper) { cropper.destroy(); }

        cropper = new Cropper(img, {
            aspectRatio: #targetWidth# / #targetHeight#,
            checkOrientation: false,
            viewMode: 1,
            dragMode: 'move',
            autoCropArea: 0.8,
            restore: false,
            guides: true,
            center: true,
            highlight: true,
            background: true,
            cropBoxMovable: true,
            cropBoxResizable: true,
            zoomable: true,
            zoomOnWheel: true,
            rotatable: false,
            scalable: false,
            toggleDragModeOnDblclick: false,
            crop: function (event) {
                var d = event.detail;
                if (infoEl && d.width > 0 && d.height > 0) {
                    infoEl.textContent = 'Crop: '
                        + Math.round(d.width) + ' \u00d7 ' + Math.round(d.height) + ' px'
                        + '  at (' + Math.round(d.x) + ', ' + Math.round(d.y) + ')'
                        + '  \u2192  will be resized to #targetWidth# \u00d7 #targetHeight# px';
                }
            }
        });
    }

    if (img.complete && img.naturalWidth > 0) {
        initCropper();
    } else {
        img.addEventListener('load', initCropper);
    }

    form.addEventListener('submit', function (event) {
        if (!cropper) {
            event.preventDefault();
            alert('Cropper not ready. Please wait for the image to load.');
            return;
        }

        var data = cropper.getData();

        if (!data.width || data.width <= 0 || !data.height || data.height <= 0) {
            event.preventDefault();
            alert('Invalid crop selection. Please adjust the crop box.');
            return;
        }

        document.getElementById('cropX').value      = Number(data.x || 0).toFixed(4);
        document.getElementById('cropY').value      = Number(data.y || 0).toFixed(4);
        document.getElementById('cropWidth').value  = Number(data.width || 0).toFixed(4);
        document.getElementById('cropHeight').value = Number(data.height || 0).toFixed(4);

        submitBtn.disabled = true;
        submitBtn.innerHTML = '<span class=\x22spinner-border spinner-border-sm me-1\x22></span> Generating...';
    });
}());
</script>
">
</cfif>

<cfinclude template="/admin/layout.cfm">
