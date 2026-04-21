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

<cfscript>
function normalizeReturnItemToken(required string value) {
    var token = uCase(trim(arguments.value));
    token = reReplace(token, "[^A-Z0-9]+", "_", "all");
    token = reReplace(token, "_{2,}", "_", "all");
    token = reReplace(token, "^_|_$", "", "all");
    return token;
}

function findOptionLabel(required array optionList, required string selectedValue, string fallbackValue = "") {
    for (var option in arguments.optionList) {
        if (compareNoCase(trim(option.value ?: ""), trim(arguments.selectedValue)) EQ 0) {
            return option.label;
        }
    }

    return len(trim(arguments.fallbackValue)) ? arguments.fallbackValue : arguments.selectedValue;
}

function isDefaultReturnItem(required struct defaultItemSet, required string category, required string selectedValue) {
    var possibleKeys = [];
    var normalizedValue = normalizeReturnItemToken(arguments.selectedValue);

    switch (arguments.category) {
        case "General":
        case "Biographical":
            arrayAppend(possibleKeys, uCase(trim(arguments.selectedValue)));
            break;
        case "Email":
            arrayAppend(possibleKeys, "EMAIL_" & normalizedValue);
            break;
        case "Phone":
            arrayAppend(possibleKeys, "PHONE_" & normalizedValue);
            break;
        case "Address":
            arrayAppend(possibleKeys, "ADDRESS_" & normalizedValue);
            break;
        case "Images":
            arrayAppend(possibleKeys, "IMAGE_" & normalizedValue);

            if (normalizedValue EQ "INTERACTIVE_ROSTER") {
                arrayAppend(possibleKeys, "INTERACTIVEUSERIMAGE");
            } else if (normalizedValue EQ "KIOSK_ROSTER") {
                arrayAppend(possibleKeys, "KIOSKROSTERIMAGE");
            } else if (normalizedValue EQ "KIOSK_PROFILE") {
                arrayAppend(possibleKeys, "KIOSKPROFILEIMAGE");
            } else if (normalizedValue EQ "KIOSK_NON_GRID") {
                arrayAppend(possibleKeys, "KIOSKNONGRIDIMAGE");
            }
            break;
        case "External IDs":
            arrayAppend(possibleKeys, "EXTERNALID_" & normalizedValue);
            break;
        case "Organizations And Flags":
            arrayAppend(possibleKeys, uCase(trim(arguments.selectedValue)));
            break;
    }

    for (var possibleKey in possibleKeys) {
        if (structKeyExists(arguments.defaultItemSet, possibleKey)) {
            return true;
        }
    }

    return false;
}

defaultReturnItemSet = {};

for (baseField in quickpull.baseFields) {
    defaultReturnItemSet[uCase(trim(baseField))] = true;
}

additionalReturnItems = [];

for (fieldName in config.generalFields) {
    if (!isDefaultReturnItem(defaultReturnItemSet, "General", fieldName)) {
        arrayAppend(additionalReturnItems, {
            key = fieldName,
            label = findOptionLabel(options.generalFields, fieldName, fieldName),
            category = "General"
        });
    }
}

for (emailType in config.emailTypes) {
    if (!isDefaultReturnItem(defaultReturnItemSet, "Email", emailType)) {
        arrayAppend(additionalReturnItems, {
            key = "EMAIL_" & normalizeReturnItemToken(emailType),
            label = findOptionLabel(options.emailTypes, emailType, emailType),
            category = "Email"
        });
    }
}

for (phoneType in config.phoneTypes) {
    if (!isDefaultReturnItem(defaultReturnItemSet, "Phone", phoneType)) {
        arrayAppend(additionalReturnItems, {
            key = "PHONE_" & normalizeReturnItemToken(phoneType),
            label = findOptionLabel(options.phoneTypes, phoneType, phoneType),
            category = "Phone"
        });
    }
}

