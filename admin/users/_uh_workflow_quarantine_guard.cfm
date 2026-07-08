<cfset quarantineEnabled = NOT (structKeyExists(request, "isProduction") AND request.isProduction)>

<cfif quarantineEnabled>
    <cfset resolvedMode = isDefined("quarantineMode") ? lCase(trim(quarantineMode ?: "page")) : "page">
    <cfset resolvedMessage = isDefined("quarantineMessage") ? trim(quarantineMessage ?: "") : "">
    <cfset resolvedReturnTo = isDefined("quarantineReturnTo") ? trim(quarantineReturnTo ?: "") : "">

    <cfif resolvedMessage EQ "">
        <cfset resolvedMessage = "UH import and sync workflows are temporarily disabled in this development environment while the priority fix plan is completed.">
    </cfif>

    <cfif resolvedMode EQ "redirect">
        <cfif resolvedReturnTo EQ "" AND structKeyExists(form, "returnTo")>
            <cfset resolvedReturnTo = trim(form.returnTo ?: "")>
        </cfif>
        <cfif resolvedReturnTo EQ "" AND structKeyExists(url, "returnTo")>
            <cfset resolvedReturnTo = trim(url.returnTo ?: "")>
        </cfif>
        <cfif left(resolvedReturnTo, 1) NEQ "/" OR find("//", resolvedReturnTo) OR findNoCase("javascript:", resolvedReturnTo)>
            <cfset resolvedReturnTo = "/admin/users/index.cfm">
        </cfif>
        <cfset redirectSep = find("?", resolvedReturnTo) ? "&" : "?">
        <cflocation url="#resolvedReturnTo##redirectSep#err=#urlEncodedFormat(resolvedMessage)#" addtoken="false">
        <cfabort>
    </cfif>

    <cfset content = "">
    <cfset content &= "<h1>UH Workflow Temporarily Disabled</h1>">
    <cfset content &= "<div class='alert alert-warning'><strong>Maintenance mode:</strong> #EncodeForHTML(resolvedMessage)#</div>">
    <cfset content &= "<div class='d-flex gap-2 flex-wrap'><a href='/admin/users/index.cfm' class='btn btn-ui-cancel'>Back to Users</a><a href='/admin/dashboard.cfm' class='btn btn-ui-cancel'>Back to Dashboard</a></div>">
    <cfinclude template="/admin/layout.cfm">
    <cfabort>
</cfif>