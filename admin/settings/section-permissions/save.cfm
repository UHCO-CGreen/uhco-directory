<!---
    Section Permissions — POST handler for updateSectionPermission.
    Permission: settings.admin_permissions.manage
--->

<cfif NOT request.hasPermission("settings.admin_permissions.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset sectionsDAO  = createObject("component", "dao.adminSections_DAO").init()>
<cfset action       = trim(form.action ?: "")>
<cfset redirectURL  = "/admin/settings/section-permissions/">

<cftry>
    <cfswitch expression="#action#">

        <cfcase value="updateSectionPermission">
            <cfset sectionID    = (isNumeric(form.sectionID    ?: "")) ? val(form.sectionID)    : 0>
            <cfset permissionID = (isNumeric(form.permissionID ?: "")) ? val(form.permissionID) : 0>

            <cfif sectionID LTE 0 OR permissionID LTE 0>
                <cfset redirectURL &= "?err=" & urlEncodedFormat("Invalid section or permission ID.")>
                <cflocation url="#redirectURL#" addtoken="false">
                <cfabort>
            </cfif>

            <cfset sectionsDAO.updateSectionPermission(
                sectionId    = sectionID,
                permissionId = permissionID
            )>

            <!--- Flush the application-scope section registry cache if it exists --->
            <cfif structKeyExists(application, "sectionPermissions")>
                <cfset structDelete(application, "sectionPermissions")>
            </cfif>

            <cfset redirectURL &= "?msg=" & urlEncodedFormat("Section permission updated.")>
        </cfcase>

        <cfdefaultcase>
            <cfset redirectURL &= "?err=" & urlEncodedFormat("Unknown action.")>
        </cfdefaultcase>

    </cfswitch>
<cfcatch type="any">
    <cfset redirectURL &= "?err=" & urlEncodedFormat(cfcatch.message)>
</cfcatch>
</cftry>

<cflocation url="#redirectURL#" addtoken="false">
