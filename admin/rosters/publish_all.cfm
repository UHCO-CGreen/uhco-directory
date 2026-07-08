<!---
    Publish all existing generated roster PDFs to Dropbox.
    Permission: rosters.manage.
--->

<cfsetting showdebugoutput="false">

<cfif NOT request.hasPermission("rosters.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfif cgi.request_method NEQ "POST">
    <cflocation url="index.cfm" addtoken="false">
</cfif>

<cfset appConfigService = createObject("component", "cfc.appConfig_service").init()>
<cfset redirectURL = "index.cfm">
<cfset rosterDirectory = expandPath("/_temp_rosters")>
<cfset publishMetaPath = rosterDirectory & "/.publish-status.json">

<cftry>
    <cfif NOT listFindNoCase("1,true,yes,on", lCase(trim(appConfigService.getValue("roster.dropbox_publish_enabled", "false"))))>
        <cfthrow type="Roster.DropboxDisabled" message="Dropbox publishing is disabled for rosters.">
    </cfif>

    <cfif NOT directoryExists(rosterDirectory)>
        <cfthrow type="Roster.NoFiles" message="No roster PDFs found to publish.">
    </cfif>

    <cfdirectory
        action="list"
        directory="#rosterDirectory#"
        name="availableRosters"
        filter="class-of-*-roster.pdf"
        sort="name ASC"
        type="file"
    >

    <cfif availableRosters.recordCount EQ 0>
        <cfthrow type="Roster.NoFiles" message="No roster PDFs found to publish.">
    </cfif>

    <cfset publishFolder = trim(appConfigService.getValue("roster.dropbox_publish_path", "Digital Assets/MyUHCO"))>
    <cfset dropboxProvider = createObject("component", "cfc.DropboxProvider").init()>

    <cfif len(publishFolder)>
        <cfset dropboxProvider.createFolder(publishFolder)>
    </cfif>

    <cfset succeeded = 0>
    <cfset failed = 0>
    <cfset failedNames = []>
    <cfset updateMeta = {}>

    <cfloop query="availableRosters">
        <cfset fileName = availableRosters.name>
        <cfset localFilePath = rosterDirectory & "/" & fileName>
        <cfset status = "fail">
        <cfset publishedPath = "">
        <cfset errorMessage = "Dropbox publish failed.">

        <cftry>
            <cfset publishedPath = dropboxProvider.uploadFile(
                localPath = localFilePath,
                dropboxPath = publishFolder & "/" & fileName,
                overwrite = true
            )>
            <cfset status = "ok">
            <cfset errorMessage = "">
            <cfset succeeded++>
        <cfcatch>
            <cfset failed++>
            <cfset errorMessage = left(trim(cfcatch.message ?: "Dropbox publish failed."), 240)>
            <cfset arrayAppend(failedNames, fileName)>
        </cfcatch>
        </cftry>

        <cfset updateMeta[lCase(fileName)] = {
            "lastStatus" = status,
            "lastAttemptAt" = dateTimeFormat(now(), "mm/dd/yyyy h:nn tt"),
            "lastPublishedAt" = status EQ "ok" ? dateTimeFormat(now(), "mm/dd/yyyy h:nn tt") : "",
            "lastPublishedPath" = status EQ "ok" ? publishedPath : "",
            "lastError" = status EQ "fail" ? errorMessage : ""
        }>
    </cfloop>

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

            <cfloop collection="#updateMeta#" item="metaKey">
                <cfset publishMeta[metaKey] = updateMeta[metaKey]>
            </cfloop>

            <cfset fileWrite(publishMetaPath, serializeJSON(publishMeta), "utf-8")>
        </cflock>
    <cfcatch>
        <!--- Keep publish-all response non-blocking if metadata write fails. --->
    </cfcatch>
    </cftry>

    <cfset redirectURL &= "?msg=" & urlEncodedFormat("Published " & succeeded & " roster(s) to Dropbox.")>
    <cfif failed EQ 0>
        <cfset redirectURL &= "&publish=ok">
    <cfelse>
        <cfset redirectURL &= "&publish=fail">
        <cfset redirectURL &= "&publishErr=" & urlEncodedFormat("Failed: " & failed & " file(s). " & left(arrayToList(failedNames, ", "), 180))>
    </cfif>
<cfcatch>
    <cfset redirectURL &= "?publish=fail">
    <cfset redirectURL &= "&publishErr=" & urlEncodedFormat(left(trim(cfcatch.message ?: "Unable to publish rosters."), 240))>
</cfcatch>
</cftry>

<cflocation url="#redirectURL#" addtoken="false">
