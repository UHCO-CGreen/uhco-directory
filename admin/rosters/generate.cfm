<!---
    Generate roster PDF.
    Permission: rosters.manage.
--->

<cfsetting showdebugoutput="false">

<cfif NOT request.hasPermission("rosters.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfif cgi.request_method NEQ "POST">
    <cflocation url="index.cfm" addtoken="false">
</cfif>

<cfset rosterService = createObject("component", "cfc.roster_service").init()>
<cfset appConfigService = createObject("component", "cfc.appConfig_service").init()>
<cfset selectedProgram = trim(form.programName ?: "")>
<cfset selectedGradYearRaw = trim(form.gradYear ?: "")>
<cfset redirectURL = "index.cfm">

<cftry>
    <cfif NOT len(selectedGradYearRaw) OR NOT isValid("integer", selectedGradYearRaw)>
        <cfthrow type="Roster.InvalidInput" message="Please select a valid graduation year.">
    </cfif>

    <cfset selectedGradYear = val(selectedGradYearRaw)>
    <cfif selectedGradYear LT 1900 OR selectedGradYear GT (year(now()) + 10)>
        <cfthrow type="Roster.InvalidInput" message="Graduation year is outside the allowed range.">
    </cfif>

    <cfset rosterUsers = rosterService.getRosterUsers(selectedGradYear, selectedProgram)>
    <cfset userCount = arrayLen(rosterUsers)>

    <cfif userCount EQ 0>
        <cfthrow type="Roster.EmptyResult" message="No Current-Student users were found for that year and program.">
    </cfif>

    <cfset layoutConfig = rosterService.getLayoutConfig(userCount)>
    <cfset pageEstimate = rosterService.estimatePages(userCount)>
    <cfif pageEstimate.exceedsTwoPages>
        <cfthrow
            type="Roster.PageLimitExceeded"
            message="Roster exceeds 2 pages for current layout. Users: #userCount#, projected pages: #pageEstimate.projectedPages#, max supported: #pageEstimate.maxSupportedCount#."
        >
    </cfif>

    <cfset outputDir = expandPath("/_temp_rosters")>
    <cfif NOT directoryExists(outputDir)>
        <cfdirectory action="create" directory="#outputDir#">
    </cfif>

    <cfset outputFileName = "class-of-#selectedGradYear#-roster.pdf">
    <cfset outputFilePath = outputDir & "/" & outputFileName>
    <cfset publishMetaPath = outputDir & "/.publish-status.json">
    <cfset generatedAt = now()>
    <cfset publishStatus = "skip">
    <cfset publishPath = "">
    <cfset publishError = "">

    <cfsavecontent variable="pdfBody">
        <cfinclude template="/admin/rosters/templates/roster-pdf.cfm">
    </cfsavecontent>

    <cfdocument
        format="PDF"
        filename="#outputFilePath#"
        overwrite="true"
        localurl="true"
        orientation="#layoutConfig.pageOrientation#"
        margintop="#layoutConfig.marginTopIn#"
        marginbottom="#layoutConfig.marginBottomIn#"
        marginleft="#layoutConfig.marginLeftIn#"
        marginright="#layoutConfig.marginRightIn#"
    >
        <cfoutput>#pdfBody#</cfoutput>
    </cfdocument>

    <cfif listFindNoCase("1,true,yes,on", lCase(trim(appConfigService.getValue("roster.dropbox_publish_enabled", "false"))))>
        <cftry>
            <cfset dropboxProvider = createObject("component", "cfc.DropboxProvider").init()>
            <cfset publishFolder = trim(appConfigService.getValue("roster.dropbox_publish_path", "Digital Assets/MyUHCO"))>

            <cfif len(publishFolder)>
                <cfset dropboxProvider.createFolder(publishFolder)>
            </cfif>

            <cfset publishPath = dropboxProvider.uploadFile(
                localPath = outputFilePath,
                dropboxPath = publishFolder & "/" & outputFileName,
                overwrite = true
            )>
            <cfset publishStatus = "ok">
            <cfcatch type="any">
                <cfset publishStatus = "fail">
                <cfset publishError = left(trim(cfcatch.message ?: "Dropbox publish failed."), 240)>
            </cfcatch>
        </cftry>
    </cfif>

    <cfif publishStatus NEQ "skip">
        <cftry>
            <cflock type="exclusive" timeout="5" name="roster.publishmeta.#hash(publishMetaPath)#">
                <cfset publishMeta = {}>
                <cfif fileExists(publishMetaPath)>
                    <cfset publishMetaRaw = trim(fileRead(publishMetaPath, "utf-8"))>
                    <cfif len(publishMetaRaw) AND isJSON(publishMetaRaw)>
                        <cfset publishMeta = deserializeJSON(publishMetaRaw)>
                        <cfif NOT isStruct(publishMeta)>
                            <cfset publishMeta = {}>
                        </cfif>
                    </cfif>
                </cfif>

                <cfset publishMeta[lCase(outputFileName)] = {
                    "lastStatus" = publishStatus,
                    "lastAttemptAt" = dateTimeFormat(now(), "mm/dd/yyyy h:nn tt"),
                    "lastPublishedAt" = publishStatus EQ "ok" ? dateTimeFormat(now(), "mm/dd/yyyy h:nn tt") : "",
                    "lastPublishedPath" = publishStatus EQ "ok" ? publishPath : "",
                    "lastError" = publishStatus EQ "fail" ? publishError : ""
                }>

                <cfset fileWrite(publishMetaPath, serializeJSON(publishMeta), "utf-8")>
            </cflock>
        <cfcatch>
            <!--- Keep generation response non-blocking if metadata write fails. --->
        </cfcatch>
        </cftry>
    </cfif>

    <cfset redirectURL &= "?msg=" & urlEncodedFormat("Roster generated successfully.")>
    <cfset redirectURL &= "&year=" & urlEncodedFormat(selectedGradYear)>
    <cfset redirectURL &= "&count=" & urlEncodedFormat(userCount)>
    <cfset redirectURL &= "&pages=" & urlEncodedFormat(pageEstimate.projectedPages)>
    <cfset redirectURL &= "&publish=" & urlEncodedFormat(publishStatus)>
    <cfif len(publishPath)>
        <cfset redirectURL &= "&publishPath=" & urlEncodedFormat(publishPath)>
    </cfif>
    <cfif len(publishError)>
        <cfset redirectURL &= "&publishErr=" & urlEncodedFormat(publishError)>
    </cfif>
<cfcatch>
    <cfset redirectURL &= "?err=" & urlEncodedFormat(cfcatch.message ?: "Unable to generate roster PDF.")>
    <cfif len(selectedGradYearRaw)>
        <cfset redirectURL &= "&year=" & urlEncodedFormat(selectedGradYearRaw)>
    </cfif>
</cfcatch>
</cftry>

<cflocation url="#redirectURL#" addtoken="false">