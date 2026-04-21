<!--- Authorization --->
<cfif NOT request.hasPermission("media.publish")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset bulkTransferService = createObject("component", "cfc.BulkImageTransferService").init()>
<cfset sourceKeys = bulkTransferService.getSourceKeys()>
<cfset variantOptions = bulkTransferService.getTransferOnlyVariantTypes()>
<cfset defaultSourceKey = bulkTransferService.getDefaultSourceKey()>
<cfset defaultVariantCode = bulkTransferService.getDefaultVariantCode()>

<cfset folderName = trim(
    structKeyExists(form, "folderName") ? (form.folderName ?: "") : (
        structKeyExists(url, "folder") ? (url.folder ?: "") : ""
    )
)>
<cfset selectedSourceKey = trim(
    structKeyExists(form, "sourceKey") ? (form.sourceKey ?: "") : (
        structKeyExists(url, "sourceKey") ? (url.sourceKey ?: "") : defaultSourceKey
    )
)>
<cfset selectedVariantCode = trim(
    structKeyExists(form, "variantCode") ? (form.variantCode ?: "") : (
        structKeyExists(url, "variantCode") ? (url.variantCode ?: "") : defaultVariantCode
    )
)>
<cfset resultLimit = isNumeric(structKeyExists(form, "resultLimit") ? (form.resultLimit ?: "") : (structKeyExists(url, "resultLimit") ? (url.resultLimit ?: "") : "")) ? val(structKeyExists(form, "resultLimit") ? (form.resultLimit ?: "") : (structKeyExists(url, "resultLimit") ? (url.resultLimit ?: "") : "25")) : 25>
<cfset resultLimit = max(1, min(resultLimit, 100))>
<cfset showTransferred = structKeyExists(form, "showTransferred") OR structKeyExists(url, "showTransferred")>
<cfset showAmbiguous = structKeyExists(form, "showAmbiguous") OR structKeyExists(url, "showAmbiguous")>
<cfset results = []>
<cfset searchMessage = "">
<cfset searchMessageClass = "alert-info">
<cfset actionMessage = "">
<cfset actionMessageClass = "alert-success">
<cfset postTransferHtml = "">
<cfset sourceKeyOptionsHtml = "">
<cfset variantOptionsHtml = "">
<cfset showTransferredChecked = showTransferred ? "checked" : "">
<cfset showAmbiguousChecked = showAmbiguous ? "checked" : "">

<cfloop array="#sourceKeys#" index="sourceKeyOption">
    <cfset sourceKeyOptionsHtml &= "<option value='#encodeForHTMLAttribute(sourceKeyOption)#'" & (compareNoCase(sourceKeyOption, selectedSourceKey) EQ 0 ? " selected" : "") & ">#encodeForHTML(sourceKeyOption)#</option>">
</cfloop>

<cfloop array="#variantOptions#" index="variantOption">
    <cfset variantLabel = trim((variantOption.DESCRIPTION ?: "") & (len(variantOption.CODE ?: "") ? " (" & (variantOption.CODE ?: "") & ")" : ""))>
    <cfif NOT len(variantLabel)>
        <cfset variantLabel = variantOption.CODE ?: "">
    </cfif>
    <cfset variantOptionsHtml &= "<option value='#encodeForHTMLAttribute(variantOption.CODE ?: "")#'" & (compareNoCase(variantOption.CODE ?: "", selectedVariantCode) EQ 0 ? " selected" : "") & ">#encodeForHTML(variantLabel)#</option>">
</cfloop>

<cfif cgi.request_method EQ "POST">
    <cfset action = trim(form.action ?: "")>

    <cfif action EQ "transfer">
        <cfif isNumeric(form.userID ?: "") AND val(form.userID) GT 0 AND len(trim(form.sourcePath ?: "")) AND len(selectedSourceKey) AND len(selectedVariantCode)>
            <cfset transferResult = bulkTransferService.transferImage(
                userID     = val(form.userID),
                sourcePath = trim(form.sourcePath),
                sourceKey  = selectedSourceKey,
                variantCode = selectedVariantCode
            )>
            <cfset actionMessage = transferResult.message>
            <cfset actionMessageClass = transferResult.success ? "alert-success" : "alert-danger">

            <cfif transferResult.success>
                <cfset postTransferHtml = "
                <div class='mt-2 small'>
                    <a href='#request.webRoot#/admin/user-media/sources.cfm?userid=#transferResult.userID#' class='alert-link'>Open User Media for this user</a>
                    <span class='text-muted ms-2'>Source Key: #encodeForHTML(selectedSourceKey)#</span>
                    <span class='text-muted ms-2'>Variant: #encodeForHTML(transferResult.variantCode ?: "")#</span>
                </div>
                ">
            </cfif>
        <cfelse>
            <cfset actionMessage = "Transfer request is missing a valid user, source path, source key, or variant.">
            <cfset actionMessageClass = "alert-danger">
        </cfif>
    </cfif>
