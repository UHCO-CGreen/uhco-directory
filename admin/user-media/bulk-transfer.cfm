<!--- Authorization --->
<cfif NOT request.hasPermission("media.publish")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset bulkTransferService = createObject("component", "cfc.BulkImageTransferService").init()>
<cfset sourceKeys = bulkTransferService.getSourceKeys()>
<cfset variantOptions = bulkTransferService.getTransferOnlyVariantTypes()>
<cfset defaultSourceKey = bulkTransferService.getDefaultSourceKey()>
<cfset defaultVariantCode = bulkTransferService.getDefaultVariantCode()>
<cfset patternDAO = createObject("component", "dao.FileNamePatternDAO").init()>
<cfset activeNamingPatterns = patternDAO.getActivePatterns()>

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
<cfset zipVariantOptionsHtml = "">
<cfset showTransferredChecked = showTransferred ? "checked" : "">
<cfset showAmbiguousChecked = showAmbiguous ? "checked" : "">
<!--- ZIP upload state --->
<cfset zipUploadMessage = "">
<cfset zipUploadMessageClass = "alert-info">
<cfset zipUploadResults = []>
<cfset zipExtractedCount = 0>
<cfset zipTransferredCount = 0>
<cfset zipAmbiguousCount = 0>
<cfset zipNoMatchCount = 0>
<cfset zipErrorCount = 0>
<cfset defaultExtractFolder = "uploaded">
<cfset selectedExtractFolder = trim(structKeyExists(form, "extractFolder") ? (form.extractFolder ?: defaultExtractFolder) : defaultExtractFolder)>
<!--- Active tab: driven by POST result or ?tab= param --->
<cfset activeTab = structKeyExists(url, "tab") ? lCase(trim(url.tab)) : "search">

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

<cfset zipVariantOptionsHtml = "<option value=''>&##x2014; Auto-detect from filename</option>">
<cfloop array="#variantOptions#" index="variantOption">
    <cfset variantLabel = trim((variantOption.DESCRIPTION ?: "") & (len(variantOption.CODE ?: "") ? " (" & (variantOption.CODE ?: "") & ")" : ""))>
    <cfif NOT len(variantLabel)>
        <cfset variantLabel = variantOption.CODE ?: "">
    </cfif>
    <cfset zipVariantOptionsHtml &= "<option value='#encodeForHTMLAttribute(variantOption.CODE ?: "")#'>#encodeForHTML(variantLabel)#</option>">
</cfloop>

