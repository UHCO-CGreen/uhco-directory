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
<cfset usersService       = createObject("component", "cfc.users_service").init()>
<cfset variantService     = createObject("component", "cfc.UserImageVariantService").init()>
<cfset publishingService  = createObject("component", "cfc.PublishingService").init()>

<!--- ── Load user ────────────────────────────────────────────────────────── --->
<cfset userResult = usersService.getUser(userID)>
<cfif NOT userResult.success>
    <cflocation url="#request.webRoot#/admin/user-media/index.cfm" addtoken="false">
</cfif>
<cfset user = userResult.data>

<!--- ── Load variant matrix to find this variant type ────────────────────── --->
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
<cfset allowResize   = isBoolean(variant.ALLOWRESIZE ?: true) AND variant.ALLOWRESIZE>
<cfset isPassThrough = NOT allowResize>

<!--- Build a human-readable dimensions string --->
<cfif isPassThrough>
    <cfset dimDisplay = "Original (pass-through)">
<cfelseif targetWidth GT 0 AND targetHeight GT 0>
    <cfset dimDisplay = "#targetWidth# &times; #targetHeight# px">
<cfelseif targetWidth GT 0>
    <cfset dimDisplay = "#targetWidth# &times; auto">
<cfelseif targetHeight GT 0>
    <cfset dimDisplay = "auto &times; #targetHeight#">
<cfelse>
    <cfset dimDisplay = "Original size">
</cfif>

<!--- ── Handle POST actions ──────────────────────────────────────────────── --->
<cfset actionMessage      = "">
<cfset actionMessageClass = "alert-success">
<cfset generationSuccess  = false>
<cfset publishSuccess     = false>
<cfset previewUrl         = "">

<cfif cgi.request_method EQ "POST">
    <cfset action = trim(form.action ?: "")>

    <!--- ── Generate (resize only — no crop data) ────────────────────── --->
    <cfif action EQ "generate">
        <cfset result = variantService.generateVariant(
            userID             = userID,
            imageVariantTypeID = imageVariantTypeID,
            userImageSourceID  = sourceID
        )>

        <cfset actionMessage      = result.message>
        <cfset actionMessageClass = result.success ? "alert-success" : "alert-danger">
        <cfset generationSuccess  = result.success>

        <!--- Refresh variant data to pick up the new LocalPath --->
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
    <cfelseif action EQ "publish">
        <cfif NOT request.hasPermission("media.publish")>
            <cfset actionMessage = "You do not have permission to publish media.">
            <cfset actionMessageClass = "alert-danger">
            <cfset publishSuccess = false>
        <cfelse>
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

<!--- ── Determine current state for button visibility ────────────────────── --->
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
        <li class='breadcrumb-item active' aria-current='page'>Generate &amp; Publish</li>
    </ol>
</nav>

<div class='d-flex justify-content-between align-items-start mb-3'>
    <div>
        <h1 class='mb-1'>Generate &amp; Publish</h1>
        <p class='text-muted mb-0'>
            <strong>#variantName#</strong>
            <span class='font-monospace ms-2'>#variantCode#</span>
            &mdash; #dimDisplay#
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

<!--- ── Preview of generated image (shown when a temp file exists) ───────── --->
<cfif len(previewUrl)>
    <cfset content &= "
    <div class='card mb-4'>
        <div class='card-header fw-semibold bg-success text-white'>
            <i class='bi bi-check-circle me-1'></i> Generated Output
        </div>
        <div class='card-body text-center'>
            <img src='#encodeForHTMLAttribute(previewUrl)#'
                 alt='Generated variant preview'
                  class='img-fluid rounded border media-preview-image-lg'>
            <p class='text-muted small mt-2 mb-0'>
                File: #encodeForHTML(variant.LOCALPATH)#
                &mdash; #dimDisplay#
            </p>
        </div>
    </div>
    ">
</cfif>

<!--- ── Action buttons ───────────────────────────────────────────────────── --->
<cfset content &= "
<div class='card mb-4'>
    <div class='card-header fw-semibold'>
        <i class='bi bi-gear me-1'></i> Actions
    </div>
    <div class='card-body'>
        <p class='text-muted mb-3'>
">

<cfif isPassThrough>
    <cfset content &= "
            This variant uses <strong>pass-through</strong> mode &mdash; the source image will be
            copied as-is with no resize or crop.
    ">
<cfelse>
    <cfset content &= "
            This variant uses <strong>proportional resize</strong> only &mdash; no cropping required.
            The source image will be resized to #dimDisplay#.
    ">
</cfif>

<cfset content &= "
        </p>
        <div class='d-flex gap-2 flex-wrap'>
            <form method='post' class='d-inline'>
                <input type='hidden' name='action' value='generate'>
                <button type='submit' class='btn btn-success'>
                    <i class='bi bi-arrow-clockwise me-1'></i> #(hasGeneratedFile ? 'Regenerate' : (isPassThrough ? 'Transfer' : 'Generate'))#
                </button>
            </form>
">

<!--- Publish button — only when a generated file exists --->
<cfif hasGeneratedFile AND request.hasPermission("media.publish")>
    <cfset content &= "
            <form method='post' class='d-inline'>
                <input type='hidden' name='action' value='publish'>
                <button type='submit' class='btn btn-primary'>
                    <i class='bi bi-cloud-arrow-up me-1'></i> Publish
                </button>
            </form>
    ">
</cfif>

<cfset content &= "
        </div>
    </div>
</div>
">

<!--- ── Published confirmation ───────────────────────────────────────────── --->
<cfif publishSuccess>
    <cfset content &= "
    <div class='card mb-4 border-primary'>
        <div class='card-body text-center'>
            <i class='bi bi-check-circle-fill text-primary fs-1 mb-2 d-block'></i>
            <h5>Published Successfully</h5>
            <p class='text-muted mb-0'>
                This variant has been published to the directory.
                You can regenerate and re-publish at any time.
            </p>
        </div>
    </div>
    ">
</cfif>

<cfinclude template="/admin/layout.cfm">