</cfif>

<cfif len(folderName)>
    <cfset searchResult = bulkTransferService.searchFolder(
        folderName = folderName,
        sourceKey = selectedSourceKey,
        variantCode = selectedVariantCode,
        includeTransferred = showTransferred,
        includeAmbiguous = showAmbiguous,
        limit = resultLimit
    )>
    <cfset results = searchResult.data>
    <cfset searchMessage = searchResult.message>
    <cfset searchMessageClass = searchResult.success ? "alert-info" : "alert-danger">
</cfif>

<cfset content = "
<nav aria-label='breadcrumb' class='mb-3'>
    <ol class='breadcrumb'>
        <li class='breadcrumb-item'><a href='#request.webRoot#/admin/user-media/index.cfm'>User Media</a></li>
        <li class='breadcrumb-item active' aria-current='page'>Bulk Transfer</li>
    </ol>
</nav>

<div class='d-flex justify-content-between align-items-center mb-3'>
    <div>
        <h1 class='mb-1'>Bulk Image Transfer</h1>
        <p class='text-muted mb-0'>Search a subfolder under <code>/_temp_source/</code>, match filenames to users, and directly publish a transfer-only variant without cropping or resizing.</p>
    </div>
</div>

<div class='card mb-4'>
    <div class='card-body'>
        <form method='get' class='row g-3 align-items-end'>
            <div class='col-md-6 col-lg-4'>
                <label for='folderName' class='form-label'>Folder Name</label>
                <input type='text' class='form-control' id='folderName' name='folder' value='#encodeForHTMLAttribute(folderName)#' placeholder='e.g. 2025' required>
                <div class='form-text'>Matches images only when the path under <code>/_temp_source/</code> contains an exact folder segment with this name.</div>
            </div>
            <div class='col-md-3 col-lg-2'>
                <label for='sourceKey' class='form-label'>Source Key</label>
                <select class='form-select' id='sourceKey' name='sourceKey' required>
                    #sourceKeyOptionsHtml#
                </select>
            </div>
            <div class='col-md-5 col-lg-3'>
                <label for='variantCode' class='form-label'>Variant</label>
                <select class='form-select' id='variantCode' name='variantCode' required>
                    #variantOptionsHtml#
                </select>
                <div class='form-text'>Only active transfer-only variants are listed here.</div>
            </div>
            <div class='col-md-2 col-lg-1'>
                <label for='resultLimit' class='form-label'>Show</label>
                <input type='number' class='form-control' id='resultLimit' name='resultLimit' min='1' max='100' value='#resultLimit#'>
            </div>
            <div class='col-md-6 col-lg-2'>
                <div class='form-check'>
                    <input class='form-check-input' type='checkbox' id='showTransferred' name='showTransferred' value='1' #showTransferredChecked#>
                    <label class='form-check-label' for='showTransferred'>Show transferred</label>
                </div>
                <div class='form-check'>
                    <input class='form-check-input' type='checkbox' id='showAmbiguous' name='showAmbiguous' value='1' #showAmbiguousChecked#>
                    <label class='form-check-label' for='showAmbiguous'>Show ambiguous</label>
                </div>
            </div>
            <div class='col-md-auto'>
                <button type='submit' class='btn btn-primary'>
                    <i class='bi bi-search me-1'></i> Search Folder
                </button>
            </div>
        </form>
    </div>
</div>
">

<cfif len(actionMessage)>
    <cfset content &= "
    <div class='alert #actionMessageClass# alert-dismissible fade show' role='alert'>
        #encodeForHTML(actionMessage)#
        #postTransferHtml#
        <button type='button' class='btn-close' data-bs-dismiss='alert' aria-label='Close'></button>
    </div>
    ">
</cfif>