<cfif cgi.request_method EQ "POST">
    <cfset action = trim(form.action ?: "")>

    <cfif action EQ "transfer">
        <cfif isNumeric(form.userID ?: "") AND val(form.userID) GT 0 AND len(trim(form.sourcePath ?: "")) AND len(selectedSourceKey) AND len(selectedVariantCode)>
            <cfset transferResult = bulkTransferService.transferImage(
                userID      = val(form.userID),
                sourcePath  = trim(form.sourcePath),
                sourceKey   = selectedSourceKey,
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

    <cfelseif action EQ "uploadZip">
        <cfset activeTab = "upload">
        <cfif structKeyExists(form, "zipFile") AND len(trim(form.zipFile ?: ""))>
            <cftry>
                <cffile
                    action="upload"
                    fileField="zipFile"
                    destination="#getTempDirectory()#"
                    nameConflict="makeunique"
                    result="uploadedZip"
                >
                <cfset uploadedZipPath = structKeyExists(uploadedZip, "serverFilePath")
                    ? uploadedZip.serverFilePath
                    : uploadedZip.serverDirectory & ((right(uploadedZip.serverDirectory, 1) EQ "\\" OR right(uploadedZip.serverDirectory, 1) EQ "/") ? "" : "\\") & uploadedZip.serverFile>
                <cfset uploadedZipExt  = lCase(listLast(uploadedZip.serverFile, "."))>
                <cfif uploadedZipExt NEQ "zip">
                    <cfif fileExists(uploadedZipPath)>
                        <cfset fileDelete(uploadedZipPath)>
                    </cfif>
                    <cfset zipUploadMessage = "Only .zip files are accepted. The uploaded file had extension: .#encodeForHTML(uploadedZipExt)#.">
                    <cfset zipUploadMessageClass = "alert-danger">
                <cfelse>
                    <cfset zipExtractFolder = reReplace(trim(form.extractFolder ?: defaultExtractFolder), "[^a-zA-Z0-9_\-]", "_", "all")>
                    <cfset selectedExtractFolder = zipExtractFolder>
                    <cfif NOT len(zipExtractFolder)>
                        <cfset zipExtractFolder = toString(defaultExtractFolder)>
                        <cfset selectedExtractFolder = zipExtractFolder>
                    </cfif>
                    <cfset zipVariantOverride = trim(form.zipVariantCode ?: "")>
                    <cfset extractResult = bulkTransferService.processZipUpload(
                        zipAbsolutePath = uploadedZipPath,
                        sourceKey       = selectedSourceKey,
                        extractFolder   = zipExtractFolder
                    )>
                    <!--- Always clean up the temp ZIP after extraction attempt --->
                    <cftry><cfif fileExists(uploadedZipPath)><cfset fileDelete(uploadedZipPath)></cfif><cfcatch></cfcatch></cftry>
                    <cfif extractResult.success AND extractResult.extractedCount GT 0>
                        <cfset matchResult = bulkTransferService.matchAndTransferExtracted(
                            extractFolder = extractResult.extractPath,
                            sourceKey     = selectedSourceKey,
                            variantCode   = zipVariantOverride
                        )>
                        <cfset zipUploadResults    = matchResult.results>
                        <cfset zipTransferredCount = matchResult.transferredCount>
                        <cfset zipAmbiguousCount   = matchResult.ambiguousCount>
                        <cfset zipNoMatchCount     = matchResult.noMatchCount>
                        <cfset zipErrorCount       = matchResult.errorCount>
                        <cfset zipExtractedCount   = extractResult.extractedCount>
                        <cfset zipUploadMessage    = "Extracted #extractResult.extractedCount# image(s) to <code>/_temp_source/#encodeForHTML(extractResult.extractPath)#/</code>. " & matchResult.message>
                        <cfset zipUploadMessageClass = (zipTransferredCount GT 0) ? "alert-success" : "alert-warning">
                    <cfelseif extractResult.success>
                        <cfset zipSkippedSummary = extractResult.skippedCount GT 0 ? " " & extractResult.skippedCount & " file(s) were skipped." : "">
                        <cfset zipUploadMessage = "ZIP uploaded but contained no valid images after filtering.#zipSkippedSummary#">
                        <cfset zipUploadMessageClass = "alert-warning">
                    <cfelse>
                        <cfset zipUploadMessage = extractResult.message>
                        <cfset zipUploadMessageClass = "alert-danger">
                    </cfif>
                </cfif>
            <cfcatch type="any">
                <cftry><cfif isDefined("uploadedZipPath") AND fileExists(uploadedZipPath)><cfset fileDelete(uploadedZipPath)></cfif><cfcatch></cfcatch></cftry>
                <cfset zipUploadMessage = "ZIP upload failed: #encodeForHTML(cfcatch.message)#">
                <cfset zipUploadMessageClass = "alert-danger">
            </cfcatch>
            </cftry>
        <cfelse>
            <cfset zipUploadMessage = "No ZIP file was received. Please choose a .zip file and try again.">
            <cfset zipUploadMessageClass = "alert-danger">
        </cfif>
    <cfelseif action EQ "clearZipHistory">
        <cfset activeTab = "upload">
        <cfset zipExtractFolder = reReplace(trim(form.extractFolder ?: defaultExtractFolder), "[^a-zA-Z0-9_\-]", "_", "all")>
        <cfif NOT len(zipExtractFolder)>
            <cfset zipExtractFolder = toString(defaultExtractFolder)>
        </cfif>
        <cfset selectedExtractFolder = zipExtractFolder>
        <cfset clearResult = bulkTransferService.clearExtractFolder(zipExtractFolder)>
        <cfset zipUploadMessage = clearResult.message>
        <cfset zipUploadMessageClass = clearResult.success ? "alert-success" : "alert-danger">
        <cfset zipUploadResults = []>
        <cfset zipExtractedCount = 0>
        <cfset zipTransferredCount = 0>
        <cfset zipAmbiguousCount = 0>
        <cfset zipNoMatchCount = 0>
        <cfset zipErrorCount = 0>
    </cfif>
</cfif>

<cfif len(folderName)>
    <cfset searchResult = bulkTransferService.searchFolder(
        folderName         = folderName,
        sourceKey          = selectedSourceKey,
        variantCode        = selectedVariantCode,
        includeTransferred = showTransferred,
        includeAmbiguous   = showAmbiguous,
        limit              = resultLimit
    )>
    <cfset results = searchResult.data>
    <cfset searchMessage = searchResult.message>
    <cfset searchMessageClass = searchResult.success ? "alert-info" : "alert-danger">
</cfif>

<!--- ── Tab nav active classes ─────────────────────────────────────────────── --->
<cfset searchTabActive   = (activeTab EQ "upload") ? "" : "active">
<cfset uploadTabActive   = (activeTab EQ "upload") ? "active" : "">
<cfset searchPaneActive  = (activeTab EQ "upload") ? "" : "show active">
<cfset uploadPaneActive  = (activeTab EQ "upload") ? "show active" : "">
<cfset searchTabSelected = (activeTab EQ "upload") ? "false" : "true">
<cfset uploadTabSelected = (activeTab EQ "upload") ? "true" : "false">

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

<ul class='nav nav-tabs' id='bulkTransferTabs' role='tablist'>
    <li class='nav-item' role='presentation'>
        <button class='nav-link #searchTabActive#' id='search-tab' data-bs-toggle='tab' data-bs-target='##search-pane' type='button' role='tab' aria-controls='search-pane' aria-selected='#searchTabSelected#'>
            <i class='bi bi-search me-1'></i> Search Folder
        </button>
    </li>
    <li class='nav-item' role='presentation'>
        <button class='nav-link #uploadTabActive#' id='upload-tab' data-bs-toggle='tab' data-bs-target='##upload-pane' type='button' role='tab' aria-controls='upload-pane' aria-selected='#uploadTabSelected#'>
            <i class='bi bi-file-zip me-1'></i> Upload ZIP
        </button>
    </li>
</ul>

<div class='tab-content border border-top-0 rounded-bottom p-3 mb-4' id='bulkTransferTabContent'>

<!--- ─── Search Folder pane ──────────────────────────────────────────────── --->
<div class='tab-pane fade #searchPaneActive#' id='search-pane' role='tabpanel' aria-labelledby='search-tab'>

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
                <button type='submit' class='btn btn-ui-filter'>
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
                        <button type='submit' class='btn btn-sm btn-ui-save' data-confirm="Transfer and publish this image for #encodeForJavaScript(row.userDisplayName)#?">
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

<!--- Close search pane --->
<cfset content &= "</div>">

<!--- ─── Upload ZIP pane ──────────────────────────────────────────────────── --->
<cfset content &= "<div class='tab-pane fade #uploadPaneActive#' id='upload-pane' role='tabpanel' aria-labelledby='upload-tab'>">

<!--- Naming convention help panel --->
<cfset namingHelpHtml = "<div class='alert alert-info mb-3' role='alert'>
    <h6 class='alert-heading'><i class='bi bi-info-circle me-1'></i> Required Image Naming Convention</h6>
    <p class='mb-2'>Each image inside the ZIP must be named so it can be matched to a user and assigned to a variant. The filename stem must include:</p>
    <ul class='mb-2'>
        <li>At least one <strong>user identifier</strong>: first name, last name, CougarNet ID, or PeopleSoft ID</li>
        <li>A <strong>variant code</strong> matching an active passthrough variant (required when Auto-detect mode is selected)</li>
    </ul>
    <p class='mb-1'><strong>Accepted extensions:</strong> .jpg, .jpeg, .png, .webp</p>
    <p class='mb-0'><strong>Examples:</strong>
        <code>jsmith_1234567_KIOSK_PROFILE.jpg</code> &nbsp;|&nbsp;
        <code>john_smith_KIOSK_ROSTER.png</code> &nbsp;|&nbsp;
        <code>jsmith_m_KIOSK_PROFILE.webp</code>
    </p>">

<cfif arrayLen(activeNamingPatterns) GT 0>
    <cfset namingHelpHtml &= "<p class='mt-2 mb-1'><strong>Active filename patterns:</strong></p><ul class='mb-0 small'>">
    <cfloop array="#activeNamingPatterns#" index="np">
        <cfset npDescriptionSuffix = len(trim(np.DESCRIPTION ?: "")) ? " &mdash; " & encodeForHTML(np.DESCRIPTION) : "">
        <cfset namingHelpHtml &= "<li><code>#encodeForHTML(np.PATTERN ?: '')#</code>#npDescriptionSuffix#</li>">
    </cfloop>
    <cfset namingHelpHtml &= "</ul>">
</cfif>

<cfset namingHelpHtml &= "</div>">
<cfset content &= namingHelpHtml>

<!--- ZIP upload form --->
<cfset content &= "
<div class='card mb-4'>
    <div class='card-body'>
        <form method='post' enctype='multipart/form-data' class='row g-3 align-items-end'>
            <div class='col-md-5 col-lg-4'>
                <label for='zipFile' class='form-label'>ZIP File</label>
                <input type='file' class='form-control' id='zipFile' name='zipFile' accept='.zip' required>
                <div class='form-text'>Images inside the ZIP are extracted and matched to users. Max 200 MB uncompressed, 500 files.</div>
            </div>
            <div class='col-md-3 col-lg-2'>
                <label for='zipSourceKey' class='form-label'>Source Key</label>
                <select class='form-select' id='zipSourceKey' name='sourceKey' required>
                    #sourceKeyOptionsHtml#
                </select>
            </div>
            <div class='col-md-4 col-lg-3'>
                <label for='zipVariantCode' class='form-label'>Variant</label>
                <select class='form-select' id='zipVariantCode' name='zipVariantCode'>
                    #zipVariantOptionsHtml#
                </select>
                <div class='form-text'>Auto-detect reads the variant code from each filename. A fixed selection overrides all files.</div>
            </div>
            <div class='col-md-3 col-lg-2'>
                <label for='extractFolder' class='form-label'>Extract Folder</label>
                <input type='text' class='form-control' id='extractFolder' name='extractFolder' value='#encodeForHTMLAttribute(toString(selectedExtractFolder))#' placeholder='e.g. #year(now())#' required>
                <div class='form-text'>Subfolder created under <code>/_temp_source/</code> for extracted images.</div>
            </div>
            <div class='col-md-auto'>
                <button type='submit' name='action' value='uploadZip' class='btn btn-ui-save'>
                    <i class='bi bi-upload me-1'></i> Upload &amp; Transfer
                </button>
            </div>
            <div class='col-md-auto'>
                <button type='submit' name='action' value='clearZipHistory' class='btn btn-ui-delete' formnovalidate data-confirm="Clear previous extracted files and ZIP results for this folder?">
                    <i class='bi bi-trash me-1'></i> Clear Upload History
                </button>
            </div>
        </form>
    </div>
</div>
">

<!--- ZIP upload result message --->
<cfif len(zipUploadMessage)>
    <cfset content &= "<div class='alert #zipUploadMessageClass# alert-dismissible fade show' role='alert'>
        #zipUploadMessage#
        <button type='button' class='btn-close' data-bs-dismiss='alert' aria-label='Close'></button>
    </div>">
</cfif>

<!--- ZIP results table --->
<cfif arrayLen(zipUploadResults) GT 0>
    <cfset zipSummaryBadgesHtml = "">
    <cfif zipAmbiguousCount GT 0>
        <cfset zipSummaryBadgesHtml &= "<span class='badge bg-warning text-dark'>#zipAmbiguousCount# ambiguous</span>">
    </cfif>
    <cfif zipNoMatchCount GT 0>
        <cfset zipSummaryBadgesHtml &= "<span class='badge bg-secondary'>#zipNoMatchCount# no match</span>">
    </cfif>
    <cfif zipErrorCount GT 0>
        <cfset zipSummaryBadgesHtml &= "<span class='badge bg-danger'>#zipErrorCount# error(s)</span>">
    </cfif>
    <cfset content &= "
    <div class='card mb-3'>
        <div class='card-header d-flex justify-content-between align-items-center'>
            <span class='fw-semibold'><i class='bi bi-list-check me-1'></i> Transfer Results</span>
            <span class='d-flex gap-2'>
                <span class='badge bg-success'>#zipTransferredCount# transferred</span>
                #zipSummaryBadgesHtml#
            </span>
        </div>
        <div class='table-responsive'>
            <table class='table table-hover align-middle mb-0'>
                <thead class='table-dark'>
                    <tr>
                        <th>File</th>
                        <th>Match</th>
                        <th>Variant</th>
                        <th>Result</th>
                    </tr>
                </thead>
                <tbody>
    ">

    <cfloop array="#zipUploadResults#" index="zRow">
        <cfif zRow.transferred>
            <cfset zBadge = "<span class='badge bg-success'>Transferred</span>">
        <cfelseif zRow.matchStatus EQ "ambiguous">
            <cfset zBadge = "<span class='badge bg-warning text-dark'>Ambiguous</span>">
        <cfelseif zRow.matchStatus EQ "matched">
            <cfset zBadge = "<span class='badge bg-danger'>Error</span>">
        <cfelse>
            <cfset zBadge = "<span class='badge bg-secondary'>No Match</span>">
        </cfif>

        <cfset zUserCell = (zRow.userID GT 0)
            ? "<span class='fw-semibold'>" & encodeForHTML(zRow.userDisplayName) & "</span><br><a href='" & request.webRoot & "/admin/user-media/sources.cfm?userid=" & zRow.userID & "' class='small'>Open User Media</a>"
            : "<span class='text-muted small'>" & encodeForHTML(zRow.matchStatus EQ "ambiguous" ? "Multiple candidates" : "No user matched") & "</span>">
        <cfset zMessageHtml = len(trim(zRow.message)) ? "<div class='text-muted small mt-1'>" & encodeForHTML(zRow.message) & "</div>" : "">

        <cfset content &= "<tr>
            <td><span class='fw-semibold'>#encodeForHTML(zRow.filename)#</span></td>
            <td>#zUserCell#</td>
            <td><code class='small'>#encodeForHTML(zRow.variantCode)#</code></td>
            <td>#zBadge##zMessageHtml#</td>
        </tr>">
    </cfloop>

    <cfset content &= "
                </tbody>
            </table>
        </div>
    </div>
    ">
</cfif>

<!--- Close upload pane --->
<cfset content &= "</div>">

<!--- Close tab-content wrapper --->
<cfset content &= "</div>">

<cfinclude template="/admin/layout.cfm">