for (addressType in config.addressTypes) {
    if (!isDefaultReturnItem(defaultReturnItemSet, "Address", addressType)) {
        arrayAppend(additionalReturnItems, {
            key = "ADDRESS_" & normalizeReturnItemToken(addressType),
            label = findOptionLabel(options.addressTypes, addressType, addressType),
            category = "Address"
        });
    }
}

for (itemKey in config.biographicalItems) {
    if (!isDefaultReturnItem(defaultReturnItemSet, "Biographical", itemKey)) {
        arrayAppend(additionalReturnItems, {
            key = itemKey,
            label = findOptionLabel(options.biographicalItems, itemKey, itemKey),
            category = "Biographical"
        });
    }
}

for (variantCode in config.imageVariants) {
    if (!isDefaultReturnItem(defaultReturnItemSet, "Images", variantCode)) {
        arrayAppend(additionalReturnItems, {
            key = "IMAGE_" & normalizeReturnItemToken(variantCode),
            label = findOptionLabel(options.imageVariants, variantCode, variantCode),
            category = "Images"
        });
    }
}

for (systemName in config.externalSystems) {
    if (!isDefaultReturnItem(defaultReturnItemSet, "External IDs", systemName)) {
        arrayAppend(additionalReturnItems, {
            key = "EXTERNALID_" & normalizeReturnItemToken(systemName),
            label = findOptionLabel(options.externalSystems, systemName, systemName),
            category = "External IDs"
        });
    }
}

if (config.appendOrganizations AND !isDefaultReturnItem(defaultReturnItemSet, "Organizations And Flags", "ORGANIZATIONS")) {
    arrayAppend(additionalReturnItems, {
        key = "ORGANIZATIONS",
        label = "All organizations",
        category = "Organizations And Flags"
    });
}

if (config.appendFlags AND !isDefaultReturnItem(defaultReturnItemSet, "Organizations And Flags", "FLAGS")) {
    arrayAppend(additionalReturnItems, {
        key = "FLAGS",
        label = "All flags",
        category = "Organizations And Flags"
    });
}
</cfscript>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-quickpulls-edit-page">
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

<div class="card shadow-sm mb-4 settings-shell settings-reference-card">
    <div class="card-body">
        <div class="small text-uppercase text-muted fw-semibold mb-2">Default Return Items</div>
        <div class="d-flex flex-wrap gap-2">
            <cfloop array="#quickpull.baseFields#" index="baseField">
                <span class="badge settings-badge-neutral">#encodeForHTML(baseField)#</span>
            </cfloop>
        </div>
    </div>
</div>

<div class="card shadow-sm mb-4 settings-shell settings-reference-card">
    <div class="card-body">
        <div class="small text-uppercase text-muted fw-semibold mb-2">Additional Return Items</div>
        <cfif arrayLen(additionalReturnItems)>
            <div class="row g-2">
                <cfloop array="#additionalReturnItems#" index="returnItem">
                    <div class="col-md-6 col-xl-4">
                        <div class="border rounded p-2 h-100 bg-light-subtle">
                            <div class="fw-semibold">#encodeForHTML(returnItem.key)#</div>
                            <div class="small text-muted">#encodeForHTML(returnItem.category)# - #encodeForHTML(returnItem.label)#</div>
                        </div>
                    </div>
                </cfloop>
            </div>
        <cfelse>
            <div class="text-muted">No additional return items selected.</div>
        </cfif>
    </div>
</div>

