<cfif NOT request.hasPermission("settings.api.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset quickpullKey = lCase(trim(url.quickpull ?: ""))>
<cfset quickpullService = createObject("component", "cfc.quickpull_service").init()>
<cfset editModel = quickpullService.getQuickpullEditModel(quickpullKey)>

<cfif structIsEmpty(editModel)>
    <cflocation url="index.cfm?error=#urlEncodedFormat('Quickpull not found.')#" addtoken="false">
    <cfabort>
</cfif>

<cfset quickpull = editModel.quickpull>
<cfset config = editModel.config>
<cfset options = editModel.options>
<cfset actionMessage = trim(url.msg ?: "")>
<cfset actionError = trim(url.error ?: "")>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item"><a href="/admin/settings/uhco-api/">UHCO API</a></li>
        <li class="breadcrumb-item"><a href="index.cfm">Quickpulls</a></li>
        <li class="breadcrumb-item active">#encodeForHTML(quickpull.label)#</li>
    </ol>
</nav>

<div class="d-flex justify-content-between align-items-start flex-wrap gap-3 mb-4">
    <div>
        <h1 class="mb-1">#encodeForHTML(quickpull.label)# Quickpull</h1>
        <div class="text-muted font-monospace mb-2">#encodeForHTML(quickpull.endpoint)#</div>
        <p class="text-muted mb-0">Default return items stay in place. Select the additional fields this quickpull should append.</p>
    </div>
    <a href="index.cfm" class="btn btn-outline-secondary">
        <i class="bi bi-arrow-left me-1"></i>Back to Quickpulls
    </a>
</div>

<cfif len(actionMessage)>
    <div class="alert alert-success">#encodeForHTML(actionMessage)#</div>
</cfif>
<cfif len(actionError)>
    <div class="alert alert-danger">#encodeForHTML(actionError)#</div>
</cfif>

<div class="card shadow-sm mb-4">
    <div class="card-body">
        <div class="small text-uppercase text-muted fw-semibold mb-2">Default Return Items</div>
        <div class="d-flex flex-wrap gap-2">
            <cfloop array="#quickpull.baseFields#" index="baseField">
                <span class="badge text-bg-light border">#encodeForHTML(baseField)#</span>
            </cfloop>
        </div>
    </div>
</div>

<form method="post" action="save.cfm">
    <input type="hidden" name="quickpullType" value="#encodeForHTMLAttribute(quickpull.key)#">

    <div class="card shadow-sm mb-4">
        <div class="card-header"><h5 class="mb-0">General</h5></div>
        <div class="card-body">
            <p class="text-muted small">Selected values are appended as top-level keys on each quickpull row.</p>
            <div class="row g-2">
                <cfloop array="#options.generalFields#" index="option">
                    <div class="col-md-4">
                        <div class="form-check">
                            <input class="form-check-input" type="checkbox" name="generalFields" id="general_#encodeForHTMLAttribute(option.value)#" value="#encodeForHTMLAttribute(option.value)#" #(arrayFindNoCase(config.generalFields, option.value) ? "checked" : "")#>
                            <label class="form-check-label" for="general_#encodeForHTMLAttribute(option.value)#">#encodeForHTML(option.label)#</label>
                        </div>
                    </div>
                </cfloop>
            </div>
        </div>
    </div>

    <div class="card shadow-sm mb-4">
        <div class="card-header"><h5 class="mb-0">Contact</h5></div>
        <div class="card-body">
            <p class="text-muted small">Emails append as EMAIL_TYPE, phones append as PHONE_TYPE, and addresses append as ADDRESS_TYPE.</p>
            <div class="row g-4">
                <div class="col-lg-4">
                    <div class="fw-semibold mb-2">Email Types</div>
                    <cfif arrayLen(options.emailTypes)>
                        <cfloop array="#options.emailTypes#" index="option">
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" name="emailTypes" id="email_#encodeForHTMLAttribute(option.value)#" value="#encodeForHTMLAttribute(option.value)#" #(arrayFindNoCase(config.emailTypes, option.value) ? "checked" : "")#>
                                <label class="form-check-label" for="email_#encodeForHTMLAttribute(option.value)#">#encodeForHTML(option.label)#</label>
                            </div>
                        </cfloop>
                    <cfelse>
                        <div class="text-muted small">No email types found.</div>
                    </cfif>
                </div>
                <div class="col-lg-4">
                    <div class="fw-semibold mb-2">Phone Types</div>
                    <cfif arrayLen(options.phoneTypes)>
                        <cfloop array="#options.phoneTypes#" index="option">
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" name="phoneTypes" id="phone_#encodeForHTMLAttribute(option.value)#" value="#encodeForHTMLAttribute(option.value)#" #(arrayFindNoCase(config.phoneTypes, option.value) ? "checked" : "")#>
                                <label class="form-check-label" for="phone_#encodeForHTMLAttribute(option.value)#">#encodeForHTML(option.label)#</label>
                            </div>
                        </cfloop>
                    <cfelse>
                        <div class="text-muted small">No phone types found.</div>
                    </cfif>
                </div>
                <div class="col-lg-4">
                    <div class="fw-semibold mb-2">Address Types</div>
                    <cfif arrayLen(options.addressTypes)>
                        <cfloop array="#options.addressTypes#" index="option">
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" name="addressTypes" id="address_#encodeForHTMLAttribute(option.value)#" value="#encodeForHTMLAttribute(option.value)#" #(arrayFindNoCase(config.addressTypes, option.value) ? "checked" : "")#>
                                <label class="form-check-label" for="address_#encodeForHTMLAttribute(option.value)#">#encodeForHTML(option.label)#</label>
                            </div>
                        </cfloop>
                    <cfelse>
                        <div class="text-muted small">No address types found.</div>
                    </cfif>
                </div>
            </div>
        </div>
    </div>

    <div class="card shadow-sm mb-4">
        <div class="card-header"><h5 class="mb-0">Biographical</h5></div>
        <div class="card-body">
            <div class="row g-2">
                <cfloop array="#options.biographicalItems#" index="option">
                    <div class="col-md-4">
                        <div class="form-check">
                            <input class="form-check-input" type="checkbox" name="biographicalItems" id="bio_#encodeForHTMLAttribute(option.value)#" value="#encodeForHTMLAttribute(option.value)#" #(arrayFindNoCase(config.biographicalItems, option.value) ? "checked" : "")#>
                            <label class="form-check-label" for="bio_#encodeForHTMLAttribute(option.value)#">#encodeForHTML(option.label)#</label>
                        </div>
                    </div>
                </cfloop>
            </div>
        </div>
    </div>

    <div class="card shadow-sm mb-4">
        <div class="card-header"><h5 class="mb-0">Images</h5></div>
        <div class="card-body">
            <p class="text-muted small">Selected variants append as IMAGE_VARIANTCODE using the first matching published image URL.</p>
            <div class="row g-2">
                <cfloop array="#options.imageVariants#" index="option">
                    <div class="col-md-4">
                        <div class="form-check">
                            <input class="form-check-input" type="checkbox" name="imageVariants" id="image_#encodeForHTMLAttribute(option.value)#" value="#encodeForHTMLAttribute(option.value)#" #(arrayFindNoCase(config.imageVariants, option.value) ? "checked" : "")#>
                            <label class="form-check-label" for="image_#encodeForHTMLAttribute(option.value)#">#encodeForHTML(option.label)#</label>
                        </div>
                    </div>
                </cfloop>
            </div>
        </div>
    </div>

    <div class="card shadow-sm mb-4">
        <div class="card-header"><h5 class="mb-0">External IDs</h5></div>
        <div class="card-body">
            <p class="text-muted small">Selected systems append as EXTERNALID_SYSTEMNAME.</p>
            <div class="row g-2">
                <cfloop array="#options.externalSystems#" index="option">
                    <div class="col-md-4">
                        <div class="form-check">
                            <input class="form-check-input" type="checkbox" name="externalSystems" id="external_#encodeForHTMLAttribute(option.value)#" value="#encodeForHTMLAttribute(option.value)#" #(arrayFindNoCase(config.externalSystems, option.value) ? "checked" : "")#>
                            <label class="form-check-label" for="external_#encodeForHTMLAttribute(option.value)#">#encodeForHTML(option.label)#</label>
                        </div>
                    </div>
                </cfloop>
            </div>
        </div>
    </div>

    <div class="card shadow-sm mb-4">
        <div class="card-header"><h5 class="mb-0">Organizations And Flags</h5></div>
        <div class="card-body">
            <div class="form-check mb-2">
                <input class="form-check-input" type="checkbox" name="appendOrganizations" id="appendOrganizations" value="1" #(config.appendOrganizations ? "checked" : "")#>
                <label class="form-check-label" for="appendOrganizations">Append all organizations as ORGANIZATIONS</label>
            </div>
            <div class="form-check">
                <input class="form-check-input" type="checkbox" name="appendFlags" id="appendFlags" value="1" #(config.appendFlags ? "checked" : "")#>
                <label class="form-check-label" for="appendFlags">Append all flags as FLAGS</label>
            </div>
        </div>
    </div>

    <div class="d-flex gap-2">
        <button type="submit" class="btn btn-primary"><i class="bi bi-save me-1"></i>Save Quickpull Settings</button>
        <a href="index.cfm" class="btn btn-outline-secondary">Cancel</a>
    </div>
</form>

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">