<cfset areaIDParam = (structKeyExists(url, "areaID") AND isNumeric(url.areaID)) ? val(url.areaID) : 0>
<cfif areaIDParam GT 0>
    <cflocation url="#request.webRoot#/admin/settings/admin-permissions/access-areas/delete.cfm?areaID=#areaIDParam#" addtoken="false">
<cfelse>
    <cflocation url="#request.webRoot#/admin/settings/admin-permissions/access-areas/" addtoken="false">
</cfif>
