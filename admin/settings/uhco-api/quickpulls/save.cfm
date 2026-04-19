<cfif NOT request.hasPermission("settings.api.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfif cgi.request_method NEQ "POST">
    <cflocation url="index.cfm" addtoken="false">
    <cfabort>
</cfif>

<cfscript>
quickpullType = lCase(trim(form.quickpullType ?: ""));
quickpullService = createObject("component", "cfc.quickpull_service").init();

function formValues(required string fieldName) {
    if (!structKeyExists(form, arguments.fieldName)) {
        return [];
    }
    if (isArray(form[arguments.fieldName])) {
        return form[arguments.fieldName];
    }
    return [form[arguments.fieldName]];
}

submittedConfig = {
    generalFields = formValues("generalFields"),
    emailTypes = formValues("emailTypes"),
    phoneTypes = formValues("phoneTypes"),
    addressTypes = formValues("addressTypes"),
    biographicalItems = formValues("biographicalItems"),
    imageVariants = formValues("imageVariants"),
    externalSystems = formValues("externalSystems"),
    appendOrganizations = structKeyExists(form, "appendOrganizations"),
    appendFlags = structKeyExists(form, "appendFlags")
};

try {
    quickpullService.saveQuickpullConfig(quickpullType, submittedConfig);
    location(url="edit.cfm?quickpull=#urlEncodedFormat(quickpullType)#&msg=#urlEncodedFormat('Quickpull settings saved.')#", addToken=false);
} catch (any err) {
    location(url="edit.cfm?quickpull=#urlEncodedFormat(quickpullType)#&error=#urlEncodedFormat(err.message)#", addToken=false);
}
</cfscript>