<cfif len(folderName)>
    <cfset content &= "
    <div class='alert #searchMessageClass#' role='alert'>
        #encodeForHTML(searchMessage)#
    </div>
    ">

    <cfset content &= "
    <div class='card'>
        <div class='card-header d-flex justify-content-between align-items-center'>
            <span class='fw-semibold'><i class='bi bi-images me-1'></i> Search Results</span>
            <span class='badge bg-secondary'>#arrayLen(results)#</span>
        </div>
    ">

    <cfif arrayLen(results) GT 0>
        <cfset content &= "
        <div class='table-responsive'>
            <table class='table table-hover align-middle mb-0'>
                <thead class='table-dark'>
                    <tr>
                        <th>Preview</th>
                        <th>File</th>
                        <th>Match</th>
                        <th>Matched By</th>
                        <th>Action</th>
                    </tr>
                </thead>
                <tbody>
        ">

        <cfloop from="1" to="#arrayLen(results)#" index="i">
            <cfset row = results[i]>
            <cfset matchHtml = "">
            <cfset actionHtml = "">
            <cfset badgeClass = row.isTransferred ? "bg-info text-dark" : (row.matchStatus EQ "matched" ? "bg-success" : (row.matchStatus EQ "ambiguous" ? "bg-warning text-dark" : "bg-secondary"))>
            <cfset badgeText = row.isTransferred ? row.transferLabel : (row.matchStatus EQ "matched" ? "Matched" : (row.matchStatus EQ "ambiguous" ? "Ambiguous" : "No Match"))>

            <cfif row.matchStatus EQ "matched">
                <cfset matchHtml = "
                <div class='fw-semibold'>#encodeForHTML(row.userDisplayName)#</div>
                <div class='text-muted small'>#encodeForHTML(row.userEmail)#</div>
                <div class='mt-1'>
                    <a href='#request.webRoot#/admin/user-media/sources.cfm?userid=#row.userID#' class='small'>Open User Media</a>
                </div>
                ">
                <cfif row.isTransferred>
                    <cfset actionHtml = "
                    <div>
                        <span class='badge bg-info text-dark'>#encodeForHTML(row.transferLabel)#</span>
                        <div class='small text-muted mt-1'>Source Key: #encodeForHTML(selectedSourceKey)#<br>Variant: #encodeForHTML(row.variantCode ?: "")#</div>
                    </div>
                    ">
                <cfelse>
                    <cfset actionHtml = "
                    <form method='post' class='d-inline'>
                        <input type='hidden' name='action' value='transfer'>
                        <input type='hidden' name='folderName' value='#encodeForHTMLAttribute(folderName)#'>
                        <input type='hidden' name='sourceKey' value='#encodeForHTMLAttribute(selectedSourceKey)#'>
                        <input type='hidden' name='variantCode' value='#encodeForHTMLAttribute(selectedVariantCode)#'>
                        <input type='hidden' name='resultLimit' value='#resultLimit#'>
                        #showTransferred ? "<input type='hidden' name='showTransferred' value='1'>" : ""#
                        #showAmbiguous ? "<input type='hidden' name='showAmbiguous' value='1'>" : ""#
                        <input type='hidden' name='userID' value='#row.userID#'>
                        <input type='hidden' name='sourcePath' value='#encodeForHTMLAttribute(row.sourcePath)#'>
                        <button type='submit' class='btn btn-sm btn-primary' onclick=&quot;return confirm('Transfer and publish this image for #encodeForJavaScript(row.userDisplayName)#?')&quot;>
                            <i class='bi bi-arrow-left-right me-1'></i> Transfer
                        </button>
                        <div class='small text-muted mt-1'>Source Key: #encodeForHTML(selectedSourceKey)#<br>Variant: #encodeForHTML(row.variantCode ?: "")#</div>
                    </form>
                    ">
                </cfif>
            <cfelseif row.matchStatus EQ "ambiguous">
                <cfset matchHtml = "<div class='text-warning-emphasis small'>#encodeForHTML(row.candidateText)#</div>">
                <cfset actionHtml = "<span class='text-muted small'>Resolve manually in User Media.</span>">
            <cfelse>
                <cfset matchHtml = "<div class='text-muted small'>#encodeForHTML(row.candidateText)#</div>">
                <cfset actionHtml = "<span class='text-muted small'>No automatic transfer available.</span>">
            </cfif>

            <cfset content &= "
            <tr>
                <td>
                    <img src='#encodeForHTMLAttribute(row.sourcePath)#' alt='#encodeForHTMLAttribute(row.filename)#' class='rounded border admin-thumb-72'>
                </td>
                <td>
                    <div class='fw-semibold'>#encodeForHTML(row.filename)#</div>
                    <div class='text-muted small font-monospace'>#encodeForHTML(row.sourcePath)#</div>
                    <div class='small mt-1'><span class='badge #badgeClass#'>#badgeText#</span></div>
                </td>
                <td>#matchHtml#</td>
                <td class='small'>#encodeForHTML(row.matchedBy)#</td>
                <td>#actionHtml#</td>
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
            <p class='text-muted mb-0'>No rows matched the current folder and filter settings.</p>
        </div>
        ">
    </cfif>

    <cfset content &= "</div>">
</cfif>

<cfinclude template="/admin/layout.cfm">