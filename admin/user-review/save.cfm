<cfif NOT request.hasAnyPermission(["user_review.manage", "settings.app_config.manage"])>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfif cgi.request_method NEQ "POST">
    <cflocation url="/admin/user-review/" addtoken="false">
    <cfabort>
</cfif>

<cfset returnTo = trim(form.returnTo ?: "")>
<cfif NOT (left(returnTo, 7) EQ "/admin/")>
    <cfset returnTo = "/admin/user-review/">
</cfif>

<cfset appConfigService = createObject("component", "cfc.appConfig_service").init()>
<cfset editableSections = "">

<cfif structKeyExists(form, "editableSections")>
    <cfif isArray(form.editableSections)>
        <cfset editableSections = arrayToList(form.editableSections)>
    <cfelse>
        <cfset editableSections = trim(form.editableSections)>
    </cfif>
</cfif>

<cfif NOT len(editableSections)>
    <cfset editableSections = "general,contact,bioinfo">
</cfif>

<cfset appConfigService.setValue("user_review.enabled", structKeyExists(form, "enabled") ? "1" : "0")>
<cfset appConfigService.setValue("user_review.allow_faculty", structKeyExists(form, "allowFaculty") ? "1" : "0")>
<cfset appConfigService.setValue("user_review.allow_staff", structKeyExists(form, "allowStaff") ? "1" : "0")>
<cfset appConfigService.setValue("user_review.allow_current_students", structKeyExists(form, "allowCurrentStudents") ? "1" : "0")>
<cfset appConfigService.setValue("user_review.allow_alumni", structKeyExists(form, "allowAlumni") ? "1" : "0")>
<cfset appConfigService.setValue("user_review.editable_sections", editableSections)>
<cfset appConfigService.setValue("user_review.external_auth_token", trim(form.externalAuthToken ?: ""))>

<cfset savedMsgSep = (find("?", returnTo) GT 0) ? "&" : "?">
<cflocation url="#returnTo##savedMsgSep#msg=#urlEncodedFormat('User Review settings saved.')#" addtoken="false">