<form method="post" action="save.cfm">
    <input type="hidden" name="quickpullType" value="#encodeForHTMLAttribute(quickpull.key)#">

    <div class="card shadow-sm mb-4 settings-shell settings-summary-card">
        <div class="card-header"><h5 class="mb-0">General</h5></div>
        <div class="card-body">
            <p class="text-muted small">Selected values are appended as top-level keys on each quickpull row.</p>
            <div class="row g-2">
                <cfloop array="#options.generalFields#" index="option">
                    <cfif NOT isDefaultReturnItem(defaultReturnItemSet, "General", option.value)>
                        <div class="col-md-4">
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" name="generalFields" id="general_#encodeForHTMLAttribute(option.value)#" value="#encodeForHTMLAttribute(option.value)#" #(arrayFindNoCase(config.generalFields, option.value) ? "checked" : "")#>
                                <label class="form-check-label" for="general_#encodeForHTMLAttribute(option.value)#">#encodeForHTML(option.label)#</label>
                            </div>
                        </div>
                    </cfif>
                </cfloop>
            </div>
        </div>
    </div>

    <div class="card shadow-sm mb-4 settings-shell settings-summary-card">
        <div class="card-header"><h5 class="mb-0">Contact</h5></div>
        <div class="card-body">
            <p class="text-muted small">Emails append as EMAIL_TYPE, phones append as PHONE_TYPE, and addresses append as ADDRESS_TYPE.</p>
            <div class="row g-4">
                <div class="col-lg-4">
                    <div class="fw-semibold mb-2">Email Types</div>
                    <cfif arrayLen(options.emailTypes)>
                        <cfloop array="#options.emailTypes#" index="option">
                            <cfif NOT isDefaultReturnItem(defaultReturnItemSet, "Email", option.value)>
                                <div class="form-check">
                                    <input class="form-check-input" type="checkbox" name="emailTypes" id="email_#encodeForHTMLAttribute(option.value)#" value="#encodeForHTMLAttribute(option.value)#" #(arrayFindNoCase(config.emailTypes, option.value) ? "checked" : "")#>
                                    <label class="form-check-label" for="email_#encodeForHTMLAttribute(option.value)#">#encodeForHTML(option.label)#</label>
                                </div>
                            </cfif>
                        </cfloop>
                    <cfelse>
                        <div class="text-muted small">No email types found.</div>
                    </cfif>
                </div>
                <div class="col-lg-4">
                    <div class="fw-semibold mb-2">Phone Types</div>
                    <cfif arrayLen(options.phoneTypes)>
                        <cfloop array="#options.phoneTypes#" index="option">
                            <cfif NOT isDefaultReturnItem(defaultReturnItemSet, "Phone", option.value)>
                                <div class="form-check">
                                    <input class="form-check-input" type="checkbox" name="phoneTypes" id="phone_#encodeForHTMLAttribute(option.value)#" value="#encodeForHTMLAttribute(option.value)#" #(arrayFindNoCase(config.phoneTypes, option.value) ? "checked" : "")#>
                                    <label class="form-check-label" for="phone_#encodeForHTMLAttribute(option.value)#">#encodeForHTML(option.label)#</label>
                                </div>
                            </cfif>
                        </cfloop>
                    <cfelse>
                        <div class="text-muted small">No phone types found.</div>
                    </cfif>
                </div>
                <div class="col-lg-4">
                    <div class="fw-semibold mb-2">Address Types</div>
                    <cfif arrayLen(options.addressTypes)>
                        <cfloop array="#options.addressTypes#" index="option">
                            <cfif NOT isDefaultReturnItem(defaultReturnItemSet, "Address", option.value)>
                                <div class="form-check">
                                    <input class="form-check-input" type="checkbox" name="addressTypes" id="address_#encodeForHTMLAttribute(option.value)#" value="#encodeForHTMLAttribute(option.value)#" #(arrayFindNoCase(config.addressTypes, option.value) ? "checked" : "")#>
                                    <label class="form-check-label" for="address_#encodeForHTMLAttribute(option.value)#">#encodeForHTML(option.label)#</label>
                                </div>
                            </cfif>
                        </cfloop>
                    <cfelse>
                        <div class="text-muted small">No address types found.</div>
                    </cfif>
                </div>
            </div>
        </div>
    </div>

    <div class="card shadow-sm mb-4 settings-shell settings-summary-card">
        <div class="card-header"><h5 class="mb-0">Biographical</h5></div>
        <div class="card-body">
            <div class="row g-2">
                <cfloop array="#options.biographicalItems#" index="option">
                    <cfif NOT isDefaultReturnItem(defaultReturnItemSet, "Biographical", option.value)>
                        <div class="col-md-4">
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" name="biographicalItems" id="bio_#encodeForHTMLAttribute(option.value)#" value="#encodeForHTMLAttribute(option.value)#" #(arrayFindNoCase(config.biographicalItems, option.value) ? "checked" : "")#>
                                <label class="form-check-label" for="bio_#encodeForHTMLAttribute(option.value)#">#encodeForHTML(option.label)#</label>
                            </div>
                        </div>
                    </cfif>
                </cfloop>
            </div>
        </div>
    </div>

    <div class="card shadow-sm mb-4 settings-shell settings-summary-card">
        <div class="card-header"><h5 class="mb-0">Images</h5></div>
        <div class="card-body">
            <p class="text-muted small">Selected variants append as IMAGE_VARIANTCODE using the first matching published image URL.</p>
            <div class="row g-2">
                <cfloop array="#options.imageVariants#" index="option">
                    <cfif NOT isDefaultReturnItem(defaultReturnItemSet, "Images", option.value)>
                        <div class="col-md-4">
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" name="imageVariants" id="image_#encodeForHTMLAttribute(option.value)#" value="#encodeForHTMLAttribute(option.value)#" #(arrayFindNoCase(config.imageVariants, option.value) ? "checked" : "")#>
                                <label class="form-check-label" for="image_#encodeForHTMLAttribute(option.value)#">#encodeForHTML(option.label)#</label>
                            </div>
                        </div>
                    </cfif>
                </cfloop>
            </div>
        </div>
    </div>

    <div class="card shadow-sm mb-4 settings-shell settings-summary-card">
        <div class="card-header"><h5 class="mb-0">External IDs</h5></div>
        <div class="card-body">
            <p class="text-muted small">Selected systems append as EXTERNALID_SYSTEMNAME.</p>
            <div class="row g-2">
                <cfloop array="#options.externalSystems#" index="option">
                    <cfif NOT isDefaultReturnItem(defaultReturnItemSet, "External IDs", option.value)>
                        <div class="col-md-4">
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" name="externalSystems" id="external_#encodeForHTMLAttribute(option.value)#" value="#encodeForHTMLAttribute(option.value)#" #(arrayFindNoCase(config.externalSystems, option.value) ? "checked" : "")#>
                                <label class="form-check-label" for="external_#encodeForHTMLAttribute(option.value)#">#encodeForHTML(option.label)#</label>
                            </div>
                        </div>
                    </cfif>
                </cfloop>
            </div>
        </div>
    </div>

    <div class="card shadow-sm mb-4 settings-shell settings-summary-card">
        <div class="card-header"><h5 class="mb-0">Organizations And Flags</h5></div>
        <div class="card-body">
            <cfif NOT isDefaultReturnItem(defaultReturnItemSet, "Organizations And Flags", "ORGANIZATIONS")>
                <div class="form-check mb-2">
                    <input class="form-check-input" type="checkbox" name="appendOrganizations" id="appendOrganizations" value="1" #(config.appendOrganizations ? "checked" : "")#>
                    <label class="form-check-label" for="appendOrganizations">Append all organizations as ORGANIZATIONS</label>
                </div>
            </cfif>
            <cfif NOT isDefaultReturnItem(defaultReturnItemSet, "Organizations And Flags", "FLAGS")>
                <div class="form-check">
                    <input class="form-check-input" type="checkbox" name="appendFlags" id="appendFlags" value="1" #(config.appendFlags ? "checked" : "")#>
                    <label class="form-check-label" for="appendFlags">Append all flags as FLAGS</label>
                </div>
            </cfif>
        </div>
    </div>

    <div class="d-flex gap-2">
        <button type="submit" class="btn btn-primary"><i class="bi bi-save me-1"></i>Save Quickpull Settings</button>
        <a href="index.cfm" class="btn btn-outline-secondary">Cancel</a>
    </div>
</form>

</div>

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">