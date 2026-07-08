<!---
    Download generated roster PDF.
    Permission: rosters.manage.
--->

<cfsetting showdebugoutput="false">

<cfif NOT request.hasPermission("rosters.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset requestedFileName = trim(url.filename ?: "")>
<cfset selectedYearRaw = trim(url.year ?: "")>

<cfif len(requestedFileName)>
    <cfif NOT reFindNoCase("^class-of-[0-9]{4}-roster\.pdf$", requestedFileName)>
        <cflocation url="index.cfm?err=#urlEncodedFormat('Invalid roster file name.')#" addtoken="false">
    </cfif>
    <cfset fileName = requestedFileName>
<cfelse>
    <cfif NOT len(selectedYearRaw) OR NOT isValid("integer", selectedYearRaw)>
        <cflocation url="index.cfm?err=#urlEncodedFormat('Invalid roster year.')#" addtoken="false">
    </cfif>
    <cfset selectedYear = val(selectedYearRaw)>
    <cfset fileName = "class-of-#selectedYear#-roster.pdf">
</cfif>

<cfset filePath = expandPath("/_temp_rosters/#fileName#")>

<cfif NOT fileExists(filePath)>
    <cflocation url="index.cfm?err=#urlEncodedFormat('Requested roster file does not exist.')#" addtoken="false">
</cfif>

<cfheader name="Content-Disposition" value="attachment; filename=#fileName#">
<cfcontent file="#filePath#" type="application/pdf" deleteFile="false">
<cfabort>